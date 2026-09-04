use crate::{
    apply_mix_param,
    audio::{
        engine::{
            buffer::AudioBuffer,
            helper::*,
            metronome::MetronomeState,
            modulation::{LiveModulationSource, ModulationState},
            routing::RoutingState,
            runtime::*,
            telemetry::{AudioEngineTelemetry, DSP_LOAD_PERCENT, PluginTelemetrySnapshot},
            transport::{PlaybackMode, TransportState},
            types::*,
            voices::{GeneratorVoice, VoiceState},
            workspace::RenderWorkspace,
        },
        event::{PluginTarget, TransportFeedback},
        render_state::{AudioEffectInstance, AudioPluginState, AudioRenderState},
    },
    commands::{AudioCommand, AudioFeedback, EffectTarget, TelemetryRegistration},
    core::project::*,
    shared::{constants::f64::PPQ, id::*},
    utils::{apply_simd_mix, apply_simd_mix_gain},
};
use hashbrown::HashMap;
use karbeat_plugin_types::SmoothableParam;
use rtrb::{Consumer, Producer};
use smallvec::SmallVec;
use std::{
    sync::{atomic::Ordering, mpsc},
    time::Instant,
};

pub struct AudioEngine {
    pub(super) io: EngineIo,

    // ======================================
    // Graph State (owned by audio thread)
    // Updated exclusively via ring-buffer commands — no triple-buffer
    // ======================================
    pub(super) current_state: AudioRenderState,

    pub(super) config: AudioEngineConfig,
    pub(super) transport: TransportState,

    pub(super) voices: VoiceState,

    // Audio thread's owned plugins - NO locks required
    pub(super) plugin_state: AudioPluginState,

    // Audio-thread-owned mixer channel DSP state.
    // Updated via SetMixerChannelParameter commands; queried via QueryMixerChannel.
    pub(super) mixer_state: AudioMixerState,

    pub(super) workspace: RenderWorkspace,
    pub(super) routing: RoutingState,
    pub(super) modulation: ModulationState,

    //////////////////////////////////////////////////
    /// Metronome state
    /////////////////////////////////////////////////
    pub(super) metronome_state: MetronomeState,

    pub(super) telemetry: AudioEngineTelemetry,
}

/// Immutable capture of the live engine data needed to construct an offline renderer.
pub struct AudioExportSnapshot {
    render_state: AudioRenderState,
    config: AudioEngineConfig,
    bpm: f32,
    time_sig_numerator: u8,
    time_sig_denominator: u8,
    bus_ids: Vec<BusId>,
    plugin_state: AudioPluginState,
    mixer_state: AudioMixerState,
    modulation: ModulationState,
}

impl AudioEngine {
    pub fn new(
        command_consumer: Consumer<AudioCommand>,
        position_producer: Producer<TransportFeedback>,
        feedback_producer: Producer<AudioFeedback>,
        sample_rate: u32,
        num_channels: u16,
        initial_bpm: f32,
        buffer_size: usize,
        telemetry: AudioEngineTelemetry,
        telemetry_reg_sender: mpsc::SyncSender<TelemetryRegistration>,
    ) -> Self {
        // Seed the graph snapshot with the real audio config so that
        // AddGenerator / AddEffect commands that arrive before the first
        // ReplaceFullGraph have a valid sample_rate and buffer_size to
        // prepare plugins with, rather than the default 0 / 0.
        let mut initial_state = AudioRenderState::default();
        initial_state.graph.sample_rate = sample_rate;
        initial_state.graph.buffer_size = buffer_size;

        Self {
            io: EngineIo {
                command_consumer,
                position_producer,
                feedback_producer,
                telemetry_reg_sender,
            },
            current_state: initial_state,
            config: AudioEngineConfig::new(sample_rate, num_channels),
            transport: TransportState::new(initial_bpm),
            voices: VoiceState::new(),
            plugin_state: AudioPluginState::default(),
            mixer_state: AudioMixerState::default(),
            workspace: RenderWorkspace::new(buffer_size, num_channels),
            routing: RoutingState::default(),
            modulation: ModulationState::default(),
            metronome_state: MetronomeState::default(),
            telemetry,
        }
    }

    /// Captures only the live engine state required for offline rendering.
    pub fn export_snapshot(&self) -> AudioExportSnapshot {
        AudioExportSnapshot {
            render_state: self.current_state.clone(),
            config: self.config,
            bpm: self.transport.bpm,
            time_sig_numerator: self.transport.time_sig_numerator,
            time_sig_denominator: self.transport.time_sig_denominator,
            bus_ids: self.workspace.bus_buffers.keys().copied().collect(),
            plugin_state: self.plugin_state.clone(),
            mixer_state: self.mixer_state.clone(),
            modulation: self.modulation.for_export(),
        }
    }

    /// Builds a fresh offline renderer from a read-only live-engine snapshot.
    pub fn from_export_snapshot(
        snapshot: AudioExportSnapshot,
        command_consumer: Consumer<AudioCommand>,
        position_producer: Producer<TransportFeedback>,
        feedback_producer: Producer<AudioFeedback>,
    ) -> Self {
        let AudioExportSnapshot {
            render_state,
            config,
            bpm,
            time_sig_numerator,
            time_sig_denominator,
            bus_ids,
            plugin_state,
            mixer_state,
            modulation,
        } = snapshot;

        let mut transport = TransportState::new(bpm);
        transport.time_sig_numerator = time_sig_numerator;
        transport.time_sig_denominator = time_sig_denominator;

        let mut workspace =
            RenderWorkspace::new(render_state.graph.buffer_size, config.num_channels);
        for &bus_id in &bus_ids {
            workspace.bus_buffers.insert(bus_id, Vec::new());
        }

        let mut routing = RoutingState::default();
        routing.cached_order = compute_routing_order(
            render_state.graph.tracks.iter().map(|track| track.id),
            bus_ids.into_iter(),
            &render_state.graph.routing,
        );

        let mut engine = Self {
            io: EngineIo {
                command_consumer,
                position_producer,
                feedback_producer,
                telemetry_reg_sender: mpsc::sync_channel(0).0,
            },
            current_state: render_state,
            config,
            transport,
            voices: VoiceState::for_export(),
            plugin_state,
            mixer_state,
            workspace,
            routing,
            modulation,
            metronome_state: MetronomeState::default(),
            telemetry: AudioEngineTelemetry::new_for_export(),
        };
        engine.recalculate_latencies();
        engine
    }

    pub fn plugin_state(&self) -> &AudioPluginState {
        &self.plugin_state
    }

    /// Renders one interleaved block into any storage exposing mutable audio samples.
    pub fn process<B: AudioBuffer + ?Sized>(&mut self, output_buffer: &mut B) {
        self.process_interleaved(output_buffer.samples_mut());
    }

