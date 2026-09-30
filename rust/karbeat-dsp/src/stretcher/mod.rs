//! Time stretching and pitch shifting via the Rubber Band Library.
//!
//! [`stretch_offline`] wraps `RubberBandStretcher` in offline mode: the whole input is studied
//! first, then processed, which gives the best quality and allows a key-frame map that pins
//! chosen input frames (such as detected beats) to exact output frames. Not real-time safe;
//! run it on a background worker.
//!
//! [`stretch_offline_parallel`] splits long input into chunks stretched in parallel.
//!
//! [`RealtimeStretcher`] wraps it in real-time mode for the audio engine: the time ratio can
//! change at any time, and processing does not allocate once created.

#![allow(
    clippy::as_conversions,
    reason = "the Rubber Band C ABI requires explicit numeric and pointer representation conversions"
)]

use std::{fmt, ptr::NonNull};

use crate::pitch_shift::ffi;

mod parallel;

pub use parallel::{PARALLEL_MIN_SECONDS, stretch_offline_parallel};

/// Frames handed to Rubber Band per call.
const BLOCK_FRAMES: usize = 4096;
/// Share of the progress range spent in the study pass; processing takes the rest.
const STUDY_WEIGHT: f32 = 0.2;
/// Highest channel count accepted, matching the pointer arrays passed to the C API.
const MAX_CHANNELS: usize = 8;

/// One offline stretch of interleaved audio.
#[derive(Clone, Copy, Debug)]
pub struct OfflineStretch<'a> {
    pub sample_rate: u32,
    pub channels: usize,
    /// Interleaved input samples; the length must be a multiple of `channels`.
    pub input: &'a [f32],
    /// Output length divided by input length; `1.0` keeps the duration.
    pub time_ratio: f64,
    /// Frequency multiplier; `1.0` keeps the pitch.
    pub pitch_scale: f64,
    /// Preserve the spectral envelope when shifting pitch, for voices and instruments.
    pub preserve_formants: bool,
    /// Optional `(input_frame, output_frame)` pairs, strictly increasing in both frames,
    /// that pin input frames to exact output frames. Empty for a constant ratio.
    pub key_frames: &'a [(usize, usize)],
}

/// Why an offline stretch did not complete.
#[derive(Debug, Clone, PartialEq)]
pub enum StretchError {
    /// The cancellation check returned `true`.
    Cancelled,
    /// The request cannot be processed.
    InvalidInput(&'static str),
    /// Rubber Band could not create a stretcher.
    Unavailable,
}

impl fmt::Display for StretchError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Cancelled => f.write_str("time stretch was cancelled"),
            Self::InvalidInput(reason) => write!(f, "invalid time stretch request: {reason}"),
            Self::Unavailable => f.write_str("the Rubber Band stretcher could not be created"),
        }
    }
}

impl std::error::Error for StretchError {}

/// Owned offline `RubberBandStretcher`, deleted on drop.
struct RbStretcher {
    state: NonNull<ffi::RubberBandState_>,
}

impl RbStretcher {
    fn new(request: &OfflineStretch<'_>, frames: u32) -> Result<Self, StretchError> {
        let mut options = ffi::RubberBandOption_RubberBandOptionProcessOffline
            | ffi::RubberBandOption_RubberBandOptionEngineFiner;
        if request.channels > 1 {
            options |= ffi::RubberBandOption_RubberBandOptionChannelsTogether;
        }
        if (request.pitch_scale - 1.0).abs() > f64::EPSILON {
            options |= ffi::RubberBandOption_RubberBandOptionPitchHighQuality;
            if request.preserve_formants {
                options |= ffi::RubberBandOption_RubberBandOptionFormantPreserved;
            }
        }
        // SAFETY: Arguments satisfy the C API contract; ownership of the returned state is
        // transferred to this wrapper.
        let raw = unsafe {
            ffi::rubberband_new(
                request.sample_rate,
                request.channels as u32,
                options as _,
                request.time_ratio,
                request.pitch_scale,
            )
        };
        let state = NonNull::new(raw).ok_or(StretchError::Unavailable)?;
        let stretcher = Self { state };
        // SAFETY: `state` is a live stretcher owned by this wrapper.
        unsafe {
            ffi::rubberband_set_expected_input_duration(stretcher.state.as_ptr(), frames);
        }
        // SAFETY: As above.
        unsafe {
            ffi::rubberband_set_max_process_size(stretcher.state.as_ptr(), BLOCK_FRAMES as u32);
        }
        Ok(stretcher)
    }

