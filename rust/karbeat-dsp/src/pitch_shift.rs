//! Real-time pitch shifting.
//!
//! [`PitchShiftEngine`] adapts the fixed-block [`DefaultLivePitchShifter`] to the engine's
//! variable callback sizes by staging one block: input is captured into a block buffer and
//! replaced by the previous block's output, so the result is independent of the callback size
//! at the cost of one block of extra latency. The shifter itself is chosen by the
//! [`LivePitchShifter`] alias in [`crate::stretcher`].

#![allow(
    clippy::as_conversions,
    reason = "latency reports convert frame counts to the plugin API's u32"
)]

use karbeat_macros::karbeat_plugin;

use crate::stretcher::{DefaultLivePitchShifter, LivePitchShifter};

/// Fallback block size, used for the latency report until a shifter has been prepared.
pub const GRAIN_SIZE: usize = 512;

/// Highest channel count the engine stages.
const MAX_CHANNELS: usize = 8;

/// Pitch-shifting engine with staging for arbitrary callback sizes.
#[derive(Debug)]
#[karbeat_plugin]
pub struct PitchShiftEngine {
    #[param(
        id = "pitch_ratio",
        name = "Pitch Ratio",
        group = "Pitcher",
        min = 0.25,
        max = 4.0,
        default = 1.0,
        step = 0.001
    )]
    pub pitch_ratio: f32,

    #[param(
        id = "preserve_formants",
        name = "Preserve Formants",
        group = "Pitcher",
        default = false
    )]
    pub preserve_formants: bool,

    /// The underlying shifter, created during prepare().
    shifter: Option<DefaultLivePitchShifter>,

    /// Sample rate captured at `prepare()`.
    sample_rate: u32,

    /// Active channel count.
    channels: usize,

    /// Internal staging buffers for channels whose block size doesn't align
    /// with the audio engine's buffer size.
    input_staging: Vec<Vec<f32>>,
    output_staging: Vec<Vec<f32>>,

    /// How many valid samples are sitting in `input_staging`.
    staging_fill: usize,

    last_pitch_ratio: f64,
    last_preserve_formants: bool,
}

impl Clone for PitchShiftEngine {
    fn clone(&self) -> Self {
        // The shifter owns native state and is not Clone; the clone builds its own on prepare.
        let mut e = Self::base_default();
        e.pitch_ratio = self.pitch_ratio.clone();
        e.sample_rate = self.sample_rate;
        e.preserve_formants = self.preserve_formants.clone();
        e.channels = self.channels;
        e
    }
}

impl Default for PitchShiftEngine {
    fn default() -> Self {
        let mut def = Self::base_default();
        def.shifter = None;
        def.sample_rate = 44100;
        def.channels = 2;
        def.input_staging = Vec::new();
        def.output_staging = Vec::new();
        def.staging_fill = 0;
        def.last_pitch_ratio = -1.0;
        def.last_preserve_formants = false;
        def
    }
}

impl PitchShiftEngine {
    // ================================================
    // Public interface
    // ================================================

    /// Called by the plugin when the sample rate or channel count is known.
    pub fn prepare(&mut self, sample_rate: f32, channels: usize) {
        let sr = sample_rate as u32;
        let channels = channels.clamp(1, MAX_CHANNELS);

        let pf = self.preserve_formants.get();

        // Rebuild the shifter if config changed.
        let needs_rebuild =
            self.shifter.is_none() || self.channels != channels || self.sample_rate != sr;

        if needs_rebuild {
            self.sample_rate = sr;
            self.channels = channels;
            self.last_preserve_formants = pf;
            self.shifter = match DefaultLivePitchShifter::new(sr, channels, pf) {
                Ok(shifter) => Some(shifter),
                Err(error) => {
                    log::error!("Pitch shifter unavailable: {error}");
                    None
                }
            };
            self.last_pitch_ratio = -1.0;

            let block = self.shifter_block_size();
            self.input_staging = vec![vec![0.0_f32; block]; channels];

            self.output_staging = vec![vec![0.0; block]; channels];
            self.staging_fill = 0;
        }
        self.update_parameters();
    }

