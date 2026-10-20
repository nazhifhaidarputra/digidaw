//! Safe owner of a `SignalsmithStretch<float>`.
//!
//! It runs the library's cheaper preset (a 100 ms block every 40 ms) with split computation,
//! which spreads each block's spectral work evenly over the samples of the next interval at
//! the cost of one interval of extra output latency, so no callback carries a whole block.
//!
//! Processing is synchronous: [`Stretcher::process`] consumes every input frame it is given
//! and fills every output frame, so the ratio of the two lengths is the time stretch of that
//! call. Pitch is independent of it.

use std::{fmt, ptr::NonNull};

use crate::{MAX_CHANNELS, SsError, ffi, from_c_int, read_pointers, to_c_int, write_pointers};

/// An owned Signalsmith stretcher, deleted on drop.
pub struct Stretcher {
    raw: NonNull<ffi::KarbeatStretch>,
    channels: usize,
    input_latency: usize,
    output_latency: usize,
    seek_length: usize,
}

impl fmt::Debug for Stretcher {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("Stretcher")
            .field("channels", &self.channels)
            .field("input_latency", &self.input_latency)
            .field("output_latency", &self.output_latency)
            .finish_non_exhaustive()
    }
}

// SAFETY: The stretcher is an opaque heap object without thread affinity; every call that
// changes it takes `&mut self`, so calls are never concurrent.
unsafe impl Send for Stretcher {}
// SAFETY: Shared references only reach the cached configuration.
unsafe impl Sync for Stretcher {}

impl Stretcher {
    /// Allocates and configures the stretcher; call it off the real-time path.
    pub fn new(sample_rate: u32, channels: usize) -> Result<Self, SsError> {
        if channels == 0 || channels > MAX_CHANNELS {
            return Err(SsError::UnsupportedChannels(channels));
        }
        if sample_rate == 0 {
            return Err(SsError::OutOfRange);
        }
        let c_channels = to_c_int(channels)?;
        #[allow(clippy::as_conversions, reason = "audio sample rates are exact in f32")]
        let rate = sample_rate as f32;
        // SAFETY: Arguments are in range; ownership of the returned instance is transferred
        // to this wrapper.
        let raw = unsafe { ffi::karbeat_stretch_new(c_channels, rate) };
        let raw = NonNull::new(raw).ok_or(SsError::CreateFailed)?;
        // SAFETY: `raw` is a live instance owned by this wrapper.
        let input_latency = from_c_int(unsafe { ffi::karbeat_stretch_input_latency(raw.as_ptr()) });
        // SAFETY: As above.
        let output_latency =
            from_c_int(unsafe { ffi::karbeat_stretch_output_latency(raw.as_ptr()) });
        // SAFETY: As above.
        let seek_length = from_c_int(unsafe { ffi::karbeat_stretch_seek_length(raw.as_ptr()) });
        Ok(Self {
            raw,
            channels,
            input_latency,
            output_latency,
            seek_length,
        })
    }

    pub fn channels(&self) -> usize {
        self.channels
    }

    /// Input frames the processing point trails the newest input by.
    pub fn input_latency(&self) -> usize {
        self.input_latency
    }

    /// Output frames the output trails the processing point by.
    pub fn output_latency(&self) -> usize {
        self.output_latency
    }

    /// Input frames [`Self::seek`] uses at most: one block plus one interval.
    pub fn seek_length(&self) -> usize {
        self.seek_length
    }

    /// Clears all buffered audio.
    pub fn reset(&mut self) {
        // SAFETY: `self.raw` is valid until drop and access is exclusive.
        unsafe { ffi::karbeat_stretch_reset(self.raw.as_ptr()) }
    }

    /// Frequency multiplier; `2.0` is an octave up.
    pub fn set_transpose_factor(&mut self, factor: f64) {
        #[allow(clippy::as_conversions, reason = "the library processes in f32")]
        let factor = factor as f32;
        // SAFETY: `self.raw` is valid until drop and access is exclusive.
        unsafe { ffi::karbeat_stretch_set_transpose_factor(self.raw.as_ptr(), factor) }
    }

    /// Keeps the spectral envelope in place when transposing. Costs extra processing while a
    /// transpose is set.
    pub fn set_formant_preserved(&mut self, preserved: bool) {
        // SAFETY: `self.raw` is valid until drop and access is exclusive.
        unsafe {
            ffi::karbeat_stretch_set_formant_compensation(self.raw.as_ptr(), i32::from(preserved));
        }
    }

    /// Replaces the input history with `input`, without producing output, so the processing
    /// point moves to [`Self::input_latency`] frames before its end. `rate` is the input
    /// frames per output frame expected next.
    ///
    /// Only the last [`Self::seek_length`] frames are used.
    pub fn seek<C: AsRef<[f32]>>(&mut self, input: &[C], rate: f64) -> Result<(), SsError> {
        let (inputs, frames) = read_pointers(input, self.channels)?;
        let frames = to_c_int(frames)?;
        // SAFETY: Each channel pointer is valid for `frames` reads, and the library does not
        // retain the pointers.
        unsafe { ffi::karbeat_stretch_seek(self.raw.as_ptr(), inputs.as_ptr(), frames, rate) }
        Ok(())
    }

