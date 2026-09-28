use karbeat_plugin_api::types::{MidiEvent, MidiMessage, NoteExpressionType};
use memmap2::Mmap;
use smallvec::SmallVec;
use std::sync::Arc;

use crate::{
    audio::{engine::helper::render_audio_waveform, render_state::AudioPluginState},
    core::project::{AudioWaveform, GeneratorInstance, Note, Pattern},
    shared::constants::f64::PPQ,
    shared::{GeneratorId, TrackId},
};

/// Borrowed parts of an audio graph used to decide which sounding notes changed.
#[derive(Clone, Copy)]
pub struct GraphView<'a> {
    pub tracks: &'a [crate::core::project::AudioTrack],
    pub clips: &'a hashbrown::HashMap<crate::core::project::ClipId, crate::core::project::Clip>,
    pub patterns: &'a hashbrown::HashMap<crate::shared::PatternId, Pattern>,
}

impl<'a> GraphView<'a> {
    /// The pattern and note behind a scheduled note ID (see `note_event_id`).
    fn pattern_note(&self, event_id: u64) -> Option<(&'a Pattern, &'a Note)> {
        let pattern_index = u32::try_from(event_id >> 32).ok()?;
        let note_index = u32::try_from(event_id & u64::from(u32::MAX)).ok()?;
        self.patterns
            .values()
            .filter(|pattern| pattern.id.to_u32() == pattern_index)
            .find_map(|pattern| {
                let note = pattern.notes.iter().find(|n| n.id.to_u32() == note_index)?;
                Some((pattern, note))
            })
    }

    /// Clips on `track_id` that play `pattern_id`.
    fn placements(
        &self,
        track_id: TrackId,
        pattern_id: crate::shared::PatternId,
    ) -> impl Iterator<Item = &'a crate::core::project::Clip> + 'a {
        let clips = self.clips;
        self.tracks
            .iter()
            .filter(move |track| track.id == track_id)
            .flat_map(|track| track.clips.iter())
            .filter_map(move |clip_id| clips.get(clip_id))
            .filter(move |clip| {
                matches!(
                    clip.source,
                    Some(crate::core::project::DawSource::Midi(id)) if id == pattern_id
                )
            })
    }

    /// Whether `pattern_id` sits in the same clips, at the same times, on `track_id` in
    /// both graphs.
    fn same_placement(
        &self,
        other: &GraphView<'_>,
        track_id: TrackId,
        pattern_id: crate::shared::PatternId,
    ) -> bool {
        self.placements(track_id, pattern_id).count()
            == other.placements(track_id, pattern_id).count()
            && self.placements(track_id, pattern_id).all(|clip| {
                other
                    .placements(track_id, pattern_id)
                    .any(|candidate| candidate.id == clip.id && candidate.time == clip.time)
            })
    }
}

/// Audio-thread reference to one active generator instance.
pub struct GeneratorVoice {
    pub id: GeneratorId,
    pub track_id: TrackId,
    pub midi_events: SmallVec<[MidiEvent; 4]>,
    pub active: bool,
    pub playing_keys: Vec<u8>,
    /// Notes the plugin is holding: updated only from events it actually received.
    pub playing_notes: SmallVec<[PlayingNote; 8]>,
    /// Whether the generator processed this block's events. Set by the renderer.
    pub delivered: bool,
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
    fn pattern_notes_carry_pan_and_pitch_as_expressions() {
        let note = crate::core::project::Note {
            id: NoteId::from(1),
            start_tick: 0,
            duration: 960,
            key: 60,
            velocity: 100,
            probability: 1.0,
            micro_offset: 0,
            mute: false,
            pan: -1.0,
            pitch: 1.0,
        };
        let mut events = SmallVec::new();
        VoiceState::schedule_pattern_notes(
            &mut events,
            PatternId::from(1),
            &[note],
            48_000,
            120.0,
            0,
            64,
        );

        let expressions: Vec<_> = events
            .iter()
            .filter_map(|event| match event.data {
                MidiMessage::NoteExpression {
                    expression, value, ..
                } => Some((expression, value)),
                _ => None,
            })
            .collect();
        assert!(matches!(events[0].data, MidiMessage::NoteOn { .. }));
        assert_eq!(
            expressions,
            [
                (NoteExpressionType::Pan, 0.0),
                (NoteExpressionType::Tuning, 0.75)
            ]
        );
    }

