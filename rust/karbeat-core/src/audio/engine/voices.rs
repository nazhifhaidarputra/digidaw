use karbeat_plugin_api::types::{MidiEvent, MidiMessage};
use smallvec::SmallVec;

use crate::{
    audio::{engine::helper::render_audio_waveform, render_state::AudioPluginState},
    core::project::{AudioWaveform, Clip, GeneratorInstance, Note, Pattern},
    shared::constants::f64::PPQ,
    shared::{GeneratorId, TrackId},
};

/// Audio-thread reference to one active generator instance.
pub struct GeneratorVoice {
    pub id: GeneratorId,
    pub track_id: TrackId,
    pub midi_events: SmallVec<[MidiEvent; 4]>,
    pub active: bool,
    pub playing_keys: Vec<u8>,
    pub playing_notes: SmallVec<[PlayingNote; 8]>,
    pub tail_remaining: Option<u32>,
}

#[cfg(test)]
mod midi_tests {
    use super::{PlayingNote, VoiceState};
    use crate::shared::{NoteId, PatternId};
    use karbeat_plugin_api::types::{MidiMessage, NoteExpressionType};
    use smallvec::SmallVec;

    #[test]
    fn tracks_overlapping_notes_by_identity() {
        let mut notes = SmallVec::<[PlayingNote; 8]>::new();
        for note_id in [10, 11] {
            VoiceState::update_playing_notes(
                &mut notes,
                &MidiMessage::NoteOn {
                    note_id: Some(note_id),
                    channel: 2,
                    key: 60,
                    velocity: 100,
                },
            );
        }

        VoiceState::update_playing_notes(
            &mut notes,
            &MidiMessage::NoteExpression {
                note_id: 11,
                expression: NoteExpressionType::Pressure,
                value: 0.8,
            },
        );
        VoiceState::update_playing_notes(
            &mut notes,
            &MidiMessage::NoteOff {
                note_id: Some(10),
                channel: 2,
                key: 60,
            },
        );

        assert_eq!(notes.len(), 1);
        assert_eq!(notes[0].note_id, Some(11));
    }

