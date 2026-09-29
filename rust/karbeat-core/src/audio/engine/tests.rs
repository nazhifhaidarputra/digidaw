#![cfg(test)]
#![allow(
    clippy::expect_used,
    reason = "engine tests fail immediately when deterministic fixtures violate their invariants"
)]

use crate::audio::engine::voices::VoiceState;
use crate::audio::engine::{AudioBuffer, AudioEngine, AudioEngineTelemetry};
use crate::audio::event::{PluginTarget, TransportFeedback};
use crate::audio::render_state::AudioGraphState;
use crate::commands::{AudioCommand, AudioFeedback, EffectTarget, TelemetryRegistration};
use crate::core::project::automation::{
    AutomationLane, AutomationPoint, AutomationTarget, EffectAutomationTarget,
    MasterAutomationTarget, MixerChannelParamTarget, TrackAutomationTarget,
};
use crate::core::project::modulation::{ModulationLink, ModulationSource};
use crate::core::project::track::AudioTrack;
use crate::core::project::{ApplicationState, ModulationLinkForOrderedLaneView, TrackType};
use karbeat_plugin_api::types::ProcessingMode;
use karbeat_plugin_api::types::{MidiMessage, NoteExpressionType};
use karbeat_plugins::registry::PluginRegistry;
use karbeat_utils::color::Color;
use karbeat_utils::hash::hash_str;
use karbeat_utils::types::NormalizedF64;
use rtrb::RingBuffer;
use std::sync::mpsc;
// use crate::audio::;

struct TimestampedAudioBlock {
    timestamp_micros: u64,
    samples: Vec<f32>,
}

impl AudioBuffer for TimestampedAudioBlock {
    fn samples(&self) -> &[f32] {
        &self.samples
    }

    fn samples_mut(&mut self) -> &mut [f32] {
        &mut self.samples
    }
}

#[test]
fn engine_processes_custom_audio_buffer() {
    let (_, command_consumer) = RingBuffer::<AudioCommand>::new(32);
    let (position_producer, _) = RingBuffer::<TransportFeedback>::new(32);
    let (feedback_producer, _) = RingBuffer::<AudioFeedback>::new(32);
    let (telemetry_sender, _) = mpsc::sync_channel::<TelemetryRegistration>(32);
    let mut engine = AudioEngine::new(
        command_consumer,
        position_producer,
        feedback_producer,
        44_100,
        2,
        120.0,
        16,
        AudioEngineTelemetry::new_for_export(),
        telemetry_sender,
    );
    let mut block = TimestampedAudioBlock {
        timestamp_micros: 42,
        samples: vec![1.0; 32],
    };

    engine.process(&mut block);

    assert!(block.samples.iter().all(|sample| *sample == 0.0));
    assert_eq!(block.timestamp_micros, 42);
}

