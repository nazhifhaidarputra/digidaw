#![allow(
    clippy::as_conversions,
    clippy::arithmetic_side_effects,
    clippy::cast_possible_truncation,
    clippy::cast_precision_loss,
    clippy::cast_sign_loss,
    clippy::indexing_slicing,
    reason = "channel and delay indices are bounded by the prepared layout and parameter ranges"
)]

use karbeat_dsp::filter::{BiquadCoefficients, BiquadState, FilterMode, SimpleFilterMode};
use karbeat_macros::{EnumParam, auto_param, karbeat_plugin};
use karbeat_plugin_api::prelude::*;
use karbeat_utils::hash::hash_str;
use serde::{Deserialize, Serialize};

/// Longest Haas delay, in milliseconds.
const MAX_HAAS_MS: f64 = 30.0;
/// Highest sample rate the Haas delay line is sized for before `prepare` resizes it.
const DEFAULT_SAMPLE_RATE: f32 = 48_000.0;
/// Butterworth Q of each of the two bass-mono high-pass stages (24 dB/octave together).
const BUTTERWORTH_Q: f32 = std::f32::consts::FRAC_1_SQRT_2;

/// Which input channels feed the stereo image.
#[derive(Clone, Copy, PartialEq, Debug, Default, EnumParam, Deserialize, Serialize)]
#[repr(usize)]
pub enum StereoSource {
    /// Left and right as they arrive.
    #[default]
    Stereo = 0,
    /// Both channels summed to mono.
    Mono = 1,
    /// The left channel on both sides.
    LeftOnly = 2,
    /// The right channel on both sides.
    RightOnly = 3,
    /// Left and right exchanged.
    Swap = 4,
}

impl From<f32> for StereoSource {
    fn from(v: f32) -> Self {
        match v as u32 {
            1 => Self::Mono,
            2 => Self::LeftOnly,
            3 => Self::RightOnly,
            4 => Self::Swap,
            _ => Self::Stereo,
        }
    }
}

impl StereoSource {
    #[inline(always)]
    fn route(self, left: f32, right: f32) -> (f32, f32) {
        match self {
            Self::Stereo => (left, right),
            Self::Mono => {
                let mono = 0.5 * (left + right);
                (mono, mono)
            }
            Self::LeftOnly => (left, left),
            Self::RightOnly => (right, right),
            Self::Swap => (right, left),
        }
    }
}

/// Mid/side to left/right gains of one block: `left = mid * mid_l + side * side_l`, and the
/// same for right.
#[derive(Clone, Copy, Debug, Default, PartialEq)]
struct ImageMatrix {
    mid_l: f32,
    side_l: f32,
    mid_r: f32,
    side_r: f32,
}

impl ImageMatrix {
    const IDENTITY: Self = Self {
        mid_l: 1.0,
        side_l: 1.0,
        mid_r: 1.0,
        side_r: -1.0,
    };

    #[inline(always)]
    fn lerp(self, to: Self, t: f32) -> Self {
        Self {
            mid_l: self.mid_l + (to.mid_l - self.mid_l) * t,
            side_l: self.side_l + (to.side_l - self.side_l) * t,
            mid_r: self.mid_r + (to.mid_r - self.mid_r) * t,
            side_r: self.side_r + (to.side_r - self.side_r) * t,
        }
    }
}

fn db_to_gain(db: f64) -> f64 {
    10f64.powf(db / 20.0)
}

/// Shapes the stereo image: picks or sums the source channels, splits them into mid and side,
/// and sets width, mid and side level, mono bass, rotation, Haas delay, balance, and polarity.
#[karbeat_plugin]
#[derive(Clone, Debug)]
pub struct DigidawStereoShaper {
    /// Which input channels feed the image.
    #[param(id = "source", name = "Source", group = "Input", default = 0.0)]
    pub source: StereoSource,

