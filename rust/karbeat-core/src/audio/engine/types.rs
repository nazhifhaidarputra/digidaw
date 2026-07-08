use hashbrown::{HashMap, HashSet};
use karbeat_plugin_api::types::ZeroCopyBuffer;
use triple_buffer::Input;

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

/// Audio-thread-owned telemetry state.
/// The engine writes into triple-buffer `Input` producers; the UI thread reads
/// from the matching `Output` consumers held in `TelemetryRegistry`.
pub struct AudioEngineTelemetry {
    /// Triple-buffer producer for the full mixer snapshot (all tracks + buses + master).
    pub mixer_telemetry_producer: Input<MixerTelemetrySnapshot>,

    /// Per-plugin triple-buffer producers — keyed by `PluginTarget`.
    /// A new entry is inserted when a plugin is added, and removed when it is removed.
    pub param_telemetry_producers: HashMap<PluginTarget, Input<PluginTelemetrySnapshot>>,

    /// Flag to check whether the UI really needs this data (e.g opening mixer screen)
    pub mixer_snapshot_active: bool,

    /// Track the subscription
    pub active_telemetry_subscriptions: HashMap<PluginTarget, HashSet<String>>,
}

impl AudioEngineTelemetry {
    /// Create a new telemetry instance.
    /// Returns the matching `Output` consumers that should be placed in `TelemetryRegistry`.
    pub fn new() -> (Self, triple_buffer::Output<MixerTelemetrySnapshot>) {
        let (mixer_input, mixer_output) =
            triple_buffer::triple_buffer(&MixerTelemetrySnapshot::default());

        let this = Self {
            mixer_telemetry_producer: mixer_input,
            param_telemetry_producers: HashMap::new(),
            mixer_snapshot_active: false,
            active_telemetry_subscriptions: HashMap::new(),
        };

        (this, mixer_output)
    }

    /// Create a fresh, detached instance for use in the export engine.
    /// The export engine never needs to push telemetry to the UI, so these
    /// producers are simply discarded after export.
    pub fn new_for_export() -> Self {
        let (mixer_input, _) =
            triple_buffer::triple_buffer(&MixerTelemetrySnapshot::default());

        Self {
            mixer_telemetry_producer: mixer_input,
            param_telemetry_producers: HashMap::new(),
            mixer_snapshot_active: false,
            active_telemetry_subscriptions: HashMap::new(),
        }
    }
}