    /// Consumes the shortest input channel's length of frames and fills the shortest output
    /// channel's length of frames.
    pub fn process<I: AsRef<[f32]>, O: AsMut<[f32]>>(
        &mut self,
        input: &[I],
        output: &mut [O],
    ) -> Result<(), SsError> {
        let (inputs, input_frames) = read_pointers(input, self.channels)?;
        let (outputs, output_frames) = write_pointers(output, self.channels)?;
        let input_frames = to_c_int(input_frames)?;
        let output_frames = to_c_int(output_frames)?;
        // SAFETY: Each channel pointer is valid for its frame count. Rust's borrows keep input
        // and output disjoint, and the library does not retain the pointers.
        unsafe {
            ffi::karbeat_stretch_process(
                self.raw.as_ptr(),
                inputs.as_ptr(),
                input_frames,
                outputs.as_ptr(),
                output_frames,
            );
        }
        Ok(())
    }
}

impl Drop for Stretcher {
    fn drop(&mut self) {
        // SAFETY: This wrapper owns the instance and `drop` runs exactly once.
        unsafe { ffi::karbeat_stretch_delete(self.raw.as_ptr()) }
    }
}

#[cfg(test)]
#[allow(
    clippy::unwrap_used,
    clippy::as_conversions,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects,
    reason = "test fixtures fail immediately on unexpected results"
)]
mod tests {
    use super::*;

    const RATE: u32 = 48_000;

    fn sine(frames: usize, hz: f32) -> Vec<f32> {
        (0..frames)
            .map(|i| (i as f32 * hz * std::f32::consts::TAU / RATE as f32).sin() * 0.5)
            .collect()
    }

    /// Rising zero crossings per second over `samples`.
    fn frequency(samples: &[f32]) -> f32 {
        let rising = samples
            .windows(2)
            .filter(|pair| pair[0] < 0.0 && pair[1] >= 0.0)
            .count();
        rising as f32 * RATE as f32 / samples.len() as f32
    }

    /// Runs `input` through in blocks of 512 output frames at `rate` input frames per output
    /// frame; returns the output after the latency has passed.
    fn run(stretcher: &mut Stretcher, input: &[f32], rate: f64) -> Vec<f32> {
        let mut output = Vec::new();
        let mut block = vec![0.0; 512];
        let mut position = 0.0_f64;
        loop {
            let start = position as usize;
            position += 512.0 * rate;
            let end = position as usize;
            if end > input.len() {
                break;
            }
            stretcher
                .process(&[&input[start..end]], &mut [&mut block[..]])
                .unwrap();
            output.extend_from_slice(&block);
        }
        output.split_off(stretcher.input_latency() + stretcher.output_latency())
    }

    #[test]
    fn configuration_follows_the_cheaper_preset() {
        let stretcher = Stretcher::new(RATE, 2).unwrap();
        assert_eq!(stretcher.channels(), 2);
        // A 100 ms block every 40 ms: seeking takes a block plus an interval.
        assert_eq!(stretcher.seek_length(), 4_800 + 1_920);
        assert!(stretcher.input_latency() > 0);
        assert!(stretcher.output_latency() > stretcher.input_latency());
    }

    #[test]
    fn transposing_moves_the_frequency_and_keeps_the_duration() {
        let mut stretcher = Stretcher::new(RATE, 1).unwrap();
        stretcher.set_transpose_factor(1.5);
        let output = run(&mut stretcher, &sine(RATE as usize * 2, 440.0), 1.0);
        let hz = frequency(&output);
        assert!((hz - 660.0).abs() < 10.0, "{hz} Hz");
    }

    #[test]
    fn stretching_keeps_the_frequency() {
        for rate in [0.5, 1.5] {
            let mut stretcher = Stretcher::new(RATE, 1).unwrap();
            let output = run(&mut stretcher, &sine(RATE as usize * 3, 440.0), rate);
            let hz = frequency(&output);
            assert!((hz - 440.0).abs() < 10.0, "rate {rate}: {hz} Hz");
        }
    }

    #[test]
    fn channel_counts_are_checked() {
        assert_eq!(
            Stretcher::new(RATE, 0).unwrap_err(),
            SsError::UnsupportedChannels(0)
        );
        assert_eq!(
            Stretcher::new(RATE, MAX_CHANNELS + 1).unwrap_err(),
            SsError::UnsupportedChannels(MAX_CHANNELS + 1)
        );
        let mut stretcher = Stretcher::new(RATE, 2).unwrap();
        let input = [vec![0.0_f32; 64]];
        let mut output = [vec![0.0_f32; 64], vec![0.0_f32; 64]];
        assert_eq!(
            stretcher.process(&input, &mut output),
            Err(SsError::ChannelMismatch {
                expected: 2,
                got: 1
            })
        );
    }
}