    fn process_interleaved(&mut self, output_buffer: &mut [f32]) {
        let start_time = Instant::now();

        self.modulation.block_param_changes.clear();

        // Process Commands (Play, Stop, Seek, Graph updates)
        while let Ok(cmd) = self.io.command_consumer.pop() {
            self.process_command(cmd);
        }

        // Poll every plugin; latency flags are edge-triggered and must all be consumed.
        let plugin_latency_changed = itertools::chain!(
            self.plugin_state
                .generators
                .iter_mut()
                .map(|(_, generator)| &mut generator.plugin),
            self.plugin_state
                .track_effects
                .iter_mut()
                .flatten()
                .map(|effect| &mut effect.plugin),
            self.plugin_state
                .bus_effects
                .iter_mut()
                .flatten()
                .map(|effect| &mut effect.plugin),
            self.plugin_state
                .master_effects
                .iter_mut()
                .map(|effect| &mut effect.plugin),
        )
        .fold(false, |changed, plugin| {
            plugin.has_latency_changed() || changed
        });

        if plugin_latency_changed {
            self.recalculate_latencies();
        }

        // Clear Buffer
        output_buffer.fill(0.0);
        let channels = 2;
        let frame_count = output_buffer.len() / channels;

        // Transport Logic
        let is_currently_playing = self.transport.is_playing();

        if is_currently_playing {
            match self.transport.mode {
                PlaybackMode::Song => {
                    self.process_song_mode(frame_count, output_buffer, channels);
                }
                PlaybackMode::Pattern {
                    pattern_id,
                    generator_id,
                } => {
                    self.process_pattern_mode(
                        pattern_id,
                        generator_id,
                        frame_count,
                        output_buffer,
                        channels,
                    );
                }
            }
        } else {
            self.render_voices_to_buffer(output_buffer, channels, false);
            self.cleanup_finished_voices(frame_count);
        }

        // Always Render Previews (Metronome, Browser Preview)
        self.render_previews_to_buffer(output_buffer, channels);

        // Clock the mixer state snapshot
        if self.telemetry.advance(frame_count, self.config.sample_rate) {
            self.emit_all_mixer_snapshots();
            self.emit_plugin_telemetry();
        }

        let elapsed = start_time.elapsed().as_secs_f32();

        let block_size = output_buffer.len() / (self.config.num_channels as usize); // Assuming stereo
        let max_time_allowed = (block_size as f32) / (self.config.sample_rate as f32);

        let load_percent = (elapsed / max_time_allowed) * 100.0;

        // Apply a simple low-pass filter to smooth the jittery meter
        let current_smoothed = f32::from_bits(DSP_LOAD_PERCENT.load(Ordering::Relaxed));
        let new_smoothed = current_smoothed + 0.1 * (load_percent - current_smoothed);

        DSP_LOAD_PERCENT.store(new_smoothed.to_bits(), Ordering::Relaxed)
    }

    fn advance_song_playhead(&mut self, frame_count: usize) {
        self.transport.song.playhead_samples += frame_count as u32;
        self.recalculate_beat_bar();
        self.emit_playback_position();
        self.cleanup_finished_voices(frame_count);
    }

    fn advance_pattern_playhead(&mut self, frame_count: usize) {
        self.transport.pattern.playhead_samples += frame_count as u32;
        self.recalculate_pattern_beat_bar();
        self.emit_playback_position();
        self.cleanup_finished_voices(frame_count);
    }

    /// Recalculates pattern beat/bar based on pattern_playhead_samples
    pub(super) fn recalculate_pattern_beat_bar(&mut self) {
        self.transport
            .recalculate_pattern_position(self.config.sample_rate);
    }

    fn process_song_mode(
        &mut self,
        frame_count: usize,
        output_buffer: &mut [f32],
        channels: usize,
    ) {
        let song_end = self.current_state.graph.max_sample_index;

        // Only enforce the auto-stop/loop boundary if the project actually has content (song_end > 0)
        if song_end > 0 && self.transport.song.playhead_samples > song_end {
            if self.transport.song.is_looping {
                self.transport.song.playhead_samples = 0;
                self.recalculate_beat_bar();
                self.transport.song.last_emitted_samples = 0;

                // Kill trailing notes/audio to prevent a massive wall of sound
                // from release tails accumulating when jumping back to bar 1
                self.stop_all_active_generators();
                self.voices.active_oneshots.clear();

                self.process_block_song_mode(frame_count, output_buffer, channels);
                self.emit_current_playback_position();
            } else {
                // If not looping, stop playback normally
                self.stop_playback();
                self.render_voices_to_buffer(output_buffer, channels, false);
                self.cleanup_finished_voices(frame_count);
            }
        } else {
            self.process_block_song_mode(frame_count, output_buffer, channels);
        }
    }

    // Process a block of frame rendering in SONG mode (normal playback)
    fn process_block_song_mode(
        &mut self,
        buffer_size: usize,
        output_buffer: &mut [f32],
        channels: usize,
    ) {
        self.resolve_sequencer_events(buffer_size);
        self.evaluate_pre_block_modulations(buffer_size);
        self.render_voices_to_buffer(output_buffer, channels, true);
        self.metronome_state.render(
            output_buffer,
            channels,
            self.transport.song.playhead_samples,
            self.transport.bpm,
            self.config.sample_rate,
        );
        self.advance_song_playhead(buffer_size);
    }

    fn process_pattern_mode(
        &mut self,
        pattern_id: PatternId,
        generator_id: GeneratorId,
        frame_count: usize,
        output_buffer: &mut [f32],
        channels: usize,
    ) {
        let pattern = match self.current_state.graph.patterns.get(&pattern_id) {
            Some(p) => p,
            None => {
                // Pattern deleted? Stop.
                self.stop_playback();
                return;
            }
        };

        // Verify the generator exists in plugin_state
        if self.plugin_state.get_generator(generator_id).is_none() {
            log::warn!("Pattern preview: Generator {:?} not found", generator_id);
            self.stop_playback();
            return;
        }

        let tempo = self.transport.bpm;
        let sample_rate = self.config.sample_rate as f32;

        let samples_per_beat = (60.0 / tempo) * sample_rate;
        let loop_len_samples =
            (((pattern.length_ticks as f32) / PPQ as f32) * samples_per_beat) as u32;

        if loop_len_samples == 0 {
            return;
        }

        // Use PATTERN playhead (independent from song)
        if self.transport.pattern.playhead_samples >= loop_len_samples {
            self.transport.pattern.playhead_samples = 0;
            self.transport.pattern.last_emitted_samples = 0;

            // This safely clears tracked keys to prevent hang on pattern loop
            Self::stop_all_active_generators_impl(
                &mut self.voices.active_generators,
                &mut self.plugin_state,
                self.config.sample_rate,
            );
        }

        let start_time = self.transport.pattern.playhead_samples;
        let end_time = start_time + (frame_count as u32);

        // Find or create voice for this generator
        let voice_idx = self
            .voices
            .active_generators
            .iter()
            .position(|g| g.id == generator_id)
            .unwrap_or_else(|| {
                // Get the track_id from plugin_state if available
                let track_id = self
                    .plugin_state
                    .get_generator(generator_id)
                    .map(|g| g.track_id)
                    .unwrap_or(TrackId::from(0));

                self.voices.active_generators.push(GeneratorVoice::new(
                    generator_id,
                    track_id,
                    true,
                ));
                self.voices.active_generators.len() - 1
            });

        let gen_voice = &mut self.voices.active_generators[voice_idx];
        gen_voice.active = true;

        Self::schedule_pattern_notes_raw(
            &mut gen_voice.midi_events,
            pattern_id,
            &pattern.notes,
            self.config.sample_rate,
            tempo,
            start_time,
            end_time,
        );

        gen_voice.midi_events.sort_by_key(|e| e.sample_offset);

        self.evaluate_pre_block_modulations(frame_count);

        // Render voices to buffer
        self.render_voices_to_buffer(output_buffer, channels, true);

        self.metronome_state.render(
            output_buffer,
            channels,
            start_time,
            self.transport.bpm,
            self.config.sample_rate,
        );

        // Advance PATTERN playhead (not song playhead)
        self.advance_pattern_playhead(frame_count);
    }

    /// Stop and reset the playhead to 0
    pub(super) fn stop_playback(&mut self) {
        self.transport.song.is_playing = false;
        self.transport.pattern.is_playing = false;
        self.stop_all_active_generators();

        self.reset_playhead();
        self.reset_pattern_state();

        // Emit exactly ONCE after both playheads are perfectly zeroed out
        self.emit_static_position();
    }

    pub(super) fn stop_all_active_generators(&mut self) {
        Self::stop_all_active_generators_impl(
            &mut self.voices.active_generators,
            &mut self.plugin_state,
            self.config.sample_rate,
        );
    }

    pub(super) fn stop_all_active_generators_impl(
        active_generators: &mut Vec<GeneratorVoice>,
        plugin_state: &mut AudioPluginState,
        sample_rate: u32,
    ) {
        for voice in active_generators.iter_mut() {
            for note in &voice.playing_notes {
                voice.midi_events.push(MidiEvent {
                    sample_offset: 0,
                    data: MidiMessage::NoteOff {
                        note_id: note.note_id,
                        channel: note.channel,
                        key: note.key,
                    },
                });
            }

            voice.playing_keys.clear();
            voice.playing_notes.clear();

            if let Some(gen_instance) = plugin_state.get_generator(voice.id) {
                // clamp tail to save CPU because who the hell is gonna have more than 20 seconds of reverb tail?
                let tail = gen_instance.plugin.tail_samples().min(20 * sample_rate);
                voice.tail_remaining = Some(tail);
            }
        }
    }

