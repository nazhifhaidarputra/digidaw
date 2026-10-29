//! Shows transport feedback when its audio is heard, not when it is rendered.
//!
//! The DSP thread renders ahead of the device: output waits in the device ring, the rate
//! bridge, and the device's own buffer before it reaches the speakers. Feedback emitted at
//! render time therefore leads the sound. The device callback publishes which frames it is
//! playing and when they reach the hardware on an [`OutputClock`]. [`PlayheadSync`] holds each
//! feedback until the clock reaches the frame it was rendered at.

use std::{
    collections::VecDeque,
    sync::{
        Arc,
        atomic::{AtomicBool, AtomicU64, Ordering, fence},
    },
    time::{Duration, Instant},
};

use karbeat_core::core::project::TickScale;
use parking_lot::Mutex;
use rtrb::Consumer;

use crate::event::{FeedbackTiming, TransportFeedback};

/// How the frames of one device stream map to engine frames.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct OutputEpoch {
    /// Engine frame rendered into the stream's first device frame.
    pub engine_frame: u64,
    /// Engine sample rate.
    pub dsp_rate: u32,
    /// Device sample rate.
    pub device_rate: u32,
    /// Device frames by which the rate bridge delays the engine output.
    pub bridge_delay_frames: u64,
}

/// Which device frame is playing now, published by the device callback.
///
/// The callback writes with atomics only. The epoch lock is taken by the DSP thread when it
/// attaches or detaches a stream and by the feedback relay, never by the callback or the render
/// loop.
pub struct OutputClock {
    origin: Instant,
    /// The latest callback: device frames consumed before it, frames it consumed (not
    /// counting underrun silence), and when its first frame reaches the hardware.
    latest: CallbackRecord,
    /// Device frames the stream consumed in total.
    consumed_frames: AtomicU64,
    /// Whether the attached stream has run a callback yet.
    started: AtomicBool,
    epoch: Mutex<Option<OutputEpoch>>,
}

impl Default for OutputClock {
    fn default() -> Self {
        Self::new()
    }
}

impl OutputClock {
    pub fn new() -> Self {
        Self {
            origin: Instant::now(),
            latest: CallbackRecord::default(),
            consumed_frames: AtomicU64::new(0),
            started: AtomicBool::new(false),
            epoch: Mutex::new(None),
        }
    }

    /// Starts counting a new device stream. Call before the stream runs its first callback.
    pub fn attach(&self, epoch: OutputEpoch) {
        self.started.store(false, Ordering::Release);
        self.consumed_frames.store(0, Ordering::Relaxed);
        *self.epoch.lock() = Some(epoch);
    }

    /// Stops mapping frames after the device stream was dropped.
    pub fn detach(&self) {
        *self.epoch.lock() = None;
        self.started.store(false, Ordering::Release);
    }

    /// Records a device callback that consumed `frames` engine frames at `now`, whose first
    /// frame reaches the hardware `playback_delay` later. Real-time safe.
    pub fn record_callback(&self, now: Instant, frames: usize, playback_delay: Duration) {
        let first_frame = self.consumed_frames.load(Ordering::Relaxed);
        let playback_at = nanos_since(self.origin, now)
            .saturating_add(u64::try_from(playback_delay.as_nanos()).unwrap_or(u64::MAX));
        self.latest.publish(first_frame, frames as u64, playback_at);
        self.consumed_frames
            .store(first_frame + frames as u64, Ordering::Relaxed);
        self.started.store(true, Ordering::Release);
    }

    /// The engine frame being heard at `now`, or `None` while no stream is playing.
    pub fn heard_engine_frame(&self, now: Instant) -> Option<u64> {
        let epoch = (*self.epoch.lock())?;
        if !self.started.load(Ordering::Acquire) || epoch.device_rate == 0 {
            return None;
        }
        let (first_frame, frames, playback_at) = self.latest.read();

        // Frames before the latest callback's first one are still playing until it lands;
        // frames it has not received yet (an underrun) cannot be heard.
        let elapsed_nanos = i128::from(nanos_since(self.origin, now)) - i128::from(playback_at);
        let elapsed_frames = elapsed_nanos * i128::from(epoch.device_rate) / 1_000_000_000;
        let heard_device = (i128::from(first_frame) + elapsed_frames)
            .clamp(0, i128::from(first_frame + frames)) as u64;

        let heard_bridged = heard_device.saturating_sub(epoch.bridge_delay_frames);
        let heard_engine =
            u128::from(heard_bridged) * u128::from(epoch.dsp_rate) / u128::from(epoch.device_rate);
        Some(epoch.engine_frame + u64::try_from(heard_engine).unwrap_or(u64::MAX))
    }
}

