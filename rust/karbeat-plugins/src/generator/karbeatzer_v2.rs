//! src/plugin/generator/karbeatzer_v2.rs

#![allow(
    clippy::as_conversions,
    reason = "synth rendering intentionally converts bounded MIDI, phase, and sample values"
)]

use std::f32::consts::PI;

use karbeat_dsp::prelude::*;
use karbeat_macros::karbeat_plugin;
use karbeat_plugin_api::prelude::*;
use karbeat_plugin_types::*;
use karbeat_utils::hash::hash_str;

#[derive(Clone)]
#[karbeat_plugin]
pub struct KarbeatzerV2 {
    // Component Building Blocks
    #[nested(prefix = "osc")]
    pub oscillators: [Oscillator; 3],

    #[nested(prefix = "amp_env/")]
    pub amp_envelope: EnvelopeSettings,

    #[nested(prefix = "filter/")]
    pub filter: BiquadFilter<SimpleFilterMode>,

    // Local Parameters
    #[param(
        id = "drive",
        name = "Drive",
        group = "Master",
        min = 0.0,
        max = 1.0,
        default = 0.0,
        step = 0.01
    )]
    pub drive: f32,

    #[param(
        id = "gain",
        name = "Gain",
        group = "Master",
        min = 0.0,
        max = 1.0,
        default = 0.8,
        step = 0.01
    )]
    pub gain: f32,

    // Internal Decoupled State (Ignored by Param UI)
    pub active_voices: Vec<SynthVoice>,
    #[serde(default)]
    pub midi_channels: [MidiChannelState; 16],
    #[serde(default)]
    pub next_note_id: u64,
    pub sample_rate: f32,
    pub channels: usize,

    #[serde(skip)]
    pub scratch_buffer: Vec<f32>,

    pub interleaved_buffer: Vec<f32>,
}

impl Default for KarbeatzerV2 {
    fn default() -> Self {
        let mut engine = Self::base_default();

        engine.oscillators = [
            Oscillator::new("Oscillator 1"),
            Oscillator::new("Oscillator 2"),
            Oscillator::new("Oscillator 3"),
        ];

        // Setup some nice default starting values
        engine.oscillators[0].waveform.set_base(Waveform::Saw);
        engine.oscillators[0].mix.set_base(1.0);

        engine.oscillators[1].waveform.set_base(Waveform::Square);
        engine.oscillators[1].detune.set_base(0.1);
        engine.oscillators[1].mix.set_base(0.5);

        engine.oscillators[2].waveform.set_base(Waveform::Sine);
        engine.oscillators[2].detune.set_base(-12.0);
        engine.oscillators[2].mix.set_base(0.3);

        // Init internal state
        engine.active_voices = Vec::with_capacity(16);
        engine.midi_channels = [MidiChannelState::default(); 16];
        engine.next_note_id = 1;
        engine.sample_rate = 48000.0;
        engine.channels = 2;

        engine.scratch_buffer = vec![0.0; 4096];
        engine.interleaved_buffer = vec![0.0; 8192];

        engine
    }
}

