use crate::{
    apply_mix_param,
    commands::{AudioCommand, AudioFeedback, EffectTarget, TelemetryRegistration},
    dsp_engine::{AudioWorkerPool, LevelJob, MAX_DSP_WORKERS},
    engine::{
        buffer::AudioBuffer,
        helper::*,
        input::{InputCapture, InputSource, InputState},
        metronome::MetronomeState,
        modulation::{LiveModulationSource, ModulationState},
        record::{RecordBlock, RecordState, RecordTake},
        render_plan::{
            BlockCtx, GatherSources, PlanGraph, PlanNodeKind, RenderJob, RenderPlan, SendPtr,
            group_voices_by_track, voice_range,
        },
        routing::RoutingState,
        runtime::*,
        schedule::{ClipSchedule, clip_span_samples},
        telemetry::{AudioEngineTelemetry, PluginTelemetrySnapshot},
        transport::{PlaybackMode, TransportState},
        types::*,
        voices::{ClipSpan, GeneratorVoice, NeighbourCrossfade, VoiceState},
        workspace::RenderWorkspace,
    },
    event::{FeedbackTiming, PluginTarget, TransportFeedback},
    render_state::{
        AudioAutomationLane, AudioEffectInstance, AudioGraphState, AudioPluginSnapshotState,
        AudioPluginState, AudioRenderState,
    },
};
use hashbrown::{HashMap, HashSet};
use karbeat_core::{core::project::*, shared::constants::f64::PPQ};
use karbeat_host::{HostError, HostInstanceId, PreparedProcessor};
use karbeat_plugins::registry::PluginRegistry;
use rtrb::{Consumer, Producer};
use smallvec::SmallVec;
use std::sync::mpsc;
use thiserror::Error;

pub struct AudioEngine {
    pub(super) io: EngineIo,

    // ======================================
    // Graph State (owned by audio thread)
    // Updated exclusively via ring-buffer commands — no triple-buffer
    // ======================================
    pub(super) current_state: AudioRenderState,

    pub(super) config: AudioEngineConfig,
    pub(super) processing_mode: ProcessingMode,
    pub(super) transport: TransportState,

    pub(super) voices: VoiceState,

    // Audio thread's owned plugins - NO locks required
    pub(super) plugin_state: AudioPluginState,

    // Audio-thread-owned mixer channel DSP state.
    // Updated via SetMixerChannelParameter commands; queried via QueryMixerChannel.
    pub(super) mixer_state: AudioMixerState,

    pub(super) workspace: RenderWorkspace,
    pub(super) routing: RoutingState,
    pub(super) modulation: ModulationState,

    //////////////////////////////////////////////////
    /// Metronome state
    /////////////////////////////////////////////////
    pub(super) metronome_state: MetronomeState,

    pub(super) telemetry: AudioEngineTelemetry,
    pub(super) graph_retirement: Producer<RetiredGraphState>,

    /// Offline bounces render what feeds the master bus, skipping its effects and fader.
    pub(super) bypass_master: bool,

    /// Clip spans per track for the current graph and tempo.
    pub(super) clip_schedule: ClipSchedule,

    /// The routing graph compiled for the worker pool.
    pub(super) render_plan: RenderPlan,
    /// Threads that render the graph alongside this one; `None` renders serially.
    pub(super) workers: Option<AudioWorkerPool>,
    /// Device input feeding level −1 of the graph.
    pub(super) input: InputState,
    /// Takes recorded from the device input.
    pub(super) record: RecordState,
}

pub(super) enum RetiredGraphState {
    Full(AudioGraphState),
    Tracks {
        tracks: Box<[AudioTrack]>,
        clips: HashMap<ClipId, Clip>,
        patterns: HashMap<PatternId, Pattern>,
    },
    Routing(Box<[RoutingConnection]>),
    Automation(AudioAutomationLane),
    AudioBuffer(Vec<f32>),
    AudioSource(std::sync::Arc<AudioWaveform>),
    TelemetryProducer(triple_buffer::Input<PluginTelemetrySnapshot>),
    TelemetrySubscription(HashSet<String>),
    RenderPlan(Box<RenderPlan>),
    RecordTake(Box<RecordTake>),
}

/// Hands `retired` to the retirement thread; a full queue leaks it rather than freeing it on
/// the audio thread.
fn push_retired(queue: &mut Producer<RetiredGraphState>, retired: RetiredGraphState) {
    if let Err(rtrb::PushError::Full(retired)) = queue.push(retired) {
        std::mem::forget(retired);
    }
}

fn graph_retirement_queue() -> Producer<RetiredGraphState> {
    let (producer, mut consumer) = rtrb::RingBuffer::new(128);
    std::thread::spawn(move || {
        loop {
            // Checked before pop: once abandoned no push can follow, so empty is final.
            let abandoned = consumer.is_abandoned();
            match consumer.pop() {
                Ok(retired) => match retired {
                    RetiredGraphState::Full(graph) => drop(graph),
                    RetiredGraphState::Tracks {
                        tracks,
                        clips,
                        patterns,
                    } => drop((tracks, clips, patterns)),
                    RetiredGraphState::Routing(routes) => drop(routes),
                    RetiredGraphState::Automation(lane) => drop(lane),
                    RetiredGraphState::AudioBuffer(buffer) => drop(buffer),
                    RetiredGraphState::AudioSource(waveform) => drop(waveform),
                    RetiredGraphState::TelemetryProducer(producer) => drop(producer),
                    RetiredGraphState::TelemetrySubscription(subscription) => drop(subscription),
                    RetiredGraphState::RenderPlan(plan) => drop(plan),
                    RetiredGraphState::RecordTake(take) => drop(take),
                },
                Err(rtrb::PopError::Empty) if abandoned => break,
                Err(rtrb::PopError::Empty) => {
                    std::thread::sleep(std::time::Duration::from_millis(10));
                }
            }
        }
    });
    producer
}

/// Live-engine data and separately prepared endpoints used to construct an offline renderer.
pub struct AudioExportSnapshot {
    render_state: AudioRenderState,
    config: AudioEngineConfig,
    bpm: f32,
    time_sig_numerator: u8,
    time_sig_denominator: u8,
    bus_ids: Vec<BusId>,
    plugin_snapshot_state: AudioPluginSnapshotState,
    mixer_state: AudioMixerState,
    modulation: ModulationState,
    hosted_processors: HashMap<HostInstanceId, PreparedProcessor>,
    bypass_master: bool,
}

#[derive(Debug, Error)]
pub enum AudioExportSnapshotError {
    #[error("plugin registry ID {registry_id} is unavailable while hydrating the export engine")]
    PluginNotFound { registry_id: u32 },
    #[error("hosted plugin {instance:?} could not be prepared for export: {source}")]
    HostedPlugin {
        instance: HostInstanceId,
        #[source]
        source: HostError,
    },
}

impl AudioExportSnapshot {
    /// Renders what feeds the master bus instead of its output: master effects, fader, pan,
    /// and master automation are skipped. Tracks and buses play as they do live.
    ///
    /// The render is compensated for the centre pan law of the channel it will play back on,
    /// so it sounds like the original on a new track at 0 dB and centre pan.
    pub fn without_master(mut self) -> Self {
        self.bypass_master = true;
        self
    }

    /// Project tempo the snapshot renders at.
    pub fn bpm(&self) -> f32 {
        self.bpm
    }

    pub fn hosted_instance(&self, target: PluginTarget) -> Option<HostInstanceId> {
        match target {
            PluginTarget::Generator(id) => self
                .plugin_snapshot_state
                .generators
                .iter()
                .find(|plugin| plugin.id == id)
                .and_then(|plugin| plugin.host_instance),
            PluginTarget::TrackEffect(track, id) => self
                .plugin_snapshot_state
                .track_effects
                .get(usize::try_from(track.to_u32()).ok()?)?
                .iter()
                .find(|plugin| plugin.id == id)
                .and_then(|plugin| plugin.host_instance),
            PluginTarget::BusEffect(bus, id) => self
                .plugin_snapshot_state
                .bus_effects
                .get(usize::try_from(bus.to_u32()).ok()?)?
                .iter()
                .find(|plugin| plugin.id == id)
                .and_then(|plugin| plugin.host_instance),
            PluginTarget::MasterEffect(id) => self
                .plugin_snapshot_state
                .master_effects
                .iter()
                .find(|plugin| plugin.id == id)
                .and_then(|plugin| plugin.host_instance),
        }
    }

