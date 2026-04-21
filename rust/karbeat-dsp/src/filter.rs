//! Biquad filter building block. A general purpose, reusable biquad filter
//! Can be used for things such as Equalizer or Compressor

use karbeat_macros::{AutoParams, EnumParam};
use karbeat_plugin_types::Param;

const MAX_CHANNELS: usize = 2;
const MAX_CASCADES: usize = 4;

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
        let output = coeffs.b0 * input 
                   + coeffs.b1 * self.x1 
                   + coeffs.b2 * self.x2
                   - coeffs.a1 * self.y1 
                   - coeffs.a2 * self.y2;

        // Shift delay lines
        self.x2 = self.x1;
        self.x1 = input;
        self.y2 = self.y1;
        self.y1 = output;

        output
    }
}

/// Biquad filter implemented from RBJ EQ Cookbook
#[derive(Clone, Debug, AutoParams)]
pub struct BiquadFilter {
    pub freq: Param<f32>,
    pub gain: Param<f32>,
    pub q: Param<f32>,
    pub active: Param<bool>,
    pub filter_type: Param<SimpleFilterMode>,
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

    // Cascaded Biquad State
    #[skip]
    state: [[BiquadState; MAX_CASCADES]; MAX_CHANNELS],
}

impl Default for BiquadFilter {
    fn default() -> Self {
        Self {
            freq: Param::new_f32(0, "Frequency", "Filter", 1000.0, 20.0, 20000.0, 1.0),
            gain: Param::new_f32(1, "Gain", "Filter", 0.0, -24.0, 24.0, 0.1),
            q: Param::new_f32(2, "Q", "Filter", 0.707, 0.1, 10.0, 0.01),
            active: Param::new_bool(3, "Active", "Filter", true),
            filter_type: Param::new_enum(4, "Type", "Filter", SimpleFilterMode::LowPass),
            cascades: Param::new_f32(5, "Order", "Filter", 1.0, 1.0, MAX_CASCADES as f32, 1.0),
            
            num_of_channels: 2,
            sample_rate: 44100.0,
            coeff: BiquadCoefficients::default(),
            state: [[BiquadState::default(); MAX_CASCADES]; MAX_CHANNELS],
        }
    }
}

impl BiquadFilter {
    /// Initializes the filter for the current audio stream format
    pub fn prepare(&mut self, num_channels: u8, sample_rate: u32) {
        self.num_of_channels = num_channels.min(MAX_CHANNELS as u8);
        self.sample_rate = sample_rate as f32;
        self.reset_state();
    }

    /// Clears all historical delay lines (prevents clicking when jumping playhead)
    pub fn reset_state(&mut self) {
        self.state = [[BiquadState::default(); MAX_CASCADES]; MAX_CHANNELS];
    }

    /// Recalculates the coefficients based on current UI parameters.
    /// Call this ONCE per block (or per sample if interpolating).
    pub fn calculate_coefficients(&mut self) {
        if !self.active.get() || self.sample_rate <= 0.0 {
            return;
        }

        let filter_mode = self.filter_type.get();
        if filter_mode == SimpleFilterMode::Off {
            return;
        }

        let freq = self.freq.get().clamp(20.0, self.sample_rate / 2.1); // Nyquist safety
        let q = self.q.get().max(0.01);
        
        let w0 = 2.0 * std::f32::consts::PI * freq / self.sample_rate;
        let alpha = w0.sin() / (2.0 * q);
        let cos_w0 = w0.cos();

        let (b0, b1, b2, a0, a1, a2);

        match filter_mode {
            SimpleFilterMode::LowPass => {
                b0 = (1.0 - cos_w0) / 2.0;
                b1 = 1.0 - cos_w0;
                b2 = (1.0 - cos_w0) / 2.0;
                a0 = 1.0 + alpha;
                a1 = -2.0 * cos_w0;
                a2 = 1.0 - alpha;
            }
            SimpleFilterMode::HighPass => {
                b0 = (1.0 + cos_w0) / 2.0;
                b1 = -(1.0 + cos_w0);
                b2 = (1.0 + cos_w0) / 2.0;
                a0 = 1.0 + alpha;
                a1 = -2.0 * cos_w0;
                a2 = 1.0 - alpha;
            }
            SimpleFilterMode::BandPass => {
                b0 = alpha;
                b1 = 0.0;
                b2 = -alpha;
                a0 = 1.0 + alpha;
                a1 = -2.0 * cos_w0;
                a2 = 1.0 - alpha;
            }
            SimpleFilterMode::Off => unreachable!(),
        }

        // Pre-divide by a0 for maximum performance in the audio loop
        let inv_a0 = 1.0 / a0;
        self.coeff= BiquadCoefficients {
            b0: b0 * inv_a0,
            b1: b1 * inv_a0,
            b2: b2 * inv_a0,
            a1: a1 * inv_a0,
            a2: a2 * inv_a0,
        };
    }

    /// Process a single multi-channel frame of audio
    #[inline(always)]
    pub fn process_frame(&mut self, frame: &mut [f32]) {
        if !self.active.get() || self.filter_type.get() == SimpleFilterMode::Off {
            return;
        }

        let num_cascades = self.cascades.get() as usize;
        let active_cascades = num_cascades.clamp(1, MAX_CASCADES);

        // Process each channel independently
        for (ch_idx, sample) in frame.iter_mut().enumerate().take(self.num_of_channels as usize) {
            let mut current_sample = *sample;

            // Cascade the signal through the required number of biquad stages
            for stage_idx in 0..active_cascades {
                current_sample = self.state[ch_idx][stage_idx].process(
                    current_sample, 
                    &self.coeff
                );
            }

            *sample = current_sample;
        }
    }
}