impl KarbeatzerV2 {
    /// Mixes a block of audio for a single voice
    fn generate_voice_block(
        oscillators: &[Oscillator; 3],
        amp_envelope: &EnvelopeSettings,
        sample_rate: f32,
        voice: &mut SynthVoice,
        channel: &MidiChannelState,
        buffer: &mut [f32],
    ) {
        let block_size = buffer.len();
        let pitch_ratio = voice.pitch_ratio(channel, sample_rate, block_size);
        let base_freq = 440.0 * (2.0_f32).powf(((voice.note as f32) - 69.0) / 12.0) * pitch_ratio;
        // let dt = 1.0 / sample_rate;

        // Extract oscillator parameters
        let mut phase_incs = [0.0; 3];
        let mut wfs = [Waveform::Sine; 3];
        let mut mixes = [0.0; 3];
        let mut pws = [0.5; 3];

        for (i, osc) in oscillators.iter().enumerate() {
            let detune = osc.detune.get();
            let freq = base_freq * (2.0_f32).powf(detune / 12.0);

            phase_incs[i] = freq / sample_rate;
            wfs[i] = osc.waveform.get();
            mixes[i] = osc.mix.get();
            pws[i] = osc.pulse_width.get();
        }

        // Render block
        for frame in 0..block_size {
            let env_level = voice.adsr.process(amp_envelope);

            if !voice.is_active {
                buffer[frame] = 0.0;
                continue;
            }

            let current_gain = voice.gain(channel) * env_level;
            let mut sample_accum = 0.0;

            for i in 0..3 {
                let phase = voice.phase[i];
                let dt_inc = phase_incs[i];

                let osc_out = match wfs[i] {
                    Waveform::Sine => (phase * 2.0 * PI as f64).sin() as f32,
                    Waveform::Saw => {
                        let naive = (2.0 * phase - 1.0) as f32;
                        naive - Oscillator::poly_blep(phase, dt_inc as f64) as f32
                    }
                    Waveform::Square => {
                        let naive = if phase < pws[i] as f64 { 1.0 } else { -1.0 };
                        let mut blep = Oscillator::poly_blep(phase, dt_inc as f64) as f32;
                        let phase2 = (phase + 1.0 - pws[i] as f64) % 1.0;
                        blep -= Oscillator::poly_blep(phase2, dt_inc as f64) as f32;
                        naive - blep
                    }
                    Waveform::Triangle => (4.0 * (phase - 0.5).abs() - 1.0) as f32,
                    Waveform::Noise => fastrand::f32() * 2.0 - 1.0,
                };

                sample_accum += osc_out * mixes[i];

                voice.phase[i] += dt_inc as f64;
                if voice.phase[i] >= 1.0 {
                    voice.phase[i] -= 1.0;
                }
            }

            buffer[frame] = voice.apply_brightness(sample_accum, channel) * current_gain;
        }
    }

    fn handle_midi_message(&mut self, message: &MidiMessage) {
        match message {
            MidiMessage::NoteOn {
                note_id,
                channel,
                key,
                velocity,
            } => {
                let channel = (*channel).min(15);
                if *velocity == 0 {
                    let sustain = self.midi_channels[channel as usize].sustain;
                    for voice in self
                        .active_voices
                        .iter_mut()
                        .filter(|voice| voice.matches_note(*note_id, channel, *key))
                    {
                        voice.release_key(sustain);
                    }
                    return;
                }

                let note_id = note_id.unwrap_or_else(|| {
                    let id = self.next_note_id;
                    self.next_note_id = self.next_note_id.wrapping_add(1).max(1);
                    id
                });
                self.active_voices.push(SynthVoice::new_with_identity(
                    note_id,
                    channel,
                    *key,
                    *velocity,
                    self.sample_rate,
                    self.oscillators.len(),
                ));
            }
            MidiMessage::NoteOff {
                note_id,
                channel,
                key,
            } => {
                let channel = (*channel).min(15);
                let sustain = self.midi_channels[channel as usize].sustain;
                for voice in self
                    .active_voices
                    .iter_mut()
                    .filter(|voice| voice.matches_note(*note_id, channel, *key))
                {
                    voice.release_key(sustain);
                }
            }
            MidiMessage::ControlChange {
                channel,
                controller,
                value,
            } => {
                let channel = (*channel).min(15);
                let state = &mut self.midi_channels[channel as usize];
                match state.apply_control_change(*controller, *value) {
                    MidiChannelAction::None => {}
                    MidiChannelAction::ReleaseSustained => {
                        for voice in self
                            .active_voices
                            .iter_mut()
                            .filter(|voice| voice.channel == channel && voice.key_released)
                        {
                            voice.release();
                        }
                    }
                    MidiChannelAction::ReleaseNotes => {
                        let sustain = state.sustain;
                        for voice in self
                            .active_voices
                            .iter_mut()
                            .filter(|voice| voice.channel == channel)
                        {
                            voice.release_key(sustain);
                        }
                    }
                    MidiChannelAction::StopSound => {
                        for voice in self
                            .active_voices
                            .iter_mut()
                            .filter(|voice| voice.channel == channel)
                        {
                            voice.is_active = false;
                        }
                    }
                }
            }
            MidiMessage::PitchBend { channel, value } => {
                self.midi_channels[(*channel).min(15) as usize].set_pitch_bend(*value);
            }
            MidiMessage::NoteExpression {
                note_id,
                expression,
                value,
            } => {
                let value = value.clamp(0.0, 1.0);
                for voice in self
                    .active_voices
                    .iter_mut()
                    .filter(|voice| voice.note_id == *note_id)
                {
                    match expression {
                        NoteExpressionType::Volume => voice.expressions.volume = value,
                        NoteExpressionType::Pan => voice.expressions.pan = value * 2.0 - 1.0,
                        NoteExpressionType::Tuning => {
                            voice.expressions.tuning_semitones = value * 4.0 - 2.0
                        }
                        NoteExpressionType::Vibrato => voice.expressions.vibrato = value,
                        NoteExpressionType::Brightness => voice.expressions.brightness = value,
                        NoteExpressionType::Pressure => voice.expressions.pressure = value,
                    }
                }
            }
        }
    }

