//! The routing graph compiled for parallel rendering.
//!
//! Every node owns its output: a track renders into its own buffer, a bus into its bus buffer,
//! and master into the block's output. A node pulls its inputs when it runs instead of being
//! pushed into by its sources: a bus sums its sources, a channel sums the keys of its
//! sidechained plugins, and master sums everything routed to it. Sources are summed in the
//! order the serial renderer pushed them (source order in the routing order, then route
//! order), so a parallel render is sample-identical to a serial one.
//!
//! Each block the coordinator gathers pointers to the state every node owns, then the worker
//! pool runs the levels. A node only touches what it owns while its level runs, and only reads
//! the outputs of earlier levels, which the level barriers order before it.

use std::{
    cell::UnsafeCell,
    panic::{AssertUnwindSafe, catch_unwind},
    time::Instant,
};

use crossbeam_utils::CachePadded;
use hashbrown::HashMap;
use karbeat_core::{
    core::project::{RoutingConnection, RoutingNode, RoutingTap, SidechainRoute},
    shared::{BusId, EffectId, TrackId},
};
use karbeat_plugin_api::types::{ParamChange, ProcessContext};

use crate::{
    dsp_engine::{LevelJob, schedule::LevelSchedule},
    engine::{
        helper::{
            apply_phase_inversion_simd, finish_planar_output, prepare_planar_input,
            process_plugin_planar, process_plugin_wrapper,
        },
        input::{InputSource, extract_source},
        kernels::{apply_fader, mix_gain},
        routing::DelayLine,
        runtime::consts::MAX_ENGINE_CHANNELS,
        types::{AudioMixerChannelValues, AudioMixerState},
        voices::{AudioVoice, GeneratorVoice, render_oneshot_voices},
    },
    event::PluginTarget,
    render_state::{AudioEffectInstance, AudioGeneratorInstance, AudioPluginState},
};

/// Stage of a node, which sets its lowest level.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(super) enum PlanNodeKind {
    /// Device input channels, level −1.
    Input(InputSource),
    Track(TrackId),
    Bus(BusId),
    Master,
}

impl PlanNodeKind {
    /// Lowest level of the stage, counted from the input level.
    fn floor(self) -> u32 {
        match self {
            Self::Input(_) => 0,
            Self::Track(_) => 1,
            Self::Bus(_) | Self::Master => 2,
        }
    }
}

#[derive(Clone, Copy, PartialEq, Eq)]
enum EdgeTarget {
    /// The node's own signal: a bus or master sum, or a track's monitored input.
    Main,
    /// One of the node's sidechain buffers, by index into the plan's sidechains.
    Sidechain(u32),
}

/// One connection, read by its destination.
#[derive(Clone, Copy)]
struct PlanEdge {
    source: u32,
    tap: RoutingTap,
    gain: f32,
    target: EdgeTarget,
    /// Key of the connection's compensation delay line.
    delay: Option<(RoutingNode, RoutingNode)>,
}

struct PlanNode {
    kind: PlanNodeKind,
    /// Incoming connections, in the order the serial renderer pushed them.
    edges: std::ops::Range<usize>,
    /// Sidechain buffers this node owns.
    sidechains: std::ops::Range<usize>,
    /// Whether any connection reads this node before its fader.
    pre_fader_tap: bool,
}

/// Raw pointer to state one node owns for one block.
pub(super) struct SendPtr<T>(*mut T);

impl<T> Clone for SendPtr<T> {
    fn clone(&self) -> Self {
        *self
    }
}

impl<T> Copy for SendPtr<T> {}

impl<T> SendPtr<T> {
    const NULL: Self = Self(std::ptr::null_mut());

    pub fn new(pointer: *mut T) -> Self {
        Self(pointer)
    }

    fn of(value: Option<&mut T>) -> Self {
        value.map_or(Self::NULL, |value| Self(value))
    }

    /// # Safety
    ///
    /// The pointee must be alive and, for the returned lifetime, accessed through no other
    /// reference: it belongs to the calling node's worker for the current block.
    unsafe fn get<'a>(self) -> Option<&'a mut T> {
        // SAFETY: The caller guarantees exclusive access to a live pointee.
        unsafe { self.0.as_mut() }
    }

    /// # Safety
    ///
    /// The pointee must be alive and not written for the returned lifetime.
    unsafe fn read<'a>(self) -> Option<&'a T> {
        // SAFETY: The caller guarantees the pointee is alive and not written.
        unsafe { self.0.as_ref() }
    }
}

// SAFETY: A `SendPtr` is dereferenced only by the worker the schedule assigns its node to,
// between the block's publication and its last barrier, or read-only by later levels after
// the barrier that ends the writer's level. `T: Send` lets that worker use the pointee.
unsafe impl<T: Send> Send for SendPtr<T> {}
// SAFETY: See `Send`.
unsafe impl<T: Send> Sync for SendPtr<T> {}

/// Pointers to the state one node owns in the current block. Null when the node has none.
#[derive(Clone, Copy)]
struct NodeRefs {
    channel: SendPtr<AudioMixerChannelValues>,
    effects: SendPtr<Vec<AudioEffectInstance>>,
    generator: SendPtr<AudioGeneratorInstance>,
    generator_voice: SendPtr<GeneratorVoice>,
    oneshots: SendPtr<AudioVoice>,
    oneshot_count: usize,
    input_delay: SendPtr<DelayLine>,
    tail: SendPtr<u32>,
    /// A bus's buffer.
    bus: SendPtr<Vec<f32>>,
}

impl NodeRefs {
    const EMPTY: Self = Self {
        channel: SendPtr::NULL,
        effects: SendPtr::NULL,
        generator: SendPtr::NULL,
        generator_voice: SendPtr::NULL,
        oneshots: SendPtr::NULL,
        oneshot_count: 0,
        input_delay: SendPtr::NULL,
        tail: SendPtr::NULL,
        bus: SendPtr::NULL,
    };
}

