//! Opt in with VITAL_VST3_PATH or `cargo test -p karbeat-core --test vst3_core -- --ignored`.
#![allow(
    clippy::unwrap_used,
    clippy::panic,
    reason = "integration test assertions"
)]

use karbeat_core::{
    api::{audio_api, audio_settings_api, external_plugin_api, project_api, track_api},
    audio::engine::{AudioEngine, AudioEngineTelemetry},
    context::DawContext,
    message::TelemetryRegistry,
};
use karbeat_host::PluginDescriptor;
use karbeat_vst3::module::Vst3Module;
use std::{
    sync::{
        Arc,
        atomic::{AtomicBool, Ordering},
    },
    time::{Duration, Instant},
};

fn workflow(descriptor: PluginDescriptor) {
    let mut ctx = DawContext::new();
    ctx.audio_runtime_settings.write().requested_dsp.sample_rate = 48_000;
    let (sender, commands) = rtrb::RingBuffer::new(256);
    let (feedback, responses) = rtrb::RingBuffer::new(256);
    let (position, _positions) = rtrb::RingBuffer::new(256);
    let (registration, _registrations) = std::sync::mpsc::sync_channel(256);
    let (telemetry, output) = AudioEngineTelemetry::new();
    ctx.telemetry_registry = Some(TelemetryRegistry::new(output));
    *ctx.command_sender.lock() = Some(sender);
    *ctx.feedback_consumer.lock() = Some(responses);
    let stop = Arc::new(AtomicBool::new(false));
    let audible = Arc::new(AtomicBool::new(false));
    let audio_stop = stop.clone();
    let audio_audible = audible.clone();
    let audio = std::thread::spawn(move || {
        let mut engine = AudioEngine::new(
            commands,
            position,
            feedback,
            48_000,
            2,
            120.0,
            512,
            telemetry,
            registration,
        );
        let mut block = [0.0_f32; 256];
        while !audio_stop.load(Ordering::Acquire) {
            engine.process(block.as_mut_slice());
            assert!(block.iter().all(|sample| sample.is_finite()));
            if block.iter().any(|sample| sample.abs() > 0.000001) {
                audio_audible.store(true, Ordering::Release);
            }
            std::thread::sleep(Duration::from_millis(1));
        }
    });
    let result = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        ctx.plugin_catalog.merge([descriptor.clone()]);
        let registry = ctx.plugin_catalog.resolve(&descriptor.identity).unwrap().id;
        let first = track_api::add_midi_track_with_generator_id(&mut ctx, registry).unwrap();
        let second = track_api::add_midi_track_with_generator_id(&mut ctx, registry).unwrap();
        let target = karbeat_core::audio::event::PluginTarget::Generator(
            first.generator.as_ref().unwrap().id,
        );
        assert!(
            external_plugin_api::capabilities(&mut ctx, target)
                .unwrap()
                .controller
        );
        audio_api::play_preview_note(&mut ctx, first.id, 60, 100, true).unwrap();
        let deadline = Instant::now() + Duration::from_secs(5);
        while !audible.load(Ordering::Acquire) && Instant::now() < deadline {
            std::thread::sleep(Duration::from_millis(2));
        }
        assert!(
            audible.load(Ordering::Acquire),
            "Vital did not reach the core mixer"
        );
        audio_api::play_preview_note(&mut ctx, first.id, 60, 0, false).unwrap();
        let settings = audio_settings_api::set_dsp_config(&mut ctx, 96_000, 256).unwrap();
        assert_eq!(settings.requested_dsp.sample_rate, 96_000);
        audible.store(false, Ordering::Release);
        audio_api::play_preview_note(&mut ctx, first.id, 64, 100, true).unwrap();
        let deadline = Instant::now() + Duration::from_secs(5);
        while !audible.load(Ordering::Acquire) && Instant::now() < deadline {
            std::thread::sleep(Duration::from_millis(2));
        }
        assert!(
            audible.load(Ordering::Acquire),
            "Vital did not resume audio at the updated DSP sample rate"
        );
        audio_api::play_preview_note(&mut ctx, first.id, 64, 0, false).unwrap();
        let directory = tempfile::tempdir().unwrap();
        let path = directory.path().join("vital.digidaw");
        project_api::save_project(&mut ctx, path.to_str().unwrap()).unwrap();
        let mut loaded =
            karbeat_core::core::file_manager::project_loader::load_daw_project(&path, 48_000)
                .unwrap();
        assert_eq!(loaded.generator_pool.len(), 2);
        for (_, generator) in &loaded.generator_pool {
            let karbeat_core::core::project::GeneratorInstanceType::Plugin(plugin) =
                &generator.instance_type
            else {
                panic!("Wrong generator type");
            };
            let external = plugin.external.as_ref().unwrap();
            assert_eq!(external.descriptor.identity, descriptor.identity);
            assert!(!external.state.as_ref().unwrap().component.is_empty());
        }
        project_api::load_project(&mut ctx, path.to_str().unwrap(), |_| ()).unwrap();
        assert!(ctx.external_plugin_failures.is_empty());
        let parameter = match &ctx
            .app_state
            .generator_pool
            .get(first.generator.as_ref().unwrap().id)
            .unwrap()
            .instance_type
        {
            karbeat_core::core::project::GeneratorInstanceType::Plugin(plugin) => {
                plugin.parameter_specs[0].id
            }
            _ => panic!("Wrong generator type"),
        };
        let text = external_plugin_api::parameter_text(&mut ctx, target, parameter, 0.5).unwrap();
        assert!(!text.is_empty());
        match external_plugin_api::parse_parameter(&mut ctx, target, parameter, text) {
            Ok(parsed) => assert!((0.0..=1.0).contains(&parsed)),
            Err(error) => assert!(matches!(
                error.downcast_ref::<karbeat_host::HostError>(),
                Some(karbeat_host::HostError::InvalidParameter(_))
            )),
        }
        let plain = external_plugin_api::convert_parameter(&mut ctx, target, parameter, 0.5, false)
            .unwrap();
        assert!(
            external_plugin_api::convert_parameter(&mut ctx, target, parameter, plain, true)
                .unwrap()
                .is_finite()
        );
        assert!(
            external_plugin_api::parse_parameter(&mut ctx, target, parameter, "x".repeat(128))
                .is_err()
        );
        assert!(
            external_plugin_api::parameter_text(&mut ctx, target, parameter, f64::NAN).is_err()
        );
        track_api::delete_track(&mut ctx, first.id).unwrap();
        assert!(ctx.app_state.tracks.get(first.id).is_none());
        assert_eq!(ctx.app_state.generator_pool.len(), 1);
        audio_api::play_preview_note(&mut ctx, second.id, 64, 100, true).unwrap();
        track_api::delete_track(&mut ctx, second.id).unwrap();
        assert!(ctx.app_state.generator_pool.is_empty());
        let original_states: Vec<_> = loaded
            .generator_pool
            .values()
            .filter_map(|generator| {
                if let karbeat_core::core::project::GeneratorInstanceType::Plugin(plugin) =
                    &generator.instance_type
                {
                    plugin
                        .external
                        .as_ref()
                        .and_then(|external| external.state.clone())
                } else {
                    None
                }
            })
            .collect();
        for (_, generator) in &mut loaded.generator_pool {
            if let karbeat_core::core::project::GeneratorInstanceType::Plugin(plugin) =
                &mut generator.instance_type
            {
                plugin.external.as_mut().unwrap().descriptor.path =
                    directory.path().join("Absent.vst3");
            }
        }
        ctx.plugin_catalog.mark_missing(&descriptor.identity);
        karbeat_core::core::file_manager::project_loader::save_daw_project(&path, &loaded).unwrap();
        project_api::load_project(&mut ctx, path.to_str().unwrap(), |_| ()).unwrap();
        assert_eq!(ctx.external_plugin_failures.len(), 2);
        assert!(external_plugin_api::capabilities(&mut ctx, target).is_err());
        project_api::save_project(&mut ctx, path.to_str().unwrap()).unwrap();
        let missing_saved =
            karbeat_core::core::file_manager::project_loader::load_daw_project(&path, 48_000)
                .unwrap();
        let stored_states: Vec<_> = missing_saved
            .generator_pool
            .values()
            .filter_map(|generator| {
                if let karbeat_core::core::project::GeneratorInstanceType::Plugin(plugin) =
                    &generator.instance_type
                {
                    plugin
                        .external
                        .as_ref()
                        .and_then(|external| external.state.clone())
                } else {
                    None
                }
            })
            .collect();
        assert_eq!(stored_states, original_states);
        track_api::delete_track(&mut ctx, first.id).unwrap();
        assert_eq!(ctx.external_plugin_failures.len(), 1);
        ctx.plugin_catalog.merge([descriptor]);
        let second_target = karbeat_core::audio::event::PluginTarget::Generator(
            second.generator.as_ref().unwrap().id,
        );
        external_plugin_api::retry(&mut ctx, second_target).unwrap();
        assert!(ctx.external_plugin_failures.is_empty());
        audible.store(false, Ordering::Release);
        audio_api::play_preview_note(&mut ctx, second.id, 67, 100, true).unwrap();
        let deadline = Instant::now() + Duration::from_secs(5);
        while !audible.load(Ordering::Acquire) && Instant::now() < deadline {
            std::thread::sleep(Duration::from_millis(2));
        }
        assert!(
            audible.load(Ordering::Acquire),
            "Recovered Vital did not reach the core mixer"
        );
        project_api::new_blank_project(&mut ctx).unwrap();
        assert!(ctx.app_state.generator_pool.is_empty());
    }));
    stop.store(true, Ordering::Release);
    audio.join().unwrap();
    if let Err(error) = result {
        std::panic::resume_unwind(error);
    }
}

fn main() {
    if std::env::var_os("VITAL_VST3_PATH").is_none()
        && !std::env::args().any(|arg| arg == "--ignored")
    {
        return;
    }
    let path = std::env::var_os("VITAL_VST3_PATH")
        .map(std::path::PathBuf::from)
        .unwrap_or_else(|| "/usr/lib/vst3/Vital.vst3".into());
    let descriptor = Vst3Module::load(&path)
        .unwrap()
        .descriptors()
        .unwrap()
        .into_iter()
        .find(|plugin| plugin.name == "Vital")
        .unwrap();
    let worker = std::thread::spawn(move || workflow(descriptor));
    let context = glib::MainContext::default();
    let deadline = Instant::now() + Duration::from_secs(90);
    while !worker.is_finished() {
        assert!(Instant::now() < deadline, "Core workflow timed out");
        context.iteration(false);
        std::thread::sleep(Duration::from_millis(1));
    }
    worker.join().unwrap();
    for _ in 0..5 {
        context.iteration(false);
    }
}
