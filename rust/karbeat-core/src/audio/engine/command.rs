use super::{
    engine::AudioEngine, helper::*, telemetry::PluginTelemetrySnapshot, transport::PlaybackMode,
    types::*, voices::PreviewVoice,
};
use crate::{
    audio::{
        event::PluginTarget,
        render_state::{AudioEffectInstance, AudioGeneratorInstance},
    },
    commands::{
        AudioCommand, AudioFeedback, EffectParameterSnapshot, EffectTarget,
        GeneratorParameterSnapshot, TelemetryRegistration,
    },
    core::project::*,
    shared::id::*,
};
use hashbrown::{HashMap, HashSet};

impl AudioEngine {
    /// Process incoming commands from command queue buffer
    pub fn process_command(&mut self, cmd: AudioCommand) {
        match cmd {
            AudioCommand::PlayOneShot(waveform) => {
                self.voices.preview_voices.clear();
                self.voices
                    .preview_voices
                    .push(PreviewVoice::new(waveform, 1.0));
            }
            AudioCommand::PlayPreview {
                waveform,
                max_frames,
            } => {
                self.voices.preview_voices.clear();
                self.voices
                    .preview_voices
                    .push(PreviewVoice::with_frame_limit(waveform, 1.0, max_frames));
            }
            AudioCommand::StopAllPreviews => self.voices.preview_voices.clear(),
            AudioCommand::SetPlaying(val) => {
                let was_playing = match self.transport.mode {
                    PlaybackMode::Song => self.transport.song.is_playing,
                    PlaybackMode::Pattern { .. } => self.transport.pattern.is_playing,
                };

                if was_playing && !val {
                    // Stopping: silence all active generators
                    self.stop_all_active_generators();
                }

                match self.transport.mode {
                    PlaybackMode::Song => {
                        self.transport.song.is_playing = val;
                    }
                    PlaybackMode::Pattern { .. } => {
                        self.transport.pattern.is_playing = val;
                    }
                }

                self.emit_current_playback_position();
            }
            AudioCommand::SetLooping(val) => {
                self.transport.song.is_looping = val;
                self.emit_current_playback_position();
            }
            AudioCommand::StopAndReset => {
                self.stop_playback();
            }
            AudioCommand::SetPlayhead(samples) => {
                log::debug!(
                    "[AudioEngine Seek] Received SetPlayhead(samples: {})",
                    samples
                );
                self.stop_all_active_generators();
                self.transport.song.playhead_samples = samples;
                self.recalculate_beat_bar();
                self.transport.song.last_emitted_samples = self.transport.song.playhead_samples;
                self.evaluate_pre_block_modulations(0);
                self.emit_current_playback_position();
            }
            AudioCommand::PlayPreviewNote {
                note_key,
                generator_id,
                velocity,
                is_note_on,
            } => {
                // this should push preview voice in the shape of note pressed connected to generator.
                // e.g Note placing on piano roll, hold press from a keyboard,
                // or a press at the piano tile on the left of piano roll screen
                // it also requires the logic to handle input based on the ADSR of the voice generator
                self.trigger_live_note(generator_id, note_key, velocity, is_note_on);
            }
            AudioCommand::SendMidiEvent {
                generator_id,
                event,
            } => {
                if !self
                    .voices
                    .queue_generator_event(&self.plugin_state, generator_id, event)
                {
                    log::warn!("MIDI event target {:?} was not found", generator_id);
                }
            }
            AudioCommand::SetBPM(bpm) => {
                self.transport.bpm = bpm;
                self.emit_current_playback_position();
                self.recalculate_max_sample_index();
            }
            AudioCommand::SetPlaybackMode(playback_mode) => {
                // Silence everything to prevent hanging notes from the previous mode
                self.stop_all_active_generators();

                // Reset the specific playhead for the new mode
                match (self.transport.mode, playback_mode) {
                    (PlaybackMode::Song, PlaybackMode::Pattern { .. }) => {
                        self.transport.pattern.playhead_samples = 0;
                        self.transport.pattern.last_emitted_samples = 0;
                        self.recalculate_pattern_beat_bar();
                        self.transport.pattern.is_playing = true;
                    }
                    (PlaybackMode::Pattern { .. }, PlaybackMode::Song) => {
                        self.transport.pattern.playhead_samples = 0;
                        self.transport.pattern.last_emitted_samples = 0;
                        self.recalculate_pattern_beat_bar();
                        self.transport.pattern.is_playing = false;
                    }
                    _ => {}
                }

                self.transport.mode = playback_mode;

                // Snap UI to the beginning immediately
                self.emit_current_playback_position();
            }
            AudioCommand::AddGenerator {
                generator_id,
                track_id,
                mut plugin,
            } => {
                // Prepare the plugin with current sample rate and buffer size
                let buf_size = self.current_state.graph.buffer_size.max(512);
                plugin.prepare(self.config.sample_rate as f32, buf_size);

                let bus_cfg = BusConfig {
                    name: "Main".into(),
                    channel_count: self.config.num_channels as usize,
                    is_optional: false,
                };
                plugin.set_io_layout(&[bus_cfg.clone()], &[bus_cfg]);

                self.plugin_state.insert_generator(AudioGeneratorInstance {
                    id: generator_id,
                    track_id,
                    plugin,
                });

                // Register a new triple-buffer pair for this generator's telemetry.
                let target = PluginTarget::Generator(generator_id);
                let (input, output) =
                    triple_buffer::triple_buffer(&PluginTelemetrySnapshot::default());
                self.telemetry
                    .param_telemetry_producers
                    .insert(target.clone(), input);
                let _ = self
                    .io
                    .telemetry_reg_sender
                    .try_send(TelemetryRegistration::Registered {
                        target,
                        consumer: Box::new(output),
                    });

                log::info!(
                    "[AudioEngine] Added generator {:?} for track {:?}",
                    generator_id,
                    track_id
                );
            }
            AudioCommand::RemoveGenerator { generator_id } => {
                self.plugin_state.remove_generator(generator_id);
                // Also remove any active voice referencing it
                self.voices
                    .active_generators
                    .retain(|v| v.id != generator_id);

                // Remove the telemetry producer and notify DawContext.
                let target = PluginTarget::Generator(generator_id);
                self.telemetry.param_telemetry_producers.remove(&target);
                self.telemetry
                    .active_telemetry_subscriptions
                    .remove(&target);
                let _ = self
                    .io
                    .telemetry_reg_sender
                    .try_send(TelemetryRegistration::Removed { target });

                log::info!("[AudioEngine] Removed generator {:?}", generator_id);
            }
            AudioCommand::SetParameter {
                target,
                param_id,
                value,
            } => {
                match target {
                    PluginTarget::Generator(generator_id) => {
                        if let Some(gen_instance) =
                            self.plugin_state.get_generator_mut(generator_id)
                        {
                            gen_instance.plugin.set_parameter(param_id, value);
                        }
                    }
                    PluginTarget::TrackEffect(track_id, effect_id) => {
                        if let Some(effects) =
                            self.get_effect_list_mut(&EffectTarget::Track(track_id))
                        {
                            if let Some(effect) = effects.iter_mut().find(|e| e.id == effect_id) {
                                effect.plugin.set_parameter(param_id, value);
                            }
                        }
                    }
                    PluginTarget::BusEffect(bus_id, effect_id) => {
                        if let Some(effects) = self.get_effect_list_mut(&EffectTarget::Bus(bus_id))
                        {
                            if let Some(effect) = effects.iter_mut().find(|e| e.id == effect_id) {
                                effect.plugin.set_parameter(param_id, value);
                            }
                        }
                    }
                    PluginTarget::MasterEffect(effect_id) => {
                        if let Some(effects) = self.get_effect_list_mut(&EffectTarget::Master) {
                            if let Some(effect) = effects.iter_mut().find(|e| e.id == effect_id) {
                                effect.plugin.set_parameter(param_id, value);
                            }
                        }
                    }
                }

                self.modulation
                    .block_param_changes
                    .entry(target.clone())
                    .or_default()
                    .push(ParamChange {
                        param_id: param_id,
                        normalized_value: value,
                        sample_offset: 0,
                    });

                let our_target = target.to_automation_target(param_id);

                self.modulation.suspended_targets.insert(our_target.clone());

                if let Some(link) = self
                    .modulation
                    .active_links
                    .iter_mut()
                    .find(|l| l.target == our_target)
                {
                    link.base_value = value;
                }
            }
            AudioCommand::UpdateGeneratorTrack {
                generator_id,
                track_id,
            } => {
                if let Some(gen_instance) = self.plugin_state.get_generator_mut(generator_id) {
                    gen_instance.track_id = track_id;
                }
                // Update active voice track association
                for voice in &mut self.voices.active_generators {
                    if voice.id == generator_id {
                        voice.track_id = track_id;
                    }
                }
            }
            AudioCommand::AddEffect {
                target,
                effect_id,
                mut effect,
            } => {
                let buf_size = self.current_state.graph.buffer_size.max(512);
                effect.prepare(self.config.sample_rate as f32, buf_size);
                let bus_cfg = BusConfig {
                    name: "Main".into(),
                    channel_count: self.config.num_channels as usize,
                    is_optional: false,
                };
                effect.set_io_layout(&[bus_cfg.clone()], &[bus_cfg]);

                let instance = AudioEffectInstance {
                    id: effect_id,
                    plugin: effect,
                };

                // Derive the PluginTarget for this effect.
                let plugin_target = match &target {
                    EffectTarget::Track(track_id) => {
                        PluginTarget::TrackEffect(*track_id, effect_id)
                    }
                    EffectTarget::Bus(bus_id) => PluginTarget::BusEffect(*bus_id, effect_id),
                    EffectTarget::Master => PluginTarget::MasterEffect(effect_id),
                };

                match target {
                    EffectTarget::Track(track_id) => {
                        self.plugin_state
                            .add_track_effect(track_id.to_u32() as usize, instance);
                        log::info!("[AudioEngine] Added effect to track {:?}", track_id);
                    }
                    EffectTarget::Bus(bus_id) => {
                        self.plugin_state
                            .add_bus_effect(bus_id.to_u32() as usize, instance);
                        log::info!(
                            "[AudioEngine] Added effect {:?} to bus {:?}",
                            effect_id,
                            bus_id
                        );
                    }
                    EffectTarget::Master => {
                        self.plugin_state.master_effects.push(instance);
                        log::info!("[AudioEngine] Added effect {:?} to master", effect_id);
                    }
                }

                // Register a new triple-buffer pair for this effect's telemetry.
                let (input, output) =
                    triple_buffer::triple_buffer(&PluginTelemetrySnapshot::default());
                self.telemetry
                    .param_telemetry_producers
                    .insert(plugin_target.clone(), input);
                let _ = self
                    .io
                    .telemetry_reg_sender
                    .try_send(TelemetryRegistration::Registered {
                        target: plugin_target,
                        consumer: Box::new(output),
                    });
            }
            AudioCommand::RemoveEffect { target, effect_id } => {
                if let Some(effects) = self.get_effect_list_mut(&target) {
                    if let Some(pos) = effects.iter().position(|e| e.id == effect_id) {
                        effects.remove(pos);
                    }
                }

                // Remove telemetry pair and notify DawContext.
                let plugin_target = match &target {
                    EffectTarget::Track(track_id) => {
                        PluginTarget::TrackEffect(*track_id, effect_id)
                    }
                    EffectTarget::Bus(bus_id) => PluginTarget::BusEffect(*bus_id, effect_id),
                    EffectTarget::Master => PluginTarget::MasterEffect(effect_id),
                };
                self.telemetry
                    .param_telemetry_producers
                    .remove(&plugin_target);
                self.telemetry
                    .active_telemetry_subscriptions
                    .remove(&plugin_target);
                let _ = self
                    .io
                    .telemetry_reg_sender
                    .try_send(TelemetryRegistration::Removed {
                        target: plugin_target,
                    });
            }
            AudioCommand::MoveEffect {
                target,
                effect_id,
                new_position,
            } => {
                if let Some(effects) = self.get_effect_list_mut(&target)
                    && let Some(old_position) =
                        effects.iter().position(|effect| effect.id == effect_id)
                {
                    let effect = effects.remove(old_position);
                    effects.insert(new_position.min(effects.len()), effect);
                }
            }

            AudioCommand::QueryGeneratorParameters { generator_id } => {
                // Get all parameter values from the generator and send back
                if let Some(gen_instance) = self.plugin_state.get_generator(generator_id) {
                    let specs = gen_instance.plugin.get_parameter_specs();
                    let parameters: Vec<(u32, f32)> = specs
                        .iter()
                        .map(|spec| (spec.id, gen_instance.plugin.get_parameter(spec.id)))
                        .collect();

                    let snapshot = GeneratorParameterSnapshot {
                        generator_id,
                        parameters,
                    };

                    let _ = self
                        .io
                        .feedback_producer
                        .push(AudioFeedback::GeneratorParameterSnapshot(snapshot));
                }
            }
            AudioCommand::SetMixerChannelParameter { target, param } => {
                // Audio thread is sole owner of mixer channel DSP values
                self.mixer_state.apply(&target, &param);

                let (our_target, norm_value) = resolve_target_mixer_param(&target, &param);

                if let Some(our_target) = our_target {
                    if let Some(link) = self
                        .modulation
                        .active_links
                        .iter_mut()
                        .find(|l| l.target == our_target)
                    {
                        link.base_value = norm_value;
                    }
                }

                log::debug!(
                    "[AudioEngine] SetMixerChannelParameter: {:?} — {:?}",
                    target,
                    param
                );
            }
            AudioCommand::QueryMixerChannel { target } => {
                let snapshot = self.mixer_state.snapshot(target);
                let _ = self
                    .io
                    .feedback_producer
                    .push(AudioFeedback::MixerChannelSnapshot(snapshot));
            }
            AudioCommand::AddBus { bus_id, name } => {
                // Initialize bus buffer and effects chain
                let id_index = bus_id.to_u32() as usize;
                self.plugin_state.add_bus(id_index);
                self.workspace.bus_buffers.insert(bus_id, Vec::new());

                // Initialize the missing bus mixer channel
                self.mixer_state.bus_channels.entry(bus_id).or_default();

                let track_ids = self.current_state.graph.tracks.iter().map(|t| t.id);
                let bus_ids = self.workspace.bus_buffers.keys().copied();
                self.routing.cached_order =
                    compute_routing_order(track_ids, bus_ids, &self.current_state.graph.routing);

                log::info!("[AudioEngine] Added bus {:?} ({})", bus_id, name);
            }
            AudioCommand::RemoveBus { bus_id } => {
                let id_index = bus_id.to_u32() as usize;
                self.plugin_state.remove_bus(id_index);
                self.workspace.bus_buffers.remove(&bus_id);
                self.mixer_state.bus_channels.remove(&bus_id);
                let track_ids = self.current_state.graph.tracks.iter().map(|t| t.id);
                let bus_ids = self.workspace.bus_buffers.keys().copied();
                self.routing.cached_order =
                    compute_routing_order(track_ids, bus_ids, &self.current_state.graph.routing);

                log::info!("[AudioEngine] Removed bus {:?}", bus_id);
            }
            AudioCommand::UpdateRouting { routing } => {
                // Routing is now directly owned by the audio thread — update and
                // recompute the cached order immediately.
                let track_ids = self.current_state.graph.tracks.iter().map(|t| t.id);
                let bus_ids = self.workspace.bus_buffers.keys().copied();
                self.routing.cached_order = compute_routing_order(track_ids, bus_ids, &routing);
                self.current_state.graph.routing = routing;
                log::info!(
                    "[AudioEngine] UpdateRouting: {} connections",
                    self.current_state.graph.routing.len()
                );
            }
            AudioCommand::QueryEffectParameters { target, effect_id } => {
                let effect_instance_opt = self
                    .get_effect_list(&target)
                    .and_then(|effects| effects.iter().find(|e| e.id == effect_id));

                if let Some(effect_instance) = effect_instance_opt {
                    let specs = effect_instance.plugin.get_parameter_specs();
                    let parameters: Vec<(u32, f32)> = specs
                        .iter()
                        .map(|spec| (spec.id, effect_instance.plugin.get_parameter(spec.id)))
                        .collect();

                    let snapshot = EffectParameterSnapshot {
                        target,
                        effect_id,
                        parameters,
                    };

                    let _ = self
                        .io
                        .feedback_producer
                        .push(AudioFeedback::EffectParameterSnapshot(snapshot));
                }
            }
            AudioCommand::HydratePlugin {
                track_effects,
                master_effects,
                bus_effects,
                generators,
                track_channels,
                bus_channels,
                master_channel,
            } => {
                let buf_size = self.current_state.graph.buffer_size.max(512);
                let sample_rate = self.config.sample_rate as f32;
                let channels = self.config.num_channels as usize;

                // Completely clear the previous project's plugin state, voices, and tails
                self.plugin_state.clear_generators();
                self.plugin_state.track_effects.clear();
                self.plugin_state.master_effects.clear();
                self.plugin_state.bus_effects.clear();
                self.voices.active_generators.clear();
                self.workspace.bus_buffers.clear();
                self.routing.track_tails.clear();
                self.routing.bus_tails.clear();
                self.routing.master_tail = 0;

                // Clear all previous telemetry state.
                self.telemetry.param_telemetry_producers.clear();
                self.telemetry.active_telemetry_subscriptions.clear();

                self.modulation
                    .replace_from_graph(&self.current_state.graph);

                // =========================================================
                // Seed audio-thread mixer channel state from project values
                // =========================================================
                self.mixer_state = AudioMixerState::default();

                for (track_id, seed) in &track_channels {
                    self.mixer_state.track_channels.insert(
                        *track_id,
                        AudioMixerChannelValues::new(
                            seed.volume,
                            seed.pan,
                            seed.mute,
                            seed.solo,
                            seed.inverted_phase,
                        ),
                    );
                }
                for (bus_id, seed) in &bus_channels {
                    self.mixer_state.bus_channels.insert(
                        *bus_id,
                        AudioMixerChannelValues::new(
                            seed.volume,
                            seed.pan,
                            seed.mute,
                            seed.solo,
                            seed.inverted_phase,
                        ),
                    );
                }
                self.mixer_state.master = AudioMixerChannelValues::new(
                    master_channel.volume,
                    master_channel.pan,
                    master_channel.mute,
                    master_channel.solo,
                    master_channel.inverted_phase,
                );

                // Accumulate all new consumers to send in one batch.
                let mut new_consumers: HashMap<
                    PluginTarget,
                    Box<triple_buffer::Output<PluginTelemetrySnapshot>>,
                > = HashMap::new();

                for (gen_id, mut plugin) in generators.into_iter() {
                    plugin.prepare(sample_rate, buf_size);
                    let bus = BusConfig {
                        name: "Main".into(),
                        channel_count: channels,
                        is_optional: false,
                    };
                    plugin.set_io_layout(std::slice::from_ref(&bus.clone()), &[bus]);

                    // Since PreparePlugin doesn't pass track_ids directly, we find the
                    // associated track from the newly synced current_state graph.
                    let track_id = self
                        .current_state
                        .graph
                        .tracks
                        .iter()
                        .find(|t| t.generator.as_ref().map_or(false, |g| g.id == gen_id))
                        .map(|t| t.id)
                        .unwrap_or_else(|| TrackId::from(0));

                    self.plugin_state.insert_generator(AudioGeneratorInstance {
                        id: gen_id,
                        track_id,
                        plugin,
                    });

                    let target = PluginTarget::Generator(gen_id);
                    let (input, output) =
                        triple_buffer::triple_buffer(&PluginTelemetrySnapshot::default());
                    self.telemetry
                        .param_telemetry_producers
                        .insert(target.clone(), input);
                    new_consumers.insert(target, Box::new(output));
                }

                // Batch load Track Effects
                for (track_id, effects_map) in track_effects.into_iter() {
                    for (effect_id, mut plugin) in effects_map.into_iter() {
                        plugin.prepare(sample_rate, buf_size);
                        let bus = BusConfig {
                            name: "Main".into(),
                            channel_count: channels,
                            is_optional: false,
                        };
                        plugin.set_io_layout(&[bus.clone()], &[bus]);
                        self.plugin_state.add_track_effect(
                            track_id.to_u32() as usize,
                            AudioEffectInstance {
                                id: effect_id,
                                plugin,
                            },
                        );

                        let target = PluginTarget::TrackEffect(track_id, effect_id);
                        let (input, output) =
                            triple_buffer::triple_buffer(&PluginTelemetrySnapshot::default());
                        self.telemetry
                            .param_telemetry_producers
                            .insert(target.clone(), input);
                        new_consumers.insert(target, Box::new(output));
                    }
                }

                // Batch load Bus Effects & Initialize Bus Buffers
                for (bus_id, effects_map) in bus_effects.into_iter() {
                    let bus_id_index = bus_id.to_u32() as usize;
                    self.plugin_state.add_bus(bus_id_index);
                    self.workspace.bus_buffers.insert(bus_id, Vec::new());

                    for (effect_id, mut plugin) in effects_map.into_iter() {
                        plugin.prepare(sample_rate, buf_size);
                        let bus = BusConfig {
                            name: "Main".into(),
                            channel_count: channels,
                            is_optional: false,
                        };
                        plugin.set_io_layout(std::slice::from_ref(&bus.clone()), &[bus]);
                        self.plugin_state.add_bus_effect(
                            bus_id_index,
                            AudioEffectInstance {
                                id: effect_id,
                                plugin,
                            },
                        );

                        let target = PluginTarget::BusEffect(bus_id, effect_id);
                        let (input, output) =
                            triple_buffer::triple_buffer(&PluginTelemetrySnapshot::default());
                        self.telemetry
                            .param_telemetry_producers
                            .insert(target.clone(), input);
                        new_consumers.insert(target, Box::new(output));
                    }
                }

                // Ensure all buses present in the graph have buffers allocated,
                // even if they don't have any effects loaded on them yet.
                for &bus_id in &self.current_state.graph.bus_ids {
                    if !self.workspace.bus_buffers.contains_key(&bus_id) {
                        self.plugin_state.add_bus(bus_id.to_u32() as usize);
                        self.workspace.bus_buffers.insert(bus_id, Vec::new());
                    }
                }

                // Batch load Master Effects
                for (effect_id, mut plugin) in master_effects.into_iter() {
                    plugin.prepare(sample_rate, buf_size);
                    let bus = BusConfig {
                        name: "Main".into(),
                        channel_count: channels,
                        is_optional: false,
                    };
                    plugin.set_io_layout(std::slice::from_ref(&bus.clone()), &[bus]);
                    self.plugin_state.master_effects.push(AudioEffectInstance {
                        id: effect_id,
                        plugin,
                    });

                    let target = PluginTarget::MasterEffect(effect_id);
                    let (input, output) =
                        triple_buffer::triple_buffer(&PluginTelemetrySnapshot::default());
                    self.telemetry
                        .param_telemetry_producers
                        .insert(target.clone(), input);
                    new_consumers.insert(target, Box::new(output));
                }

                // Send all new consumers to DawContext in one batch via the dedicated channel.
                let _ =
                    self.io
                        .telemetry_reg_sender
                        .try_send(TelemetryRegistration::BatchRegistered {
                            consumers: new_consumers,
                        });

                log::info!("[AudioEngine] Prepared all plugins for the newly loaded project.");
            }
            AudioCommand::SetMetronomeActive(active) => {
                self.metronome_state.set_active(active);
                log::info!("[AudioEngine] Metronome Active: {}", active);
            }
            AudioCommand::TogglePlayingWithPlaybackMode(playback_mode) => {
                if self.transport.mode == playback_mode {
                    let is_playing = match self.transport.mode {
                        PlaybackMode::Song => &mut self.transport.song.is_playing,
                        PlaybackMode::Pattern { .. } => &mut self.transport.pattern.is_playing,
                    };
                    if *is_playing {
                        *is_playing = false;
                        self.stop_all_active_generators();
                    } else {
                        *is_playing = true;
                    }
                } else {
                    self.stop_all_active_generators();
                    self.transport.song.is_playing = false;
                    self.transport.pattern.is_playing = false;
                    self.transport.mode = playback_mode;
                    match self.transport.mode {
                        PlaybackMode::Song => {
                            self.transport.song.is_playing = true;
                        }
                        PlaybackMode::Pattern { .. } => {
                            self.reset_pattern_state();
                            self.transport.pattern.is_playing = true;
                        }
                    }
                }
                self.emit_current_playback_position();
            }
            AudioCommand::TogglePatternPlayback {
                pattern_id,
                generator_id,
            } => {
                if !matches!(self.transport.mode, PlaybackMode::Pattern { .. }) {
                    self.stop_playback();
                    self.transport.mode = PlaybackMode::Pattern {
                        pattern_id,
                        generator_id,
                    };
                    self.reset_pattern_state();
                    self.transport.pattern.is_playing = true;
                } else if self.transport.pattern.is_playing {
                    self.transport.pattern.is_playing = false;
                    self.stop_all_active_generators();
                    self.reset_pattern_state();
                } else {
                    self.transport.pattern.is_playing = true;
                }

                self.emit_current_playback_position();
            }
            AudioCommand::SwitchPatternGenerator(new_gen_id) => {
                if let PlaybackMode::Pattern { generator_id, .. } = &mut self.transport.mode {
                    if *generator_id != new_gen_id {
                        // Silence the old generator so ADSR tails/notes don't hang forever
                        if let Some(old_voice) = self
                            .voices
                            .active_generators
                            .iter_mut()
                            .find(|g| g.id == *generator_id)
                        {
                            if let Some(gen_instance) =
                                self.plugin_state.get_generator_mut(old_voice.id)
                            {
                                gen_instance.plugin.reset();
                            }
                            old_voice.midi_events.clear();
                            old_voice.playing_keys.clear();
                        }

                        // Hot-swap the ID. The `process_pattern_mode` function will
                        // automatically route the next batch of MIDI notes to the new generator.
                        *generator_id = new_gen_id;
                    }
                }
            }
            AudioCommand::ExecutePluginCommand {
                target,
                command,
                payload,
                request_id,
            } => {
                if let Some(plugin) = self.get_plugin_mut(&target) {
                    if let Some(res) = plugin.execute_custom_command(&command, &payload) {
                        let _ =
                            self.io
                                .feedback_producer
                                .push(AudioFeedback::PluginCommandResponse {
                                    request_id,
                                    response: res,
                                });
                    }
                }
            }
            AudioCommand::SetPluginState { target, state } => {
                if let Some(plugin) = self.get_plugin_mut(&target) {
                    plugin.set_state(&state);
                }
            }
            AudioCommand::QueryPluginState { target, request_id } => {
                if let Some(plugin) = self.get_plugin(&target) {
                    let state = plugin.get_state();
                    let _ = self
                        .io
                        .feedback_producer
                        .push(AudioFeedback::PluginStateSnapshot {
                            target,
                            state,
                            request_id,
                        });
                }
            }
            AudioCommand::QueryZeroCopyBuffer {
                target,
                name,
                request_id,
            } => {
                let buffer_opt = self
                    .get_plugin(&target)
                    .and_then(|p| p.get_zero_copy_buffer(&name));
                let _ = self
                    .io
                    .feedback_producer
                    .push(AudioFeedback::ZeroCopyBufferResponse {
                        request_id,
                        buffer: buffer_opt,
                    });
            }
            AudioCommand::QueryAudioExportSnapshot { response_tx } => {
                let _ = response_tx.send(self.export_snapshot());
            }
            AudioCommand::AddModulationSource { id, source } => {
                self.modulation.add_source(id, &source);
                log::info!("[AudioEngine] Added Modulation Source {:?}", id);
            }
            AudioCommand::RemoveModulationSource(modulation_id) => {
                self.modulation.active_sources.remove(&modulation_id);
                log::info!(
                    "[AudioEngine] Removed Modulation Source {:?}",
                    modulation_id
                );
            }
            AudioCommand::AddModulationLink { link, .. } => {
                self.modulation.active_links.push(link);
            }
            AudioCommand::UpdateModulationLinkDepth { id, depth } => {
                if let Some(link) = self.modulation.active_links.iter_mut().find(|l| l.id == id) {
                    link.depth = depth;
                }
            }
            AudioCommand::RemoveModulationLink(modulation_link_id) => {
                self.modulation
                    .active_links
                    .retain(|l| l.id != modulation_link_id);
                log::info!(
                    "[AudioEngine] Removed Modulation Link {:?}",
                    modulation_link_id
                );
            }
            AudioCommand::UpdateTrackGraph {
                tracks,
                clips,
                patterns,
            } => {
                // Update only the track/pattern/sample-index portion of the local graph.
                // Routing and automation lanes are untouched by this command.
                self.current_state.graph.tracks = tracks;
                self.current_state.graph.clips = clips;
                self.current_state.graph.patterns = patterns;

                let valid_track_ids: HashSet<_> = self
                    .current_state
                    .graph
                    .tracks
                    .iter()
                    .map(|t| t.id)
                    .collect();

                self.mixer_state
                    .track_channels
                    .retain(|track_id, _| valid_track_ids.contains(track_id));

                // Guarantee every track in the new graph has an initialized mixer channel!
                for track in self.current_state.graph.tracks.iter() {
                    self.mixer_state.track_channels.entry(track.id).or_default();
                }

                // Recompute routing order so new tracks are included in the DSP loop!
                let track_ids = self.current_state.graph.tracks.iter().map(|t| t.id);
                let bus_ids = self.workspace.bus_buffers.keys().copied();
                self.routing.cached_order =
                    compute_routing_order(track_ids, bus_ids, &self.current_state.graph.routing);
                self.recalculate_max_sample_index();
            }
            AudioCommand::UpdateAutomationLane { id, lane } => {
                log::info!("Receive update automation lane of Id {}", id);
                self.current_state.graph.automation_lanes.insert(id, lane);
            }
            AudioCommand::RemoveAutomationLane { id } => {
                self.current_state.graph.automation_lanes.remove(&id);
            }
            AudioCommand::UpdateAudioConfig {
                sample_rate,
                buffer_size,
            } => {
                let sr_changed = match sample_rate {
                    Some(val) => val != self.current_state.graph.sample_rate,
                    None => false,
                };
                let buf_changed = match buffer_size {
                    Some(val) => val != self.current_state.graph.buffer_size,
                    None => false,
                };

                if sr_changed || buf_changed {
                    if let Some(sample_rate) = sample_rate.filter(|_| sr_changed) {
                        let ratio = sample_rate as f64 / self.config.sample_rate as f64;
                        self.transport.song.playhead_samples =
                            (self.transport.song.playhead_samples as f64 * ratio) as u32;
                        self.transport.song.last_emitted_samples =
                            (self.transport.song.last_emitted_samples as f64 * ratio) as u32;

                        self.transport.pattern.playhead_samples =
                            (self.transport.pattern.playhead_samples as f64 * ratio) as u32;
                        self.transport.pattern.last_emitted_samples =
                            (self.transport.pattern.last_emitted_samples as f64 * ratio) as u32;

                        self.current_state.graph.max_sample_index =
                            (self.current_state.graph.max_sample_index as f64 * ratio) as u32;

                        // Scale all Audio Clips that are mapped in Absolute Samples
                        for clip in self.current_state.graph.clips.values_mut() {
                            if let crate::core::project::clip::ClipTimeUnit::Samples {
                                start_time,
                                loop_length,
                                offset_start,
                            } = &mut clip.time
                            {
                                *start_time = (*start_time as f64 * ratio) as u64;
                                *loop_length = (*loop_length as f64 * ratio) as u64;
                                *offset_start = (*offset_start as f64 * ratio) as u64;
                            }
                        }

                        self.config.sample_rate = sample_rate;
                    }

                    let sr = sample_rate.unwrap_or(self.current_state.graph.sample_rate);
                    let buf_size = buffer_size.unwrap_or(self.current_state.graph.buffer_size);
                    self.current_state.graph.buffer_size = buf_size;

                    self.reprepare_plugins_and_clear_delays(sr, buf_size);
                    self.recalculate_latencies();

                    log::info!(
                        "[AudioEngine] UpdateAudioConfig applied: {} Hz, buf {}. Playheads scaled and plugins re-prepared.",
                        sr,
                        buf_size
                    );

                    self.recalculate_max_sample_index();
                }
            }
            AudioCommand::ReplaceFullGraph { graph } => {
                let sr_changed = graph.sample_rate != self.config.sample_rate;
                let buf_changed = graph.buffer_size != self.current_state.graph.buffer_size;

                if sr_changed || buf_changed {
                    let sr = graph.sample_rate;
                    let buf_size = graph.buffer_size;

                    if sr_changed {
                        let ratio = sr as f64 / self.config.sample_rate as f64;
                        self.transport.song.playhead_samples =
                            (self.transport.song.playhead_samples as f64 * ratio) as u32;
                        self.transport.song.last_emitted_samples =
                            (self.transport.song.last_emitted_samples as f64 * ratio) as u32;

                        self.transport.pattern.playhead_samples =
                            (self.transport.pattern.playhead_samples as f64 * ratio) as u32;
                        self.transport.pattern.last_emitted_samples =
                            (self.transport.pattern.last_emitted_samples as f64 * ratio) as u32;

                        self.config.sample_rate = sr;
                    }

                    self.reprepare_plugins_and_clear_delays(sr, buf_size);

                    log::info!(
                        "[AudioEngine] ReplaceFullGraph sync: {} Hz, buf {}. Playheads scaled and plugins re-prepared.",
                        sr,
                        buf_size
                    );
                }

                // Used for undo/redo. Atomically replace the full graph snapshot
                // and recompute the cached routing order.
                let track_ids = graph.tracks.iter().map(|t| t.id);
                let bus_ids = graph.bus_ids.iter().copied();
                self.routing.cached_order =
                    compute_routing_order(track_ids, bus_ids, &graph.routing);

                self.current_state.graph = graph;

                self.modulation
                    .replace_from_graph(&self.current_state.graph);

                log::debug!("[AudioEngine] ReplaceFullGraph applied");
                self.recalculate_max_sample_index();
            }
            AudioCommand::BeginEdit { target } => {
                self.handle_parameter_edit(&target, true);
            }
            AudioCommand::EndEdit { target } => {
                self.handle_parameter_edit(&target, false);
            }
            AudioCommand::SetPluginTelemetrySubscription {
                target,
                buffers,
                active,
            } => {
                if active {
                    let entry = self
                        .telemetry
                        .active_telemetry_subscriptions
                        .entry(target)
                        .or_default();
                    for buf in buffers {
                        entry.insert(buf);
                    }
                } else {
                    self.telemetry
                        .active_telemetry_subscriptions
                        .remove(&target);
                }
            }
            AudioCommand::SetMixerTelemetrySubscription { active } => {
                self.telemetry.mixer_snapshot_active = active
            }
            AudioCommand::ResumeAutomation { target } => {
                self.modulation.suspended_targets.remove(&target);
            }
        }
    }
}
