//! Centralized application context containing all shared state.
//!
//! This module replaces scattered lazy static globals with a single `KarbeatContext` struct
//! for improved testability and explicit dependencies.

use std::sync::{mpsc, Arc, Once};

use hashbrown::HashMap;
use karbeat_plugin_api::traits::AudioPlugin;
use karbeat_plugins::registry::PluginRegistry;
use parking_lot::{Mutex, RwLock};
use rtrb::{Consumer, Producer};

use crate::{
    audio::{
        backend::AudioDeviceConfig,
        event::TransportFeedback,
        render_state::{AudioAutomationLane, AudioGraphState},
    },
    commands::{AudioCommand, AudioFeedback, TelemetryRegistration},
    core::{
        history::{HistoryManager, ProjectAction},
        project::{ApplicationState, AudioTrack, AutomationLane, Pattern},
    },
    message::TelemetryRegistry,
    shared::{AutomationId, PatternId},
};

pub struct DawContext {
    pub app_state: ApplicationState,
    /// Undo/redo history manager
    pub history: HistoryManager,

    /// Audio command queue producer (UI → Audio)
    pub command_sender: Mutex<Option<Producer<AudioCommand>>>,

    /// Parameter feedback consumer (Audio → UI)
    pub feedback_consumer: Arc<Mutex<Option<rtrb::Consumer<AudioFeedback>>>>,

    /// Audio stream handle
    pub stream_guard: Option<cpal::Stream>,

    /// Playback position ring buffer consumer
    pub position_consumer: Arc<Mutex<Option<rtrb::Consumer<TransportFeedback>>>>,

    /// Plugin factory registry
    pub plugin_registry: PluginRegistry,

    /// The live, thread-safe audio configuration.
    /// The UI writes to this, and the background stream monitor reads from it.
    pub active_audio_config: Arc<RwLock<AudioDeviceConfig>>,

    pub telemetry_registry: Option<TelemetryRegistry>,

    /// Receiver for per-plugin triple-buffer `Output` consumers sent from the audio thread.
    ///
    /// The audio thread sends a `TelemetryRegistration` message whenever a plugin is
    /// added or removed. The UI thread polls this receiver (e.g. on every frame) to
    /// keep `telemetry_registry.param_telemetry_consumers` in sync.
    pub telemetry_reg_receiver: Option<Mutex<mpsc::Receiver<TelemetryRegistration>>>,
}

impl DawContext {
    pub fn new() -> Self {
        Self {
            app_state: ApplicationState::default(),
            history: HistoryManager::new(),
            command_sender: Mutex::new(None),
            feedback_consumer: Arc::new(Mutex::new(None)),
            stream_guard: None,
            position_consumer: Arc::new(Mutex::new(None)),
            plugin_registry: PluginRegistry::new_with_defaults(),
            active_audio_config: Arc::new(RwLock::new(AudioDeviceConfig::default())),
            telemetry_registry: None,
            telemetry_reg_receiver: None,
        }
    }

    pub fn send_audio_command(&mut self, command: AudioCommand) -> anyhow::Result<()> {
        if let Some(sender) = self.command_sender.lock().as_mut() {
            let _ = sender.push(command);
        } else {
            return Err(anyhow::anyhow!("Audio stream is not initialized"));
        };

        Ok(())
    }

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

    pub fn get_plugin_box(&self, registry_id: u32) -> Option<Box<dyn AudioPlugin + Send + Sync>> {
        let registry = &self.plugin_registry;
        let Some((plugin, _)) = registry.create_plugin_by_id(registry_id) else {
            return None;
        };

        Some(plugin)
    }

    // ======================================
    // Granular graph-state broadcast helpers
    // ======================================

    fn update_track_graph(&mut self) -> (HashMap<PatternId, Pattern>, Box<[AudioTrack]>) {
        let app = &mut self.app_state;
        let mut tracks_vec: Box<[AudioTrack]> = app.tracks.values().cloned().collect();
        tracks_vec.sort_by_key(|t| t.id);

        // return the pattern pool and tracks
        (app.pattern_pool.clone(), tracks_vec)
    }

    pub fn broadcast_track_graph(&mut self) {
        let (patterns, tracks) = self.update_track_graph();
        let (tracks_len, patterns_len) = (tracks.len(), patterns.len());
        let _ = self.send_audio_command(AudioCommand::UpdateTrackGraph {
            tracks: tracks,
            patterns: patterns,
        });
        log::debug!(
            "number of tracks: {}, number of patterns: {}",
            tracks_len,
            patterns_len
        );
    }

    pub fn broadcast_full_graph(&mut self) {
        let graph = AudioGraphState::from(&self.app_state);
        let _ = self.send_audio_command(AudioCommand::ReplaceFullGraph { graph });
    }

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

pub static INIT_LOGGER: Once = Once::new();
