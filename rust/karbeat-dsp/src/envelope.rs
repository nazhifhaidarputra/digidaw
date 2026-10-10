// ============================================================================
// ENVELOPE (envelope.rs)
// ============================================================================

use karbeat_macros::karbeat_plugin;
use serde::{Deserialize, Serialize};

/// A common trait for any envelope settings struct.
/// Allows the AdsrProcessor to process both standard and advanced envelopes.
pub trait Envelope {
    fn attack_ms(&self) -> f32;
    fn decay_ms(&self) -> f32;
    fn sustain_level(&self) -> f32;
    fn release_ms(&self) -> f32;

    // Default implementation returns 1.0, but advanced envelopes can override this
    fn peak_level(&self) -> f32 {
        1.0
    }
}

/// Standard ADSR envelope settings
#[derive(Clone, Debug)]
#[karbeat_plugin]
pub struct EnvelopeSettings {
    #[param(
        id = "attack",
        name = "Attack",
        group = "Envelope",
        min = 1.0,
        max = 10000.0,
        default = 10.0,
        step = 1.0
    )]
    pub attack_ms: f32,

    #[param(
        id = "decay",
        name = "Decay",
        group = "Envelope",
        min = 1.0,
        max = 10000.0,
        default = 200.0,
        step = 1.0
    )]
    pub decay_ms: f32,

    #[param(
        id = "sustain",
        name = "Sustain",
        group = "Envelope",
        min = 0.0,
        max = 1.0,
        default = 0.7,
        step = 0.01
    )]
    pub sustain_level: f32,

    #[param(
        id = "release",
        name = "Release",
        group = "Envelope",
        min = 1.0,
        max = 10000.0,
        default = 500.0,
        step = 1.0
    )]
    pub release_ms: f32,
}

impl Default for EnvelopeSettings {
    fn default() -> Self {
        Self::new("Envelope")
    }
}

impl EnvelopeSettings {
    pub fn new(group: &str) -> Self {
        let mut env = Self::base_default();
        let g = group.to_string();
        env.attack_ms.group = g.clone();
        env.decay_ms.group = g.clone();
        env.sustain_level.group = g.clone();
        env.release_ms.group = g;
        env
    }
}

impl Envelope for EnvelopeSettings {
    fn attack_ms(&self) -> f32 {
        self.attack_ms.get()
    }
    fn decay_ms(&self) -> f32 {
        self.decay_ms.get()
    }
    fn sustain_level(&self) -> f32 {
        self.sustain_level.get()
    }
    fn release_ms(&self) -> f32 {
        self.release_ms.get()
    }
}

/// Advanced DAHDSR envelope settings with adjustable curve tensions
#[derive(Clone, Debug)]
#[karbeat_plugin]
pub struct AdvancedEnvelopeSettings {
    #[param(
        id = "delay",
        name = "Delay",
        group = "Envelope",
        min = 0.0,
        max = 5000.0,
        default = 0.0,
        step = 1.0
    )]
    pub delay_ms: f32,

    #[param(
        id = "attack",
        name = "Attack",
        group = "Envelope",
        min = 1.0,
        max = 10000.0,
        default = 10.0,
        step = 1.0
    )]
    pub attack_ms: f32,

    #[param(
        id = "hold",
        name = "Hold",
        group = "Envelope",
        min = 0.0,
        max = 5000.0,
        default = 0.0,
        step = 1.0
    )]
    pub hold_ms: f32,

    #[param(
        id = "decay",
        name = "Decay",
        group = "Envelope",
        min = 1.0,
        max = 10000.0,
        default = 200.0,
        step = 1.0
    )]
    pub decay_ms: f32,

    #[param(
        id = "release",
        name = "Release",
        group = "Envelope",
        min = 1.0,
        max = 10000.0,
        default = 500.0,
        step = 1.0
    )]
    pub release_ms: f32,

    #[param(
        id = "peak_level",
        name = "Peak Level",
        group = "Envelope",
        min = 0.0,
        max = 1.0,
        default = 1.0,
        step = 0.01
    )]
    pub peak_level: f32,

    #[param(
        id = "sustain",
        name = "Sustain",
        group = "Envelope",
        min = 0.0,
        max = 1.0,
        default = 0.7,
        step = 0.01
    )]
    pub sustain_level: f32,

    #[param(id = "attack_tension", name = "Attack Tension", group = "Envelope", min = -1.0, max = 1.0, default = 0.0, step = 0.01)]
    pub attack_tension: f32,

    #[param(id = "decay_tension", name = "Decay Tension", group = "Envelope", min = -1.0, max = 1.0, default = 0.5, step = 0.01)]
    pub decay_tension: f32,

    #[param(id = "release_tension", name = "Release Tension", group = "Envelope", min = -1.0, max = 1.0, default = 0.5, step = 0.01)]
    pub release_tension: f32,
}