    fn set_key_frames(&self, from: &mut [u32], to: &mut [u32]) {
        // SAFETY: Both slices hold `from.len()` entries, and Rubber Band copies the map.
        unsafe {
            ffi::rubberband_set_key_frame_map(
                self.state.as_ptr(),
                from.len() as u32,
                from.as_mut_ptr(),
                to.as_mut_ptr(),
            );
        }
    }

    fn study(&self, channels: &[*const f32], frames: usize, last: bool) {
        // SAFETY: Each pointer addresses at least `frames` samples, and Rubber Band does not
        // retain them.
        unsafe {
            ffi::rubberband_study(
                self.state.as_ptr(),
                channels.as_ptr(),
                frames as u32,
                i32::from(last),
            );
        }
    }

    fn process(&self, channels: &[*const f32], frames: usize, last: bool) {
        // SAFETY: As in `study`.
        unsafe {
            ffi::rubberband_process(
                self.state.as_ptr(),
                channels.as_ptr(),
                frames as u32,
                i32::from(last),
            );
        }
    }

    /// Frames ready to retrieve, or `None` once all output has been retrieved.
    fn available(&self) -> Option<usize> {
        // SAFETY: `self.state` is valid until drop.
        let available = unsafe { ffi::rubberband_available(self.state.as_ptr()) };
        usize::try_from(available).ok()
    }

    fn retrieve(&self, channels: &[*mut f32], frames: usize) -> usize {
        // SAFETY: Each pointer addresses at least `frames` writable samples.
        unsafe {
            ffi::rubberband_retrieve(self.state.as_ptr(), channels.as_ptr(), frames as u32) as usize
        }
    }
}

impl Drop for RbStretcher {
    fn drop(&mut self) {
        // SAFETY: This wrapper owns the state and `drop` runs exactly once.
        unsafe { ffi::rubberband_delete(self.state.as_ptr()) }
    }
}

/// The first `channels` pointers; `channels` is validated to be at most [`MAX_CHANNELS`].
fn active<T>(pointers: &[T; MAX_CHANNELS], channels: usize) -> &[T] {
    pointers.get(..channels).unwrap_or(pointers)
}

/// Pitch-preserving real-time time stretcher for stereo audio.
///
/// Create it off the real-time path. Afterwards, [`Self::process`] with at most
/// `max_process_frames` frames, [`Self::retrieve`], [`Self::set_time_ratio`] and
/// [`Self::reset`] do not allocate.
pub struct RealtimeStretcher {
    state: NonNull<ffi::RubberBandState_>,
    time_ratio: f64,
    max_process_frames: usize,
}

impl fmt::Debug for RealtimeStretcher {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("RealtimeStretcher")
            .field("time_ratio", &self.time_ratio)
            .finish()
    }
}

// SAFETY: The stretcher is an opaque heap object that Rubber Band allows on any thread as long
// as calls are not concurrent; every method takes `&mut self` or only reads through `&self`.
unsafe impl Send for RealtimeStretcher {}

/// Channels a [`RealtimeStretcher`] processes: the engine's stereo output.
pub const REALTIME_CHANNELS: usize = 2;

impl RealtimeStretcher {
    /// A stretcher at `sample_rate` that accepts up to `max_process_frames` per call.
    pub fn new(sample_rate: u32, max_process_frames: usize) -> Result<Self, StretchError> {
        let options = ffi::RubberBandOption_RubberBandOptionProcessRealTime
            | ffi::RubberBandOption_RubberBandOptionEngineFiner
            | ffi::RubberBandOption_RubberBandOptionChannelsTogether;
        // SAFETY: Arguments satisfy the C API contract; ownership of the returned state is
        // transferred to this wrapper.
        let raw = unsafe {
            ffi::rubberband_new(
                sample_rate,
                REALTIME_CHANNELS as u32,
                options as _,
                1.0,
                1.0,
            )
        };
        let state = NonNull::new(raw).ok_or(StretchError::Unavailable)?;
        let max_process_frames = max_process_frames.max(1);
        // SAFETY: `state` is a live stretcher owned by this wrapper.
        unsafe {
            ffi::rubberband_set_max_process_size(state.as_ptr(), max_process_frames as u32);
        }
        Ok(Self {
            state,
            time_ratio: 1.0,
            max_process_frames,
        })
    }

    /// Largest frame count one [`Self::process`] call accepts.
    pub fn max_process_frames(&self) -> usize {
        self.max_process_frames
    }

