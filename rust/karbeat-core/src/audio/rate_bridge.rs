use rubato::{
    audioadapter_buffers::direct::InterleavedSlice, Fft, FixedSync, Indexing, Resampler,
};

/// Bridges the DSP engine's sample rate to whatever rate the CPAL device
/// actually negotiated. These two rates are independent by design (the engine
/// rate comes from `AudioRuntimeSettings::requested_dsp`, the device rate from
/// whatever the OS/driver returns), so this bridge runs on essentially every
/// stream, on every backend — it is not a rare fallback path.
///
/// When the rates happen to match exactly (common on JACK, where the server's
/// fixed rate is usually set to match the project), this is a true passthrough
/// with zero added latency and zero interpolation error. When they differ
/// (common on the default host, whose native device rate frequently doesn't
/// match the DSP rate), audio is resampled with Rubato's synchronous `Fft`
/// resampler rather than naive linear interpolation — linear interpolation's
/// error is roughly proportional to waveform curvature rather than amplitude,
/// so it shows up disproportionately as distortion in quiet/decaying material
/// even though the underlying float values never technically clip.
pub struct DeviceRateBridge {
    /// Resampler of the bridge. `None` means the rates match exactly: passthrough, no resampler needed.
    resampler: Option<Fft<f32>>,
    channels: usize,
    output: Vec<f32>,
    output_len: usize,
    indexing: Indexing,
}

impl DeviceRateBridge {
    pub fn new(
        input_rate: u32,
        output_rate: u32,
        channels: usize,
        maximum_input_frames: usize,
    ) -> anyhow::Result<Self> {
        anyhow::ensure!(input_rate > 0, "DSP sample rate must be positive");
        anyhow::ensure!(output_rate > 0, "Device sample rate must be positive");
        anyhow::ensure!(channels > 0, "Channel count must be positive");
        anyhow::ensure!(maximum_input_frames > 0, "DSP block size must be positive");

        let resampler = if input_rate == output_rate {
            None
        } else {
            Some(
                Fft::<f32>::new(
                    input_rate as usize,
                    output_rate as usize,
                    maximum_input_frames,
                    channels,
                    FixedSync::Input,
                )
                .map_err(|e| anyhow::anyhow!("failed to build device rate bridge: {e}"))?,
            )
        };

        let max_output_frames = resampler
            .as_ref()
            .map(|r| r.output_frames_max())
            .unwrap_or(maximum_input_frames);

        Ok(Self {
            resampler,
            channels,
            output: vec![0.0; max_output_frames * channels],
            output_len: 0,
            indexing: Indexing::new(),
        })
    }

    /// The fixed capacity of the internal output buffer. Never changes after
    /// construction, regardless of how many frames a given `process` call
    /// actually produces.
    pub fn maximum_output_samples(&self) -> usize {
        self.output.len()
    }

    pub fn process<'a>(&'a mut self, input: &[f32]) -> &'a [f32] {
        let Some(resampler) = self.resampler.as_mut() else {
            // Rates match: bit-exact passthrough, no interpolation error and
            // no added latency.
            let len = input.len().min(self.output.len());
            self.output[..len].copy_from_slice(&input[..len]);
            self.output_len = len;
            return &self.output[..self.output_len];
        };

        let frames_needed = resampler.input_frames_next();
        let needed_samples = frames_needed * self.channels;
        if input.len() < needed_samples {
            // Defensive: the DSP thread always hands us a fixed-size staging
            // buffer sized to match, so this shouldn't happen in practice.
            self.output_len = 0;
            return &self.output[..0];
        }

        let (Ok(input_adapter), output_capacity) = (
            InterleavedSlice::new(input, self.channels, frames_needed),
            self.output.len() / self.channels,
        ) else {
            self.output_len = 0;
            return &self.output[..0];
        };
        let Ok(mut output_adapter) =
            InterleavedSlice::new_mut(&mut self.output, self.channels, output_capacity)
        else {
            self.output_len = 0;
            return &self.output[..0];
        };

        let frames_written = resampler
            .process_into_buffer(&input_adapter, &mut output_adapter, Some(&self.indexing))
            .map(|(_consumed, written)| written)
            .unwrap_or(0);

        self.output_len = frames_written * self.channels;
        &self.output[..self.output_len]
    }
}

#[cfg(test)]
mod tests {
    use super::DeviceRateBridge;

    #[test]
    fn equal_rates_are_a_bit_exact_passthrough_with_no_added_latency() {
        let mut bridge = DeviceRateBridge::new(48_000, 48_000, 1, 4).unwrap();
        let first = bridge.process(&[0.0, 1.0, 2.0, 3.0]).to_vec();
        let second = bridge.process(&[4.0, 5.0, 6.0, 7.0]).to_vec();
        // Unlike a hand-rolled interpolator, an exact-rate passthrough should
        // never hold a frame back for "continuity" — there's nothing to
        // interpolate, so every input frame comes straight through.
        assert_eq!(first, vec![0.0, 1.0, 2.0, 3.0]);
        assert_eq!(second, vec![4.0, 5.0, 6.0, 7.0]);
    }

    #[test]
    fn mismatched_rates_converge_to_the_correct_long_run_frame_count() {
        let mut bridge = DeviceRateBridge::new(44_100, 48_000, 2, 441).unwrap();
        let input = vec![0.25; 441 * 2];
        let mut output_frames = 0usize;
        // Run for a full simulated second's worth of 44.1kHz input (100 blocks
        // of 441 frames). The Fft resampler has a small fixed startup delay
        // (unlike the old interpolator, which had none), so we allow a
        // generous tolerance that comfortably absorbs that one-time offset
        // while still catching any gross ratio error.
        for _ in 0..100 {
            output_frames += bridge.process(&input).len() / 2;
        }
        assert!(
            (output_frames as isize - 48_000).abs() <= 512,
            "expected ~48000 output frames, got {output_frames}"
        );
    }

    #[test]
    fn output_storage_capacity_does_not_change_during_processing() {
        let mut bridge = DeviceRateBridge::new(44_100, 96_000, 2, 64).unwrap();
        let capacity = bridge.maximum_output_samples();
        let input = vec![0.0; 64 * 2];
        for _ in 0..10_000 {
            let output = bridge.process(&input);
            assert!(output.len() <= capacity);
        }
        assert_eq!(bridge.maximum_output_samples(), capacity);
    }
}