    #[test]
    fn note_off_on_another_key_keeps_the_held_key_tracked() {
        let mut notes = SmallVec::<[PlayingNote; 8]>::new();
        VoiceState::update_playing_notes(
            &mut notes,
            &MidiMessage::NoteOn {
                note_id: Some(7),
                channel: 0,
                key: 60,
                velocity: 100,
            },
        );
        VoiceState::update_playing_notes(
            &mut notes,
            &MidiMessage::NoteOff {
                note_id: Some(7),
                channel: 0,
                key: 64,
            },
        );
        assert_eq!(notes.len(), 1);
        assert_eq!(notes[0].key, 60);
    }

    #[test]
    fn undelivered_blocks_keep_one_release_per_held_note() {
        use crate::shared::{GeneratorId, TrackId};
        use karbeat_plugin_api::types::MidiEvent;

        let mut voice = super::GeneratorVoice::new(GeneratorId::from(1), TrackId::from(1), true);
        voice.midi_events.push(MidiEvent {
            sample_offset: 5,
            data: MidiMessage::NoteOn {
                note_id: Some(1),
                channel: 0,
                key: 60,
                velocity: 100,
            },
        });
        voice.delivered = true;
        voice.finish_block();
        assert_eq!(voice.playing_notes.len(), 1);

        // Stopped twice while the generator is not rendering, plus a stray note-on.
        voice.release_all();
        voice.release_all();
        voice.midi_events.push(MidiEvent {
            sample_offset: 9,
            data: MidiMessage::NoteOn {
                note_id: Some(2),
                channel: 0,
                key: 62,
                velocity: 100,
            },
        });
        voice.finish_block();
        voice.finish_block();
        assert_eq!(voice.midi_events.len(), 1);
        assert!(matches!(
            voice.midi_events[0].data,
            MidiMessage::NoteOff { key: 60, .. }
        ));
        assert_eq!(voice.playing_notes.len(), 1);

        voice.delivered = true;
        voice.finish_block();
        assert!(voice.playing_notes.is_empty());
        assert!(voice.midi_events.is_empty());
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
            delivered: false,
        }
    }

    pub fn track_midi_event(&mut self, message: &MidiMessage) {
        VoiceState::update_playing_notes(&mut self.playing_notes, message);
        VoiceState::update_playing_keys(&mut self.playing_keys, message);
    }

    fn note_off(note: PlayingNote) -> MidiEvent {
        MidiEvent {
            sample_offset: 0,
            data: MidiMessage::NoteOff {
                note_id: note.note_id,
                channel: note.channel,
                key: note.key,
            },
        }
    }

    fn is_release_of(event: &MidiEvent, note: PlayingNote) -> bool {
        matches!(
            event.data,
            MidiMessage::NoteOff { note_id, channel, key }
                if note_id == note.note_id && channel == note.channel && key == note.key
        )
    }

    /// Queues a note-off for a held note at the start of the next block, unless one is
    /// already queued. Tracking changes only once the plugin receives it.
    pub fn queue_release(&mut self, note: PlayingNote) {
        if !self
            .midi_events
            .iter()
            .any(|event| Self::is_release_of(event, note))
        {
            self.midi_events.push(Self::note_off(note));
        }
    }

    /// Queues note-offs for every note the plugin is holding.
    pub fn release_all(&mut self) {
        for index in 0..self.playing_notes.len() {
            self.queue_release(self.playing_notes[index]);
        }
    }

    /// Settles this block's events once rendering is done.
    ///
    /// When the generator ran, tracking follows what it received and the queue empties.
    /// When it did not run (its track was muted, soloed out, or skipped), note-ons are
    /// dropped but note-offs for held notes stay queued for the next block it runs, so a
    /// release is never lost. The queue stays bounded by the held notes.
    pub fn finish_block(&mut self) {
        if self.delivered {
            for event in &self.midi_events {
                VoiceState::update_playing_notes(&mut self.playing_notes, &event.data);
                VoiceState::update_playing_keys(&mut self.playing_keys, &event.data);
            }
            self.midi_events.clear();
        } else {
            // One pending note-off per held note that had a release queued.
            let pending: SmallVec<[PlayingNote; 8]> = self
                .playing_notes
                .iter()
                .copied()
                .filter(|note| {
                    self.midi_events
                        .iter()
                        .any(|event| Self::is_release_of(event, *note))
                })
                .collect();
            self.midi_events.clear();
            self.midi_events
                .extend(pending.into_iter().map(Self::note_off));
        }
        self.delivered = false;
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
                // A note-off only ends the note it names on the key it holds. An
                // off for the same ID on another key (a note moved while sounding)
                // leaves the held key tracked, so cleanup can still release it.
                let same_key = note.channel == *channel && note.key == *key;
                match note_id {
                    Some(note_id) => note.note_id != Some(*note_id) || !same_key,
                    None => !same_key,
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
    pub source: Arc<Mmap>,
    pub source_channels: usize,
    pub source_sample_rate: u32,
    pub sample_mode: crate::core::project::audio_waveform::AudioSampleMode,
    pub original_bpm: f32,
    pub is_looping: bool,
    pub source_start_sample: usize,
    pub source_end_sample: usize,
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
    /// Releases sounding pattern notes whose source changed when the track graph is
    /// replaced, so edits during playback never leave notes hanging.
    ///
    /// A note is released when it was deleted, moved, resized, or transposed, or, in song
    /// mode (`clips_matter`), when the clips placing its pattern on the voice's track were
    /// moved, resized, or removed. Each note-off uses the key and channel actually held,
    /// not the edited note's. Unchanged notes, and notes that are not from a pattern (live
    /// input), keep sounding.
    pub fn release_changed_notes(
        &mut self,
        old: GraphView<'_>,
        new: GraphView<'_>,
        clips_matter: bool,
    ) {
        for voice in &mut self.active_generators {
            for index in 0..voice.playing_notes.len() {
                let playing = voice.playing_notes[index];
                let Some(event_id) = playing.note_id else {
                    continue;
                };
                let Some((pattern, before)) = old.pattern_note(event_id) else {
                    continue;
                };
                let note_unchanged = new.pattern_note(event_id).is_some_and(|(_, after)| {
                    after.start_tick == before.start_tick
                        && after.duration == before.duration
                        && after.key == before.key
                });
                let placement_unchanged =
                    !clips_matter || old.same_placement(&new, voice.track_id, pattern.id);
                if !note_unchanged || !placement_unchanged {
                    voice.queue_release(playing);
                }
            }
        }
    }

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
            let raw_source: &[f32] = bytemuck::cast_slice(&voice.source[..]);
            let Some(source) = raw_source.get(voice.source_start_sample..voice.source_end_sample)
            else {
                continue;
            };

            let playback_rate = match voice.sample_mode {
                crate::core::project::audio_waveform::AudioSampleMode::Default => 1.0,
                crate::core::project::audio_waveform::AudioSampleMode::Stretch
                | crate::core::project::audio_waveform::AudioSampleMode::Resampled => {
                    (bpm / voice.original_bpm.max(1.0)) as f64
                }
            };

            let step = voice.source_sample_rate as f64 / sample_rate as f64 * playback_rate;
            let source_frames = (source.len() / voice.source_channels) as f64;
            let is_looping = voice.is_looping && source_frames > 0.0;
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
                &voice.sample_mode,
                source,
                voice.source_channels,
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
        clip_start: u32,
        clip_loop_length: u32,
        clip_offset: u32,
        waveform: &AudioWaveform,
        buffer_start: u32,
        buffer_end: u32,
        sample_rate: u32,
    ) {
        let render_start = buffer_start.max(clip_start);
        let render_end = buffer_end.min(clip_start + clip_loop_length);
        if render_end <= render_start {
            return;
        }

        let output_offset_samples = (render_start - buffer_start) as usize;
        let clip_elapsed_samples = render_start - clip_start;
        let effective_position = clip_elapsed_samples + clip_offset;
        let source_position =
            effective_position as f64 * waveform.sample_rate as f64 / sample_rate as f64;
        let Some(source) = waveform.get_playable_buffer() else {
            return;
        };
        let Some(mapped_source) = waveform.buffer.as_ref() else {
            return;
        };
        let raw_source: &[f32] = bytemuck::cast_slice(&mapped_source[..]);
        let source_start_sample = source.as_ptr() as usize - raw_source.as_ptr() as usize;
        let source_start_sample = source_start_sample / std::mem::size_of::<f32>();
        let source_end_sample = source_start_sample + source.len();
        let source_channels = waveform.channels as usize;
        let source_frames = (source.len() / source_channels) as f64;
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
            source: Arc::clone(mapped_source),
            source_channels,
            source_sample_rate: waveform.sample_rate,
            sample_mode: waveform.sample_mode,
            original_bpm: waveform.original_bpm,
            is_looping: waveform.is_looping,
            source_start_sample,
            source_end_sample,
            output_offset_samples,
            source_read_index,
            start_boundary: 0.0,
            end_boundary: source_frames,
            clip_elapsed_samples,
            clip_loop_length,
        });
    }

    pub fn schedule_midi_events(
        events: &mut SmallVec<[MidiEvent; 4]>,
        sample_rate: u32,
        tempo: f32,
        pattern: &Pattern,
        clip_start: u32,
        clip_loop_length: u32,
        clip_offset: u32,
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

        let clip_end = clip_start + clip_loop_length;

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
                let sample_offset = (absolute_start - buffer_start) as usize;
                events.push(MidiEvent {
                    sample_offset,
                    data: MidiMessage::NoteOn {
                        note_id: Some(note_id),
                        channel: 0,
                        key: note.key,
                        velocity: note.velocity,
                    },
                });
                Self::push_note_expressions(events, sample_offset, note_id, note);
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
                let sample_offset = (note_start - buffer_start) as usize;
                events.push(MidiEvent {
                    sample_offset,
                    data: MidiMessage::NoteOn {
                        note_id: Some(note_id),
                        channel: 0,
                        key: note.key,
                        velocity: note.velocity,
                    },
                });
                Self::push_note_expressions(events, sample_offset, note_id, note);
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

    /// Sends a note's pan and fine pitch as per-note expressions at its note-on. Values are
    /// normalized: pan 0.5 and pitch 0.5 are neutral, with pitch spanning
    /// ±[`PITCH_RANGE`](crate::core::project::track::note_transform::PITCH_RANGE) semitones.
    fn push_note_expressions(
        events: &mut SmallVec<[MidiEvent; 4]>,
        sample_offset: usize,
        note_id: u64,
        note: &Note,
    ) {
        use crate::core::project::track::note_transform::PITCH_RANGE;
        if note.pan != 0.0 {
            events.push(MidiEvent {
                sample_offset,
                data: MidiMessage::NoteExpression {
                    note_id,
                    expression: NoteExpressionType::Pan,
                    value: (note.pan.clamp(-1.0, 1.0) + 1.0) * 0.5,
                },
            });
        }
        if note.pitch != 0.0 {
            events.push(MidiEvent {
                sample_offset,
                data: MidiMessage::NoteExpression {
                    note_id,
                    expression: NoteExpressionType::Tuning,
                    value: (note.pitch.clamp(-PITCH_RANGE, PITCH_RANGE) + PITCH_RANGE)
                        / (2.0 * PITCH_RANGE),
                },
            });
        }
    }

    fn note_event_id(pattern_id: crate::shared::PatternId, note_id: crate::shared::NoteId) -> u64 {
        (u64::from(pattern_id.to_u32()) << 32) | u64::from(note_id.to_u32())
    }
}