/// The latest device callback, published with a seqlock so the callback never waits: the
/// device frames before it, its frame count, and when its first frame met the hardware, in
/// nanoseconds since the clock's origin.
#[derive(Default)]
struct CallbackRecord {
    /// Odd while the callback is writing.
    sequence: AtomicU64,
    first_frame: AtomicU64,
    frames: AtomicU64,
    at_nanos: AtomicU64,
}

impl CallbackRecord {
    /// Real-time safe; only the device callback publishes.
    fn publish(&self, first_frame: u64, frames: u64, at_nanos: u64) {
        let sequence = self.sequence.load(Ordering::Relaxed);
        self.sequence
            .store(sequence.wrapping_add(1), Ordering::Relaxed);
        fence(Ordering::Release);
        self.first_frame.store(first_frame, Ordering::Relaxed);
        self.frames.store(frames, Ordering::Relaxed);
        self.at_nanos.store(at_nanos, Ordering::Relaxed);
        self.sequence
            .store(sequence.wrapping_add(2), Ordering::Release);
    }

    fn read(&self) -> (u64, u64, u64) {
        loop {
            let before = self.sequence.load(Ordering::Acquire);
            if before % 2 == 1 {
                std::hint::spin_loop();
                continue;
            }
            let values = (
                self.first_frame.load(Ordering::Relaxed),
                self.frames.load(Ordering::Relaxed),
                self.at_nanos.load(Ordering::Relaxed),
            );
            fence(Ordering::Acquire);
            if self.sequence.load(Ordering::Relaxed) == before {
                return values;
            }
        }
    }
}

fn nanos_since(origin: Instant, instant: Instant) -> u64 {
    u64::try_from(instant.saturating_duration_since(origin).as_nanos()).unwrap_or(u64::MAX)
}

/// When device input was captured, published by the input callback, so a recording can be
/// placed on the timeline where it was played.
pub struct InputClock {
    origin: Instant,
    /// The latest callback: frames captured before it, frames it delivered, and when its
    /// first frame was captured.
    latest: CallbackRecord,
    /// Frames captured in total.
    captured_frames: AtomicU64,
    started: AtomicBool,
}

impl Default for InputClock {
    fn default() -> Self {
        Self::new()
    }
}

impl InputClock {
    pub fn new() -> Self {
        Self {
            origin: Instant::now(),
            latest: CallbackRecord::default(),
            captured_frames: AtomicU64::new(0),
            started: AtomicBool::new(false),
        }
    }

    /// Starts counting a new input stream. Call before the stream runs its first callback.
    pub fn reset(&self) {
        self.started.store(false, Ordering::Release);
        self.captured_frames.store(0, Ordering::Relaxed);
    }

    /// Records an input callback at `now` that delivered `frames` frames, the first of which
    /// was captured `capture_delay` earlier. Real-time safe.
    pub fn record_callback(&self, now: Instant, frames: usize, capture_delay: Duration) {
        let first_frame = self.captured_frames.load(Ordering::Relaxed);
        let captured_at = nanos_since(self.origin, now)
            .saturating_sub(u64::try_from(capture_delay.as_nanos()).unwrap_or(u64::MAX));
        self.latest.publish(first_frame, frames as u64, captured_at);
        self.captured_frames
            .store(first_frame + frames as u64, Ordering::Relaxed);
        self.started.store(true, Ordering::Release);
    }

    /// When input frame `frame` of the stream was, or will be, captured at `device_rate`, or
    /// `None` before the stream's first callback.
    pub fn captured_at(&self, frame: u64, device_rate: u32) -> Option<Instant> {
        if !self.started.load(Ordering::Acquire) || device_rate == 0 {
            return None;
        }
        let (first_frame, _, captured_at) = self.latest.read();
        let offset_nanos =
            (i128::from(frame) - i128::from(first_frame)) * 1_000_000_000 / i128::from(device_rate);
        let nanos = (i128::from(captured_at) + offset_nanos).max(0) as u64;
        Some(self.origin + Duration::from_nanos(nanos))
    }
}

/// Relays transport feedback to the UI at the moment its audio is heard.
pub struct PlayheadSync {
    consumer: Consumer<TransportFeedback>,
    clock: Arc<OutputClock>,
    /// Feedback rendered but not heard yet, oldest first.
    pending: VecDeque<TransportFeedback>,
    /// Latest feedback whose audio has been heard.
    current: Option<TransportFeedback>,
    last_shown: Option<TransportFeedback>,
}

impl PlayheadSync {
    pub fn new(consumer: Consumer<TransportFeedback>, clock: Arc<OutputClock>) -> Self {
        Self {
            consumer,
            clock,
            pending: VecDeque::with_capacity(128),
            current: None,
            last_shown: None,
        }
    }

    /// Returns the engine's feedback ring, so a later relay can take it over.
    pub fn into_consumer(self) -> Consumer<TransportFeedback> {
        self.consumer
    }

