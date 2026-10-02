//! Opt-in LSP compatibility tests. LSP ships its VST3 bundle only for Linux:
//! LSP_VST3_PATH=/usr/lib64/vst3/lsp-plugins.vst3 cargo test -p karbeat-vst3 --test lsp -- --ignored --test-threads=1
//!
//! The suite is compiled only on Linux; other platforms build an empty `main` because this
//! target runs without the libtest harness.

fn main() {
    #[cfg(target_os = "linux")]
    lsp::main();
}

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
    use karbeat_plugin_api::prelude::AudioPlugin;
    use karbeat_plugin_api::types::{AudioBuffers, AudioBusBuffer, ProcessContext, ProcessingMode};
    use karbeat_vst3::{Vst3PluginHost, module::Vst3Module};
    use std::path::PathBuf;

    const BLOCK: usize = 256;
    const BLOCKS: usize = 64;

    fn config(kind: PluginKind) -> ProcessingConfig {
        ProcessingConfig {
            sample_rate: 48_000.0,
            max_block_size: BLOCK,
            main_input_channels: if kind == PluginKind::Instrument { 0 } else { 2 },
            main_output_channels: 2,
            sidechain_channels: 2,
            offline: false,
        }
    }

    /// Renders a steady tone through the main input and an optional pulsing sidechain, returning
    /// the output energy of the final block.
    fn render(processor: &mut dyn AudioPlugin, sidechain: bool) -> f64 {
        let mut energy = 0.0;
        for block in 0..BLOCKS {
            let phase = |index: usize| {
                let sample = f64::from(u32::try_from(block * BLOCK + index).unwrap());
                #[allow(clippy::cast_possible_truncation, reason = "test tone")]
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
        host: &mut Vst3PluginHost,
        descriptor: &PluginDescriptor,
        sidechain: bool,
    ) -> Result<(HostInstanceId, f64), String> {
        let id = host
            .create(descriptor)
            .map_err(|e| format!("create: {e}"))?;
        let result: Result<f64, String> = (|| {
            host.prepare(id, &config(descriptor.kind))
                .map_err(|e| format!("prepare: {e}"))?;
            let mut processor = host
                .take_processor(id)
                .map_err(|e| format!("take_processor: {e}"))?;
            host.resume(id).map_err(|e| format!("resume: {e}"))?;
            let energy = render(processor.as_mut(), sidechain);
            host.suspend(id).map_err(|e| format!("suspend: {e}"))?;
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
        host: &mut Vst3PluginHost,
        descriptor: &PluginDescriptor,
        idle_edit: bool,
    ) -> f64 {
        let id = host.create(descriptor).unwrap();
        host.prepare(id, &config(descriptor.kind)).unwrap();
        let parameters = host.parameters(id).unwrap();
        let edits = [
            ("Enable input LUFS limitation", 0.0),
            ("Overdrive protection", 0.0),
            ("Clipping threshold", 0.5),
        ]
        .map(|(name, value)| {
            let parameter = parameters.iter().find(|spec| spec.name == name);
            (parameter.unwrap().id, value)
        });
        // The native owner captures state before publishing an endpoint, which flushes once.
        host.save_state(id).unwrap();
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

    pub(super) fn main() {
        if std::env::var_os("LSP_VST3_PATH").is_none()
            && !std::env::args().any(|arg| arg == "--ignored")
        {
            return;
        }
        let path = std::env::var_os("LSP_VST3_PATH").map_or_else(
            || PathBuf::from("/usr/lib64/vst3/lsp-plugins.vst3"),
            PathBuf::from,
        );
        let descriptors = Vst3Module::load(&path).unwrap().descriptors().unwrap();
        assert!(!descriptors.is_empty(), "no LSP classes found in {path:?}");
        let mut host = Vst3PluginHost::new();

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
            "{} of {} LSP classes failed:\n{}",
            failures.len(),
            descriptors.len(),
            failures.join("\n")
        );

        let sidechain = descriptors
            .iter()
            .find(|descriptor| descriptor.name == "Sidechain Compressor Stereo")
            .unwrap();
        let probe = host.create(sidechain).unwrap();
        assert!(host.capabilities(probe).unwrap().sidechain);
        host.destroy(probe).unwrap();
        let (_, dry) = run(&mut host, sidechain, false).unwrap();
        let (_, keyed) = run(&mut host, sidechain, true).unwrap();
        assert!(dry > 0.0, "sidechain compressor must pass the main signal");
        assert!(
            keyed < dry,
            "a loud sidechain must reduce the output: dry {dry}, keyed {keyed}"
        );

        // LSP reads parameter queues only while rendering frames, so a zero-sample flush
        // would lose every edit made while the plugin's channel is idle.
        let clipper = descriptors
            .iter()
            .find(|descriptor| descriptor.name == "Clipper Stereo")
            .unwrap();
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
    }
}