impl AdvancedEnvelopeSettings {
    pub fn new(group: &str) -> Self {
        let mut env = Self::base_default();
        let g = group.to_string();
        env.delay_ms.group = g.clone();
        env.attack_ms.group = g.clone();
        env.hold_ms.group = g.clone();
        env.decay_ms.group = g.clone();
        env.release_ms.group = g.clone();
        env.peak_level.group = g.clone();
        env.sustain_level.group = g.clone();
        env.attack_tension.group = g.clone();
        env.decay_tension.group = g.clone();
        env.release_tension.group = g;
        env
    }

    #[inline(always)]
    pub fn apply_tension(progress: f32, tension: f32) -> f32 {
        if tension.abs() < 0.001 {
            return progress;
        }
        let k = tension * 10.0;
        ((progress * k).exp() - 1.0) / (k.exp() - 1.0)
    }
}

impl Default for AdvancedEnvelopeSettings {
    fn default() -> Self {
        Self::new("Advanced Envelope")
    }
}

impl Envelope for AdvancedEnvelopeSettings {
    fn attack_ms(&self) -> f32 {
        self.attack_ms.get()
    }
    fn decay_ms(&self) -> f32 {
        self.decay_ms.get()
    }
    fn sustain_level(&self) -> f32 {
        self.sustain_level.get()
    }
    fn release_ms(&self) -> f32 {
        self.release_ms.get()
    }
    fn peak_level(&self) -> f32 {
        self.peak_level.get()
    }
}

/// Phase of an [`AdsrProcessor`], as reported to callers and stored in saved state.
#[derive(Debug, Clone, Copy, PartialEq, Deserialize, Serialize)]
pub enum EnvelopeState {
    Idle,
    Attack,
    Decay,
    Sustain,
    Release,
}

/// Level and timing data every envelope phase shares.
#[derive(Debug, Clone, Copy)]
struct AdsrLevels {
    current_level: f32,
    phase_time: f32,          // Time spent in the CURRENT phase
    release_start_level: f32, // Captures amplitude when note is released
    sample_rate: f32,
}

karbeat_utils::typestate! {
    /// Envelope phases and the moves between them.
    #[derive(Debug, Clone, Copy)]
    machine Adsr {
        shared: AdsrLevels,
        erased: #[derive(Debug, Clone, Copy)] AnyAdsr,
        states {
            #[derive(Debug, Clone, Copy)]
            Idle as IdleAdsr {}
            #[derive(Debug, Clone, Copy)]
            Attack as AttackAdsr {}
            #[derive(Debug, Clone, Copy)]
            Decay as DecayAdsr {}
            #[derive(Debug, Clone, Copy)]
            Sustain as SustainAdsr {}
            #[derive(Debug, Clone, Copy)]
            Release as ReleaseAdsr {}
        }
        transitions {
            Idle | Attack | Decay | Sustain | Release => Attack:
            fn note_on(levels, state) {
                levels.phase_time = 0.0;
                Attack {}
            }

            Idle | Attack | Decay | Sustain | Release => Release:
            fn note_off(levels, state) {
                levels.phase_time = 0.0;
                levels.release_start_level = levels.current_level;
                Release {}
            }

            Attack => Decay: fn attack_done(levels, state, peak: f32) {
                levels.current_level = peak;
                levels.phase_time = 0.0;
                Decay {}
            }

            Decay => Sustain: fn decay_done(levels, state, sustain: f32) {
                levels.current_level = sustain;
                levels.phase_time = 0.0;
                Sustain {}
            }

            Release => Idle: fn release_done(levels, state) {
                levels.current_level = 0.0;
                levels.phase_time = 0.0;
                Idle {}
            }
        }
    }
}

impl AnyAdsr {
    fn new(state: EnvelopeState, shared: AdsrLevels) -> Self {
        match state {
            EnvelopeState::Idle => Adsr {
                shared,
                state: Idle {},
            }
            .into(),
            EnvelopeState::Attack => Adsr {
                shared,
                state: Attack {},
            }
            .into(),
            EnvelopeState::Decay => Adsr {
                shared,
                state: Decay {},
            }
            .into(),
            EnvelopeState::Sustain => Adsr {
                shared,
                state: Sustain {},
            }
            .into(),
            EnvelopeState::Release => Adsr {
                shared,
                state: Release {},
            }
            .into(),
        }
    }