    fn handle_side_effects(&mut self) {
        // Safe to call every time parameters change
        self.filter.calculate_coefficients();
    }
}

// ============================================================================
// DIRECT GENERATOR IMPLEMENTATION
// ============================================================================

#[karbeat_macros::auto_param(on_change = "self.handle_side_effects()")]
impl AudioPlugin for KarbeatzerV2 {
    fn name(&self) -> &str {
        "Karbeatzer V2"
    }

    fn prepare(&mut self, sample_rate: f32, _max_buffer_size: usize) {
        self.sample_rate = sample_rate;
        self.filter.prepare(self.channels as u8, sample_rate as u32);
        self.filter.calculate_coefficients();
    }

    fn set_io_layout(&mut self, _inputs: &[BusConfig], outputs: &[BusConfig]) {
        let new_channels = outputs.first().map(|b| b.channel_count).unwrap_or(2);
        if self.channels != new_channels {
            self.channels = new_channels;
            self.filter
                .prepare(self.channels as u8, self.sample_rate as u32);
        }
    }

    fn reset(&mut self) {
        self.active_voices.clear();
        self.filter.reset_state();
    }

    fn process(&mut self, buffers: &mut AudioBuffers, context: &ProcessContext) {
        for param_change in context.param_changes {
            self.set_parameter(param_change.param_id, param_change.normalized_value);
        }

        if buffers.main_outputs.is_empty() {
            return;
        }

        let outputs = &mut buffers.main_outputs[0].channel_data;
        let total_frames = outputs.first().map_or(0, |ch| ch.len());

        if self.channels == 0 || total_frames == 0 {
            return;
        }

        // Resize internal interleaved buffer if necessary
        let required_len = total_frames * self.channels;
        if self.interleaved_buffer.len() < required_len {
            self.interleaved_buffer.resize(required_len, 0.0);
        }
        self.interleaved_buffer[..required_len].fill(0.0);

        let current_drive = self.drive.get();
        let master_gain = self.gain.get();
        let midi_events = context.midi_events;

        let mut current_frame = 0;
        let mut event_idx = 0;

        if self.scratch_buffer.len() < total_frames {
            self.scratch_buffer.resize(total_frames, 0.0);
        }

        while current_frame < total_frames {
            let next_event_frame = if event_idx < midi_events.len() {
                midi_events[event_idx].sample_offset
            } else {
                total_frames
            };

            let end_frame = next_event_frame.min(total_frames);
            let block_len = end_frame - current_frame;

            if block_len > 0 {
                let out_slice = &mut self.interleaved_buffer
                    [current_frame * self.channels..end_frame * self.channels];

                let KarbeatzerV2 {
                    active_voices,
                    midi_channels,
                    oscillators,
                    amp_envelope,
                    sample_rate,
                    scratch_buffer,
                    ..
                } = self;

                let scratch_slice = &mut scratch_buffer[0..block_len];

                // Render all active voices
                for voice in active_voices.iter_mut() {
                    if !voice.is_active {
                        continue;
                    }

                    let channel = midi_channels[voice.channel as usize];
                    Self::generate_voice_block(
                        oscillators,
                        amp_envelope,
                        *sample_rate,
                        voice,
                        &channel,
                        scratch_slice,
                    );

                    // Mix mono voice into interleaved stereo output buffer
                    let (left_gain, right_gain) = voice.pan_gains(&channel);
                    for (i, &sample) in scratch_slice.iter().enumerate() {
                        for ch in 0..self.channels {
                            let pan_gain = match ch {
                                0 => left_gain,
                                1 => right_gain,
                                _ => 1.0,
                            };
                            out_slice[i * self.channels + ch] += sample * pan_gain;
                        }
                    }
                }

                // Apply global filter
                for chunk in out_slice.chunks_exact_mut(self.channels) {
                    self.filter.process_frame(chunk);
                }

                // Apply drive
                if current_drive > 0.0 {
                    let drive_amt = 1.0 + current_drive * 4.0;
                    for sample in out_slice.iter_mut() {
                        *sample = (*sample * drive_amt).tanh();
                    }
                }

                // Apply Master Gain
                for sample in out_slice.iter_mut() {
                    *sample *= master_gain;
                }
            }

            // Process MIDI
            while event_idx < midi_events.len() && midi_events[event_idx].sample_offset == end_frame
            {
                self.handle_midi_message(&midi_events[event_idx].data);
                event_idx += 1;
            }
            current_frame = end_frame;
        }

        // Cleanup dead voices
        self.active_voices.retain(|v| v.is_active);

        // 2. Finally, de-interleave the result into the provided AudioBuffers
        for c in 0..self.channels {
            for i in 0..total_frames {
                outputs[c][i] = self.interleaved_buffer[i * self.channels + c];
            }
        }
    }