    /// Output duration per input duration; `2.0` plays twice as long.
    pub fn set_time_ratio(&mut self, ratio: f64) {
        if ratio.is_finite() && ratio > 0.0 && (ratio - self.time_ratio).abs() > 1e-9 {
            self.time_ratio = ratio;
            // SAFETY: `self.state` is valid until drop.
            unsafe { ffi::rubberband_set_time_ratio(self.state.as_ptr(), ratio) }
        }
    }

    /// Clears all buffered audio, as before the first `process` call.
    pub fn reset(&mut self) {
        // SAFETY: `self.state` is valid until drop.
        unsafe { ffi::rubberband_reset(self.state.as_ptr()) }
    }

    /// Input frames to feed before the audio that should start the output.
    pub fn start_pad(&self) -> usize {
        // SAFETY: `self.state` is valid until drop.
        unsafe { ffi::rubberband_get_preferred_start_pad(self.state.as_ptr()) as usize }
    }

    /// Output frames to drop after feeding [`Self::start_pad`] frames of lead-in.
    pub fn start_delay(&self) -> usize {
        // SAFETY: `self.state` is valid until drop.
        unsafe { ffi::rubberband_get_start_delay(self.state.as_ptr()) as usize }
    }

    /// Input frames Rubber Band wants before it can produce more output.
    pub fn samples_required(&self) -> usize {
        // SAFETY: `self.state` is valid until drop.
        unsafe { ffi::rubberband_get_samples_required(self.state.as_ptr()) as usize }
    }

    /// Feeds `left` and `right`, which must have equal length of at most
    /// [`Self::max_process_frames`].
    pub fn process(&mut self, left: &[f32], right: &[f32]) {
        let frames = left.len().min(right.len()).min(self.max_process_frames);
        let channels = [left.as_ptr(), right.as_ptr()];
        // SAFETY: Both pointers address at least `frames` samples, and Rubber Band does not
        // retain them.
        unsafe {
            ffi::rubberband_process(self.state.as_ptr(), channels.as_ptr(), frames as u32, 0);
        }
    }

    /// Output frames ready to retrieve.
    pub fn available(&self) -> usize {
        // SAFETY: `self.state` is valid until drop.
        let available = unsafe { ffi::rubberband_available(self.state.as_ptr()) };
        usize::try_from(available).unwrap_or(0)
    }

    /// Moves up to `left.len()` ready frames into `left` and `right`; returns how many.
    pub fn retrieve(&mut self, left: &mut [f32], right: &mut [f32]) -> usize {
        let frames = left.len().min(right.len());
        let channels = [left.as_mut_ptr(), right.as_mut_ptr()];
        // SAFETY: Both pointers address at least `frames` writable samples.
        unsafe {
            ffi::rubberband_retrieve(self.state.as_ptr(), channels.as_ptr(), frames as u32) as usize
        }
    }
}

impl Drop for RealtimeStretcher {
    fn drop(&mut self) {
        // SAFETY: This wrapper owns the state and `drop` runs exactly once.
        unsafe { ffi::rubberband_delete(self.state.as_ptr()) }
    }
}

/// Per-channel scratch reused for every block.
struct Planar {
    channels: Vec<Vec<f32>>,
}

impl Planar {
    fn new(channels: usize) -> Self {
        Self {
            channels: vec![vec![0.0; BLOCK_FRAMES]; channels],
        }
    }

    /// Splits interleaved `input` frames into the channel buffers.
    fn load(&mut self, input: &[f32]) {
        let count = self.channels.len();
        for (frame_index, frame) in input.chunks_exact(count).enumerate() {
            for (channel, sample) in self.channels.iter_mut().zip(frame) {
                if let Some(slot) = channel.get_mut(frame_index) {
                    *slot = *sample;
                }
            }
        }
    }

    fn input_pointers(&self) -> [*const f32; MAX_CHANNELS] {
        let mut pointers = [std::ptr::null(); MAX_CHANNELS];
        for (pointer, channel) in pointers.iter_mut().zip(&self.channels) {
            *pointer = channel.as_ptr();
        }
        pointers
    }

    fn output_pointers(&mut self) -> [*mut f32; MAX_CHANNELS] {
        let mut pointers = [std::ptr::null_mut(); MAX_CHANNELS];
        for (pointer, channel) in pointers.iter_mut().zip(&mut self.channels) {
            *pointer = channel.as_mut_ptr();
        }
        pointers
    }

