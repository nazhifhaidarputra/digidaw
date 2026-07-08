use hashbrown::HashMap;
use triple_buffer::Output;

use crate::audio::{
    engine::{MixerTelemetrySnapshot, PluginTelemetrySnapshot},
    event::PluginTarget,
};

pub enum AudioEngineResponse {
    PluginCommandResponse {
        request_id: u32,
        response: serde_json::Value,
    },
}

pub type TelemetryBlob = Box<[f32]>;

/// UI-thread-owned telemetry consumers.
///
/// `mixer_telemetry_consumer` is a single triple-buffer `Output` that always
/// reflects the latest full mixer snapshot written by the audio thread.
///
/// `param_telemetry_consumers` is a per-plugin map; entries are inserted when a
/// plugin is added to the engine and removed when it is removed.
pub struct TelemetryRegistry {
    /// Consumer for the full mixer snapshot.
    pub mixer_telemetry_consumer: Output<MixerTelemetrySnapshot>,

    /// Per-plugin parameter telemetry consumers.
    pub param_telemetry_consumers: HashMap<PluginTarget, Output<PluginTelemetrySnapshot>>,
}

impl TelemetryRegistry {
    /// Create a registry from the mixer `Output` consumer produced during
    /// `AudioEngineTelemetry::new()`.  The plugin consumer map starts empty
    /// and is populated as plugins are registered.
    pub fn new(mixer_consumer: Output<MixerTelemetrySnapshot>) -> Self {
        Self {
            mixer_telemetry_consumer: mixer_consumer,
            param_telemetry_consumers: HashMap::new(),
        }
    }

    /// Register or replace the consumer for a plugin target.
    pub fn insert_plugin_consumer(
        &mut self,
        target: PluginTarget,
        consumer: Output<PluginTelemetrySnapshot>,
    ) {
        self.param_telemetry_consumers.insert(target, consumer);
    }

    /// Remove the consumer for a plugin target (called when the plugin is removed).
    pub fn remove_plugin_consumer(&mut self, target: &PluginTarget) {
        self.param_telemetry_consumers.remove(target);
    }
}
