//! Takes recorded from device input while the song plays.
//!
//! The control side hands the engine a [`RecordTake`] with the producer of a sample ring. Each
//! song block the engine copies the take's input channels from the captured device block into
//! that ring; a writer thread drains it into a file. The take's [`TakeShared`] tells the writer
//! where on the timeline the take starts and when it has ended.

use std::sync::{
    Arc,
    atomic::{AtomicBool, AtomicU64, Ordering},
};

use karbeat_core::shared::TrackId;
use rtrb::Producer;

use super::input::{InputSource, extract_source};

/// Takes the engine records at once.
pub const MAX_RECORD_TAKES: usize = 16;

/// Marks a start field the engine has not written yet.
const NOT_STARTED: u64 = u64::MAX;

/// State of one take shared between the engine and its writer. Written by the engine with
/// atomics only.
#[derive(Debug)]
pub struct TakeShared {
    /// Song playhead, in samples, of the first recorded frame.
    start_playhead: AtomicU64,
    /// Engine frame rendered in the block the take started in.
    start_render_frame: AtomicU64,
    /// Device input frame of the first recorded frame.
    start_input_frame: AtomicU64,
    /// Frames recorded so far.
    frames: AtomicU64,
    /// Frames lost because the ring was full.
    dropped_frames: AtomicU64,
    /// Whether the engine has stopped recording the take.
    ended: AtomicBool,
}

impl Default for TakeShared {
    fn default() -> Self {
        Self {
            start_playhead: AtomicU64::new(NOT_STARTED),
            start_render_frame: AtomicU64::new(NOT_STARTED),
            start_input_frame: AtomicU64::new(NOT_STARTED),
            frames: AtomicU64::new(0),
            dropped_frames: AtomicU64::new(0),
            ended: AtomicBool::new(false),
        }
    }
}

/// Where a take started, published once its first block is recorded.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct TakeStart {
    /// Song playhead, in samples, of the first recorded frame.
    pub playhead_samples: u64,
    /// Engine frame rendered in the block the take started in.
    pub render_frame: u64,
    /// Device input frame of the first recorded frame.
    pub input_frame: u64,
}

impl TakeShared {
    /// Where the take started, or `None` before its first recorded block.
    pub fn start(&self) -> Option<TakeStart> {
        // The playhead is stored last, so the other fields are visible once it is.
        let playhead_samples = self.start_playhead.load(Ordering::Acquire);
        (playhead_samples != NOT_STARTED).then(|| TakeStart {
            playhead_samples,
            render_frame: self.start_render_frame.load(Ordering::Relaxed),
            input_frame: self.start_input_frame.load(Ordering::Relaxed),
        })
    }

    /// Frames recorded so far.
    pub fn frames(&self) -> u64 {
        self.frames.load(Ordering::Acquire)
    }

    /// Frames lost because the writer fell behind.
    pub fn dropped_frames(&self) -> u64 {
        self.dropped_frames.load(Ordering::Relaxed)
    }

    /// Whether the engine has stopped recording; every recorded frame is in the ring by then.
    pub fn ended(&self) -> bool {
        self.ended.load(Ordering::Acquire)
    }

    fn end(&self) {
        self.ended.store(true, Ordering::Release);
    }
}

/// A take handed to the engine to record.
pub struct RecordTake {
    track_id: TrackId,
    source: InputSource,
    producer: Producer<f32>,
    shared: Arc<TakeShared>,
    /// Song playhead the next block must start at; any other playhead is a seek and ends the
    /// take.
    next_playhead: Option<u64>,
}

impl RecordTake {
    /// A take of `source` on `track_id` whose samples go to `producer`, interleaved with
    /// `source.channels` channels.
    pub fn new(
        track_id: TrackId,
        source: InputSource,
        producer: Producer<f32>,
        shared: Arc<TakeShared>,
    ) -> Self {
        Self {
            track_id,
            source,
            producer,
            shared,
            next_playhead: None,
        }
    }

    pub fn track_id(&self) -> TrackId {
        self.track_id
    }

    /// Ends the take; its producer stays alive until the engine retires it.
    pub(crate) fn end(&mut self) {
        self.shared.end();
    }

    fn channels(&self) -> usize {
        usize::from(self.source.channels.clamp(1, 2))
    }

    /// Pushes one block of `stereo` frames, or silence for `frames` frames when the input was
    /// not captured. Real-time safe.
    fn push(&mut self, stereo: Option<&[f32]>, frames: usize) {
        let channels = self.channels();
        let samples = frames * channels;
        let Ok(mut chunk) = self.producer.write_chunk(samples) else {
            self.shared
                .dropped_frames
                .fetch_add(frames as u64, Ordering::Relaxed);
            return;
        };
        let (first, second) = chunk.as_mut_slices();
        let mut written = first.iter_mut().chain(second.iter_mut());
        match stereo {
            Some(stereo) => {
                for frame in stereo.as_chunks::<2>().0.iter().take(frames) {
                    for sample in &frame[..channels] {
                        if let Some(slot) = written.next() {
                            *slot = *sample;
                        }
                    }
                }
            }
            None => written.for_each(|slot| *slot = 0.0),
        }
        chunk.commit_all();
    }
}