/// What a node produced in a block, written only by the node's worker.
struct NodeSlot {
    /// A track's or input's post-fader signal.
    post: Vec<f32>,
    /// The signal before the fader, kept when a connection taps it.
    pre: Vec<f32>,
    /// Whether the node reached its outputs this block.
    routed: bool,
    /// Time the node took this block.
    micros: f32,
}

struct NodeCell(CachePadded<UnsafeCell<NodeSlot>>);

// SAFETY: A slot is written only by the worker running its node, during the node's level, and
// read by others only after the barrier that ends that level.
unsafe impl Sync for NodeCell {}

/// Scratch one worker uses for every node it runs.
struct WorkerScratch {
    channels_in: Vec<Vec<f32>>,
    channels_out: Vec<Vec<f32>>,
    aux_channels: Vec<Vec<f32>>,
    /// Holds one delayed connection.
    edge: Vec<f32>,
}

struct ScratchCell(CachePadded<UnsafeCell<WorkerScratch>>);

// SAFETY: Each worker only touches the scratch at its own index.
unsafe impl Sync for ScratchCell {}

/// Read-only inputs of one render pass.
pub(super) struct BlockCtx<'a> {
    pub base: ProcessContext<'a>,
    pub param_changes: &'a HashMap<PluginTarget, Vec<ParamChange>>,
    pub channels: usize,
    pub sample_rate: u32,
    pub bpm: f32,
    pub is_any_solo: bool,
    pub max_effect_tail: u32,
    pub bypass_master: bool,
    /// Every device input channel of this pass, interleaved, and their count.
    pub input: &'a [f32],
    pub input_channels: usize,
}

impl<'a> BlockCtx<'a> {
    fn changes(&self, target: &PluginTarget) -> &'a [ParamChange] {
        self.param_changes
            .get(target)
            .map(Vec::as_slice)
            .unwrap_or(&[])
    }
}

/// State the plan gathers node pointers from.
pub(super) struct GatherSources<'a> {
    pub mixer: &'a mut AudioMixerState,
    pub plugins: &'a mut AudioPluginState,
    pub generators: &'a mut [GeneratorVoice],
    pub oneshots: &'a mut [AudioVoice],
    pub track_tails: &'a mut HashMap<TrackId, u32>,
    pub bus_tails: &'a mut HashMap<BusId, u32>,
    pub master_tail: &'a mut u32,
    pub track_input_delays: &'a mut HashMap<TrackId, DelayLine>,
    pub edge_delays: &'a mut HashMap<(RoutingNode, RoutingNode), DelayLine>,
    pub bus_buffers: &'a mut HashMap<BusId, Vec<f32>>,
    pub sidechain_buffers: &'a mut HashMap<SidechainRoute, Vec<f32>>,
}

/// What the plan is built from.
pub(super) struct PlanGraph<'a> {
    pub order: &'a [RoutingNode],
    pub outgoing: &'a HashMap<RoutingNode, Vec<RoutingConnection>>,
    /// Channel owning each sidechain buffer.
    pub sidechains: &'a [(SidechainRoute, RoutingNode)],
    /// Tracks hearing an input, in track order.
    pub monitored: &'a [(TrackId, InputSource)],
    pub workers: usize,
    /// Interleaved samples a node buffer holds without growing.
    pub block_samples: usize,
    pub channels: usize,
}

pub(super) struct RenderPlan {
    nodes: Vec<PlanNode>,
    edges: Vec<PlanEdge>,
    sidechains: Vec<SidechainRoute>,
    schedule: LevelSchedule,
    refs: Vec<NodeRefs>,
    edge_delays: Vec<SendPtr<DelayLine>>,
    sidechain_buffers: Vec<SendPtr<Vec<f32>>>,
    slots: Box<[NodeCell]>,
    scratch: Box<[ScratchCell]>,
    /// Whether the graph changed since the plan was built.
    stale: bool,
    blocks_since_rebalance: u32,
}

impl Default for RenderPlan {
    fn default() -> Self {
        Self {
            nodes: Vec::new(),
            edges: Vec::new(),
            sidechains: Vec::new(),
            schedule: LevelSchedule::new(Vec::new(), Vec::new(), 1),
            refs: Vec::new(),
            edge_delays: Vec::new(),
            sidechain_buffers: Vec::new(),
            slots: Box::new([]),
            scratch: Box::new([]),
            stale: true,
            blocks_since_rebalance: 0,
        }
    }
}

