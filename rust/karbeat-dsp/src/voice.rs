use serde::{Deserialize, Serialize};

use crate::envelope::AdsrProcessor;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum MidiChannelAction {
    None,
    ReleaseSustained,
    ReleaseNotes,
    StopSound,
}

#[derive(Clone, Copy, Debug, Serialize, Deserialize)]
pub struct MidiChannelState {
    pub volume: f32,
    pub pan: f32,
    pub expression: f32,
    pub pitch_bend_semitones: f32,
    pub modulation: f32,
    pub brightness: f32,
    pub sustain: bool,
}

impl Default for MidiChannelState {
    fn default() -> Self {
        Self {
            volume: 1.0,
            pan: 0.0,
            expression: 1.0,
            pitch_bend_semitones: 0.0,
            modulation: 0.0,
            brightness: 1.0,
            sustain: false,
        }
    }
}

impl MidiChannelState {
    pub fn set_pitch_bend(&mut self, value: i16) {
        let normalized = if value < 0 {
            value as f32 / 8192.0
        } else {
            value as f32 / 8191.0
        };
        self.pitch_bend_semitones = normalized.clamp(-1.0, 1.0) * 2.0;
    }

    pub fn apply_control_change(&mut self, controller: u8, value: u8) -> MidiChannelAction {
        let normalized = value.min(127) as f32 / 127.0;
        match controller {
            1 => self.modulation = normalized,
            7 => self.volume = normalized,
            10 => self.pan = normalized * 2.0 - 1.0,
            11 => self.expression = normalized,
            64 => {
                let was_sustained = self.sustain;
                self.sustain = value >= 64;
                if was_sustained && !self.sustain {
                    return MidiChannelAction::ReleaseSustained;
                }
            }
            74 => self.brightness = normalized,
            120 => return MidiChannelAction::StopSound,
            121 => {
                let was_sustained = self.sustain;
                *self = Self::default();
                if was_sustained {
                    return MidiChannelAction::ReleaseSustained;
                }
            }
            123..=127 => return MidiChannelAction::ReleaseNotes,
            _ => {}
        }
        MidiChannelAction::None
    }
}

#[derive(Clone, Copy, Debug, Serialize, Deserialize)]
pub struct NoteExpressionState {
    pub volume: f32,
    pub pan: f32,
    pub tuning_semitones: f32,
    pub vibrato: f32,
    pub brightness: f32,
    pub pressure: f32,
}

impl Default for NoteExpressionState {
    fn default() -> Self {
        Self {
            volume: 1.0,
            pan: 0.0,
            tuning_semitones: 0.0,
            vibrato: 0.0,
            brightness: 1.0,
            pressure: 0.0,
        }
    }
}

#[derive(Clone, Serialize, Deserialize)]
pub struct SynthVoice {
    #[serde(default)]
    pub note_id: u64,
    #[serde(default)]
    pub channel: u8,
    pub note: u8,
    pub velocity: u8,
    pub is_active: bool,
    pub phase: Vec<f64>,
    pub adsr: AdsrProcessor, // Every voice tracks its own ADSR state
    pub filter_state: Vec<f64>,
    #[serde(default)]
    pub expressions: NoteExpressionState,
    #[serde(default)]
    pub key_released: bool,
    #[serde(default)]
    pub vibrato_phase: f32,
    #[serde(default)]
    pub brightness_filter_state: f32,
}

impl SynthVoice {
    pub fn new(note: u8, velocity: u8, sample_rate: f32, num_voices: usize) -> Self {
        Self::new_with_identity(
            u64::from(note),
            0,
            note,
            velocity,
            sample_rate,
            num_voices,
        )
    }

    pub fn new_with_identity(
        note_id: u64,
        channel: u8,
        note: u8,
        velocity: u8,
        sample_rate: f32,
        num_voices: usize,
    ) -> Self {
        let mut adsr = AdsrProcessor::new(sample_rate);
        adsr.note_on(); // Start the attack phase immediately

        Self {
            note_id,
            channel: channel.min(15),
            note,
            velocity,
            is_active: true,
            phase: vec![0.0; num_voices],
            adsr,
            filter_state: vec![0.0; num_voices],
            expressions: NoteExpressionState::default(),
            key_released: false,
            vibrato_phase: 0.0,
            brightness_filter_state: 0.0,
        }
    }

