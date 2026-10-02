use hashbrown::HashMap;

use crate::{
    audio::engine::kernels::mix_gain,
    audio::render_state::{AudioEffectInstance, AudioGraphState, AudioPluginState},
    core::project::{RoutingConnection, RoutingNode, RoutingTap, SidechainRoute},
    shared::{BusId, EffectId, TrackId},
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

/// Delay-compensation layout for one routing graph.
#[derive(Debug, Default, PartialEq, Eq)]
pub(super) struct LatencyPlan {
    /// Delay applied to a track's own signal before its effects, so that a sidechain source
    /// arriving later than the track can still line up with it.
    pub track_input_delays: HashMap<TrackId, u32>,
    /// Delay applied on each `(source, destination)` connection that needs alignment.
    pub edge_delays: HashMap<(RoutingNode, RoutingNode), u32>,
    /// Latency of the master output relative to the unprocessed timeline.
    pub system_latency: u32,
}

/// Plans plugin delay compensation with a forward arrival-time pass over `order`.
///
/// `arrive(node)` is when a node's input is aligned: the latest `arrive(src) + latency(src)`
/// over its inputs. Each connection is delayed by the gap between its source's output time and
/// its destination's arrival time, so every input of a node lines up without stacking a node's
/// own compensation onto the signals that pass through it.
///
/// A channel without a main output route is unlinked: it reaches master only through its
/// sends, so it contributes no implicit path.
///
/// `sidechain_target` returns the channel owning a sidechained plugin and the latency in front of
/// that plugin inside the channel. The sidechain signal is aligned with the plugin's main input;
/// when the source is later than that, the owner's arrival moves later too. Routes it returns
/// `None` for (generator sidechains) are not compensated.
pub(super) fn plan_latency(
    order: &[RoutingNode],
    routes: &[RoutingConnection],
    node_latency: impl Fn(RoutingNode) -> u32,
    sidechain_target: impl Fn(SidechainRoute) -> Option<(RoutingNode, u32)>,
) -> LatencyPlan {
    let mut arrive: HashMap<RoutingNode, u32> = HashMap::new();
    let mut output: HashMap<RoutingNode, u32> = HashMap::new();
    for &node in order {
        let mut time = 0;
        for route in routes {
            let target = match route.destination {
                RoutingNode::PluginSidechain(sidechain) => sidechain_target(sidechain)
                    .filter(|(owner, _)| *owner == node)
                    .map(|(_, before)| before),
                destination if destination == node => Some(0),
                _ => None,
            };
            if let (Some(before), Some(&source)) = (target, output.get(&route.source)) {
                time = time.max(source.saturating_sub(before));
            }
        }
        arrive.insert(node, time);
        output.insert(node, time.saturating_add(node_latency(node)));
    }

    let mut plan = LatencyPlan::default();
    let mut connect = |source: RoutingNode, destination: RoutingNode, target: Option<u32>| {
        let delay = match (target, output.get(&source)) {
            (Some(target), Some(&source)) => target.saturating_sub(source),
            _ => 0,
        };
        if delay > 0 {
            plan.edge_delays.insert((source, destination), delay);
        }
    };
    for route in routes {
        let target = match route.destination {
            RoutingNode::PluginSidechain(sidechain) => sidechain_target(sidechain)
                .and_then(|(owner, before)| Some(arrive.get(&owner)?.saturating_add(before))),
            destination => arrive.get(&destination).copied(),
        };
        connect(route.source, route.destination, target);
    }
    for (&node, &time) in &arrive {
        if let RoutingNode::Track(track) = node
            && time > 0
        {
            plan.track_input_delays.insert(track, time);
        }
    }
    plan.system_latency = output.get(&RoutingNode::Master).copied().unwrap_or(0);
    plan
}

/// Latency of `effects` in front of the effect `id`, or `None` when it is not in the chain.
fn latency_before(effects: &[AudioEffectInstance], id: EffectId) -> Option<u32> {
    let position = effects.iter().position(|effect| effect.id == id)?;
    Some(
        effects
            .iter()
            .take(position)
            .map(AudioEffectInstance::active_latency_samples)
            .sum(),
    )
}

fn chain_latency(effects: Option<&Vec<AudioEffectInstance>>) -> u32 {
    effects.map_or(0, |effects| {
        effects
            .iter()
            .map(AudioEffectInstance::active_latency_samples)
            .sum()
    })
}

fn sync_delay_lines<K: Copy + Eq + std::hash::Hash>(
    lines: &mut HashMap<K, DelayLine>,
    delays: &HashMap<K, u32>,
    channels: usize,
) {
    lines.retain(|key, _| delays.contains_key(key));
    for (&key, &delay) in delays {
        lines
            .entry(key)
            .or_default()
            .set_delay(usize::try_from(delay).unwrap_or(usize::MAX), channels);
    }
}

/// Buffers a routed signal can be mixed into during one render block.
pub(super) struct RouteTargets<'a> {
    /// Interleaved master input.
    pub output: &'a mut [f32],
    pub bus_buffers: &'a mut HashMap<BusId, Vec<f32>>,
    pub aux_buffers: &'a mut HashMap<SidechainRoute, Vec<f32>>,
    /// Scratch used to delay one connection without touching the source signal.
    pub edge_buffer: &'a mut [f32],
}