    /// Inverts the polarity of the left input.
    #[param(
        id = "invert_left",
        name = "Invert Left",
        group = "Input",
        default = false
    )]
    pub invert_left: bool,

    /// Inverts the polarity of the right input.
    #[param(
        id = "invert_right",
        name = "Invert Right",
        group = "Input",
        default = false
    )]
    pub invert_right: bool,

    /// Side level relative to mid: 0 % is mono, 100 % unchanged, 200 % twice as wide.
    #[param(
        id = "width",
        name = "Width",
        group = "Image",
        default = 1.0,
        min = 0.0,
        max = 2.0,
        step = 0.01
    )]
    pub width: f64,

    /// Level of the mid (centre) signal in dB.
    #[param(
        id = "mid_db",
        name = "Mid",
        group = "Image",
        default = 0.0,
        min = -48.0,
        max = 12.0,
        step = 0.1
    )]
    pub mid_db: f64,

    /// Level of the side (stereo difference) signal in dB.
    #[param(
        id = "side_db",
        name = "Side",
        group = "Image",
        default = 0.0,
        min = -48.0,
        max = 12.0,
        step = 0.1
    )]
    pub side_db: f64,

    /// Turns the image toward one side, in degrees; ±45 places the centre hard left or right.
    #[param(
        id = "rotation",
        name = "Rotation",
        group = "Image",
        default = 0.0,
        min = -45.0,
        max = 45.0,
        step = 0.1
    )]
    pub rotation: f64,

    /// Removes the side signal below the bass-mono frequency, so the low end stays centred.
    #[param(id = "bass_mono", name = "Mono Bass", group = "Bass", default = false)]
    pub bass_mono: bool,

    /// Frequency below which the low end is mono.
    #[param(
        id = "bass_mono_hz",
        name = "Mono Below",
        group = "Bass",
        default = 120.0,
        min = 20.0,
        max = 500.0,
        step = 1.0
    )]
    pub bass_mono_hz: f64,

    /// Haas delay in milliseconds: positive delays the right channel, negative the left.
    #[param(
        id = "haas_ms",
        name = "Haas Delay",
        group = "Space",
        default = 0.0,
        min = -30.0,
        max = 30.0,
        step = 0.01
    )]
    pub haas_ms: f64,

    /// Left/right balance: negative turns the right channel down, positive the left.
    #[param(
        id = "balance",
        name = "Balance",
        group = "Output",
        default = 0.0,
        min = -1.0,
        max = 1.0,
        step = 0.01
    )]
    pub balance: f64,

    /// Output level in dB.
    #[param(
        id = "output_db",
        name = "Output",
        group = "Output",
        default = 0.0,
        min = -24.0,
        max = 12.0,
        step = 0.1
    )]
    pub output_db: f64,

    channels: usize,
    sample_rate: f32,
    /// Matrix the last block ended on; the next block ramps from it.
    matrix: ImageMatrix,
    /// Haas delay the last block ended on, in samples; negative delays the left channel.
    haas_samples: f32,
    /// Ring buffers for the left and right Haas delay.
    haas_lines: [Vec<f32>; 2],
    haas_write: usize,
    bass_coefficients: BiquadCoefficients,
    bass_coefficients_for: f32,
    /// Two high-pass stages on the side signal.
    bass_states: [BiquadState; 2],
}

impl Default for DigidawStereoShaper {
    fn default() -> Self {
        let mut inst = Self::base_default();
        inst.channels = 2;
        inst.sample_rate = DEFAULT_SAMPLE_RATE;
        inst.matrix = ImageMatrix::IDENTITY;
        inst.bass_coefficients = BiquadCoefficients::BYPASS;
        inst.allocate_haas(DEFAULT_SAMPLE_RATE);
        inst
    }
}

impl DigidawStereoShaper {
    fn allocate_haas(&mut self, sample_rate: f32) {
        let len = (MAX_HAAS_MS * 0.001 * f64::from(sample_rate)).ceil() as usize + 2;
        for line in &mut self.haas_lines {
            line.clear();
            line.resize(len, 0.0);
        }
        self.haas_write = 0;
    }

    /// Mid/side to left/right gains for the current parameters.
    fn target_matrix(&self) -> ImageMatrix {
        let width = self.width.get().clamp(0.0, 2.0);
        let mid = db_to_gain(self.mid_db.get());
        let side = db_to_gain(self.side_db.get()) * width;
        // Positive rotation turns the image to the right.
        let angle = -self.rotation.get().clamp(-45.0, 45.0).to_radians();
        let (sin, cos) = angle.sin_cos();
        let output = db_to_gain(self.output_db.get());
        let balance = self.balance.get().clamp(-1.0, 1.0);
        let left = output * (1.0 - balance).min(1.0);
        let right = output * (1.0 + balance).min(1.0);
        // Gains, then a rotation of the (mid, side) plane, then back to left and right.
        ImageMatrix {
            mid_l: (left * (cos + sin) * mid) as f32,
            side_l: (left * (cos - sin) * side) as f32,
            mid_r: (right * (cos - sin) * mid) as f32,
            side_r: (-right * (cos + sin) * side) as f32,
        }
    }