#[test]
fn export_snapshot_builds_fresh_offline_runtime() {
    let (_, command_consumer) = RingBuffer::<AudioCommand>::new(32);
    let (position_producer, _) = RingBuffer::<TransportFeedback>::new(32);
    let (feedback_producer, _) = RingBuffer::<AudioFeedback>::new(32);
    let (telemetry_sender, _) = mpsc::sync_channel::<TelemetryRegistration>(32);
    let mut engine = AudioEngine::new(
        command_consumer,
        position_producer,
        feedback_producer,
        48_000,
        2,
        120.0,
        512,
        AudioEngineTelemetry::new_for_export(),
        telemetry_sender,
    );

    let mut app_state = ApplicationState::default();
    let track_id = app_state.tracks.insert_with_key(|id| {
        AudioTrack::new(
            id,
            "Export Track",
            Color::new_from_rgb(0, 0, 0),
            TrackType::Audio,
        )
    });
    engine.process_command(AudioCommand::ReplaceFullGraph {
        graph: AudioGraphState::from(&app_state),
    });
    engine.process_command(AudioCommand::SetBPM(96.0));
    engine.transport.time_sig_numerator = 7;
    engine.transport.time_sig_denominator = 8;
    engine.transport.song.playhead_samples = 24_000;
    engine.transport.song.is_playing = true;
    engine.workspace.mix_buffer.extend_from_slice(&[0.5, -0.5]);
    let bus_id = crate::shared::BusId::from(3);
    engine.workspace.bus_buffers.insert(bus_id, vec![0.25]);
    engine.routing.track_tails.insert(track_id, 1_024);
    engine.mixer_state.master.mute = true;

    let plugin_registry = PluginRegistry::new_with_defaults();
    let registry_id = hash_str("synth_karbeatzer_v2");
    let (plugin_factory, _) = plugin_registry
        .create_plugin_by_id(registry_id)
        .expect("test generator should be registered");
    let generator_id = crate::shared::GeneratorId::from(1);
    engine.process_command(AudioCommand::AddGenerator {
        generator_id,
        track_id,
        registry_id,
        plugin_factory,
    });
    let parameter_id = engine
        .plugin_state
        .get_generator(generator_id)
        .expect("live generator should exist")
        .plugin
        .get_parameter_specs()[0]
        .id;
    engine.process_command(AudioCommand::SetParameter {
        target: PluginTarget::Generator(generator_id),
        param_id: parameter_id,
        value: 0.37,
    });

    let effect_registry_id = hash_str("effect_delay");
    let (effect_factory, _) = plugin_registry
        .create_plugin_by_id(effect_registry_id)
        .expect("test effect should be registered");
    let track_effect_id = crate::shared::EffectId::from(1);
    engine.process_command(AudioCommand::AddEffect {
        target: EffectTarget::Track(track_id),
        effect_id: track_effect_id,
        registry_id: effect_registry_id,
        effect_factory,
    });
    let bus_effect_id = crate::shared::EffectId::from(2);
    engine.process_command(AudioCommand::AddEffect {
        target: EffectTarget::Bus(bus_id),
        effect_id: bus_effect_id,
        registry_id: effect_registry_id,
        effect_factory,
    });
    let master_effect_id = crate::shared::EffectId::from(3);
    engine.process_command(AudioCommand::AddEffect {
        target: EffectTarget::Master,
        effect_id: master_effect_id,
        registry_id: effect_registry_id,
        effect_factory,
    });
    let snapshot = engine.export_snapshot();
    let (_, command_consumer) = RingBuffer::<AudioCommand>::new(32);
    let (position_producer, _) = RingBuffer::<TransportFeedback>::new(32);
    let (feedback_producer, _) = RingBuffer::<AudioFeedback>::new(32);
    let offline_engine = AudioEngine::from_export_snapshot(
        snapshot,
        &plugin_registry,
        2,
        command_consumer,
        position_producer,
        feedback_producer,
    )
    .expect("export snapshot should hydrate");

    assert_eq!(offline_engine.current_state.graph.tracks.len(), 1);
    assert_eq!(offline_engine.transport.bpm, 96.0);
    assert_eq!(offline_engine.transport.time_sig_numerator, 7);
    assert_eq!(offline_engine.transport.time_sig_denominator, 8);
    assert_eq!(offline_engine.processing_mode, ProcessingMode::Offline);
    assert_eq!(offline_engine.transport.song.playhead_samples, 0);
    assert!(!offline_engine.transport.song.is_playing);
    assert!(offline_engine.workspace.mix_buffer.is_empty());
    assert!(
        offline_engine
            .workspace
            .bus_buffers
            .get(&bus_id)
            .is_some_and(Vec::is_empty)
    );
    assert!(offline_engine.routing.track_tails.is_empty());
    assert!(offline_engine.mixer_state.master.mute);
    let offline_generator = offline_engine
        .plugin_state
        .get_generator(generator_id)
        .expect("snapshot generator should be hydrated");
    assert_eq!(offline_generator.registry_id, registry_id);
    assert_eq!(offline_generator.plugin.get_parameter(parameter_id), 0.37);
    assert_eq!(
        offline_engine.plugin_state.track_effects[track_id.to_u32() as usize][0].id,
        track_effect_id
    );
    assert_eq!(
        offline_engine.plugin_state.bus_effects[bus_id.to_u32() as usize][0].id,
        bus_effect_id
    );
    assert_eq!(
        offline_engine.plugin_state.master_effects[0].id,
        master_effect_id
    );
}

#[test]
fn non_note_midi_messages_preserve_playing_keys() {
    let messages = [
        MidiMessage::ControlChange {
            channel: 0,
            controller: 1,
            value: 64,
        },
        MidiMessage::PitchBend {
            channel: 0,
            value: 1024,
        },
        MidiMessage::NoteExpression {
            note_id: 1,
            expression: NoteExpressionType::Pressure,
            value: 0.5,
        },
    ];

    for message in messages {
        let mut playing_keys = vec![60, 64];
        VoiceState::update_playing_keys(&mut playing_keys, &message);
        assert_eq!(playing_keys, [60, 64]);
    }
}

#[test]
fn channel_mode_midi_messages_clear_playing_keys() {
    for controller in [120, 123, 124, 125, 126, 127] {
        let mut playing_keys = vec![60, 64];
        let message = MidiMessage::ControlChange {
            channel: 0,
            controller,
            value: 0,
        };

        VoiceState::update_playing_keys(&mut playing_keys, &message);
        assert!(playing_keys.is_empty());
    }
}

#[test]
fn generator_remains_active_after_note_off_for_release_envelope() {
    let (_, command_consumer) = RingBuffer::<AudioCommand>::new(32);
    let (position_producer, _) = RingBuffer::<TransportFeedback>::new(32);
    let (feedback_producer, _) = RingBuffer::<AudioFeedback>::new(32);
    let (telemetry_sender, _) = mpsc::sync_channel::<TelemetryRegistration>(32);
    let mut engine = AudioEngine::new(
        command_consumer,
        position_producer,
        feedback_producer,
        48_000,
        2,
        120.0,
        16,
        AudioEngineTelemetry::new_for_export(),
        telemetry_sender,
    );
    let registry = PluginRegistry::new_with_defaults();
    let registry_id = hash_str("synth_karbeatzer_v2");
    let (factory, _) = registry
        .create_plugin_by_id(registry_id)
        .expect("test generator should be registered");
    let generator_id = crate::shared::GeneratorId::from(1);
    let track_id = crate::shared::TrackId::from(1);
    engine.process_command(AudioCommand::AddGenerator {
        generator_id,
        track_id,
        registry_id,
        plugin_factory: factory,
    });
    let mut voice = crate::audio::engine::GeneratorVoice::new(generator_id, track_id, true);
    voice
        .midi_events
        .push(karbeat_plugin_api::types::MidiEvent {
            sample_offset: 0,
            data: MidiMessage::NoteOff {
                note_id: None,
                channel: 0,
                key: 60,
            },
        });
    engine.voices.active_generators.push(voice);

    engine.cleanup_finished_voices();

    assert_eq!(engine.voices.active_generators.len(), 1);
    assert!(engine.voices.active_generators[0].active);
    assert!(engine.voices.active_generators[0].midi_events.is_empty());
}

