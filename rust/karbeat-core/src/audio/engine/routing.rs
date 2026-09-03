use hashbrown::HashMap;

use crate::{
    audio::render_state::{AudioGraphState, AudioPluginState},
    core::project::{RoutingNode, SidechainRoute},
    shared::{BusId, TrackId},
};

/// Ring buffer used to align paths for plugin delay compensation.
#[derive(Clone, Default)]
pub struct DelayLine {
    buffer: Vec<f32>,
    write_pos: usize,
    delay_samples: usize,
}

impl DelayLine {
    pub fn set_delay(&mut self, delay_samples: usize, channels: usize) {
        let required_len = delay_samples * channels;
        if self.delay_samples != delay_samples || self.buffer.len() != required_len {
            self.delay_samples = delay_samples;
            self.buffer.resize(required_len, 0.0);
            self.buffer.fill(0.0);
            self.write_pos = 0;
        }
    }

    #[inline(always)]
    pub fn process_block(&mut self, buffer: &mut [f32], channels: usize) {
        if self.delay_samples == 0 {
            return;
        }

        let buffer_len = self.buffer.len();
        for frame in buffer.chunks_mut(channels) {
            let delayed_frame = &mut self.buffer[self.write_pos..self.write_pos + frame.len()];
            for (sample, delayed_sample) in frame.iter_mut().zip(delayed_frame) {
                std::mem::swap(sample, delayed_sample);
            }
            self.write_pos = (self.write_pos + channels) % buffer_len;
        }
    }
}

#[derive(Clone, Default)]
pub(super) struct RoutingState {
    pub cached_order: Vec<RoutingNode>,
    pub track_tails: HashMap<TrackId, u32>,
    pub bus_tails: HashMap<BusId, u32>,
    pub master_tail: u32,
    pub node_has_signal: HashMap<RoutingNode, bool>,
    pub compensation_delays: HashMap<RoutingNode, u32>,
    pub track_delay_lines: HashMap<TrackId, DelayLine>,
    pub bus_delay_lines: HashMap<BusId, DelayLine>,
    pub sidechain_delay_lines: HashMap<SidechainRoute, DelayLine>,
}

impl RoutingState {
    pub fn for_export(&self) -> Self {
        let mut state = self.clone();
        state.node_has_signal.clear();
        state
    }

    pub fn recalculate_latencies(
        &mut self,
        graph: &AudioGraphState,
        plugin_state: &AudioPluginState,
        bus_ids: impl Iterator<Item = BusId>,
        channels: usize,
    ) -> u32 {
        let mut internal_latency = HashMap::new();
        for track in graph.tracks.as_ref() {
            let mut latency = track
                .generator
                .as_ref()
                .and_then(|generator| plugin_state.get_generator(generator.id))
                .map(|instance| instance.plugin.latency_samples())
                .unwrap_or(0);
            if let Some(effects) = plugin_state.get_track_effects(track.id.to_u32() as usize) {
                latency += effects
                    .iter()
                    .map(|effect| effect.plugin.latency_samples())
                    .sum::<u32>();
            }
            internal_latency.insert(RoutingNode::Track(track.id), latency);
        }

        for bus_id in bus_ids {
            let latency = plugin_state
                .get_bus_effects(bus_id.to_u32() as usize)
                .map(|effects| {
                    effects
                        .iter()
                        .map(|effect| effect.plugin.latency_samples())
                        .sum()
                })
                .unwrap_or(0);
            internal_latency.insert(RoutingNode::Bus(bus_id), latency);
        }

        let master_latency = plugin_state
            .master_effects
            .iter()
            .map(|effect| effect.plugin.latency_samples())
            .sum();
        internal_latency.insert(RoutingNode::Master, master_latency);

        let mut path_latency = HashMap::new();
        path_latency.insert(RoutingNode::Master, master_latency);
        for node in self.cached_order.iter().rev() {
            if matches!(node, RoutingNode::Bus(_)) {
                let destination_latency = graph
                    .routing
                    .iter()
                    .filter(|route| route.source == *node)
                    .filter_map(|route| path_latency.get(&route.destination))
                    .copied()
                    .max()
                    .unwrap_or(0);
                path_latency.insert(
                    *node,
                    internal_latency.get(node).copied().unwrap_or(0) + destination_latency,
                );
            }
        }
        for track in graph.tracks.as_ref() {
            let node = RoutingNode::Track(track.id);
            let destination_latency = graph
                .routing
                .iter()
                .filter(|route| route.source == node)
                .filter_map(|route| path_latency.get(&route.destination))
                .copied()
                .max()
                .unwrap_or(0);
            path_latency.insert(
                node,
                internal_latency.get(&node).copied().unwrap_or(0) + destination_latency,
            );
        }

        let maximum_latency = path_latency.values().copied().max().unwrap_or(0);
        for (node, path_latency) in path_latency {
            let compensation = maximum_latency - path_latency;
            self.compensation_delays.insert(node, compensation);
            let delay_line = match node {
                RoutingNode::Track(id) => self.track_delay_lines.entry(id).or_default(),
                RoutingNode::Bus(id) => self.bus_delay_lines.entry(id).or_default(),
                RoutingNode::PluginSidechain(route) => {
                    self.sidechain_delay_lines.entry(route).or_default()
                }
                RoutingNode::Master => continue,
            };
            delay_line.set_delay(compensation as usize, channels);
        }

        maximum_latency
    }
}

#[cfg(test)]
mod tests {
    use super::DelayLine;

    #[test]
    fn process_block_delays_interleaved_frames() {
        let mut delay = DelayLine::default();
        delay.set_delay(2, 2);

        let mut first_block = [1.0, 2.0, 3.0, 4.0];
        delay.process_block(&mut first_block, 2);
        assert_eq!(first_block, [0.0; 4]);

        let mut second_block = [5.0, 6.0, 7.0, 8.0];
        delay.process_block(&mut second_block, 2);
        assert_eq!(second_block, [1.0, 2.0, 3.0, 4.0]);
    }
}
