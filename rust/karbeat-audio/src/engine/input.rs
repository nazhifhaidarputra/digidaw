//! Device input captured for level −1 of the render graph.
//!
//! The device's input callback queues interleaved samples on a ring. Once per engine block the
//! DSP thread converts them to the engine rate and keeps one block of every device channel;
//! level −1 nodes then pick the channels each monitored track listens to.

use hashbrown::HashMap;
use karbeat_core::shared::TrackId;
use rtrb::Consumer;

use crate::rate_bridge::DeviceRateBridge;

/// Channels of the input device a track listens to.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub struct InputSource {
    /// First device channel, from 0.
    pub first_channel: u16,
    /// 1 plays the channel on both sides; 2 takes it and the next as left and right.
    pub channels: u16,
}

/// Input a track listens to.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct TrackInput {
    pub source: InputSource,
    /// Whether the input is heard through the track.
    pub monitor: bool,
}

/// Input stream of one device, handed to the engine when the stream starts.
pub struct InputCapture {
    consumer: Consumer<f32>,
    device_channels: usize,
    bridge: DeviceRateBridge,
    /// One bridge call worth of device samples.
    staging: Vec<f32>,
    /// Converted samples at the engine rate not yet taken by a block.
    pending: Vec<f32>,
    pending_len: usize,
}

impl InputCapture {
    /// Prepares to convert `device_channels` channels from `device_rate` to `dsp_rate` in
    /// blocks of up to `block_frames`. Allocates; call when the stream starts.
    pub fn new(
        consumer: Consumer<f32>,
        device_channels: usize,
        device_rate: u32,
        dsp_rate: u32,
        block_frames: usize,
    ) -> anyhow::Result<Self> {
        let bridge = DeviceRateBridge::with_fixed_output(
            device_rate,
            dsp_rate,
            device_channels,
            block_frames,
        )?;
        let staging = vec![0.0; bridge.maximum_input_frames() * device_channels];
        let pending =
            vec![0.0; (block_frames * 2) * device_channels + bridge.maximum_output_samples()];
        Ok(Self {
            consumer,
            device_channels,
            bridge,
            staging,
            pending,
            pending_len: 0,
        })
    }

    pub fn device_channels(&self) -> usize {
        self.device_channels
    }

    /// Converts queued device input until `frames` engine frames are pending or the ring runs
    /// dry. Returns whether `frames` are pending.
    fn fill(&mut self, frames: usize) -> bool {
        let channels = self.device_channels;
        while self.pending_len < frames * channels {
            let needed = self.bridge.input_frames_next() * channels;
            if self.consumer.slots() < needed || self.staging.len() < needed {
                break;
            }
            let Ok(chunk) = self.consumer.read_chunk(needed) else {
                break;
            };
            let (first, second) = chunk.as_slices();
            self.staging[..first.len()].copy_from_slice(first);
            self.staging[first.len()..first.len() + second.len()].copy_from_slice(second);
            chunk.commit_all();
            let converted = self.bridge.process(&self.staging[..needed]);
            let Some(room) = self
                .pending
                .get_mut(self.pending_len..self.pending_len + converted.len())
            else {
                break;
            };
            room.copy_from_slice(converted);
            self.pending_len += converted.len();
        }
        self.pending_len >= frames * channels
    }

    /// Whether a block of `frames` can be captured without converting more than one call.
    fn ready(&self, frames: usize) -> bool {
        let channels = self.device_channels;
        self.pending_len >= frames * channels
            || self.consumer.slots() >= self.bridge.input_frames_next() * channels
    }
}

/// Input state of the engine: what tracks listen to and the current block of device input.
#[derive(Default)]
pub(super) struct InputState {
    pub tracks: HashMap<TrackId, TrackInput>,
    capture: Option<InputCapture>,
    /// Every device channel of the current block at the engine rate, interleaved.
    block: Vec<f32>,
    /// Frames of `block` already handed to render passes.
    cursor: usize,
    /// Whether `block` holds captured input; it is silence after an underrun.
    live: bool,
    /// Blocks rendered without enough input.
    pub underruns: u64,
}

impl InputState {
    /// Installs a device input stream, returning the previous one. Allocates.
    pub fn attach(&mut self, capture: InputCapture, block_frames: usize) -> Option<InputCapture> {
        self.block = vec![0.0; block_frames * capture.device_channels];
        self.live = false;
        self.capture.replace(capture)
    }