#[test]
fn browser_preview_stops_at_its_frame_limit() {
    let (_, cmd_consumer) = RingBuffer::<AudioCommand>::new(32);
    let (pos_producer, _) = RingBuffer::<TransportFeedback>::new(32);
    let (fb_producer, _) = RingBuffer::<AudioFeedback>::new(32);
    let (telemetry_tx, _) = mpsc::sync_channel::<TelemetryRegistration>(32);
    let sample_rate = 44_100;
    let mut engine = AudioEngine::new(
        cmd_consumer,
        pos_producer,
        fb_producer,
        sample_rate,
        2,
        120.0,
        16,
        AudioEngineTelemetry::new_for_export(),
        telemetry_tx,
    );

    let file = tempfile::NamedTempFile::new().expect("preview fixture file");
    let spec = hound::WavSpec {
        channels: 1,
        sample_rate,
        bits_per_sample: 16,
        sample_format: hound::SampleFormat::Int,
    };
    let mut writer = hound::WavWriter::new(file.reopen().expect("fixture handle"), spec)
        .expect("fixture writer");
    for _ in 0..64 {
        writer.write_sample(16_384_i16).expect("fixture sample");
    }
    writer.finalize().expect("finalize fixture");
    let waveform = crate::core::file_manager::audio_loader::load_audio_file(
        file.path().to_str().expect("fixture path"),
        None,
        sample_rate,
    )
    .expect("load preview fixture");

    engine.process_command(AudioCommand::PlayPreview {
        waveform,
        max_frames: 4,
    });

    let mut first_block = vec![0.0; 16 * 2];
    engine.process(&mut first_block);
    assert!(first_block[..8].iter().any(|sample| *sample != 0.0));
    assert!(first_block[8..].iter().all(|sample| *sample == 0.0));

    let mut second_block = vec![1.0; 16 * 2];
    engine.process(&mut second_block);
    assert!(second_block.iter().all(|sample| *sample == 0.0));
}

#[test]
fn test_automation_lane_applied_to_mixer_volume() {
    // Setup Audio Engine
    let (_, cmd_consumer) = RingBuffer::<AudioCommand>::new(1024);
    let (pos_producer, _) = RingBuffer::<TransportFeedback>::new(1024);
    let (fb_producer, _) = RingBuffer::<AudioFeedback>::new(1024);
    let (telemetry_tx, _) = mpsc::sync_channel::<TelemetryRegistration>(1024);

    let mut engine = AudioEngine::new(
        cmd_consumer,
        pos_producer,
        fb_producer,
        44100,
        2,
        120.0,
        512,
        AudioEngineTelemetry::new_for_export(),
        telemetry_tx,
    );

    let mut app_state = ApplicationState::default();
    let track_id = app_state.tracks.insert_with_key(|id| {
        AudioTrack::new(
            id,
            "Test Track",
            Color::new_from_rgb(0, 0, 0),
            TrackType::Audio,
        )
    });

    // Target: Track Volume
    let target = AutomationTarget::Track {
        track_id,
        track_target: TrackAutomationTarget::MixerChannel(MixerChannelParamTarget::Volume),
    };

    let automation_id = app_state.automation_pool.insert_with_key(|id| {
        let mut lane = AutomationLane::new(id, "Volume", 0.0, 1.0, 0.5);
        lane.add_point(AutomationPoint::new(0, NormalizedF64::new(0.75)));
        lane
    });
    let automation_lane = app_state.automation_pool[automation_id].clone();

    // Setup modulation source and link
    let mod_source_id = app_state
        .modulation_sources
        .insert(ModulationSource::Automation {
            lane_id: automation_id,
        });
    let mod_link_id =
        app_state
            .modulation_links
            .insert_with_key(|id| ModulationLinkForOrderedLaneView {
                order_idx: 0,
                prop: ModulationLink {
                    id,
                    source_id: mod_source_id,
                    target: target.clone(),
                    depth: 1.0,
                    base_value: 0.5,
                },
            });

    // Initialize Engine State
    engine.process_command(AudioCommand::ReplaceFullGraph {
        graph: AudioGraphState::from(&app_state),
    });

    let mut new_val = crate::audio::engine::AudioMixerChannelValues::default();
    new_val.volume.set_base(0.5);
    engine.mixer_state.track_channels.insert(track_id, new_val);

    engine.process_command(AudioCommand::AddModulationSource {
        id: mod_source_id,
        source: ModulationSource::Automation {
            lane_id: automation_id,
        },
    });
    engine.process_command(AudioCommand::AddModulationLink {
        id: mod_link_id,
        link: ModulationLink {
            id: mod_link_id,
            source_id: mod_source_id,
            target: target.clone(),
            depth: 1.0,
            base_value: 0.5,
        },
    });
    engine.process_command(AudioCommand::UpdateAutomationLane {
        id: automation_id,
        lane: automation_lane.into(),
    });

    // Let's set playhead to 0 and playback mode
    engine.process_command(AudioCommand::SetPlayhead(0));

    // Run one process block
    let mut output_buffer = vec![0.0; 512 * 2];
    engine.process(&mut output_buffer);

    // The normalized automation value is mapped into the channel's -100 dB to +6 dB range.
    let ch = engine
        .mixer_state
        .track_channels
        .get(&track_id)
        .expect("Track channel not found");
    assert_eq!(
        ch.volume.get(),
        -20.5,
        "Volume should be automated to -20.5 dB"
    );
}