    pub fn release(&mut self) {
        self.adsr.note_off(); // Trigger the graceful fade-out
    }

    pub fn release_key(&mut self, sustain: bool) {
        self.key_released = true;
        if !sustain {
            self.release();
        }
    }

    pub fn matches_note(&self, note_id: Option<u64>, channel: u8, key: u8) -> bool {
        note_id.map_or(self.channel == channel && self.note == key, |id| {
            self.note_id == id
        })
    }

    pub fn pitch_ratio(
        &mut self,
        channel: &MidiChannelState,
        sample_rate: f32,
        frames: usize,
    ) -> f32 {
        let vibrato_depth = (channel.modulation * 0.5 + self.expressions.vibrato).min(2.0);
        let vibrato = (self.vibrato_phase * std::f32::consts::TAU).sin() * vibrato_depth;
        self.vibrato_phase =
            (self.vibrato_phase + 5.0 * frames as f32 / sample_rate.max(1.0)).fract();
        2.0_f32.powf(
            (channel.pitch_bend_semitones + self.expressions.tuning_semitones + vibrato) / 12.0,
        )
    }

    pub fn gain(&self, channel: &MidiChannelState) -> f32 {
        let velocity = self.velocity as f32 / 127.0;
        velocity
            * channel.volume
            * channel.expression
            * self.expressions.volume
            * (1.0 + self.expressions.pressure * 0.25)
    }

    pub fn pan_gains(&self, channel: &MidiChannelState) -> (f32, f32) {
        let pan = (channel.pan + self.expressions.pan).clamp(-1.0, 1.0);
        (1.0 - pan.max(0.0), 1.0 + pan.min(0.0))
    }

    pub fn apply_brightness(&mut self, sample: f32, channel: &MidiChannelState) -> f32 {
        let brightness = (channel.brightness * self.expressions.brightness).clamp(0.0, 1.0);
        let coefficient = 0.02 + brightness * brightness * 0.98;
        self.brightness_filter_state += coefficient * (sample - self.brightness_filter_state);
        self.brightness_filter_state
    }
}

#[cfg(test)]
mod tests {
    use super::{MidiChannelAction, MidiChannelState, SynthVoice};

    #[test]
    fn channel_controls_map_to_performance_state() {
        let mut channel = MidiChannelState::default();

        channel.apply_control_change(7, 64);
        channel.apply_control_change(10, 127);
        channel.set_pitch_bend(8191);

        assert!((channel.volume - 64.0 / 127.0).abs() < f32::EPSILON);
        assert_eq!(channel.pan, 1.0);
        assert_eq!(channel.pitch_bend_semitones, 2.0);
    }

    #[test]
    fn sustain_defers_note_release() {
        let mut channel = MidiChannelState::default();
        channel.apply_control_change(64, 127);
        let mut voice = SynthVoice::new_with_identity(42, 1, 60, 100, 48_000.0, 1);

        voice.release_key(channel.sustain);
        assert!(voice.key_released);
        assert_ne!(voice.adsr.state, crate::envelope::EnvelopeState::Release);

        assert_eq!(
            channel.apply_control_change(64, 0),
            MidiChannelAction::ReleaseSustained
        );
        voice.release();
        assert_eq!(voice.adsr.state, crate::envelope::EnvelopeState::Release);
    }

    #[test]
    fn performance_state_changes_pitch_gain_and_pan() {
        let mut channel = MidiChannelState {
            volume: 0.5,
            pan: 0.25,
            pitch_bend_semitones: 2.0,
            ..MidiChannelState::default()
        };
        channel.expression = 0.5;
        let mut voice = SynthVoice::new_with_identity(7, 0, 60, 127, 48_000.0, 1);
        voice.expressions.volume = 0.8;
        voice.expressions.pan = 0.25;
        voice.expressions.tuning_semitones = 1.0;

        let expected_pitch = 2.0_f32.powf(3.0 / 12.0);
        assert!((voice.pitch_ratio(&channel, 48_000.0, 64) - expected_pitch).abs() < 1.0e-6);
        assert!((voice.gain(&channel) - 0.2).abs() < 1.0e-6);
        assert_eq!(voice.pan_gains(&channel), (0.5, 1.0));
    }
}
