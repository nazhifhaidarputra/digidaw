//! Biquad filter building block. A general purpose, reusable biquad filter
//! Can be used for things such as Equalizer or Compressor

use karbeat_macros::{ AutoParams, EnumParam };
use karbeat_plugin_types::{ EnumParam, Param };
use smallvec::{ smallvec, SmallVec };

const DEFAULT_CHANNELS: usize = 2;
const DEFAULT_CASCADES: usize = 8;

pub trait FilterMode: Copy + Default + PartialEq + EnumParam {
    /// Get coefficients based on type and current audio parameters
    fn get_coefficients(
        &self,
        freq: f32,
        q: f32,
        gain: f32,
        sample_rate: f32
    ) -> BiquadCoefficients;
    /// Fast check if the filter is completely bypassed
    fn is_off(&self) -> bool;
}

/// Options of Simple filter often used (LPF, HPF, and BPF)
#[derive(Clone, Copy, PartialEq, Debug, Default, EnumParam)]
#[repr(usize)]
pub enum SimpleFilterMode {
    #[default]
    LowPass = 0,
    HighPass = 1,
    BandPass = 2,
    Off = 3,
}

impl From<f32> for SimpleFilterMode {
    fn from(v: f32) -> Self {
        match v as u32 {
            0 => SimpleFilterMode::LowPass,
            1 => SimpleFilterMode::HighPass,
            2 => SimpleFilterMode::BandPass,
            _ => SimpleFilterMode::Off,
        }
    }
}

#[derive(Clone, Copy, PartialEq, Debug, Default, EnumParam)]
#[repr(usize)]
pub enum BiquadFilterType {
    #[default]
    Peaking = 0,
    LowShelf = 1,
    HighShelf = 2,
    LowPass = 3,
    HighPass = 4,
    BandPass = 5,
    Notch = 6,
    Off = 7,
}

impl From<f32> for BiquadFilterType {
    fn from(v: f32) -> Self {
        match v as u32 {
            0 => BiquadFilterType::Peaking,
            1 => BiquadFilterType::LowShelf,
            2 => BiquadFilterType::HighShelf,
            3 => BiquadFilterType::LowPass,
            4 => BiquadFilterType::HighPass,
            5 => BiquadFilterType::BandPass,
            6 => BiquadFilterType::Notch,
            _ => BiquadFilterType::Off,
        }
    }
}

impl FilterMode for SimpleFilterMode {
    #[inline]
    fn is_off(&self) -> bool {
        *self == SimpleFilterMode::Off
    }

    fn get_coefficients(
        &self,
        freq: f32,
        q: f32,
        _gain: f32,
        sample_rate: f32
    ) -> BiquadCoefficients {
        if self.is_off() {
            return BiquadCoefficients::default();
        }

        let w0 = (2.0 * std::f32::consts::PI * freq) / sample_rate;
        let alpha = w0.sin() / (2.0 * q);
        let cos_w0 = w0.cos();

        let (b0, b1, b2, a0, a1, a2) = match self {
            SimpleFilterMode::LowPass => {
                (
                    (1.0 - cos_w0) / 2.0,
                    1.0 - cos_w0,
                    (1.0 - cos_w0) / 2.0,
                    1.0 + alpha,
                    -2.0 * cos_w0,
                    1.0 - alpha,
                )
            }
            SimpleFilterMode::HighPass => {
                (
                    (1.0 + cos_w0) / 2.0,
                    -(1.0 + cos_w0),
                    (1.0 + cos_w0) / 2.0,
                    1.0 + alpha,
                    -2.0 * cos_w0,
                    1.0 - alpha,
                )
            }
            SimpleFilterMode::BandPass => {
                (alpha, 0.0, -alpha, 1.0 + alpha, -2.0 * cos_w0, 1.0 - alpha)
            }
            SimpleFilterMode::Off => unreachable!(),
        };

        let inv_a0 = 1.0 / a0;
        BiquadCoefficients {
            b0: b0 * inv_a0,
            b1: b1 * inv_a0,
            b2: b2 * inv_a0,
            a1: a1 * inv_a0,
            a2: a2 * inv_a0,
        }
    }
}

impl FilterMode for BiquadFilterType {
    #[inline]
    fn is_off(&self) -> bool {
        *self == BiquadFilterType::Off
    }

