//! Opt-in full-stack LV2 test: engine thread, native host, project save and load.
//! cargo test -p karbeat-core-api --test lv2_core -- --ignored
//!
//! Uses mda DX10 and LSP Clipper from `MDA_LV2_PATH` / `LSP_LV2_PATH`, and LSP's VST3 clipper
//! from `LSP_VST3_PATH` when it is installed, to run both formats side by side.
//!
//! LV2 hosting exists on Linux only; other platforms build an empty `main` because this target
//! runs without the libtest harness.

fn main() {
    #[cfg(target_os = "linux")]
    lv2::main();
}

#[cfg(target_os = "linux")]
#[allow(
    clippy::unwrap_used,
    clippy::panic,
    reason = "integration test assertions"
)]
mod lv2 {
    use karbeat_core::{
        audio::{
            engine::{AudioEngine, AudioEngineTelemetry},
            event::PluginTarget,
        },
        commands::EffectTarget,
        context::DawContext,
        core::project::GeneratorInstanceType,
        message::TelemetryRegistry,
    };
    use karbeat_core_api::{
        audio_api, audio_settings_api, external_plugin_api, project_api, track_api,
    };
    use karbeat_host::{HostError, PluginDescriptor, PluginFormat};
    use std::{
        path::PathBuf,
        sync::{
            Arc,
            atomic::{AtomicBool, Ordering},
        },
        time::{Duration, Instant},
    };

    const DX10: &str = "http://drobilla.net/plugins/mda/DX10";
    const CLIPPER: &str = "http://lsp-plug.in/plugins/lv2/clipper_stereo";

    struct Plugins {
        instrument: PluginDescriptor,
        effect: PluginDescriptor,
        vst3_effect: Option<PluginDescriptor>,
    }

    fn wait_audible(audible: &AtomicBool, what: &str) {
        let deadline = Instant::now() + Duration::from_secs(5);
        while !audible.load(Ordering::Acquire) && Instant::now() < deadline {
            std::thread::sleep(Duration::from_millis(2));
        }
        assert!(audible.load(Ordering::Acquire), "{what}");
    }

    fn hosted_instance(ctx: &DawContext, target: PluginTarget) -> karbeat_host::HostInstanceId {
        let lookup = external_plugin_api::prepare_hosted_target(ctx, target).unwrap();
        external_plugin_api::resolve_hosted_target(lookup)
            .unwrap()
            .instance
            .id
    }

