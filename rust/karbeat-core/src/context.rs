//! Centralized application context containing all shared state.
//!
//! This module replaces scattered lazy static globals with a single `KarbeatContext` struct
//! for improved testability and explicit dependencies.

use std::sync::{Arc, Once, mpsc};

use hashbrown::HashMap;
use karbeat_host::HostStateCapture;
use karbeat_host::HostInstanceId;
use karbeat_plugins::registry::{PluginFactory, PluginRegistry};
use parking_lot::{Mutex, RwLock};
use rtrb::{Consumer, Producer};

use crate::{
    audio::{
        backend::{AudioDeviceConfig, AudioRuntimeSettings},
        event::TransportFeedback,
        render_state::{AudioAutomationLane, AudioGraphState},
    },
    commands::{AudioCommand, AudioFeedback, TelemetryRegistration},
    core::{
        history::{HistoryManager, ProjectAction},
        project::{ApplicationState, AudioTrack, AutomationLane, Clip, Pattern},
    },
    message::TelemetryRegistry,
    shared::{AutomationId, ClipId, PatternId},
};

/// Application-owned coordination point for project state, history, audio queues, and telemetry.
///
/// UI/control code mutates `app_state` through the API modules and explicitly broadcasts matching
/// commands so the audio thread's private render state stays synchronized.
pub struct DawContext {
    /// Serialized project model used as the control-side source of truth.
    pub app_state: ApplicationState,
    /// Undo/redo history manager
    pub history: HistoryManager,

    /// Audio command queue producer (UI → Audio)
    pub command_sender: Arc<Mutex<Option<Producer<AudioCommand>>>>,

    /// Parameter feedback consumer (Audio → UI)
    pub feedback_consumer: Arc<Mutex<Option<rtrb::Consumer<AudioFeedback>>>>,
    /// Save replies intercepted by the control worker that owns the feedback consumer.
    pub project_state_feedback: Arc<Mutex<crate::audio::project_state::ProjectStateFeedback>>,

    /// Audio stream handle
    pub stream_guard: Option<cpal::Stream>,

    /// Playback position ring buffer consumer
    pub position_consumer: Arc<Mutex<Option<rtrb::Consumer<TransportFeedback>>>>,

    /// Plugin factory registry
    pub plugin_registry: PluginRegistry,

    /// External discovery descriptors and UI IDs, separate from first-party factories.
    pub external_plugin_failures: HashMap<crate::audio::event::PluginTarget, String>,

    pub hosted_targets: HashMap<crate::audio::event::PluginTarget, HostedTargetState>,

    /// Combined first-party and externally discovered plugin metadata.
    pub plugin_catalog: crate::audio::plugin_catalog::PluginCatalog,

    /// Format-independent control-side access to live hosted plug-in state.
    pub host_state_capture: Arc<dyn HostStateCapture>,

    /// The live, thread-safe audio configuration.
    /// The UI writes to this, and the background stream monitor reads from it.
    pub active_audio_config: Arc<RwLock<AudioDeviceConfig>>,

    /// Requested and active stream/DSP settings shared with the backend supervisor.
    pub audio_runtime_settings: Arc<RwLock<AudioRuntimeSettings>>,

    /// UI-thread telemetry consumers after the audio engine has initialized them.
    pub telemetry_registry: Option<TelemetryRegistry>,

    /// Receiver for per-plugin triple-buffer `Output` consumers sent from the audio thread.
    ///
    /// The audio thread sends a `TelemetryRegistration` message whenever a plugin is
    /// added or removed. The UI thread polls this receiver (e.g. on every frame) to
    /// keep `telemetry_registry.param_telemetry_consumers` in sync.
    pub telemetry_reg_receiver: Option<Mutex<mpsc::Receiver<TelemetryRegistration>>>,
}

#[derive(Clone, Debug)]
pub enum HostedTargetState {
    Active(HostInstanceId),
    Transitioning,
    Failed(String),
}

#[derive(Clone)]
pub struct ControlHandles {
    pub command_sender: Arc<Mutex<Option<Producer<AudioCommand>>>>,
    pub feedback_consumer: Arc<Mutex<Option<Consumer<AudioFeedback>>>>,
    pub project_state_feedback: Arc<Mutex<crate::audio::project_state::ProjectStateFeedback>>,
}

