use rtrb::RingBuffer;
use thiserror::Error;

use crate::{
    audio::engine::{AudioEngine, AudioExportSnapshot},
    audio::writer::{AudioExportConfig, AudioWriter, create_writer},
    commands::AudioCommand,
    context::DawContext,
};
use karbeat_plugins::registry::PluginRegistry;

#[derive(Debug, Clone, Error)]
#[error("Audio export failed ({error_source}): {message}")]
pub struct AudioExportError {
    pub error_source: String,
    pub message: String,
}

impl AudioExportError {
    pub fn new(source: &str, message: impl Into<String>) -> Self {
        Self {
            error_source: source.to_string(),
            message: message.into(),
        }
    }
}

#[derive(Debug, Clone, Default)]
pub enum TailHandling {
    #[default]
    CutRemainder,
    LeaveRemainder,
    WrapRemainder,
}

/// Export project to a sound file based on provided writer
/// Generic, UI-agnostic.
/// `progress_callback` should return `true` to continue, or `false` to abort rendering.
pub fn export_project<F>(
    ctx: &mut DawContext,
    output_path: &str,
    config: AudioExportConfig,
    tail_handling: TailHandling,
    mut progress_callback: F,
) -> Result<(), AudioExportError>
where
    F: FnMut(f32) -> bool + Send,
{
    log::info!("Starting offline render to: {}", output_path);
    let plugin_registry = ctx.plugin_registry.clone();

    let (snapshot_tx, snapshot_rx) = std::sync::mpsc::channel();

    ctx.send_audio_command(AudioCommand::QueryAudioExportSnapshot {
        response_tx: snapshot_tx,
    })
    .map_err(|_| AudioExportError::new("Engine", "Failed to query audio export snapshot"))?;

    let snapshot = snapshot_rx
        .recv_timeout(std::time::Duration::from_secs(30))
        .map_err(|e| {
            AudioExportError::new(
                "QueryExportSnapshotReceiver",
                format!("Failed to receive audio export snapshot: {e}"),
            )
        })?;
    validate_external_plugins(&ctx.app_state, &snapshot)?;
    let output_path = output_path.to_owned();

    std::thread::scope(|scope| {
        scope
            .spawn(move || {
                render_snapshot(
                    snapshot,
                    &output_path,
                    config,
                    tail_handling,
                    plugin_registry,
                    &mut progress_callback,
                )
            })
            .join()
            .map_err(|_| AudioExportError::new("Thread", "Offline render thread panicked"))?
    })
}

fn validate_external_plugins(
    app: &crate::core::project::ApplicationState,
    snapshot: &AudioExportSnapshot,
) -> Result<(), AudioExportError> {
    use crate::{audio::event::PluginTarget, core::project::GeneratorInstanceType};
    let generators =
        app.generator_pool
            .iter()
            .filter_map(|(id, generator)| match &generator.instance_type {
                GeneratorInstanceType::Plugin(instance) => {
                    Some((PluginTarget::Generator(id), instance))
                }
                _ => None,
            });
    let tracks = app.mixer.channels.iter().flat_map(|(track, channel)| {
        channel.channel.effects.iter().map(move |effect| {
            (
                PluginTarget::TrackEffect(track, effect.id),
                &effect.instance,
            )
        })
    });
    let buses = app.mixer.buses.iter().flat_map(|(bus, channel)| {
        channel
            .channel
            .effects
            .iter()
            .map(move |effect| (PluginTarget::BusEffect(bus, effect.id), &effect.instance))
    });
    let master = app
        .mixer
        .master_bus
        .effects
        .iter()
        .map(|effect| (PluginTarget::MasterEffect(effect.id), &effect.instance));
    for (target, instance) in generators.chain(tracks).chain(buses).chain(master) {
        if let Some(external) = &instance.external {
            if snapshot.hosted_instance(target).is_none() {
                return Err(AudioExportError::new(
                    "HostedPlugin",
                    format!(
                        "{} ({:?}: {}) is missing from the audio engine; restore the plugin before exporting",
                        external.descriptor.name,
                        external.descriptor.identity.format,
                        external.descriptor.identity.native_id,
                    ),
                ));
            }
        }
    }
    Ok(())
}