    #[test]
    fn scheduled_identity_includes_pattern() {
        let note_id = NoteId::from(4);

        assert_ne!(
            VoiceState::note_event_id(PatternId::from(1), note_id),
            VoiceState::note_event_id(PatternId::from(2), note_id)
        );
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct PlayingNote {
    pub note_id: Option<u64>,
    pub channel: u8,
    pub key: u8,
}

impl GeneratorVoice {
    pub fn new(id: GeneratorId, track_id: TrackId, active: bool) -> Self {
        Self {
            id,
            track_id,
            midi_events: SmallVec::new(),
            active,
            playing_keys: Vec::new(),
            playing_notes: SmallVec::new(),
            tail_remaining: None,
        }
    }

    pub fn track_midi_event(&mut self, message: &MidiMessage) {
        VoiceState::update_playing_notes(&mut self.playing_notes, message);
        VoiceState::update_playing_keys(&mut self.playing_keys, message);
    }
}

impl VoiceState {
    pub fn update_playing_notes(
        playing_notes: &mut SmallVec<[PlayingNote; 8]>,
        message: &MidiMessage,
    ) {
        match message {
            MidiMessage::NoteOn {
                note_id,
                channel,
                key,
                velocity,
            } if *velocity > 0 => {
                let note = PlayingNote {
                    note_id: *note_id,
                    channel: *channel,
                    key: *key,
                };
                if !playing_notes.contains(&note) {
                    playing_notes.push(note);
                }
            }
            MidiMessage::NoteOn {
                note_id,
                channel,
                key,
                ..
            }
            | MidiMessage::NoteOff {
                note_id,
                channel,
                key,
            } => playing_notes.retain(|note| {
                if let Some(note_id) = note_id {
                    note.note_id != Some(*note_id)
                } else {
                    note.channel != *channel || note.key != *key
                }
            }),
            MidiMessage::ControlChange {
                channel,
                controller,
                ..
            } if matches!(*controller, 120 | 123..=127) => {
                playing_notes.retain(|note| note.channel != *channel);
            }
            MidiMessage::ControlChange { .. }
            | MidiMessage::PitchBend { .. }
            | MidiMessage::NoteExpression { .. } => {}
        }
    }
}

/// Scheduled audio clip playback state.
pub struct AudioVoice {
    pub track_id: TrackId,
    pub waveform: AudioWaveform,
    /// Frame offset at which rendering starts in the current block.
    pub output_offset_samples: usize,
    /// Fractional source frame position.
    pub source_read_index: f64,
    /// First readable source frame.
    pub start_boundary: f64,
    /// Exclusive source-frame boundary.
    pub end_boundary: f64,
    pub clip_elapsed_samples: u32,
    pub clip_loop_length: u32,
}

/// Playback state for a browser or other temporary preview.
pub struct PreviewVoice {
    pub waveform: AudioWaveform,
    pub current_frame: f64,
    pub is_finished: bool,
    pub volume: f32,
    pub rendered_frames: u64,
    pub max_rendered_frames: Option<u64>,
}

impl PreviewVoice {
    pub fn new(waveform: AudioWaveform, volume: f32) -> Self {
        Self {
            waveform,
            current_frame: 0.0,
            is_finished: false,
            volume,
            rendered_frames: 0,
            max_rendered_frames: None,
        }
    }

    pub fn with_frame_limit(waveform: AudioWaveform, volume: f32, max_frames: u64) -> Self {
        Self {
            max_rendered_frames: Some(max_frames),
            ..Self::new(waveform, volume)
        }
    }
}

pub(super) struct VoiceState {
    pub active_generators: Vec<GeneratorVoice>,
    pub active_oneshots: Vec<AudioVoice>,
    pub preview_voices: Vec<PreviewVoice>,
}

impl VoiceState {
    pub fn new() -> Self {
        Self {
            active_generators: Vec::with_capacity(32),
            active_oneshots: Vec::with_capacity(16),
            preview_voices: Vec::with_capacity(4),
        }
    }

    pub fn for_export() -> Self {
        Self {
            active_generators: Vec::with_capacity(64),
            active_oneshots: Vec::with_capacity(32),
            preview_voices: Vec::with_capacity(4),
        }
    }

    pub fn update_playing_keys(playing_keys: &mut Vec<u8>, message: &MidiMessage) {
        match message {
            MidiMessage::NoteOn { key, velocity, .. } => {
                if *velocity > 0 {
                    if !playing_keys.contains(key) {
                        playing_keys.push(*key);
                    }
                } else {
                    playing_keys.retain(|playing_key| playing_key != key);
                }
            }
            MidiMessage::NoteOff { key, .. } => {
                playing_keys.retain(|playing_key| playing_key != key);
            }
            MidiMessage::ControlChange { controller, .. }
                if matches!(*controller, 120 | 123..=127) =>
            {
                playing_keys.clear();
            }
            MidiMessage::ControlChange { .. }
            | MidiMessage::PitchBend { .. }
            | MidiMessage::NoteExpression { .. } => {}
        }
    }

    pub fn queue_generator_event(
        &mut self,
        plugin_state: &AudioPluginState,
        generator_id: GeneratorId,
        event: MidiEvent,
    ) -> bool {
        let Some(generator) = plugin_state.get_generator(generator_id) else {
            return false;
        };
        let voice_index = self
            .active_generators
            .iter()
            .position(|voice| voice.id == generator_id)
            .unwrap_or_else(|| {
                self.active_generators.push(GeneratorVoice::new(
                    generator_id,
                    generator.track_id,
                    true,
                ));
                self.active_generators.len() - 1
            });
        let voice = &mut self.active_generators[voice_index];
        voice.midi_events.push(event);
        voice.active = true;
        true
    }

    pub fn ensure_generator_voice(
        active_generators: &mut Vec<GeneratorVoice>,
        plugin_state: &AudioPluginState,
        track_id: TrackId,
        generator: &GeneratorInstance,
    ) -> Option<usize> {
        if let Some(index) = active_generators
            .iter()
            .position(|voice| voice.id == generator.id)
        {
            return Some(index);
        }

        if plugin_state.get_generator(generator.id).is_some() {
            active_generators.push(GeneratorVoice::new(generator.id, track_id, true));
            return Some(active_generators.len() - 1);
        }

        None
    }

    pub fn render_oneshots(
        &mut self,
        sample_rate: u32,
        track_id: TrackId,
        output: &mut [f32],
        channels: usize,
        bpm: f32,
    ) -> bool {
        let mut did_render = false;
        let buffer_frames = output.len() / channels;
        let fade_samples = (sample_rate as f32 * 0.002) as u32;

        for voice in self
            .active_oneshots
            .iter_mut()
            .filter(|voice| voice.track_id == track_id)
        {
            did_render = true;
            let source_channels = voice.waveform.channels as usize;
            let Some(context) = voice.waveform.get_playback_context(bpm) else {
                continue;
            };

            let step =
                voice.waveform.sample_rate as f64 / sample_rate as f64 * context.playback_rate;
            let source = context.buffer;
            let source_frames = (source.len() / source_channels) as f64;
            let is_looping = voice.waveform.is_looping && source_frames > 0.0;
            let mut frames_to_process = buffer_frames.saturating_sub(voice.output_offset_samples);

            if !is_looping {
                let max_steps = (source_frames - 1.0 - voice.source_read_index) / step;
                frames_to_process = if max_steps < 0.0 {
                    0
                } else {
                    frames_to_process.min(max_steps.floor() as usize + 1)
                };
            }
            if frames_to_process == 0 {
                continue;
            }

            let start = voice.output_offset_samples * channels;
            let end = start + frames_to_process * channels;
            render_audio_waveform(
                &context.mode,
                source,
                source_channels,
                &mut output[start..end],
                channels,
                &mut voice.source_read_index,
                step,
                is_looping,
                source_frames,
                1.0,
                Some(&mut voice.clip_elapsed_samples),
                fade_samples,
                voice.clip_loop_length,
            );
            voice.output_offset_samples = 0;
        }

        did_render
    }

    pub fn render_previews(&mut self, output: &mut [f32], channels: usize, sample_rate: u32) {
        let buffer_frames = output.len() / channels;

        for voice in &mut self.preview_voices {
            if voice.is_finished {
                continue;
            }

            let source_channels = voice.waveform.channels as usize;
            let Some(source) = voice.waveform.get_playable_buffer() else {
                break;
            };
            let source_frames = (source.len() / source_channels) as f64;
            let step = voice.waveform.sample_rate as f64 / sample_rate as f64;
            let is_looping = voice.waveform.is_looping && source_frames > 0.0;
            let max_steps = (source_frames - 1.0 - voice.current_frame) / step;
            let mut frames_to_process = if !is_looping {
                if max_steps < 0.0 {
                    0
                } else {
                    buffer_frames.min(max_steps.floor() as usize + 1)
                }
            } else {
                buffer_frames
            };

            if let Some(max_rendered_frames) = voice.max_rendered_frames {
                let remaining = max_rendered_frames.saturating_sub(voice.rendered_frames);
                frames_to_process = frames_to_process.min(remaining as usize);
            }
            if frames_to_process == 0 {
                voice.is_finished = true;
                continue;
            }

            render_audio_waveform(
                &voice.waveform.sample_mode,
                source,
                source_channels,
                &mut output[..frames_to_process * channels],
                channels,
                &mut voice.current_frame,
                step,
                is_looping,
                source_frames,
                voice.volume,
                None,
                0,
                0,
            );
            voice.rendered_frames = voice
                .rendered_frames
                .saturating_add(frames_to_process as u64);
            if !is_looping && voice.current_frame >= source_frames - 1.0 {
                voice.is_finished = true;
            }
            if voice
                .max_rendered_frames
                .is_some_and(|max_frames| voice.rendered_frames >= max_frames)
            {
                voice.is_finished = true;
            }
        }

        self.preview_voices.retain(|voice| !voice.is_finished);
    }

    pub fn prepare_audio_voice(
        &mut self,
        track_id: TrackId,
        clip: &Clip,
        waveform: &AudioWaveform,
        buffer_start: u32,
        buffer_end: u32,
        sample_rate: u32,
    ) {
        let clip_start = clip.time.start_time_raw() as u32;
        let render_start = buffer_start.max(clip_start);
        let render_end = buffer_end.min(clip_start + clip.time.loop_length_raw() as u32);
        if render_end <= render_start {
            return;
        }

        let output_offset_samples = (render_start - buffer_start) as usize;
        let clip_elapsed_samples = render_start - clip_start;
        let effective_position = clip_elapsed_samples + clip.time.offset_start_raw() as u32;
        let source_position =
            effective_position as f64 * waveform.sample_rate as f64 / sample_rate as f64;
        let Some(source) = waveform.get_playable_buffer() else {
            return;
        };
        let source_frames = (source.len() / waveform.channels as usize) as f64;
        let source_read_index = if waveform.is_looping && source_frames > 0.0 {
            source_position % source_frames
        } else {
            if source_position >= source_frames {
                return;
            }
            source_position
        };

        self.active_oneshots.push(AudioVoice {
            track_id,
            waveform: waveform.clone(),
            output_offset_samples,
            source_read_index,
            start_boundary: 0.0,
            end_boundary: source_frames,
            clip_elapsed_samples,
            clip_loop_length: clip.time.loop_length_raw() as u32,
        });
    }

    pub fn schedule_midi_events(
        events: &mut SmallVec<[MidiEvent; 4]>,
        sample_rate: u32,
        tempo: f32,
        clip: &Clip,
        pattern: &Pattern,
        buffer_start: u32,
        buffer_end: u32,
    ) {
        let samples_per_beat = ((60.0 / tempo) * sample_rate as f32) as u32;
        if samples_per_beat == 0 {
            return;
        }
        let pattern_frames = (pattern.length_ticks as f64 / PPQ * samples_per_beat as f64) as u32;
        if pattern_frames == 0 {
            return;
        }

        let clip_start = clip.time.start_time_raw() as u32;
        let clip_end = clip_start + clip.time.loop_length_raw() as u32;
        let clip_offset = clip.time.offset_start_raw() as u32;

        for note in &pattern.notes {
            let note_id = Self::note_event_id(pattern.id, note.id);
            let note_start = (note.start_tick as f64 / PPQ * samples_per_beat as f64) as u32;
            let note_duration = (note.duration as f64 / PPQ * samples_per_beat as f64) as u32;
            if note_start < clip_offset {
                continue;
            }
            let absolute_start = clip_start + note_start - clip_offset;
            if absolute_start >= clip_end {
                continue;
            }
            let absolute_end = (absolute_start + note_duration).min(clip_end);

            if absolute_start >= buffer_start && absolute_start < buffer_end {
                events.push(MidiEvent {
                    sample_offset: (absolute_start - buffer_start) as usize,
                    data: MidiMessage::NoteOn {
                        note_id: Some(note_id),
                        channel: 0,
                        key: note.key,
                        velocity: note.velocity,
                    },
                });
            }
            if absolute_end >= buffer_start && absolute_end < buffer_end {
                events.push(MidiEvent {
                    sample_offset: (absolute_end - buffer_start) as usize,
                    data: MidiMessage::NoteOff {
                        note_id: Some(note_id),
                        channel: 0,
                        key: note.key,
                    },
                });
            }
        }
        events.sort_by_key(|event| event.sample_offset);
    }

    pub fn schedule_pattern_notes(
        events: &mut SmallVec<[MidiEvent; 4]>,
        pattern_id: crate::shared::PatternId,
        notes: &[Note],
        sample_rate: u32,
        tempo: f32,
        buffer_start: u32,
        buffer_end: u32,
    ) {
        let samples_per_tick = (60.0 / tempo) * sample_rate as f32 / PPQ as f32;
        for note in notes {
            let note_id = Self::note_event_id(pattern_id, note.id);
            let note_start = (note.start_tick as f32 * samples_per_tick) as u32;
            let note_end = note_start + (note.duration as f32 * samples_per_tick) as u32;
            if note_start >= buffer_start && note_start < buffer_end {
                events.push(MidiEvent {
                    sample_offset: (note_start - buffer_start) as usize,
                    data: MidiMessage::NoteOn {
                        note_id: Some(note_id),
                        channel: 0,
                        key: note.key,
                        velocity: note.velocity,
                    },
                });
            }
            if note_end >= buffer_start && note_end < buffer_end {
                events.push(MidiEvent {
                    sample_offset: (note_end - buffer_start) as usize,
                    data: MidiMessage::NoteOff {
                        note_id: Some(note_id),
                        channel: 0,
                        key: note.key,
                    },
                });
            }
        }
    }

    fn note_event_id(pattern_id: crate::shared::PatternId, note_id: crate::shared::NoteId) -> u64 {
        (u64::from(pattern_id.to_u32()) << 32) | u64::from(note_id.to_u32())
    }
}