impl RenderPlan {
    /// Compiles the routing graph. `seed_cost` estimates a node's cost before it is measured.
    /// Allocates; runs when the graph changes, never per block.
    pub fn build(graph: &PlanGraph<'_>, seed_cost: impl Fn(PlanNodeKind) -> f32) -> Self {
        let kinds: Vec<PlanNodeKind> = graph
            .monitored
            .iter()
            .map(|(_, source)| PlanNodeKind::Input(*source))
            .fold(Vec::new(), |mut inputs, input| {
                if !inputs.contains(&input) {
                    inputs.push(input);
                }
                inputs
            })
            .into_iter()
            .chain(graph.order.iter().filter_map(|node| match *node {
                RoutingNode::Track(id) => Some(PlanNodeKind::Track(id)),
                RoutingNode::Bus(id) => Some(PlanNodeKind::Bus(id)),
                RoutingNode::Master => Some(PlanNodeKind::Master),
                RoutingNode::PluginSidechain(_) => None,
            }))
            .collect();
        let index_of = |kind: PlanNodeKind| kinds.iter().position(|other| *other == kind);
        let routing_index = |node: RoutingNode| match node {
            RoutingNode::Track(id) => index_of(PlanNodeKind::Track(id)),
            RoutingNode::Bus(id) => index_of(PlanNodeKind::Bus(id)),
            RoutingNode::Master => index_of(PlanNodeKind::Master),
            RoutingNode::PluginSidechain(_) => None,
        };

        // Sidechain buffers, grouped by the channel that owns them.
        let mut owned: Vec<(usize, SidechainRoute)> = graph
            .sidechains
            .iter()
            .filter_map(|(route, owner)| Some((routing_index(*owner)?, *route)))
            .collect();
        owned.sort_by_key(|(owner, _)| *owner);
        let sidechains: Vec<SidechainRoute> = owned.iter().map(|(_, route)| *route).collect();
        let sidechain_of = |route: SidechainRoute| {
            sidechains
                .iter()
                .position(|other| *other == route)
                .map(|index| (owned[index].0, index as u32))
        };

        // Incoming connections in push order: sources in plan order, then route order. A
        // connection to a node that runs before its source was lost by the serial renderer,
        // so it is dropped here too.
        let mut incoming: Vec<(usize, PlanEdge)> = Vec::new();
        let mut pre_fader_tap = vec![false; kinds.len()];
        for (track, source) in graph.monitored {
            if let (Some(input), Some(track)) = (
                index_of(PlanNodeKind::Input(*source)),
                index_of(PlanNodeKind::Track(*track)),
            ) {
                incoming.push((
                    track,
                    PlanEdge {
                        source: input as u32,
                        tap: RoutingTap::PostFader,
                        gain: 1.0,
                        target: EdgeTarget::Main,
                        delay: None,
                    },
                ));
            }
        }
        for (source_index, kind) in kinds.iter().enumerate() {
            let source = match *kind {
                PlanNodeKind::Track(id) => RoutingNode::Track(id),
                PlanNodeKind::Bus(id) => RoutingNode::Bus(id),
                PlanNodeKind::Master => RoutingNode::Master,
                PlanNodeKind::Input(_) => continue,
            };
            for route in graph.outgoing.get(&source).map_or(&[][..], Vec::as_slice) {
                let destination = match route.destination {
                    RoutingNode::PluginSidechain(sidechain) => sidechain_of(sidechain)
                        .map(|(owner, index)| (owner, EdgeTarget::Sidechain(index))),
                    RoutingNode::Bus(_) | RoutingNode::Master => {
                        routing_index(route.destination).map(|owner| (owner, EdgeTarget::Main))
                    }
                    RoutingNode::Track(_) => None,
                };
                let Some((destination, target)) = destination else {
                    continue;
                };
                if destination <= source_index {
                    continue;
                }
                if route.tap == RoutingTap::PreFader {
                    pre_fader_tap[source_index] = true;
                }
                incoming.push((
                    destination,
                    PlanEdge {
                        source: source_index as u32,
                        tap: route.tap,
                        gain: route.send_level,
                        target,
                        delay: Some((route.source, route.destination)),
                    },
                ));
            }
        }
        // Stable, so each destination keeps its push order.
        incoming.sort_by_key(|(destination, _)| *destination);

        let mut nodes = Vec::with_capacity(kinds.len());
        let mut levels = Vec::with_capacity(kinds.len());
        let (mut edge_at, mut sidechain_at) = (0, 0);
        for (index, kind) in kinds.iter().enumerate() {
            let edge_end = edge_at
                + incoming[edge_at..]
                    .iter()
                    .take_while(|(destination, _)| *destination == index)
                    .count();
            let sidechain_end = sidechain_at
                + owned[sidechain_at..]
                    .iter()
                    .take_while(|(owner, _)| *owner == index)
                    .count();
            let level = incoming[edge_at..edge_end]
                .iter()
                .map(|(_, edge)| levels[edge.source as usize] + 1)
                .fold(kind.floor(), u32::max);
            levels.push(level);
            nodes.push(PlanNode {
                kind: *kind,
                edges: edge_at..edge_end,
                sidechains: sidechain_at..sidechain_end,
                pre_fader_tap: pre_fader_tap[index],
            });
            edge_at = edge_end;
            sidechain_at = sidechain_end;
        }
        // Master always runs last, alone.
        let deepest = nodes
            .iter()
            .zip(&levels)
            .filter(|(node, _)| node.kind != PlanNodeKind::Master)
            .map(|(_, level)| *level)
            .max()
            .unwrap_or(0);
        for (node, level) in nodes.iter().zip(levels.iter_mut()) {
            if node.kind == PlanNodeKind::Master {
                *level = (*level).max(deepest + 1);
            }
        }
        // Levels nobody uses, like the input level without inputs, cost a barrier each.
        let mut used: Vec<u32> = levels.clone();
        used.sort_unstable();
        used.dedup();
        for level in &mut levels {
            *level = used.iter().position(|used| used == level).unwrap_or(0) as u32;
        }

        let edges: Vec<PlanEdge> = incoming.into_iter().map(|(_, edge)| edge).collect();
        let seeds = kinds.iter().map(|kind| seed_cost(*kind)).collect();
        let workers = graph.workers.max(1);
        let plugin_frames = (graph.block_samples / graph.channels.max(1)).max(4_096);
        let plugin_channels = graph.channels.min(MAX_ENGINE_CHANNELS as usize);
        let planar = || -> Vec<Vec<f32>> {
            (0..plugin_channels)
                .map(|_| vec![0.0; plugin_frames])
                .collect()
        };
        Self {
            refs: vec![NodeRefs::EMPTY; nodes.len()],
            edge_delays: vec![SendPtr::NULL; edges.len()],
            sidechain_buffers: vec![SendPtr::NULL; sidechains.len()],
            slots: nodes
                .iter()
                .map(|node| {
                    let owns_post =
                        matches!(node.kind, PlanNodeKind::Track(_) | PlanNodeKind::Input(_));
                    NodeCell(CachePadded::new(UnsafeCell::new(NodeSlot {
                        post: Vec::with_capacity(if owns_post { graph.block_samples } else { 0 }),
                        pre: Vec::with_capacity(if node.pre_fader_tap {
                            graph.block_samples
                        } else {
                            0
                        }),
                        routed: false,
                        micros: 0.0,
                    })))
                })
                .collect(),
            scratch: (0..workers)
                .map(|_| {
                    ScratchCell(CachePadded::new(UnsafeCell::new(WorkerScratch {
                        channels_in: planar(),
                        channels_out: planar(),
                        aux_channels: planar(),
                        edge: Vec::with_capacity(graph.block_samples),
                    })))
                })
                .collect(),
            schedule: LevelSchedule::new(levels, seeds, workers),
            nodes,
            edges,
            sidechains,
            stale: false,
            blocks_since_rebalance: 0,
        }
    }