fn render_snapshot<F>(
    mut snapshot: AudioExportSnapshot,
    output_path: &str,
    config: AudioExportConfig,
    tail_handling: TailHandling,
    plugin_registry: PluginRegistry,
    progress_callback: &mut F,
) -> Result<(), AudioExportError>
where
    F: FnMut(f32) -> bool,
{
    let sample_rate = config.sample_rate();
    let channels = config.channels() as usize;
    let block_size = 4096;
    snapshot
        .prepare_hosted(|instance| {
            karbeat_vst3::native::prepare_offline_instance(
                instance,
                sample_rate,
                block_size,
                channels,
            )
            .map(|prepared| prepared.processor)
        })
        .map_err(|error| AudioExportError::new("HostedPlugin", error.to_string()))?;
    let (mut cmd_producer, cmd_consumer) = RingBuffer::<AudioCommand>::new(16);
    let (pos_producer, mut pos_consumer) = RingBuffer::new(1024);
    let (feedback_producer, mut feedback_consumer) = RingBuffer::new(1024);
    let mut offline_engine = AudioEngine::from_export_snapshot(
        snapshot,
        &plugin_registry,
        channels as u16,
        cmd_consumer,
        pos_producer,
        feedback_producer,
    )
    .map_err(|e| AudioExportError::new("Snapshot", e.to_string()))?;
    let path = std::path::Path::new(output_path);
    let mut writer = create_writer(path, config).map_err(|e| {
        AudioExportError::new("WriterInit", format!("Failed to create writer: {e}"))
    })?;

    cmd_producer
        .push(AudioCommand::UpdateAudioConfig {
            sample_rate: Some(sample_rate),
            buffer_size: Some(block_size),
        })
        .map_err(|_| AudioExportError::new("Engine", "Command queue full"))?;
    cmd_producer
        .push(AudioCommand::SetPlaybackMode(
            crate::audio::engine::PlaybackMode::Song,
        ))
        .map_err(|_| AudioExportError::new("Engine", "Command queue full"))?;
    cmd_producer
        .push(AudioCommand::SetPlayhead(0))
        .map_err(|_| AudioExportError::new("Engine", "Command queue full"))?;
    cmd_producer
        .push(AudioCommand::SetPlaying(true))
        .map_err(|_| AudioExportError::new("Engine", "Command queue full"))?;

    offline_engine.process(&mut []);
    validate_rendered_block(&offline_engine, &[])?;

    let tail_samples = offline_engine.get_project_tail_length();
    let song_length_samples = offline_engine.get_export_length() - tail_samples;
    let mut mix_buffer = vec![0.0; block_size * channels];
    let throttle_limit = (sample_rate / block_size as u32 / 30).max(1);
    let mut loop_counter = 0;

    if matches!(tail_handling, TailHandling::WrapRemainder) {
        let mut preroll_processed = 0;
        while preroll_processed < song_length_samples {
            let frames = (song_length_samples - preroll_processed).min(block_size as u32) as usize;
            offline_engine.process(&mut mix_buffer[..frames * channels]);
            validate_rendered_block(&offline_engine, &mix_buffer[..frames * channels])?;
            drain_engine_feedback(&mut pos_consumer, &mut feedback_consumer);
            preroll_processed += frames as u32;
            loop_counter += 1;

            if loop_counter % throttle_limit == 0
                && !progress_callback(preroll_processed as f32 / song_length_samples as f32 * 0.5)
            {
                return finalize_cancelled(writer);
            }
        }

        cmd_producer
            .push(AudioCommand::SetPlayhead(0))
            .map_err(|_| AudioExportError::new("Engine", "Command queue full"))?;
    }

    let (progress_base, progress_scale) = match tail_handling {
        TailHandling::CutRemainder => (0.0, 1.0),
        TailHandling::LeaveRemainder => (0.0, 0.95),
        TailHandling::WrapRemainder => (0.5, 0.5),
    };
    let mut processed_samples = 0;

    while processed_samples < song_length_samples {
        let frames = (song_length_samples - processed_samples).min(block_size as u32) as usize;
        let active_slice = &mut mix_buffer[..frames * channels];
        offline_engine.process(active_slice);
        validate_rendered_block(&offline_engine, active_slice)?;
        writer
            .write(active_slice)
            .map_err(|e| AudioExportError::new("Writer", format!("Write error: {e}")))?;
        drain_engine_feedback(&mut pos_consumer, &mut feedback_consumer);
        processed_samples += frames as u32;
        loop_counter += 1;

        if loop_counter % throttle_limit == 0 {
            let progress = progress_base
                + processed_samples as f32 / song_length_samples as f32 * progress_scale;
            if !progress_callback(progress) {
                return finalize_cancelled(writer);
            }
        }
    }

    if matches!(tail_handling, TailHandling::LeaveRemainder) {
        cmd_producer
            .push(AudioCommand::SetPlaying(false))
            .map_err(|_| AudioExportError::new("Engine", "Command queue full"))?;
        offline_engine.process(&mut []);
        validate_rendered_block(&offline_engine, &[])?;

        let mut tail_processed = 0;
        while tail_processed < tail_samples {
            let frames = (tail_samples - tail_processed).min(block_size as u32) as usize;
            let active_slice = &mut mix_buffer[..frames * channels];
            offline_engine.process(active_slice);
            validate_rendered_block(&offline_engine, active_slice)?;
            writer
                .write(active_slice)
                .map_err(|e| AudioExportError::new("Writer", format!("Write error: {e}")))?;
            drain_engine_feedback(&mut pos_consumer, &mut feedback_consumer);
            tail_processed += frames as u32;

            let progress = if tail_samples == 0 {
                1.0
            } else {
                0.95 + tail_processed as f32 / tail_samples as f32 * 0.05
            };
            if !progress_callback(progress) {
                return finalize_cancelled(writer);
            }
        }
    }

    let _ = progress_callback(1.0);
    writer
        .finalize()
        .map_err(|e| AudioExportError::new("Writer", format!("Finalize error: {e}")))?;
    log::info!("Offline render successfully completed");
    Ok(())
}