    /// Interleaves the first `frames` frames into `output`, replacing its contents.
    fn interleave(&self, frames: usize, output: &mut Vec<f32>) {
        output.clear();
        for frame in 0..frames {
            for channel in &self.channels {
                output.push(channel.get(frame).copied().unwrap_or(0.0));
            }
        }
    }
}

fn validate(request: &OfflineStretch<'_>) -> Result<u32, StretchError> {
    if request.channels == 0 || request.channels > MAX_CHANNELS {
        return Err(StretchError::InvalidInput(
            "channel count must be between 1 and 8",
        ));
    }
    if !request.input.len().is_multiple_of(request.channels) {
        return Err(StretchError::InvalidInput(
            "input length is not a whole number of frames",
        ));
    }
    if !(request.time_ratio.is_finite() && request.time_ratio > 0.0)
        || !(request.pitch_scale.is_finite() && request.pitch_scale > 0.0)
    {
        return Err(StretchError::InvalidInput(
            "time ratio and pitch scale must be positive",
        ));
    }
    let frames = u32::try_from(request.input.len().div_euclid(request.channels))
        .map_err(|_| StretchError::InvalidInput("input is too long"))?;
    let increasing = request
        .key_frames
        .windows(2)
        .all(|pair| matches!(pair, [a, b] if b.0 > a.0 && b.1 > a.1));
    if !increasing {
        return Err(StretchError::InvalidInput(
            "key frames must be strictly increasing",
        ));
    }
    Ok(frames)
}

/// Stretches `request.input` and streams the interleaved result to `sink` in blocks.
///
/// `cancelled` is polled once per block. `progress` receives values from `0.0` to `1.0`.
/// Returns the number of output frames written.
pub fn stretch_offline(
    request: &OfflineStretch<'_>,
    cancelled: &dyn Fn() -> bool,
    progress: &mut dyn FnMut(f32),
    sink: &mut dyn FnMut(&[f32]),
) -> Result<usize, StretchError> {
    let frames = validate(request)?;
    let channels = request.channels;
    let stretcher = RbStretcher::new(request, frames)?;
    let mut planar = Planar::new(channels);
    let block_samples = BLOCK_FRAMES.saturating_mul(channels);
    let blocks = request.input.chunks(block_samples);
    let block_count = blocks.len().max(1) as f32;

    for (index, block) in blocks.clone().enumerate() {
        if cancelled() {
            return Err(StretchError::Cancelled);
        }
        planar.load(block);
        let pointers = planar.input_pointers();
        stretcher.study(
            active(&pointers, channels),
            block.len().div_euclid(channels),
            index.saturating_add(1) == blocks.len(),
        );
        progress(STUDY_WEIGHT * index.saturating_add(1) as f32 / block_count);
    }

    if !request.key_frames.is_empty() {
        let mut from = Vec::with_capacity(request.key_frames.len());
        let mut to = Vec::with_capacity(request.key_frames.len());
        for &(input_frame, output_frame) in request.key_frames {
            from.push(
                u32::try_from(input_frame)
                    .map_err(|_| StretchError::InvalidInput("key frame is out of range"))?,
            );
            to.push(
                u32::try_from(output_frame)
                    .map_err(|_| StretchError::InvalidInput("key frame is out of range"))?,
            );
        }
        stretcher.set_key_frames(&mut from, &mut to);
    }

    let mut output = Planar::new(channels);
    let mut interleaved = Vec::with_capacity(block_samples);
    let mut written = 0_usize;
    let mut drain = |output: &mut Planar, interleaved: &mut Vec<f32>| {
        while let Some(available) = stretcher.available() {
            if available == 0 {
                break;
            }
            let pointers = output.output_pointers();
            let retrieved =
                stretcher.retrieve(active(&pointers, channels), available.min(BLOCK_FRAMES));
            output.interleave(retrieved, interleaved);
            sink(interleaved);
            written = written.saturating_add(retrieved);
        }
    };

    for (index, block) in blocks.clone().enumerate() {
        if cancelled() {
            return Err(StretchError::Cancelled);
        }
        planar.load(block);
        let pointers = planar.input_pointers();
        stretcher.process(
            active(&pointers, channels),
            block.len().div_euclid(channels),
            index.saturating_add(1) == blocks.len(),
        );
        drain(&mut output, &mut interleaved);
        progress(
            STUDY_WEIGHT + (1.0 - STUDY_WEIGHT) * index.saturating_add(1) as f32 / block_count,
        );
    }
    if blocks.len() == 0 {
        stretcher.process(active(&planar.input_pointers(), channels), 0, true);
    }
    // After the final block, `available` reports `None` once every frame is out.
    while stretcher.available().is_some() {
        if cancelled() {
            return Err(StretchError::Cancelled);
        }
        drain(&mut output, &mut interleaved);
        if stretcher.available() == Some(0) {
            std::thread::yield_now();
        }
    }
    progress(1.0);
    Ok(written)
}

