//! Device input captured for level −1 of the render graph.
//!
//! The device's input callback queues interleaved samples on a ring. Once per engine block the
//! DSP thread converts them to the engine rate and keeps one block of every device channel;
//! level −1 nodes then pick the channels each monitored track listens to, and recording takes
//! copy the channels they record.
//!
//! The input device runs on its own clock, which drifts from the output clock that paces the
//! engine. A [`DriftController`] watches how much input waits on the ring and nudges the
//! resampling ratio so the backlog, and with it the input latency, stays constant.

use karbeat_core::core::project::TrackInputSettings;
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

impl From<&TrackInputSettings> for InputSource {
    fn from(settings: &TrackInputSettings) -> Self {
        Self {
            first_channel: settings.first_channel,
            channels: settings.channels.clamp(1, 2),
        }
    }
}

/// Input stream of one device, handed to the engine when the stream starts.
pub struct InputCapture {
    consumer: Consumer<f32>,
    device_channels: usize,
    device_rate: u32,
    dsp_rate: u32,
    bridge: DeviceRateBridge,
    drift: DriftController,
    /// One bridge call worth of device samples.
    staging: Vec<f32>,
    /// Converted samples at the engine rate not yet taken by a block.
    pending: Vec<f32>,
    pending_len: usize,
    /// Device frames read from the ring since the stream started.
    consumed_frames: u64,
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
        let bridge = DeviceRateBridge::adjustable_fixed_output(
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
            device_rate,
            dsp_rate,
            bridge,
            drift: DriftController::default(),
            staging,
            pending,
            pending_len: 0,
            consumed_frames: 0,
        })
    }

    pub fn device_channels(&self) -> usize {
        self.device_channels
    }

    /// Device frames per engine frame at the nominal rates.
    fn device_per_engine_frame(&self) -> f64 {
        f64::from(self.device_rate) / f64::from(self.dsp_rate.max(1))
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
            self.consumed_frames += (needed / channels) as u64;
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

    /// Device frame the first pending engine frame was converted from.
    fn first_pending_device_frame(&self) -> u64 {
        let behind = (self.pending_len / self.device_channels.max(1)
            + self.bridge.output_delay_frames()) as f64
            * self.device_per_engine_frame();
        self.consumed_frames.saturating_sub(behind.round() as u64)
    }

    /// Device input waiting to become engine frames, in device frames.
    fn backlog_frames(&self) -> f64 {
        let channels = self.device_channels.max(1);
        (self.consumer.slots() / channels) as f64
            + (self.pending_len / channels) as f64 * self.device_per_engine_frame()
    }

    /// Feeds the backlog after a block of `frames` to the drift controller and applies the
    /// ratio it asks for. Real-time safe.
    fn correct_drift(&mut self, frames: usize) {
        let elapsed = frames as f64 / f64::from(self.dsp_rate.max(1));
        let relative = self.drift.update(
            self.backlog_frames() / f64::from(self.device_rate.max(1)),
            elapsed,
        );
        self.bridge.set_relative_ratio(relative);
    }

    /// Whether a block of `frames` can be captured without converting more than one call.
    fn ready(&self, frames: usize) -> bool {
        let channels = self.device_channels;
        self.pending_len >= frames * channels
            || self.consumer.slots() >= self.bridge.input_frames_next() * channels
    }
}

/// Holds the input backlog at the level it settled at after the stream started, by scaling the
/// resampling ratio: a growing backlog means the input clock runs faster than the engine's, so
/// more input is taken per block.
///
/// The backlog is smoothed over [`Self::SMOOTHING`] seconds, which averages away the sawtooth
/// of the device callbacks, and a PI loop that settles in about a minute steers it.
#[derive(Debug)]
pub(super) struct DriftController {
    /// Smoothed backlog in seconds.
    smoothed: Option<f64>,
    /// Backlog held once warm-up ends, in seconds.
    target: Option<f64>,
    /// Seconds of input seen so far, until warm-up ends.
    warmed: f64,
    /// Integral of the backlog error, in second-seconds.
    integral: f64,
    /// Current ratio scale; below 1 takes more input per block.
    relative: f64,
}

