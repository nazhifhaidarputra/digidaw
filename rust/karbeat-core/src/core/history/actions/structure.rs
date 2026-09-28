use hashbrown::HashSet;

use super::{
    automation::{AutomationChanged, AutomationRecorder},
    pools::{PoolBefore, PoolSwap},
};
use crate::commands::EffectTarget;
use crate::core::{
    history::{EngineSync, HistoryAction, HistoryError, PluginSync},
    project::{
        ApplicationState, AudioTrack, Clip, GeneratorInstance,
        mixer::{
            BusMixerChannel, EffectChain, EffectInstance, RoutingConnection, RoutingNode,
            TrackMixerChannel,
        },
    },
};
use crate::shared::id::{BusId, ClipId, EffectId, GeneratorId, GraphNodeId, TrackId};

fn effects_mut(
    app: &mut ApplicationState,
    target: EffectTarget,
) -> Result<&mut EffectChain, HistoryError> {
    app.get_mixer_channel_from_target_mut(target.into())
        .map(|channel| &mut channel.effects)
        .ok_or(HistoryError::missing("Mixer channel"))
}

/// Tracks or buses added or deleted, with everything that belongs to them: generators, mixer
/// channels and their effects, routing-graph nodes, clips, routing, and automation.
///
/// Holds only what the edit changed, as it is on the other side of the edit. Deleted entities
/// were detached and come back under their original keys; their plugins are re-installed on the
/// audio thread from the restored project state.
#[derive(Debug)]
pub struct StructureChanged {
    label: &'static str,
    tracks: PoolSwap<TrackId, AudioTrack>,
    generators: PoolSwap<GeneratorId, GeneratorInstance>,
    graph_nodes: PoolSwap<GraphNodeId, RoutingNode>,
    clips: PoolSwap<ClipId, Clip>,
    buses: PoolSwap<BusId, BusMixerChannel>,
    channels: Box<[(TrackId, Option<TrackMixerChannel>)]>,
    routing: Vec<RoutingConnection>,
    automation: AutomationChanged,
}

impl StructureChanged {
    fn swap(&mut self, app: &mut ApplicationState) -> Result<EngineSync, HistoryError> {
        self.tracks.swap(&mut app.tracks, "Track")?;
        self.generators.swap(&mut app.generator_pool, "Generator")?;
        self.buses.swap(&mut app.mixer.buses, "Bus")?;
        self.graph_nodes
            .swap(&mut app.mixer.graph_nodes, "Routing node")?;
        self.clips.swap(&mut app.clips_pool, "Clip")?;
        for (track_id, other) in &mut self.channels {
            let current = app.mixer.channels.remove(*track_id);
            if let Some(channel) = other.take() {
                app.mixer.channels.insert(*track_id, channel);
            }
            *other = current;
        }
        std::mem::swap(&mut app.mixer.routing, &mut self.routing);
        let mut sync = self.automation.swap(app)?;

        sync.merge(self.plugin_sync(app));
        sync.merge(EngineSync::full_graph());
        Ok(sync)
    }

    /// Engine changes that mirror which generators, channels, and buses exist now.
    fn plugin_sync(&self, app: &ApplicationState) -> EngineSync {
        let mut sync = EngineSync::none();
        for generator_id in self.generators.keys() {
            let change = match app.tracks.values().find(|track| {
                track
                    .generator
                    .as_ref()
                    .is_some_and(|g| g.id == generator_id)
            }) {
                Some(track) if app.generator_pool.contains_key(generator_id) => {
                    PluginSync::InstallGenerator {
                        generator_id,
                        track_id: track.id,
                    }
                }
                _ => PluginSync::RemoveGenerator { generator_id },
            };
            sync.merge(EngineSync::plugin(change));
        }
        for bus_id in self.buses.keys() {
            match app.mixer.buses.get(bus_id) {
                Some(bus) => {
                    sync.merge(EngineSync::plugin(PluginSync::AddBus(bus_id)));
                    for effect in bus.channel.effects.iter() {
                        sync.merge(EngineSync::plugin(PluginSync::InstallEffect {
                            target: EffectTarget::Bus(bus_id),
                            effect_id: effect.id,
                        }));
                    }
                }
                None => sync.merge(EngineSync::plugin(PluginSync::RemoveBus(bus_id))),
            }
        }
        for (track_id, other) in &self.channels {
            let target = EffectTarget::Track(*track_id);
            if let Some(channel) = app.mixer.channels.get(*track_id) {
                for effect in channel.channel.effects.iter() {
                    sync.merge(EngineSync::plugin(PluginSync::InstallEffect {
                        target,
                        effect_id: effect.id,
                    }));
                }
            } else if let Some(removed) = other {
                for effect in removed.channel.effects.iter() {
                    sync.merge(EngineSync::plugin(PluginSync::RemoveEffect {
                        target,
                        effect_id: effect.id,
                    }));
                }
            }
        }
        sync
    }
}