    /// The transport position heard at `now`, when it changed since the last call.
    ///
    /// While playing, the position is advanced from the latest heard feedback to `now`, so it
    /// moves smoothly between the engine's feedback updates.
    pub fn poll(&mut self, now: Instant) -> Option<TransportFeedback> {
        while let Ok(feedback) = self.consumer.pop() {
            match feedback.timing {
                FeedbackTiming::Immediate => {
                    self.pending.clear();
                    self.current = Some(feedback);
                }
                FeedbackTiming::Audible => self.pending.push_back(feedback),
            }
        }

        // Without a playing stream nothing can be heard, so feedback passes straight through.
        let heard = self.clock.heard_engine_frame(now);
        while let Some(next) = self.pending.front() {
            if heard.is_some_and(|heard| next.render_frame > heard) {
                break;
            }
            self.current = self.pending.pop_front();
        }

        let mut shown = self.current?;
        if let Some(heard) = heard {
            advance_to_heard(&mut shown, heard, self.pending.front());
        }
        if self.last_shown == Some(shown) {
            return None;
        }
        self.last_shown = Some(shown);
        Some(shown)
    }
}

/// Moves a playing `feedback` forward to the `heard` frame, by at most one feedback interval.
/// A `next` feedback that jumps backwards is a loop wrap at an unknown frame, so the position
/// is not advanced towards it.
fn advance_to_heard(
    feedback: &mut TransportFeedback,
    heard: u64,
    next: Option<&TransportFeedback>,
) {
    if !feedback.is_playing || feedback.sample_rate == 0 {
        return;
    }
    let position = |feedback: &TransportFeedback| {
        if feedback.is_pattern_mode {
            feedback.pattern_samples
        } else {
            feedback.samples
        }
    };
    if next.is_some_and(|next| position(next) < position(feedback)) {
        return;
    }

    let interval = u64::from(feedback.sample_rate / 60);
    let ahead = heard.saturating_sub(feedback.render_frame).min(interval) as u32;
    if ahead == 0 {
        return;
    }
    let scale = TickScale::new(feedback.tempo, feedback.sample_rate);
    let to_ticks =
        |samples: u32| u32::try_from(scale.to_ticks(u64::from(samples))).unwrap_or(u32::MAX);
    if feedback.is_pattern_mode {
        feedback.pattern_samples = feedback.pattern_samples.saturating_add(ahead);
        feedback.pattern_ticks = to_ticks(feedback.pattern_samples);
    } else {
        feedback.samples = feedback.samples.saturating_add(ahead);
        feedback.ticks = to_ticks(feedback.samples);
    }
}

#[cfg(test)]
#[allow(
    clippy::unwrap_used,
    reason = "fixture rings have room for every pushed feedback"
)]
mod tests {
    use super::*;
    use rtrb::{Producer, RingBuffer};

    const RATE: u32 = 48_000;

    fn epoch(engine_frame: u64) -> OutputEpoch {
        OutputEpoch {
            engine_frame,
            dsp_rate: RATE,
            device_rate: RATE,
            bridge_delay_frames: 0,
        }
    }

    fn feedback(samples: u32, render_frame: u64, timing: FeedbackTiming) -> TransportFeedback {
        TransportFeedback {
            samples,
            ticks: 0,
            beat: 1,
            bar: 1,
            tempo: 120.0,
            sample_rate: RATE,
            is_playing: true,
            is_looping: false,
            is_recording: false,
            is_pattern_playing: false,
            is_pattern_mode: false,
            pattern_samples: 0,
            pattern_ticks: 0,
            pattern_beat: 1,
            pattern_bar: 1,
            render_frame,
            timing,
        }
    }

    fn relay(clock: &Arc<OutputClock>) -> (Producer<TransportFeedback>, PlayheadSync) {
        let (producer, consumer) = RingBuffer::new(64);
        (producer, PlayheadSync::new(consumer, Arc::clone(clock)))
    }

    fn after(origin: Instant, millis: u64) -> Instant {
        origin + Duration::from_millis(millis)
    }

    #[test]
    fn heard_frame_follows_the_device_playback_time() {
        let clock = OutputClock::new();
        let origin = Instant::now();
        assert_eq!(clock.heard_engine_frame(origin), None);

        clock.attach(epoch(1_000));
        assert_eq!(clock.heard_engine_frame(origin), None, "no callback yet");

        // 480 frames consumed at +10 ms reach the DAC 20 ms later.
        clock.record_callback(after(origin, 10), 480, Duration::from_millis(20));
        let playback_at = after(origin, 30);
        assert_eq!(clock.heard_engine_frame(playback_at), Some(1_000));
        assert_eq!(
            clock.heard_engine_frame(playback_at + Duration::from_millis(5)),
            Some(1_240)
        );
        // Frames the device has not received cannot be heard, even long after.
        assert_eq!(
            clock.heard_engine_frame(playback_at + Duration::from_secs(1)),
            Some(1_480)
        );

        clock.detach();
        assert_eq!(clock.heard_engine_frame(playback_at), None);
    }

