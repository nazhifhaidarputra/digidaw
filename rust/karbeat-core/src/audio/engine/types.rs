use std::sync::Arc;

use arc_swap::ArcSwap;
use hashbrown::{HashMap, HashSet};
use karbeat_plugin_api::types::ZeroCopyBuffer;

use crate::{audio::event::PluginTarget, commands::MixerChannelSnapshot, shared::*};

/// A snapshot of a single plugin's current state (Params + Custom Buffers)
#[derive(Clone, Default)]
pub struct PluginTelemetrySnapshot {
    pub parameters: Vec<(u32, f32)>,
    pub buffers: HashMap<String, ZeroCopyBuffer>,
}

/// A unified snapshot of the entire mixer state.
/// This is extremely cheap to clone and push, so we can do the whole mixer at once.
#[derive(Clone, Default)]
pub struct MixerTelemetrySnapshot {
    pub tracks: HashMap<TrackId, MixerChannelSnapshot>,
    pub buses: HashMap<BusId, MixerChannelSnapshot>,
    pub master: Option<MixerChannelSnapshot>,
}

/// A snapshot of plugin parameters.
/// Because querying 100+ plugins is heavy, this will only contain plugins the UI is actively watching.
#[derive(Clone, Default)]
pub struct ActivePluginTelemetrySnapshots {
    pub active_plugins: HashMap<PluginTarget, PluginTelemetrySnapshot>,
}

#[derive(Clone, Default)]
pub struct AudioEngineTelemetry {
    pub mixer_telemetry: Arc<ArcSwap<MixerTelemetrySnapshot>>,
    pub param_telemetry: Arc<ArcSwap<ActivePluginTelemetrySnapshots>>,

    /// Flag to check whether the UI really needs this data (e.g opening mixer screen)
    pub mixer_snapshot_active: bool,

    /// Track the subscription
    pub active_telemetry_subscriptions: HashMap<PluginTarget, HashSet<String>>,
}