swap_action!(StructureChanged, field label);

/// Captures the project before a track or bus is added or deleted and builds the
/// [`StructureChanged`] record afterwards.
#[derive(Debug)]
pub struct StructureRecorder {
    tracks: PoolBefore<TrackId, AudioTrack>,
    generators: PoolBefore<GeneratorId, GeneratorInstance>,
    graph_nodes: PoolBefore<GraphNodeId, RoutingNode>,
    clips: Vec<(ClipId, Clip)>,
    buses_before: Vec<(BusId, BusMixerChannel)>,
    bus_keys: HashSet<BusId>,
    channels_before: Vec<(TrackId, Option<TrackMixerChannel>)>,
    track_keys: HashSet<TrackId>,
    routing: Vec<RoutingConnection>,
    automation: AutomationRecorder,
}

impl StructureRecorder {
    /// Snapshots the project. `tracks` and `buses` are the existing tracks and buses the edit
    /// deletes; created ones are found automatically.
    pub fn begin(app: &ApplicationState, tracks: &[TrackId], buses: &[BusId]) -> Self {
        let clips = tracks
            .iter()
            .filter_map(|id| app.tracks.get(*id))
            .flat_map(|track| track.clips.iter())
            .filter_map(|id| app.clips_pool.get(*id).map(|clip| (*id, clip.clone())))
            .collect();
        Self {
            tracks: PoolBefore::capture(&app.tracks),
            generators: PoolBefore::capture(&app.generator_pool),
            graph_nodes: PoolBefore::capture(&app.mixer.graph_nodes),
            clips,
            buses_before: buses
                .iter()
                .filter_map(|id| app.mixer.buses.get(*id).map(|bus| (*id, bus.clone())))
                .collect(),
            bus_keys: app.mixer.buses.keys().collect(),
            channels_before: tracks
                .iter()
                .map(|id| (*id, app.mixer.channels.get(*id).cloned()))
                .collect(),
            track_keys: app.tracks.keys().collect(),
            routing: app.mixer.routing.clone(),
            automation: AutomationRecorder::begin(app),
        }
    }

    /// Builds the record from what the edit changed.
    pub fn finish(self, app: &ApplicationState, label: &'static str) -> StructureChanged {
        let mut channels = self.channels_before;
        channels.extend(
            app.tracks
                .keys()
                .filter(|id| !self.track_keys.contains(id))
                .map(|id| (id, None)),
        );
        let mut buses: Vec<(BusId, Option<BusMixerChannel>)> = self
            .buses_before
            .into_iter()
            .map(|(id, bus)| (id, Some(bus)))
            .collect();
        buses.extend(
            app.mixer
                .buses
                .keys()
                .filter(|id| !self.bus_keys.contains(id))
                .map(|id| (id, None)),
        );
        let clips = self
            .clips
            .into_iter()
            .filter(|(id, _)| !app.clips_pool.contains_key(*id))
            .map(|(id, clip)| (id, Some(clip)))
            .collect();

        StructureChanged {
            label,
            tracks: self.tracks.diff(&app.tracks),
            generators: self.generators.diff(&app.generator_pool),
            graph_nodes: self.graph_nodes.diff(&app.mixer.graph_nodes),
            clips: PoolSwap::from_entries(clips),
            buses: PoolSwap::from_entries(buses),
            channels: channels.into_boxed_slice(),
            routing: self.routing,
            automation: self.automation.finish(app, label),
        }
    }
}

/// A first-party effect added to or removed from a chain, with the automation removed with it.
#[derive(Debug)]
pub struct EffectToggled {
    label: &'static str,
    target: EffectTarget,
    effect_id: EffectId,
    /// Chain position of the effect while it is present.
    index: usize,
    /// The effect while it is absent from the chain.
    effect: Option<EffectInstance>,
    automation: Option<AutomationChanged>,
}

impl EffectToggled {
    /// Records an effect the edit added at `index`.
    pub fn added(target: EffectTarget, effect_id: EffectId, index: usize) -> Self {
        Self {
            label: "Add Effect",
            target,
            effect_id,
            index,
            effect: None,
            automation: None,
        }
    }

    /// Records an effect the edit removed from `index`, and the automation removed with it.
    pub fn removed(
        target: EffectTarget,
        effect_id: EffectId,
        index: usize,
        effect: EffectInstance,
        automation: AutomationChanged,
    ) -> Self {
        Self {
            label: "Remove Effect",
            target,
            effect_id,
            index,
            effect: Some(effect),
            automation: Some(automation),
        }
    }

