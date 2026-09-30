use rtrb::RingBuffer;
use thiserror::Error;

use crate::{
    audio::engine::{AudioEngine, AudioExportSnapshot},
    audio::writer::{AudioExportConfig, AudioWriter, create_writer, metadata::AudioMetadata},
    commands::AudioCommand,
    context::DawContext,
    core::project::ClipTimeUnit,
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

/// Part of the song a render covers. Tail handling applies after its end.
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq)]
pub enum ExportRange {
    /// From the song start to the end of the last clip.
    #[default]
    Song,
    /// From `start_tick` up to `end_tick`, such as the loop region.
    Ticks { start_tick: u64, end_tick: u64 },
}

/// What a render is for.
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq)]
pub enum RenderPurpose {
    /// A mixdown of the master bus output, tagged with the project metadata.
    #[default]
    Export,
    /// Audio to reuse in the project: the mix feeding the master bus, without the master
    /// effects and fader so it is not processed twice when played back, and untagged.
    Bounce,
}

/// How to render: the range, what happens after it, and what the render is for.
#[derive(Debug, Clone, Default)]
pub struct RenderOptions {
    pub tail_handling: TailHandling,
    pub range: ExportRange,
    pub purpose: RenderPurpose,
}

pub struct PendingAudioExport {
    app: crate::core::project::ApplicationState,
    plugin_registry: PluginRegistry,
    handles: crate::context::ControlHandles,
    hosted_formats: hashbrown::HashMap<karbeat_host::HostInstanceId, karbeat_host::PluginFormat>,
}

pub fn begin_export(ctx: &DawContext) -> PendingAudioExport {
    PendingAudioExport {
        app: ctx.app_state.clone(),
        plugin_registry: ctx.plugin_registry.clone(),
        handles: ctx.control_handles(),
        hosted_formats: ctx
            .hosted_targets
            .values()
            .filter_map(|state| match state {
                crate::context::HostedTargetState::Active(instance) => {
                    Some((instance.id, instance.format))
                }
                crate::context::HostedTargetState::Transitioning
                | crate::context::HostedTargetState::Failed(_) => None,
            })
            .collect(),
    }
}

/// Export project to a sound file based on provided writer
/// Generic, UI-agnostic.
/// `progress_callback` should return `true` to continue, or `false` to abort rendering.
pub fn export_project<F>(
    ctx: &mut DawContext,
    output_path: &str,
    config: AudioExportConfig,
    options: RenderOptions,
    progress_callback: F,
) -> Result<(), AudioExportError>
where
    F: FnMut(f32) -> bool + Send,
{
    execute_export(
        begin_export(ctx),
        output_path,
        config,
        options,
        progress_callback,
    )
}