impl DawContext {
    /// Creates a context with a blank project, first-party registry, and disconnected audio queues.
    pub fn new() -> Self {
        let plugin_registry = PluginRegistry::new_with_defaults();
        let plugin_catalog = crate::audio::plugin_catalog::PluginCatalog::new(&plugin_registry);
        Self {
            app_state: ApplicationState::default(),
            history: HistoryManager::new(),
            command_sender: Arc::new(Mutex::new(None)),
            feedback_consumer: Arc::new(Mutex::new(None)),
            project_state_feedback: Arc::new(Mutex::new(Default::default())),
            stream_guard: None,
            position_consumer: Arc::new(Mutex::new(None)),
            plugin_registry,
            plugin_catalog,
            host_state_capture: Arc::new(karbeat_vst3::native::NativeStateCapture),
            external_plugin_failures: HashMap::new(),
            hosted_targets: HashMap::new(),
            active_audio_config: Arc::new(RwLock::new(AudioDeviceConfig::default())),
            audio_runtime_settings: Arc::new(RwLock::new(AudioRuntimeSettings::default())),
            telemetry_registry: None,
            telemetry_reg_receiver: None,
        }
    }

    /// Pushes one command into the bounded UI-to-audio queue.
    ///
    /// Returns an error when the stream is uninitialized or the queue has no free slot.
    pub fn send_audio_command(&mut self, command: AudioCommand) -> anyhow::Result<()> {
        if let Some(sender) = self.command_sender.lock().as_mut() {
            sender
                .push(command)
                .map_err(|_| anyhow::anyhow!("Audio command queue is full"))?;
        } else {
            return Err(anyhow::anyhow!("Audio stream is not initialized"));
        };

        Ok(())
    }

    pub fn control_handles(&self) -> ControlHandles {
        ControlHandles {
            command_sender: Arc::clone(&self.command_sender),
            feedback_consumer: Arc::clone(&self.feedback_consumer),
            project_state_feedback: Arc::clone(&self.project_state_feedback),
        }
    }

    /// Best-effort pushes a command sequence when an audio sender exists.
    ///
    /// Individual full-queue failures and an absent sender are intentionally ignored; this helper
    /// preserves the existing non-atomic chained-notification behavior.
    pub fn try_send_audio_command_chain(
        &mut self,
        commands: Vec<AudioCommand>,
    ) -> anyhow::Result<()> {
        if let Some(sender) = self.command_sender.lock().as_mut() {
            commands.into_iter().for_each(|command| {
                let _ = sender.push(command);
            });
        }

        Ok(())
    }

    /// Returns the first-party factory registered for `registry_id`.
    pub fn get_plugin_factory(&self, registry_id: u32) -> Option<PluginFactory> {
        let registry = &self.plugin_registry;
        let Some((plugin, _)) = registry.create_plugin_by_id(registry_id) else {
            return None;
        };

        Some(plugin)
    }

    /// Constructs and prepares a first-party plugin plus its preallocated telemetry channel.
    ///
    /// Preparation uses the requested DSP rate and block size and configures one stereo main bus
    /// in each direction before the value can be transferred to the audio thread.
    pub fn prepare_plugin_install(
        &self,
        factory: PluginFactory,
    ) -> (
        Box<dyn karbeat_plugin_api::traits::AudioPlugin>,
        crate::commands::PreparedPluginTelemetry,
    ) {
        let config = self.audio_runtime_settings.read().requested_dsp;
        let mut plugin = factory();
        plugin.prepare(config.sample_rate as f32, config.block_size as usize);
        let bus = karbeat_plugin_api::types::BusConfig {
            name: "Main".into(),
            channel_count: 2,
            is_optional: false,
        };
        plugin.set_io_layout(std::slice::from_ref(&bus), std::slice::from_ref(&bus));
        let telemetry = crate::commands::PreparedPluginTelemetry::new(plugin.as_ref());
        (plugin, telemetry)
    }

    // ======================================
    // Granular graph-state broadcast helpers
    // ======================================

