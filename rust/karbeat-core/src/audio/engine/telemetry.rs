use std::sync::atomic::{AtomicU32, Ordering};

use hashbrown::{HashMap, HashSet};
use karbeat_plugin_api::types::ZeroCopyBuffer;
use triple_buffer::Input;

use crate::{
    audio::engine::AudioMixerState,
    audio::event::PluginTarget,
    commands::{MixerChannelSnapshot, MixerChannelTarget},
    shared::{BusId, TrackId},
};

/// Parameter values and requested custom buffers for one plugin.
#[derive(Clone, Default)]
pub struct PluginTelemetrySnapshot {
    pub parameters: Vec<(u32, f32)>,
    pub buffers: HashMap<String, ZeroCopyBuffer>,
}

impl PluginTelemetrySnapshot {
    pub fn from_plugin(plugin: &dyn crate::core::project::plugin::AudioPlugin) -> Self {
        let parameters = plugin
            .get_parameter_specs()
            .into_iter()
            .map(|spec| (spec.id, plugin.get_current_parameter(spec.id)))
            .collect();
        Self {
            parameters,
            buffers: HashMap::new(),
        }
    }
}

/// Meter and parameter values for all mixer channels.
#[derive(Clone, Default)]
pub struct MixerTelemetrySnapshot {
    pub tracks: HashMap<TrackId, MixerChannelSnapshot>,
    pub buses: HashMap<BusId, MixerChannelSnapshot>,
    pub master: Option<MixerChannelSnapshot>,
}

/// Audio-thread producers for low-contention UI telemetry.
pub struct AudioEngineTelemetry {
    /// Producer for the complete mixer snapshot.
    pub mixer_telemetry_producer: Input<MixerTelemetrySnapshot>,
    /// Producers created for individual plugin subscriptions.
    pub param_telemetry_producers: HashMap<PluginTarget, Input<PluginTelemetrySnapshot>>,
    /// Whether mixer snapshots currently have a consumer.
    pub mixer_snapshot_active: bool,
    /// Requested custom buffer names for each subscribed plugin.
    pub active_telemetry_subscriptions: HashMap<PluginTarget, HashSet<String>>,
    pub(super) samples_since_last_snapshot: usize,
}

impl AudioEngineTelemetry {
    /// Creates live telemetry and returns its mixer consumer.
    pub fn new() -> (Self, triple_buffer::Output<MixerTelemetrySnapshot>) {
        let (mixer_input, mixer_output) =
            triple_buffer::triple_buffer(&MixerTelemetrySnapshot::default());
        let telemetry = Self {
            mixer_telemetry_producer: mixer_input,
            param_telemetry_producers: HashMap::new(),
            mixer_snapshot_active: false,
            active_telemetry_subscriptions: HashMap::new(),
            samples_since_last_snapshot: 0,
        };
        (telemetry, mixer_output)
    }

    /// Creates detached telemetry for an offline export engine.
    pub fn new_for_export() -> Self {
        let (mixer_input, _) = triple_buffer::triple_buffer(&MixerTelemetrySnapshot::default());
        Self {
            mixer_telemetry_producer: mixer_input,
            param_telemetry_producers: HashMap::new(),
            mixer_snapshot_active: false,
            active_telemetry_subscriptions: HashMap::new(),
            samples_since_last_snapshot: 0,
        }
    }

    pub(super) fn advance(&mut self, frame_count: usize, sample_rate: u32) -> bool {
        self.samples_since_last_snapshot += frame_count;
        let interval = sample_rate as usize / 30;
        if interval == 0 || self.samples_since_last_snapshot < interval {
            return false;
        }
        self.samples_since_last_snapshot %= interval;
        true
    }

    pub(super) fn emit_mixer_snapshot(&mut self, mixer: &AudioMixerState) {
        if !self.mixer_snapshot_active {
            return;
        }

        let snapshot = self.mixer_telemetry_producer.input_buffer_mut();
        snapshot.tracks.clear();
        snapshot.buses.clear();
        snapshot.master = Some(mixer.snapshot(MixerChannelTarget::Master));
        for &track_id in mixer.track_channels.keys() {
            snapshot.tracks.insert(
                track_id,
                mixer.snapshot(MixerChannelTarget::Track(track_id)),
            );
        }
        for &bus_id in mixer.bus_channels.keys() {
            snapshot
                .buses
                .insert(bus_id, mixer.snapshot(MixerChannelTarget::Bus(bus_id)));
        }

        self.mixer_telemetry_producer.publish();
    }
}

pub static DSP_LOAD_PERCENT: AtomicU32 = AtomicU32::new(0);

pub fn get_current_dsp_load() -> f32 {
    f32::from_bits(DSP_LOAD_PERCENT.load(Ordering::Relaxed))
}

pub fn record_dsp_load(elapsed_seconds: f32, frame_count: usize, sample_rate: u32) {
    if frame_count == 0 || sample_rate == 0 {
        return;
    }
    let deadline = frame_count as f32 / sample_rate as f32;
    let load_percent = elapsed_seconds / deadline * 100.0;
    let current = f32::from_bits(DSP_LOAD_PERCENT.load(Ordering::Relaxed));
    let smoothed = current + 0.1 * (load_percent - current);
    DSP_LOAD_PERCENT.store(smoothed.to_bits(), Ordering::Relaxed);
}
