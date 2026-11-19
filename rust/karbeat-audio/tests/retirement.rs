//! Everything the audio thread lets go of is destroyed off it, without leaking.
//!
//! Its own test binary, because the leak counter is process-wide: tests elsewhere in the crate
//! leak on purpose to exercise shutdown ordering.
#![allow(clippy::unwrap_used, reason = "the test fails as soon as a step fails")]

use std::{sync::mpsc::sync_channel, thread::spawn, time::Duration};

use hashbrown::HashSet;
use karbeat_audio::{
    commands::{AudioCommand, EffectTarget, PreparedPluginTelemetry, retiring},
    engine::{AudioEngine, AudioEngineTelemetry, MetronomeClick},
    event::PluginTarget,
    render_state::{AudioGraphState, retiring_plugin},
};
use karbeat_core::{core::project::ApplicationState, shared::EffectId};
use karbeat_host::retire::{RetirementService, leaked_objects, mark_realtime_thread};
use karbeat_plugin_api::traits::AudioPluginBuilder;
use karbeat_plugins::effect::delay::DigidawDelay;

const RATE: u32 = 48_000;
const BLOCK: usize = 256;

fn install_effect(id: u32) -> AudioCommand {
    let plugin: Box<dyn karbeat_plugin_api::traits::AudioPlugin> = Box::new(DigidawDelay::build());
    let telemetry = PreparedPluginTelemetry::new(plugin.as_ref());
    AudioCommand::InstallEffect {
        target: EffectTarget::Master,
        effect_id: EffectId::from(id),
        registry_id: 0,
        plugin: retiring_plugin(plugin),
        telemetry: Some(telemetry),
    }
}

#[test]
fn an_engine_retires_everything_it_replaced_and_dropped_without_leaks() {
    let (_commands, consumer) = rtrb::RingBuffer::new(16);
    let (positions, _positions) = rtrb::RingBuffer::new(256);
    let (feedback, _feedback) = rtrb::RingBuffer::new(256);
    let (registrations, _registered) = sync_channel(256);
    let (telemetry, _mixer) = AudioEngineTelemetry::new();
    let mut engine = AudioEngine::new(
        consumer,
        positions,
        feedback,
        RATE,
        2,
        120.0,
        BLOCK,
        telemetry,
        registrations,
    );
    let graph = || AudioGraphState::from(&ApplicationState::default());
    let commands = vec![
        AudioCommand::ReplaceFullGraph {
            graph: retiring(graph()),
        },
        install_effect(1),
        install_effect(2),
        AudioCommand::SetPluginTelemetrySubscription {
            target: PluginTarget::MasterEffect(EffectId::from(1)),
            buffers: retiring(HashSet::from(["spectrum".to_owned()])),
            active: true,
        },
        AudioCommand::SetMetronomeClick(Some(retiring(MetronomeClick {
            downbeat: vec![1.0; 64],
            offbeat: vec![0.5; 64],
            sample_rate: RATE,
        }))),
        AudioCommand::UpdateRouting {
            routing: retiring(Box::new([])),
        },
        AudioCommand::RemoveEffect {
            target: EffectTarget::Master,
            effect_id: EffectId::from(1),
        },
        AudioCommand::SetMetronomeClick(None),
        AudioCommand::ReplaceFullGraph {
            graph: retiring(graph()),
        },
    ];
    let leaks_before = leaked_objects();

    // The engine runs and is dropped on a real-time thread, as in the device backend.
    spawn(move || {
        mark_realtime_thread();
        let mut block = vec![0.0_f32; BLOCK * 2];
        for command in commands {
            engine.process_command(command);
            engine.process(&mut block);
        }
        drop(engine);
    })
    .join()
    .unwrap();

    let service = RetirementService::global();
    assert!(service.drain_all(Duration::from_secs(5)));
    assert_eq!(service.queued(), 0);
    assert_eq!(leaked_objects(), leaks_before);
    assert_eq!(leaks_before, 0);
}