    /// Run on a control worker. Commit prepared endpoints only after every capture succeeds.
    pub fn prepare_hosted(
        &mut self,
        mut prepare: impl FnMut(HostInstanceId) -> Result<PreparedProcessor, HostError>,
    ) -> Result<(), AudioExportSnapshotError> {
        let ids = self
            .plugin_snapshot_state
            .generators
            .iter()
            .filter_map(|plugin| plugin.host_instance)
            .chain(
                self.plugin_snapshot_state
                    .track_effects
                    .iter()
                    .flatten()
                    .filter_map(|plugin| plugin.host_instance),
            )
            .chain(
                self.plugin_snapshot_state
                    .bus_effects
                    .iter()
                    .flatten()
                    .filter_map(|plugin| plugin.host_instance),
            )
            .chain(
                self.plugin_snapshot_state
                    .master_effects
                    .iter()
                    .filter_map(|plugin| plugin.host_instance),
            );
        let mut prepared = HashMap::new();
        for instance in ids {
            if prepared.contains_key(&instance) || !self.hosted_processors.is_empty() {
                return Err(AudioExportSnapshotError::HostedPlugin {
                    instance,
                    source: HostError::InvalidTransition,
                });
            }
            let processor = prepare(instance)
                .map_err(|source| AudioExportSnapshotError::HostedPlugin { instance, source })?;
            prepared.insert(instance, processor);
        }
        self.hosted_processors = prepared;
        Ok(())
    }
}

impl AudioEngine {
    /// Ends `take` and hands it to the retirement thread, which drops its ring producer.
    pub(super) fn retire_record_take(&mut self, mut take: Box<RecordTake>) {
        take.end();
        self.retire_graph_state(RetiredGraphState::RecordTake(take));
    }

    pub(super) fn retire_graph_state(&mut self, retired: RetiredGraphState) {
        push_retired(&mut self.graph_retirement, retired);
    }

