use rtrb::RingBuffer;
use thiserror::Error;

use crate::{
    commands::{AudioCommand, AudioFeedback},
    context::{ControlHandles, DawContext, HostedTargetState},
    engine::{AudioEngine, AudioExportSnapshot, PlaybackMode},
    event::{PluginTarget, TransportFeedback},
    rate_bridge::DeviceRateBridge,
    writer::{AudioExportConfig, AudioWriter, create_writer, metadata::AudioMetadata},
};
use futures_lite::future::block_on;
use karbeat_core::core::project::{ApplicationState, ClipTimeUnit, GeneratorInstanceType};
use karbeat_plugins::registry::PluginRegistry;
use std::{
    fs::{remove_file, rename},
    io::ErrorKind,
    iter::repeat_n,
    mem::take,
    path::{Path, PathBuf},
    sync::mpsc::channel as mpsc_channel,
    thread::{scope as thread_scope, sleep},
    time::{Duration, Instant},
};

/// Wall-clock time hosted plugins get to finish restoring their state before the timeline
/// renders.
const HOSTED_SETTLE_TIME: Duration = Duration::from_millis(400);
/// Longest wait for hosted plugins that still report pending work after the settle time.
const HOSTED_SETTLE_LIMIT: Duration = Duration::from_secs(10);
/// Pause between settling blocks, which leaves plugin worker threads time to run.
const HOSTED_SETTLE_INTERVAL: Duration = Duration::from_millis(10);
/// Peak below which a block counts as silent while hosted plugins ring out (-80 dBFS).
const RING_OUT_SILENCE: f32 = 1.0e-4;
/// Longest ring-out rendered after the reported tail, matching the engine's cap on reported
/// tails.
const RING_OUT_LIMIT_SECONDS: u32 = 20;

#[derive(Debug, Clone, Error)]
#[error("Audio export failed ({error_source}): {message}")]
pub struct AudioExportError {
    pub error_source: String,
    pub message: String,
}

/// [`AudioExportError::error_source`] of a render the progress callback stopped.
pub const EXPORT_CANCELLED: &str = "Cancelled";

impl AudioExportError {
    pub fn new(source: &str, message: impl Into<String>) -> Self {
        Self {
            error_source: source.to_string(),
            message: message.into(),
        }
    }

    /// Whether the progress callback stopped the render.
    pub fn is_cancelled(&self) -> bool {
        self.error_source == EXPORT_CANCELLED
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
    app: ApplicationState,
    plugin_registry: PluginRegistry,
    handles: ControlHandles,
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
                HostedTargetState::Active(target) => {
                    let instance = target.state().instance;
                    Some((instance.id, instance.format))
                }
                HostedTargetState::Transitioning(_) | HostedTargetState::Failed(_) => None,
            })
            .collect(),
    }
}

