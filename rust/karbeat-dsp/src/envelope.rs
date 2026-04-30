// ============================================================================
// ENVELOPE (envelope.rs)
// ============================================================================

use karbeat_macros::karbeat_plugin;
use karbeat_plugin_types::parameter::Param;

/// Standard ADSR envelope settings
#[derive(Clone, Debug)]
#[karbeat_plugin]
pub struct EnvelopeSettings {
    #[param(id = "attack", name = "Attack", group = "Envelope", min = 0.001, max = 10.0, default = 0.01, step = 0.001)]
    pub attack: f32,

    #[param(id = "decay", name = "Decay", group = "Envelope", min = 0.001, max = 10.0, default = 0.2, step = 0.001)]
    pub decay: f32,

    #[param(id = "sustain", name = "Sustain", group = "Envelope", min = 0.0, max = 1.0, default = 0.7, step = 0.01)]
    pub sustain: f32,

    #[param(id = "release", name = "Release", group = "Envelope", min = 0.001, max = 10.0, default = 0.5, step = 0.001)]
    pub release: f32,
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
        env.attack.group = g.clone();
        env.decay.group = g.clone();
        env.sustain.group = g.clone();
        env.release.group = g;
        env
    }
}

/// Advanced DAHDSR envelope settings with adjustable curve tensions
#[derive(Clone, Debug)]
#[karbeat_plugin]
pub struct AdvancedEnvelopeSettings {
    #[param(id = "delay", name = "Delay", group = "Envelope", min = 0.0, max = 5.0, default = 0.0, step = 0.01)]
    pub delay: f32,
    
    #[param(id = "attack", name = "Attack", group = "Envelope", min = 0.001, max = 10.0, default = 0.01, step = 0.001)]
    pub attack: f32,
    
    #[param(id = "hold", name = "Hold", group = "Envelope", min = 0.0, max = 5.0, default = 0.0, step = 0.01)]
    pub hold: f32,
    
    #[param(id = "decay", name = "Decay", group = "Envelope", min = 0.001, max = 10.0, default = 0.2, step = 0.001)]
    pub decay: f32,
    
    #[param(id = "release", name = "Release", group = "Envelope", min = 0.001, max = 10.0, default = 0.5, step = 0.001)]
    pub release: f32,

    #[param(id = "peak_level", name = "Peak Level", group = "Envelope", min = 0.0, max = 1.0, default = 1.0, step = 0.01)]
    pub peak_level: f32,
    
    #[param(id = "sustain", name = "Sustain", group = "Envelope", min = 0.0, max = 1.0, default = 0.7, step = 0.01)]
    pub sustain: f32,

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
        env.delay.group = g.clone();
        env.attack.group = g.clone();
        env.hold.group = g.clone();
        env.decay.group = g.clone();
        env.release.group = g.clone();
        env.peak_level.group = g.clone();
        env.sustain.group = g.clone();
        env.attack_tension.group = g.clone();
        env.decay_tension.group = g.clone();
        env.release_tension.group = g;
        env
    }

    #[inline(always)]
    pub fn apply_tension(progress: f32, tension: f32) -> f32 {
        if tension.abs() < 0.001 { return progress; }
        let k = tension * 10.0;
        ((progress * k).exp() - 1.0) / (k.exp() - 1.0)
    }
}

impl Default for AdvancedEnvelopeSettings {
    fn default() -> Self {
        Self::new("Advanced Envelope")
    }
}