    fn category(&self) -> PluginCategory {
        PluginCategory::Instrument
    }

    fn latency_samples(&self) -> u32 {
        0
    }

    fn tail_samples(&self) -> u32 {
        let release_ms = self.amp_envelope.release_ms.get();
        let tail_in_samples = (release_ms / 1000.0) * self.sample_rate;

        // Add a tiny safety buffer (e.g., 64 samples) to guarantee the
        // envelope has definitively hit absolute 0.0 before the engine culls it.
        (tail_in_samples as u32) + 64
    }

    fn execute_custom_command(
        &mut self,
        _command: &str,
        _payload: &serde_json::Value,
    ) -> Option<serde_json::Value> {
        None
    }
}

// ============================================================================
// REGISTRY BUILDER & MANIFEST
// ============================================================================

impl AudioPluginBuilder for KarbeatzerV2 {
    fn build() -> Self {
        Self::default()
    }
}

#[cfg(test)]
mod rich_midi_tests {
    use super::KarbeatzerV2;
    use karbeat_plugin_api::types::{MidiMessage, NoteExpressionType};

    #[test]
    fn routes_channel_and_per_note_expression() {
        let mut synth = KarbeatzerV2::default();
        synth.handle_midi_message(&MidiMessage::NoteOn {
            note_id: Some(42),
            channel: 3,
            key: 64,
            velocity: 127,
        });
        synth.handle_midi_message(&MidiMessage::PitchBend {
            channel: 3,
            value: 8191,
        });
        synth.handle_midi_message(&MidiMessage::NoteExpression {
            note_id: 42,
            expression: NoteExpressionType::Pan,
            value: 1.0,
        });

        assert_eq!(synth.midi_channels[3].pitch_bend_semitones, 2.0);
        assert_eq!(synth.active_voices[0].expressions.pan, 1.0);
    }
}

impl Manifestable for KarbeatzerV2 {
    fn build_manifest() -> PluginManifest {
        let id_string = "synth_karbeatzer_v2";
        PluginManifest {
            id: hash_str(id_string),
            id_string: id_string.to_string(),
            name: "Karbeatzer V2".to_owned(),
            internal_type: "KarbeatzerV2".to_owned(),
            is_synth: true,
            parameters: Self::default()
                .auto_get_parameter_specs(karbeat_utils::hash::FNV_OFFSET, ""),
        }
    }
}