    fn target_haas_samples(&self) -> f32 {
        let ms = self.haas_ms.get().clamp(-MAX_HAAS_MS, MAX_HAAS_MS);
        (ms * 0.001 * f64::from(self.sample_rate)) as f32
    }

    fn update_bass_filter(&mut self) {
        let freq = self.bass_mono_hz.get().clamp(20.0, 500.0) as f32;
        if (freq - self.bass_coefficients_for).abs() < 0.01 {
            return;
        }
        self.bass_coefficients_for = freq;
        self.bass_coefficients =
            SimpleFilterMode::HighPass.get_coefficients(freq, BUTTERWORTH_Q, 0.0, self.sample_rate);
    }

    /// Reads `line` `delay` samples behind the write position, interpolating between samples.
    #[inline(always)]
    fn read_delayed(line: &[f32], write: usize, delay: f32) -> f32 {
        let len = line.len();
        let delay = delay.clamp(0.0, (len - 2) as f32);
        let whole = delay as usize;
        let fraction = delay - whole as f32;
        let newer = line[(write + len - whole) % len];
        let older = line[(write + len - whole - 1) % len];
        newer + (older - newer) * fraction
    }

    fn process_stereo(&mut self, left: &mut [f32], right: &mut [f32]) {
        let frames = left.len().min(right.len());
        if frames == 0 {
            return;
        }
        let source = self.source.get();
        let left_sign = if self.invert_left.get() { -1.0 } else { 1.0 };
        let right_sign = if self.invert_right.get() { -1.0 } else { 1.0 };
        let bass_mono = self.bass_mono.get();
        if bass_mono {
            self.update_bass_filter();
        }

        let from = self.matrix;
        let to = self.target_matrix();
        let haas_from = self.haas_samples;
        let haas_to = self.target_haas_samples();
        let use_haas = haas_from != 0.0 || haas_to != 0.0;
        let line_len = self.haas_lines[0].len();
        let step = 1.0 / frames as f32;

        for frame in 0..frames {
            let t = (frame + 1) as f32 * step;
            let (l, r) = source.route(left[frame] * left_sign, right[frame] * right_sign);
            let mid = 0.5 * (l + r);
            let mut side = 0.5 * (l - r);
            if bass_mono {
                for state in &mut self.bass_states {
                    side = state.process(side, &self.bass_coefficients);
                }
            }
            let matrix = from.lerp(to, t);
            let mut out_l = mid * matrix.mid_l + side * matrix.side_l;
            let mut out_r = mid * matrix.mid_r + side * matrix.side_r;

            if use_haas && line_len > 2 {
                let write = self.haas_write;
                self.haas_lines[0][write] = out_l;
                self.haas_lines[1][write] = out_r;
                let haas = haas_from + (haas_to - haas_from) * t;
                if haas > 0.0 {
                    out_r = Self::read_delayed(&self.haas_lines[1], write, haas);
                } else if haas < 0.0 {
                    out_l = Self::read_delayed(&self.haas_lines[0], write, -haas);
                }
                self.haas_write = (write + 1) % line_len;
            }

            left[frame] = out_l;
            right[frame] = out_r;
        }

        self.matrix = to;
        if !bass_mono {
            self.bass_states = [BiquadState::default(); 2];
        }
        if !use_haas {
            // An idle delay line holds stale audio; start it from silence when it returns.
            self.haas_lines.iter_mut().for_each(|line| line.fill(0.0));
            self.haas_write = 0;
        }
        self.haas_samples = haas_to;
    }
}

#[auto_param]
impl AudioPlugin for DigidawStereoShaper {
    fn name(&self) -> &str {
        "DigiDAW Stereo Shaper"
    }

    fn category(&self) -> PluginCategory {
        PluginCategory::Effect
    }