#[cfg(test)]
impl RecordTake {
    /// Pushes `frames` stereo frames as the engine would.
    pub(crate) fn push_for_test(&mut self, stereo: &[f32], frames: usize) {
        self.push(Some(stereo), frames);
        self.shared
            .frames
            .fetch_add(frames as u64, Ordering::Release);
    }

    /// Publishes `start` as the engine does after the first block.
    pub(crate) fn start_for_test(&self, start: TakeStart) {
        self.shared
            .start_render_frame
            .store(start.render_frame, Ordering::Relaxed);
        self.shared
            .start_input_frame
            .store(start.input_frame, Ordering::Relaxed);
        self.shared
            .start_playhead
            .store(start.playhead_samples, Ordering::Release);
    }
}

/// Takes being recorded and the scratch block they are copied through.
pub(super) struct RecordState {
    /// Boxed as they arrive in commands, so retiring one never allocates.
    #[allow(
        clippy::vec_box,
        reason = "takes are retired as the boxes their commands carried"
    )]
    takes: Vec<Box<RecordTake>>,
    /// One stereo block of a take's input.
    scratch: Vec<f32>,
}

impl Default for RecordState {
    fn default() -> Self {
        Self::with_block(0)
    }
}

/// Where the block being recorded sits.
pub(super) struct RecordBlock<'a> {
    /// Every device channel of the block, interleaved, or `None` when input was not captured.
    pub device: Option<&'a [f32]>,
    pub device_channels: usize,
    pub frames: usize,
    pub playhead_samples: u64,
    pub render_frame: u64,
    /// Device input frame of the block's first frame.
    pub input_frame: u64,
}

impl RecordState {
    /// Room for every take and a scratch block of `block_frames`. Allocates.
    pub fn with_block(block_frames: usize) -> Self {
        Self {
            takes: Vec::with_capacity(MAX_RECORD_TAKES),
            scratch: vec![0.0; block_frames * 2],
        }
    }

    /// Sizes the scratch block for `block_frames`. Allocates; call from setup.
    pub fn prepare(&mut self, block_frames: usize) {
        self.scratch.resize(block_frames * 2, 0.0);
    }

    /// Whether any take is waiting for or recording audio.
    pub fn is_armed(&self) -> bool {
        !self.takes.is_empty()
    }

    /// Whether a take has started recording audio.
    pub fn is_capturing(&self) -> bool {
        self.takes.iter().any(|take| take.next_playhead.is_some())
    }

    /// Adds `take`, returning it back when the engine already records that track or holds as
    /// many takes as it can.
    pub fn start(&mut self, take: Box<RecordTake>) -> Result<(), Box<RecordTake>> {
        if self.takes.len() >= MAX_RECORD_TAKES
            || self.takes.iter().any(|held| held.track_id == take.track_id)
        {
            return Err(take);
        }
        self.takes.push(take);
        Ok(())
    }

    /// Ends and removes the take of `track_id`, so it can be retired off the audio thread.
    pub fn end(&mut self, track_id: TrackId) -> Option<Box<RecordTake>> {
        let index = self
            .takes
            .iter()
            .position(|take| take.track_id == track_id)?;
        let mut take = self.takes.swap_remove(index);
        take.end();
        Some(take)
    }

    /// Ends every take that started recording, because the song stopped. Takes still waiting
    /// for playback keep waiting.
    pub fn end_started(&mut self, mut retire: impl FnMut(Box<RecordTake>)) {
        let mut index = 0;
        while index < self.takes.len() {
            if self.takes[index].next_playhead.is_some() {
                let mut take = self.takes.swap_remove(index);
                take.end();
                retire(take);
            } else {
                index += 1;
            }
        }
    }

    /// Records one song block into every take. A take whose playhead jumped since its last
    /// block was seeked, so it ends and is handed to `retire`. Real-time safe.
    pub fn record(&mut self, block: &RecordBlock<'_>, mut retire: impl FnMut(Box<RecordTake>)) {
        let samples = block.frames * 2;
        let mut index = 0;
        while index < self.takes.len() {
            let take = &mut self.takes[index];
            if take
                .next_playhead
                .is_some_and(|expected| expected != block.playhead_samples)
            {
                let mut take = self.takes.swap_remove(index);
                take.end();
                retire(take);
                continue;
            }
            let stereo = match (block.device, self.scratch.get_mut(..samples)) {
                (Some(device), Some(scratch)) => {
                    extract_source(device, block.device_channels, take.source, scratch);
                    Some(&*scratch)
                }
                _ => None,
            };
            take.push(stereo, block.frames);
            if take.next_playhead.is_none() {
                let shared = &take.shared;
                shared
                    .start_render_frame
                    .store(block.render_frame, Ordering::Relaxed);
                shared
                    .start_input_frame
                    .store(block.input_frame, Ordering::Relaxed);
                shared
                    .start_playhead
                    .store(block.playhead_samples, Ordering::Release);
            }
            take.shared
                .frames
                .fetch_add(block.frames as u64, Ordering::Release);
            take.next_playhead = Some(block.playhead_samples + block.frames as u64);
            index += 1;
        }
    }
}