    fn update_parameters(&mut self) {
        if let Some(shifter) = &mut self.shifter {
            let ratio = f64::from(self.pitch_ratio.get());
            if ratio != self.last_pitch_ratio {
                shifter.set_pitch_scale(ratio);
                self.last_pitch_ratio = ratio;
            }
            let preserve = self.preserve_formants.get();
            if preserve != self.last_preserve_formants {
                shifter.set_preserve_formants(preserve);
                self.last_preserve_formants = preserve;
            }
        }
    }

    /// Process audio in place with one fixed block of staging delay.
    /// The engine must be prepared for the supplied channel count first.
    pub fn process_block(&mut self, channels_data: &mut [&mut [f32]]) {
        if channels_data.is_empty() || self.shifter.is_none() {
            return;
        }
        let num_frames = channels_data[0].len();
        if channels_data.len() != self.channels
            || channels_data.iter().any(|ch| ch.len() != num_frames)
        {
            return;
        }
        self.update_parameters();
        let block = self.shifter_block_size();
        let mut pos = 0;
        while pos < num_frames {
            let count = (block - self.staging_fill).min(num_frames - pos);
            let end = self.staging_fill + count;
            for (ch, data) in channels_data.iter_mut().enumerate() {
                // Capture input before replacing it with the previous block's output.
                self.input_staging[ch][self.staging_fill..end]
                    .copy_from_slice(&data[pos..pos + count]);
                data[pos..pos + count]
                    .copy_from_slice(&self.output_staging[ch][self.staging_fill..end]);
            }
            self.staging_fill = end;
            pos += count;
            if self.staging_fill == block {
                if let Some(shifter) = &mut self.shifter {
                    // Staging buffers are sized to the block and channel count at prepare().
                    shifter
                        .shift(&self.input_staging, &mut self.output_staging)
                        .ok();
                }
                self.staging_fill = 0;
            }
        }
    }

    /// Returns the shifter delay plus one block of staging latency.
    pub fn latency_samples(&self) -> u32 {
        self.shifter
            .as_ref()
            .map(|s| (s.latency() + s.block_size()) as u32)
            .unwrap_or(GRAIN_SIZE as u32)
    }

    /// Reset all internal state.
    pub fn reset(&mut self) {
        if let Some(s) = &mut self.shifter {
            s.reset();
        }
        for buf in &mut self.input_staging {
            buf.fill(0.0);
        }
        for buf in &mut self.output_staging {
            buf.fill(0.0);
        }
        self.staging_fill = 0;
    }

    // ------------------------------------------------------------------
    // Private helpers
    // ------------------------------------------------------------------

    fn shifter_block_size(&self) -> usize {
        self.shifter
            .as_ref()
            .map(|s| s.block_size())
            .unwrap_or(GRAIN_SIZE)
    }
}

#[cfg(test)]
#[allow(
    clippy::unwrap_used,
    reason = "test setup requires a live pitch shifter"
)]
mod tests {
    use super::*;
    use karbeat_plugin_types::parameter::AutoParams;

    fn render(input: &[f32], sizes: &[usize], ratio: f32) -> Vec<f32> {
        let mut engine = PitchShiftEngine::default();
        engine.pitch_ratio.set_base(ratio);
        engine.prepare(48000.0, 1);
        assert!(engine.shifter.is_some());
        let mut output = input.to_vec();
        let mut pos = 0;
        for size in sizes.iter().cycle() {
            if pos == output.len() {
                break;
            }
            let end = (pos + size).min(output.len());
            engine.process_block(&mut [&mut output[pos..end]]);
            pos = end;
        }
        output
    }

    #[test]
    fn output_is_independent_of_callback_size() {
        let input: Vec<f32> = (0..24000)
            .map(|i| (i as f32 * 0.057).sin() * 0.25)
            .collect();
        for ratio in [0.25, 0.75, 1.0, 1.005, 1.5, 4.0] {
            let expected = render(&input, &[512], ratio);
            for sizes in [&[128][..], &[700][..], &[1, 63, 511, 1024, 37][..]] {
                let actual = render(&input, sizes, ratio);
                let error = actual
                    .iter()
                    .zip(&expected)
                    .map(|(a, b)| (a - b).abs())
                    .fold(0.0_f32, f32::max);
                assert!(
                    error < 1e-6,
                    "ratio {ratio}, sizes {sizes:?}: error {error}"
                );
            }
        }
    }