fn drain_engine_feedback(
    position: &mut rtrb::Consumer<crate::audio::event::TransportFeedback>,
    feedback: &mut rtrb::Consumer<crate::commands::AudioFeedback>,
) {
    while position.pop().is_ok() {}
    while feedback.pop().is_ok() {}
}

fn validate_rendered_block(engine: &AudioEngine, samples: &[f32]) -> Result<(), AudioExportError> {
    engine
        .validate_hosted_processing()
        .map_err(|error| AudioExportError::new("HostedPlugin", error.to_string()))?;
    if samples.iter().any(|sample| !sample.is_finite()) {
        return Err(AudioExportError::new(
            "Render",
            "audio processing produced non-finite samples",
        ));
    }
    Ok(())
}

fn finalize_cancelled(mut writer: Box<dyn AudioWriter>) -> Result<(), AudioExportError> {
    log::warn!("Export cancelled by callback");
    writer
        .finalize()
        .map_err(|e| AudioExportError::new("Writer", format!("Finalize error: {e}")))
}

#[cfg(test)]
#[allow(
    clippy::unwrap_used,
    reason = "export fixtures assert setup and file preservation"
)]
mod tests {
    use super::*;
    use crate::{
        audio::{
            engine::AudioEngineTelemetry,
            event::PluginTarget,
            hosted_plugin::HostedPluginInstall,
            writer::{BitDepth, BitPerSample, WavAudioWriterConfig},
        },
        core::project::{
            ApplicationState, ExternalPluginInstance, GeneratorInstanceType, PluginInstance,
        },
        shared::EffectId,
    };
    use karbeat_host::{
        HostInstanceId, HostedProcessor, PluginDescriptor, PluginFormat, PluginIdentity,
        PluginKind, ProcessingConfig,
    };
    use karbeat_plugin_api::traits::AudioPluginBuilder;
    use karbeat_plugins::effect::delay::DigidawDelay;