    pub fn is_stale(&self) -> bool {
        self.stale
    }

    pub fn mark_stale(&mut self) {
        self.stale = true;
    }

    /// Workers the plan was built for.
    pub fn workers(&self) -> usize {
        self.scratch.len()
    }

    /// Tracks in the order they render, for claiming shared state in serial order.
    pub fn tracks(&self) -> impl Iterator<Item = TrackId> + '_ {
        self.nodes.iter().filter_map(|node| match node.kind {
            PlanNodeKind::Track(id) => Some(id),
            _ => None,
        })
    }

    /// Points every node at the state it owns this block. Audio voices must be grouped by
    /// track. Real-time safe: lookups, plus the mixer channels and tail counters created on
    /// first use, as the serial renderer did.
    pub fn gather(&mut self, sources: GatherSources<'_>) {
        let GatherSources {
            mixer,
            plugins,
            generators,
            oneshots,
            track_tails,
            bus_tails,
            master_tail,
            track_input_delays,
            edge_delays,
            bus_buffers,
            sidechain_buffers,
        } = sources;
        // Entries the serial renderer created on first use are created first: an insertion
        // can move a map's values, which would leave pointers gathered before it dangling.
        for node in &self.nodes {
            match node.kind {
                PlanNodeKind::Track(id) => {
                    mixer.track_channels.entry(id).or_default();
                    track_tails.entry(id).or_insert(0);
                }
                PlanNodeKind::Bus(id) if bus_buffers.contains_key(&id) => {
                    mixer.bus_channels.entry(id).or_default();
                    bus_tails.entry(id).or_insert(0);
                }
                _ => {}
            }
        }
        let generator_base = generators.as_mut_ptr();
        let oneshot_base = oneshots.as_mut_ptr();
        for (node, refs) in self.nodes.iter().zip(self.refs.iter_mut()) {
            *refs = NodeRefs::EMPTY;
            match node.kind {
                PlanNodeKind::Input(_) => {}
                PlanNodeKind::Track(id) => {
                    refs.channel = SendPtr::of(mixer.track_channels.get_mut(&id));
                    refs.effects = SendPtr::of(plugins.track_effects.get_mut(id.to_u32() as usize));
                    if let Some(index) = generators
                        .iter()
                        .position(|voice| voice.track_id == id && voice.active)
                    {
                        let generator_id = generators[index].id;
                        // SAFETY: `index` is in bounds of `generators`, whose base pointer
                        // stays valid for the block; each track takes a different voice.
                        refs.generator_voice = SendPtr(unsafe { generator_base.add(index) });
                        refs.generator = SendPtr::of(plugins.get_generator_mut(generator_id));
                    }
                    let range = voice_range(oneshots, id);
                    if range.end <= oneshots.len() && !range.is_empty() {
                        // SAFETY: `range` is in bounds; tracks own disjoint voice ranges.
                        refs.oneshots = SendPtr(unsafe { oneshot_base.add(range.start) });
                        refs.oneshot_count = range.len();
                    }
                    refs.input_delay = SendPtr::of(track_input_delays.get_mut(&id));
                    refs.tail = SendPtr::of(track_tails.get_mut(&id));
                }
                PlanNodeKind::Bus(id) => {
                    refs.bus = SendPtr::of(bus_buffers.get_mut(&id));
                    if !refs.bus.0.is_null() {
                        refs.channel = SendPtr::of(mixer.bus_channels.get_mut(&id));
                        refs.effects =
                            SendPtr::of(plugins.bus_effects.get_mut(id.to_u32() as usize));
                        refs.tail = SendPtr::of(bus_tails.get_mut(&id));
                    }
                }
                PlanNodeKind::Master => {
                    refs.channel = SendPtr::of(Some(&mut mixer.master));
                    refs.effects = SendPtr::of(Some(&mut plugins.master_effects));
                    refs.tail = SendPtr::of(Some(&mut *master_tail));
                }
            }
        }
        for (edge, delay) in self.edges.iter().zip(self.edge_delays.iter_mut()) {
            *delay = SendPtr::of(edge.delay.and_then(|key| edge_delays.get_mut(&key)));
        }
        for (route, buffer) in self
            .sidechains
            .iter()
            .zip(self.sidechain_buffers.iter_mut())
        {
            *buffer = SendPtr::of(sidechain_buffers.get_mut(route));
        }
    }

    /// Folds this block's node timings into the schedule, and rebalances it about once every
    /// `rebalance_every` blocks.
    pub fn finish_block(&mut self, rebalance_every: u32) {
        for (node, cell) in self.slots.iter_mut().enumerate() {
            let micros = cell.0.get_mut().micros;
            self.schedule.observe(node, micros);
        }
        self.blocks_since_rebalance += 1;
        if self.blocks_since_rebalance >= rebalance_every {
            self.blocks_since_rebalance = 0;
            self.schedule.rebalance();
        }
    }
}

/// Range of `voices` playing on `track_id`, once voices are grouped by track.
pub(super) fn voice_range(voices: &[AudioVoice], track_id: TrackId) -> std::ops::Range<usize> {
    let Some(start) = voices.iter().position(|voice| voice.track_id == track_id) else {
        return 0..0;
    };
    let len = voices[start..]
        .iter()
        .take_while(|voice| voice.track_id == track_id)
        .count();
    start..start + len
}

