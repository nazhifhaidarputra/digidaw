//! Algorithm-neutral contracts for time stretching and pitch shifting.
//!
//! Consumers use the `Default*` aliases in [`crate::stretcher`], so swapping the algorithm
//! means implementing these traits and changing those aliases. Channel buffers are slices of
//! per-channel samples.

use super::{OfflineStretch, StretchError};

/// Real-time, fixed-block pitch shifter.
///
/// Create it off the real-time path. Afterwards every method must be real-time safe: no
/// allocation, locking or blocking.
pub trait LivePitchShifter: Send + Sync + Sized {
    fn new(
        sample_rate: u32,
        channels: usize,
        preserve_formants: bool,
    ) -> Result<Self, StretchError>;

    /// Frames every [`Self::shift`] call takes and returns.
    fn block_size(&self) -> usize;

    /// Output frames before the first shifted input frame appears; may follow the pitch scale.
    fn latency(&self) -> usize;

    /// Frequency multiplier; `2.0` is an octave up.
    fn set_pitch_scale(&mut self, scale: f64);

    fn set_preserve_formants(&mut self, preserve: bool);

    /// Shifts one block of [`Self::block_size`] frames from `input` into `output`, both with
    /// the channel count given at construction.
    fn shift<I: AsRef<[f32]>, O: AsMut<[f32]>>(
        &mut self,
        input: &[I],
        output: &mut [O],
    ) -> Result<(), StretchError>;

    /// Clears all buffered audio.
    fn reset(&mut self);
}

/// Real-time stretcher whose time ratio and pitch can change at any time.
///
/// Processing is synchronous: [`Self::process`] consumes every input frame it is given and
/// fills every output frame, so the ratio of the two lengths is the time stretch of that call.
/// The processing point trails the newest input by [`Self::input_latency`] input frames, and
/// the output trails the processing point by [`Self::output_latency`] output frames.
///
/// Create it off the real-time path. Afterwards every method must be real-time safe: no
/// allocation, locking or blocking.
pub trait RealtimeTimeStretcher: Send + Sized {
    fn new(sample_rate: u32, channels: usize) -> Result<Self, StretchError>;

    /// Frequency multiplier; `2.0` is an octave up.
    fn set_pitch_scale(&mut self, scale: f64);

    fn set_preserve_formants(&mut self, preserve: bool);

    /// Clears all buffered audio.
    fn reset(&mut self);

    /// Input frames the processing point trails the newest input by.
    fn input_latency(&self) -> usize;

    /// Output frames the output trails the processing point by.
    fn output_latency(&self) -> usize;

    /// Input frames [`Self::seek`] uses at most.
    fn seek_frames(&self) -> usize;

    /// Replaces the input history with `input` without producing output, so the processing
    /// point moves to [`Self::input_latency`] frames before its end. `rate` is the input frames
    /// per output frame expected next. Only the last [`Self::seek_frames`] frames are used.
    fn seek<C: AsRef<[f32]>>(&mut self, input: &[C], rate: f64);

    /// Consumes the shortest input channel's length of frames and fills the shortest output
    /// channel's length of frames. A call with the wrong channel count does nothing.
    fn process<I: AsRef<[f32]>, O: AsMut<[f32]>>(&mut self, input: &[I], output: &mut [O]);
}

/// Whole-input stretcher for background renders; not real-time safe.
pub trait OfflineTimeStretcher: Sync {
    /// Stretches `request.input` and streams the interleaved result to `sink` in blocks.
    ///
    /// `cancelled` is polled once per block. `progress` receives values from `0.0` to `1.0`.
    /// Returns the number of output frames written.
    fn stretch(
        &self,
        request: &OfflineStretch<'_>,
        cancelled: &dyn Fn() -> bool,
        progress: &mut dyn FnMut(f32),
        sink: &mut dyn FnMut(&[f32]),
    ) -> Result<usize, StretchError>;
}
