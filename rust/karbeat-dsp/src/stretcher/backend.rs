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
/// Create it off the real-time path. Afterwards, processing at most
/// [`Self::max_process_frames`] frames per call, retrieving, the setters and [`Self::reset`]
/// must not allocate.
pub trait RealtimeTimeStretcher: Send + Sized {
    fn new(
        sample_rate: u32,
        channels: usize,
        max_process_frames: usize,
    ) -> Result<Self, StretchError>;

    /// Largest frame count one [`Self::process`] call accepts.
    fn max_process_frames(&self) -> usize;

    /// Output duration per input duration; `2.0` plays twice as long.
    fn set_time_ratio(&mut self, ratio: f64);

    /// Frequency multiplier; `2.0` is an octave up.
    fn set_pitch_scale(&mut self, scale: f64);

    /// Clears all buffered audio, as before the first `process` call.
    fn reset(&mut self);

    /// Input frames to feed before the audio that should start the output.
    fn start_pad(&self) -> usize;

    /// Output frames to drop after feeding [`Self::start_pad`] frames of lead-in.
    fn start_delay(&self) -> usize;

    /// Input frames wanted before more output can be produced.
    fn samples_required(&self) -> usize;

    /// Feeds the shortest channel's length of `input`, at most [`Self::max_process_frames`].
    fn process<C: AsRef<[f32]>>(&mut self, input: &[C]);

    /// Output frames ready to retrieve.
    fn available(&self) -> usize;

    /// Moves up to the shortest channel's length of ready frames into `output`; returns how
    /// many.
    fn retrieve<C: AsMut<[f32]>>(&mut self, output: &mut [C]) -> usize;
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