#[test]
fn effect_bypass_skips_latency_and_survives_export_snapshot() {
    let (_, command_consumer) = RingBuffer::<AudioCommand>::new(32);
    let (position_producer, _) = RingBuffer::<TransportFeedback>::new(32);
    let (feedback_producer, _) = RingBuffer::<AudioFeedback>::new(32);
    let (telemetry_sender, _) = mpsc::sync_channel::<TelemetryRegistration>(32);
    let mut engine = AudioEngine::new(
        command_consumer,
        position_producer,
        feedback_producer,
        48_000,
        2,
        120.0,
        512,
        AudioEngineTelemetry::new_for_export(),
        telemetry_sender,
    );
    engine.process_command(AudioCommand::ReplaceFullGraph {
        graph: AudioGraphState::from(&ApplicationState::default()),
    });

    let plugin_registry = PluginRegistry::new_with_defaults();
    let effect_registry_id = hash_str("effect_delay");
    let (effect_factory, _) = plugin_registry
        .create_plugin_by_id(effect_registry_id)
        .expect("test effect should be registered");
    let effect_id = crate::shared::EffectId::from(1);
    engine.process_command(AudioCommand::AddEffect {
        target: EffectTarget::Master,
        effect_id,
        registry_id: effect_registry_id,
        effect_factory,
    });
    assert!(!engine.plugin_state.master_effects[0].bypass);

    engine.process_command(AudioCommand::SetEffectBypass {
        target: EffectTarget::Master,
        effect_id,
        bypass: true,
    });
    let effect = &engine.plugin_state.master_effects[0];
    assert!(effect.bypass);
    assert_eq!(effect.active_latency_samples(), 0);

    let mut block = vec![0.0; 512 * 2];
    engine.process(&mut block);

    let (_, command_consumer) = RingBuffer::<AudioCommand>::new(32);
    let (position_producer, _) = RingBuffer::<TransportFeedback>::new(32);
    let (feedback_producer, _) = RingBuffer::<AudioFeedback>::new(32);
    let offline_engine = AudioEngine::from_export_snapshot(
        engine.export_snapshot(),
        &plugin_registry,
        2,
        command_consumer,
        position_producer,
        feedback_producer,
    )
    .expect("export snapshot should hydrate");
    assert!(offline_engine.plugin_state.master_effects[0].bypass);

    engine.process_command(AudioCommand::SetEffectBypass {
        target: EffectTarget::Master,
        effect_id,
        bypass: false,
    });
    assert!(!engine.plugin_state.master_effects[0].bypass);
}

#[test]
fn removing_an_effect_drops_its_automation_in_the_same_command() {
    let (_, command_consumer) = RingBuffer::<AudioCommand>::new(32);
    let (position_producer, _) = RingBuffer::<TransportFeedback>::new(32);
    let (feedback_producer, _) = RingBuffer::<AudioFeedback>::new(32);
    let (telemetry_sender, _) = mpsc::sync_channel::<TelemetryRegistration>(32);
    let mut engine = AudioEngine::new(
        command_consumer,
        position_producer,
        feedback_producer,
        48_000,
        2,
        120.0,
        512,
        AudioEngineTelemetry::new_for_export(),
        telemetry_sender,
    );

    let effect_id = crate::shared::EffectId::from(1);
    let effect_target = AutomationTarget::Master(MasterAutomationTarget::MixerChannel(
        MixerChannelParamTarget::Plugin {
            effect_id,
            target: EffectAutomationTarget::PluginParam { param_id: 0 },
        },
    ));
    let volume_target = AutomationTarget::Master(MasterAutomationTarget::MixerChannel(
        MixerChannelParamTarget::Volume,
    ));
    let mut app_state = ApplicationState::default();
    let (effect_lane, effect_link) = app_state
        .add_automation_lane(effect_target, "Gain", 0.0, 1.0, 0.5)
        .expect("effect lane should be created");
    let (volume_lane, volume_link) = app_state
        .add_automation_lane(volume_target, "Volume", 0.0, 1.0, 0.5)
        .expect("volume lane should be created");
    let effect_source = app_state.modulation_links[effect_link].prop.source_id;
    let volume_source = app_state.modulation_links[volume_link].prop.source_id;
    engine.process_command(AudioCommand::ReplaceFullGraph {
        graph: AudioGraphState::from(&app_state),
    });
    engine
        .modulation
        .replace_from_graph(&engine.current_state.graph);

    let plugin_registry = PluginRegistry::new_with_defaults();
    let effect_registry_id = hash_str("effect_delay");
    let (effect_factory, _) = plugin_registry
        .create_plugin_by_id(effect_registry_id)
        .expect("test effect should be registered");
    engine.process_command(AudioCommand::AddEffect {
        target: EffectTarget::Master,
        effect_id,
        registry_id: effect_registry_id,
        effect_factory,
    });

    engine.process_command(AudioCommand::RemoveEffect {
        target: EffectTarget::Master,
        effect_id,
    });

    let links: Vec<_> = engine
        .modulation
        .active_links
        .iter()
        .map(|l| l.id)
        .collect();
    assert_eq!(links, vec![volume_link]);
    assert!(
        !engine
            .modulation
            .active_sources
            .contains_key(&effect_source)
    );
    assert!(
        engine
            .modulation
            .active_sources
            .contains_key(&volume_source)
    );
    let lanes = &engine.current_state.graph.automation_lanes;
    assert!(!lanes.contains_key(&effect_lane.id));
    assert!(lanes.contains_key(&volume_lane.id));
    assert!(engine.plugin_state.master_effects.is_empty());
}