    fn engine() -> AudioEngine {
        let (_, commands) = RingBuffer::new(8);
        let (position, _) = RingBuffer::new(8);
        let (feedback, _) = RingBuffer::new(8);
        let (telemetry, _) = std::sync::mpsc::sync_channel(8);
        AudioEngine::new(
            commands,
            position,
            feedback,
            48_000,
            2,
            120.0,
            512,
            AudioEngineTelemetry::new_for_export(),
            telemetry,
        )
    }

    #[test]
    fn missing_external_generators_and_effects_fail_export_validation() {
        let snapshot = engine().export_snapshot();
        let mut plugin = PluginInstance::new("Missing external");
        plugin.external = Some(ExternalPluginInstance {
            descriptor: PluginDescriptor {
                identity: PluginIdentity {
                    format: PluginFormat::Vst3,
                    native_id: "missing.class".into(),
                },
                path: "missing.vst3".into(),
                name: "Missing external".into(),
                vendor: String::new(),
                version: "1".into(),
                kind: PluginKind::Instrument,
            },
            state: None,
        });
        for instrument in [true, false] {
            let mut app = ApplicationState::default();
            assert!(validate_external_plugins(&app, &snapshot).is_ok());
            if instrument {
                app.add_generator(GeneratorInstanceType::Plugin(plugin.clone()));
            } else {
                app.mixer.master_bus.effects.insert(plugin.clone());
            }
            let error = validate_external_plugins(&app, &snapshot).unwrap_err();
            assert_eq!(error.error_source, "HostedPlugin");
            assert!(error.message.contains("missing.class"));
        }
    }

    #[test]
    fn unavailable_native_capture_preserves_an_existing_export_file() {
        let mut engine = engine();
        let (processor, mut retirement) = Box::new(HostedProcessor::new(
            Box::new(DigidawDelay::build()),
            HostInstanceId(99),
        ))
        .prepare_transfer()
        .unwrap();
        let (command, _) = HostedPluginInstall::new(
            PluginTarget::MasterEffect(EffectId::from(1)),
            None,
            123,
            ProcessingConfig {
                sample_rate: 48_000.0,
                max_block_size: 4096,
                main_input_channels: 2,
                main_output_channels: 2,
                sidechain_channels: 0,
                offline: false,
            },
            processor,
        );
        let (command, mut control) = karbeat_host::ControlTransfer::new(command);
        engine.process_command(AudioCommand::InstallHostedPlugin(command));
        assert!(control.collect());
        let directory = tempfile::tempdir().unwrap();
        let path = directory.path().join("existing.wav");
        std::fs::write(&path, b"previous export").unwrap();
        let config = AudioExportConfig::Wav(WavAudioWriterConfig {
            sample_rate: 44_100,
            channels: 2,
            bit_depth: BitDepth::BitPerSample(BitPerSample::B32),
        });
        let result = render_snapshot(
            engine.export_snapshot(),
            path.to_str().unwrap(),
            config,
            TailHandling::CutRemainder,
            PluginRegistry::new_with_defaults(),
            &mut |_| true,
        );
        assert_eq!(result.unwrap_err().error_source, "HostedPlugin");
        assert_eq!(std::fs::read(path).unwrap(), b"previous export");
        drop(engine);
        assert!(retirement.take().is_some());
    }

    #[test]
    fn non_finite_rendered_audio_is_rejected_before_writing() {
        let engine = engine();
        assert!(validate_rendered_block(&engine, &[0.0, -0.5, 1.0]).is_ok());
        for sample in [f32::NAN, f32::INFINITY, f32::NEG_INFINITY] {
            assert_eq!(
                validate_rendered_block(&engine, &[sample])
                    .unwrap_err()
                    .error_source,
                "Render"
            );
        }
    }
}