/// Puts each track's audio voices next to each other, keeping their order within a track.
/// Voices are queued track by track, so this rarely moves anything. Never allocates.
pub(super) fn group_voices_by_track(voices: &mut [AudioVoice]) {
    let grouped = |voices: &[AudioVoice]| {
        voices.iter().enumerate().all(|(index, voice)| {
            index == 0
                || voices[index - 1].track_id == voice.track_id
                || !voices[..index - 1]
                    .iter()
                    .any(|earlier| earlier.track_id == voice.track_id)
        })
    };
    if grouped(voices) {
        return;
    }
    // Stable insertion sort by the first position of each track.
    for index in 1..voices.len() {
        let mut at = index;
        while at > 0 {
            let track = voices[at].track_id;
            let first = voices[..at]
                .iter()
                .position(|voice| voice.track_id == track);
            match first {
                Some(first) if first < at - 1 && voices[at - 1].track_id != track => {
                    voices.swap(at - 1, at);
                    at -= 1;
                }
                _ => break,
            }
        }
    }
}

/// One render pass of the plan, run level by level on the worker pool.
pub(super) struct RenderJob<'a> {
    pub plan: &'a RenderPlan,
    pub ctx: &'a BlockCtx<'a>,
    /// The pass's interleaved output, which only master writes.
    pub output: SendPtr<f32>,
    pub output_len: usize,
}

impl LevelJob for RenderJob<'_> {
    fn levels(&self) -> usize {
        self.plan.schedule.levels()
    }

    fn run(&self, worker: usize, level: usize) {
        for &node in self.plan.schedule.nodes(level, worker) {
            self.render(node as usize, worker);
        }
    }
}