    fn get_coefficients(
        &self,
        freq: f32,
        q: f32,
        gain: f32,
        sample_rate: f32
    ) -> BiquadCoefficients {
        if self.is_off() {
            return BiquadCoefficients::default();
        }

        let a = (10.0f32).powf(gain / 40.0);
        let w0 = (2.0 * std::f32::consts::PI * freq) / sample_rate;
        let alpha = w0.sin() / (2.0 * q);
        let cos_w0 = w0.cos();

        let (b0, b1, b2, a0, a1, a2) = match self {
            BiquadFilterType::Peaking => {
                (
                    1.0 + alpha * a,
                    -2.0 * cos_w0,
                    1.0 - alpha * a,
                    1.0 + alpha / a,
                    -2.0 * cos_w0,
                    1.0 - alpha / a,
                )
            }
            BiquadFilterType::LowShelf => {
                let two_sqrt_a_alpha = 2.0 * a.sqrt() * alpha;
                (
                    a * (a + 1.0 - (a - 1.0) * cos_w0 + two_sqrt_a_alpha),
                    2.0 * a * (a - 1.0 - (a + 1.0) * cos_w0),
                    a * (a + 1.0 - (a - 1.0) * cos_w0 - two_sqrt_a_alpha),
                    a + 1.0 + (a - 1.0) * cos_w0 + two_sqrt_a_alpha,
                    -2.0 * (a - 1.0 + (a + 1.0) * cos_w0),
                    a + 1.0 + (a - 1.0) * cos_w0 - two_sqrt_a_alpha,
                )
            }
            BiquadFilterType::HighShelf => {
                let two_sqrt_a_alpha = 2.0 * a.sqrt() * alpha;
                (
                    a * (a + 1.0 + (a - 1.0) * cos_w0 + two_sqrt_a_alpha),
                    -2.0 * a * (a - 1.0 + (a + 1.0) * cos_w0),
                    a * (a + 1.0 + (a - 1.0) * cos_w0 - two_sqrt_a_alpha),
                    a + 1.0 - (a - 1.0) * cos_w0 + two_sqrt_a_alpha,
                    2.0 * (a - 1.0 - (a + 1.0) * cos_w0),
                    a + 1.0 - (a - 1.0) * cos_w0 - two_sqrt_a_alpha,
                )
            }
            BiquadFilterType::LowPass => {
                (
                    (1.0 - cos_w0) / 2.0,
                    1.0 - cos_w0,
                    (1.0 - cos_w0) / 2.0,
                    1.0 + alpha,
                    -2.0 * cos_w0,
                    1.0 - alpha,
                )
            }
            BiquadFilterType::HighPass => {
                (
                    (1.0 + cos_w0) / 2.0,
                    -(1.0 + cos_w0),
                    (1.0 + cos_w0) / 2.0,
                    1.0 + alpha,
                    -2.0 * cos_w0,
                    1.0 - alpha,
                )
            }
            BiquadFilterType::BandPass => {
                (alpha, 0.0, -alpha, 1.0 + alpha, -2.0 * cos_w0, 1.0 - alpha)
            }
            BiquadFilterType::Notch => {
                (1.0, -2.0 * cos_w0, 1.0, 1.0 + alpha, -2.0 * cos_w0, 1.0 - alpha)
            }
            BiquadFilterType::Off => unreachable!(),
        };

        let inv_a0 = 1.0 / a0;
        BiquadCoefficients {
            b0: b0 * inv_a0,
            b1: b1 * inv_a0,
            b2: b2 * inv_a0,
            a1: a1 * inv_a0,
            a2: a2 * inv_a0,
        }
    }
}

/// The 5 RBJ Cookbook coefficients for a single biquad stage
#[derive(Clone, Copy, Debug, Default)]
pub struct BiquadCoefficients {
    pub b0: f32,
    pub b1: f32,
    pub b2: f32,
    pub a1: f32,
    pub a2: f32,
}

/// The historical delay lines (x[n-1], x[n-2], y[n-1], y[n-2]) for ONE channel in ONE stage
#[derive(Clone, Copy, Debug, Default)]
pub struct BiquadState {
    pub x1: f32,
    pub x2: f32,
    pub y1: f32,
    pub y2: f32,
}

impl BiquadState {
    #[inline(always)]
    pub fn process(&mut self, input: f32, coeffs: &BiquadCoefficients) -> f32 {
        let output =
            coeffs.b0 * input +
            coeffs.b1 * self.x1 +
            coeffs.b2 * self.x2 -
            coeffs.a1 * self.y1 -
            coeffs.a2 * self.y2;

        // Shift delay lines
        self.x2 = self.x1;
        self.x1 = input;
        self.y2 = self.y1;
        self.y1 = output;

        output
    }
}

/// A filter chain for a SINGLE channel that handles N cascaded biquad stages
#[derive(Clone, Debug)]
pub struct SingleBiquadFilterStage {
    pub stages: SmallVec<[BiquadState; DEFAULT_CASCADES]>,
}

impl SingleBiquadFilterStage {
    pub fn new(num_cascades: usize) -> Self {
        Self {
            stages: smallvec![BiquadState::default(); num_cascades],
        }
    }

    /// Expands or shrinks the number of cascaded stages
    pub fn resize_cascades(&mut self, num_cascades: usize) {
        self.stages.resize(num_cascades, BiquadState::default());
    }

