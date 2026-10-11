//! Opt-in LSP compatibility tests. LSP ships its LV2 bundle for Linux:
//! LSP_LV2_PATH=/usr/lib64/lv2/lsp-plugins.lv2 cargo test -p karbeat-lv2 --test lsp -- --ignored --test-threads=1
//!
//! Set LSP_TEST_EDITOR=1 to also open the compressor's X11 editor, which needs a display.
//!
//! The suite is compiled only on Linux; other platforms build an empty `main` because this
//! target runs without the libtest harness.

fn main() {
    #[cfg(target_os = "linux")]
    lsp::main();
}

#[cfg(target_os = "linux")]
#[path = "support/x11_editor.rs"]
mod x11_editor;

#[cfg(target_os = "linux")]
#[allow(
    clippy::unwrap_used,
    clippy::panic,
    reason = "integration test setup failures should fail the test"
)]
mod lsp {
    use karbeat_host_api::{
        HostInstanceId, PluginController, PluginDescriptor, PluginInstanceManager, PluginKind,
        ProcessingConfig,
    };
    use karbeat_lv2::{Lv2PluginHost, world};
    use karbeat_plugin_api::prelude::AudioPlugin;
    use karbeat_plugin_api::types::{AudioBuffers, AudioBusBuffer, ProcessContext, ProcessingMode};
    use std::path::PathBuf;

    const BLOCK: usize = 256;
    const BLOCKS: usize = 64;
    const SIDECHAIN_COMPRESSOR: &str = "http://lsp-plug.in/plugins/lv2/sc_compressor_stereo";
    const CLIPPER: &str = "http://lsp-plug.in/plugins/lv2/clipper_stereo";

    fn config(kind: PluginKind, max_block_size: usize) -> ProcessingConfig {
        ProcessingConfig {
            sample_rate: 48_000.0,
            max_block_size,
            main_input_channels: if kind == PluginKind::Instrument { 0 } else { 2 },
            main_output_channels: 2,
            sidechain_channels: 2,
            offline: false,
        }
    }

