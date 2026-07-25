use karbeat_macros::karbeat_plugin;

use crate::oscillator::Waveform;


/// A reusable module/component to
/// help creating plugin in which LFO
/// is used
#[derive(Clone, Debug)]
#[karbeat_plugin]
pub struct Lfo {
    /// The waveform type of the LFO
    #[param(
        id="waveform_type",
        name="Waveform Type",
        group="Lfo Main Param",
        default=Waveform::Sine,
    )]
    pub waveform: Waveform,
    
    /// Period of the lfo in seconds
    /// min: 10 ms, max: 10000 ms
    #[param(
        id="period",
        name="Period",
        group="Lfo Main Param",
        min=0.01,
        max=10.0,
        default=0.1,
        step=0.001
    )]
    pub period: f64,

    /// Depth/Amount of the LFO (0.0 = completely off, 1.0 = maximum effect)
    #[param(
        id="depth",
        name="Depth",
        group="Lfo Main Param",
        min=0.0,
        max=1.0,
        default=1.0,
        step=0.01
    )]
    pub depth: f64,

    /// Starting phase of the waveform (0.0 to 1.0)
    #[param(
        id="phase_offset",
        name="Phase Offset",
        group="Lfo Main Param",
        min=0.0,
        max=1.0,
        default=0.0,
        step=0.01
    )]
    pub phase_offset: f64,

    current_phase: f64,
    sample_rate: f32,
}

impl Default for Lfo {
    fn default() -> Self {
        let mut lfo = Self::base_default();
        lfo.current_phase = 0.0;
        lfo.sample_rate = 48000.0;
        lfo
    }
}

impl Lfo {
    pub fn prepare(&mut self, sample_rate: f32) {
        self.sample_rate = sample_rate;
        self.reset();
    }

    pub fn reset(&mut self) {
        self.current_phase = self.phase_offset.get();
    }

    #[inline(always)]
    pub fn tick(&mut self) -> f64{
        let period_sec = self.period.get().max(0.001);
        let phase_inc = 1.0 / (period_sec * self.sample_rate as f64);

        let phase = self.current_phase;

        let tau_f64 = std::f64::consts::TAU;
        let mut val = match self.waveform.get() {
            Waveform::Sine => (phase * tau_f64).sin(),
            Waveform::Saw => {
                if phase < 0.25 {
                    phase * 4.0
                } else if phase < 0.75 {
                    1.0 - (phase - 0.25) * 4.0
                } else {
                    -1.0 + (phase - 0.75) * 4.0
                }
            },
            Waveform::Square => 1.0 - (phase * 2.0),
            Waveform::Triangle => if phase < 0.5 { 1.0 } else { -1.0 },
            Waveform::Noise => {
                fastrand::f64()
            },
        };

        val *= self.depth.get();

        self.current_phase += phase_inc;

        if self.current_phase >= 1.0 {
            self.current_phase -= 1.0;
        }

        val

    }
}