#[cfg(test)]
#[allow(
    clippy::unwrap_used,
    clippy::panic,
    reason = "record tests fail immediately when a fixture cannot be built"
)]
mod tests {
    use super::*;

    fn track(id: u32) -> TrackId {
        TrackId::from(id)
    }

    fn take(channels: u16) -> (Box<RecordTake>, rtrb::Consumer<f32>, Arc<TakeShared>) {
        let (producer, consumer) = rtrb::RingBuffer::new(64);
        let shared = Arc::new(TakeShared::default());
        let take = RecordTake::new(
            track(1),
            InputSource {
                first_channel: 1,
                channels,
            },
            producer,
            Arc::clone(&shared),
        );
        (Box::new(take), consumer, shared)
    }

    fn block(device: &[f32], playhead: u64) -> RecordBlock<'_> {
        RecordBlock {
            device: Some(device),
            device_channels: 3,
            frames: device.len() / 3,
            playhead_samples: playhead,
            render_frame: 1_000 + playhead,
            input_frame: 500 + playhead,
        }
    }

    fn drain(consumer: &mut rtrb::Consumer<f32>) -> Vec<f32> {
        std::iter::from_fn(|| consumer.pop().ok()).collect()
    }

    #[test]
    fn a_take_records_its_channels_and_publishes_where_it_started() {
        let mut state = RecordState::default();
        state.prepare(4);
        let (take, mut consumer, shared) = take(2);
        assert!(state.start(take).is_ok());
        assert!(shared.start().is_none());

        let device = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0];
        state.record(&block(&device, 96), |_| panic!("the take must not end"));

        assert_eq!(drain(&mut consumer), [2.0, 3.0, 5.0, 6.0]);
        assert_eq!(
            shared.start(),
            Some(TakeStart {
                playhead_samples: 96,
                render_frame: 1_096,
                input_frame: 596,
            })
        );
        assert_eq!(shared.frames(), 2);
        assert!(state.is_capturing());
    }

    #[test]
    fn mono_takes_record_one_channel() {
        let mut state = RecordState::default();
        state.prepare(4);
        let (take, mut consumer, _) = take(1);
        assert!(state.start(take).is_ok());
        state.record(&block(&[1.0, 2.0, 3.0, 4.0, 5.0, 6.0], 0), |_| {});
        assert_eq!(drain(&mut consumer), [2.0, 5.0]);
    }

    #[test]
    fn a_seek_ends_the_take() {
        let mut state = RecordState::default();
        state.prepare(4);
        let (take, _consumer, shared) = take(2);
        assert!(state.start(take).is_ok());
        let device = [0.0; 6];
        state.record(&block(&device, 0), |_| {});
        state.record(&block(&device, 2), |_| {});
        let mut retired = 0;
        state.record(&block(&device, 100), |_| retired += 1);
        assert_eq!(retired, 1);
        assert!(shared.ended());
        assert_eq!(shared.frames(), 4);
        assert!(!state.is_armed());
    }

    #[test]
    fn stopping_ends_only_started_takes() {
        let mut state = RecordState::default();
        state.prepare(4);
        let (waiting, _, waiting_shared) = take(2);
        assert!(state.start(waiting).is_ok());
        let mut retired = 0;
        state.end_started(|_| retired += 1);
        assert_eq!(retired, 0);
        assert!(!waiting_shared.ended());

        state.record(&block(&[0.0; 6], 0), |_| {});
        state.end_started(|_| retired += 1);
        assert_eq!(retired, 1);
        assert!(waiting_shared.ended());
    }

    #[test]
    fn a_full_ring_counts_dropped_frames_and_silence_fills_missing_input() {
        let (producer, mut consumer) = rtrb::RingBuffer::new(4);
        let shared = Arc::new(TakeShared::default());
        let mut state = RecordState::default();
        state.prepare(2);
        let take = RecordTake::new(
            track(1),
            InputSource {
                first_channel: 0,
                channels: 2,
            },
            producer,
            Arc::clone(&shared),
        );
        assert!(state.start(Box::new(take)).is_ok());
        let silent = RecordBlock {
            device: None,
            device_channels: 2,
            frames: 2,
            playhead_samples: 0,
            render_frame: 0,
            input_frame: 0,
        };
        state.record(&silent, |_| {});
        assert_eq!(drain(&mut consumer), [0.0; 4]);
        state.record(
            &RecordBlock {
                playhead_samples: 2,
                ..silent
            },
            |_| {},
        );
        state.record(
            &RecordBlock {
                playhead_samples: 4,
                ..silent
            },
            |_| {},
        );
        assert_eq!(shared.dropped_frames(), 2);
    }
}
