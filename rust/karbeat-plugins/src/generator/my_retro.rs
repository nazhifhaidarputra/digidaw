// ====================================================
// MY RETRO SYNTH
// Author: Haidar Wibowo
// ====================================================

#![allow(
    clippy::as_conversions,
    reason = "synth rendering intentionally converts bounded MIDI, phase, and sample values"
)]

use karbeat_dsp::prelude::*;
use karbeat_macros::karbeat_plugin;
use karbeat_plugin_api::prelude::*;
use karbeat_utils::hash::hash_str;

/// A generator/synthesizer that produces a retro-sounding synth sound.
/// It has strictly two oscillators, making it a simple 8-bit retro sound.
#[derive(Clone)]
#[karbeat_plugin]
pub struct MyRetro {
    // Nested building blocks
    #[nested(prefix = "osc")]
    pub oscillators: [Oscillator; 2],

    #[nested(prefix = "amp_env/")]
    pub amp_envelope: EnvelopeSettings,

    // Local Parameters
    #[param(
        id = "bitcrush",
        name = "Resolution",
        group = "Bitcrush",
        min = 2.0,
        max = 256.0,
        default = 16.0,
        step = 1.0
    )]
    pub bitcrush_resolution: f32,

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

    #[param(
        id = "base_freq",
        name = "Base frequency",
        group = "Master",
        min = 432.0,
        max = 448.0,
        default = 440.0,
        step = 1.0
    )]
    pub base_freq: f32,

    // Internal Decoupled State
    pub active_voices: Vec<SynthVoice>,
    #[serde(default)]
    pub midi_channels: [MidiChannelState; 16],
    #[serde(default)]
    pub next_note_id: u64,
    pub sample_rate: f32,
    pub channels: usize,

    pub mix_buffer: Vec<f32>,
}

impl Default for MyRetro {
    fn default() -> Self {
        let mut engine = Self::base_default();

        // Override specific nested logic for the two oscillators safely
        let mut osc1 = Oscillator::new("Oscillator 1");
        osc1.waveform.set_base(Waveform::Square);
        osc1.mix.set_base(1.0);

        let mut osc2 = Oscillator::new("Oscillator 2");
        osc2.waveform.set_base(Waveform::Square);
        osc2.detune.set_base(-12.0);
        osc2.mix.set_base(0.8);

        engine.oscillators = [osc1, osc2];

        // Init internal state
        engine.active_voices = Vec::with_capacity(16);
        engine.midi_channels = [MidiChannelState::default(); 16];
        engine.next_note_id = 1;
        engine.sample_rate = 48000.0;
        engine.channels = 2;

        engine.mix_buffer = vec![0.0; 8192];

        engine
    }
}

impl MyRetro {
    pub fn new() -> Self {
        Self::default()
    }

    /// Processes in pure Mono and ACCUMULATES directly into the mix buffer
    pub fn accumulate_voice_block(
        oscillators: &[Oscillator; 2],
        amp_envelope: &EnvelopeSettings,
        crush_steps: f32,
        sample_rate: f32,
        voice: &mut SynthVoice,
        channel: &MidiChannelState,
        buffer: &mut [f32],
        channels: usize,
        base_freq: f32,
    ) {
        let frames = buffer.len() / channels;
        let pitch_ratio = voice.pitch_ratio(channel, sample_rate, frames) as f64;
        let actual_freq =
            base_freq as f64 * (2.0_f64).powf(((voice.note as f64) - 69.0) / 12.0) * pitch_ratio;
        let (left_gain, right_gain) = voice.pan_gains(channel);

        for frame in buffer.chunks_exact_mut(channels) {
            if !voice.is_active {
                break; // Instantly skip the rest of the block if dead
            }

            let env_level = voice.adsr.process(amp_envelope);

            if voice.adsr.state == EnvelopeState::Idle {
                voice.is_active = false;
                break; // Massive CPU save: don't iterate remaining frames!
            }

            let current_gain = voice.gain(channel) * env_level;
            let mut temp_sample = 0.0;

            for (i, osc) in oscillators.iter().enumerate() {
                let mut phase = voice.phase[i];
                let mut filter_state = voice.filter_state[i];

                let mut osc_output = [0.0; 2];
                osc.output_wave(
                    &mut osc_output,
                    sample_rate as u32,
                    2,
                    actual_freq,
                    &mut phase,
                    &mut filter_state,
                );

                voice.phase[i] = phase;
                temp_sample += osc_output[0]; // We only care about Mono L
            }

            let crushed_sample =
                voice.apply_brightness((temp_sample * crush_steps).round() / crush_steps, channel);

            // ACCUMULATE directly into the shared block buffer
            for (channel_index, sample) in frame.iter_mut().enumerate() {
                let pan_gain = match channel_index {
                    0 => left_gain,
                    1 => right_gain,
                    _ => 1.0,
                };
                *sample += crushed_sample * current_gain * pan_gain;
            }
        }
    }