    fn update_track_graph(
        &mut self,
    ) -> (
        HashMap<PatternId, Pattern>,
        HashMap<ClipId, Clip>,
        Box<[AudioTrack]>,
    ) {
        let app = &mut self.app_state;
        let mut tracks_vec: Box<[AudioTrack]> = app.tracks.values().cloned().collect();
        tracks_vec.sort_by_key(|t| t.id);

        // return the pattern pool and tracks
        let patterns = app
            .pattern_pool
            .iter()
            .map(|(id, pattern)| (id, pattern.clone()))
            .collect();
        let clips = app
            .clips_pool
            .iter()
            .map(|(id, clip)| (id, clip.clone()))
            .collect();
        (patterns, clips, tracks_vec)
    }

    /// Rebuilds and best-effort publishes tracks, clips, and patterns to the audio thread.
    pub fn broadcast_track_graph(&mut self) {
        let (patterns, clips, tracks) = self.update_track_graph();
        let (tracks_len, patterns_len) = (tracks.len(), patterns.len());
        let _ = self.send_audio_command(AudioCommand::UpdateTrackGraph {
            tracks: tracks,
            clips,
            patterns: patterns,
        });
        log::debug!(
            "number of tracks: {}, number of patterns: {}",
            tracks_len,
            patterns_len
        );
    }

    /// Builds a complete render graph snapshot and best-effort replaces audio-thread graph state.
    pub fn broadcast_full_graph(&mut self) {
        let graph = AudioGraphState::from(&self.app_state);
        let _ = self.send_audio_command(AudioCommand::ReplaceFullGraph { graph });
    }

    /// Converts one project automation lane into its audio-only form and publishes it.
    pub fn broadcast_automation_lane(&mut self, id: AutomationId, lane: &AutomationLane) {
        let lane_audio_graph = AudioAutomationLane {
            points: lane.points.clone(),
            enabled: lane.enabled,
            min: lane.min,
            max: lane.max,
            default_value: lane.default_value,
        };
        let _ = self.send_audio_command(AudioCommand::UpdateAutomationLane {
            id,
            lane: lane_audio_graph,
        });
    }

    /// Records one reversible project action and clears redo state according to history rules.
    pub fn push_history(&mut self, action: ProjectAction) {
        self.history.push(action);
    }

    /// Extracts the position consumer. This should only be called once when starting the UI stream.
    pub fn take_position_consumer(&self) -> Option<Consumer<TransportFeedback>> {
        self.position_consumer.lock().take()
    }

    /// Extracts the feedback consumer.
    pub fn take_feedback_consumer(&self) -> Option<Consumer<AudioFeedback>> {
        self.feedback_consumer.lock().take()
    }

    /// Replaces the UI-owned telemetry registry after engine initialization or restart.
    pub fn update_telemetry_reg(&mut self, new_reg: TelemetryRegistry) {
        self.telemetry_registry = Some(new_reg);
    }

    /// Drain all pending `TelemetryRegistration` messages from the audio thread and
    /// apply them to `telemetry_registry`.
    ///
    /// Call this on every UI frame (e.g. alongside `get_mixer_telemetry_sync`).
    /// It is entirely non-blocking: if no messages are pending it returns immediately.
    pub fn drain_telemetry_registrations(&mut self) {
        let Some(receiver_mutex) = &self.telemetry_reg_receiver else {
            return;
        };

        // Lock the receiver to poll messages
        let receiver = receiver_mutex.lock();
        let Some(reg) = &mut self.telemetry_registry else {
            return;
        };

        while let Ok(msg) = receiver.try_recv() {
            match msg {
                TelemetryRegistration::Registered { target, consumer } => {
                    reg.insert_plugin_consumer(target, *consumer);
                }
                TelemetryRegistration::Removed { target } => {
                    reg.remove_plugin_consumer(&target);
                }
                TelemetryRegistration::BatchRegistered { consumers } => {
                    reg.param_telemetry_consumers.clear();
                    for (target, consumer) in consumers {
                        reg.insert_plugin_consumer(target, *consumer);
                    }
                }
            }
        }
    }
}

/// Process-wide guard ensuring logger initialization is attempted at most once.
pub static INIT_LOGGER: Once = Once::new();