impl Default for DriftController {
    fn default() -> Self {
        Self {
            smoothed: None,
            target: None,
            warmed: 0.0,
            integral: 0.0,
            relative: 1.0,
        }
    }
}

impl DriftController {
    /// Seconds over which the backlog is averaged.
    const SMOOTHING: f64 = 2.0;
    /// Seconds after the start before the backlog is taken as the target.
    const WARM_UP: f64 = 1.0;
    /// Proportional gain, per second of backlog error.
    const PROPORTIONAL: f64 = 0.2;
    /// Integral gain, per second-second of backlog error.
    const INTEGRAL: f64 = 0.01;
    /// Largest correction, as a fraction of the nominal ratio.
    const MAX_CORRECTION: f64 = 0.01;

    /// Takes the `backlog` in seconds after `elapsed` seconds of input and returns the ratio
    /// scale to resample the next block with.
    pub fn update(&mut self, backlog: f64, elapsed: f64) -> f64 {
        let smoothed = match self.smoothed {
            Some(smoothed) => {
                let weight = elapsed / (Self::SMOOTHING + elapsed);
                smoothed + (backlog - smoothed) * weight
            }
            None => backlog,
        };
        self.smoothed = Some(smoothed);
        let Some(target) = self.target else {
            self.warmed += elapsed;
            if self.warmed >= Self::WARM_UP {
                self.target = Some(smoothed);
            }
            return self.relative;
        };
        let error = smoothed - target;
        let integral_limit = Self::MAX_CORRECTION / Self::INTEGRAL;
        self.integral = (self.integral + error * elapsed).clamp(-integral_limit, integral_limit);
        let correction = Self::PROPORTIONAL * error + Self::INTEGRAL * self.integral;
        self.relative = 1.0 - correction.clamp(-Self::MAX_CORRECTION, Self::MAX_CORRECTION);
        self.relative
    }

    /// How much faster the input clock runs than the engine's, in parts per million.
    pub fn drift_ppm(&self) -> f64 {
        (1.0 / self.relative - 1.0) * 1.0e6
    }
}

/// Input state of the engine: the current block of device input.
#[derive(Default)]
pub(super) struct InputState {
    capture: Option<InputCapture>,
    /// Every device channel of the current block at the engine rate, interleaved.
    block: Vec<f32>,
    /// Frames of `block` already handed to render passes.
    cursor: usize,
    /// Whether `block` holds captured input; it is silence after an underrun.
    live: bool,
    /// Device frame the current block's first frame was captured as.
    block_input_frame: u64,
    /// Blocks rendered without enough input.
    pub underruns: u64,
}

