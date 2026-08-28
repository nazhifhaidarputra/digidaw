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
    // Song playback position
    pub samples: u32,
    pub ticks: u32,
    pub beat: usize,
    pub bar: usize,
    pub tempo: f32, // Useful for Flutter to interpolate movement
    pub sample_rate: u32,

    // Transport state
    pub is_playing: bool,
    pub is_looping: bool,
    pub is_recording: bool,
    pub is_pattern_playing: bool,

    // Pattern playback (independent from song)
    pub is_pattern_mode: bool,
    pub pattern_samples: u32,
    pub pattern_ticks: u32,
    pub pattern_beat: usize,
    pub pattern_bar: usize,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Hash, Eq)]
pub enum PluginTarget {
    Generator(GeneratorId),
    TrackEffect(TrackId, EffectId),
    BusEffect(BusId, EffectId),
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