    #[test]
    fn pitch_ratio_spans_two_octaves_each_way() {
        let engine = PitchShiftEngine::default();
        let spec = engine
            .auto_get_parameter_specs(karbeat_utils::hash::FNV_OFFSET, "")
            .into_iter()
            .find(|spec| spec.path.ends_with("pitch_ratio"))
            .unwrap();
        for (actual, expected) in [(spec.min, 0.25), (spec.max, 4.0), (spec.step, 0.001)] {
            assert!((actual - expected).abs() < 1e-6, "{actual} != {expected}");
        }
        assert_eq!(engine.pitch_ratio.get(), 1.0);
    }

    #[test]
    fn staged_stereo_matches_direct_shifter_through_silence() {
        let mut engine = PitchShiftEngine::default();
        engine.pitch_ratio.set_base(0.75);
        engine.prepare(48000.0, 2);
        let mut direct = DefaultLivePitchShifter::new(48000, 2, false).unwrap();
        direct.set_pitch_scale(0.75);
        let block = direct.block_size();
        assert_eq!(engine.latency_samples() as usize, direct.latency() + block);
        let frames = block * 48;
        let input: Vec<Vec<f32>> = (0..2)
            .map(|ch| {
                (0..frames)
                    .map(|i| {
                        if (block * 8..block * 32).contains(&i) {
                            0.0
                        } else {
                            (i as f32 * (0.057 + ch as f32 * 0.021)).sin() * 0.25
                        }
                    })
                    .collect()
            })
            .collect();
        let mut expected = vec![vec![0.0; frames]; 2];
        let mut source = vec![vec![0.0; block]; 2];
        let mut shifted = vec![vec![0.0; block]; 2];
        for pos in (0..frames - block).step_by(block) {
            for ch in 0..2 {
                source[ch].copy_from_slice(&input[ch][pos..pos + block]);
            }
            direct.shift(&source, &mut shifted).unwrap();
            for ch in 0..2 {
                expected[ch][pos + block..pos + 2 * block].copy_from_slice(&shifted[ch]);
            }
        }
        let mut actual = input.clone();
        let (left, right) = actual.split_at_mut(1);
        for (l, r) in left[0].chunks_mut(137).zip(right[0].chunks_mut(137)) {
            engine.process_block(&mut [l, r]);
        }
        for ch in 0..2 {
            for (a, b) in actual[ch].iter().zip(&expected[ch]) {
                assert!((a - b).abs() < 1e-6);
            }
        }
        engine.reset();
        let mut silent = vec![0.0; frames];
        let mut silent_right = silent.clone();
        engine.process_block(&mut [&mut silent, &mut silent_right]);
        assert!(silent.iter().chain(&silent_right).all(|s| s.abs() < 1e-6));
    }

    #[test]
    fn unity_impulse_matches_reported_latency() {
        let mut engine = PitchShiftEngine::default();
        engine.prepare(48000.0, 1);
        let latency = engine.latency_samples() as usize;
        let mut audio = vec![0.0; latency + 4096];
        audio[0] = 1.0;
        for chunk in audio.chunks_mut(137) {
            engine.process_block(&mut [chunk]);
        }
        let peak = audio
            .iter()
            .enumerate()
            .max_by(|(_, a), (_, b)| a.abs().total_cmp(&b.abs()))
            .map(|(index, _)| index)
            .unwrap();
        assert_eq!(peak, latency);
        assert!(audio[peak] > 0.5);
    }

    #[test]
    fn parameter_changes_keep_prepared_buffers_and_apply_fine_pitch() {
        let mut engine = PitchShiftEngine::default();
        engine.prepare(48000.0, 1);
        let input = engine.input_staging[0].as_ptr();
        let output = engine.output_staging[0].as_ptr();
        engine.pitch_ratio.set_base(1.005);
        engine.preserve_formants.set_base(true);
        engine.process_block(&mut [&mut [0.25; 128]]);
        assert!(engine.shifter.is_some());
        assert_eq!(engine.input_staging[0].as_ptr(), input);
        assert_eq!(engine.output_staging[0].as_ptr(), output);
        assert_eq!(engine.last_pitch_ratio, f64::from(engine.pitch_ratio.get()));
        assert!(engine.last_preserve_formants);
        assert_eq!(engine.staging_fill, 128);
    }
}