impl InputState {
    /// Installs a device input stream, returning the previous one. Allocates.
    pub fn attach(&mut self, capture: InputCapture, block_frames: usize) -> Option<InputCapture> {
        self.block = vec![0.0; block_frames * capture.device_channels];
        self.live = false;
        self.block_input_frame = 0;
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
            let advance = frames as f64 * capture.device_per_engine_frame();
            self.block_input_frame += advance.round() as u64;
            self.live = false;
            self.underruns += 1;
            return;
        }
        self.block_input_frame = capture.first_pending_device_frame();
        self.block[..samples].copy_from_slice(&capture.pending[..samples]);
        capture.pending.copy_within(samples..capture.pending_len, 0);
        capture.pending_len -= samples;
        capture.correct_drift(frames);
        self.live = true;
    }

    /// The whole captured block of every device channel, or `None` when it holds no input.
    pub fn block(&self, frames: usize) -> Option<&[f32]> {
        let samples = frames * self.device_channels();
        self.block.get(..samples).filter(|_| self.live)
    }

    /// Device frame the current block's first frame was captured as.
    pub fn block_input_frame(&self) -> u64 {
        self.block_input_frame
    }

    /// How much faster the input clock runs than the engine's, in parts per million.
    pub fn drift_ppm(&self) -> f64 {
        self.capture
            .as_ref()
            .map_or(0.0, |capture| capture.drift.drift_ppm())
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
            frame.get(first + 1).copied().unwrap_or(left)
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
    use super::{DriftController, InputCapture, InputSource, InputState, extract_source};

    fn state_with_ring(channels: usize, block: usize) -> (InputState, rtrb::Producer<f32>) {
        let (producer, consumer) = rtrb::RingBuffer::new(block * channels * 64);
        let capture = InputCapture::new(consumer, channels, 48_000, 48_000, block).unwrap();
        let mut state = InputState::default();
        state.attach(capture, block);
        (state, producer)
    }

    #[test]
    fn captured_blocks_carry_the_device_signal_per_channel() {
        let (mut state, mut producer) = state_with_ring(2, 64);
        let mut blocks = 0;
        for _ in 0..40 {
            while producer.slots() >= 2 {
                producer.push(0.25).unwrap();
                producer.push(-0.5).unwrap();
            }
            if !state.ready(64) {
                continue;
            }
            state.capture(64);
            blocks += 1;
            let (samples, live) = state.take(64);
            assert!(live);
            assert_eq!(samples.len(), 128);
        }
        assert!(blocks > 10);
        // Once the resampler's delay has passed, each channel holds its own level.
        let block = state.block(64).unwrap();
        assert!(
            block.chunks_exact(2).all(|frame| {
                (frame[0] - 0.25).abs() < 1.0e-3 && (frame[1] + 0.5).abs() < 1.0e-3
            })
        );
    }

    #[test]
    fn blocks_know_the_device_frame_they_start_at() {
        let (mut state, mut producer) = state_with_ring(1, 64);
        for _ in 0..4_096 {
            producer.push(0.0).unwrap();
        }
        // The resampler's delay reaches back before the stream's first frame at the start.
        for _ in 0..8 {
            state.capture(64);
        }
        let first = state.block_input_frame();
        assert!(first > 0);
        state.capture(64);
        assert_eq!(state.block_input_frame() - first, 64);
    }

    #[test]
    fn a_short_ring_renders_silent_input_and_counts_an_underrun() {
        let (mut state, mut producer) = state_with_ring(2, 4);
        producer.push(1.0).unwrap();
        assert!(!state.ready(4));
        state.capture(4);
        assert_eq!(state.underruns, 1);
        assert!(!state.take(4).1);
        assert!(state.block(4).is_none());
    }

    /// Runs `seconds` of a device whose clock runs `drift_ppm` fast against the engine,
    /// returning the controller and the backlog it ends with, in seconds.
    fn simulate_drift(drift_ppm: f64, seconds: f64) -> (DriftController, f64) {
        let block = 256.0 / 48_000.0;
        let mut controller = DriftController::default();
        let mut backlog = 0.02;
        let mut relative = 1.0;
        let mut time = 0.0;
        while time < seconds {
            // The device delivers faster by the drift; each block takes input at `1 / relative`.
            backlog += block * (1.0 + drift_ppm * 1.0e-6) - block / relative;
            // The callback sawtooth: the backlog is read at a random phase of a 10 ms period.
            let jitter = 0.005 * ((time * 977.0).sin());
            relative = controller.update(backlog + jitter, block);
            time += block;
        }
        (controller, backlog)
    }

    #[test]
    fn drift_correction_follows_a_fast_input_clock_and_holds_the_backlog() {
        let (controller, backlog) = simulate_drift(1_000.0, 300.0);
        assert!(
            (controller.drift_ppm() - 1_000.0).abs() < 50.0,
            "drift estimate {} ppm",
            controller.drift_ppm()
        );
        assert!(
            (backlog - 0.02).abs() < 0.005,
            "backlog wandered to {backlog}"
        );
    }

    #[test]
    fn drift_correction_stays_neutral_on_a_shared_clock() {
        let (controller, backlog) = simulate_drift(0.0, 120.0);
        assert!(controller.drift_ppm().abs() < 50.0);
        assert!((backlog - 0.02).abs() < 0.005);
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
        let mut past_the_last_channel = [0.0; 4];
        extract_source(
            &device,
            3,
            InputSource {
                first_channel: 2,
                channels: 2,
            },
            &mut past_the_last_channel,
        );
        assert_eq!(past_the_last_channel, [3.0, 3.0, 6.0, 6.0]);
    }
}
