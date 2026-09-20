use serde::{Deserialize, Serialize};

use crate::{
    core::project::{
        AutomationTarget, EffectAutomationTarget, MixerChannelParamTarget, TrackAutomationTarget,
    },
    shared::id::*,
};

/// Transport feedback struct sent from the audio thread to Flutter.
/// This is the single source of truth for all runtime transport state.
#[derive(Clone, Copy, Debug)]
pub struct TransportFeedback {
    /// Song playhead position in engine-rate samples.
    pub samples: u32,
    /// Song playhead position in pulses-per-quarter-note ticks.
    pub ticks: u32,
    /// One-based beat index in the song timeline.
    pub beat: usize,
    /// One-based bar index in the song timeline.
    pub bar: usize,
    /// Current tempo in beats per minute, allowing clients to interpolate between updates.
    pub tempo: f32,
    /// Engine sample rate used to interpret sample positions.
    pub sample_rate: u32,

    /// Whether the currently selected playback mode is running.
    pub is_playing: bool,
    /// Whether song playback loops at the configured loop boundary.
    pub is_looping: bool,
    /// Whether song recording is armed and active.
    pub is_recording: bool,
    /// Whether independent pattern playback is running.
    pub is_pattern_playing: bool,

    /// Whether pattern mode, rather than song mode, owns the active playhead.
    pub is_pattern_mode: bool,
    /// Pattern playhead position in engine-rate samples.
    pub pattern_samples: u32,
    /// Pattern playhead position in pulses-per-quarter-note ticks.
    pub pattern_ticks: u32,
    /// One-based beat index within pattern playback.
    pub pattern_beat: usize,
    /// One-based bar index within pattern playback.
    pub pattern_bar: usize,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Hash, Eq)]
/// Identifies one plugin instance independent of whether it is a generator or mixer effect.
pub enum PluginTarget {
    /// Generator plugin in the project generator pool.
    Generator(GeneratorId),
    /// Effect on a track mixer channel.
    TrackEffect(TrackId, EffectId),
    /// Effect on a bus mixer channel.
    BusEffect(BusId, EffectId),
    /// Effect on the master mixer channel.
    MasterEffect(EffectId),
}

impl TryFrom<&AutomationTarget> for PluginTarget {
    type Error = &'static str;

    fn try_from(target: &AutomationTarget) -> Result<Self, Self::Error> {
        target
            .as_plugin_target()
            .ok_or("AutomationTarget does not map to a PluginTarget")
    }
}

impl PluginTarget {
    /// Builds the automation target for parameter `param_id` on this plugin instance.
    pub fn to_automation_target(&self, param_id: u32) -> AutomationTarget {
        match self {
            PluginTarget::Generator(generator_id) => AutomationTarget::Generator {
                generator_id: *generator_id,
                param_id,
            },
            PluginTarget::TrackEffect(track_id, effect_id) => AutomationTarget::Track {
                track_id: *track_id,
                track_target: TrackAutomationTarget::MixerChannel(
                    MixerChannelParamTarget::Plugin {
                        effect_id: *effect_id,
                        target: EffectAutomationTarget::PluginParam { param_id },
                    },
                ),
            },
            PluginTarget::BusEffect(bus_id, effect_id) => AutomationTarget::Bus {
                bus_id: *bus_id,
                mix_target: MixerChannelParamTarget::Plugin {
                    effect_id: *effect_id,
                    target: EffectAutomationTarget::PluginParam { param_id },
                },
            },
            PluginTarget::MasterEffect(effect_id) => AutomationTarget::Master(
                crate::core::project::MasterAutomationTarget::MixerChannel(
                    MixerChannelParamTarget::Plugin {
                        effect_id: *effect_id,
                        target: EffectAutomationTarget::PluginParam { param_id },
                    },
                ),
            ),
        }
    }
}