    fn prepare(&mut self, sample_rate: f32, _max_buffer_size: usize) {
        self.sample_rate = sample_rate.max(1.0);
        self.allocate_haas(self.sample_rate);
        self.bass_coefficients_for = 0.0;
        self.reset();
    }

    fn reset(&mut self) {
        self.bass_states = [BiquadState::default(); 2];
        self.haas_lines.iter_mut().for_each(|line| line.fill(0.0));
        self.haas_write = 0;
    }

    fn settle_parameters(&mut self) {
        self.matrix = self.target_matrix();
        self.haas_samples = self.target_haas_samples();
    }

    fn set_io_layout(&mut self, inputs: &[BusConfig], _outputs: &[BusConfig]) {
        self.channels = inputs.first().map_or(2, |bus| bus.channel_count);
    }

    fn tail_samples(&self) -> u32 {
        (MAX_HAAS_MS * 0.001 * f64::from(self.sample_rate)).ceil() as u32
    }

    fn process(&mut self, buffers: &mut AudioBuffers, _context: &ProcessContext) {
        let Some(input) = buffers.main_inputs.first_mut() else {
            return;
        };
        let Some(output) = buffers.main_outputs.first_mut() else {
            return;
        };
        let channels = input.channel_data.len().min(output.channel_data.len());
        if channels == 0 {
            return;
        }
        for (source, destination) in input
            .channel_data
            .iter()
            .zip(output.channel_data.iter_mut())
        {
            let frames = source.len().min(destination.len());
            destination[..frames].copy_from_slice(&source[..frames]);
        }

        if channels >= 2 {
            let (left, rest) = output.channel_data.split_at_mut(1);
            self.process_stereo(left[0], rest[0]);
            // Channels past the stereo pair only follow the output level.
            let gain = db_to_gain(self.output_db.get()) as f32;
            for channel in rest.iter_mut().skip(1) {
                channel.iter_mut().for_each(|sample| *sample *= gain);
            }
        } else {
            // A mono input has no image to shape: polarity and output level still apply.
            let sign = if self.invert_left.get() { -1.0 } else { 1.0 };
            let gain = db_to_gain(self.output_db.get()) as f32 * sign;
            output.channel_data[0]
                .iter_mut()
                .for_each(|sample| *sample *= gain);
        }
    }
}

impl AudioPluginBuilder for DigidawStereoShaper {
    fn build() -> Self {
        Self::default()
    }
}

