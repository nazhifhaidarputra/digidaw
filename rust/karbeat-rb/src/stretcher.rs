//! Safe owner of a `RubberBandStretcher`.

use std::{fmt, ptr::NonNull};

use crate::{RbError, check_channels, ffi, from_c_uint, read_pointers, to_c_uint, write_pointers};

/// Construction options for a [`Stretcher`]. Unset flags use Rubber Band's defaults: offline
/// processing, the faster R2 engine, channels processed apart, and shifted formants.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct StretcherOptions {
    /// Real-time mode: the ratios may change at any time and there is no study pass.
    pub realtime: bool,
    /// The R3 ("finer") engine: higher quality, more CPU.
    pub engine_finer: bool,
    /// Process channels together, keeping the stereo image.
    pub channels_together: bool,
    /// Favour pitch-shift quality over CPU when the pitch scale is not 1.
    pub pitch_high_quality: bool,
    /// Preserve the spectral envelope when shifting pitch.
    pub formant_preserved: bool,
}

impl StretcherOptions {
    fn bits(self) -> Result<ffi::RubberBandOptions, RbError> {
        let flags = [
            (
                self.realtime,
                ffi::RubberBandOption_RubberBandOptionProcessRealTime,
            ),
            (
                self.engine_finer,
                ffi::RubberBandOption_RubberBandOptionEngineFiner,
            ),
            (
                self.channels_together,
                ffi::RubberBandOption_RubberBandOptionChannelsTogether,
            ),
            (
                self.pitch_high_quality,
                ffi::RubberBandOption_RubberBandOptionPitchHighQuality,
            ),
            (
                self.formant_preserved,
                ffi::RubberBandOption_RubberBandOptionFormantPreserved,
            ),
        ];
        let bits = flags
            .iter()
            .filter(|(set, _)| *set)
            .fold(0, |bits, (_, flag)| bits | flag);
        ffi::RubberBandOptions::try_from(bits).map_err(|_| RbError::OutOfRange)
    }
}

/// An owned `RubberBandStretcher`, deleted on drop.
///
/// After construction, [`Self::process`], [`Self::retrieve`], the ratio setters and
/// [`Self::reset`] do not allocate on the Rust side.
pub struct Stretcher {
    state: NonNull<ffi::RubberBandState_>,
    channels: usize,
}

impl fmt::Debug for Stretcher {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("Stretcher")
            .field("channels", &self.channels)
            .finish_non_exhaustive()
    }
}

// SAFETY: The stretcher is an opaque heap object that Rubber Band allows on any thread as long
// as calls are not concurrent; every mutating method takes `&mut self`.
unsafe impl Send for Stretcher {}

impl Stretcher {
    pub fn new(
        sample_rate: u32,
        channels: usize,
        options: StretcherOptions,
        time_ratio: f64,
        pitch_scale: f64,
    ) -> Result<Self, RbError> {
        let c_channels = check_channels(channels)?;
        let bits = options.bits()?;
        // SAFETY: Arguments satisfy the C API contract; ownership of the returned state is
        // transferred to this wrapper.
        let raw =
            unsafe { ffi::rubberband_new(sample_rate, c_channels, bits, time_ratio, pitch_scale) };
        let state = NonNull::new(raw).ok_or(RbError::CreateFailed)?;
        Ok(Self { state, channels })
    }

    pub fn channels(&self) -> usize {
        self.channels
    }

    /// Output duration per input duration; `2.0` plays twice as long.
    pub fn set_time_ratio(&mut self, ratio: f64) {
        // SAFETY: `self.state` is valid until drop and access is exclusive.
        unsafe { ffi::rubberband_set_time_ratio(self.state.as_ptr(), ratio) }
    }

    /// Frequency multiplier; `2.0` is an octave up.
    pub fn set_pitch_scale(&mut self, scale: f64) {
        // SAFETY: `self.state` is valid until drop and access is exclusive.
        unsafe { ffi::rubberband_set_pitch_scale(self.state.as_ptr(), scale) }
    }

    /// Offline only: the total input length, which lets Rubber Band plan the whole stretch.
    pub fn set_expected_input_duration(&mut self, frames: usize) -> Result<(), RbError> {
        let frames = to_c_uint(frames)?;
        // SAFETY: `self.state` is valid until drop and access is exclusive.
        unsafe { ffi::rubberband_set_expected_input_duration(self.state.as_ptr(), frames) }
        Ok(())
    }

    /// The largest frame count a single [`Self::process`] call will pass.
    pub fn set_max_process_size(&mut self, frames: usize) -> Result<(), RbError> {
        let frames = to_c_uint(frames)?;
        // SAFETY: `self.state` is valid until drop and access is exclusive.
        unsafe { ffi::rubberband_set_max_process_size(self.state.as_ptr(), frames) }
        Ok(())
    }

    /// Offline only: pins `(input_frame, output_frame)` pairs, strictly increasing in both.
    /// Call after studying and before processing. Allocates the C arrays.
    pub fn set_key_frame_map(&mut self, map: &[(usize, usize)]) -> Result<(), RbError> {
        let mut from = Vec::with_capacity(map.len());
        let mut to = Vec::with_capacity(map.len());
        for &(input_frame, output_frame) in map {
            from.push(to_c_uint(input_frame)?);
            to.push(to_c_uint(output_frame)?);
        }
        let count = to_c_uint(map.len())?;
        // SAFETY: Both arrays hold `count` entries, and Rubber Band copies the map.
        unsafe {
            ffi::rubberband_set_key_frame_map(
                self.state.as_ptr(),
                count,
                from.as_mut_ptr(),
                to.as_mut_ptr(),
            );
        }
        Ok(())
    }