    fn workflow(plugins: Plugins) {
        let host = karbeat_host::PluginHostService::start(
            karbeat_vst3::Vst3Executor,
            karbeat_clap::ClapExecutor,
            karbeat_lv2::Lv2Executor,
        )
        .unwrap();
        let mut ctx = DawContext::with_external_plugins(host);
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
            let instrument = plugins.instrument.clone();
            ctx.plugin_catalog
                .merge([instrument.clone(), plugins.effect.clone()]);
            let registry = ctx.plugin_catalog.resolve(&instrument.identity).unwrap().id;
            let effect_registry = ctx
                .plugin_catalog
                .resolve(&plugins.effect.identity)
                .unwrap()
                .id;
            let first = track_api::add_midi_track_with_generator_id(&mut ctx, registry).unwrap();
            let second = track_api::add_midi_track_with_generator_id(&mut ctx, registry).unwrap();
            let target = PluginTarget::Generator(first.generator.as_ref().unwrap().id);
            let capabilities = external_plugin_api::capabilities(&mut ctx, target).unwrap();
            assert!(capabilities.controller && capabilities.offline);
            audio_api::play_preview_note(&mut ctx, first.id, 60, 100, true).unwrap();
            wait_audible(&audible, "DX10 did not reach the core mixer");
            audio_api::play_preview_note(&mut ctx, first.id, 60, 0, false).unwrap();

            // An LV2 effect after the instrument, and a VST3 one beside it when available.
            let effect = external_plugin_api::add_effect(
                &mut ctx,
                EffectTarget::Track(first.id),
                effect_registry,
            )
            .unwrap();
            let effect_target = PluginTarget::TrackEffect(first.id, effect.id);
            assert!(
                external_plugin_api::capabilities(&mut ctx, effect_target)
                    .unwrap()
                    .editor
            );
            let mut instances = vec![
                hosted_instance(&ctx, target),
                hosted_instance(&ctx, effect_target),
                hosted_instance(
                    &ctx,
                    PluginTarget::Generator(second.generator.as_ref().unwrap().id),
                ),
            ];
            let mut vst3_target = None;
            if let Some(vst3) = &plugins.vst3_effect {
                ctx.plugin_catalog.merge([vst3.clone()]);
                let vst3_registry = ctx.plugin_catalog.resolve(&vst3.identity).unwrap().id;
                let vst3_effect = external_plugin_api::add_effect(
                    &mut ctx,
                    EffectTarget::Track(first.id),
                    vst3_registry,
                )
                .unwrap();
                let other = PluginTarget::TrackEffect(first.id, vst3_effect.id);
                assert_eq!(
                    external_plugin_api::descriptor(&ctx, other)
                        .unwrap()
                        .identity
                        .format,
                    PluginFormat::Vst3
                );
                instances.push(hosted_instance(&ctx, other));
                vst3_target = Some(other);
            }
            let issued = instances.len();
            instances.sort_by_key(|instance| instance.0);
            instances.dedup();
            assert_eq!(
                instances.len(),
                issued,
                "instance IDs must be unique across formats"
            );
            audible.store(false, Ordering::Release);
            audio_api::play_preview_note(&mut ctx, first.id, 62, 100, true).unwrap();
            wait_audible(
                &audible,
                "DX10 did not pass through the hosted effect chain",
            );
            audio_api::play_preview_note(&mut ctx, first.id, 62, 0, false).unwrap();

            let settings = audio_settings_api::set_dsp_config(&mut ctx, 96_000, 256).unwrap();
            assert_eq!(settings.requested_dsp.sample_rate, 96_000);
            audible.store(false, Ordering::Release);
            audio_api::play_preview_note(&mut ctx, first.id, 64, 100, true).unwrap();
            wait_audible(
                &audible,
                "DX10 did not resume audio at the updated DSP sample rate",
            );
            audio_api::play_preview_note(&mut ctx, first.id, 64, 0, false).unwrap();

            let parameter = match &ctx
                .app_state
                .generator_pool
                .get(first.generator.as_ref().unwrap().id)
                .unwrap()
                .instance_type
            {
                GeneratorInstanceType::Plugin(plugin) => plugin.parameter_specs[0].id,
                _ => panic!("Wrong generator type"),
            };
            external_plugin_api::set_parameter(&mut ctx, target, parameter, 0.25).unwrap();
            let directory = tempfile::tempdir().unwrap();
            let path = directory.path().join("lv2.digidaw");
            project_api::save_project(&mut ctx, path.to_str().unwrap()).unwrap();
            let mut loaded =
                karbeat_core::core::file_manager::project_loader::load_daw_project(&path, 48_000)
                    .unwrap();
            assert_eq!(loaded.generator_pool.len(), 2);
            for (_, generator) in &loaded.generator_pool {
                let GeneratorInstanceType::Plugin(plugin) = &generator.instance_type else {
                    panic!("Wrong generator type");
                };
                let external = plugin.external.as_ref().unwrap();
                assert_eq!(external.descriptor.identity, instrument.identity);
                let state = external.state.as_ref().unwrap();
                assert!(
                    String::from_utf8_lossy(&state.component).contains(DX10),
                    "saved state must be the plugin's own Turtle description"
                );
            }
            project_api::load_project(&mut ctx, path.to_str().unwrap(), |_| ()).unwrap();
            assert!(ctx.external_plugin_failures.is_empty());
            // The reloaded project hosts a new native instance; ask it for the live value.
            let reloaded = hosted_instance(&ctx, target);
            let restored =
                futures_lite::future::block_on(karbeat_lv2::native::call(move |owner| {
                    use karbeat_host::PluginController as _;
                    owner.host.parameters(reloaded)
                }))
                .unwrap()
                .into_iter()
                .find(|spec| spec.id == parameter)
                .map(|spec| spec.value)
                .unwrap();
            assert!(
                (restored - 0.25).abs() < 1.0e-4,
                "parameter was not restored with the project: {restored}"
            );
            if let Some(other) = vst3_target {
                assert!(
                    external_plugin_api::capabilities(&mut ctx, other)
                        .unwrap()
                        .controller
                );
            }
            let text =
                external_plugin_api::parameter_text(&mut ctx, target, parameter, 0.5).unwrap();
            assert!(!text.is_empty());
            let parsed =
                external_plugin_api::parse_parameter(&mut ctx, target, parameter, text).unwrap();
            assert!((parsed - 0.5).abs() < 0.01);
            let plain =
                external_plugin_api::convert_parameter(&mut ctx, target, parameter, 0.5, false)
                    .unwrap();
            let normalized =
                external_plugin_api::convert_parameter(&mut ctx, target, parameter, plain, true)
                    .unwrap();
            assert!((normalized - 0.5).abs() < 1.0e-4);
            assert!(matches!(
                external_plugin_api::parse_parameter(&mut ctx, target, parameter, "x".repeat(128))
                    .unwrap_err()
                    .downcast_ref::<HostError>(),
                Some(HostError::InvalidParameter(_))
            ));
            assert!(
                external_plugin_api::parameter_text(&mut ctx, target, parameter, f64::NAN).is_err()
            );
            audible.store(false, Ordering::Release);
            audio_api::play_preview_note(&mut ctx, first.id, 65, 100, true).unwrap();
            wait_audible(&audible, "DX10 did not play after the project was reloaded");
            audio_api::play_preview_note(&mut ctx, first.id, 65, 0, false).unwrap();

            track_api::delete_track(&mut ctx, first.id).unwrap();
            assert!(ctx.app_state.tracks.get(first.id).is_none());
            assert_eq!(ctx.app_state.generator_pool.len(), 1);
            audio_api::play_preview_note(&mut ctx, second.id, 64, 100, true).unwrap();
            track_api::delete_track(&mut ctx, second.id).unwrap();
            assert!(ctx.app_state.generator_pool.is_empty());

            // A project whose plugin has gone missing keeps its saved state and can be retried.
            for (_, generator) in &mut loaded.generator_pool {
                if let GeneratorInstanceType::Plugin(plugin) = &mut generator.instance_type {
                    plugin.external.as_mut().unwrap().descriptor.path =
                        directory.path().join("Absent.lv2");
                }
            }
            ctx.plugin_catalog.mark_missing(&instrument.identity);
            karbeat_core::core::file_manager::project_loader::save_daw_project(&path, &loaded)
                .unwrap();
            project_api::load_project(&mut ctx, path.to_str().unwrap(), |_| ()).unwrap();
            assert_eq!(ctx.external_plugin_failures.len(), 2);
            assert!(external_plugin_api::capabilities(&mut ctx, target).is_err());
            track_api::delete_track(&mut ctx, first.id).unwrap();
            assert_eq!(ctx.external_plugin_failures.len(), 1);
            ctx.plugin_catalog.merge([instrument]);
            let second_target = PluginTarget::Generator(second.generator.as_ref().unwrap().id);
            external_plugin_api::retry(&mut ctx, second_target).unwrap();
            assert!(ctx.external_plugin_failures.is_empty());
            audible.store(false, Ordering::Release);
            audio_api::play_preview_note(&mut ctx, second.id, 67, 100, true).unwrap();
            wait_audible(&audible, "Recovered DX10 did not reach the core mixer");
            project_api::new_blank_project(&mut ctx).unwrap();
            assert!(ctx.app_state.generator_pool.is_empty());
        }));
        stop.store(true, Ordering::Release);
        audio.join().unwrap();
        if let Err(error) = result {
            std::panic::resume_unwind(error);
        }
    }

    fn bundle(variable: &str, default: &str) -> PathBuf {
        std::env::var_os(variable).map_or_else(|| PathBuf::from(default), PathBuf::from)
    }

    fn lv2_plugin(bundle: &std::path::Path, uri: &str) -> PluginDescriptor {
        karbeat_lv2::world::probe_bundle(bundle)
            .unwrap()
            .into_iter()
            .find(|plugin| plugin.identity.native_id == uri)
            .unwrap()
    }

    pub(super) fn main() {
        if !std::env::args().any(|arg| arg == "--ignored") {
            return;
        }
        let vst3 = bundle("LSP_VST3_PATH", "/usr/lib64/vst3/lsp-plugins.vst3");
        let plugins = Plugins {
            instrument: lv2_plugin(&bundle("MDA_LV2_PATH", "/usr/lib64/lv2/mda.lv2"), DX10),
            effect: lv2_plugin(
                &bundle("LSP_LV2_PATH", "/usr/lib64/lv2/lsp-plugins.lv2"),
                CLIPPER,
            ),
            vst3_effect: vst3.exists().then(|| {
                karbeat_vst3::module::Vst3Module::load(&vst3)
                    .unwrap()
                    .descriptors()
                    .unwrap()
                    .into_iter()
                    .find(|plugin| plugin.name == "Clipper Stereo")
                    .unwrap()
            }),
        };
        let worker = std::thread::spawn(move || workflow(plugins));
        let context = glib::MainContext::default();
        let deadline = Instant::now() + Duration::from_secs(180);
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
}