impl RenderJob<'_> {
    fn render(&self, index: usize, worker: usize) {
        let plan = self.plan;
        let (Some(node), Some(refs), Some(cell), Some(scratch)) = (
            plan.nodes.get(index),
            plan.refs.get(index),
            plan.slots.get(index),
            plan.scratch.get(worker),
        ) else {
            return;
        };
        // SAFETY: The schedule runs this node on exactly one worker this block.
        let slot = unsafe { &mut *cell.0.get() };
        // SAFETY: Only this worker uses the scratch at its index.
        let scratch = unsafe { &mut *scratch.0.get() };
        slot.routed = false;
        let started = Instant::now();
        // A panicking plugin silences its node instead of stalling the pool.
        let rendered = catch_unwind(AssertUnwindSafe(|| match node.kind {
            PlanNodeKind::Input(source) => self.render_input(source, slot),
            PlanNodeKind::Track(id) => self.render_track(node, *refs, id, slot, scratch),
            PlanNodeKind::Bus(id) => self.render_bus(node, *refs, id, slot, scratch),
            PlanNodeKind::Master => self.render_master(node, *refs, slot, scratch),
        }));
        if rendered.is_err() {
            slot.routed = false;
        }
        slot.micros = started.elapsed().as_secs_f32() * 1.0e6;
    }

    /// Signal a source routed this block, at `tap`.
    fn source_signal(&self, source: u32, tap: RoutingTap) -> Option<&[f32]> {
        let index = source as usize;
        // SAFETY: The source ran at an earlier level; the barrier that ended it orders its
        // writes before this read, and nothing writes it again this block.
        let slot = unsafe { &*self.plan.slots.get(index)?.0.get() };
        if !slot.routed {
            return None;
        }
        if tap == RoutingTap::PreFader {
            return Some(&slot.pre);
        }
        match self.plan.nodes.get(index)?.kind {
            PlanNodeKind::Bus(_) => {
                // SAFETY: As above; the bus buffer is the bus node's output.
                unsafe { self.plan.refs.get(index)?.bus.read() }.map(Vec::as_slice)
            }
            _ => Some(&slot.post),
        }
    }

    /// Mixes the node's incoming connections aimed at `target` into `into`. Returns whether any
    /// source was routed.
    fn pull(
        &self,
        node: &PlanNode,
        target: EdgeTarget,
        into: &mut [f32],
        scratch: &mut WorkerScratch,
    ) -> bool {
        let mut any = false;
        for index in node.edges.clone() {
            let (Some(edge), Some(delay)) =
                (self.plan.edges.get(index), self.plan.edge_delays.get(index))
            else {
                continue;
            };
            if edge.target != target {
                continue;
            }
            let Some(signal) = self.source_signal(edge.source, edge.tap) else {
                continue;
            };
            // SAFETY: A connection's delay line belongs to its destination, this node.
            let signal = match unsafe { delay.get() } {
                Some(delay) => {
                    scratch.edge.resize(signal.len(), 0.0);
                    scratch.edge.copy_from_slice(signal);
                    delay.process_block(&mut scratch.edge, self.ctx.channels);
                    &scratch.edge[..]
                }
                None => signal,
            };
            mix_gain(into, signal, edge.gain);
            any = true;
        }
        any
    }

    /// Clears and sums the node's sidechain buffers.
    fn pull_sidechains(&self, node: &PlanNode, len: usize, scratch: &mut WorkerScratch) {
        for index in node.sidechains.clone() {
            // SAFETY: A sidechain buffer belongs to the channel owning its plugin, this node.
            let Some(buffer) = self
                .plan
                .sidechain_buffers
                .get(index)
                .and_then(|buffer| unsafe { buffer.get() })
            else {
                continue;
            };
            buffer.resize(len, 0.0);
            buffer.fill(0.0);
            self.pull(node, EdgeTarget::Sidechain(index as u32), buffer, scratch);
        }
    }

    /// The node's buffer for sidechain `route`, when it has one.
    fn sidechain(&self, node: &PlanNode, route: SidechainRoute) -> Option<&[f32]> {
        let index = node
            .sidechains
            .clone()
            .find(|&index| self.plan.sidechains.get(index) == Some(&route))?;
        // SAFETY: The buffer belongs to this node and was filled by `pull_sidechains`.
        unsafe { self.plan.sidechain_buffers.get(index)?.read() }.map(Vec::as_slice)
    }

    /// Whether any routed source feeds sidechain `route` of the node.
    fn sidechain_has_signal(&self, node: &PlanNode, route: SidechainRoute) -> bool {
        let Some(index) = node
            .sidechains
            .clone()
            .find(|&index| self.plan.sidechains.get(index) == Some(&route))
        else {
            return false;
        };
        node.edges.clone().any(|edge| {
            self.plan.edges.get(edge).is_some_and(|edge| {
                edge.target == EdgeTarget::Sidechain(index as u32)
                    && self.source_signal(edge.source, edge.tap).is_some()
            })
        })
    }

    fn render_input(&self, source: InputSource, slot: &mut NodeSlot) {
        let ctx = self.ctx;
        if ctx.input.is_empty() || ctx.input_channels == 0 {
            return;
        }
        let frames = ctx.input.len() / ctx.input_channels;
        slot.post.resize(frames * 2, 0.0);
        extract_source(ctx.input, ctx.input_channels, source, &mut slot.post);
        slot.routed = true;
    }

    /// Runs an effect chain over `buffer`, zeroing it when a plugin cannot process.
    fn run_chain(
        &self,
        node: &PlanNode,
        effects: &mut [AudioEffectInstance],
        buffer: &mut [f32],
        target: impl Fn(EffectId) -> (PluginTarget, SidechainRoute),
        scratch: &mut WorkerScratch,
    ) {
        let ctx = self.ctx;
        let channels = ctx.channels;
        let frames = if effects.is_empty() {
            None
        } else {
            prepare_planar_input(
                buffer,
                channels,
                &mut scratch.channels_in,
                &scratch.channels_out,
            )
        };
        for effect in effects.iter_mut() {
            if effect.bypass {
                continue;
            }
            let (plugin, sidechain) = target(effect.id);
            let aux = self.sidechain(node, sidechain);
            let mut process_ctx = ctx.base.clone();
            process_ctx.param_changes = ctx.changes(&plugin);
            let Some(frames) = frames else {
                buffer.fill(0.0);
                return;
            };
            if !process_plugin_planar(
                &mut *effect.plugin,
                aux,
                channels,
                frames,
                &process_ctx,
                &mut scratch.channels_in,
                &mut scratch.channels_out,
                &mut scratch.aux_channels,
            ) {
                buffer.fill(0.0);
                return;
            }
        }
        if let Some(frames) = frames {
            finish_planar_output(buffer, &scratch.channels_in, channels, frames);
        }
    }

    /// Advances a channel's effect tail. Returns whether the channel keeps rendering.
    fn ring_tail(
        has_signal: bool,
        tail: &mut u32,
        effects: Option<&mut Vec<AudioEffectInstance>>,
        chain_tail: u32,
        len: usize,
    ) -> bool {
        if has_signal {
            *tail = chain_tail;
            return true;
        }
        if *tail == 0 {
            return false;
        }
        *tail = tail.saturating_sub(len as u32);
        if *tail == 0 {
            if let Some(effects) = effects {
                effects.iter_mut().for_each(|effect| effect.plugin.reset());
            }
            return false;
        }
        true
    }

    fn chain_tail(&self, effects: Option<&Vec<AudioEffectInstance>>) -> u32 {
        effects
            .and_then(|effects| {
                effects
                    .iter()
                    .map(|effect| effect.plugin.tail_samples().min(self.ctx.max_effect_tail))
                    .max()
            })
            .unwrap_or(0)
    }

    /// Copies the pre-fader signal when a connection taps it, applies the fader, and marks
    /// the node routed.
    fn fader(
        node: &PlanNode,
        channel: &mut AudioMixerChannelValues,
        buffer: &mut [f32],
        pre: &mut Vec<f32>,
        channels: usize,
    ) {
        if node.pre_fader_tap {
            pre.clear();
            pre.extend_from_slice(buffer);
        }
        let peak = apply_fader(buffer, channels, &mut channel.volume, &mut channel.pan);
        channel.observe_peak(peak);
    }

    fn render_track(
        &self,
        node: &PlanNode,
        refs: NodeRefs,
        track_id: TrackId,
        slot: &mut NodeSlot,
        scratch: &mut WorkerScratch,
    ) {
        let ctx = self.ctx;
        let channels = ctx.channels;
        // SAFETY: Everything in `refs` belongs to this track for the block.
        let channel = unsafe { refs.channel.get() };
        // SAFETY: As above.
        let mut effects = unsafe { refs.effects.get() };
        // SAFETY: As above.
        let generator = unsafe { refs.generator.get() };
        // SAFETY: As above.
        let generator_voice = unsafe { refs.generator_voice.get() };
        // SAFETY: As above.
        let tail = unsafe { refs.tail.get() };
        let (Some(channel), Some(tail)) = (channel, tail) else {
            return;
        };
        channel.prepare_smoothing(ctx.sample_rate);
        if channel.mute || (ctx.is_any_solo && !channel.solo) {
            return;
        }
        let len = self.output_len;
        slot.post.resize(len, 0.0);
        slot.post.fill(0.0);
        self.pull_sidechains(node, len, scratch);

        let mut has_signal = false;
        if let (Some(voice), Some(generator)) = (generator_voice, generator) {
            let aux = self.sidechain(node, SidechainRoute::Generator(voice.id));
            let mut generator_ctx = ctx.base.clone();
            generator_ctx.midi_events = &voice.midi_events;
            generator_ctx.param_changes = ctx.changes(&PluginTarget::Generator(voice.id));
            process_plugin_wrapper(
                &mut *generator.plugin,
                &mut slot.post,
                aux,
                channels,
                &generator_ctx,
                &mut scratch.channels_in,
                &mut scratch.channels_out,
                &mut scratch.aux_channels,
            );
            voice.delivered = true;
            has_signal = true;
        }

        if refs.oneshot_count > 0 {
            // SAFETY: The track's audio voices are a range only this track renders.
            let voices =
                unsafe { std::slice::from_raw_parts_mut(refs.oneshots.0, refs.oneshot_count) };
            has_signal |=
                render_oneshot_voices(voices, ctx.sample_rate, &mut slot.post, channels, ctx.bpm);
        }
        has_signal |= self.pull(node, EdgeTarget::Main, &mut slot.post, scratch);

        // A silent channel still runs its effects while a sidechain feeds them, so gates and
        // duckers keep reacting to their key signal, and while a hosted plugin needs its
        // process callback.
        if !has_signal
            && effects.as_deref().is_some_and(|effects| {
                effects.iter().any(|effect| {
                    effect.keeps_processing()
                        || self.sidechain_has_signal(
                            node,
                            SidechainRoute::TrackEffect(track_id, effect.id),
                        )
                })
            })
        {
            has_signal = true;
        }
        let chain_tail = self.chain_tail(effects.as_deref());
        if !Self::ring_tail(has_signal, tail, effects.as_deref_mut(), chain_tail, len) {
            return;
        }

        // Align the track with any later-arriving sidechain source before its effects.
        // SAFETY: The track's input delay line belongs to it.
        if let Some(delay_line) = unsafe { refs.input_delay.get() } {
            delay_line.process_block(&mut slot.post, channels);
        }
        if channel.inverted_phase {
            apply_phase_inversion_simd(&mut slot.post);
        }
        if let Some(effects) = effects {
            self.run_chain(
                node,
                effects,
                &mut slot.post,
                |effect| {
                    (
                        PluginTarget::TrackEffect(track_id, effect),
                        SidechainRoute::TrackEffect(track_id, effect),
                    )
                },
                scratch,
            );
        }
        Self::fader(node, channel, &mut slot.post, &mut slot.pre, channels);
        slot.routed = true;
    }

    fn render_bus(
        &self,
        node: &PlanNode,
        refs: NodeRefs,
        bus_id: BusId,
        slot: &mut NodeSlot,
        scratch: &mut WorkerScratch,
    ) {
        let ctx = self.ctx;
        // SAFETY: Everything in `refs` belongs to this bus for the block.
        let channel = unsafe { refs.channel.get() };
        // SAFETY: As above.
        let mut effects = unsafe { refs.effects.get() };
        // SAFETY: As above.
        let tail = unsafe { refs.tail.get() };
        // SAFETY: As above.
        let buffer = unsafe { refs.bus.get() };
        let (Some(channel), Some(tail), Some(buffer)) = (channel, tail, buffer) else {
            return;
        };
        channel.prepare_smoothing(ctx.sample_rate);
        if channel.mute {
            return;
        }
        let len = self.output_len;
        buffer.resize(len, 0.0);
        buffer.fill(0.0);
        let mut has_signal = self.pull(node, EdgeTarget::Main, buffer, scratch);
        self.pull_sidechains(node, len, scratch);

        // Sidechain input counts as signal so keyed effects keep processing, and so does a
        // hosted plugin that needs its process callback.
        has_signal = has_signal
            || effects.as_deref().is_some_and(|effects| {
                effects.iter().any(|effect| {
                    effect.keeps_processing()
                        || self.sidechain_has_signal(
                            node,
                            SidechainRoute::BusEffect(bus_id, effect.id),
                        )
                })
            });
        let chain_tail = self.chain_tail(effects.as_deref());
        if !Self::ring_tail(has_signal, tail, effects.as_deref_mut(), chain_tail, len) {
            return;
        }

        if let Some(effects) = effects {
            self.run_chain(
                node,
                effects,
                buffer,
                |effect| {
                    (
                        PluginTarget::BusEffect(bus_id, effect),
                        SidechainRoute::BusEffect(bus_id, effect),
                    )
                },
                scratch,
            );
        }
        Self::fader(node, channel, buffer, &mut slot.pre, ctx.channels);
        slot.routed = true;
    }

    fn render_master(
        &self,
        node: &PlanNode,
        refs: NodeRefs,
        slot: &mut NodeSlot,
        scratch: &mut WorkerScratch,
    ) {
        let ctx = self.ctx;
        if self.output.0.is_null() {
            return;
        }
        // SAFETY: Master is the only node writing the pass's output.
        let output = unsafe { std::slice::from_raw_parts_mut(self.output.0, self.output_len) };
        let mut has_signal = self.pull(node, EdgeTarget::Main, output, scratch);
        self.pull_sidechains(node, self.output_len, scratch);
        // A bounce plays back through one more channel than the audio it replaces, whose
        // centre pan passes 1/sqrt(2) per side, so it is rendered that much louder.
        if ctx.bypass_master {
            output
                .iter_mut()
                .for_each(|sample| *sample *= std::f32::consts::SQRT_2);
            slot.routed = true;
            return;
        }
        // SAFETY: Everything in `refs` belongs to master for the block.
        let channel = unsafe { refs.channel.get() };
        // SAFETY: As above.
        let effects = unsafe { refs.effects.get() };
        // SAFETY: As above.
        let tail = unsafe { refs.tail.get() };
        let (Some(channel), Some(effects), Some(tail)) = (channel, effects, tail) else {
            return;
        };
        has_signal = has_signal
            || effects.iter().any(|effect| {
                effect.keeps_processing()
                    || self.sidechain_has_signal(node, SidechainRoute::MasterEffect(effect.id))
            });
        let chain_tail = self.chain_tail(Some(&*effects));
        if has_signal {
            *tail = chain_tail;
        } else if *tail > 0 {
            *tail = tail.saturating_sub(self.output_len as u32);
            // Once the tail runs out, master has finally gone silent.
            if *tail == 0 {
                effects.iter_mut().for_each(|effect| effect.plugin.reset());
            }
        }
        if !has_signal && *tail == 0 {
            output.fill(0.0);
            return;
        }
        channel.prepare_smoothing(ctx.sample_rate);
        if channel.inverted_phase {
            apply_phase_inversion_simd(output);
        }
        self.run_chain(
            node,
            effects,
            output,
            |effect| {
                (
                    PluginTarget::MasterEffect(effect),
                    SidechainRoute::MasterEffect(effect),
                )
            },
            scratch,
        );
        let peak = apply_fader(output, ctx.channels, &mut channel.volume, &mut channel.pan);
        channel.observe_peak(peak);
        slot.routed = true;
    }
}