    pub(super) fn get_effect_list_mut(
        &mut self,
        target: &EffectTarget,
    ) -> Option<&mut Vec<AudioEffectInstance>> {
        match target {
            EffectTarget::Track(track_id) => self
                .plugin_state
                .get_track_effects_mut(track_id.to_u32() as usize),
            EffectTarget::Bus(bus_id) => self
                .plugin_state
                .get_bus_effects_mut(bus_id.to_u32() as usize),
            EffectTarget::Master => Some(&mut self.plugin_state.master_effects),
        }
    }

    pub(super) fn get_effect_list(
        &self,
        target: &EffectTarget,
    ) -> Option<&Vec<AudioEffectInstance>> {
        match target {
            EffectTarget::Track(track_id) => self
                .plugin_state
                .get_track_effects(track_id.to_u32() as usize),
            EffectTarget::Bus(bus_id) => {
                self.plugin_state.get_bus_effects(bus_id.to_u32() as usize)
            }
            EffectTarget::Master => Some(&self.plugin_state.master_effects),
        }
    }

    pub(super) fn get_plugin_mut<'a>(
        &'a mut self,
        target: &PluginTarget,
    ) -> Option<&'a mut Box<dyn crate::core::project::plugin::AudioPlugin + Send + Sync>> {
        match target {
            PluginTarget::Generator(id) => self
                .plugin_state
                .get_generator_mut(*id)
                .map(|i| &mut i.plugin),
            PluginTarget::TrackEffect(track_id, effect_id) => self
                .get_effect_list_mut(&EffectTarget::Track(*track_id))?
                .iter_mut()
                .find(|e| e.id == *effect_id)
                .map(|e| &mut e.plugin),
            PluginTarget::BusEffect(bus_id, effect_id) => self
                .get_effect_list_mut(&EffectTarget::Bus(*bus_id))?
                .iter_mut()
                .find(|e| e.id == *effect_id)
                .map(|e| &mut e.plugin),
            PluginTarget::MasterEffect(effect_id) => self
                .get_effect_list_mut(&EffectTarget::Master)?
                .iter_mut()
                .find(|e| e.id == *effect_id)
                .map(|e| &mut e.plugin),
        }
    }

    pub(super) fn get_plugin<'a>(
        &'a self,
        target: &PluginTarget,
    ) -> Option<&'a Box<dyn crate::core::project::plugin::AudioPlugin + Send + Sync>> {
        match target {
            PluginTarget::Generator(id) => self.plugin_state.get_generator(*id).map(|i| &i.plugin),
            PluginTarget::TrackEffect(track_id, effect_id) => self
                .get_effect_list(&EffectTarget::Track(*track_id))?
                .iter()
                .find(|e| e.id == *effect_id)
                .map(|e| &e.plugin),
            PluginTarget::BusEffect(bus_id, effect_id) => self
                .get_effect_list(&EffectTarget::Bus(*bus_id))?
                .iter()
                .find(|e| e.id == *effect_id)
                .map(|e| &e.plugin),
            PluginTarget::MasterEffect(effect_id) => self
                .get_effect_list(&EffectTarget::Master)?
                .iter()
                .find(|e| e.id == *effect_id)
                .map(|e| &e.plugin),
        }
    }

    pub(super) fn reset_pattern_state(&mut self) {
        self.transport.reset_pattern();
    }

    /// Recalculates current Beat and Bar based on playhead_samples
    /// Uses 1-based indexing for musical time.
    pub(super) fn recalculate_beat_bar(&mut self) {
        self.transport
            .recalculate_song_position(self.config.sample_rate);
    }

    fn reset_playhead(&mut self) {
        log::info!("[AudioEngine] Reset Playhead");
        self.transport.reset_song();
    }

    fn emit_playback_position(&mut self) {
        let emission_interval = self.config.sample_rate / 60; // ~60fps
        let (current, last) = match self.transport.mode {
            PlaybackMode::Song => (
                self.transport.song.playhead_samples,
                self.transport.song.last_emitted_samples,
            ),
            PlaybackMode::Pattern { .. } => (
                self.transport.pattern.playhead_samples,
                self.transport.pattern.last_emitted_samples,
            ),
        };
        if current >= last + emission_interval {
            if !self.io.position_producer.is_full() {
                let _ = self
                    .io
                    .position_producer
                    .push(self.build_position_struct(Some(true)));
            }
            match self.transport.mode {
                PlaybackMode::Song => {
                    self.transport.song.last_emitted_samples = self.transport.song.playhead_samples;
                }
                PlaybackMode::Pattern { .. } => {
                    self.transport.pattern.last_emitted_samples =
                        self.transport.pattern.playhead_samples;
                }
            }
        }
    }

    fn emit_static_position(&mut self) {
        if !self.io.position_producer.is_full() {
            let _ = self
                .io
                .position_producer
                .push(self.build_position_struct(Some(false)));
        }
    }

    fn build_position_struct(&self, is_playing: Option<bool>) -> TransportFeedback {
        self.transport
            .position_feedback(self.config.sample_rate, is_playing)
    }

    pub(super) fn emit_current_playback_position(&mut self) {
        if !self.io.position_producer.is_full() {
            let _ = self
                .io
                .position_producer
                .push(self.build_position_struct(None));
        }
    }

    fn cleanup_finished_voices(&mut self, frame_count: usize) {
        // Generators stay alive (persistent), just clear their MIDI events for the next frame
        for gen_voice in self.voices.active_generators.iter_mut() {
            // DYNAMICALLY UPDATE PLAYING KEYS based on what just happened in this audio block
            for event in &gen_voice.midi_events {
                VoiceState::update_playing_notes(&mut gen_voice.playing_notes, &event.data);
                VoiceState::update_playing_keys(&mut gen_voice.playing_keys, &event.data);
            }

            // Now it's safe to clear events for the next block
            gen_voice.midi_events.clear();
            // gen_voice.automation_events.clear();

            // SAFE TAIL HANDLING
            if gen_voice.playing_notes.is_empty() {
                // Initialize the tail tracker if normal playback just ended a note
                if gen_voice.tail_remaining.is_none() {
                    if let Some(gen_instance) = self.plugin_state.get_generator(gen_voice.id) {
                        let tail = gen_instance
                            .plugin
                            .tail_samples()
                            .min(20 * self.config.sample_rate);
                        gen_voice.tail_remaining = Some(tail);
                    }
                }

                // Decrement the tail
                if let Some(tail) = gen_voice.tail_remaining {
                    let new_tail = tail.saturating_sub(frame_count as u32);

                    if new_tail == 0 {
                        if let Some(gen_instance) =
                            self.plugin_state.get_generator_mut(gen_voice.id)
                        {
                            gen_instance.plugin.reset();
                        }

                        // clear the tail and flag for culling
                        gen_voice.tail_remaining = None;
                        gen_voice.active = false;
                    } else {
                        gen_voice.tail_remaining = Some(new_tail);
                    }
                }
            } else {
                // If a new key is pressed, abort any lingering tail countdown
                gen_voice.tail_remaining = None;
            }
        }

        self.voices.active_generators.retain(|g| g.active);

        self.voices.active_oneshots.clear();
    }

    pub(super) fn trigger_live_note(
        &mut self,
        generator_id: GeneratorId,
        key: u8,
        velocity: u8,
        is_on: bool,
    ) {
        // Try to find the track that has this generator from current_state
        let target_info = self.current_state.graph.tracks.iter().find_map(|t| {
            if let Some(gen_) = &t.generator {
                if gen_.id == generator_id {
                    return Some((t.id, gen_.clone()));
                }
            }
            None
        });

        // If we found the track info, use it
        if let Some((track_id, gen_instance)) = target_info {
            if let Some(voice_idx) = Self::ensure_generator_voice(
                &mut self.voices.active_generators,
                &self.plugin_state,
                track_id,
                &gen_instance,
            ) {
                let gen_voice = &mut self.voices.active_generators[voice_idx];
                let message = if is_on {
                    MidiMessage::NoteOn {
                        note_id: None,
                        channel: 0,
                        key,
                        velocity,
                    }
                } else {
                    MidiMessage::NoteOff {
                        note_id: None,
                        channel: 0,
                        key,
                    }
                };

                gen_voice.midi_events.push(MidiEvent {
                    sample_offset: 0,
                    data: message,
                });
                gen_voice.active = true;
                return;
            }
        }

        // Fallback: If triple buffer hasn't synced yet, check plugin_state directly
        // This handles the case where AudioCommand::AddGenerator was received but
        // the UI hasn't updated current_state via triple buffer yet
        if let Some(gen_instance) = self.plugin_state.get_generator(generator_id) {
            let track_id = gen_instance.track_id;

            // Find or create voice
            let voice_idx = self
                .voices
                .active_generators
                .iter()
                .position(|g| g.id == generator_id)
                .unwrap_or_else(|| {
                    self.voices.active_generators.push(GeneratorVoice::new(
                        generator_id,
                        track_id,
                        true,
                    ));
                    self.voices.active_generators.len() - 1
                });

            let gen_voice = &mut self.voices.active_generators[voice_idx];
            let message = if is_on {
                MidiMessage::NoteOn {
                    note_id: None,
                    channel: 0,
                    key,
                    velocity,
                }
            } else {
                MidiMessage::NoteOff {
                    note_id: None,
                    channel: 0,
                    key,
                }
            };

            gen_voice.midi_events.push(MidiEvent {
                sample_offset: 0,
                data: message,
            });
            gen_voice.active = true;
        } else {
            log::warn!(
                "PlayPreviewNote: Generator ID {:?} not found in plugin_state or graph",
                generator_id
            );
        }
    }

    fn render_voices_to_buffer(&mut self, output: &mut [f32], channels: usize, is_playing: bool) {
        let buf_len = output.len();

        // Peak meters react immediately and fall by roughly 20 dB/second.
        // Decaying every channel here also guarantees muted and inactive
        // channels return to silence instead of retaining a stale reading.
        let frames = buf_len / channels.max(1);
        let release_factor =
            10.0_f32.powf(-((frames as f32) / self.config.sample_rate.max(1) as f32));
        for channel in self.mixer_state.track_channels.values_mut() {
            channel.decay_magnitude(release_factor);
        }
        for channel in self.mixer_state.bus_channels.values_mut() {
            channel.decay_magnitude(release_factor);
        }
        self.mixer_state.master.decay_magnitude(release_factor);

        // Clear signal flow tracker for this new frame
        self.routing.node_has_signal.clear();

        // Ensure bus buffers are properly sized
        for (_bus_id, buf) in self.workspace.bus_buffers.iter_mut() {
            if buf.len() != buf_len {
                buf.resize(buf_len, 0.0);
            }
            buf.fill(0.0);
        }

        // Ensure aux (sidechain) buffers are properly sized and cleared
        for (_aux_id, buf) in self.workspace.aux_buffers.iter_mut() {
            if buf.len() != buf_len {
                buf.resize(buf_len, 0.0);
            }
            buf.fill(0.0);
        }

        // Check for solo state
        let is_any_solo = self.mixer_state.track_channels.values().any(|ch| ch.solo);

        // Get routing info
        let routing = self.current_state.graph.routing.clone();

        let sample_rate = self.config.sample_rate as f64;
        let bpm = self.transport.bpm as f64;
        let sample_position = match self.transport.mode {
            PlaybackMode::Song => self.transport.song.playhead_samples as u64,
            PlaybackMode::Pattern { .. } => self.transport.pattern.playhead_samples as u64,
        };

        let samples_per_beat = (60.0 / bpm) * sample_rate;
        let beat_position = if samples_per_beat > 0.0 {
            (sample_position as f64) / samples_per_beat + 1.0
        } else {
            1.0
        };
        let bar_position = if self.transport.time_sig_numerator > 0 {
            (beat_position - 1.0) / (self.transport.time_sig_numerator as f64) + 1.0
        } else {
            1.0
        };

        let base_ctx = ProcessContext {
            bpm,
            time_sig_numerator: self.transport.time_sig_numerator,
            time_sig_denominator: self.transport.time_sig_denominator,
            is_playing,
            is_recording: self.transport.song.is_recording,
            mode: ProcessingMode::Realtime, // Note: Set to Offline if cloning for export loop
            project_time_seconds: (sample_position as f64) / sample_rate,
            project_time_samples: sample_position,
            beat_position,
            bar_position,
            loop_start_beat: None,
            loop_end_beat: None,
            midi_events: &[],
            param_changes: &[],
        };

        // Iterate through tracks, buses, and master in topological order
        for node in self.routing.cached_order.clone().iter() {
            match node {
                RoutingNode::Track(track_id) => {
                    // Read channel DSP values from audio-thread-owned mixer state
                    let channel_mut = self
                        .mixer_state
                        .track_channels
                        .entry(*track_id)
                        .or_default();
                    channel_mut
                        .volume
                        .set_smoothing_time(0.015, self.config.sample_rate as f64);
                    channel_mut
                        .pan
                        .set_smoothing_time(0.015, self.config.sample_rate as f64);

                    // Check mute/solo
                    if channel_mut.mute {
                        continue;
                    }
                    if is_any_solo && !channel_mut.solo {
                        continue;
                    }

                    // Ensure mix_buffer is sized correctly
                    if self.workspace.mix_buffer.len() != buf_len {
                        self.workspace.mix_buffer.resize(buf_len, 0.0);
                    }
                    self.workspace.mix_buffer.fill(0.0);

                    let mut has_signal = false;

                    // Generator Voice
                    if let Some(gen_voice) = self
                        .voices
                        .active_generators
                        .iter()
                        .find(|g| g.track_id == *track_id && g.active)
                    {
                        let gen_id = gen_voice.id;
                        let events = &gen_voice.midi_events;

                        if let Some(gen_instance) = self.plugin_state.get_generator_mut(gen_id) {
                            let sidechain_id = SidechainRoute::Generator(gen_id);
                            let aux = self
                                .workspace
                                .aux_buffers
                                .get(&sidechain_id)
                                .map(|b| b.as_slice());
                            // PROCESS AUDIO
                            // Build context for the generator — MIDI events are passed via ProcessContext
                            let mut gen_ctx = base_ctx.clone();
                            gen_ctx.midi_events = events;

                            let pt = PluginTarget::Generator(gen_id);
                            let changes = self
                                .modulation
                                .block_param_changes
                                .get(&pt)
                                .map(|v| v.as_slice())
                                .unwrap_or(&[]);
                            gen_ctx.param_changes = changes;

                            process_plugin_wrapper(
                                &mut *gen_instance.plugin,
                                &mut self.workspace.mix_buffer,
                                aux,
                                channels,
                                &gen_ctx,
                                &mut self.workspace.channel_buffers_in,
                                &mut self.workspace.channel_buffers_out,
                                &mut self.workspace.aux_channel_buffers,
                            );
                            has_signal = true;
                        }
                    }

                    // Audio Voice
                    if self.render_oneshots(
                        // &mut self.voices.active_oneshots,
                        // self.config.sample_rate,
                        *track_id, // &mut self.workspace.mix_buffer,
                        channels,
                    ) {
                        has_signal = true;
                    }

                    // track tail handling
                    let track_effects_tail = self
                        .plugin_state
                        .get_track_effects(track_id.to_u32() as usize)
                        .map(|effects| {
                            effects
                                .iter()
                                .map(|e| e.plugin.tail_samples())
                                .max()
                                .unwrap_or(0)
                        })
                        .unwrap_or(0);

                    if has_signal {
                        self.routing
                            .track_tails
                            .insert(*track_id, track_effects_tail);
                    } else {
                        let current_tail =
                            self.routing.track_tails.get(track_id).copied().unwrap_or(0);
                        if current_tail > 0 {
                            let new_tail = current_tail.saturating_sub(buf_len as u32);
                            self.routing.track_tails.insert(*track_id, new_tail);
                            if new_tail == 0 {
                                if let Some(effects) = self
                                    .plugin_state
                                    .get_track_effects_mut(track_id.to_u32() as usize)
                                {
                                    effects.iter_mut().for_each(|e| e.plugin.reset());
                                }
                                continue;
                            }
                            // has_signal = true;
                        } else {
                            continue;
                        }
                    }

                    // Apply track mixer channel (volume/pan/phase) and effects
                    // Effects receive an empty MIDI slice — track routing is audio-only at this stage
                    Self::apply_mixer_channel_with_effects(
                        &mut self
                            .mixer_state
                            .track_channels
                            .entry(*track_id)
                            .or_default(),
                        &mut self.plugin_state.track_effects,
                        *track_id,
                        &mut self.workspace.mix_buffer,
                        channels,
                        &base_ctx,
                        &self.workspace.aux_buffers,
                        &mut self.workspace.channel_buffers_in,
                        &mut self.workspace.channel_buffers_out,
                        &mut self.workspace.aux_channel_buffers,
                        &self.modulation.block_param_changes,
                    );

                    if let Some(delay_line) = self.routing.track_delay_lines.get_mut(track_id) {
                        delay_line.process_block(&mut self.workspace.mix_buffer, channels);
                    }

                    if let Some(channel) = self.mixer_state.track_channels.get_mut(track_id) {
                        channel.observe_magnitude(&self.workspace.mix_buffer);
                    }

                    // Route the track signal to destinations based on routing matrix
                    let mut track_routes = routing
                        .iter()
                        .filter(|c| c.source == RoutingNode::Track(*track_id))
                        .peekable();

                    if track_routes.peek().is_none() {
                        self.routing
                            .node_has_signal
                            .insert(RoutingNode::Master, true);
                        apply_simd_mix(output, &self.workspace.mix_buffer);
                    } else {
                        // Route to each destination with appropriate send level
                        for conn in track_routes {
                            self.routing.node_has_signal.insert(conn.destination, true);
                            match conn.destination {
                                RoutingNode::Master => {
                                    apply_simd_mix_gain(
                                        output,
                                        &self.workspace.mix_buffer,
                                        conn.send_level,
                                    );
                                }
                                RoutingNode::Bus(bus_id) => {
                                    if let Some(bus_buf) =
                                        self.workspace.bus_buffers.get_mut(&bus_id)
                                    {
                                        apply_simd_mix_gain(
                                            bus_buf,
                                            &self.workspace.mix_buffer,
                                            conn.send_level,
                                        );
                                    }
                                }
                                RoutingNode::Track(_) => {
                                    // Invalid: can't route to a track
                                }
                                RoutingNode::PluginSidechain(sidechain_route_id) => {
                                    let aux_buf = self
                                        .workspace
                                        .aux_buffers
                                        .entry(sidechain_route_id)
                                        .or_insert_with(|| vec![0.0; buf_len]);

                                    // Mix the current track's signal into the aux buffer
                                    apply_simd_mix_gain(
                                        aux_buf,
                                        &self.workspace.mix_buffer,
                                        conn.send_level,
                                    );
                                }
                            }
                        }
                    }
                }
                RoutingNode::Bus(bus_id) => {
                    let bus_buf = match self.workspace.bus_buffers.get(bus_id) {
                        Some(buf) => buf,
                        None => {
                            continue;
                        }
                    };

                    // Resize temp buffer if needed and copy
                    if self.workspace.bus_temp_buffer.len() != buf_len {
                        self.workspace.bus_temp_buffer.resize(buf_len, 0.0);
                    }
                    self.workspace.bus_temp_buffer.copy_from_slice(bus_buf);

                    // Get bus channel settings from audio-thread-owned mixer state
                    let bus_settings_channel =
                        self.mixer_state.bus_channels.entry(*bus_id).or_default();
                    bus_settings_channel
                        .volume
                        .set_smoothing_time(0.015, self.config.sample_rate as f64);
                    bus_settings_channel
                        .pan
                        .set_smoothing_time(0.015, self.config.sample_rate as f64);

                    // Skip if muted
                    if bus_settings_channel.mute {
                        continue;
                    }

                    // ================= Bus Tail Handling ===================
                    let mut bus_has_signal = self
                        .routing
                        .node_has_signal
                        .get(&RoutingNode::Bus(*bus_id))
                        .copied()
                        .unwrap_or(false);
                    let bus_effects_tail = self
                        .plugin_state
                        .get_bus_effects(bus_id.to_u32() as usize)
                        .map(|effects| {
                            effects
                                .iter()
                                .map(|e| e.plugin.tail_samples())
                                .max()
                                .unwrap_or(0)
                        })
                        .unwrap_or(0);
                    if bus_has_signal {
                        self.routing.bus_tails.insert(*bus_id, bus_effects_tail);
                    } else {
                        let current_tail = self.routing.bus_tails.get(bus_id).copied().unwrap_or(0);
                        if current_tail > 0 {
                            let new_tail = current_tail.saturating_sub(buf_len as u32);
                            self.routing.bus_tails.insert(*bus_id, new_tail);
                            if new_tail == 0 {
                                if let Some(effects) = self
                                    .plugin_state
                                    .get_bus_effects_mut(bus_id.to_u32() as usize)
                                {
                                    effects.iter_mut().for_each(|e| e.plugin.reset());
                                }
                                continue;
                            }
                            // Tail is ringing, keep bus alive
                            bus_has_signal = true;
                        } else {
                            // Since it has no input signal, no tail -> skip processing
                            continue;
                        }
                    }

                    // Copy to mix_buffer for processing
                    if self.workspace.mix_buffer.len() != buf_len {
                        self.workspace.mix_buffer.resize(buf_len, 0.0);
                    }
                    self.workspace
                        .mix_buffer
                        .copy_from_slice(&self.workspace.bus_temp_buffer);

                    // Apply bus effects
                    if let Some(effects) = self
                        .plugin_state
                        .get_bus_effects_mut(bus_id.to_u32() as usize)
                    {
                        for effect in effects.iter_mut() {
                            let sidechain_id = SidechainRoute::BusEffect(*bus_id, effect.id);
                            let aux = self
                                .workspace
                                .aux_buffers
                                .get(&sidechain_id)
                                .map(|b| b.as_slice());

                            let pt = PluginTarget::BusEffect(*bus_id, effect.id);
                            let mut ctx = base_ctx.clone();
                            ctx.param_changes = self
                                .modulation
                                .block_param_changes
                                .get(&pt)
                                .map(|v| v.as_slice())
                                .unwrap_or(&[]);

                            process_plugin_wrapper(
                                &mut *effect.plugin,
                                &mut self.workspace.mix_buffer,
                                aux,
                                channels,
                                &ctx,
                                &mut self.workspace.channel_buffers_in,
                                &mut self.workspace.channel_buffers_out,
                                &mut self.workspace.aux_channel_buffers,
                            );
                        }
                    }

                    // Apply PDC on Bus
                    if let Some(delay_line) = self.routing.bus_delay_lines.get_mut(bus_id) {
                        delay_line.process_block(&mut self.workspace.mix_buffer, channels);
                    }

                    apply_volume_and_pan_simd(
                        &mut self.workspace.mix_buffer,
                        channels,
                        &mut bus_settings_channel.volume,
                        &mut bus_settings_channel.pan,
                    );
                    bus_settings_channel.observe_magnitude(&self.workspace.mix_buffer);

                    // Route bus output to destinations
                    let bus_routes = routing
                        .iter()
                        .filter(|c| c.source == RoutingNode::Bus(*bus_id));

                    for conn in bus_routes {
                        self.routing.node_has_signal.insert(conn.destination, true);
                        match conn.destination {
                            RoutingNode::Master => {
                                apply_simd_mix_gain(
                                    output,
                                    &self.workspace.mix_buffer,
                                    conn.send_level,
                                );
                            }
                            RoutingNode::Bus(dest_bus_id) => {
                                if let Some(dest_buf) =
                                    self.workspace.bus_buffers.get_mut(&dest_bus_id)
                                {
                                    apply_simd_mix_gain(
                                        dest_buf,
                                        &self.workspace.mix_buffer,
                                        conn.send_level,
                                    );
                                }
                            }
                            RoutingNode::Track(_) => {}
                            RoutingNode::PluginSidechain(sidechain_route_id) => {
                                let aux_buf = self
                                    .workspace
                                    .aux_buffers
                                    .entry(sidechain_route_id)
                                    .or_insert_with(|| vec![0.0; buf_len]);

                                // Mix the current track's signal into the aux buffer
                                apply_simd_mix_gain(
                                    aux_buf,
                                    &self.workspace.mix_buffer,
                                    conn.send_level,
                                );
                            }
                        }
                    }
                }
                RoutingNode::Master => {
                    // TAIL HANDLING
                    let master_has_signal = self
                        .routing
                        .node_has_signal
                        .get(&RoutingNode::Master)
                        .copied()
                        .unwrap_or(false);
                    let master_effects_tail = self
                        .plugin_state
                        .master_effects
                        .iter()
                        .map(|e| e.plugin.tail_samples())
                        .max()
                        .unwrap_or(0);

                    if master_has_signal {
                        self.routing.master_tail = master_effects_tail;
                    } else {
                        if self.routing.master_tail > 0 {
                            self.routing.master_tail =
                                self.routing.master_tail.saturating_sub(buf_len as u32);
                            // If the tail becomes 0, then master has finally gone silent!
                            if self.routing.master_tail == 0 {
                                self.plugin_state
                                    .master_effects
                                    .iter_mut()
                                    .for_each(|e| e.plugin.reset());
                            }
                        }
                    }

                    if master_has_signal || self.routing.master_tail > 0 {
                        let master_bus_mut = &mut self.mixer_state.master;
                        master_bus_mut
                            .volume
                            .set_smoothing_time(0.015, self.config.sample_rate as f64);
                        master_bus_mut
                            .pan
                            .set_smoothing_time(0.015, self.config.sample_rate as f64);

                        Self::apply_master_bus_with_effects(
                            master_bus_mut,
                            &mut self.plugin_state.master_effects,
                            output,
                            channels,
                            &base_ctx,
                            &self.workspace.aux_buffers,
                            &mut self.workspace.channel_buffers_in,
                            &mut self.workspace.channel_buffers_out,
                            &mut self.workspace.aux_channel_buffers,
                            &self.modulation.block_param_changes,
                        );
                        master_bus_mut.observe_magnitude(output);
                    } else {
                        // output silent buffer
                        output.fill(0.0);
                    }
                }
                RoutingNode::PluginSidechain(sidechain_route_id) => {
                    // the send level evaluation has been done, we only handles the PDC

                    if let Some(aux_buf) = self.workspace.aux_buffers.get_mut(sidechain_route_id) {
                        if let Some(delay_line) = self
                            .routing
                            .sidechain_delay_lines
                            .get_mut(sidechain_route_id)
                        {
                            delay_line.process_block(aux_buf, channels);
                        }
                    }
                }
            }
        }
    }

    fn render_oneshots(&mut self, track_id: TrackId, channels: usize) -> bool {
        self.voices.render_oneshots(
            self.config.sample_rate,
            track_id,
            &mut self.workspace.mix_buffer,
            channels,
            self.transport.bpm,
        )
    }

    /// Apply mixer channel settings (volume, pan, phase) and effects from plugin_state
    fn apply_mixer_channel_with_effects<'a>(
        mixer_channel: &mut AudioMixerChannelValues,
        track_effects: &mut Vec<Vec<AudioEffectInstance>>,
        track_id: TrackId,
        buffer: &mut [f32],
        channels: usize,
        process_ctx: &ProcessContext<'a>,
        aux_buffers: &'a HashMap<SidechainRoute, Vec<f32>>,
        channel_buffers_in: &mut [Vec<f32>],
        channel_buffers_out: &mut [Vec<f32>],
        aux_channel_buffers: &mut [Vec<f32>],
        block_param_changes: &'a HashMap<PluginTarget, Vec<ParamChange>>,
    ) {
        // ==== SIMD Phase Inversion ====
        if mixer_channel.inverted_phase {
            apply_phase_inversion_simd(buffer);
        }

        // Effects chain from plugin_state
        if let Some(effects) = track_effects.get_mut(track_id.to_u32() as usize) {
            for effect in effects.iter_mut() {
                let sidechain_id = SidechainRoute::TrackEffect(track_id, effect.id);
                let aux = aux_buffers.get(&sidechain_id).map(|b| b.as_slice());

                let pt = PluginTarget::TrackEffect(track_id, effect.id);
                let mut ctx = process_ctx.clone();
                ctx.param_changes = block_param_changes
                    .get(&pt)
                    .map(|v| v.as_slice())
                    .unwrap_or(&[]);

                process_plugin_wrapper(
                    &mut *effect.plugin,
                    buffer,
                    aux,
                    channels,
                    &ctx,
                    channel_buffers_in,
                    channel_buffers_out,
                    aux_channel_buffers,
                );
            }
        }

        apply_volume_and_pan_simd(
            buffer,
            channels,
            &mut mixer_channel.volume,
            &mut mixer_channel.pan,
        );
    }

    /// Apply master bus settings (volume, pan, phase) and effects from plugin_state
    ///
    /// # Parameters
    ///
    /// * `master_bus` - The master bus settings
    /// * `master_effects` - The master bus effects chain
    /// * `buffer` - The buffer to apply the master bus settings to
    /// * `channels` - The number of channels in the buffer
    fn apply_master_bus_with_effects<'a>(
        master_bus: &mut AudioMixerChannelValues,
        master_effects: &mut [AudioEffectInstance],
        buffer: &mut [f32],
        channels: usize,
        process_ctx: &ProcessContext<'a>,
        aux_buffers: &'a HashMap<SidechainRoute, Vec<f32>>,
        channel_buffers_in: &mut [Vec<f32>],
        channel_buffers_out: &mut [Vec<f32>],
        aux_channel_buffers: &mut [Vec<f32>],
        block_param_changes: &'a HashMap<PluginTarget, Vec<ParamChange>>,
    ) {
        // ==== SIMD Phase Inversion ====
        if master_bus.inverted_phase {
            apply_phase_inversion_simd(buffer);
        }

        // Master effects chain
        for effect in master_effects.iter_mut() {
            let sidechain_id = SidechainRoute::MasterEffect(effect.id);
            let aux = aux_buffers.get(&sidechain_id).map(|b| b.as_slice());

            let pt = PluginTarget::MasterEffect(effect.id);
            let mut ctx = process_ctx.clone();
            ctx.param_changes = block_param_changes
                .get(&pt)
                .map(|v| v.as_slice())
                .unwrap_or(&[]);

            process_plugin_wrapper(
                &mut *effect.plugin,
                buffer,
                aux,
                channels,
                &ctx,
                channel_buffers_in,
                channel_buffers_out,
                aux_channel_buffers,
            );
        }

        // ==== SIMD Apply Gain and Pan ====
        apply_volume_and_pan_simd(
            buffer,
            channels,
            &mut master_bus.volume,
            &mut master_bus.pan,
        );
    }

    fn resolve_sequencer_events(&mut self, buffer_size: usize) {
        let start_time = self.transport.song.playhead_samples;
        let end_time = start_time + (buffer_size as u32);

        // Use the tracks from the current audio graph state
        let tracks = self.current_state.graph.tracks.clone();

        for track in tracks.iter() {
            self.process_track(track, start_time, end_time);
        }
    }

    fn process_track(&mut self, track: &AudioTrack, start_time: u32, end_time: u32) {
        let track_id = track.id;

        let mut gen_voice_idx = None;
        if let Some(gen_instance) = &track.generator {
            gen_voice_idx = Self::ensure_generator_voice(
                &mut self.voices.active_generators,
                &self.plugin_state,
                track_id,
                gen_instance,
            );
        }

        let samples_per_beat =
            ((60.0 / self.transport.bpm) * (self.config.sample_rate as f32)) as f64;
        let samples_per_tick = samples_per_beat / PPQ;

        for clip_id in track.clips() {
            let Some(clip_data) = self.current_state.graph.clips.get(clip_id).cloned() else {
                continue;
            };
            let (clip_start, clip_length, clip_offset) = match &clip_data.time {
                ClipTimeUnit::Samples {
                    start_time,
                    loop_length,
                    offset_start,
                } => (
                    *start_time as u32,
                    *loop_length as u32,
                    *offset_start as u32,
                ),
                ClipTimeUnit::Ticks {
                    start_time,
                    loop_length,
                    offset_start,
                } => {
                    let st = ((*start_time as f64) * samples_per_tick) as u32;
                    let ll = ((*loop_length as f64) * samples_per_tick) as u32;
                    let os = ((*offset_start as f64) * samples_per_tick) as u32;
                    (st, ll, os)
                }
            };

            if clip_start > end_time {
                break;
            }
            let clip_end = clip_start + clip_length;
            if clip_end < start_time {
                continue;
            }

            let clip = Clip {
                name: clip_data.name.clone(),
                id: clip_data.id,
                source: clip_data.source.clone(),
                time: ClipTimeUnit::Samples {
                    start_time: clip_start as u64,
                    loop_length: clip_length as u64,
                    offset_start: clip_offset as u64,
                },
            };

            match &clip.source {
                Some(DawSource::Audio(source_id)) => {
                    let waveform_opt = self
                        .current_state
                        .graph
                        .asset_library
                        .source_map
                        .get(*source_id)
                        .cloned();
                    if let Some(waveform) = waveform_opt {
                        self.prepare_audio_voice(track.id, &clip, &waveform, start_time, end_time);
                    }
                }
                Some(DawSource::Midi(id)) => {
                    let fresh_pattern = self.current_state.graph.patterns.get(id);

                    if let Some(pattern) = fresh_pattern {
                        if let Some(idx) = gen_voice_idx {
                            let gen_voice = &mut self.voices.active_generators[idx];
                            Self::schedule_midi_events(
                                &mut gen_voice.midi_events,
                                self.config.sample_rate,
                                self.transport.bpm,
                                &clip,
                                pattern,
                                start_time,
                                end_time,
                            );
                        }
                    }
                }
                _ => {}
            }
        }

        // Just sort the events. Playing_keys is safely handled downstream now!
        if let Some(idx) = gen_voice_idx {
            let voice = &mut self.voices.active_generators[idx];
            voice.midi_events.sort_by_key(|e| e.sample_offset);
        }
    }

    /// Ensure that the generator voice is active
    fn ensure_generator_voice(
        active_generators: &mut Vec<GeneratorVoice>,
        plugin_state: &AudioPluginState,
        track_id: TrackId,
        gen_instance: &GeneratorInstance,
    ) -> Option<usize> {
        VoiceState::ensure_generator_voice(active_generators, plugin_state, track_id, gen_instance)
    }

    /// Render preview voices to the output buffer
    fn render_previews_to_buffer(&mut self, output: &mut [f32], channels: usize) {
        self.voices
            .render_previews(output, channels, self.config.sample_rate);
    }

    /// Prepare audio voice from Audio Waveform that will be rendered
    fn prepare_audio_voice(
        &mut self,
        track_id: TrackId,
        clip: &Clip,
        waveform: &AudioWaveform,
        buffer_start: u32,
        buffer_end: u32,
    ) {
        self.voices.prepare_audio_voice(
            track_id,
            clip,
            waveform,
            buffer_start,
            buffer_end,
            self.config.sample_rate,
        );
    }

    fn schedule_midi_events(
        events: &mut SmallVec<[MidiEvent; 4]>,
        sample_rate: u32,
        tempo: f32,
        clip: &Clip,
        pattern: &Pattern,
        buffer_start: u32,
        buffer_end: u32,
    ) {
        VoiceState::schedule_midi_events(
            events,
            sample_rate,
            tempo,
            clip,
            pattern,
            buffer_start,
            buffer_end,
        );
    }

    // Helper to schedule notes without a Clip wrapper
    fn schedule_pattern_notes_raw(
        events: &mut SmallVec<[MidiEvent; 4]>,
        pattern_id: PatternId,
        notes: &[crate::core::project::Note],
        sample_rate: u32,
        tempo: f32,
        buffer_start: u32,
        buffer_end: u32,
    ) {
        VoiceState::schedule_pattern_notes(
            events,
            pattern_id,
            notes,
            sample_rate,
            tempo,
            buffer_start,
            buffer_end,
        );
    }

    pub(super) fn recalculate_latencies(&mut self) {
        let max_system_latency = self.routing.recalculate_latencies(
            &self.current_state.graph,
            &self.plugin_state,
            self.workspace.bus_buffers.keys().copied(),
            self.config.num_channels as usize,
        );

        log::info!(
            "[PDC] Recalculated Latencies. Max System Latency: {} samples",
            max_system_latency
        );
    }

    pub(super) fn evaluate_pre_block_modulations(&mut self, buffer_size: usize) {
        let mut peak_updates = Vec::new();
        for (id, (source, _)) in self.modulation.active_sources.iter() {
            if let LiveModulationSource::PeakController { source: p_tgt } = source {
                if let Some(karbeat_plugin_api::prelude::ZeroCopyBuffer::Float32(control_buf)) =
                    self.get_plugin(p_tgt)
                        .and_then(|p| p.get_zero_copy_buffer("control"))
                {
                    peak_updates.push((*id, control_buf.first().copied().unwrap_or(0.0)));
                }
            }
        }
        for (id, val) in peak_updates {
            self.modulation.set_source_output(id, val);
        }

        let parameter_changes = self.modulation.evaluate(
            buffer_size,
            self.transport.bpm,
            self.config.sample_rate,
            self.transport.song.playhead_samples,
            &self.current_state.graph.automation_lanes,
        );
        for (target, (automation_override, modulation)) in parameter_changes {
            let base = automation_override.unwrap_or_else(|| self.modulation.base_value(&target));
            let final_value = (base + modulation).clamp(0.0, 1.0);
            self.apply_parameter_change(&target, final_value);
        }
    }

    fn apply_parameter_change(&mut self, target: &AutomationTarget, final_value: f32) {
        match target {
            AutomationTarget::Generator {
                generator_id,
                param_id,
            } => {
                if let Some(inst) = self.plugin_state.get_generator_mut(*generator_id) {
                    inst.plugin.apply_automation(*param_id, final_value);
                }
            }

            AutomationTarget::Track {
                track_id,
                track_target,
            } => match track_target {
                TrackAutomationTarget::MixerChannel(mix_target) => {
                    apply_mix_param!(
                        mix_target,
                        final_value,
                        self.mixer_state.track_channels.get_mut(track_id),
                        self.plugin_state
                            .get_track_effects_mut(track_id.to_u32() as usize)
                    );
                }
            },

            AutomationTarget::Bus { bus_id, mix_target } => {
                apply_mix_param!(
                    mix_target,
                    final_value,
                    self.mixer_state.bus_channels.get_mut(bus_id),
                    self.plugin_state
                        .get_bus_effects_mut(bus_id.to_u32() as usize)
                );
            }

            AutomationTarget::Master(master_target) => match master_target {
                MasterAutomationTarget::MixerChannel(mix_target) => {
                    apply_mix_param!(
                        mix_target,
                        final_value,
                        Some(&mut self.mixer_state.master),
                        Some(&mut self.plugin_state.master_effects)
                    );
                }
                MasterAutomationTarget::TempoBpm => {
                    self.transport.bpm = final_value;
                }
            },
        }
    }

    pub(super) fn handle_parameter_edit(&mut self, target: &AutomationTarget, is_begin: bool) {
        match target {
            AutomationTarget::Generator {
                generator_id,
                param_id,
            } => {
                if let Some(inst) = self.plugin_state.get_generator_mut(*generator_id) {
                    if is_begin {
                        inst.plugin.begin_parameter_edit(*param_id);
                    } else {
                        inst.plugin.end_parameter_edit(*param_id);
                    }
                }
            }
            AutomationTarget::Track {
                track_id,
                track_target,
            } => match track_target {
                TrackAutomationTarget::MixerChannel(mix_target) => match mix_target {
                    MixerChannelParamTarget::Plugin { effect_id, target } => match target {
                        EffectAutomationTarget::Mix => {}
                        EffectAutomationTarget::PluginParam { param_id } => {
                            if let Some(effects) = self
                                .plugin_state
                                .get_track_effects_mut(track_id.to_u32() as usize)
                            {
                                if let Some(e) = effects.iter_mut().find(|e| e.id == *effect_id) {
                                    if is_begin {
                                        e.plugin.begin_parameter_edit(*param_id);
                                    } else {
                                        e.plugin.end_parameter_edit(*param_id);
                                    }
                                }
                            }
                        }
                    },
                    _ => {}
                },
            },
            AutomationTarget::Bus { bus_id, mix_target } => match mix_target {
                MixerChannelParamTarget::Plugin { effect_id, target } => match target {
                    EffectAutomationTarget::Mix => {}
                    EffectAutomationTarget::PluginParam { param_id } => {
                        if let Some(effects) = self
                            .plugin_state
                            .get_bus_effects_mut(bus_id.to_u32() as usize)
                        {
                            if let Some(e) = effects.iter_mut().find(|e| e.id == *effect_id) {
                                if is_begin {
                                    e.plugin.begin_parameter_edit(*param_id);
                                } else {
                                    e.plugin.end_parameter_edit(*param_id);
                                }
                            }
                        }
                    }
                },
                _ => {}
            },
            AutomationTarget::Master(master_target) => match master_target {
                MasterAutomationTarget::MixerChannel(mix_target) => match mix_target {
                    MixerChannelParamTarget::Plugin { effect_id, target } => match target {
                        EffectAutomationTarget::Mix => {}
                        EffectAutomationTarget::PluginParam { param_id } => {
                            if let Some(e) = self
                                .plugin_state
                                .master_effects
                                .iter_mut()
                                .find(|e| e.id == *effect_id)
                            {
                                if is_begin {
                                    e.plugin.begin_parameter_edit(*param_id);
                                } else {
                                    e.plugin.end_parameter_edit(*param_id);
                                }
                            }
                        }
                    },
                    _ => {}
                },
                MasterAutomationTarget::TempoBpm => {}
            },
        }
    }

    /// Returns the exact number of samples needed to fully clear all plugin delays and reverb tails.
    /// Call this when the transport stops to know when to put the engine to sleep.
    pub fn get_project_tail_length(&self) -> u32 {
        let max_tail = itertools::chain!(
            self.plugin_state
                .generators
                .iter()
                .map(|(_, generator)| generator.plugin.tail_samples()),
            self.plugin_state
                .track_effects
                .iter()
                .flatten()
                .map(|effect| effect.plugin.tail_samples()),
            self.plugin_state
                .bus_effects
                .iter()
                .flatten()
                .map(|effect| effect.plugin.tail_samples()),
            self.plugin_state
                .master_effects
                .iter()
                .map(|effect| effect.plugin.tail_samples()),
        )
        .max()
        .unwrap_or(0);

        // Cap the tail at 20 seconds so infinite reverbs don't render forever
        let max_allowed_tail = 20 * self.config.sample_rate;
        let max_tail = max_tail.min(max_allowed_tail);

        // Include PDC latency since it naturally delays the final output
        let max_system_latency = self
            .routing
            .compensation_delays
            .values()
            .copied()
            .max()
            .unwrap_or(0);

        max_tail + max_system_latency
    }

    /// Returns the absolute total length of the song in samples, including reverb tails.
    /// Your offline export loop should use THIS value as its target length!
    pub fn get_export_length(&self) -> u32 {
        self.current_state.graph.max_sample_index + self.get_project_tail_length()
    }

    /// Dynamically calculates the absolute end of the project in samples (Clips ONLY).
    /// Safely handles the conversion of MIDI Ticks -> Samples based on CURRENT engine BPM & Sample Rate.
    pub(super) fn reprepare_plugins_and_clear_delays(&mut self, sr: u32, buf_size: usize) {
        let channels = self.config.num_channels as usize;
        let bf_size = buf_size.max(512);

        for plugin in itertools::chain!(
            self.plugin_state
                .generators
                .iter_mut()
                .map(|(_, generator)| &mut generator.plugin),
            self.plugin_state
                .track_effects
                .iter_mut()
                .flatten()
                .map(|effect| &mut effect.plugin),
            self.plugin_state
                .bus_effects
                .iter_mut()
                .flatten()
                .map(|effect| &mut effect.plugin),
            self.plugin_state
                .master_effects
                .iter_mut()
                .map(|effect| &mut effect.plugin),
        ) {
            plugin.prepare(sr as f32, bf_size);
            let bus = BusConfig {
                name: "Main".into(),
                channel_count: channels,
                is_optional: false,
            };
            plugin.set_io_layout(std::slice::from_ref(&bus.clone()), &[bus]);
        }

        // Clear delay lines to avoid playing back garbage/pitch-shifted audio
        self.routing.track_delay_lines.clear();
        self.routing.bus_delay_lines.clear();
        self.routing.sidechain_delay_lines.clear();
    }

    /// Recalculate max samples index of the timeline after
    /// changes in the tracks
    pub(super) fn recalculate_max_sample_index(&mut self) {
        let bpm = self.transport.bpm as f64;
        let sample_rate = self.config.sample_rate as f64;
        let mut max_clip_end: u32 = 0;

        // Find the absolute furthest boundary of any clip on the timeline
        for track in self.current_state.graph.tracks.iter() {
            for clip_id in track.clips.iter() {
                let Some(clip) = self.current_state.graph.clips.get(clip_id) else {
                    continue;
                };
                let end_sample = match &clip.time {
                    crate::core::project::clip::ClipTimeUnit::Samples {
                        start_time,
                        loop_length,
                        ..
                    } => (*start_time + *loop_length) as u32,
                    crate::core::project::clip::ClipTimeUnit::Ticks {
                        start_time,
                        loop_length,
                        ..
                    } => {
                        let end_tick = *start_time + *loop_length;
                        // Accurately project MIDI ticks into exact sample lengths
                        ((end_tick as f64) * (60.0 / bpm) * (sample_rate / PPQ)) as u32
                    }
                };
                if end_sample > max_clip_end {
                    max_clip_end = end_sample;
                }
            }
        }

        // Set max_sample_index to ONLY the end of the clips (No Tails)
        // This ensures looping and song-stop behaves perfectly in the UI.
        self.current_state.graph.max_sample_index = max_clip_end;

        log::debug!(
            "[AudioEngine] Max Sample Index recalculated (Clips only): {}",
            self.current_state.graph.max_sample_index
        );
    }

    /// Emits snapshots of all active mixer channels via the triple-buffer.
    fn emit_all_mixer_snapshots(&mut self) {
        self.telemetry.emit_mixer_snapshot(&self.mixer_state);
    }

    /// Fetches parameters only for plugins the UI is actively watching.
    /// Publishes each plugin's snapshot into its own per-plugin triple-buffer producer.
    fn emit_plugin_telemetry(&mut self) {
        if self.telemetry.active_telemetry_subscriptions.is_empty() {
            return;
        }

        // Collect the (target, snapshot) pairs first to satisfy the borrow checker.
        let targets_and_names: Vec<(PluginTarget, Vec<String>)> = self
            .telemetry
            .active_telemetry_subscriptions
            .iter()
            .map(|(t, names)| (t.clone(), names.iter().cloned().collect()))
            .collect();

        for (target, buffer_names) in targets_and_names {
            if let Some(plugin) = self.get_plugin(&target) {
                let mut plugin_snap = PluginTelemetrySnapshot::default();

                // Fetch all parameters
                let specs = plugin.get_parameter_specs();
                plugin_snap.parameters = specs
                    .iter()
                    .map(|s| (s.id, plugin.get_parameter(s.id)))
                    .collect();

                // Fetch requested zero-copy buffers (e.g., "telemetry" or "magnitude")
                for name in &buffer_names {
                    if let Some(buf) = plugin.get_zero_copy_buffer(name) {
                        plugin_snap.buffers.insert(name.clone(), buf);
                    }
                }

                // Write directly into the per-plugin triple-buffer producer.
                if let Some(producer) = self.telemetry.param_telemetry_producers.get_mut(&target) {
                    *producer.input_buffer_mut() = plugin_snap;
                    producer.publish();
                }
            }
        }
    }
}