/// Effect that replaces its main input with a constant tone, ignoring its sidechain.
struct ToneEffect;

/// Effect that passes its main input through and accumulates the energy of its sidechain input.
struct AuxProbe(std::sync::Arc<std::sync::Mutex<f32>>);

macro_rules! test_effect_boilerplate {
    () => {
        fn name(&self) -> &str {
            "Routing test effect"
        }
        fn category(&self) -> karbeat_plugin_api::types::PluginCategory {
            karbeat_plugin_api::types::PluginCategory::Effect
        }
        fn prepare(&mut self, _: f32, _: usize) {}
        fn reset(&mut self) {}
        fn set_io_layout(
            &mut self,
            _: &[karbeat_plugin_api::types::BusConfig],
            _: &[karbeat_plugin_api::types::BusConfig],
        ) {
        }
        fn set_parameter(&mut self, _: u32, _: f32) {}
        fn get_parameter(&self, _: u32) -> f32 {
            0.0
        }
        fn apply_automation(&mut self, _: u32, _: f32) {}
        fn clear_automation(&mut self, _: u32) {}
        fn default_parameters(&self) -> karbeat_plugin_api::traits::HashMap<u32, f32> {
            karbeat_plugin_api::traits::HashMap::new()
        }
        fn static_parameter_specs() -> Vec<karbeat_plugin_api::prelude::ParameterSpec> {
            Vec::new()
        }
        fn get_parameter_specs(&self) -> Vec<karbeat_plugin_api::prelude::ParameterSpec> {
            Vec::new()
        }
        fn as_any(&self) -> &dyn std::any::Any {
            self
        }
    };
}

impl karbeat_plugin_api::traits::AudioPlugin for ToneEffect {
    test_effect_boilerplate!();
    fn process(
        &mut self,
        buffers: &mut karbeat_plugin_api::types::AudioBuffers,
        _: &karbeat_plugin_api::types::ProcessContext,
    ) {
        for output in buffers.main_outputs.iter_mut() {
            for channel in output.channel_data.iter_mut() {
                channel.fill(0.5);
            }
        }
    }
}

impl karbeat_plugin_api::traits::AudioPlugin for AuxProbe {
    test_effect_boilerplate!();
    fn process(
        &mut self,
        buffers: &mut karbeat_plugin_api::types::AudioBuffers,
        _: &karbeat_plugin_api::types::ProcessContext,
    ) {
        for (output, input) in buffers
            .main_outputs
            .iter_mut()
            .zip(buffers.main_inputs.iter())
        {
            for (destination, source) in output
                .channel_data
                .iter_mut()
                .zip(input.channel_data.iter())
            {
                destination.copy_from_slice(source);
            }
        }
        let energy: f32 = buffers
            .aux_inputs
            .iter()
            .flat_map(|bus| bus.channel_data.iter())
            .flat_map(|channel| channel.iter())
            .map(|sample| sample.abs())
            .sum();
        *self.0.lock().expect("probe lock") += energy;
    }
}

/// Renders a tone track through a bus into the sidechain of a probe effect on a silent track,
/// with the source fader pulled down, and returns the sidechain energy the probe received.
fn render_bus_keyed_sidechain(tap: crate::core::project::RoutingTap) -> f32 {
    use crate::core::project::{RoutingConnection, RoutingNode, SidechainRoute};

    let (_, command_consumer) = RingBuffer::<AudioCommand>::new(32);
    let (position_producer, _) = RingBuffer::<TransportFeedback>::new(32);
    let (feedback_producer, _) = RingBuffer::<AudioFeedback>::new(32);
    let (telemetry_sender, _) = mpsc::sync_channel::<TelemetryRegistration>(32);
    let mut engine = AudioEngine::new(
        command_consumer,
        position_producer,
        feedback_producer,
        48_000,
        2,
        120.0,
        64,
        AudioEngineTelemetry::new_for_export(),
        telemetry_sender,
    );
    // The keyed track is created first, so without sidechain-aware ordering it would render
    // before the bus that feeds its sidechain and receive silence.
    let mut app_state = ApplicationState::default();
    let keyed = app_state.tracks.insert_with_key(|id| {
        AudioTrack::new(id, "Keyed", Color::new_from_rgb(0, 0, 0), TrackType::Audio)
    });
    let source = app_state.tracks.insert_with_key(|id| {
        AudioTrack::new(id, "Source", Color::new_from_rgb(0, 0, 0), TrackType::Audio)
    });
    engine.process_command(AudioCommand::ReplaceFullGraph {
        graph: AudioGraphState::from(&app_state),
    });
    let bus = crate::shared::BusId::from(1);
    engine.process_command(AudioCommand::AddBus {
        bus_id: bus,
        name: "Key".into(),
    });
    let tone = crate::shared::EffectId::from(1);
    let probe = crate::shared::EffectId::from(2);
    let energy = std::sync::Arc::new(std::sync::Mutex::new(0.0));
    engine.process_command(AudioCommand::InstallEffect {
        target: EffectTarget::Track(source),
        effect_id: tone,
        registry_id: 0,
        plugin: Box::new(ToneEffect),
        telemetry: None,
    });
    engine.process_command(AudioCommand::InstallEffect {
        target: EffectTarget::Track(keyed),
        effect_id: probe,
        registry_id: 0,
        plugin: Box::new(AuxProbe(energy.clone())),
        telemetry: None,
    });
    let mut key =
        RoutingConnection::new_send(RoutingNode::Track(source), RoutingNode::Bus(bus), 1.0);
    key.tap = tap;
    engine.process_command(AudioCommand::UpdateRouting {
        routing: vec![
            key,
            RoutingConnection::new_send(
                RoutingNode::Bus(bus),
                RoutingNode::PluginSidechain(SidechainRoute::TrackEffect(keyed, probe)),
                1.0,
            ),
            RoutingConnection::new(RoutingNode::Track(keyed), RoutingNode::Master),
        ]
        .into_boxed_slice(),
    });
    let mut source_channel = crate::audio::engine::AudioMixerChannelValues::default();
    source_channel.volume.set_base(-100.0);
    engine
        .mixer_state
        .track_channels
        .insert(source, source_channel);
    // The tone effect has no clips to render, so a ringing tail keeps its track processing.
    engine.routing.track_tails.insert(source, u32::MAX);

    // Let the fader finish smoothing before measuring.
    let mut block = vec![0.0_f32; 128];
    for _ in 0..16 {
        engine.process(&mut block);
    }
    *energy.lock().expect("probe lock") = 0.0;
    for _ in 0..8 {
        engine.process(&mut block);
    }
    *energy.lock().expect("probe lock")
}