impl Manifestable for DigidawStereoShaper {
    fn build_manifest() -> PluginManifest {
        PluginManifest {
            id: hash_str("effect_stereo_shaper"),
            id_string: "effect_stereo_shaper".to_string(),
            name: "DigiDAW Stereo Shaper".to_string(),
            internal_type: "DigidawStereoShaper".to_string(),
            is_synth: false,
            parameters: Self::static_parameter_specs(),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn context() -> ProcessContext<'static> {
        ProcessContext {
            bpm: 120.0,
            time_sig_numerator: 4,
            time_sig_denominator: 4,
            is_playing: true,
            is_recording: false,
            mode: ProcessingMode::Realtime,
            project_time_seconds: 0.0,
            project_time_samples: 0,
            beat_position: 0.0,
            bar_position: 0.0,
            loop_start_beat: None,
            loop_end_beat: None,
            midi_events: &[],
            param_changes: &[],
        }
    }

    /// Runs one block and returns the left and right output.
    fn run(plugin: &mut DigidawStereoShaper, left: &[f32], right: &[f32]) -> (Vec<f32>, Vec<f32>) {
        let mut in_l = left.to_vec();
        let mut in_r = right.to_vec();
        let mut out_l = vec![0.0; left.len()];
        let mut out_r = vec![0.0; right.len()];
        let mut inputs: [&mut [f32]; 2] = [&mut in_l, &mut in_r];
        let mut outputs: [&mut [f32]; 2] = [&mut out_l, &mut out_r];
        let mut main_inputs = [AudioBusBuffer {
            channel_data: &mut inputs,
            is_silent: false,
        }];
        let mut main_outputs = [AudioBusBuffer {
            channel_data: &mut outputs,
            is_silent: false,
        }];
        let mut buffers = AudioBuffers {
            main_inputs: &mut main_inputs,
            main_outputs: &mut main_outputs,
            aux_inputs: &mut [],
            aux_outputs: &mut [],
        };
        plugin.process(&mut buffers, &context());
        (out_l, out_r)
    }

    fn settled() -> DigidawStereoShaper {
        let mut plugin = DigidawStereoShaper::default();
        plugin.prepare(1000.0, 64);
        plugin
    }

    fn assert_close(actual: &[f32], expected: &[f32]) {
        for (a, e) in actual.iter().zip(expected) {
            assert!((a - e).abs() < 1e-4, "{actual:?} != {expected:?}");
        }
    }

    #[test]
    fn default_settings_pass_audio_through() {
        let mut plugin = settled();
        plugin.settle_parameters();
        let (l, r) = run(&mut plugin, &[0.5, -0.25, 1.0], &[0.1, 0.2, -0.3]);
        assert_close(&l, &[0.5, -0.25, 1.0]);
        assert_close(&r, &[0.1, 0.2, -0.3]);
    }

    #[test]
    fn zero_width_folds_the_image_to_mono() {
        let mut plugin = settled();
        plugin.width.set_base(0.0);
        plugin.settle_parameters();
        let (l, r) = run(&mut plugin, &[1.0, 0.0], &[0.0, 1.0]);
        assert_close(&l, &[0.5, 0.5]);
        assert_close(&r, &[0.5, 0.5]);
    }

    #[test]
    fn source_modes_pick_and_swap_channels() {
        let mut plugin = settled();
        plugin.source.set_base(StereoSource::Swap);
        plugin.settle_parameters();
        let (l, r) = run(&mut plugin, &[1.0], &[0.25]);
        assert_close(&l, &[0.25]);
        assert_close(&r, &[1.0]);

        plugin.source.set_base(StereoSource::LeftOnly);
        let (l, r) = run(&mut plugin, &[1.0], &[0.25]);
        assert_close(&l, &[1.0]);
        assert_close(&r, &[1.0]);
    }

    #[test]
    fn full_rotation_places_the_centre_on_one_side() {
        let mut plugin = settled();
        plugin.rotation.set_base(45.0);
        plugin.settle_parameters();
        let (l, r) = run(&mut plugin, &[1.0], &[1.0]);
        assert_close(&l, &[0.0]);
        assert_close(&r, &[std::f32::consts::SQRT_2]);
    }

    #[test]
    fn haas_delay_holds_back_one_channel() {
        let mut plugin = settled();
        plugin.haas_ms.set_base(2.0); // two samples at 1 kHz
        plugin.settle_parameters();
        let (l, r) = run(&mut plugin, &[1.0, 0.0, 0.0, 0.0], &[1.0, 0.0, 0.0, 0.0]);
        assert_close(&l, &[1.0, 0.0, 0.0, 0.0]);
        assert_close(&r, &[0.0, 0.0, 1.0, 0.0]);
    }

    #[test]
    fn mono_bass_removes_low_side_content() {
        let mut plugin = DigidawStereoShaper::default();
        plugin.prepare(48_000.0, 4800);
        plugin.bass_mono.set_base(true);
        plugin.bass_mono_hz.set_base(200.0);
        plugin.settle_parameters();
        // 40 Hz, fully out of phase: pure side signal well below the cutoff.
        let left: Vec<f32> = (0..4800)
            .map(|n| (std::f32::consts::TAU * 40.0 * n as f32 / 48_000.0).sin())
            .collect();
        let right: Vec<f32> = left.iter().map(|sample| -sample).collect();
        let (l, _) = run(&mut plugin, &left, &right);
        let peak = l[2400..].iter().fold(0.0f32, |max, s| max.max(s.abs()));
        assert!(
            peak < 0.1,
            "side bass should be mostly removed, peak {peak}"
        );
    }

    #[test]
    fn a_parameter_change_ramps_instead_of_jumping() {
        let mut plugin = settled();
        plugin.settle_parameters();
        plugin.output_db.set_base(-24.0);
        let (l, _) = run(&mut plugin, &[1.0; 4], &[1.0; 4]);
        let target = db_to_gain(-24.0) as f32;
        // The first sample is still near unity; the block ends on the new level.
        assert!(l[0] > 0.7, "{l:?}");
        assert!((l[3] - target).abs() < 1e-4, "{l:?}");
    }
}