#[derive(Default)]
pub(super) struct RoutingState {
    pub cached_order: Vec<RoutingNode>,
    pub outgoing_routes: HashMap<RoutingNode, Vec<RoutingConnection>>,
    pub track_tails: HashMap<TrackId, u32>,
    pub bus_tails: HashMap<BusId, u32>,
    pub master_tail: u32,
    pub node_has_signal: HashMap<RoutingNode, bool>,
    /// Latency of the master output from the latest compensation plan.
    pub system_latency: u32,
    /// Set by commands that change routing or chain latency; the next block replans.
    pub latency_dirty: bool,
    pub track_input_delay_lines: HashMap<TrackId, DelayLine>,
    pub edge_delay_lines: HashMap<(RoutingNode, RoutingNode), DelayLine>,
}

impl RoutingState {
    pub fn set_routes(&mut self, routes: &[RoutingConnection]) {
        self.outgoing_routes.clear();
        for route in routes {
            self.outgoing_routes
                .entry(route.source)
                .or_default()
                .push(route.clone());
        }
    }

    /// Replans delay compensation for the cached order and resizes the delay lines. Runs on
    /// command and preparation paths, never inside the render loop.
    pub fn recalculate_latencies(
        &mut self,
        graph: &AudioGraphState,
        plugin_state: &AudioPluginState,
        channels: usize,
    ) -> u32 {
        let generator_latency = |track: TrackId| {
            graph
                .tracks
                .iter()
                .find(|item| item.id == track)
                .and_then(|item| item.generator.as_ref())
                .and_then(|generator| plugin_state.get_generator(generator.id))
                .map_or(0, |instance| instance.plugin.latency_samples())
        };
        let node_latency = |node| match node {
            RoutingNode::Track(id) => generator_latency(id).saturating_add(chain_latency(
                plugin_state.get_track_effects(id.to_u32() as usize),
            )),
            RoutingNode::Bus(id) => {
                chain_latency(plugin_state.get_bus_effects(id.to_u32() as usize))
            }
            RoutingNode::Master => chain_latency(Some(&plugin_state.master_effects)),
            RoutingNode::PluginSidechain(_) => 0,
        };
        let sidechain_target = |route| match route {
            SidechainRoute::TrackEffect(track, effect) => {
                let effects = plugin_state.get_track_effects(track.to_u32() as usize)?;
                let before = latency_before(effects, effect)?;
                Some((
                    RoutingNode::Track(track),
                    generator_latency(track).saturating_add(before),
                ))
            }
            SidechainRoute::BusEffect(bus, effect) => {
                let effects = plugin_state.get_bus_effects(bus.to_u32() as usize)?;
                Some((RoutingNode::Bus(bus), latency_before(effects, effect)?))
            }
            SidechainRoute::MasterEffect(effect) => Some((
                RoutingNode::Master,
                latency_before(&plugin_state.master_effects, effect)?,
            )),
            SidechainRoute::Generator(_) => None,
        };
        let plan = plan_latency(
            &self.cached_order,
            &graph.routing,
            node_latency,
            sidechain_target,
        );
        sync_delay_lines(
            &mut self.track_input_delay_lines,
            &plan.track_input_delays,
            channels,
        );
        sync_delay_lines(&mut self.edge_delay_lines, &plan.edge_delays, channels);
        self.system_latency = plan.system_latency;
        plan.system_latency
    }

    /// Mixes a channel's signal into each of its destinations for one render block.
    ///
    /// Each connection reads the post- or pre-fader signal chosen by its tap, passes it through
    /// its compensation delay when it has one, and mixes it at the connection's send level. A
    /// channel without routes is unlinked and reaches nothing. Real-time safe: all buffers are
    /// sized before the render loop and missing destinations are skipped.
    pub fn route_signal(
        &mut self,
        source: RoutingNode,
        routes: &[RoutingConnection],
        post_fader: &[f32],
        pre_fader: &[f32],
        channels: usize,
        targets: &mut RouteTargets<'_>,
    ) {
        for route in routes {
            let signal = match route.tap {
                RoutingTap::PostFader => post_fader,
                RoutingTap::PreFader => pre_fader,
            };
            self.mix_connection(
                source,
                route.destination,
                signal,
                route.send_level,
                channels,
                targets,
            );
        }
    }