#[cfg(test)]
mod tests {
    use super::{PlanGraph, PlanNodeKind, RenderPlan};
    use crate::engine::input::InputSource;
    use hashbrown::HashMap;
    use karbeat_core::{
        core::project::{RoutingConnection, RoutingNode, SidechainRoute},
        shared::{BusId, EffectId, TrackId},
    };

    fn track(id: u32) -> RoutingNode {
        RoutingNode::Track(TrackId::from(id))
    }

    fn plan(
        order: &[RoutingNode],
        routes: &[RoutingConnection],
        sidechains: &[(SidechainRoute, RoutingNode)],
        monitored: &[(TrackId, InputSource)],
    ) -> RenderPlan {
        let mut outgoing: HashMap<RoutingNode, Vec<RoutingConnection>> = HashMap::new();
        for route in routes {
            outgoing
                .entry(route.source)
                .or_default()
                .push(route.clone());
        }
        RenderPlan::build(
            &PlanGraph {
                order,
                outgoing: &outgoing,
                sidechains,
                monitored,
                workers: 2,
                block_samples: 128,
                channels: 2,
            },
            |_| 1.0,
        )
    }

    /// Level of every node, by kind.
    fn levels(plan: &RenderPlan) -> Vec<(PlanNodeKind, usize)> {
        let mut levels = Vec::new();
        for level in 0..plan.schedule.levels() {
            for worker in 0..plan.schedule.workers() {
                for &node in plan.schedule.nodes(level, worker) {
                    levels.push((plan.nodes[node as usize].kind, level));
                }
            }
        }
        levels.sort_by_key(|(kind, _)| format!("{kind:?}"));
        levels
    }