/// Export project to a sound file based on provided writer
/// Generic, UI-agnostic.
/// `progress_callback` should return `true` to continue, or `false` to abort rendering, which
/// deletes the partial file and fails with an error whose
/// [`is_cancelled`](AudioExportError::is_cancelled) is `true`.
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
    tracing::info!("Starting offline render to: {}", output_path);

    let (snapshot_tx, snapshot_rx) = mpsc_channel();

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
        .recv_timeout(Duration::from_secs(30))
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

    thread_scope(|scope| {
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
    app: &ApplicationState,
    snapshot: &AudioExportSnapshot,
) -> Result<(), AudioExportError> {
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

pub(crate) fn render_snapshot<F>(
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
    // Render exactly as the live engine does: at its DSP rate, in its block size. Automation,
    // LFOs and other per-block work then step as they do live, and sources are resampled to
    // the same rate. The file's own rate and channels are applied afterwards by the sink, as
    // the device stream applies the device's.
    let sample_rate = snapshot.sample_rate();
    let block_size = snapshot.block_size().max(1);
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
            block_on(
                external_plugins.prepare_offline(karbeat_host::OfflinePrepareRequest {
                    instance: karbeat_host::ExternalPluginInstanceHandle {
                        format,
                        id: instance,
                    },
                    sample_rate,
                    // The engine prepares plugins for at least 512 frames.
                    max_block_size: block_size.max(512),
                    output_channels: ENGINE_CHANNELS,
                }),
            )
            .map(|prepared| prepared.processor)
        })
        .map_err(|error| AudioExportError::new("HostedPlugin", error.to_string()))?;
    let (mut cmd_producer, cmd_consumer) = RingBuffer::<AudioCommand>::new(16);
    let (pos_producer, position) = RingBuffer::new(1024);
    let (feedback_producer, feedback) = RingBuffer::new(1024);
    let engine = AudioEngine::from_export_snapshot(
        snapshot,
        &plugin_registry,
        ENGINE_CHANNELS as u16,
        cmd_consumer,
        pos_producer,
        feedback_producer,
    )
    .map_err(|e| AudioExportError::new("Snapshot", e.to_string()))?;
    let (file_rate, file_channels) = (config.sample_rate(), usize::from(config.channels()));
    let output = StagedOutput::new(Path::new(output_path));
    let writer = create_writer(&output.staging, config, metadata).map_err(|e| {
        AudioExportError::new("WriterInit", format!("Failed to create writer: {e}"))
    })?;
    let mut sink = ExportSink::new(writer, sample_rate, file_rate, file_channels, block_size)?;
    let mut render = OfflineRender {
        engine,
        buffer: vec![0.0; block_size * ENGINE_CHANNELS],
        position,
        feedback,
    };

    cmd_producer
        .push(AudioCommand::UpdateAudioConfig {
            sample_rate: Some(sample_rate),
            buffer_size: Some(block_size),
        })
        .map_err(|_| AudioExportError::new("Engine", "Command queue full"))?;
    cmd_producer
        .push(AudioCommand::SetPlaybackMode(PlaybackMode::Song))
        .map_err(|_| AudioExportError::new("Engine", "Command queue full"))?;
    render.engine.process(&mut []);
    validate_rendered_block(&render.engine, &[])?;

    settle_hosted_plugins(
        &mut render.engine,
        &mut render.buffer,
        HOSTED_SETTLE_TIME,
        HOSTED_SETTLE_LIMIT,
        &mut render.position,
        &mut render.feedback,
    )?;

    let tail_samples = render.engine.get_project_tail_length();
    let (start_sample, song_length_samples) = match range {
        ExportRange::Song => (
            0,
            render
                .engine
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
    render.engine.process(&mut []);
    validate_rendered_block(&render.engine, &[])?;
    let throttle_limit = (sample_rate / block_size as u32 / 30).max(1);
    let mut loop_counter = 0;

    if matches!(tail_handling, TailHandling::WrapRemainder) {
        let completed = render.render(song_length_samples, None, |rendered| {
            loop_counter += 1;
            loop_counter % throttle_limit != 0
                || progress_callback(rendered as f32 / song_length_samples as f32 * 0.5)
        })?;
        if !completed {
            return sink.cancel();
        }

        cmd_producer
            .push(AudioCommand::SetPlayhead(start_sample))
            .map_err(|_| AudioExportError::new("Engine", "Command queue full"))?;
    }

    // Delay compensation holds the output back by the system latency. Render past it so the
    // file starts on the first frame of the range, as the live playhead display does.
    // The pre-roll and the range render as one stream of engine blocks, as playback renders
    // them; a separate pre-roll would end on a short block and shift every later block
    // boundary, which block-wise processing such as envelopes and automation can hear.
    let latency = render.engine.system_latency();
    sink.skip(latency);

    let (progress_base, progress_scale) = match tail_handling {
        TailHandling::CutRemainder => (0.0, 1.0),
        TailHandling::LeaveRemainder => (0.0, 0.95),
        TailHandling::WrapRemainder => (0.5, 0.5),
    };
    let completed = render.render(
        song_length_samples.saturating_add(latency),
        Some(&mut sink),
        |rendered| {
            loop_counter += 1;
            let rendered = rendered.saturating_sub(latency);
            loop_counter % throttle_limit != 0
                || progress_callback(
                    progress_base + rendered as f32 / song_length_samples as f32 * progress_scale,
                )
        },
    )?;
    if !completed {
        return sink.cancel();
    }

    if matches!(tail_handling, TailHandling::LeaveRemainder) {
        cmd_producer
            .push(AudioCommand::SetPlaying(false))
            .map_err(|_| AudioExportError::new("Engine", "Command queue full"))?;
        render.engine.process(&mut []);
        validate_rendered_block(&render.engine, &[])?;

        let completed = render.render(tail_samples, Some(&mut sink), |rendered| {
            progress_callback(0.95 + rendered as f32 / tail_samples as f32 * 0.05)
        })?;
        if !completed {
            return sink.cancel();
        }

        // Hosted plugins often report no tail at all (LSP's convolution reverbs do), so keep
        // rendering while they are still audible.
        if render.engine.has_continuous_effects() {
            let limit = RING_OUT_LIMIT_SECONDS.saturating_mul(sample_rate);
            let mut tail_processed = tail_samples;
            while tail_processed < limit
                && render_ring_out_block(&mut render.engine, &mut render.buffer)?
            {
                sink.push(&render.buffer)?;
                drain_engine_feedback(&mut render.position, &mut render.feedback);
                tail_processed += block_size as u32;
                if !progress_callback(1.0) {
                    return sink.cancel();
                }
            }
        }
    }

    let _ = progress_callback(1.0);
    sink.finish()?;
    output.commit()?;
    tracing::info!("Offline render successfully completed");
    Ok(())
}

/// Channels the engine renders: interleaved stereo, whatever the file's layout.
const ENGINE_CHANNELS: usize = 2;

/// The offline engine and the queues it reports into.
struct OfflineRender {
    engine: AudioEngine,
    /// One engine block of interleaved stereo.
    buffer: Vec<f32>,
    position: rtrb::Consumer<TransportFeedback>,
    feedback: rtrb::Consumer<AudioFeedback>,
}

impl OfflineRender {
    /// Renders `frames` frames in engine blocks, handing each to `sink`, or dropping it without
    /// one. `on_block` gets the frames rendered so far and returns `false` to cancel. Returns
    /// whether every frame was rendered.
    fn render(
        &mut self,
        frames: u32,
        mut sink: Option<&mut ExportSink>,
        mut on_block: impl FnMut(u32) -> bool,
    ) -> Result<bool, AudioExportError> {
        let block = self.buffer.len() / ENGINE_CHANNELS;
        let mut rendered = 0;
        while rendered < frames {
            let count = ((frames - rendered) as usize).min(block);
            let slice = &mut self.buffer[..count * ENGINE_CHANNELS];
            self.engine.process(slice);
            validate_rendered_block(&self.engine, slice)?;
            if let Some(sink) = sink.as_deref_mut() {
                sink.push(slice)?;
            }
            drain_engine_feedback(&mut self.position, &mut self.feedback);
            rendered += count as u32;
            if !on_block(rendered) {
                return Ok(false);
            }
        }
        Ok(true)
    }
}

/// Carries rendered engine audio to the file the way the device stream carries it to the
/// speakers: through the same [`DeviceRateBridge`] when the file's rate differs from the DSP
/// rate, then into the file's channel layout.
struct ExportSink {
    writer: Box<dyn AudioWriter>,
    /// `None` when the file is at the DSP rate.
    bridge: Option<DeviceRateBridge>,
    /// Interleaved stereo DSP-rate audio waiting for a full resampler call.
    pending: Vec<f32>,
    /// Resampled audio of the last call.
    resampled: Vec<f32>,
    /// File frames per DSP frame.
    ratio: f64,
    channels: usize,
    /// DSP frames accepted.
    input_frames: u64,
    /// File frames written.
    output_frames: u64,
    /// Resampled frames still to drop: the resampler's delay.
    delay: usize,
    /// Rendered frames still to drop before any reach the file: the delay-compensation
    /// pre-roll.
    skip: usize,
    /// One write in the file's layout.
    scratch: Vec<f32>,
}

impl ExportSink {
    fn new(
        writer: Box<dyn AudioWriter>,
        dsp_rate: u32,
        file_rate: u32,
        channels: usize,
        block_size: usize,
    ) -> Result<Self, AudioExportError> {
        if channels == 0 {
            return Err(AudioExportError::new(
                "WriterInit",
                "The export needs at least one channel",
            ));
        }
        let bridge = (dsp_rate != file_rate)
            .then(|| DeviceRateBridge::new(dsp_rate, file_rate, ENGINE_CHANNELS, block_size))
            .transpose()
            .map_err(|error| AudioExportError::new("Resampler", error.to_string()))?;
        Ok(Self {
            delay: bridge
                .as_ref()
                .map_or(0, DeviceRateBridge::output_delay_frames),
            writer,
            bridge,
            pending: Vec::new(),
            resampled: Vec::new(),
            ratio: f64::from(file_rate) / f64::from(dsp_rate),
            channels,
            input_frames: 0,
            output_frames: 0,
            skip: 0,
            scratch: Vec::new(),
        })
    }

    /// Drops the next `frames` rendered frames.
    fn skip(&mut self, frames: u32) {
        self.skip = self.skip.saturating_add(frames as usize);
    }

    /// File frames the accepted DSP frames make.
    fn target_frames(&self) -> u64 {
        (self.input_frames as f64 * self.ratio).round() as u64
    }

    /// Takes interleaved stereo frames at the DSP rate.
    fn push(&mut self, stereo: &[f32]) -> Result<(), AudioExportError> {
        let skipped = self.skip.min(stereo.len() / ENGINE_CHANNELS);
        self.skip = self.skip.saturating_sub(skipped);
        let stereo = stereo
            .get(skipped.saturating_mul(ENGINE_CHANNELS)..)
            .unwrap_or_default();
        if stereo.is_empty() {
            return Ok(());
        }
        self.input_frames += (stereo.len() / ENGINE_CHANNELS) as u64;
        if self.bridge.is_none() {
            return self.write(stereo);
        }
        self.pending.extend_from_slice(stereo);
        self.resample_pending()
    }

    /// Runs every full resampler call the pending audio allows.
    fn resample_pending(&mut self) -> Result<(), AudioExportError> {
        loop {
            let Some(bridge) = self.bridge.as_mut() else {
                return Ok(());
            };
            let needed = bridge.input_frames_next() * ENGINE_CHANNELS;
            if needed == 0 || self.pending.len() < needed {
                return Ok(());
            }
            let output = bridge.process(&self.pending[..needed]);
            self.resampled.clear();
            self.resampled.extend_from_slice(output);
            self.pending.drain(..needed);
            let resampled = take(&mut self.resampled);
            let result = self.write(&resampled);
            self.resampled = resampled;
            result?;
        }
    }

    /// Writes stereo frames in the file's layout, after the resampler's delay and up to the
    /// frames the accepted audio makes.
    fn write(&mut self, stereo: &[f32]) -> Result<(), AudioExportError> {
        let (frames, _) = stereo.as_chunks::<ENGINE_CHANNELS>();
        let skip = self.delay.min(frames.len());
        self.delay -= skip;
        let room = self.target_frames().saturating_sub(self.output_frames) as usize;
        self.scratch.clear();
        let mut written = 0_u64;
        for &[left, right] in frames.iter().skip(skip).take(room) {
            if self.channels == 1 {
                self.scratch.push((left + right) * 0.5);
            } else {
                self.scratch.extend_from_slice(&[left, right]);
                self.scratch
                    .extend(repeat_n(0.0, self.channels - ENGINE_CHANNELS));
            }
            written += 1;
        }
        self.output_frames += written;
        if self.scratch.is_empty() {
            return Ok(());
        }
        self.writer
            .write(&self.scratch)
            .map_err(|e| AudioExportError::new("Writer", format!("Write error: {e}")))
    }

    /// Flushes the resampler and finalizes the file.
    fn finish(mut self) -> Result<(), AudioExportError> {
        if let Some((call_frames, delay)) = self.bridge.as_ref().map(|bridge| {
            (
                bridge.maximum_input_frames().max(1),
                bridge.output_delay_frames(),
            )
        }) {
            // Feed silence until the resampler has given out every accepted frame. Its delay,
            // in input frames, plus a few calls bounds how many calls that takes.
            let calls = (delay as f64 / self.ratio / call_frames as f64).ceil() as usize + 3;
            for _ in 0..calls {
                if self.output_frames >= self.target_frames() {
                    break;
                }
                let needed = self
                    .bridge
                    .as_ref()
                    .map_or(0, DeviceRateBridge::input_frames_next)
                    * ENGINE_CHANNELS;
                let missing = needed.saturating_sub(self.pending.len());
                self.pending.extend(repeat_n(0.0, missing));
                self.resample_pending()?;
            }
        }
        self.writer
            .finalize()
            .map_err(|e| AudioExportError::new("Writer", format!("Finalize error: {e}")))
    }

    /// Abandons a cancelled render. The staged file is deleted with its [`StagedOutput`].
    fn cancel(self) -> Result<(), AudioExportError> {
        tracing::info!("Export cancelled");
        Err(AudioExportError::new(
            EXPORT_CANCELLED,
            "The export was cancelled",
        ))
    }
}

/// A render's file while it is written: a hidden sibling of the target that replaces the target
/// only once the render has finished. A cancelled or failed render deletes it on drop and leaves
/// any earlier file at the target untouched.
struct StagedOutput {
    staging: PathBuf,
    target: PathBuf,
}

impl StagedOutput {
    fn new(target: &Path) -> Self {
        let name = target
            .file_name()
            .map_or_else(|| "export".into(), |name| name.to_string_lossy());
        Self {
            staging: target.with_file_name(format!(".{name}.partial")),
            target: target.to_path_buf(),
        }
    }

    /// Moves the finished file over the target.
    fn commit(self) -> Result<(), AudioExportError> {
        rename(&self.staging, &self.target).map_err(|error| {
            AudioExportError::new("Writer", format!("Failed to save the export: {error}"))
        })
        // Drop then finds no staged file left to remove.
    }
}

impl Drop for StagedOutput {
    fn drop(&mut self) {
        match remove_file(&self.staging) {
            Ok(()) => {}
            Err(error) if error.kind() == ErrorKind::NotFound => {}
            Err(error) => tracing::warn!(
                "Failed to remove the unfinished export {}: {error}",
                self.staging.display()
            ),
        }
    }
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
    position: &mut rtrb::Consumer<TransportFeedback>,
    feedback: &mut rtrb::Consumer<AudioFeedback>,
) {
    while position.pop().is_ok() {}
    while feedback.pop().is_ok() {}
}

/// Runs the stopped engine at a real-time pace so hosted plugins finish restoring their state.
///
/// Native plugins apply restored state from their process callback, often after a worker
/// thread has loaded files; LSP's samplers load their samples and its convolution reverbs their
/// impulse responses this way. An offline render outruns that work, so the timeline would
/// otherwise start on plugins that are still loading, and a sampler would drop its first note.
/// Instruments are woken for every block, since a parked one gets no process calls. Settling
/// lasts `settle`, and longer while a plugin reports pending work, up to `limit`. Renders without
/// hosted plugins skip the wait.
fn settle_hosted_plugins(
    engine: &mut AudioEngine,
    buffer: &mut [f32],
    settle: Duration,
    limit: Duration,
    position: &mut rtrb::Consumer<TransportFeedback>,
    feedback: &mut rtrb::Consumer<AudioFeedback>,
) -> Result<(), AudioExportError> {
    if !engine.has_hosted_plugins() {
        return Ok(());
    }
    let started = Instant::now();
    loop {
        engine.wake_hosted_generators();
        engine.process(buffer);
        validate_rendered_block(engine, buffer)?;
        drain_engine_feedback(position, feedback);
        let elapsed = started.elapsed();
        if elapsed >= settle && !engine.has_pending_plugin_work() {
            return Ok(());
        }
        if elapsed >= limit {
            tracing::warn!("Hosted plugins still report pending work after {elapsed:?}");
            return Ok(());
        }
        sleep(HOSTED_SETTLE_INTERVAL);
    }
}

/// Renders the next block after the reported tail; `false` once the engine has gone silent.
fn render_ring_out_block(
    engine: &mut AudioEngine,
    buffer: &mut [f32],
) -> Result<bool, AudioExportError> {
    engine.process(buffer);
    validate_rendered_block(engine, buffer)?;
    Ok(buffer.iter().any(|sample| sample.abs() >= RING_OUT_SILENCE))
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

#[cfg(test)]
#[allow(
    clippy::unwrap_used,
    reason = "export fixtures assert setup and file preservation"
)]
mod tests {
    use super::*;
    use crate::{
        commands::{EffectTarget, MixerChannelTarget},
        engine::{
            AudioEngineTelemetry,
            tests::{IdleProbe, song_engine_with_ramp_clip},
        },
        event::PluginTarget,
        hosted_plugin::HostedPluginInstall,
        writer::{BitDepth, BitPerSample, wav::WavAudioWriterConfig},
    };
    use karbeat_core::{
        core::project::{
            ApplicationState, ExternalPluginInstance, GeneratorInstanceType, MixerChannelParams,
            PluginInstance,
        },
        shared::EffectId,
    };
    use karbeat_host::{
        HostInstanceId, HostedProcessor, PluginDescriptor, PluginFormat, PluginIdentity,
        PluginKind, ProcessingConfig,
    };
    use karbeat_plugin_api::traits::AudioPluginBuilder;
    use karbeat_plugins::effect::delay::DigidawDelay;
    use karbeat_utils::hash::hash_str;
    use std::{
        fs::{read, read_dir, write},
        sync::{
            Arc,
            atomic::{AtomicUsize, Ordering},
            mpsc::sync_channel,
        },
    };

    fn engine() -> AudioEngine {
        let (_, commands) = RingBuffer::new(8);
        let (position, _) = RingBuffer::new(8);
        let (feedback, _) = RingBuffer::new(8);
        let (telemetry, _) = sync_channel(8);
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
        write(&path, b"previous export").unwrap();
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
        assert_eq!(read(path).unwrap(), b"previous export");
        drop(engine);
        assert!(retirement.take().is_some());
    }

    /// Installs a hosted effect on the master that rings for `ringing` blocks and counts its
    /// process calls.
    fn engine_with_hosted_ringing_effect(
        ringing: usize,
    ) -> (
        AudioEngine,
        Arc<AtomicUsize>,
        karbeat_host::ProcessorRetirement,
    ) {
        let mut engine = engine();
        let calls = Arc::new(AtomicUsize::new(0));
        let mut endpoint = Box::new(HostedProcessor::new(
            Box::new(IdleProbe {
                calls: calls.clone(),
                ringing,
                continuous: false,
            }),
            HostInstanceId(7),
        ));
        // This fixture deliberately generates audio without input, so it opts into continuous
        // processing like a hosted effect that scans or produces on its own.
        endpoint.set_continuous_processing(true);
        let (processor, retirement) = endpoint.prepare_transfer().unwrap();
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
        // Publishing the routing schedules the master node, as loading any project does.
        engine.process_command(AudioCommand::UpdateRouting {
            routing: Box::default(),
        });
        (engine, calls, retirement)
    }

    #[test]
    fn settling_gives_hosted_effects_blocks_without_moving_the_timeline() {
        let (_, mut position) = RingBuffer::new(1);
        let (_, mut feedback) = RingBuffer::new(1);
        let mut buffer = vec![0.0; 512];

        // Without hosted effects there is nothing to wait for.
        let started = Instant::now();
        settle_hosted_plugins(
            &mut engine(),
            &mut buffer,
            Duration::from_secs(30),
            Duration::from_secs(30),
            &mut position,
            &mut feedback,
        )
        .unwrap();
        assert!(started.elapsed() < Duration::from_secs(5));

        let (mut engine, calls, mut retirement) = engine_with_hosted_ringing_effect(0);
        settle_hosted_plugins(
            &mut engine,
            &mut buffer,
            Duration::from_millis(50),
            Duration::from_secs(5),
            &mut position,
            &mut feedback,
        )
        .unwrap();
        assert!(calls.load(Ordering::Relaxed) > 0);
        assert_eq!(engine.get_export_length(), 0);
        drop(engine);
        assert!(retirement.take().is_some());
    }

    #[test]
    fn ring_out_lasts_until_hosted_effects_fall_silent() {
        let (mut engine, _, mut retirement) = engine_with_hosted_ringing_effect(5);
        // The effect reports no tail, so only listening reveals that it still rings.
        assert_eq!(engine.get_project_tail_length(), 0);
        let mut buffer = vec![0.0; 512];
        let mut audible_blocks = 0;
        while render_ring_out_block(&mut engine, &mut buffer).unwrap() {
            audible_blocks += 1;
            assert!(audible_blocks <= 5);
        }
        assert_eq!(audible_blocks, 5);
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
        let error = render_ramp(
            &song_engine_with_ramp_clip(),
            region(960, 960, RenderPurpose::Export),
        )
        .unwrap_err();
        assert_eq!(error.error_source, "Range");
    }

    #[test]
    fn bounces_skip_the_master_fader() {
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

    /// Renders the whole song to a 32-bit float WAV at `sample_rate` with `channels`, and reads
    /// back the interleaved samples.
    fn render_song(engine: &AudioEngine, sample_rate: u32, channels: u16) -> Vec<f32> {
        let directory = tempfile::tempdir().unwrap();
        let path = directory.path().join("song.wav");
        render_snapshot(
            engine.export_snapshot(),
            path.to_str().unwrap(),
            AudioExportConfig::Wav(WavAudioWriterConfig {
                sample_rate,
                channels,
                bit_depth: BitDepth::BitPerSample(BitPerSample::B32),
            }),
            &AudioMetadata::default(),
            RenderOptions::default(),
            PluginRegistry::new_with_defaults(),
            karbeat_host::HostClient::unavailable(),
            hashbrown::HashMap::new(),
            &mut |_| true,
        )
        .unwrap();
        let mut reader = hound::WavReader::open(&path).unwrap();
        assert_eq!(reader.spec().sample_rate, sample_rate);
        assert_eq!(reader.spec().channels, channels);
        reader.samples::<f32>().map(Result::unwrap).collect()
    }

    #[test]
    fn delay_compensation_does_not_shift_the_export() {
        let mut engine = song_engine_with_ramp_clip();
        let registry = PluginRegistry::new_with_defaults();
        let registry_id = hash_str("effect_pitch_shifter");
        let (effect_factory, _) = registry.create_plugin_by_id(registry_id).unwrap();
        engine.process_command(AudioCommand::AddEffect {
            target: EffectTarget::Master,
            effect_id: EffectId::from(1),
            registry_id,
            effect_factory,
        });
        engine.process(&mut [0.0; 1_024 * 2]);
        let latency = engine.system_latency();
        assert!(latency > 2_000, "the shifter must delay the mix: {latency}");

        let left: Vec<f32> = render_song(&engine, RENDER_RATE, 2)
            .chunks(2)
            .map(|frame| frame[0])
            .collect();
        // The whole song, not shortened by the latency.
        assert_eq!(left.len(), 96_000);
        // The ramp reaches 0.5 by frame 500; uncompensated, the file opened with `latency`
        // frames of silence.
        assert!(
            left[..2_000].iter().any(|sample| sample.abs() > 0.05),
            "the export starts with silence"
        );
    }

    #[test]
    fn exports_at_another_rate_are_resampled_after_rendering() {
        let engine = song_engine_with_ramp_clip();
        let native = render_song(&engine, RENDER_RATE, 2);
        let resampled = render_song(&engine, 44_100, 2);
        // Two seconds at either rate.
        assert_eq!(native.len(), 96_000 * 2);
        assert_eq!(resampled.len(), 88_200 * 2);
        // The ramp keeps its timing: its first wrap, frame 1,000 at 48 kHz, lands at frame
        // ~919 at 44.1 kHz. Band-limiting spreads the drop over a few frames, so the wrap is
        // where the ramp first falls below half its peak after rising.
        let first_wrap = |interleaved: &[f32]| {
            let left: Vec<f32> = interleaved.chunks(2).map(|frame| frame[0]).collect();
            let peak = left[..2_000].iter().fold(0.0_f32, |peak, s| peak.max(*s));
            let top = left.iter().position(|s| *s > peak * 0.9).unwrap();
            top + left[top..].iter().position(|s| *s < peak * 0.5).unwrap()
        };
        assert_eq!(first_wrap(&native), 1_000);
        let wrap = first_wrap(&resampled);
        assert!((915..=923).contains(&wrap), "wrap at {wrap}");
    }

    #[test]
    fn mono_exports_mix_both_channels_at_full_length() {
        let engine = song_engine_with_ramp_clip();
        let stereo = render_song(&engine, RENDER_RATE, 2);
        let mono = render_song(&engine, RENDER_RATE, 1);
        assert_eq!(mono.len(), 96_000);
        for (index, (mono, frame)) in mono.iter().zip(stereo.chunks(2)).enumerate() {
            let mixed = (frame[0] + frame[1]) * 0.5;
            assert!(
                (mono - mixed).abs() < 1e-6,
                "frame {index}: {mono} != {mixed}"
            );
        }
    }

    #[test]
    fn a_clip_from_the_source_start_opens_at_full_level() {
        // The ramp source reads frame k as k / 1,000, and the master's centre pan halves it.
        // An anti-click fade-in once silenced the first frames of every clip.
        let left = render_ramp(&song_engine_with_ramp_clip(), RenderOptions::default()).unwrap();
        for (frame, sample) in left.iter().enumerate().take(200) {
            let expected = frame as f32 / 1_000.0 * 0.5;
            assert!(
                (sample - expected).abs() < 1e-5,
                "frame {frame}: {sample} != {expected}"
            );
        }
    }

    #[test]
    fn cancelling_keeps_the_earlier_file_and_leaves_no_partial_render() {
        let engine = song_engine_with_ramp_clip();
        let directory = tempfile::tempdir().unwrap();
        let path = directory.path().join("song.wav");
        write(&path, b"previous export").unwrap();
        let mut calls = 0;
        let error = render_snapshot(
            engine.export_snapshot(),
            path.to_str().unwrap(),
            AudioExportConfig::Wav(WavAudioWriterConfig {
                sample_rate: RENDER_RATE,
                channels: 2,
                bit_depth: BitDepth::BitPerSample(BitPerSample::B16),
            }),
            &AudioMetadata::default(),
            RenderOptions::default(),
            PluginRegistry::new_with_defaults(),
            karbeat_host::HostClient::unavailable(),
            hashbrown::HashMap::new(),
            &mut |_| {
                calls += 1;
                calls < 3
            },
        )
        .unwrap_err();
        assert!(error.is_cancelled(), "{error}");
        assert_eq!(read(&path).unwrap(), b"previous export");
        let left: Vec<_> = read_dir(directory.path())
            .unwrap()
            .map(|entry| entry.unwrap().file_name())
            .collect();
        assert_eq!(left, ["song.wav"]);
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
