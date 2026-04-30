// ============================================================================
// SYNTH VOICE (Decoupled Playback State)
// ============================================================================

use crate::prelude::EnvelopeSettings;

#[derive(Clone, Debug, Default)]
pub struct SynthVoice {
    pub note: u8,
    pub velocity: u8,
    pub is_active: bool,
    pub phase: [f64; 3], // Up to 3 oscillators
    
    // Simple internal envelope state tracking
    pub env_phase: f32,
    pub is_released: bool,
}

impl SynthVoice {
    pub fn new(note: u8, velocity: u8) -> Self {
        Self {
            note,
            velocity,
            is_active: true,
            phase: [0.0; 3],
            env_phase: 0.0,
            is_released: false,
        }
    }

    pub fn release(&mut self) {
        self.is_released = true;
    }

    /// Advances the envelope phase and returns the current amplitude (0.0 to 1.0).
    /// If the envelope finishes its release, it flags the voice as inactive.
    pub fn advance_envelope(&mut self, dt: f32, settings: &EnvelopeSettings) -> f32 {
        if !self.is_active { return 0.0; }

        let a = settings.attack.get();
        let d = settings.decay.get();
        let s = settings.sustain.get();
        let r = settings.release.get();

        if self.is_released {
            self.env_phase += dt;
            if self.env_phase >= r {
                self.is_active = false;
                return 0.0;
            }
            // Linear fade out from sustain level
            return s * (1.0 - (self.env_phase / r));
        }

        self.env_phase += dt;

        if self.env_phase <= a {
            // Attack Phase
            self.env_phase / a
        } else if self.env_phase <= a + d {
            // Decay Phase
            let decay_progress = (self.env_phase - a) / d;
            1.0 - (1.0 - s) * decay_progress
        } else {
            // Sustain Phase
            s
        }
    }
}