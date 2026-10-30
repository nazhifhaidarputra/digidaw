use rubato::{
    Async, Fft, FixedAsync, FixedSync, Indexing, Resampler, SincInterpolationParameters,
    WindowFunction, audioadapter_buffers::direct::InterleavedSlice,
};

/// Furthest an adjustable bridge's ratio moves from its nominal value, as a factor.
const MAX_RELATIVE_RATIO: f64 = 1.02;

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
    resampler: Option<Box<dyn Resampler<f32> + Send>>,
    /// Whether the resampler's ratio can be adjusted, see [`Self::set_relative_ratio`].
    adjustable: bool,
    channels: usize,
    output: Vec<f32>,
    output_len: usize,
    maximum_output_samples: usize,
    /// Frames each call takes in passthrough, and the largest input a call takes otherwise.
    maximum_input_frames: usize,
    indexing: Indexing,
}

impl DeviceRateBridge {
    pub fn new(
        input_rate: u32,
        output_rate: u32,
        channels: usize,
        maximum_input_frames: usize,
    ) -> anyhow::Result<Self> {
        Self::build(
            input_rate,
            output_rate,
            channels,
            maximum_input_frames,
            BridgeKind::Fixed(FixedSync::Input),
        )
    }

    /// A bridge whose every call produces exactly `output_frames` frames, taking as many input
    /// frames as [`Self::input_frames_next`] asks for. Used to bring device input to the DSP
    /// rate one engine block at a time.
    pub fn with_fixed_output(
        input_rate: u32,
        output_rate: u32,
        channels: usize,
        output_frames: usize,
    ) -> anyhow::Result<Self> {
        Self::build(
            input_rate,
            output_rate,
            channels,
            output_frames,
            BridgeKind::Fixed(FixedSync::Output),
        )
    }

    /// Like [`Self::with_fixed_output`], but the ratio can be nudged with
    /// [`Self::set_relative_ratio`] to follow a device clock that drifts from the engine's. It
    /// resamples even when the nominal rates match.
    pub fn adjustable_fixed_output(
        input_rate: u32,
        output_rate: u32,
        channels: usize,
        output_frames: usize,
    ) -> anyhow::Result<Self> {
        Self::build(
            input_rate,
            output_rate,
            channels,
            output_frames,
            BridgeKind::Adjustable,
        )
    }

    fn build(
        input_rate: u32,
        output_rate: u32,
        channels: usize,
        chunk_frames: usize,
        kind: BridgeKind,
    ) -> anyhow::Result<Self> {
        anyhow::ensure!(input_rate > 0, "DSP sample rate must be positive");
        anyhow::ensure!(output_rate > 0, "Device sample rate must be positive");
        anyhow::ensure!(channels > 0, "Channel count must be positive");
        anyhow::ensure!(chunk_frames > 0, "DSP block size must be positive");

        let resampler: Option<Box<dyn Resampler<f32> + Send>> = match kind {
            BridgeKind::Fixed(_) if input_rate == output_rate => None,
            BridgeKind::Fixed(fixed) => Some(Box::new(
                Fft::<f32>::new(
                    input_rate as usize,
                    output_rate as usize,
                    chunk_frames,
                    channels,
                    fixed,
                )
                .map_err(|e| anyhow::anyhow!("failed to build device rate bridge: {e}"))?,
            )),
            BridgeKind::Adjustable => Some(Box::new(
                Async::<f32>::new_sinc(
                    f64::from(output_rate) / f64::from(input_rate),
                    MAX_RELATIVE_RATIO,
                    &SincInterpolationParameters::new(128, WindowFunction::BlackmanHarris2),
                    chunk_frames,
                    channels,
                    FixedAsync::Output,
                )
                .map_err(|e| anyhow::anyhow!("failed to build device rate bridge: {e}"))?,
            )),
        };
        let passthrough = resampler.is_none();

        let max_output_frames = resampler
            .as_ref()
            .map(|r| r.output_frames_max())
            .unwrap_or(chunk_frames);
        let maximum_input_frames = resampler
            .as_ref()
            .map_or(chunk_frames, |r| r.input_frames_max());

        let maximum_output_samples = max_output_frames * channels;
        Ok(Self {
            resampler,
            adjustable: matches!(kind, BridgeKind::Adjustable),
            channels,
            output: if passthrough {
                Vec::new()
            } else {
                vec![0.0; maximum_output_samples]
            },
            output_len: 0,
            maximum_output_samples,
            maximum_input_frames,
            indexing: Indexing::new(),
        })
    }

    /// The fixed capacity of the internal output buffer. Never changes after
    /// construction, regardless of how many frames a given `process` call
    /// actually produces.
    pub fn maximum_output_samples(&self) -> usize {
        self.maximum_output_samples
    }

