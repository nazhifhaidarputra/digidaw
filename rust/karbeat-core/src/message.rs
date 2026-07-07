use std::sync::Arc;

use arc_swap::ArcSwap;

use crate::audio::engine::{ActivePluginTelemetrySnapshots, MixerTelemetrySnapshot};

pub enum AudioEngineResponse {
    PluginCommandResponse {
        request_id: u32,
        response: serde_json::Value,
    },
}
pub type TelemetryBlob = Box<[f32]>;

#[derive(Clone, Default)]
pub struct TelemetryRegistry {
    pub mixer_telemetry: Arc<ArcSwap<MixerTelemetrySnapshot>>,
    pub param_telemetry: Arc<ArcSwap<ActivePluginTelemetrySnapshots>>,
}