    /// Renders a steady tone through the main input and an optional loud sidechain, returning
    /// the output energy of the final block.
    fn render(processor: &mut dyn AudioPlugin, sidechain: bool) -> f64 {
        let mut energy = 0.0;
        for block in 0..BLOCKS {
            let phase = |index: usize| {
                let sample = f64::from(u32::try_from(block * BLOCK + index).unwrap());
                #[allow(
                    clippy::as_conversions,
                    clippy::cast_possible_truncation,
                    reason = "test tone"
                )]
                let value = (sample * 440.0 * std::f64::consts::TAU / 48_000.0).sin() as f32;
                value * 0.25
            };
            let mut in_l: Vec<f32> = (0..BLOCK).map(phase).collect();
            let mut in_r = in_l.clone();
            let level = if sidechain { 1.0 } else { 0.0 };
            let mut side_l = vec![level; BLOCK];
            let mut side_r = vec![level; BLOCK];
            let mut out_l = vec![0.0; BLOCK];
            let mut out_r = vec![0.0; BLOCK];
            let mut main_channels: [&mut [f32]; 2] = [&mut in_l, &mut in_r];
            let mut side_channels: [&mut [f32]; 2] = [&mut side_l, &mut side_r];
            let mut out_channels: [&mut [f32]; 2] = [&mut out_l, &mut out_r];
            let mut main = [AudioBusBuffer {
                channel_data: &mut main_channels,
                is_silent: false,
            }];
            let mut side = [AudioBusBuffer {
                channel_data: &mut side_channels,
                is_silent: !sidechain,
            }];
            let mut output = [AudioBusBuffer {
                channel_data: &mut out_channels,
                is_silent: false,
            }];
            let context = ProcessContext {
                bpm: 120.0,
                time_sig_numerator: 4,
                time_sig_denominator: 4,
                is_playing: true,
                is_recording: false,
                mode: ProcessingMode::Realtime,
                project_time_seconds: 0.0,
                project_time_samples: u64::try_from(block * BLOCK).unwrap(),
                beat_position: 0.0,
                bar_position: 0.0,
                loop_start_beat: None,
                loop_end_beat: None,
                midi_events: &[],
                param_changes: &[],
            };
            processor.process(
                &mut AudioBuffers {
                    main_inputs: &mut main,
                    main_outputs: &mut output,
                    aux_inputs: &mut side,
                    aux_outputs: &mut [],
                },
                &context,
            );
            energy = out_l
                .iter()
                .chain(&out_r)
                .map(|sample| {
                    assert!(sample.is_finite(), "non-finite output sample");
                    f64::from(sample.abs())
                })
                .sum();
        }
        energy
    }

    fn run(
        host: &mut Lv2PluginHost,
        descriptor: &PluginDescriptor,
        sidechain: bool,
    ) -> Result<(HostInstanceId, f64), String> {
        let id = host
            .create(descriptor)
            .map_err(|e| format!("create: {e}"))?;
        let result: Result<f64, String> = (|| {
            host.prepare(id, &config(descriptor.kind, BLOCK))
                .map_err(|e| format!("prepare: {e}"))?;
            let mut processor = host
                .take_processor(id)
                .map_err(|e| format!("take_processor: {e}"))?;
            host.resume(id).map_err(|e| format!("resume: {e}"))?;
            let energy = render(processor.as_mut(), sidechain);
            host.suspend(id).map_err(|e| format!("suspend: {e}"))?;
            if let Some(error) = processor.processing_error() {
                return Err(format!("process: {error}"));
            }
            drop(processor);
            Ok(energy)
        })();
        let destroyed = host.destroy(id).map_err(|e| format!("destroy: {e}"));
        let energy = result?;
        destroyed?;
        Ok((id, energy))
    }

    /// Drives the clipper 24 dB into its ceiling with both protection stages switched off,
    /// making those edits either while no audio runs (the host flushes them) or while it does,
    /// and returns the output energy of the final block.
    fn clipped_energy(
        host: &mut Lv2PluginHost,
        descriptor: &PluginDescriptor,
        idle_edit: bool,
    ) -> f64 {
        let id = host.create(descriptor).unwrap();
        host.prepare(id, &config(descriptor.kind, BLOCK)).unwrap();
        let edits = clipper_edits(host, id);
        let mut processor = host.take_processor(id).unwrap();
        assert!(
            processor.latency_samples() > 0,
            "the clipper's lookahead must be known before the first audio block"
        );
        if idle_edit {
            for (parameter, value) in edits {
                host.set_parameter(id, parameter, value).unwrap();
            }
            host.flush_parameters(id).unwrap();
            host.resume(id).unwrap();
        } else {
            host.resume(id).unwrap();
            for (parameter, value) in edits {
                host.set_parameter(id, parameter, value).unwrap();
            }
        }
        let energy = render(processor.as_mut(), false);
        host.suspend(id).unwrap();
        drop(processor);
        host.destroy(id).unwrap();
        energy
    }

    fn clipper_edits(host: &Lv2PluginHost, id: HostInstanceId) -> [(u32, f64); 3] {
        let parameters = host.parameters(id).unwrap();
        [
            ("Enable input LUFS limitation", 0.0),
            ("Overdrive protection", 0.0),
            ("Clipping threshold", 0.5),
        ]
        .map(|(name, value)| {
            let parameter = parameters.iter().find(|spec| spec.name == name);
            (parameter.unwrap().id, value)
        })
    }

    /// Saves an edited instance and restores it into one prepared with another block size,
    /// which gives the second instance a different URID map.
    fn state_round_trip(host: &mut Lv2PluginHost, descriptor: &PluginDescriptor) {
        let source = host.create(descriptor).unwrap();
        host.prepare(source, &config(descriptor.kind, BLOCK))
            .unwrap();
        for (parameter, value) in clipper_edits(host, source) {
            host.set_parameter(source, parameter, value).unwrap();
        }
        let state = host.save_state(source).unwrap();
        assert!(state.controller.is_none());
        let text = String::from_utf8(state.component.clone()).unwrap();
        assert!(
            text.contains(CLIPPER),
            "state must name the plugin it belongs to"
        );
        let target = host.create(descriptor).unwrap();
        host.prepare(target, &config(descriptor.kind, BLOCK * 2))
            .unwrap();
        host.restore_state(target, &state).unwrap();
        let expected = host.parameters(source).unwrap();
        let restored = host.parameters(target).unwrap();
        assert_eq!(expected.len(), restored.len());
        for (expected, restored) in expected.iter().zip(&restored) {
            assert!(
                (expected.value - restored.value).abs() < 1.0e-5,
                "{} was not restored: {} vs {}",
                expected.name,
                expected.value,
                restored.value
            );
        }
        // The plugin's own properties must survive too, not just the control ports.
        let again = host.save_state(target).unwrap();
        assert_eq!(
            property_lines(&String::from_utf8(again.component).unwrap()),
            property_lines(&text),
            "restoring into another URID map changed the plugin's saved properties"
        );
        let mut foreign = state;
        foreign.identity.native_id = SIDECHAIN_COMPRESSOR.into();
        assert!(host.restore_state(target, &foreign).is_err());
        host.destroy(source).unwrap();
        host.destroy(target).unwrap();
    }

    /// Sorted, trimmed lines of a Turtle state, so two serialisations can be compared without
    /// depending on statement order.
    fn property_lines(text: &str) -> Vec<String> {
        let mut lines = text
            .lines()
            .map(|line| {
                line.trim()
                    .trim_end_matches([';', ',', '.'])
                    .trim()
                    .to_owned()
            })
            .filter(|line| !line.is_empty())
            .collect::<Vec<_>>();
        lines.sort();
        lines
    }

    pub(super) fn main() {
        if std::env::var_os("LSP_LV2_PATH").is_none()
            && !std::env::args().any(|arg| arg == "--ignored")
        {
            return;
        }
        let path = std::env::var_os("LSP_LV2_PATH").map_or_else(
            || PathBuf::from("/usr/lib64/lv2/lsp-plugins.lv2"),
            PathBuf::from,
        );
        let descriptors = world::probe_bundle(&path).unwrap();
        assert!(!descriptors.is_empty(), "no LSP plugins found in {path:?}");
        let mut host = Lv2PluginHost::new();

        let failures = descriptors
            .iter()
            .filter_map(|descriptor| {
                run(&mut host, descriptor, false)
                    .err()
                    .map(|error| format!("{}: {error}", descriptor.name))
            })
            .collect::<Vec<_>>();
        assert!(
            failures.is_empty(),
            "{} of {} LSP plugins failed:\n{}",
            failures.len(),
            descriptors.len(),
            failures.join("\n")
        );

        let find = |uri: &str| {
            descriptors
                .iter()
                .find(|descriptor| descriptor.identity.native_id == uri)
                .unwrap()
        };
        let sidechain = find(SIDECHAIN_COMPRESSOR);
        let probe = host.create(sidechain).unwrap();
        let capabilities = host.capabilities(probe).unwrap();
        assert!(capabilities.sidechain && capabilities.controller && capabilities.editor);
        host.destroy(probe).unwrap();
        let (_, dry) = run(&mut host, sidechain, false).unwrap();
        let (_, keyed) = run(&mut host, sidechain, true).unwrap();
        assert!(dry > 0.0, "sidechain compressor must pass the main signal");
        assert!(
            keyed < dry,
            "a loud sidechain must reduce the output: dry {dry}, keyed {keyed}"
        );

        // LV2 plugins read control ports only inside `run`, so edits made while the plugin's
        // channel is idle reach it through the host's flush block.
        let clipper = find(CLIPPER);
        let (_, untouched) = run(&mut host, clipper, false).unwrap();
        let live = clipped_energy(&mut host, clipper, false);
        let idle = clipped_energy(&mut host, clipper, true);
        assert!(
            live > untouched * 2.0,
            "edits made during playback must drive the clipper: {untouched} -> {live}"
        );
        assert!(
            (idle - live).abs() < live * 0.05,
            "edits made while idle must match edits made during playback: {idle} vs {live}"
        );

        state_round_trip(&mut host, clipper);

        if std::env::var_os("LSP_TEST_EDITOR").is_some() {
            let id = host.create(sidechain).unwrap();
            host.prepare(id, &config(sidechain.kind, BLOCK)).unwrap();
            let mut processor = host.take_processor(id).unwrap();
            host.resume(id).unwrap();
            super::x11_editor::exercise_editor(&mut host, id, &mut || {
                render(processor.as_mut(), false);
            });
            host.suspend(id).unwrap();
            drop(processor);
            host.destroy(id).unwrap();
            drop(host);
            super::x11_editor::exercise_native_editor(
                sidechain.clone(),
                config(sidechain.kind, BLOCK),
            );
        }
    }
}