pub fn execute_export<F>(
    pending: PendingAudioExport,
    output_path: &str,
    config: AudioExportConfig,
    options: RenderOptions,
    mut progress_callback: F,
) -> Result<(), AudioExportError>
where
    F: FnMut(f32) -> bool + Send,
{
    log::info!("Starting offline render to: {}", output_path);

    let (snapshot_tx, snapshot_rx) = std::sync::mpsc::channel();

    pending
        .handles
        .command_sender
        .lock()
        .as_mut()
        .ok_or_else(|| AudioExportError::new("Engine", "Audio engine is unavailable"))?
        .push(AudioCommand::QueryAudioExportSnapshot {
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
    validate_external_plugins(&pending.app, &snapshot)?;
    let (snapshot, metadata) = match options.purpose {
        RenderPurpose::Export => (
            snapshot,
            AudioMetadata::from_project(&pending.app.metadata)
                .map_err(|error| AudioExportError::new("Metadata", error.to_string()))?,
        ),
        RenderPurpose::Bounce => (snapshot, AudioMetadata::default()),
    };
    let output_path = output_path.to_owned();
    let plugin_registry = pending.plugin_registry;
    let external_plugins = pending.handles.external_plugins;
    let hosted_formats = pending.hosted_formats;

    std::thread::scope(|scope| {
        scope
            .spawn(move || {
                render_snapshot(
                    snapshot,
                    &output_path,
                    config,
                    &metadata,
                    options,
                    plugin_registry,
                    external_plugins,
                    hosted_formats,
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
    snapshot: AudioExportSnapshot,
    output_path: &str,
    config: AudioExportConfig,
    metadata: &AudioMetadata,
    options: RenderOptions,
    plugin_registry: PluginRegistry,
    external_plugins: karbeat_host::HostClient,
    hosted_formats: hashbrown::HashMap<karbeat_host::HostInstanceId, karbeat_host::PluginFormat>,
    progress_callback: &mut F,
) -> Result<(), AudioExportError>
where
    F: FnMut(f32) -> bool,
{
    let RenderOptions {
        tail_handling,
        range,
        ..
    } = options;
    let sample_rate = config.sample_rate();
    let channels = config.channels() as usize;
    let block_size = 4096;
    let bpm = snapshot.bpm();
    let mut snapshot = match options.purpose {
        RenderPurpose::Export => snapshot,
        RenderPurpose::Bounce => snapshot.without_master(),
    };
    snapshot
        .prepare_hosted(|instance| {
            let format = hosted_formats
                .get(&instance)
                .copied()
                .ok_or(karbeat_host::HostError::UnknownInstance(instance))?;
            futures_lite::future::block_on(external_plugins.prepare_offline(
                karbeat_host::OfflinePrepareRequest {
                    instance: karbeat_host::ExternalPluginInstanceHandle {
                        format,
                        id: instance,
                    },
                    sample_rate,
                    max_block_size: block_size,
                    output_channels: channels,
                },
            ))
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
    let mut writer = create_writer(path, config, metadata).map_err(|e| {
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
    // Apply the render sample rate first: the song length and the range depend on it
    offline_engine.process(&mut []);
    validate_rendered_block(&offline_engine, &[])?;

    let tail_samples = offline_engine.get_project_tail_length();
    let (start_sample, song_length_samples) = match range {
        ExportRange::Song => (
            0,
            offline_engine
                .get_export_length()
                .saturating_sub(tail_samples),
        ),
        ExportRange::Ticks {
            start_tick,
            end_tick,
        } => range_in_samples(start_tick, end_tick, bpm, sample_rate)?,
    };

    cmd_producer
        .push(AudioCommand::SetPlayhead(start_sample))
        .map_err(|_| AudioExportError::new("Engine", "Command queue full"))?;
    cmd_producer
        .push(AudioCommand::SetPlaying(true))
        .map_err(|_| AudioExportError::new("Engine", "Command queue full"))?;
    offline_engine.process(&mut []);
    validate_rendered_block(&offline_engine, &[])?;
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
            .push(AudioCommand::SetPlayhead(start_sample))
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

/// Converts a tick range to `(start_sample, length_in_samples)` at the render sample rate.
fn range_in_samples(
    start_tick: u64,
    end_tick: u64,
    bpm: f32,
    sample_rate: u32,
) -> Result<(u32, u32), AudioExportError> {
    let to_samples = |ticks: u64| {
        u32::try_from(ClipTimeUnit::ticks_to_samples(ticks, bpm, sample_rate))
            .map_err(|_| AudioExportError::new("Range", "The render range is too long"))
    };
    let (start, end) = (to_samples(start_tick)?, to_samples(end_tick)?);
    if end <= start {
        return Err(AudioExportError::new(
            "Range",
            "The render range must end after it starts",
        ));
    }
    Ok((start, end.saturating_sub(start)))
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
            writer::{BitDepth, BitPerSample, wav::WavAudioWriterConfig},
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
            &AudioMetadata::default(),
            RenderOptions::default(),
            PluginRegistry::new_with_defaults(),
            karbeat_host::HostClient::unavailable(),
            hashbrown::HashMap::new(),
            &mut |_| true,
        );
        assert_eq!(result.unwrap_err().error_source, "HostedPlugin");
        assert_eq!(std::fs::read(path).unwrap(), b"previous export");
        drop(engine);
        assert!(retirement.take().is_some());
    }

    const RENDER_RATE: u32 = 48_000;

    /// Renders the ramp fixture to a 32-bit float WAV and reads back the left channel.
    fn render_ramp(
        engine: &AudioEngine,
        options: RenderOptions,
    ) -> Result<Vec<f32>, AudioExportError> {
        let directory = tempfile::tempdir().unwrap();
        let path = directory.path().join("render.wav");
        render_snapshot(
            engine.export_snapshot(),
            path.to_str().unwrap(),
            AudioExportConfig::Wav(WavAudioWriterConfig {
                sample_rate: RENDER_RATE,
                channels: 2,
                bit_depth: BitDepth::BitPerSample(BitPerSample::B32),
            }),
            &AudioMetadata::default(),
            options,
            PluginRegistry::new_with_defaults(),
            karbeat_host::HostClient::unavailable(),
            hashbrown::HashMap::new(),
            &mut |_| true,
        )?;
        let mut reader = hound::WavReader::open(&path).unwrap();
        let samples: Vec<f32> = reader.samples::<f32>().map(Result::unwrap).collect();
        Ok(samples.chunks(2).map(|frame| frame[0]).collect())
    }

    fn region(start_tick: u64, end_tick: u64, purpose: RenderPurpose) -> RenderOptions {
        RenderOptions {
            range: ExportRange::Ticks {
                start_tick,
                end_tick,
            },
            purpose,
            ..RenderOptions::default()
        }
    }

    #[test]
    fn region_export_renders_exactly_the_region() {
        use crate::audio::engine::tests::song_engine_with_ramp_clip;

        let engine = song_engine_with_ramp_clip();
        let whole_song = render_ramp(&engine, RenderOptions::default()).unwrap();
        assert_eq!(whole_song.len(), 96_000);

        // Ticks 480..1,440 are samples 12,000..36,000 at 120 BPM
        let rendered = render_ramp(&engine, region(480, 1_440, RenderPurpose::Export)).unwrap();
        assert_eq!(rendered.len(), 24_000);
        assert!(rendered.iter().any(|sample| *sample > 0.1));
        for (index, (region, song)) in rendered.iter().zip(&whole_song[12_000..]).enumerate() {
            assert!(
                (region - song).abs() < 1e-5,
                "frame {index}: {region} != {song}"
            );
        }
    }

    #[test]
    fn region_past_the_song_end_renders_silence_after_it() {
        use crate::audio::engine::tests::song_engine_with_ramp_clip;

        // Ticks 3,360..4,800 are samples 84,000..120,000; the clip ends at 96,000
        let rendered = render_ramp(
            &song_engine_with_ramp_clip(),
            region(3_360, 4_800, RenderPurpose::Export),
        )
        .unwrap();
        assert_eq!(rendered.len(), 36_000);
        assert!(rendered[..11_000].iter().any(|sample| *sample > 0.1));
        assert!(rendered[13_000..].iter().all(|sample| *sample == 0.0));
    }

    #[test]
    fn empty_regions_are_rejected() {
        use crate::audio::engine::tests::song_engine_with_ramp_clip;

        let error = render_ramp(
            &song_engine_with_ramp_clip(),
            region(960, 960, RenderPurpose::Export),
        )
        .unwrap_err();
        assert_eq!(error.error_source, "Range");
    }

    #[test]
    fn bounces_skip_the_master_fader() {
        use crate::audio::engine::tests::song_engine_with_ramp_clip;
        use crate::commands::MixerChannelTarget;
        use crate::core::project::MixerChannelParams;

        let mut engine = song_engine_with_ramp_clip();
        let unity = render_ramp(&engine, region(0, 960, RenderPurpose::Export)).unwrap();
        engine.process_command(AudioCommand::SetMixerChannelParameter {
            target: MixerChannelTarget::Master,
            param: MixerChannelParams::Volume(-20.0),
        });
        let peak = |samples: &[f32]| samples.iter().fold(0.0_f32, |peak, s| peak.max(s.abs()));

        let exported = render_ramp(&engine, region(0, 960, RenderPurpose::Export)).unwrap();
        let bounced = render_ramp(&engine, region(0, 960, RenderPurpose::Bounce)).unwrap();
        assert!(
            peak(&exported) < peak(&unity) * 0.2,
            "the export goes through the master fader"
        );
        // The export passes the master's centre pan (1/sqrt(2)); the bounce skips it and is
        // raised by sqrt(2) for the channel it will play back on
        assert_eq!(bounced.len(), unity.len());
        assert!(peak(&bounced) > 0.5);
        for (bounce, reference) in bounced.iter().zip(&unity) {
            assert!(
                (bounce - reference * 2.0).abs() < 1e-4,
                "{bounce} != 2 * {reference}"
            );
        }
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