#[test]
fn bus_feeds_a_track_sidechain_and_pre_fader_taps_ignore_the_source_fader() {
    use crate::core::project::RoutingTap;

    let pre_fader = render_bus_keyed_sidechain(RoutingTap::PreFader);
    let post_fader = render_bus_keyed_sidechain(RoutingTap::PostFader);
    // 8 blocks of 64 stereo frames at the tone's 0.5 amplitude, through the bus's
    // constant-power center pan.
    let expected = 512.0 * std::f32::consts::FRAC_1_SQRT_2;
    assert!(
        (pre_fader - expected).abs() < 1.0,
        "bus signal must reach the track sidechain, got {pre_fader}"
    );
    assert!(
        post_fader < pre_fader * 0.01,
        "post-fader tap must follow the lowered source fader: pre {pre_fader}, post {post_fader}"
    );
}

/// Renders a tone track and returns the master output energy of the last block.
fn render_tone_track(linked_to_master: bool) -> f32 {
    use crate::core::project::{RoutingConnection, RoutingNode};

    let (_, command_consumer) = RingBuffer::<AudioCommand>::new(32);
    let (position_producer, _) = RingBuffer::<TransportFeedback>::new(32);
    let (feedback_producer, _) = RingBuffer::<AudioFeedback>::new(32);
    let (telemetry_sender, _) = mpsc::sync_channel::<TelemetryRegistration>(32);
    let mut engine = AudioEngine::new(
        command_consumer,
        position_producer,
        feedback_producer,
        48_000,
        2,
        120.0,
        64,
        AudioEngineTelemetry::new_for_export(),
        telemetry_sender,
    );
    let mut app_state = ApplicationState::default();
    let track = app_state.tracks.insert_with_key(|id| {
        AudioTrack::new(id, "Tone", Color::new_from_rgb(0, 0, 0), TrackType::Audio)
    });
    engine.process_command(AudioCommand::ReplaceFullGraph {
        graph: AudioGraphState::from(&app_state),
    });
    engine.process_command(AudioCommand::InstallEffect {
        target: EffectTarget::Track(track),
        effect_id: crate::shared::EffectId::from(1),
        registry_id: 0,
        plugin: Box::new(ToneEffect),
        telemetry: None,
    });
    let routing = if linked_to_master {
        vec![RoutingConnection::new(
            RoutingNode::Track(track),
            RoutingNode::Master,
        )]
    } else {
        Vec::new()
    };
    engine.process_command(AudioCommand::UpdateRouting {
        routing: routing.into_boxed_slice(),
    });
    engine.routing.track_tails.insert(track, u32::MAX);

    let mut block = vec![0.0_f32; 128];
    for _ in 0..4 {
        engine.process(&mut block);
    }
    block.iter().map(|sample| sample.abs()).sum()
}

#[test]
fn unlinked_track_does_not_reach_master() {
    assert!(render_tone_track(true) > 1.0);
    assert_eq!(render_tone_track(false), 0.0);
}