    fn swap(&mut self, app: &mut ApplicationState) -> Result<EngineSync, HistoryError> {
        let chain = effects_mut(app, self.target)?;
        let change = match self.effect.take() {
            Some(effect) => {
                chain.restore(self.effect_id, self.index, effect)?;
                PluginSync::InstallEffect {
                    target: self.target,
                    effect_id: self.effect_id,
                }
            }
            None => {
                self.index = chain
                    .position(self.effect_id)
                    .ok_or(HistoryError::missing("Effect"))?;
                self.effect = chain.remove(self.effect_id);
                PluginSync::RemoveEffect {
                    target: self.target,
                    effect_id: self.effect_id,
                }
            }
        };
        let mut sync = EngineSync::plugin(change);
        if let Some(automation) = &mut self.automation {
            sync.merge(automation.swap(app)?);
        }
        Ok(sync)
    }
}

swap_action!(EffectToggled, field label);

/// An effect moved within its chain; holds its position on the other side of the edit.
#[derive(Debug)]
pub struct EffectMoved {
    target: EffectTarget,
    effect_id: EffectId,
    position: usize,
}

impl EffectMoved {
    /// Records a move from the effect's previous position.
    pub fn new(target: EffectTarget, effect_id: EffectId, previous_position: usize) -> Self {
        Self {
            target,
            effect_id,
            position: previous_position,
        }
    }

    fn swap(&mut self, app: &mut ApplicationState) -> Result<EngineSync, HistoryError> {
        let destination = self.position;
        self.position = effects_mut(app, self.target)?.move_to(self.effect_id, destination)?;
        Ok(EngineSync::plugin(PluginSync::MoveEffect {
            target: self.target,
            effect_id: self.effect_id,
            position: destination,
        }))
    }
}

swap_action!(EffectMoved, "Move Effect");

/// An effect bypassed or enabled; holds the flag on the other side of the edit.
#[derive(Debug)]
pub struct EffectBypassed {
    target: EffectTarget,
    effect_id: EffectId,
    bypass: bool,
}

impl EffectBypassed {
    /// Records a bypass change from the previous flag.
    pub fn new(target: EffectTarget, effect_id: EffectId, previous_bypass: bool) -> Self {
        Self {
            target,
            effect_id,
            bypass: previous_bypass,
        }
    }

    fn swap(&mut self, app: &mut ApplicationState) -> Result<EngineSync, HistoryError> {
        let effect = effects_mut(app, self.target)?
            .get_mut(self.effect_id)
            .ok_or(HistoryError::missing("Effect"))?;
        std::mem::swap(&mut effect.instance.bypass, &mut self.bypass);
        Ok(EngineSync::plugin(PluginSync::SetEffectBypass {
            target: self.target,
            effect_id: self.effect_id,
            bypass: effect.instance.bypass,
        }))
    }
}

swap_action!(EffectBypassed, "Bypass Effect");

/// Routing or sidechain connections changed, with the routing-graph nodes they added or removed.
#[derive(Debug)]
pub struct RoutingChanged {
    label: &'static str,
    routing: Vec<RoutingConnection>,
    graph_nodes: PoolSwap<GraphNodeId, RoutingNode>,
}

impl RoutingChanged {
    fn swap(&mut self, app: &mut ApplicationState) -> Result<EngineSync, HistoryError> {
        std::mem::swap(&mut app.mixer.routing, &mut self.routing);
        self.graph_nodes
            .swap(&mut app.mixer.graph_nodes, "Routing node")?;
        Ok(EngineSync::routing())
    }
}

swap_action!(RoutingChanged, field label);

/// Captures routing before a routing edit and builds the [`RoutingChanged`] record afterwards.
#[derive(Debug)]
pub struct RoutingRecorder {
    routing: Vec<RoutingConnection>,
    graph_nodes: PoolBefore<GraphNodeId, RoutingNode>,
}

impl RoutingRecorder {
    /// Snapshots the routing matrix and routing-graph nodes.
    pub fn begin(app: &ApplicationState) -> Self {
        Self {
            routing: app.mixer.routing.clone(),
            graph_nodes: PoolBefore::capture(&app.mixer.graph_nodes),
        }
    }

    /// Builds the record from what the edit changed.
    pub fn finish(self, app: &ApplicationState, label: &'static str) -> RoutingChanged {
        RoutingChanged {
            label,
            routing: self.routing,
            graph_nodes: self.graph_nodes.diff(&app.mixer.graph_nodes),
        }
    }
}