    const fn envelope_state(&self) -> EnvelopeState {
        match self {
            Self::Idle(_) => EnvelopeState::Idle,
            Self::Attack(_) => EnvelopeState::Attack,
            Self::Decay(_) => EnvelopeState::Decay,
            Self::Sustain(_) => EnvelopeState::Sustain,
            Self::Release(_) => EnvelopeState::Release,
        }
    }
}

/// Serialized form of an [`AdsrProcessor`].
#[derive(Deserialize, Serialize)]
struct AdsrSnapshot {
    state: EnvelopeState,
    current_level: f32,
    phase_time: f32,
    release_start_level: f32,
    sample_rate: f32,
}

impl From<AdsrSnapshot> for AdsrProcessor {
    fn from(snapshot: AdsrSnapshot) -> Self {
        Self {
            adsr: AnyAdsr::new(
                snapshot.state,
                AdsrLevels {
                    current_level: snapshot.current_level,
                    phase_time: snapshot.phase_time,
                    release_start_level: snapshot.release_start_level,
                    sample_rate: snapshot.sample_rate,
                },
            ),
        }
    }
}

impl From<AdsrProcessor> for AdsrSnapshot {
    fn from(processor: AdsrProcessor) -> Self {
        let levels = processor.adsr.shared();
        Self {
            state: processor.state(),
            current_level: levels.current_level,
            phase_time: levels.phase_time,
            release_start_level: levels.release_start_level,
            sample_rate: levels.sample_rate,
        }
    }
}

#[derive(Debug, Clone, Deserialize, Serialize)]
#[serde(from = "AdsrSnapshot", into = "AdsrSnapshot")]
pub struct AdsrProcessor {
    adsr: AnyAdsr,
}

impl AdsrProcessor {
    pub fn new(sample_rate: f32) -> Self {
        Self {
            adsr: AnyAdsr::new(
                EnvelopeState::Idle,
                AdsrLevels {
                    current_level: 0.0,
                    phase_time: 0.0,
                    release_start_level: 0.0,
                    sample_rate,
                },
            ),
        }
    }

    /// Phase the envelope is in.
    pub const fn state(&self) -> EnvelopeState {
        self.adsr.envelope_state()
    }

    /// Level produced by the latest [`Self::process`] call.
    pub fn current_level(&self) -> f32 {
        self.adsr.shared().current_level
    }

    pub fn note_on(&mut self) {
        // Every phase can restart, so the machine comes back either way.
        self.adsr = match self.adsr.note_on() {
            Ok(adsr) | Err((adsr, _)) => adsr,
        };
    }

    pub fn note_off(&mut self) {
        // Every phase can release, so the machine comes back either way.
        self.adsr = match self.adsr.note_off() {
            Ok(adsr) | Err((adsr, _)) => adsr,
        };
    }

    pub fn process<T: Envelope>(&mut self, settings: &T) -> f32 {
        let levels = self.adsr.shared_mut();
        levels.phase_time += 1.0 / levels.sample_rate;

        self.adsr = match self.adsr {
            AnyAdsr::Idle(mut adsr) => {
                adsr.shared.current_level = 0.0;
                adsr.into()
            }
            AnyAdsr::Attack(mut adsr) => {
                let attack_sec = settings.attack_ms() / 1000.0;
                let peak = settings.peak_level();

                adsr.shared.current_level = (adsr.shared.phase_time / attack_sec) * peak;

                if adsr.shared.phase_time >= attack_sec {
                    adsr.attack_done(peak).into()
                } else {
                    adsr.into()
                }
            }
            AnyAdsr::Decay(mut adsr) => {
                let decay_sec = settings.decay_ms() / 1000.0;
                let sustain = settings.sustain_level();
                let peak = settings.peak_level();

                // Interpolate from peak down to sustain_level
                let progress = adsr.shared.phase_time / decay_sec;
                adsr.shared.current_level = peak - (peak - sustain) * progress;

                if adsr.shared.phase_time >= decay_sec {
                    adsr.decay_done(sustain).into()
                } else {
                    adsr.into()
                }
            }
            AnyAdsr::Sustain(mut adsr) => {
                adsr.shared.current_level = settings.sustain_level();
                adsr.into()
            }
            AnyAdsr::Release(mut adsr) => {
                let release_sec = settings.release_ms() / 1000.0;
                let progress = adsr.shared.phase_time / release_sec;

                // Fade from the captured note_off level down to 0
                adsr.shared.current_level = adsr.shared.release_start_level * (1.0 - progress);

                if adsr.shared.phase_time >= release_sec {
                    adsr.release_done().into()
                } else {
                    adsr.into()
                }
            }
        };

        self.adsr.shared().current_level
    }
}