#[test]
fn pattern_transport_pauses_seeks_and_loops_a_region() {
    use crate::core::project::track::midi::Pattern;

    let (_, command_consumer) = RingBuffer::<AudioCommand>::new(32);
    let (position_producer, _) = RingBuffer::<TransportFeedback>::new(64);
    let (feedback_producer, _) = RingBuffer::<AudioFeedback>::new(32);
    let (telemetry_sender, _) = mpsc::sync_channel::<TelemetryRegistration>(32);
    let mut engine = AudioEngine::new(
        command_consumer,
        position_producer,
        feedback_producer,
        48_000,
        2,
        120.0,
        64,
        AudioEngineTelemetry::new_for_export(),
        telemetry_sender,
    );
    let mut app_state = ApplicationState::default();
    let track_id = app_state.tracks.insert_with_key(|id| {
        AudioTrack::new(id, "Synth", Color::new_from_rgb(0, 0, 0), TrackType::Midi)
    });
    let pattern_id = app_state.pattern_pool.insert_with_key(|id| Pattern {
        id,
        length_ticks: 960 * 16,
        ..Pattern::default()
    });
    engine.process_command(AudioCommand::ReplaceFullGraph {
        graph: AudioGraphState::from(&app_state),
    });
    let registry = PluginRegistry::new_with_defaults();
    let registry_id = hash_str("synth_karbeatzer_v2");
    let (plugin_factory, _) = registry
        .create_plugin_by_id(registry_id)
        .expect("test generator should be registered");
    let generator_id = crate::shared::GeneratorId::from(1);
    engine.process_command(AudioCommand::AddGenerator {
        generator_id,
        track_id,
        registry_id,
        plugin_factory,
    });

    let toggle = || AudioCommand::TogglePatternPlayback {
        pattern_id,
        generator_id,
    };
    let mut block = vec![0.0_f32; 128];

    // A position seeked while stopped is where playback starts.
    engine.process_command(AudioCommand::SetPatternPlayhead(1_000));
    engine.process_command(toggle());
    engine.process(&mut block);
    assert_eq!(engine.transport.pattern.playhead_samples, 1_064);

    // Pausing keeps the position; playing again resumes from it.
    engine.process_command(toggle());
    assert!(!engine.transport.pattern.is_playing);
    engine.process(&mut block);
    assert_eq!(engine.transport.pattern.playhead_samples, 1_064);
    engine.process_command(toggle());
    assert!(engine.transport.pattern.is_playing);

    // One beat at 120 BPM and 48 kHz is 24,000 samples; the loop wraps to its start.
    engine.process_command(AudioCommand::SetPatternLoop(Some((960, 1_920))));
    engine.process_command(AudioCommand::SetPatternPlayhead(48_000));
    engine.process(&mut block);
    assert_eq!(engine.transport.pattern.playhead_samples, 24_064);

    // Stopping rewinds the pattern only.
    engine.transport.song.playhead_samples = 5_000;
    engine.process_command(AudioCommand::StopPatternPlayback);
    assert_eq!(engine.transport.pattern.playhead_samples, 0);
    assert_eq!(engine.transport.song.playhead_samples, 5_000);
}

/// Generator that records which keys it is holding, from the MIDI it actually receives.
struct HeldKeysRecorder(std::sync::Arc<std::sync::Mutex<Vec<u8>>>);

impl karbeat_plugin_api::traits::AudioPlugin for HeldKeysRecorder {
    fn name(&self) -> &str {
        "Held keys recorder"
    }
    fn category(&self) -> karbeat_plugin_api::types::PluginCategory {
        karbeat_plugin_api::types::PluginCategory::Instrument
    }
    fn prepare(&mut self, _: f32, _: usize) {}
    fn reset(&mut self) {}
    fn set_io_layout(
        &mut self,
        _: &[karbeat_plugin_api::types::BusConfig],
        _: &[karbeat_plugin_api::types::BusConfig],
    ) {
    }
    fn process(
        &mut self,
        _: &mut karbeat_plugin_api::types::AudioBuffers,
        context: &karbeat_plugin_api::types::ProcessContext,
    ) {
        let mut held = self.0.lock().expect("recorder lock");
        for event in context.midi_events {
            match event.data {
                MidiMessage::NoteOn { key, velocity, .. } if velocity > 0 => {
                    if !held.contains(&key) {
                        held.push(key);
                    }
                }
                MidiMessage::NoteOn { key, .. } | MidiMessage::NoteOff { key, .. } => {
                    held.retain(|held_key| *held_key != key);
                }
                _ => {}
            }
        }
    }
    fn set_parameter(&mut self, _: u32, _: f32) {}
    fn get_parameter(&self, _: u32) -> f32 {
        0.0
    }
    fn apply_automation(&mut self, _: u32, _: f32) {}
    fn clear_automation(&mut self, _: u32) {}
    fn default_parameters(&self) -> karbeat_plugin_api::traits::HashMap<u32, f32> {
        karbeat_plugin_api::traits::HashMap::new()
    }
    fn static_parameter_specs() -> Vec<karbeat_plugin_api::prelude::ParameterSpec> {
        Vec::new()
    }
    fn get_parameter_specs(&self) -> Vec<karbeat_plugin_api::prelude::ParameterSpec> {
        Vec::new()
    }
    fn as_any(&self) -> &dyn std::any::Any {
        self
    }
}

struct PatternRig {
    engine: AudioEngine,
    app_state: ApplicationState,
    track_id: crate::shared::TrackId,
    pattern_id: crate::shared::PatternId,
    generator_id: crate::shared::GeneratorId,
    held: std::sync::Arc<std::sync::Mutex<Vec<u8>>>,
}

impl PatternRig {
    /// A pattern with one long note on `key`, played by a recording generator.
    fn new(key: u8) -> Self {
        use crate::core::project::track::midi::Pattern;

        let (_, command_consumer) = RingBuffer::<AudioCommand>::new(32);
        let (position_producer, _) = RingBuffer::<TransportFeedback>::new(256);
        let (feedback_producer, _) = RingBuffer::<AudioFeedback>::new(32);
        let (telemetry_sender, _) = mpsc::sync_channel::<TelemetryRegistration>(32);
        let mut engine = AudioEngine::new(
            command_consumer,
            position_producer,
            feedback_producer,
            48_000,
            2,
            120.0,
            64,
            AudioEngineTelemetry::new_for_export(),
            telemetry_sender,
        );
        let mut app_state = ApplicationState::default();
        let track_id = app_state.tracks.insert_with_key(|id| {
            AudioTrack::new(id, "Synth", Color::new_from_rgb(0, 0, 0), TrackType::Midi)
        });
        let pattern_id = app_state.pattern_pool.insert_with_key(|id| Pattern {
            id,
            ..Pattern::default()
        });
        app_state.pattern_pool[pattern_id]
            .add_note(key, 0, Some(960 * 8))
            .expect("valid note");
        engine.process_command(AudioCommand::ReplaceFullGraph {
            graph: AudioGraphState::from(&app_state),
        });
        let held = std::sync::Arc::new(std::sync::Mutex::new(Vec::new()));
        let generator_id = crate::shared::GeneratorId::from(1);
        engine.process_command(AudioCommand::InstallGenerator {
            generator_id,
            track_id,
            registry_id: 0,
            plugin: Box::new(HeldKeysRecorder(held.clone())),
            telemetry: None,
        });
        Self {
            engine,
            app_state,
            track_id,
            pattern_id,
            generator_id,
            held,
        }
    }

