use hashbrown::{HashMap, HashSet};
use karbeat_plugin_api::types::ParamChange;

use crate::{
    audio::{
        event::PluginTarget,
        render_state::{AudioAutomationLane, AudioGraphState},
    },
    core::project::{AutomationTarget, ModulationLink, ModulationSource},
    shared::{AutomationId, ModulationId, constants::f64::PPQ},
};

#[derive(Clone)]
pub struct LiveLfo {
    pub rate_hz: f32,
    pub phase: f32,
}

#[derive(Clone)]
pub enum LiveModulationSource {
    LFO(LiveLfo),
    Automation {
        lane_id: crate::shared::AutomationId,
    },
    PeakController {
        source: PluginTarget,
    },
}

impl LiveModulationSource {
    pub fn from_project(source: &ModulationSource) -> Self {
        match source {
            ModulationSource::LFO { rate_hz } => Self::LFO(LiveLfo {
                rate_hz: *rate_hz,
                phase: 0.0,
            }),
            ModulationSource::Automation { lane_id } => Self::Automation { lane_id: *lane_id },
            ModulationSource::PeakController { source } => Self::PeakController { source: *source },
        }
    }
}

#[derive(Clone, Default)]
pub(super) struct ModulationState {
    pub active_sources: HashMap<ModulationId, (LiveModulationSource, f32)>,
    pub active_links: Vec<ModulationLink>,
    pub suspended_targets: HashSet<AutomationTarget>,
    pub block_param_changes: HashMap<PluginTarget, Vec<ParamChange>>,
}

impl ModulationState {
    pub fn for_export(&self) -> Self {
        let mut state = self.clone();
        state.block_param_changes.clear();
        state
    }

    pub fn add_source(&mut self, id: ModulationId, source: &ModulationSource) {
        self.active_sources
            .insert(id, (LiveModulationSource::from_project(source), 0.0));
    }

    pub fn replace_from_graph(&mut self, graph: &AudioGraphState) {
        self.active_sources.clear();
        self.active_links.clear();
        self.suspended_targets.clear();
        self.block_param_changes.clear();

        for (&id, source) in &graph.modulation_sources {
            self.add_source(id, source);
        }
        self.active_links
            .extend(graph.modulation_links.values().cloned());
    }

    pub fn set_source_output(&mut self, id: ModulationId, value: f32) {
        if let Some((_, output)) = self.active_sources.get_mut(&id) {
            *output = value;
        }
    }

    pub fn evaluate(
        &mut self,
        buffer_size: usize,
        bpm: f32,
        sample_rate: u32,
        playhead_samples: u32,
        automation_lanes: &HashMap<AutomationId, AudioAutomationLane>,
    ) -> HashMap<AutomationTarget, (Option<f32>, f32)> {
        if bpm <= 0.0 {
            return HashMap::new();
        }

        let sample_rate = sample_rate as f32;
        let samples_per_tick = (60.0 / bpm) * sample_rate / PPQ as f32;
        let current_tick = (playhead_samples as f64 / samples_per_tick as f64) as u32;

        for (source, output) in self.active_sources.values_mut() {
            match source {
                LiveModulationSource::LFO(lfo) => {
                    let phase_increment = lfo.rate_hz * buffer_size as f32 / sample_rate;
                    lfo.phase = (lfo.phase + phase_increment).fract();
                    *output = (lfo.phase * std::f32::consts::TAU).sin();
                }
                LiveModulationSource::Automation { lane_id } => {
                    if let Some(lane) = automation_lanes.get(lane_id) {
                        *output = lane.value_at_ticks(current_tick) as f32;
                    }
                }
                LiveModulationSource::PeakController { .. } => {}
            }
        }

        self.active_links.iter().fold(
            HashMap::<AutomationTarget, (Option<f32>, f32)>::new(),
            |mut accumulators, link| {
                if let Some((source, output)) = self.active_sources.get(&link.source_id) {
                    let entry = accumulators
                        .entry(link.target.clone())
                        .or_insert((None, 0.0));
                    match source {
                        LiveModulationSource::Automation { .. } => {
                            if !self.suspended_targets.contains(&link.target) {
                                entry.0 = Some(*output);
                            }
                        }
                        _ => entry.1 += output * link.depth,
                    }
                }
                accumulators
            },
        )
    }

    pub fn base_value(&self, target: &AutomationTarget) -> f32 {
        self.active_links
            .iter()
            .find(|link| link.target == *target)
            .map(|link| link.base_value)
            .unwrap_or(0.0)
    }
}
