//! Centralized application context containing all shared state.
//!
//! This module replaces scattered lazy static globals with a single `KarbeatContext` struct
//! for improved testability and explicit dependencies.

use std::sync::{Arc, Once};

use hashbrown::HashMap;
use karbeat_plugin_api::traits::AudioPlugin;
use karbeat_plugins::registry::PluginRegistry;
use parking_lot::{Mutex, RwLock};
use rtrb::{Consumer, Producer};

use crate::{
    audio::{
        backend::AudioDeviceConfig, event::TransportFeedback, render_state::{AudioAutomationLane, AudioGraphState}
    }, commands::{AudioCommand, AudioFeedback}, core::{
        history::{HistoryManager, ProjectAction},
        project::{ApplicationState, AudioTrack, Pattern},
    }, message::TelemetryRegistry, shared::{AutomationId, PatternId}
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

    pub telemetry_registry: TelemetryRegistry,
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
            telemetry_registry: TelemetryRegistry::default(),
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
        log::debug!("number of tracks: {}, number of patterns: {}", tracks_len, patterns_len);
    }

    pub fn broadcast_full_graph(&mut self) {
        let graph = AudioGraphState::from(&self.app_state);
        let _ = self.send_audio_command(AudioCommand::ReplaceFullGraph { graph });
    }

    pub fn broadcast_automation_lane(&mut self, id: AutomationId) {
        let app = &self.app_state;
        let Some(lane_arc) = app.automation_pool.get(&id) else {
            return;
        };
        let lane = AudioAutomationLane {
            points: lane_arc.points.clone(),
            enabled: lane_arc.enabled,
            min: lane_arc.min,
            max: lane_arc.max,
            default_value: lane_arc.default_value,
        };
        let _ = self.send_audio_command(AudioCommand::UpdateAutomationLane { id, lane });
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
        self.telemetry_registry =  new_reg;
    }
}

pub static INIT_LOGGER: Once = Once::new();