    fn mix_connection(
        &mut self,
        source: RoutingNode,
        destination: RoutingNode,
        signal: &[f32],
        gain: f32,
        channels: usize,
        targets: &mut RouteTargets<'_>,
    ) {
        let delayed = self
            .edge_delay_lines
            .get_mut(&(source, destination))
            .zip(targets.edge_buffer.get_mut(..signal.len()));
        let signal = match delayed {
            Some((delay_line, delayed)) => {
                delayed.copy_from_slice(signal);
                delay_line.process_block(delayed, channels);
                &*delayed
            }
            None => signal,
        };
        let buffer = match destination {
            RoutingNode::Master => Some(&mut *targets.output),
            RoutingNode::Bus(bus) => targets.bus_buffers.get_mut(&bus).map(Vec::as_mut_slice),
            RoutingNode::PluginSidechain(route) => {
                targets.aux_buffers.get_mut(&route).map(Vec::as_mut_slice)
            }
            RoutingNode::Track(_) => None,
        };
        if let Some(buffer) = buffer {
            mix_gain(buffer, signal, gain);
            self.node_has_signal.insert(destination, true);
        }
    }

    /// Drops every delay line; the next recalculation rebuilds them with cleared history.
    pub fn clear_delay_lines(&mut self) {
        self.track_input_delay_lines.clear();
        self.edge_delay_lines.clear();
    }
}

#[cfg(test)]
mod tests {
    use super::{DelayLine, LatencyPlan, plan_latency};
    use crate::{
        core::project::{RoutingConnection, RoutingNode, SidechainRoute},
        shared::{BusId, EffectId, TrackId},
    };
    use hashbrown::HashMap;

    fn track(id: u32) -> RoutingNode {
        RoutingNode::Track(TrackId::from(id))
    }

    fn latencies(values: &[(RoutingNode, u32)]) -> impl Fn(RoutingNode) -> u32 {
        let values: HashMap<_, _> = values.iter().copied().collect();
        move |node| values.get(&node).copied().unwrap_or(0)
    }

    #[test]
    fn bus_inputs_align_without_stacking_bus_compensation_on_them() {
        // C (50 samples) and A feed bus X; B goes straight to master.
        let (a, b, c) = (track(1), track(2), track(3));
        let x = RoutingNode::Bus(BusId::from(1));
        let routes = [
            RoutingConnection::new(c, x),
            RoutingConnection::new(a, x),
            RoutingConnection::new(x, RoutingNode::Master),
            RoutingConnection::new(b, RoutingNode::Master),
        ];
        let plan = plan_latency(
            &[a, b, c, x, RoutingNode::Master],
            &routes,
            latencies(&[(c, 50)]),
            |_| None,
        );
        // Every path reaches master 50 samples late: A and B wait for C, and X adds nothing.
        assert_eq!(
            plan,
            LatencyPlan {
                track_input_delays: HashMap::new(),
                edge_delays: [((a, x), 50), ((b, RoutingNode::Master), 50)]
                    .into_iter()
                    .collect(),
                system_latency: 50,
            }
        );
    }

    #[test]
    fn sidechain_aligns_with_the_input_of_the_keyed_effect() {
        // Track T runs 30 samples of latency before the keyed effect S; the key K has 20.
        let (key, keyed) = (track(1), track(2));
        let sidechain = SidechainRoute::TrackEffect(TrackId::from(2), EffectId::from(7));
        let routes = [
            RoutingConnection::new(key, RoutingNode::Master),
            RoutingConnection::new(keyed, RoutingNode::Master),
            RoutingConnection::new_send(key, RoutingNode::PluginSidechain(sidechain), 1.0),
        ];
        let plan = plan_latency(
            &[key, keyed, RoutingNode::Master],
            &routes,
            latencies(&[(key, 20), (keyed, 30)]),
            |route| (route == sidechain).then_some((keyed, 30)),
        );
        assert_eq!(
            plan.edge_delays,
            [
                ((key, RoutingNode::PluginSidechain(sidechain)), 10),
                ((key, RoutingNode::Master), 10),
            ]
            .into_iter()
            .collect()
        );
        assert!(plan.track_input_delays.is_empty());
        assert_eq!(plan.system_latency, 30);
    }

    #[test]
    fn late_sidechain_source_delays_the_keyed_track_instead() {
        let (key, keyed) = (track(1), track(2));
        let sidechain = SidechainRoute::TrackEffect(TrackId::from(2), EffectId::from(7));
        let routes = [
            RoutingConnection::new(key, RoutingNode::Master),
            RoutingConnection::new_send(key, RoutingNode::PluginSidechain(sidechain), 1.0),
        ];
        let plan = plan_latency(
            &[key, keyed, RoutingNode::Master],
            &routes,
            latencies(&[(key, 50)]),
            |route| (route == sidechain).then_some((keyed, 0)),
        );
        assert_eq!(
            plan.track_input_delays,
            [(TrackId::from(2), 50)].into_iter().collect()
        );
        assert!(plan.edge_delays.is_empty());
        assert_eq!(plan.system_latency, 50);
    }

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