    /// Pure associated function (no `&self`).
    /// Takes only the specific slices and primitives it needs!
    pub fn generate_voice_block(
        oscillators: &[Oscillator; 2],
        amp_envelope: &EnvelopeSettings,
        crush_steps: f32,
        sample_rate: f32,
        channels: usize,
        voice: &mut SynthVoice,
        channel: &MidiChannelState,
        buffer: &mut [f32],
        base_freq: f32,
    ) {
        buffer.fill(0.0);

        let pitch_ratio = voice.pitch_ratio(channel, sample_rate, buffer.len() / channels) as f64;
        let base_freq =
            base_freq as f64 * (2.0_f64).powf(((voice.note as f64) - 69.0) / 12.0) * pitch_ratio;
        let (left_gain, right_gain) = voice.pan_gains(channel);

        for frame in buffer.chunks_exact_mut(channels) {
            if !voice.is_active {
                continue;
            }

            let env_level = voice.adsr.process(amp_envelope);

            if voice.adsr.state == EnvelopeState::Idle {
                voice.is_active = false;
                continue;
            }

            let current_gain = voice.gain(channel) * env_level;

            // Temporary buffer to hold the output of the oscillators BEFORE bitcrush
            let mut temp_sample = 0.0;

            for (i, osc) in oscillators.iter().enumerate() {
                let mut phase = voice.phase[i];
                let mut filter_state = voice.filter_state[i];

                // Extract 1 sample frame
                let mut osc_output = [0.0; 2];
                osc.output_wave(
                    &mut osc_output,
                    sample_rate as u32,
                    2,
                    base_freq,
                    &mut phase,
                    &mut filter_state,
                );

                voice.phase[i] = phase;

                // Mix the raw, uncrushed oscillators together
                temp_sample += osc_output[0];
            }

            // Apply the bitcrush ONCE to the cleanly summed signal,
            // and apply the envelope GAIN *AFTER* the bitcrush!
            let crushed_sample =
                voice.apply_brightness((temp_sample * crush_steps).round() / crush_steps, channel);
            let final_sample = crushed_sample * current_gain;

            for (channel_index, sample) in frame.iter_mut().enumerate() {
                let pan_gain = match channel_index {
                    0 => left_gain,
                    1 => right_gain,
                    _ => 1.0,
                };
                *sample = final_sample * pan_gain;
            }
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
                let mut voice = SynthVoice::new_with_identity(
                    note_id,
                    channel,
                    *key,
                    *velocity,
                    self.sample_rate,
                    self.oscillators.len(),
                );
                for (index, oscillator) in self.oscillators.iter().enumerate() {
                    voice.phase[index] = oscillator.phase_offset.get() as f64;
                    voice.filter_state[index] = 0.0;
                }
                self.active_voices.push(voice);
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
}

// ============================================================================
// DIRECT GENERATOR IMPLEMENTATION
// ============================================================================

#[karbeat_macros::auto_param]
impl AudioPlugin for MyRetro {
    fn name(&self) -> &str {
        "My Retro"
    }

    fn prepare(&mut self, sample_rate: f32, max_buffer_size: usize) {
        self.sample_rate = sample_rate;
        self.mix_buffer
            .resize(max_buffer_size.saturating_mul(self.channels), 0.0);
    }

    fn set_io_layout(&mut self, _inputs: &[BusConfig], outputs: &[BusConfig]) {
        let new_channels = outputs.first().map(|b| b.channel_count).unwrap_or(2);
        if self.channels != new_channels {
            self.channels = new_channels;
        }
    }

    fn reset(&mut self) {
        self.active_voices.clear();
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

        let output_samples = total_frames * self.channels;
        if self.mix_buffer.len() < output_samples {
            self.mix_buffer.resize(output_samples, 0.0);
        }
        self.mix_buffer[..output_samples].fill(0.0);

        let midi_events = context.midi_events;

        let master_gain = self.gain.get();
        let crush_steps = self.bitcrush_resolution.get().max(2.0);
        let base_freq = self.base_freq.get();

        let mut current_frame = 0;
        let mut event_idx = 0;

        while current_frame < total_frames {
            let next_event_frame = if event_idx < midi_events.len() {
                midi_events[event_idx].sample_offset
            } else {
                total_frames
            };

            let end_frame = next_event_frame.min(total_frames);
            let block_len = end_frame - current_frame;

            if block_len > 0 {
                let out_slice =
                    &mut self.mix_buffer[current_frame * self.channels..end_frame * self.channels];

                let MyRetro {
                    active_voices,
                    midi_channels,
                    oscillators,
                    amp_envelope,
                    sample_rate,
                    ..
                } = self;

                // 1. Process all voices directly into the out_slice
                for voice in active_voices.iter_mut() {
                    if !voice.is_active {
                        continue;
                    }

                    let channel = midi_channels[voice.channel as usize];
                    Self::accumulate_voice_block(
                        oscillators,
                        amp_envelope,
                        crush_steps,
                        *sample_rate,
                        voice,
                        &channel,
                        out_slice,
                        self.channels,
                        base_freq,
                    );
                }

                // 2. Apply Master Gain once to the combined mono block
                for sample in out_slice {
                    *sample *= master_gain;
                }
            }

            // Handle MIDI events at this exact frame
            while event_idx < midi_events.len() && midi_events[event_idx].sample_offset == end_frame
            {
                self.handle_midi_message(&midi_events[event_idx].data);
                event_idx += 1;
            }

            current_frame = end_frame;
        }

        self.active_voices.retain(|v| v.is_active);

        // 3. De-interleave the rendered mix into plugin outputs.
        for c in 0..self.channels {
            for frame in 0..total_frames {
                outputs[c][frame] = self.mix_buffer[frame * self.channels + c];
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

impl AudioPluginBuilder for MyRetro {
    fn build() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod rich_midi_tests {
    use super::MyRetro;
    use karbeat_plugin_api::types::MidiMessage;

    #[test]
    fn sustain_holds_then_releases_a_voice() {
        let mut synth = MyRetro::default();
        synth.handle_midi_message(&MidiMessage::ControlChange {
            channel: 0,
            controller: 64,
            value: 127,
        });
        synth.handle_midi_message(&MidiMessage::NoteOn {
            note_id: Some(9),
            channel: 0,
            key: 60,
            velocity: 100,
        });
        synth.handle_midi_message(&MidiMessage::NoteOff {
            note_id: Some(9),
            channel: 0,
            key: 60,
        });
        assert!(synth.active_voices[0].key_released);
        assert_ne!(
            synth.active_voices[0].adsr.state,
            karbeat_dsp::envelope::EnvelopeState::Release
        );

        synth.handle_midi_message(&MidiMessage::ControlChange {
            channel: 0,
            controller: 64,
            value: 0,
        });
        assert_eq!(
            synth.active_voices[0].adsr.state,
            karbeat_dsp::envelope::EnvelopeState::Release
        );
    }
}

impl Manifestable for MyRetro {
    fn build_manifest() -> PluginManifest {
        let id_str = "synth_my_retro";
        PluginManifest {
            id: hash_str(id_str),
            id_string: id_str.to_owned(),
            name: "My Retro".to_owned(),
            internal_type: "MyRetro".to_owned(),
            is_synth: true,
            parameters: Self::static_parameter_specs(),
        }
    }
}