    pub fn reset_state(&mut self) {
        for stage in &mut self.stages {
            *stage = BiquadState::default();
        }
    }

    #[inline(always)]
    pub fn process(&mut self, mut input: f32, coeffs: &BiquadCoefficients) -> f32 {
        // Cascade the signal through all configured biquad stages
        for stage in &mut self.stages {
            input = stage.process(input, coeffs);
        }
        input
    }
}

/// Biquad filter implemented from RBJ EQ Cookbook
#[derive(Clone, Debug, AutoParams)]
pub struct BiquadFilter<T: FilterMode + 'static> {
    pub freq: Param<f32>,
    pub gain: Param<f32>,
    pub q: Param<f32>,
    pub active: Param<bool>,
    pub filter_type: Param<T>,
    pub cascades: Param<f32>,

    // ==========================
    // Internal state
    // ==========================

    #[skip]
    num_of_channels: u8,
    #[skip]
    sample_rate: f32,

    // Internal runtime coefficient (known size at compile Time)
    #[skip]
    coeff: BiquadCoefficients,

    // Multi-channel layout using stacked single-channel filters
    #[skip]
    channels: SmallVec<[SingleBiquadFilterStage; DEFAULT_CHANNELS]>,
}

impl<T: FilterMode + 'static> Default for BiquadFilter<T> {
    fn default() -> Self {
        Self {
            freq: Param::new_f32(0, "Frequency", "Filter", 1000.0, 20.0, 20000.0, 1.0),
            gain: Param::new_f32(1, "Gain", "Filter", 0.0, -24.0, 24.0, 0.1),
            q: Param::new_f32(2, "Q", "Filter", 0.707, 0.1, 10.0, 0.01),
            active: Param::new_bool(3, "Active", "Filter", true),
            filter_type: Param::new_enum(4, "Type", "Filter", T::default()),
            cascades: Param::new_f32(5, "Order", "Filter", 1.0, 1.0, 8.0, 1.0),

            num_of_channels: DEFAULT_CHANNELS as u8,
            sample_rate: 44100.0,
            coeff: BiquadCoefficients::default(),
            channels: smallvec![SingleBiquadFilterStage::new(1); DEFAULT_CHANNELS],
        }
    }
}

impl<T: FilterMode + 'static> BiquadFilter<T> {
    /// Initializes the filter for the current audio stream format
    pub fn prepare(&mut self, num_channels: u8, sample_rate: u32) {
        self.sample_rate = sample_rate as f32;
        self.resize_channels(num_channels as usize);
        self.reset_state();
    }

    /// Expands or shrinks the filter to handle N discrete channels
    pub fn resize_channels(&mut self, new_channels: usize) {
        self.num_of_channels = new_channels as u8;
        let active_cascades = self.cascades.get().max(1.0) as usize;
        self.channels.resize(new_channels, SingleBiquadFilterStage::new(active_cascades));
    }

    /// Expands or shrinks the filter's processing order (cascades)
    pub fn resize_cascades(&mut self, new_cascades: usize) {
        for channel in &mut self.channels {
            channel.resize_cascades(new_cascades);
        }
    }

    /// Clears all historical delay lines (prevents clicking when jumping playhead)
    pub fn reset_state(&mut self) {
        for channel in &mut self.channels {
            channel.reset_state();
        }
    }

    /// Recalculates the coefficients based on current UI parameters.
    /// Call this ONCE per block (or per sample if interpolating).
    pub fn calculate_coefficients(&mut self) {
        if !self.active.get() || self.sample_rate <= 0.0 {
            return;
        }

        let filter_mode = self.filter_type.get();
        if filter_mode.is_off() {
            return;
        }

        // Dynamically resize cascades if the param changed
        let active_cascades = self.cascades.get().max(1.0) as usize;
        if self.channels.first().map_or(0, |ch| ch.stages.len()) != active_cascades {
            self.resize_cascades(active_cascades);
        }

        let freq = self.freq.get().clamp(20.0, self.sample_rate / 2.1); // Nyquist safety
        let q = self.q.get().max(0.01);
        let gain = self.gain.get();

        self.coeff = filter_mode.get_coefficients(freq, q, gain, self.sample_rate);
    }

    /// Process a single multi-channel frame of audio
    #[inline(always)]
    pub fn process_frame(&mut self, frame: &mut [f32]) {
        if !self.active.get() || self.filter_type.get().is_off() {
            return;
        }

        for (ch_idx, sample) in frame
            .iter_mut()
            .enumerate()
            .take(self.num_of_channels as usize) {
            if let Some(channel_filter) = self.channels.get_mut(ch_idx) {
                *sample = channel_filter.process(*sample, &self.coeff);
            }
        }
    }
}