    fn play(&mut self) {
        self.engine
            .process_command(AudioCommand::TogglePatternPlayback {
                pattern_id: self.pattern_id,
                generator_id: self.generator_id,
            });
    }

    fn render(&mut self, blocks: usize) {
        let mut block = vec![0.0_f32; 128];
        for _ in 0..blocks {
            self.engine.process(&mut block);
        }
    }

    /// Publishes the edited project the way note edits reach the audio thread.
    fn publish(&mut self) {
        let graph = AudioGraphState::from(&self.app_state);
        self.engine.process_command(AudioCommand::UpdateTrackGraph {
            tracks: graph.tracks,
            clips: graph.clips,
            patterns: graph.patterns,
        });
    }

    fn held(&self) -> Vec<u8> {
        self.held.lock().expect("recorder lock").clone()
    }
}

#[test]
fn moving_a_sounding_note_releases_the_key_it_was_holding() {
    let mut rig = PatternRig::new(60);
    rig.play();
    rig.render(2);
    assert_eq!(rig.held(), [60]);

    // Drag the sounding note up to 64 while the pattern plays.
    let note_id = rig.app_state.pattern_pool[rig.pattern_id].notes[0].id;
    rig.app_state.pattern_pool[rig.pattern_id]
        .notes
        .iter_mut()
        .find(|note| note.id == note_id)
        .expect("note")
        .key = 64;
    rig.publish();
    rig.render(1);
    assert!(
        rig.held().is_empty(),
        "old key still held: {:?}",
        rig.held()
    );

    rig.engine
        .process_command(AudioCommand::StopPatternPlayback);
    rig.render(1);
    assert!(rig.held().is_empty());
    assert!(
        rig.engine
            .voices
            .active_generators
            .iter()
            .all(|voice| voice.playing_notes.is_empty())
    );
}

#[test]
fn releases_queued_while_a_track_is_muted_reach_the_generator_later() {
    let mut rig = PatternRig::new(60);
    rig.play();
    rig.render(2);
    assert_eq!(rig.held(), [60]);

    rig.engine
        .mixer_state
        .track_channels
        .entry(rig.track_id)
        .or_default()
        .mute = true;
    rig.engine
        .process_command(AudioCommand::StopPatternPlayback);
    rig.render(3);
    // The muted generator has not run, so it still holds the note, and so does tracking.
    assert_eq!(rig.held(), [60]);

    rig.engine
        .mixer_state
        .track_channels
        .entry(rig.track_id)
        .or_default()
        .mute = false;
    rig.render(1);
    assert!(rig.held().is_empty(), "note hung: {:?}", rig.held());
}

#[test]
fn update_audio_source_swaps_only_that_waveform() {
    use crate::core::project::{AudioWaveform, Fade, GainEnvelope};
    use std::sync::Arc;

    let (_, cmd_consumer) = RingBuffer::<AudioCommand>::new(32);
    let (pos_producer, _) = RingBuffer::<TransportFeedback>::new(32);
    let (fb_producer, _) = RingBuffer::<AudioFeedback>::new(32);
    let (telemetry_tx, _) = mpsc::sync_channel::<TelemetryRegistration>(32);
    let mut engine = AudioEngine::new(
        cmd_consumer,
        pos_producer,
        fb_producer,
        48_000,
        2,
        120.0,
        64,
        AudioEngineTelemetry::new_for_export(),
        telemetry_tx,
    );

    let mut app = ApplicationState::default();
    let id = app.asset_library.source_map.insert_with_key(|id| {
        Arc::new(AudioWaveform {
            id: Some(id),
            ..AudioWaveform::default()
        })
    });
    engine.process_command(AudioCommand::ReplaceFullGraph {
        graph: AudioGraphState::from(&app),
    });

    app.set_audio_source_envelope(
        id,
        GainEnvelope {
            fade_out: Fade {
                length: 32,
                ..Fade::default()
            },
            ..GainEnvelope::default()
        },
    )
    .expect("set envelope");
    let updated = Arc::clone(&app.asset_library.source_map[id]);
    engine.process_command(AudioCommand::UpdateAudioSource {
        id,
        waveform: Arc::clone(&updated),
    });

    let rendered = &engine.current_state.graph.asset_library.source_map[id];
    assert!(Arc::ptr_eq(rendered, &updated));
    assert_eq!(rendered.envelope.fade_out.length, 32);

    // Sources the render graph does not know are ignored rather than inserted.
    let unknown = app
        .asset_library
        .source_map
        .insert(Arc::new(AudioWaveform::default()));
    engine.process_command(AudioCommand::UpdateAudioSource {
        id: unknown,
        waveform: Arc::new(AudioWaveform::default()),
    });
    assert!(
        !engine
            .current_state
            .graph
            .asset_library
            .source_map
            .contains_key(unknown)
    );
}