    fn level_of(plan: &RenderPlan, kind: PlanNodeKind) -> usize {
        levels(plan)
            .into_iter()
            .find(|(other, _)| *other == kind)
            .map(|(_, level)| level)
            .unwrap_or(usize::MAX)
    }

    #[test]
    fn tracks_buses_and_master_take_successive_levels() {
        let (a, b) = (track(1), track(2));
        let (x, y) = (
            RoutingNode::Bus(BusId::from(1)),
            RoutingNode::Bus(BusId::from(2)),
        );
        let plan = plan(
            &[a, b, x, y, RoutingNode::Master],
            &[
                RoutingConnection::new(a, x),
                RoutingConnection::new(b, y),
                RoutingConnection::new(x, y),
                RoutingConnection::new(y, RoutingNode::Master),
            ],
            &[],
            &[],
        );
        assert_eq!(plan.schedule.levels(), 4);
        assert_eq!(level_of(&plan, PlanNodeKind::Track(TrackId::from(1))), 0);
        assert_eq!(level_of(&plan, PlanNodeKind::Track(TrackId::from(2))), 0);
        assert_eq!(level_of(&plan, PlanNodeKind::Bus(BusId::from(1))), 1);
        assert_eq!(level_of(&plan, PlanNodeKind::Bus(BusId::from(2))), 2);
        assert_eq!(level_of(&plan, PlanNodeKind::Master), 3);
    }

    #[test]
    fn a_track_keyed_by_another_track_runs_a_level_later() {
        let (key, keyed) = (track(1), track(2));
        let route = SidechainRoute::TrackEffect(TrackId::from(2), EffectId::from(7));
        let plan = plan(
            &[key, keyed, RoutingNode::Master],
            &[
                RoutingConnection::new(key, RoutingNode::Master),
                RoutingConnection::new(keyed, RoutingNode::Master),
                RoutingConnection::new_send(key, RoutingNode::PluginSidechain(route), 1.0),
            ],
            &[(route, keyed)],
            &[],
        );
        assert_eq!(level_of(&plan, PlanNodeKind::Track(TrackId::from(1))), 0);
        assert_eq!(level_of(&plan, PlanNodeKind::Track(TrackId::from(2))), 1);
        assert_eq!(level_of(&plan, PlanNodeKind::Master), 2);
    }

    #[test]
    fn inputs_run_first_and_feed_their_tracks() {
        let source = InputSource {
            first_channel: 0,
            channels: 2,
        };
        let plan = plan(
            &[track(1), track(2), RoutingNode::Master],
            &[RoutingConnection::new(track(1), RoutingNode::Master)],
            &[],
            &[(TrackId::from(1), source)],
        );
        assert_eq!(level_of(&plan, PlanNodeKind::Input(source)), 0);
        assert_eq!(level_of(&plan, PlanNodeKind::Track(TrackId::from(1))), 1);
        assert_eq!(level_of(&plan, PlanNodeKind::Track(TrackId::from(2))), 1);
        assert_eq!(level_of(&plan, PlanNodeKind::Master), 2);
    }

    #[test]
    fn connections_against_the_routing_order_are_dropped() {
        // Bus X is ordered before its source, as a cycle leftover would be.
        let x = RoutingNode::Bus(BusId::from(1));
        let plan = plan(
            &[x, track(1), RoutingNode::Master],
            &[RoutingConnection::new(track(1), x)],
            &[],
            &[],
        );
        assert!(plan.edges.is_empty());
    }
}