#[cfg(test)]
#[allow(
    clippy::unwrap_used,
    clippy::indexing_slicing,
    reason = "test fixtures fail immediately on unexpected results"
)]
mod tests {
    use super::{OfflineStretch, StretchError, stretch_offline};

    const RATE: u32 = 48_000;

    fn sine(frames: usize, channels: usize) -> Vec<f32> {
        (0..frames)
            .flat_map(|frame| {
                let value = (frame as f32 * 440.0 * std::f32::consts::TAU / RATE as f32).sin();
                std::iter::repeat_n(value * 0.5, channels)
            })
            .collect()
    }

    fn request(input: &[f32], channels: usize, time_ratio: f64) -> OfflineStretch<'_> {
        OfflineStretch {
            sample_rate: RATE,
            channels,
            input,
            time_ratio,
            pitch_scale: 1.0,
            preserve_formants: false,
            key_frames: &[],
        }
    }

    fn run(request: &OfflineStretch<'_>) -> Result<Vec<f32>, StretchError> {
        let mut output = Vec::new();
        stretch_offline(request, &|| false, &mut |_| {}, &mut |block| {
            output.extend_from_slice(block)
        })?;
        Ok(output)
    }

    fn assert_close(actual: usize, expected: usize) {
        let tolerance = expected / 100 + 1;
        assert!(
            actual.abs_diff(expected) <= tolerance,
            "{actual} frames, expected about {expected}"
        );
    }

    #[test]
    fn output_length_follows_the_time_ratio() {
        let input = sine(RATE as usize, 2);
        for ratio in [0.75, 1.0, 1.5] {
            let output = run(&request(&input, 2, ratio)).unwrap();
            assert_close(output.len() / 2, (RATE as f64 * ratio) as usize);
        }
    }

    #[test]
    fn progress_reaches_one_and_counts_every_output_frame() {
        let input = sine(RATE as usize / 2, 1);
        let mut last = 0.0;
        let mut streamed = 0;
        let written = stretch_offline(
            &request(&input, 1, 2.0),
            &|| false,
            &mut |fraction| {
                assert!(fraction >= last);
                last = fraction;
            },
            &mut |block| streamed += block.len(),
        )
        .unwrap();
        assert_eq!(last, 1.0);
        assert_eq!(written, streamed);
        assert_close(written, RATE as usize);
    }

    #[test]
    fn cancellation_stops_the_render() {
        let input = sine(RATE as usize, 2);
        let result = stretch_offline(
            &request(&input, 2, 1.25),
            &|| true,
            &mut |_| {},
            &mut |_| {},
        );
        assert_eq!(result, Err(StretchError::Cancelled));
    }

    #[test]
    fn key_frame_pins_an_input_transient_to_its_output_frame() {
        let frames = RATE as usize;
        let mut input = vec![0.0_f32; frames];
        let click = frames / 2;
        for sample in &mut input[click..click + 32] {
            *sample = 0.9;
        }
        let target = click * 3 / 2 + RATE as usize / 10;
        let key_frames = [(click, target)];
        let output = run(&OfflineStretch {
            key_frames: &key_frames,
            ..request(&input, 1, 1.5)
        })
        .unwrap();

        let peak = output
            .iter()
            .enumerate()
            .max_by(|a, b| a.1.abs().total_cmp(&b.1.abs()))
            .map(|(index, _)| index)
            .unwrap();
        assert!(
            peak.abs_diff(target) < 2_048,
            "transient at {peak}, expected near {target}"
        );
    }

    #[test]
    fn invalid_requests_are_rejected() {
        let input = sine(1_000, 2);
        assert!(matches!(
            run(&request(&input[..3], 2, 1.0)),
            Err(StretchError::InvalidInput(_))
        ));
        assert!(matches!(
            run(&request(&input, 2, 0.0)),
            Err(StretchError::InvalidInput(_))
        ));
        let backwards = [(500, 500), (400, 600)];
        assert!(matches!(
            run(&OfflineStretch {
                key_frames: &backwards,
                ..request(&input, 2, 1.0)
            }),
            Err(StretchError::InvalidInput(_))
        ));
    }
}
