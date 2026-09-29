use smallvec::SmallVec;

use crate::{
    commands::EffectTarget,
    shared::id::{AudioSourceId, AutomationId, BusId, EffectId, GeneratorId, TrackId},
};

/// Audio-engine updates required after an undo or redo changed the project.
///
/// History actions only mutate `ApplicationState`; they report what the engine must republish
/// and the API layer sends the matching commands (see `DawContext::apply_engine_sync`).
#[must_use = "apply the sync so the audio engine matches the project"]
#[derive(Debug, Default, Clone, PartialEq)]
pub struct EngineSync {
    /// Republish tracks, clips, and patterns.
    pub track_graph: bool,
    /// Replace the whole render graph, including routing, automation, and modulation.
    pub full_graph: bool,
    /// Republish the project tempo.
    pub tempo: bool,
    /// Republish the routing matrix.
    pub routing: bool,
    /// Republish these automation lanes.
    pub lanes: SmallVec<[AutomationId; 2]>,
    /// Republish these audio sources.
    pub sources: SmallVec<[AudioSourceId; 1]>,
    /// Install or remove built-in plugin processors and buses.
    pub plugins: Vec<PluginSync>,
}

/// One plugin or bus change the engine must mirror.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PluginSync {
    /// Build the generator from its restored project instance and install it.
    InstallGenerator {
        /// Restored generator.
        generator_id: GeneratorId,
        /// Track that owns it.
        track_id: TrackId,
    },
    /// Remove a generator processor.
    RemoveGenerator {
        /// Generator removed from the project.
        generator_id: GeneratorId,
    },
    /// Build the effect from its restored project instance and install it.
    InstallEffect {
        /// Chain holding the effect.
        target: EffectTarget,
        /// Restored effect.
        effect_id: EffectId,
    },
    /// Remove an effect processor.
    RemoveEffect {
        /// Chain holding the effect.
        target: EffectTarget,
        /// Effect removed from the project.
        effect_id: EffectId,
    },
    /// Move an effect processor to a chain position.
    MoveEffect {
        /// Chain holding the effect.
        target: EffectTarget,
        /// Moved effect.
        effect_id: EffectId,
        /// Zero-based destination position.
        position: usize,
    },
    /// Enable or bypass an effect processor.
    SetEffectBypass {
        /// Chain holding the effect.
        target: EffectTarget,
        /// Affected effect.
        effect_id: EffectId,
        /// `true` passes audio through untouched.
        bypass: bool,
    },
    /// Create an engine bus for a restored project bus.
    AddBus(BusId),
    /// Remove an engine bus.
    RemoveBus(BusId),
}

impl EngineSync {
    /// Nothing to republish.
    pub fn none() -> Self {
        Self::default()
    }

    /// Republish tracks, clips, and patterns.
    pub fn track_graph() -> Self {
        Self {
            track_graph: true,
            ..Self::default()
        }
    }

    /// Replace the whole render graph.
    pub fn full_graph() -> Self {
        Self {
            full_graph: true,
            ..Self::default()
        }
    }

    /// Republish the tempo.
    pub fn tempo() -> Self {
        Self {
            tempo: true,
            ..Self::default()
        }
    }

    /// Republish the routing matrix.
    pub fn routing() -> Self {
        Self {
            routing: true,
            ..Self::default()
        }
    }

    /// Republish one automation lane.
    pub fn lane(id: AutomationId) -> Self {
        Self {
            lanes: smallvec::smallvec![id],
            ..Self::default()
        }
    }

    /// Republish one audio source.
    pub fn source(id: AudioSourceId) -> Self {
        Self {
            sources: smallvec::smallvec![id],
            ..Self::default()
        }
    }

    /// Mirror one plugin or bus change.
    pub fn plugin(change: PluginSync) -> Self {
        Self {
            plugins: vec![change],
            ..Self::default()
        }
    }

    /// Adds `other`'s updates to this one, keeping plugin changes in order.
    pub fn merge(&mut self, other: EngineSync) {
        self.track_graph |= other.track_graph;
        self.full_graph |= other.full_graph;
        self.tempo |= other.tempo;
        self.routing |= other.routing;
        for lane in other.lanes {
            if !self.lanes.contains(&lane) {
                self.lanes.push(lane);
            }
        }
        for source in other.sources {
            if !self.sources.contains(&source) {
                self.sources.push(source);
            }
        }
        self.plugins.extend(other.plugins);
    }

    /// Returns this sync combined with `other`.
    pub fn and(mut self, other: EngineSync) -> Self {
        self.merge(other);
        self
    }

    /// Whether nothing needs to be republished.
    pub fn is_empty(&self) -> bool {
        *self == Self::default()
    }
}