    /// Offline only: studies the shortest channel's length of `input` before processing.
    pub fn study<C: AsRef<[f32]>>(&mut self, input: &[C], last: bool) -> Result<(), RbError> {
        let (pointers, frames) = read_pointers(input, self.channels)?;
        let frames = to_c_uint(frames)?;
        // SAFETY: Each of the first `channels` pointers addresses at least `frames` samples,
        // and Rubber Band does not retain them.
        unsafe {
            ffi::rubberband_study(
                self.state.as_ptr(),
                pointers.as_ptr(),
                frames,
                i32::from(last),
            );
        }
        Ok(())
    }

    /// Feeds the shortest channel's length of `input`.
    pub fn process<C: AsRef<[f32]>>(&mut self, input: &[C], last: bool) -> Result<(), RbError> {
        let (pointers, frames) = read_pointers(input, self.channels)?;
        let frames = to_c_uint(frames)?;
        // SAFETY: Each of the first `channels` pointers addresses at least `frames` samples,
        // and Rubber Band does not retain them.
        unsafe {
            ffi::rubberband_process(
                self.state.as_ptr(),
                pointers.as_ptr(),
                frames,
                i32::from(last),
            );
        }
        Ok(())
    }

    /// Frames ready to retrieve, or `None` once the final block's output is all retrieved.
    pub fn available(&self) -> Option<usize> {
        // SAFETY: `self.state` is valid until drop.
        let available = unsafe { ffi::rubberband_available(self.state.as_ptr()) };
        usize::try_from(available).ok()
    }

    /// Moves up to the shortest channel's length of ready frames into `output`; returns how
    /// many.
    pub fn retrieve<C: AsMut<[f32]>>(&mut self, output: &mut [C]) -> Result<usize, RbError> {
        let (pointers, frames) = write_pointers(output, self.channels)?;
        let frames = to_c_uint(frames)?;
        // SAFETY: Each of the first `channels` pointers addresses at least `frames` writable
        // samples, the buffers are exclusively borrowed, and Rubber Band does not retain them.
        let retrieved =
            unsafe { ffi::rubberband_retrieve(self.state.as_ptr(), pointers.as_ptr(), frames) };
        Ok(from_c_uint(retrieved))
    }

    /// Clears all buffered audio, as before the first `process` call.
    pub fn reset(&mut self) {
        // SAFETY: `self.state` is valid until drop and access is exclusive.
        unsafe { ffi::rubberband_reset(self.state.as_ptr()) }
    }

    /// Real-time only: input frames to feed before the audio that should start the output.
    pub fn start_pad(&self) -> usize {
        // SAFETY: `self.state` is valid until drop.
        from_c_uint(unsafe { ffi::rubberband_get_preferred_start_pad(self.state.as_ptr()) })
    }

    /// Real-time only: output frames to drop after feeding [`Self::start_pad`] frames.
    pub fn start_delay(&self) -> usize {
        // SAFETY: `self.state` is valid until drop.
        from_c_uint(unsafe { ffi::rubberband_get_start_delay(self.state.as_ptr()) })
    }

    /// Input frames Rubber Band wants before it can produce more output.
    pub fn samples_required(&self) -> usize {
        // SAFETY: `self.state` is valid until drop.
        from_c_uint(unsafe { ffi::rubberband_get_samples_required(self.state.as_ptr()) })
    }
}

impl Drop for Stretcher {
    fn drop(&mut self) {
        // SAFETY: This wrapper owns the state and `drop` runs exactly once.
        unsafe { ffi::rubberband_delete(self.state.as_ptr()) }
    }
}

#[cfg(test)]
#[allow(
    clippy::unwrap_used,
    reason = "test fixtures fail immediately on unexpected results"
)]
mod tests {
    use super::*;

    #[test]
    fn mismatched_channel_buffers_are_rejected() {
        let mut stretcher =
            Stretcher::new(48_000, 2, StretcherOptions::default(), 1.0, 1.0).unwrap();
        let mono = [vec![0.0_f32; 64]];
        assert_eq!(
            stretcher.process(&mono, false),
            Err(RbError::ChannelMismatch {
                expected: 2,
                got: 1
            })
        );
        assert_eq!(
            Stretcher::new(48_000, 9, StretcherOptions::default(), 1.0, 1.0).err(),
            Some(RbError::UnsupportedChannels(9))
        );
    }

    #[test]
    fn realtime_round_trip_produces_output() {
        let options = StretcherOptions {
            realtime: true,
            engine_finer: true,
            channels_together: true,
            ..StretcherOptions::default()
        };
        let mut stretcher = Stretcher::new(48_000, 2, options, 1.0, 1.0).unwrap();
        stretcher.set_max_process_size(1024).unwrap();
        stretcher.set_pitch_scale(1.5);
        let input = [vec![0.25_f32; 1024], vec![0.25_f32; 1024]];
        let mut output = [vec![0.0_f32; 1024], vec![0.0_f32; 1024]];
        let mut retrieved = 0;
        for _ in 0..32 {
            stretcher.process(&input, false).unwrap();
            retrieved += stretcher.retrieve(&mut output).unwrap();
        }
        assert!(retrieved > 0);
    }
}