    pub fn detach(&mut self) -> Option<InputCapture> {
        self.live = false;
        self.capture.take()
    }

    pub fn device_channels(&self) -> usize {
        self.capture
            .as_ref()
            .map_or(0, InputCapture::device_channels)
    }

    /// Whether the next block of `frames` has its input waiting. Without an input stream there
    /// is nothing to wait for.
    pub fn ready(&self, frames: usize) -> bool {
        self.capture
            .as_ref()
            .is_none_or(|capture| capture.ready(frames))
    }

    /// Captures the input of the next engine block. A short ring renders the block with
    /// silent input and counts an underrun. Real-time safe.
    pub fn capture(&mut self, frames: usize) {
        self.cursor = 0;
        let Some(capture) = self.capture.as_mut() else {
            self.live = false;
            return;
        };
        let samples = frames * capture.device_channels;
        if self.block.len() < samples || !capture.fill(frames) {
            self.live = false;
            self.underruns += 1;
            return;
        }
        self.block[..samples].copy_from_slice(&capture.pending[..samples]);
        capture.pending.copy_within(samples..capture.pending_len, 0);
        capture.pending_len -= samples;
        self.live = true;
    }

    /// The next `frames` frames of the captured block for one render pass, and whether they
    /// hold live input.
    pub fn take(&mut self, frames: usize) -> (&[f32], bool) {
        let channels = self.device_channels();
        let start = self.cursor * channels;
        self.cursor += frames;
        match self.block.get(start..start + frames * channels) {
            Some(samples) if self.live => (samples, true),
            _ => (&[], false),
        }
    }
}

/// Copies `source`'s channels out of one interleaved device block into a stereo block.
pub(super) fn extract_source(
    device: &[f32],
    device_channels: usize,
    source: InputSource,
    output: &mut [f32],
) {
    let first = usize::from(source.first_channel);
    let stereo = source.channels >= 2;
    for (frame, out) in device
        .chunks_exact(device_channels.max(1))
        .zip(output.as_chunks_mut::<2>().0)
    {
        let left = frame.get(first).copied().unwrap_or(0.0);
        let right = if stereo {
            frame.get(first + 1).copied().unwrap_or(0.0)
        } else {
            left
        };
        *out = [left, right];
    }
}

#[cfg(test)]
#[allow(
    clippy::unwrap_used,
    reason = "input tests fail immediately when a fixture cannot be built"
)]
mod tests {
    use super::{InputCapture, InputSource, InputState, extract_source};

    fn state_with_ring(channels: usize, block: usize) -> (InputState, rtrb::Producer<f32>) {
        let (producer, consumer) = rtrb::RingBuffer::new(block * channels * 8);
        let capture = InputCapture::new(consumer, channels, 48_000, 48_000, block).unwrap();
        let mut state = InputState::default();
        state.attach(capture, block);
        (state, producer)
    }

    #[test]
    fn captured_blocks_hand_out_the_device_samples_in_order() {
        let (mut state, mut producer) = state_with_ring(2, 4);
        for sample in 0..16 {
            producer.push(sample as f32).unwrap();
        }
        assert!(state.ready(4));
        state.capture(4);
        let (first, live) = state.take(2);
        assert!(live);
        assert_eq!(first, &[0.0, 1.0, 2.0, 3.0]);
        let (second, _) = state.take(2);
        assert_eq!(second, &[4.0, 5.0, 6.0, 7.0]);
        state.capture(4);
        assert_eq!(
            state.take(4).0,
            &[8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0]
        );
    }

    #[test]
    fn a_short_ring_renders_silent_input_and_counts_an_underrun() {
        let (mut state, mut producer) = state_with_ring(2, 4);
        producer.push(1.0).unwrap();
        assert!(!state.ready(4));
        state.capture(4);
        assert_eq!(state.underruns, 1);
        assert!(!state.take(4).1);
    }

    #[test]
    fn sources_pick_their_channels() {
        let device = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0];
        let mut stereo = [0.0; 4];
        extract_source(
            &device,
            3,
            InputSource {
                first_channel: 1,
                channels: 2,
            },
            &mut stereo,
        );
        assert_eq!(stereo, [2.0, 3.0, 5.0, 6.0]);
        let mut mono = [0.0; 4];
        extract_source(
            &device,
            3,
            InputSource {
                first_channel: 2,
                channels: 1,
            },
            &mut mono,
        );
        assert_eq!(mono, [3.0, 3.0, 6.0, 6.0]);
    }
}