    /// Most input frames one call takes.
    pub fn maximum_input_frames(&self) -> usize {
        self.maximum_input_frames
    }

    /// Input frames the next call takes.
    pub fn input_frames_next(&self) -> usize {
        self.resampler
            .as_ref()
            .map_or(self.maximum_input_frames, |r| r.input_frames_next())
    }

    /// Output frames by which the bridge delays its input; zero in passthrough.
    pub fn output_delay_frames(&self) -> usize {
        self.resampler
            .as_ref()
            .map_or(0, |resampler| resampler.output_delay())
    }

    /// Scales the ratio of an adjustable bridge by `relative` (within ±2%), ramping over the
    /// next call so the change is inaudible. Does nothing on other bridges. Real-time safe.
    pub fn set_relative_ratio(&mut self, relative: f64) {
        if !self.adjustable {
            return;
        }
        let relative = relative.clamp(1.0 / MAX_RELATIVE_RATIO, MAX_RELATIVE_RATIO);
        if let Some(adjustable) = self
            .resampler
            .as_mut()
            .and_then(|resampler| resampler.as_adjustable())
        {
            let _ = adjustable.set_resample_ratio_relative(relative, true);
        }
    }

    pub fn process<'a>(&'a mut self, input: &'a [f32]) -> &'a [f32] {
        let Some(resampler) = self.resampler.as_mut() else {
            return input;
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

#[derive(Clone, Copy)]
enum BridgeKind {
    /// Fixed ratio; passthrough when the rates match.
    Fixed(FixedSync),
    /// Ratio adjustable at run time.
    Adjustable,
}

#[cfg(test)]
#[allow(
    clippy::unwrap_used,
    reason = "rate bridge tests fail immediately when a supported fixed-rate fixture cannot be built"
)]
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

    #[test]
    fn fixed_output_bridges_produce_whole_blocks() {
        let mut bridge = DeviceRateBridge::with_fixed_output(44_100, 48_000, 2, 256).unwrap();
        let mut produced = 0;
        for _ in 0..20 {
            let input = vec![0.1; bridge.input_frames_next() * 2];
            let output = bridge.process(&input);
            assert_eq!(output.len(), 256 * 2);
            produced += output.len() / 2;
        }
        assert_eq!(produced, 20 * 256);
        let passthrough = DeviceRateBridge::with_fixed_output(48_000, 48_000, 2, 256).unwrap();
        assert_eq!(passthrough.input_frames_next(), 256);
    }

    #[test]
    fn adjustable_bridges_take_more_input_when_the_ratio_is_lowered() {
        let mut bridge = DeviceRateBridge::adjustable_fixed_output(48_000, 48_000, 2, 256).unwrap();
        let consumed = |bridge: &mut DeviceRateBridge| {
            (0..200)
                .map(|_| {
                    let frames = bridge.input_frames_next();
                    assert_eq!(bridge.process(&vec![0.1; frames * 2]).len(), 256 * 2);
                    frames
                })
                .sum::<usize>()
        };
        let nominal = consumed(&mut bridge);
        bridge.set_relative_ratio(0.99);
        let slowed = consumed(&mut bridge);
        assert!(
            slowed > nominal + 200 * 256 / 200,
            "a 1% lower ratio must consume about 1% more input: {nominal} -> {slowed}"
        );
    }

    #[test]
    fn mismatched_rates_preserve_a_continuous_stereo_tone() {
        let input_rate = 44_100_u32;
        let output_rate = 48_000_u32;
        let block_frames = 441_usize;
        let mut bridge = DeviceRateBridge::new(input_rate, output_rate, 2, block_frames).unwrap();
        let mut input = vec![0.0; block_frames * 2];
        let mut output = Vec::new();
        let mut input_frame = 0_usize;

        for _ in 0..100 {
            for frame in input.chunks_exact_mut(2) {
                let phase =
                    std::f32::consts::TAU * 1_000.0 * input_frame as f32 / input_rate as f32;
                let sample = phase.sin() * 0.5;
                frame.copy_from_slice(&[sample, sample]);
                input_frame += 1;
            }
            output.extend_from_slice(bridge.process(&input));
        }

        let settled = &output[4_096.min(output.len())..];
        assert!(settled.len() > output_rate as usize);
        assert!(settled.iter().all(|sample| sample.is_finite()));
        assert!(settled.iter().all(|sample| sample.abs() <= 0.51));
        assert!(
            settled
                .chunks_exact(2)
                .all(|frame| (frame[0] - frame[1]).abs() < 1.0e-6)
        );

        let max_step = settled
            .chunks_exact(2)
            .map(|frame| frame[0])
            .collect::<Vec<_>>()
            .windows(2)
            .map(|pair| (pair[1] - pair[0]).abs())
            .fold(0.0_f32, f32::max);
        assert!(max_step < 0.08, "resampled tone discontinuity: {max_step}");
    }
}