    #[test]
    fn heard_frame_removes_the_bridge_delay_and_converts_the_rate() {
        let clock = OutputClock::new();
        let origin = Instant::now();
        clock.attach(OutputEpoch {
            engine_frame: 0,
            dsp_rate: 48_000,
            device_rate: 96_000,
            bridge_delay_frames: 200,
        });
        clock.record_callback(origin, 0, Duration::ZERO);
        clock.record_callback(origin, 2_000, Duration::ZERO);
        // 12.5 ms in, device frame 1_200 is bridge output 1_000, which is engine frame 500.
        assert_eq!(
            clock.heard_engine_frame(origin + Duration::from_micros(12_500)),
            Some(500)
        );
    }

    #[test]
    fn feedback_waits_until_its_frame_is_heard() {
        let clock = Arc::new(OutputClock::new());
        let origin = Instant::now();
        clock.attach(epoch(0));
        clock.record_callback(origin, 48_000, Duration::from_millis(100));
        let (mut producer, mut sync) = relay(&clock);

        producer
            .push(feedback(1_000, 1_000, FeedbackTiming::Audible))
            .unwrap();
        // Engine frame 1_000 is heard 100 ms + 1_000 frames after the callback.
        assert_eq!(sync.poll(after(origin, 100)), None);
        let shown = sync.poll(after(origin, 121)).unwrap();
        assert_eq!(shown.samples, 1_008, "advanced to the heard frame");
        assert_eq!(
            sync.poll(after(origin, 121)),
            None,
            "unchanged positions are not resent"
        );
    }

    #[test]
    fn immediate_feedback_replaces_what_is_not_heard_yet() {
        let clock = Arc::new(OutputClock::new());
        let origin = Instant::now();
        clock.attach(epoch(0));
        clock.record_callback(origin, 48_000, Duration::from_millis(100));
        let (mut producer, mut sync) = relay(&clock);

        producer
            .push(feedback(5_000, 5_000, FeedbackTiming::Audible))
            .unwrap();
        producer
            .push(TransportFeedback {
                is_playing: false,
                ..feedback(0, 6_000, FeedbackTiming::Immediate)
            })
            .unwrap();
        let shown = sync.poll(origin).unwrap();
        assert_eq!((shown.samples, shown.is_playing), (0, false));
        // The replaced feedback never shows, even once its frame is heard.
        assert_eq!(sync.poll(after(origin, 500)), None);
    }

    #[test]
    fn feedback_passes_through_without_a_stream() {
        let clock = Arc::new(OutputClock::new());
        let (mut producer, mut sync) = relay(&clock);
        producer
            .push(feedback(9_000, 9_000, FeedbackTiming::Audible))
            .unwrap();
        assert_eq!(sync.poll(Instant::now()).unwrap().samples, 9_000);
    }

    #[test]
    fn advance_is_capped_and_stops_before_a_loop_wrap() {
        let mut shown = feedback(10_000, 10_000, FeedbackTiming::Audible);
        advance_to_heard(&mut shown, 50_000, None);
        assert_eq!(shown.samples, 10_800, "at most one feedback interval");
        assert_eq!(shown.ticks, 432, "25 samples per tick at 120 BPM");

        let mut shown = feedback(10_000, 10_000, FeedbackTiming::Audible);
        let wrapped = feedback(100, 10_900, FeedbackTiming::Audible);
        advance_to_heard(&mut shown, 10_500, Some(&wrapped));
        assert_eq!(shown.samples, 10_000);

        let mut stopped = TransportFeedback {
            is_playing: false,
            ..feedback(10_000, 10_000, FeedbackTiming::Audible)
        };
        advance_to_heard(&mut stopped, 10_500, None);
        assert_eq!(stopped.samples, 10_000);
    }

    #[test]
    fn input_frames_map_to_their_capture_time() {
        let clock = InputClock::new();
        let origin = clock.origin;
        assert_eq!(clock.captured_at(0, 48_000), None);
        // The first callback delivers 480 frames captured 10 ms before it ran.
        clock.record_callback(after(origin, 30), 480, Duration::from_millis(10));
        assert_eq!(clock.captured_at(0, 48_000), Some(after(origin, 20)));
        // The second delivers the next 480, each a 48th of a millisecond later.
        clock.record_callback(after(origin, 40), 480, Duration::from_millis(10));
        assert_eq!(clock.captured_at(480, 48_000), Some(after(origin, 30)));
        assert_eq!(clock.captured_at(960, 48_000), Some(after(origin, 40)));
        clock.reset();
        assert_eq!(clock.captured_at(0, 48_000), None);
    }
}
