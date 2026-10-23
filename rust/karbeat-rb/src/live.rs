//! Safe owner of a `RubberBandLiveShifter`.
//!
//! Unlike the general stretcher, the live shifter takes and returns one fixed-size block per
//! call, does not allocate or lock while shifting, and has lower latency. It shifts pitch
//! only.

use std::{fmt, ptr::NonNull};

use crate::{RbError, check_channels, ffi, from_c_uint, read_pointers, write_pointers};

/// Construction options for a [`LiveShifter`]. It always uses the short window.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct LiveOptions {
    /// Preserve the spectral envelope when shifting pitch.
    pub formant_preserved: bool,
}

impl LiveOptions {
    fn bits(self) -> Result<ffi::RubberBandLiveOptions, RbError> {
        let mut bits = ffi::RubberBandLiveOption_RubberBandLiveOptionWindowShort;
        if self.formant_preserved {
            bits |= ffi::RubberBandLiveOption_RubberBandLiveOptionFormantPreserved;
        }
        ffi::RubberBandLiveOptions::try_from(bits).map_err(|_| RbError::OutOfRange)
    }
}

/// An owned `RubberBandLiveShifter`, deleted on drop.
pub struct LiveShifter {
    state: NonNull<ffi::RubberBandLiveState_>,
    block_size: usize,
    channels: usize,
}

impl fmt::Debug for LiveShifter {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("LiveShifter")
            .field("block_size", &self.block_size)
            .field("channels", &self.channels)
            .finish_non_exhaustive()
    }
}

// SAFETY: The shifter is an opaque heap object that Rubber Band allows on any thread as long
// as calls are not concurrent; every mutating method takes `&mut self`.
unsafe impl Send for LiveShifter {}
// SAFETY: Shared references only reach the cached block size and Rubber Band's read-only
// start-delay query; everything that changes the instance takes `&mut self`.
unsafe impl Sync for LiveShifter {}

impl LiveShifter {
    pub fn new(sample_rate: u32, channels: usize, options: LiveOptions) -> Result<Self, RbError> {
        let c_channels = check_channels(channels)?;
        let bits = options.bits()?;
        // SAFETY: Arguments satisfy the C API contract; ownership of the returned state is
        // transferred to this wrapper.
        let raw = unsafe { ffi::rubberband_live_new(sample_rate, c_channels, bits) };
        let state = NonNull::new(raw).ok_or(RbError::CreateFailed)?;
        // SAFETY: `state` is a live shifter owned by this wrapper.
        let block_size =
            from_c_uint(unsafe { ffi::rubberband_live_get_block_size(state.as_ptr()) });
        Ok(Self {
            state,
            block_size,
            channels,
        })
    }

    /// Frames every [`Self::shift`] call takes and returns.
    pub fn block_size(&self) -> usize {
        self.block_size
    }

    pub fn channels(&self) -> usize {
        self.channels
    }

    /// Output frames before the first shifted input frame appears.
    pub fn start_delay(&self) -> usize {
        // SAFETY: `self.state` is valid until drop.
        from_c_uint(unsafe { ffi::rubberband_live_get_start_delay(self.state.as_ptr()) })
    }

    /// Frequency multiplier; `2.0` is an octave up.
    pub fn set_pitch_scale(&mut self, scale: f64) {
        // SAFETY: `self.state` is valid until drop and access is exclusive.
        unsafe { ffi::rubberband_live_set_pitch_scale(self.state.as_ptr(), scale) }
    }

    pub fn set_formant_preserved(&mut self, preserved: bool) {
        let option = if preserved {
            ffi::RubberBandLiveOption_RubberBandLiveOptionFormantPreserved
        } else {
            ffi::RubberBandLiveOption_RubberBandLiveOptionFormantShifted
        };
        let Ok(option) = ffi::RubberBandOptions::try_from(option) else {
            return;
        };
        // SAFETY: `self.state` is valid until drop and access is exclusive.
        unsafe { ffi::rubberband_live_set_formant_option(self.state.as_ptr(), option) }
    }

    /// Shifts one block: every input and output channel must hold at least
    /// [`Self::block_size`] frames, and only that many are read and written.
    pub fn shift<I: AsRef<[f32]>, O: AsMut<[f32]>>(
        &mut self,
        input: &[I],
        output: &mut [O],
    ) -> Result<(), RbError> {
        let (inputs, input_frames) = read_pointers(input, self.channels)?;
        let (outputs, output_frames) = write_pointers(output, self.channels)?;
        let frames = input_frames.min(output_frames);
        if frames < self.block_size {
            return Err(RbError::ShortBuffer {
                needed: self.block_size,
                got: frames,
            });
        }
        // SAFETY: Each initialized channel points to a full block. Rust's borrows keep input
        // and output disjoint, and Rubber Band does not retain the pointers.
        unsafe {
            ffi::rubberband_live_shift(self.state.as_ptr(), inputs.as_ptr(), outputs.as_ptr());
        }
        Ok(())
    }

    /// Clears all buffered audio.
    pub fn reset(&mut self) {
        // SAFETY: `self.state` is valid until drop and access is exclusive.
        unsafe { ffi::rubberband_live_reset(self.state.as_ptr()) }
    }
}

impl Drop for LiveShifter {
    fn drop(&mut self) {
        // SAFETY: This wrapper owns the state and `drop` runs exactly once.
        unsafe { ffi::rubberband_live_delete(self.state.as_ptr()) }
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
    fn short_blocks_are_rejected() {
        let mut shifter = LiveShifter::new(48_000, 1, LiveOptions::default()).unwrap();
        let block = shifter.block_size();
        assert!(block > 0);
        let input = [vec![0.0_f32; block - 1]];
        let mut output = [vec![0.0_f32; block]];
        assert_eq!(
            shifter.shift(&input, &mut output),
            Err(RbError::ShortBuffer {
                needed: block,
                got: block - 1
            })
        );
        let input = [vec![0.0_f32; block]];
        assert_eq!(shifter.shift(&input, &mut output), Ok(()));
    }
}