    #[allow(
        clippy::too_many_arguments,
        reason = "It is still okay to have this number of param for instantiation"
    )]
    pub fn new(
        command_consumer: Consumer<AudioCommand>,
        position_producer: Producer<TransportFeedback>,
        feedback_producer: Producer<AudioFeedback>,
        sample_rate: u32,
        num_channels: u16,
        initial_bpm: f32,
        buffer_size: usize,
        telemetry: AudioEngineTelemetry,
        telemetry_reg_sender: mpsc::SyncSender<TelemetryRegistration>,
    ) -> Self {
        // Seed the graph snapshot with the real audio config so that
        // AddGenerator / AddEffect commands that arrive before the first
        // ReplaceFullGraph have a valid sample_rate and buffer_size to
        // prepare plugins with, rather than the default 0 / 0.
        let mut initial_state = AudioRenderState::default();
        initial_state.graph.sample_rate = sample_rate;
        initial_state.graph.buffer_size = buffer_size;
        let mut voices = VoiceState::new();
        voices.stretch_pool.prepare(sample_rate);

        Self {
            io: EngineIo {
                command_consumer,
                position_producer,
                feedback_producer,
                telemetry_reg_sender,
            },
            current_state: initial_state,
            config: AudioEngineConfig::new(sample_rate, num_channels),
            processing_mode: ProcessingMode::Realtime,
            transport: TransportState::new(initial_bpm),
            voices,
            plugin_state: AudioPluginState::default(),
            mixer_state: AudioMixerState::default(),
            workspace: RenderWorkspace::new(buffer_size, num_channels),
            routing: RoutingState::default(),
            modulation: ModulationState::default(),
            metronome_state: MetronomeState::default(),
            telemetry,
            graph_retirement: graph_retirement_queue(),
            bypass_master: false,
            clip_schedule: ClipSchedule::default(),
            render_plan: RenderPlan::default(),
            workers: None,
            input: InputState::default(),
            record: RecordState::with_block(buffer_size),
        }
    }

    /// Captures only the live engine state required for offline rendering.
    pub fn export_snapshot(&self) -> AudioExportSnapshot {
        AudioExportSnapshot {
            render_state: self.current_state.clone(),
            config: self.config,
            bpm: self.transport.bpm,
            time_sig_numerator: self.transport.time_sig_numerator,
            time_sig_denominator: self.transport.time_sig_denominator,
            bus_ids: self.workspace.bus_buffers.keys().copied().collect(),
            plugin_snapshot_state: AudioPluginSnapshotState::from(&self.plugin_state),
            mixer_state: self.mixer_state.clone(),
            modulation: self.modulation.for_export(),
            hosted_processors: HashMap::new(),
            bypass_master: false,
        }
    }

    /// Builds a fresh offline renderer from a read-only live-engine snapshot.
    pub fn from_export_snapshot(
        snapshot: AudioExportSnapshot,
        plugin_registry: &PluginRegistry,
        num_channels: u16,
        command_consumer: Consumer<AudioCommand>,
        position_producer: Producer<TransportFeedback>,
        feedback_producer: Producer<AudioFeedback>,
    ) -> Result<Self, AudioExportSnapshotError> {
        let AudioExportSnapshot {
            render_state,
            mut config,
            bpm,
            time_sig_numerator,
            time_sig_denominator,
            bus_ids,
            plugin_snapshot_state,
            mixer_state,
            modulation,
            mut hosted_processors,
            bypass_master,
        } = snapshot;
        config.num_channels = num_channels;

        let mut transport = TransportState::new(bpm);
        transport.time_sig_numerator = time_sig_numerator;
        transport.time_sig_denominator = time_sig_denominator;

        let mut workspace =
            RenderWorkspace::new(render_state.graph.buffer_size, config.num_channels);
        for &bus_id in &bus_ids {
            workspace.prepare_bus(bus_id);
        }
        for route in &render_state.graph.routing {
            if let RoutingNode::PluginSidechain(sidechain) = route.destination {
                workspace.prepare_sidechain(sidechain);
            }
        }

        let mut routing = RoutingState::default();
        routing.cached_order = compute_routing_order(
            &render_state.graph.tracks,
            bus_ids.into_iter(),
            &render_state.graph.routing,
        );
        routing.set_routes(&render_state.graph.routing);

        let sample_rate = config.sample_rate as f32;
        let buffer_size = render_state.graph.buffer_size.max(512);
        let channels = config.num_channels as usize;
        let mut plugin_state = AudioPluginState::default();

        for generator in plugin_snapshot_state.generators {
            let plugin = Self::plugin_from_snapshot(
                plugin_registry,
                generator.registry_id,
                &generator.serialized_state,
                generator.host_instance,
                generator.host_bypass,
                &mut hosted_processors,
                sample_rate,
                buffer_size,
                channels,
            )?;
            plugin_state.insert_generator(crate::render_state::AudioGeneratorInstance {
                id: generator.id,
                track_id: generator.track_id,
                registry_id: generator.registry_id,
                plugin,
            });
        }

        plugin_state.track_effects = Self::effects_from_snapshot(
            plugin_snapshot_state.track_effects,
            &mut hosted_processors,
            plugin_registry,
            sample_rate,
            buffer_size,
            channels,
        )?;
        plugin_state.master_effects = Self::effect_chain_from_snapshot(
            plugin_snapshot_state.master_effects,
            &mut hosted_processors,
            plugin_registry,
            sample_rate,
            buffer_size,
            channels,
        )?;
        plugin_state.bus_effects = Self::effects_from_snapshot(
            plugin_snapshot_state.bus_effects,
            &mut hosted_processors,
            plugin_registry,
            sample_rate,
            buffer_size,
            channels,
        )?;

        let mut voices = VoiceState::for_export();
        voices.stretch_pool.prepare(config.sample_rate);
        let mut engine = Self {
            io: EngineIo {
                command_consumer,
                position_producer,
                feedback_producer,
                telemetry_reg_sender: mpsc::sync_channel(0).0,
            },
            current_state: render_state,
            config,
            processing_mode: ProcessingMode::Offline,
            transport,
            voices,
            plugin_state,
            mixer_state,
            workspace,
            routing,
            modulation,
            metronome_state: MetronomeState::default(),
            telemetry: AudioEngineTelemetry::new_for_export(),
            graph_retirement: graph_retirement_queue(),
            bypass_master,
            clip_schedule: ClipSchedule::default(),
            render_plan: RenderPlan::default(),
            workers: None,
            input: InputState::default(),
            record: RecordState::with_block(buffer_size),
        };
        engine.recalculate_latencies();
        Ok(engine)
    }

    fn effects_from_snapshot(
        chains: Vec<Vec<crate::render_state::EffectPluginSnapshot>>,
        hosted_processors: &mut HashMap<HostInstanceId, PreparedProcessor>,
        plugin_registry: &PluginRegistry,
        sample_rate: f32,
        buffer_size: usize,
        channels: usize,
    ) -> Result<Vec<Vec<AudioEffectInstance>>, AudioExportSnapshotError> {
        chains
            .into_iter()
            .map(|chain| {
                Self::effect_chain_from_snapshot(
                    chain,
                    hosted_processors,
                    plugin_registry,
                    sample_rate,
                    buffer_size,
                    channels,
                )
            })
            .collect()
    }

    fn effect_chain_from_snapshot(
        chain: Vec<crate::render_state::EffectPluginSnapshot>,
        hosted_processors: &mut HashMap<HostInstanceId, PreparedProcessor>,
        plugin_registry: &PluginRegistry,
        sample_rate: f32,
        buffer_size: usize,
        channels: usize,
    ) -> Result<Vec<AudioEffectInstance>, AudioExportSnapshotError> {
        chain
            .into_iter()
            .map(|effect| {
                let plugin = Self::plugin_from_snapshot(
                    plugin_registry,
                    effect.registry_id,
                    &effect.serialized_state,
                    effect.host_instance,
                    effect.host_bypass,
                    hosted_processors,
                    sample_rate,
                    buffer_size,
                    channels,
                )?;
                Ok(AudioEffectInstance {
                    id: effect.id,
                    registry_id: effect.registry_id,
                    plugin,
                    bypass: effect.bypass,
                })
            })
            .collect()
    }

    fn plugin_from_snapshot(
        plugin_registry: &PluginRegistry,
        registry_id: u32,
        state: &[u8],
        host_instance: Option<HostInstanceId>,
        host_bypass: bool,
        hosted_processors: &mut HashMap<HostInstanceId, PreparedProcessor>,
        sample_rate: f32,
        buffer_size: usize,
        channels: usize,
    ) -> Result<Box<dyn AudioPlugin>, AudioExportSnapshotError> {
        if let Some(instance) = host_instance {
            let endpoint = hosted_processors.remove(&instance).ok_or(
                AudioExportSnapshotError::HostedPlugin {
                    instance,
                    source: HostError::InvalidState(
                        "fresh native export state was not prepared".into(),
                    ),
                },
            )?;
            let mut plugin = endpoint
                .install()
                .map_err(|source| AudioExportSnapshotError::HostedPlugin { instance, source })?;
            plugin.set_bypass(host_bypass);
            return Ok(plugin);
        }
        let (factory, _) = plugin_registry
            .create_plugin_by_id(registry_id)
            .ok_or(AudioExportSnapshotError::PluginNotFound { registry_id })?;
        let mut plugin = factory();
        plugin.set_state(state);
        plugin.prepare(sample_rate, buffer_size);
        let bus = BusConfig {
            name: "Main".into(),
            channel_count: channels,
            is_optional: false,
        };
        plugin.set_io_layout(std::slice::from_ref(&bus), std::slice::from_ref(&bus));
        Ok(plugin)
    }

    pub fn plugin_state(&self) -> &AudioPluginState {
        &self.plugin_state
    }

    /// Renders one interleaved block into any storage exposing mutable audio samples.
    pub fn process<B: AudioBuffer + ?Sized>(&mut self, output_buffer: &mut B) {
        self.process_interleaved(output_buffer.samples_mut());
    }

    fn process_interleaved(&mut self, output_buffer: &mut [f32]) {
        let block_start_frame = self.transport.render_frame;
        for changes in self.modulation.block_param_changes.values_mut() {
            changes.clear();
        }

        // Process Commands (Play, Stop, Seek, Graph updates)
        while let Ok(cmd) = self.io.command_consumer.pop() {
            self.process_command(cmd);
        }

        // Poll every plugin; latency flags are edge-triggered and must all be consumed.
        let plugin_latency_changed = itertools::chain!(
            self.plugin_state
                .generators
                .iter_mut()
                .map(|(_, generator)| &mut generator.plugin),
            self.plugin_state
                .track_effects
                .iter_mut()
                .flatten()
                .map(|effect| &mut effect.plugin),
            self.plugin_state
                .bus_effects
                .iter_mut()
                .flatten()
                .map(|effect| &mut effect.plugin),
            self.plugin_state
                .master_effects
                .iter_mut()
                .map(|effect| &mut effect.plugin),
        )
        .fold(false, |changed, plugin| {
            plugin.has_latency_changed() || changed
        });

        if plugin_latency_changed || self.routing.latency_dirty {
            self.recalculate_latencies();
        }

        // Clear Buffer
        output_buffer.fill(0.0);
        let channels = 2;
        let frame_count = output_buffer.len() / channels;
        self.input.capture(frame_count);
        self.record_block(frame_count);

        // Transport Logic
        let is_currently_playing = self.transport.is_playing();

        if is_currently_playing {
            match self.transport.mode {
                PlaybackMode::Song => {
                    self.process_song_mode(frame_count, output_buffer, channels);
                }
                PlaybackMode::Pattern {
                    pattern_id,
                    generator_id,
                } => {
                    self.process_pattern_mode(
                        pattern_id,
                        generator_id,
                        frame_count,
                        output_buffer,
                        channels,
                    );
                }
            }
        } else {
            self.render_voices_to_buffer(output_buffer, channels, false);
            self.cleanup_finished_voices(frame_count);
        }

        // Always Render Previews (Metronome, Browser Preview)
        self.render_previews_to_buffer(output_buffer, channels);

        // Clock the mixer state snapshot
        if self.telemetry.advance(frame_count, self.config.sample_rate) {
            self.emit_all_mixer_snapshots();
            self.emit_plugin_telemetry();
        }

        self.transport.render_frame = block_start_frame + frame_count as u64;
    }

    /// Copies the captured input block into the armed takes while the song plays, and ends
    /// the takes that started once it stops. Real-time safe.
    fn record_block(&mut self, frames: usize) {
        if !self.record.is_armed() {
            return;
        }
        let queue = &mut self.graph_retirement;
        let mut retire = |mut take: Box<RecordTake>| {
            take.end();
            push_retired(queue, RetiredGraphState::RecordTake(take));
        };
        let song_playing =
            matches!(self.transport.mode, PlaybackMode::Song) && self.transport.song.is_playing;
        if song_playing {
            let block = RecordBlock {
                device: self.input.block(frames),
                device_channels: self.input.device_channels(),
                frames,
                playhead_samples: u64::from(self.transport.song.playhead_samples),
                render_frame: self.transport.render_frame,
                input_frame: self.input.block_input_frame(),
            };
            self.record.record(&block, &mut retire);
        } else {
            self.record.end_started(&mut retire);
        }
        self.transport.song.is_recording = self.record.is_armed();
    }

    /// Installs the device input stream that feeds level −1, returning the previous one.
    /// Allocates; call when the input stream starts.
    pub fn attach_input(&mut self, capture: InputCapture) -> Option<InputCapture> {
        let block_frames = self.current_state.graph.buffer_size.max(1);
        self.input.attach(capture, block_frames)
    }

    /// Removes the device input stream.
    pub fn detach_input(&mut self) -> Option<InputCapture> {
        self.input.detach()
    }

    /// Whether the input of the next block of `frames` has arrived. Always true without an
    /// input stream.
    pub fn input_ready(&self, frames: usize) -> bool {
        self.input.ready(frames)
    }

    /// How much faster the input device's clock runs than the engine's, in parts per million.
    pub fn input_drift_ppm(&self) -> f64 {
        self.input.drift_ppm()
    }

    /// Blocks rendered with silent input because the device input fell behind.
    pub fn input_underruns(&self) -> u64 {
        self.input.underruns
    }

    /// Output frames rendered since the engine started.
    pub fn rendered_frames(&self) -> u64 {
        self.transport.render_frame
    }

    fn advance_song_playhead(&mut self, frame_count: usize) {
        self.transport.song.playhead_samples += frame_count as u32;
        self.transport.render_frame += frame_count as u64;
        self.recalculate_beat_bar();
        self.emit_playback_position();
        self.cleanup_finished_voices(frame_count);
    }

    fn advance_pattern_playhead(&mut self, frame_count: usize) {
        self.transport.pattern.playhead_samples += frame_count as u32;
        self.transport.render_frame += frame_count as u64;
        self.recalculate_pattern_beat_bar();
        self.emit_playback_position();
        self.cleanup_finished_voices(frame_count);
    }

    /// Recalculates pattern beat/bar based on pattern_playhead_samples
    pub(super) fn recalculate_pattern_beat_bar(&mut self) {
        self.transport
            .recalculate_pattern_position(self.config.sample_rate);
    }

    fn process_song_mode(
        &mut self,
        frame_count: usize,
        output_buffer: &mut [f32],
        channels: usize,
    ) {
        // A playhead at or past the loop end plays on; only crossing the end wraps. A take
        // being recorded runs straight on, so the loop waits until it ends.
        let capturing = self.record.is_capturing();
        if self.transport.song.is_looping
            && !capturing
            && let Some((loop_start, loop_end)) = self.song_loop_samples()
            && self.transport.song.playhead_samples < loop_end
        {
            self.process_song_loop_block(
                loop_start,
                loop_end,
                frame_count,
                output_buffer,
                channels,
            );
            return;
        }

        let song_end = self.current_state.graph.max_sample_index;

        // Only enforce the auto-stop/loop boundary if the project actually has content (song_end > 0)
        if song_end > 0 && self.transport.song.playhead_samples > song_end && !capturing {
            if self.transport.song.is_looping {
                self.transport.song.playhead_samples = 0;
                self.recalculate_beat_bar();
                self.transport.song.last_emitted_samples = 0;

                // Kill trailing notes/audio to prevent a massive wall of sound
                // from release tails accumulating when jumping back to bar 1
                self.stop_all_active_generators();
                self.voices.clear_oneshots();

                self.process_block_song_mode(frame_count, output_buffer, channels);
                self.emit_current_playback_position(FeedbackTiming::Audible);
            } else {
                // If not looping, stop playback normally, once the song's end is heard
                self.stop_playback(FeedbackTiming::Audible);
                self.render_voices_to_buffer(output_buffer, channels, false);
                self.cleanup_finished_voices(frame_count);
            }
        } else {
            self.process_block_song_mode(frame_count, output_buffer, channels);
        }
    }

    /// Song loop region in samples at the current tempo, when one is set.
    ///
    /// Converted every block like the pattern loop, so tempo changes and automation move the
    /// loop points with the music.
    pub(super) fn song_loop_samples(&self) -> Option<(u32, u32)> {
        let (start_tick, end_tick) = self.transport.song.loop_region?;
        let bpm = self.transport.bpm;
        let sample_rate = self.config.sample_rate;
        let to_samples = |ticks: u64| {
            u32::try_from(ClipTimeUnit::ticks_to_samples(ticks, bpm, sample_rate))
                .unwrap_or(u32::MAX)
        };
        let (start, end) = (to_samples(start_tick), to_samples(end_tick));
        (end > start).then_some((start, end))
    }

    /// Renders a song block before the loop end. A block that reaches the end is split there,
    /// so the jump back to the loop start lands on the exact sample.
    fn process_song_loop_block(
        &mut self,
        loop_start: u32,
        loop_end: u32,
        frame_count: usize,
        output_buffer: &mut [f32],
        channels: usize,
    ) {
        let frames_to_end = loop_end.saturating_sub(self.transport.song.playhead_samples) as usize;
        if frames_to_end > frame_count {
            self.process_block_song_mode(frame_count, output_buffer, channels);
            return;
        }

        let split = frames_to_end
            .saturating_mul(channels)
            .min(output_buffer.len());
        let (before_end, after_start) = output_buffer.split_at_mut(split);
        if frames_to_end > 0 {
            self.process_block_song_mode(frames_to_end, before_end, channels);
        }

        self.transport.song.playhead_samples = loop_start;
        self.transport.song.last_emitted_samples = loop_start;
        self.recalculate_beat_bar();
        // Release held notes and one-shots so tails from the loop end do not pile up
        self.stop_all_active_generators();
        self.voices.clear_oneshots();

        let remaining = frame_count.saturating_sub(frames_to_end);
        if remaining > 0 {
            self.process_block_song_mode(remaining, after_start, channels);
        }
        self.emit_current_playback_position(FeedbackTiming::Audible);
    }

    // Process a block of frame rendering in SONG mode (normal playback)
    fn process_block_song_mode(
        &mut self,
        buffer_size: usize,
        output_buffer: &mut [f32],
        channels: usize,
    ) {
        self.resolve_sequencer_events(buffer_size);
        self.evaluate_pre_block_modulations(buffer_size);
        self.render_voices_to_buffer(output_buffer, channels, true);
        self.metronome_state.render(
            output_buffer,
            channels,
            self.transport.song.playhead_samples,
            self.transport.bpm,
            self.config.sample_rate,
        );
        self.advance_song_playhead(buffer_size);
    }

    fn process_pattern_mode(
        &mut self,
        pattern_id: PatternId,
        generator_id: GeneratorId,
        frame_count: usize,
        output_buffer: &mut [f32],
        channels: usize,
    ) {
        let Some(pattern) = self.current_state.graph.patterns.get(&pattern_id) else {
            // Pattern deleted? Stop.
            self.stop_playback(FeedbackTiming::Immediate);
            return;
        };

        // Verify the generator exists in plugin_state
        if self.plugin_state.get_generator(generator_id).is_none() {
            log::warn!("Pattern preview: Generator {:?} not found", generator_id);
            self.stop_playback(FeedbackTiming::Immediate);
            return;
        }

        let scale = TickScale::new(self.transport.bpm, self.config.sample_rate);
        let ticks_to_samples =
            |ticks: u64| u32::try_from(scale.to_samples(ticks)).unwrap_or(u32::MAX);
        let (loop_start_samples, loop_end_samples) = match self.transport.pattern.loop_region {
            Some((start, end)) => (ticks_to_samples(start), ticks_to_samples(end)),
            None => (0, ticks_to_samples(pattern.length_ticks)),
        };

        if loop_end_samples <= loop_start_samples {
            return;
        }

        // Use PATTERN playhead (independent from song). A playhead before the loop region
        // plays into it; reaching the end jumps back to the region start.
        if self.transport.pattern.playhead_samples >= loop_end_samples {
            self.transport.pattern.playhead_samples = loop_start_samples;
            self.transport.pattern.last_emitted_samples = loop_start_samples;

            // This safely clears tracked keys to prevent hang on pattern loop
            Self::stop_all_active_generators_impl(&mut self.voices.active_generators);
        }

        let start_time = self.transport.pattern.playhead_samples;
        let end_time = start_time + (frame_count as u32);

        // Find or create voice for this generator
        let voice_idx = self
            .voices
            .active_generators
            .iter()
            .position(|g| g.id == generator_id)
            .unwrap_or_else(|| {
                // Get the track_id from plugin_state if available
                let track_id = self
                    .plugin_state
                    .get_generator(generator_id)
                    .map(|g| g.track_id)
                    .unwrap_or(TrackId::from(0));

                self.voices.active_generators.push(GeneratorVoice::new(
                    generator_id,
                    track_id,
                    true,
                ));
                self.voices.active_generators.len() - 1
            });

        let gen_voice = &mut self.voices.active_generators[voice_idx];
        gen_voice.active = true;

        Self::schedule_pattern_notes_raw(
            &mut gen_voice.midi_events,
            pattern_id,
            &pattern.notes,
            scale,
            start_time,
            end_time,
        );

        gen_voice.midi_events.sort_by_key(|e| e.sample_offset);

        self.evaluate_pre_block_modulations(frame_count);

        // Render voices to buffer
        self.render_voices_to_buffer(output_buffer, channels, true);

        self.metronome_state.render(
            output_buffer,
            channels,
            start_time,
            self.transport.bpm,
            self.config.sample_rate,
        );

        // Advance PATTERN playhead (not song playhead)
        self.advance_pattern_playhead(frame_count);
    }

    /// Stop and reset the playhead to 0
    pub(super) fn stop_playback(&mut self, timing: FeedbackTiming) {
        self.transport.song.is_playing = false;
        self.transport.pattern.is_playing = false;
        self.stop_all_active_generators();
        self.release_manual_parameter_overrides();

        self.reset_playhead();
        self.reset_pattern_state();

        // Emit exactly ONCE after both playheads are perfectly zeroed out
        self.emit_static_position(timing);
    }

    pub(super) fn stop_all_active_generators(&mut self) {
        Self::stop_all_active_generators_impl(&mut self.voices.active_generators);
    }

    /// Queues note-offs for every held note. Tracking clears as the plugins receive them,
    /// so a release queued while a generator is not rendering is delivered later.
    pub(super) fn stop_all_active_generators_impl(active_generators: &mut Vec<GeneratorVoice>) {
        for voice in active_generators.iter_mut() {
            voice.release_all();
        }
    }

    pub(super) fn get_effect_list_mut(
        &mut self,
        target: &EffectTarget,
    ) -> Option<&mut Vec<AudioEffectInstance>> {
        match target {
            EffectTarget::Track(track_id) => self
                .plugin_state
                .get_track_effects_mut(track_id.to_u32() as usize),
            EffectTarget::Bus(bus_id) => self
                .plugin_state
                .get_bus_effects_mut(bus_id.to_u32() as usize),
            EffectTarget::Master => Some(&mut self.plugin_state.master_effects),
        }
    }

    pub(super) fn get_effect_list(
        &self,
        target: &EffectTarget,
    ) -> Option<&Vec<AudioEffectInstance>> {
        match target {
            EffectTarget::Track(track_id) => self
                .plugin_state
                .get_track_effects(track_id.to_u32() as usize),
            EffectTarget::Bus(bus_id) => {
                self.plugin_state.get_bus_effects(bus_id.to_u32() as usize)
            }
            EffectTarget::Master => Some(&self.plugin_state.master_effects),
        }
    }

    pub(super) fn get_plugin_mut<'a>(
        &'a mut self,
        target: &PluginTarget,
    ) -> Option<&'a mut Box<dyn karbeat_core::core::project::plugin::AudioPlugin>> {
        match target {
            PluginTarget::Generator(id) => self
                .plugin_state
                .get_generator_mut(*id)
                .map(|i| &mut i.plugin),
            PluginTarget::TrackEffect(track_id, effect_id) => self
                .get_effect_list_mut(&EffectTarget::Track(*track_id))?
                .iter_mut()
                .find(|e| e.id == *effect_id)
                .map(|e| &mut e.plugin),
            PluginTarget::BusEffect(bus_id, effect_id) => self
                .get_effect_list_mut(&EffectTarget::Bus(*bus_id))?
                .iter_mut()
                .find(|e| e.id == *effect_id)
                .map(|e| &mut e.plugin),
            PluginTarget::MasterEffect(effect_id) => self
                .get_effect_list_mut(&EffectTarget::Master)?
                .iter_mut()
                .find(|e| e.id == *effect_id)
                .map(|e| &mut e.plugin),
        }
    }

    pub(super) fn get_plugin<'a>(
        &'a self,
        target: &PluginTarget,
    ) -> Option<&'a dyn karbeat_core::core::project::plugin::AudioPlugin> {
        self.plugin_state.plugin(target)
    }

    pub(super) fn reset_pattern_state(&mut self) {
        self.transport.reset_pattern();
    }

    /// Recalculates current Beat and Bar based on playhead_samples
    /// Uses 1-based indexing for musical time.
    pub(super) fn recalculate_beat_bar(&mut self) {
        self.transport
            .recalculate_song_position(self.config.sample_rate);
    }

    fn reset_playhead(&mut self) {
        log::info!("[AudioEngine] Reset Playhead");
        self.transport.reset_song();
    }

    fn emit_playback_position(&mut self) {
        let emission_interval = self.config.sample_rate / 60; // ~60fps
        let (current, last) = match self.transport.mode {
            PlaybackMode::Song => (
                self.transport.song.playhead_samples,
                self.transport.song.last_emitted_samples,
            ),
            PlaybackMode::Pattern { .. } => (
                self.transport.pattern.playhead_samples,
                self.transport.pattern.last_emitted_samples,
            ),
        };
        if current >= last + emission_interval {
            if !self.io.position_producer.is_full() {
                let _ = self
                    .io
                    .position_producer
                    .push(self.build_position_struct(Some(true), FeedbackTiming::Audible));
            }
            match self.transport.mode {
                PlaybackMode::Song => {
                    self.transport.song.last_emitted_samples = self.transport.song.playhead_samples;
                }
                PlaybackMode::Pattern { .. } => {
                    self.transport.pattern.last_emitted_samples =
                        self.transport.pattern.playhead_samples;
                }
            }
        }
    }

    fn emit_static_position(&mut self, timing: FeedbackTiming) {
        if !self.io.position_producer.is_full() {
            let _ = self
                .io
                .position_producer
                .push(self.build_position_struct(Some(false), timing));
        }
    }

    fn build_position_struct(
        &self,
        is_playing: Option<bool>,
        timing: FeedbackTiming,
    ) -> TransportFeedback {
        self.transport
            .position_feedback(self.config.sample_rate, is_playing, timing)
    }

    pub(super) fn emit_current_playback_position(&mut self, timing: FeedbackTiming) {
        if !self.io.position_producer.is_full() {
            let _ = self
                .io
                .position_producer
                .push(self.build_position_struct(None, timing));
        }
    }

    pub(super) fn cleanup_finished_voices(&mut self, frame_count: usize) {
        // Generators stay resident, but only process while they have events, held notes, or a
        // reported tail left. This is what lets a hosted instrument go idle after its last note.
        // Built-in generators often report no tail despite having a release envelope, so they
        // keep a short grace period before parking.
        const IDLE_GENERATOR_TAIL_SECONDS: f32 = 2.0;
        const MAX_GENERATOR_TAIL_SECONDS: u32 = 20;
        let fallback_tail = (self.config.sample_rate as f32 * IDLE_GENERATOR_TAIL_SECONDS) as u32;
        let max_tail = self
            .config
            .sample_rate
            .saturating_mul(MAX_GENERATOR_TAIL_SECONDS);
        let plugin_state = &self.plugin_state;
        for gen_voice in self.voices.active_generators.iter_mut() {
            let had_events = !gen_voice.midi_events.is_empty();
            gen_voice.finish_block();
            let has_activity = had_events
                || !gen_voice.midi_events.is_empty()
                || !gen_voice.playing_notes.is_empty();
            if has_activity {
                gen_voice.active = true;
                gen_voice.tail_remaining =
                    plugin_state
                        .get_generator(gen_voice.id)
                        .map_or(fallback_tail, |generator| {
                            let reported = generator.plugin.tail_samples();
                            if reported == 0 {
                                fallback_tail
                            } else {
                                reported.min(max_tail)
                            }
                        });
            } else if gen_voice.active {
                gen_voice.tail_remaining = gen_voice
                    .tail_remaining
                    .saturating_sub(u32::try_from(frame_count).unwrap_or(u32::MAX));
                if gen_voice.tail_remaining == 0 {
                    gen_voice.active = false;
                }
            }
        }

        self.voices.clear_oneshots();
        self.voices.stretch_pool.end_block();
    }

    pub(super) fn trigger_live_note(
        &mut self,
        generator_id: GeneratorId,
        key: u8,
        velocity: u8,
        is_on: bool,
    ) {
        // Try to find the track that has this generator from current_state
        let target_info = self.current_state.graph.tracks.iter().find_map(|t| {
            if let Some(gen_) = &t.generator {
                if gen_.id == generator_id {
                    return Some((t.id, gen_.clone()));
                }
            }
            None
        });

        // If we found the track info, use it
        if let Some((track_id, gen_instance)) = target_info {
            if let Some(voice_idx) = Self::ensure_generator_voice(
                &mut self.voices.active_generators,
                &self.plugin_state,
                track_id,
                &gen_instance,
            ) {
                let gen_voice = &mut self.voices.active_generators[voice_idx];
                let message = if is_on {
                    MidiMessage::NoteOn {
                        note_id: None,
                        channel: 0,
                        key,
                        velocity,
                    }
                } else {
                    MidiMessage::NoteOff {
                        note_id: None,
                        channel: 0,
                        key,
                    }
                };

                gen_voice.midi_events.push(MidiEvent {
                    sample_offset: 0,
                    data: message,
                });
                gen_voice.active = true;
                return;
            }
        }

        // Fallback: If triple buffer hasn't synced yet, check plugin_state directly
        // This handles the case where AudioCommand::AddGenerator was received but
        // the UI hasn't updated current_state via triple buffer yet
        if let Some(gen_instance) = self.plugin_state.get_generator(generator_id) {
            let track_id = gen_instance.track_id;

            // Find or create voice
            let voice_idx = self
                .voices
                .active_generators
                .iter()
                .position(|g| g.id == generator_id)
                .unwrap_or_else(|| {
                    self.voices.active_generators.push(GeneratorVoice::new(
                        generator_id,
                        track_id,
                        true,
                    ));
                    self.voices.active_generators.len() - 1
                });

            let gen_voice = &mut self.voices.active_generators[voice_idx];
            let message = if is_on {
                MidiMessage::NoteOn {
                    note_id: None,
                    channel: 0,
                    key,
                    velocity,
                }
            } else {
                MidiMessage::NoteOff {
                    note_id: None,
                    channel: 0,
                    key,
                }
            };

            gen_voice.midi_events.push(MidiEvent {
                sample_offset: 0,
                data: message,
            });
            gen_voice.active = true;
        } else {
            log::warn!(
                "PlayPreviewNote: Generator ID {:?} not found in plugin_state or graph",
                generator_id
            );
        }
    }

    fn render_voices_to_buffer(&mut self, output: &mut [f32], channels: usize, is_playing: bool) {
        let buf_len = output.len();
        // Infinite tails would otherwise keep a parked effect alive forever.
        let max_effect_tail = self.config.sample_rate.saturating_mul(20);

        // Peak meters react immediately and fall by roughly 20 dB/second.
        // Decaying every channel here also guarantees muted and inactive
        // channels return to silence instead of retaining a stale reading.
        let frames = buf_len / channels.max(1);
        let release_factor =
            10.0_f32.powf(-((frames as f32) / self.config.sample_rate.max(1) as f32));
        for channel in self.mixer_state.track_channels.values_mut() {
            channel.decay_magnitude(release_factor);
        }
        for channel in self.mixer_state.bus_channels.values_mut() {
            channel.decay_magnitude(release_factor);
        }
        self.mixer_state.master.decay_magnitude(release_factor);

        // Check for solo state
        let is_any_solo = self.mixer_state.track_channels.values().any(|ch| ch.solo);

        if self.render_plan.is_stale() || self.render_plan.workers() != self.dsp_workers() {
            self.rebuild_render_plan();
        }

        let sample_rate = self.config.sample_rate as f64;
        let bpm = self.transport.bpm as f64;
        let sample_position = match self.transport.mode {
            PlaybackMode::Song => self.transport.song.playhead_samples as u64,
            PlaybackMode::Pattern { .. } => self.transport.pattern.playhead_samples as u64,
        };

        let samples_per_beat = (60.0 / bpm) * sample_rate;
        let beat_position = if samples_per_beat > 0.0 {
            (sample_position as f64) / samples_per_beat + 1.0
        } else {
            1.0
        };
        let bar_position = if self.transport.time_sig_numerator > 0 {
            (beat_position - 1.0) / (self.transport.time_sig_numerator as f64) + 1.0
        } else {
            1.0
        };

        // Plugins see the song loop in quarter notes from the song start, like VST3 cycle points
        let (loop_start_beat, loop_end_beat) = match self.transport.mode {
            PlaybackMode::Song if self.transport.song.is_looping => {
                match self.transport.song.loop_region {
                    Some((start, end)) if end > start => {
                        (Some(start as f64 / PPQ), Some(end as f64 / PPQ))
                    }
                    _ => (None, None),
                }
            }
            _ => (None, None),
        };

        let base_ctx = ProcessContext {
            bpm,
            time_sig_numerator: self.transport.time_sig_numerator,
            time_sig_denominator: self.transport.time_sig_denominator,
            is_playing,
            is_recording: self.transport.song.is_recording,
            mode: self.processing_mode,
            project_time_seconds: (sample_position as f64) / sample_rate,
            project_time_samples: sample_position,
            beat_position,
            bar_position,
            loop_start_beat,
            loop_end_beat,
            midi_events: &[],
            param_changes: &[],
        };

        // Shared state is claimed here, in the order the graph renders in, so a parallel render
        // claims exactly what a serial one does.
        group_voices_by_track(&mut self.voices.active_oneshots);
        for track_id in self.render_plan.tracks() {
            let heard = self
                .mixer_state
                .track_channels
                .get(&track_id)
                .is_none_or(|channel| !channel.mute && (!is_any_solo || channel.solo));
            if heard {
                let range = voice_range(&self.voices.active_oneshots, track_id);
                self.voices.lease_stretchers(
                    range,
                    self.config.sample_rate,
                    self.transport.bpm,
                    frames,
                );
            }
        }

        self.render_plan.gather(GatherSources {
            mixer: &mut self.mixer_state,
            plugins: &mut self.plugin_state,
            generators: &mut self.voices.active_generators,
            oneshots: &mut self.voices.active_oneshots,
            track_tails: &mut self.routing.track_tails,
            bus_tails: &mut self.routing.bus_tails,
            master_tail: &mut self.routing.master_tail,
            track_input_delays: &mut self.routing.track_input_delay_lines,
            edge_delays: &mut self.routing.edge_delay_lines,
            bus_buffers: &mut self.workspace.bus_buffers,
            sidechain_buffers: &mut self.workspace.aux_buffers,
        });

        let input_channels = self.input.device_channels();
        let (input, _) = self.input.take(frames);
        let ctx = BlockCtx {
            base: base_ctx,
            param_changes: &self.modulation.block_param_changes,
            channels,
            sample_rate: self.config.sample_rate,
            bpm: self.transport.bpm,
            is_any_solo,
            max_effect_tail,
            bypass_master: self.bypass_master,
            input,
            input_channels,
        };
        let job = RenderJob {
            plan: &self.render_plan,
            ctx: &ctx,
            output: SendPtr::new(output.as_mut_ptr()),
            output_len: buf_len,
        };
        match self.workers.as_mut() {
            Some(pool) => pool.run(&job),
            None => {
                for level in 0..job.levels() {
                    job.run(0, level);
                }
            }
        }

        self.voices.return_stretchers();
        let blocks_per_second = (self.config.sample_rate as usize / frames.max(1)).max(1);
        self.render_plan
            .finish_block(u32::try_from(blocks_per_second).unwrap_or(u32::MAX));
    }

    /// Threads rendering the graph, this one included.
    pub fn dsp_workers(&self) -> usize {
        self.workers.as_ref().map_or(1, AudioWorkerPool::workers)
    }

    /// Renders the graph on `workers` threads, this one included; 1 renders serially.
    /// Spawns or joins threads, so call it from setup, never from `process`.
    pub fn set_dsp_workers(&mut self, workers: usize) {
        if workers.clamp(1, MAX_DSP_WORKERS) == self.dsp_workers() {
            return;
        }
        self.workers = None;
        self.workers = AudioWorkerPool::new(
            workers,
            self.current_state.graph.buffer_size,
            self.config.sample_rate,
        );
        self.render_plan.mark_stale();
    }

    /// Compiles the routing graph for the worker pool. Allocates; runs only after the graph
    /// changed.
    fn rebuild_render_plan(&mut self) {
        let tracks = &self.current_state.graph.tracks;
        let sidechains: Vec<(SidechainRoute, RoutingNode)> = self
            .workspace
            .aux_buffers
            .keys()
            .filter_map(|route| Some((*route, sidechain_owner(tracks, *route)?)))
            .collect();
        let monitored: Vec<(TrackId, InputSource)> = tracks
            .iter()
            .filter(|track| track.input.monitor)
            .map(|track| (track.id, InputSource::from(&track.input)))
            .collect();
        let plugin_state = &self.plugin_state;
        let plan = RenderPlan::build(
            &PlanGraph {
                order: &self.routing.cached_order,
                outgoing: &self.routing.outgoing_routes,
                sidechains: &sidechains,
                monitored: &monitored,
                workers: self.dsp_workers(),
                block_samples: self.workspace.mix_buffer.capacity(),
                channels: self.config.num_channels as usize,
            },
            |kind| {
                let effects = match kind {
                    PlanNodeKind::Input(_) => return 0.5,
                    PlanNodeKind::Track(id) => plugin_state.get_track_effects(id.to_u32() as usize),
                    PlanNodeKind::Bus(id) => plugin_state.get_bus_effects(id.to_u32() as usize),
                    PlanNodeKind::Master => Some(&plugin_state.master_effects),
                };
                1.0 + effects.map_or(0, Vec::len) as f32
            },
        );
        let retired = std::mem::replace(&mut self.render_plan, plan);
        self.retire_graph_state(RetiredGraphState::RenderPlan(Box::new(retired)));
    }

    fn resolve_sequencer_events(&mut self, buffer_size: usize) {
        let start_time = self.transport.song.playhead_samples;
        let end_time = start_time + (buffer_size as u32);

        let tracks = std::mem::take(&mut self.current_state.graph.tracks);
        let scale = TickScale::new(self.transport.bpm, self.config.sample_rate);
        self.clip_schedule
            .ensure(&tracks, &self.current_state.graph.clips, scale);

        for (track_index, track) in tracks.iter().enumerate() {
            self.process_track(track_index, track, scale, start_time, end_time);
        }

        self.current_state.graph.tracks = tracks;
    }

    fn process_track(
        &mut self,
        track_index: usize,
        track: &AudioTrack,
        scale: TickScale,
        start_time: u32,
        end_time: u32,
    ) {
        let track_id = track.id;

        let mut gen_voice_idx = None;
        if let Some(gen_instance) = &track.generator {
            gen_voice_idx = Self::ensure_generator_voice(
                &mut self.voices.active_generators,
                &self.plugin_state,
                track_id,
                gen_instance,
            );
        }

        let clip_ids = track.clips();
        // Only the clips that can overlap this block; the checks below still decide.
        for index in self
            .clip_schedule
            .candidates(track_index, start_time, end_time)
        {
            let Some(clip_id) = clip_ids.get(index) else {
                break;
            };
            let Some(clip_data) = self.current_state.graph.clips.get(clip_id) else {
                continue;
            };
            let (clip_start, clip_length, clip_offset) = clip_span_samples(&clip_data.time, scale);

            if clip_start > end_time {
                break;
            }
            let clip_end = clip_start + clip_length;
            if clip_end < start_time {
                continue;
            }

            match &clip_data.source {
                Some(DawSource::Audio(source_id)) => {
                    let waveform_opt = self
                        .current_state
                        .graph
                        .asset_library
                        .source_map
                        .get(*source_id);
                    if let Some(waveform) = waveform_opt {
                        let graph_clips = &self.current_state.graph.clips;
                        let span_at = |neighbour: usize| {
                            let clip = graph_clips.get(clip_ids.get(neighbour)?)?;
                            matches!(clip.source, Some(DawSource::Audio(_)))
                                .then(|| audio_clip_span(clip, scale))
                        };
                        let crossfade = NeighbourCrossfade::for_clip(
                            audio_clip_span(clip_data, scale),
                            index.checked_sub(1).and_then(span_at),
                            span_at(index + 1),
                        );
                        self.voices.prepare_audio_voice(
                            track.id,
                            *clip_id,
                            clip_start,
                            clip_length,
                            clip_offset,
                            waveform,
                            clip_data.envelope.as_ref(),
                            crossfade,
                            start_time,
                            end_time,
                            self.config.sample_rate,
                            self.transport.bpm,
                        );
                    }
                }
                Some(DawSource::Midi(id)) => {
                    let fresh_pattern = self.current_state.graph.patterns.get(id);

                    if let Some(pattern) = fresh_pattern {
                        if let Some(idx) = gen_voice_idx {
                            let gen_voice = &mut self.voices.active_generators[idx];
                            VoiceState::schedule_midi_events(
                                &mut gen_voice.midi_events,
                                pattern,
                                &clip_data.time,
                                scale,
                                start_time,
                                end_time,
                            );
                        }
                    }
                }
                _ => {}
            }
        }

        // Just sort the events. Playing_keys is safely handled downstream now!
        if let Some(idx) = gen_voice_idx {
            let voice = &mut self.voices.active_generators[idx];
            voice.midi_events.sort_by_key(|e| e.sample_offset);
            // A parked generator must wake for the block that has scheduled events.
            if !voice.midi_events.is_empty() {
                voice.active = true;
            }
        }
    }

    /// Ensure that the generator voice is active
    fn ensure_generator_voice(
        active_generators: &mut Vec<GeneratorVoice>,
        plugin_state: &AudioPluginState,
        track_id: TrackId,
        gen_instance: &GeneratorInstance,
    ) -> Option<usize> {
        VoiceState::ensure_generator_voice(active_generators, plugin_state, track_id, gen_instance)
    }

    /// Render preview voices to the output buffer
    fn render_previews_to_buffer(&mut self, output: &mut [f32], channels: usize) {
        self.voices
            .render_previews(output, channels, self.config.sample_rate);
    }

    // Helper to schedule notes without a Clip wrapper
    fn schedule_pattern_notes_raw(
        events: &mut SmallVec<[MidiEvent; 4]>,
        pattern_id: PatternId,
        notes: &[karbeat_core::core::project::Note],
        scale: TickScale,
        buffer_start: u32,
        buffer_end: u32,
    ) {
        VoiceState::schedule_pattern_notes(
            events,
            pattern_id,
            notes,
            scale,
            buffer_start,
            buffer_end,
        );
    }

    /// Gives every sidechain destination in the current routing an aux buffer, and retires the
    /// buffers of routes that no longer exist off the audio thread.
    pub(super) fn sync_sidechain_buffers(&mut self) {
        for connection in &self.current_state.graph.routing {
            if let RoutingNode::PluginSidechain(route) = connection.destination {
                self.workspace.prepare_sidechain(route);
            }
        }
        while let Some(stale) =
            self.workspace.aux_buffers.keys().copied().find(|route| {
                !self.current_state.graph.routing.iter().any(|connection| {
                    connection.destination == RoutingNode::PluginSidechain(*route)
                })
            })
        {
            if let Some(buffer) = self.workspace.aux_buffers.remove(&stale) {
                self.retire_graph_state(RetiredGraphState::AudioBuffer(buffer));
            }
        }
    }

    pub(super) fn recalculate_latencies(&mut self) {
        self.routing.latency_dirty = false;
        let max_system_latency = self.routing.recalculate_latencies(
            &self.current_state.graph,
            &self.plugin_state,
            self.config.num_channels as usize,
        );

        // Offline renders compensate their own graph and leave the monitor reading alone.
        if matches!(self.processing_mode, ProcessingMode::Realtime) {
            super::telemetry::PDC_LATENCY_SAMPLES
                .store(max_system_latency, std::sync::atomic::Ordering::Relaxed);
        }

        log::info!(
            "[PDC] Recalculated Latencies. Max System Latency: {} samples",
            max_system_latency
        );
    }

    /// Drops modulation links that target `plugin`, together with the automation sources and
    /// lanes that drove them. Real-time safe: links and sources hold no heap data, and removed
    /// lanes are retired off the audio thread.
    pub(super) fn remove_plugin_modulations(&mut self, plugin: PluginTarget) {
        let mut index = 0;
        while let Some(link) = self.modulation.active_links.get(index) {
            if link.target.as_plugin_target() != Some(plugin) {
                index = index.saturating_add(1);
                continue;
            }
            let link = self.modulation.active_links.remove(index);
            self.modulation.suspended_targets.remove(&link.target);
            self.current_state.graph.modulation_links.remove(&link.id);

            let lane_id = match self.modulation.active_sources.get(&link.source_id) {
                Some((LiveModulationSource::Automation { lane_id }, _)) => Some(*lane_id),
                _ => None,
            };
            if let Some(lane_id) = lane_id {
                self.modulation.active_sources.remove(&link.source_id);
                self.current_state
                    .graph
                    .modulation_sources
                    .remove(&link.source_id);
                if let Some(lane) = self.current_state.graph.automation_lanes.remove(&lane_id) {
                    self.retire_graph_state(RetiredGraphState::Automation(lane));
                }
            }
        }
    }

    /// Releases every manual parameter override so automation and modulation resume.
    ///
    /// Called on transport seek and play/stop, which is the point where a user edit stops
    /// taking precedence over automation. Runs on the audio thread, but only on transport
    /// commands, and performs no heap allocation.
    pub(super) fn release_manual_parameter_overrides(&mut self) {
        self.modulation.suspended_targets.clear();

        for (_, generator) in self.plugin_state.generators.iter_mut() {
            generator.plugin.clear_parameter_overrides();
        }
        for chain in self
            .plugin_state
            .track_effects
            .iter_mut()
            .chain(self.plugin_state.bus_effects.iter_mut())
        {
            for effect in chain {
                effect.plugin.clear_parameter_overrides();
            }
        }
        for effect in &mut self.plugin_state.master_effects {
            effect.plugin.clear_parameter_overrides();
        }
    }

    pub(super) fn evaluate_pre_block_modulations(&mut self, buffer_size: usize) {
        let mut peak_updates = std::mem::take(&mut self.modulation.peak_updates);
        peak_updates.clear();
        for (id, (source, _)) in self.modulation.active_sources.iter() {
            if let LiveModulationSource::PeakController { source: p_tgt } = source {
                if let Some(karbeat_plugin_api::prelude::ZeroCopyBuffer::Float32(control_buf)) =
                    self.get_plugin(p_tgt)
                        .and_then(|p| p.get_zero_copy_buffer("control"))
                {
                    peak_updates.push((*id, control_buf.first().copied().unwrap_or(0.0)));
                }
            }
        }
        for &(id, val) in &peak_updates {
            self.modulation.set_source_output(id, val);
        }
        self.modulation.peak_updates = peak_updates;

        let mut parameter_changes = std::mem::take(&mut self.modulation.target_accumulators);
        self.modulation.evaluate(
            buffer_size,
            self.transport.bpm,
            self.config.sample_rate,
            self.transport.song.playhead_samples,
            &self.current_state.graph.automation_lanes,
            &mut parameter_changes,
        );
        for (target, (automation_override, modulation)) in &parameter_changes {
            let base = automation_override.unwrap_or_else(|| self.modulation.base_value(target));
            let final_value = (base + modulation).clamp(0.0, 1.0);
            self.apply_parameter_change(target, final_value);
        }
        self.modulation.target_accumulators = parameter_changes;
    }

    fn apply_parameter_change(&mut self, target: &AutomationTarget, final_value: f32) {
        match target {
            AutomationTarget::Generator {
                generator_id,
                param_id,
            } => {
                if let Some(inst) = self.plugin_state.get_generator_mut(*generator_id) {
                    inst.plugin.apply_automation(*param_id, final_value);
                }
            }

            AutomationTarget::Track {
                track_id,
                track_target,
            } => match track_target {
                TrackAutomationTarget::MixerChannel(mix_target) => {
                    apply_mix_param!(
                        mix_target,
                        final_value,
                        self.mixer_state.track_channels.get_mut(track_id),
                        self.plugin_state
                            .get_track_effects_mut(track_id.to_u32() as usize)
                    );
                }
            },

            AutomationTarget::Bus { bus_id, mix_target } => {
                apply_mix_param!(
                    mix_target,
                    final_value,
                    self.mixer_state.bus_channels.get_mut(bus_id),
                    self.plugin_state
                        .get_bus_effects_mut(bus_id.to_u32() as usize)
                );
            }

            AutomationTarget::Master(master_target) => match master_target {
                MasterAutomationTarget::MixerChannel(mix_target) => {
                    apply_mix_param!(
                        mix_target,
                        final_value,
                        Some(&mut self.mixer_state.master),
                        Some(&mut self.plugin_state.master_effects)
                    );
                }
                MasterAutomationTarget::TempoBpm => {
                    // Lanes are normalized; tempo owns the mapping to beats per minute.
                    self.transport.bpm = karbeat_dsp::interpolation::lerp(
                        final_value,
                        TEMPO_AUTOMATION_MIN_BPM,
                        TEMPO_AUTOMATION_MAX_BPM,
                    );
                }
            },
        }
    }

    pub(super) fn handle_parameter_edit(&mut self, target: &AutomationTarget, is_begin: bool) {
        match target {
            AutomationTarget::Generator {
                generator_id,
                param_id,
            } => {
                if let Some(inst) = self.plugin_state.get_generator_mut(*generator_id) {
                    if is_begin {
                        inst.plugin.begin_parameter_edit(*param_id);
                    } else {
                        inst.plugin.end_parameter_edit(*param_id);
                    }
                }
            }
            AutomationTarget::Track {
                track_id,
                track_target,
            } => match track_target {
                TrackAutomationTarget::MixerChannel(mix_target) => match mix_target {
                    MixerChannelParamTarget::Plugin { effect_id, target } => match target {
                        EffectAutomationTarget::Mix => {}
                        EffectAutomationTarget::PluginParam { param_id } => {
                            if let Some(effects) = self
                                .plugin_state
                                .get_track_effects_mut(track_id.to_u32() as usize)
                            {
                                if let Some(e) = effects.iter_mut().find(|e| e.id == *effect_id) {
                                    if is_begin {
                                        e.plugin.begin_parameter_edit(*param_id);
                                    } else {
                                        e.plugin.end_parameter_edit(*param_id);
                                    }
                                }
                            }
                        }
                    },
                    _ => {}
                },
            },
            AutomationTarget::Bus { bus_id, mix_target } => match mix_target {
                MixerChannelParamTarget::Plugin { effect_id, target } => match target {
                    EffectAutomationTarget::Mix => {}
                    EffectAutomationTarget::PluginParam { param_id } => {
                        if let Some(effects) = self
                            .plugin_state
                            .get_bus_effects_mut(bus_id.to_u32() as usize)
                        {
                            if let Some(e) = effects.iter_mut().find(|e| e.id == *effect_id) {
                                if is_begin {
                                    e.plugin.begin_parameter_edit(*param_id);
                                } else {
                                    e.plugin.end_parameter_edit(*param_id);
                                }
                            }
                        }
                    }
                },
                _ => {}
            },
            AutomationTarget::Master(master_target) => match master_target {
                MasterAutomationTarget::MixerChannel(mix_target) => match mix_target {
                    MixerChannelParamTarget::Plugin { effect_id, target } => match target {
                        EffectAutomationTarget::Mix => {}
                        EffectAutomationTarget::PluginParam { param_id } => {
                            if let Some(e) = self
                                .plugin_state
                                .master_effects
                                .iter_mut()
                                .find(|e| e.id == *effect_id)
                            {
                                if is_begin {
                                    e.plugin.begin_parameter_edit(*param_id);
                                } else {
                                    e.plugin.end_parameter_edit(*param_id);
                                }
                            }
                        }
                    },
                    _ => {}
                },
                MasterAutomationTarget::TempoBpm => {}
            },
        }
    }

    /// Whether any effect keeps processing on a silent channel, as hosted plugins do.
    pub fn has_continuous_effects(&self) -> bool {
        itertools::chain!(
            self.plugin_state.track_effects.iter().flatten(),
            self.plugin_state.bus_effects.iter().flatten(),
            self.plugin_state.master_effects.iter(),
        )
        .any(AudioEffectInstance::keeps_processing)
    }

    /// Returns the exact number of samples needed to fully clear all plugin delays and reverb tails.
    /// Call this when the transport stops to know when to put the engine to sleep.
    pub fn get_project_tail_length(&self) -> u32 {
        let max_tail = itertools::chain!(
            self.plugin_state
                .generators
                .iter()
                .map(|(_, generator)| generator.plugin.tail_samples()),
            self.plugin_state
                .track_effects
                .iter()
                .flatten()
                .map(|effect| effect.plugin.tail_samples()),
            self.plugin_state
                .bus_effects
                .iter()
                .flatten()
                .map(|effect| effect.plugin.tail_samples()),
            self.plugin_state
                .master_effects
                .iter()
                .map(|effect| effect.plugin.tail_samples()),
        )
        .max()
        .unwrap_or(0);

        // Cap the tail at 20 seconds so infinite reverbs don't render forever
        let max_allowed_tail = 20 * self.config.sample_rate;
        let max_tail = max_tail.min(max_allowed_tail);

        // Include PDC latency since it naturally delays the final output
        max_tail + self.routing.system_latency
    }

    /// Returns the absolute total length of the song in samples, including reverb tails.
    /// Your offline export loop should use THIS value as its target length!
    pub fn get_export_length(&self) -> u32 {
        self.current_state.graph.max_sample_index + self.get_project_tail_length()
    }

    /// Dynamically calculates the absolute end of the project in samples (Clips ONLY).
    /// Safely handles the conversion of MIDI Ticks -> Samples based on CURRENT engine BPM & Sample Rate.
    pub(super) fn reprepare_plugins_and_clear_delays(&mut self, sr: u32, buf_size: usize) {
        let channels = self.config.num_channels as usize;
        let bf_size = buf_size.max(512);

        for plugin in itertools::chain!(
            self.plugin_state
                .generators
                .iter_mut()
                .map(|(_, generator)| &mut generator.plugin),
            self.plugin_state
                .track_effects
                .iter_mut()
                .flatten()
                .map(|effect| &mut effect.plugin),
            self.plugin_state
                .bus_effects
                .iter_mut()
                .flatten()
                .map(|effect| &mut effect.plugin),
            self.plugin_state
                .master_effects
                .iter_mut()
                .map(|effect| &mut effect.plugin),
        ) {
            plugin.prepare(sr as f32, bf_size);
            let bus = BusConfig {
                name: "Main".into(),
                channel_count: channels,
                is_optional: false,
            };
            plugin.set_io_layout(std::slice::from_ref(&bus.clone()), &[bus]);
        }

        // Clear delay lines to avoid playing back garbage/pitch-shifted audio
        self.routing.clear_delay_lines();
    }

    /// Recalculate max samples index of the timeline after
    /// changes in the tracks
    pub(super) fn recalculate_max_sample_index(&mut self) {
        let scale = TickScale::new(self.transport.bpm, self.config.sample_rate);
        let mut max_clip_end: u32 = 0;

        // Find the absolute furthest boundary of any clip on the timeline
        for track in self.current_state.graph.tracks.iter() {
            for clip_id in track.clips.iter() {
                let Some(clip) = self.current_state.graph.clips.get(clip_id) else {
                    continue;
                };
                let (start, length, _) = clip_span_samples(&clip.time, scale);
                let end_sample = start.saturating_add(length);
                if end_sample > max_clip_end {
                    max_clip_end = end_sample;
                }
            }
        }

        // Set max_sample_index to ONLY the end of the clips (No Tails)
        // This ensures looping and song-stop behaves perfectly in the UI.
        self.current_state.graph.max_sample_index = max_clip_end;

        log::debug!(
            "[AudioEngine] Max Sample Index recalculated (Clips only): {}",
            self.current_state.graph.max_sample_index
        );
    }

    /// Emits snapshots of all active mixer channels via the triple-buffer.
    fn emit_all_mixer_snapshots(&mut self) {
        self.telemetry.emit_mixer_snapshot(&self.mixer_state);
    }

    /// Fetches parameters only for plugins the UI is actively watching.
    /// Publishes each plugin's snapshot into its own per-plugin triple-buffer producer.
    fn emit_plugin_telemetry(&mut self) {
        if self.telemetry.active_telemetry_subscriptions.is_empty() {
            return;
        }

        let mut producers = std::mem::take(&mut self.telemetry.param_telemetry_producers);
        for (target, producer) in &mut producers {
            let Some(buffer_names) = self.telemetry.active_telemetry_subscriptions.get(target)
            else {
                continue;
            };
            let Some(plugin) = self.plugin_state.plugin(target) else {
                continue;
            };

            let snapshot = producer.input_buffer_mut();
            for (id, value) in &mut snapshot.parameters {
                *value = plugin.get_current_parameter(*id);
            }
            snapshot
                .buffers
                .retain(|name, _| buffer_names.contains(name));
            for name in buffer_names {
                if let Some(buffer) = plugin.get_zero_copy_buffer(name) {
                    if let Some(existing) = snapshot.buffers.get_mut(name) {
                        *existing = buffer;
                    } else {
                        snapshot.buffers.insert(name.clone(), buffer);
                    }
                } else {
                    snapshot.buffers.remove(name);
                }
            }
            producer.publish();
        }
        self.telemetry.param_telemetry_producers = producers;
    }
}

/// Timeline span and crossfade length of an audio clip, for neighbour crossfades.
fn audio_clip_span(clip: &Clip, scale: TickScale) -> ClipSpan {
    let (start, length, _) = clip_span_samples(&clip.time, scale);
    ClipSpan {
        start,
        length,
        crossfade: clip
            .envelope
            .as_ref()
            .map_or(0, |envelope| envelope.crossfade),
    }
}
