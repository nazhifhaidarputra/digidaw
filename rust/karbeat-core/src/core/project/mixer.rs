    use hashbrown::{HashMap, HashSet};
    use karbeat_plugin_types::{Param, ParameterSpec};
    use karbeat_plugins::registry::PluginRegistry;
    use smallvec::SmallVec;

    use serde::{Deserialize, Serialize};
    use thiserror::Error;

    use crate::{
        audio::event::PluginTarget,
        commands::EffectTarget,
        core::project::{plugin::AudioPlugin, ApplicationState, AudioTrack, PluginInstance, TrackId},
        shared::{BusId, EffectId, GeneratorId},
    };

    #[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
    pub enum SidechainRoute {
        Generator(GeneratorId),
        TrackEffect(TrackId, EffectId),
        BusEffect(BusId, EffectId),
        MasterEffect(EffectId),
    }

    impl SidechainRoute {
        pub fn owner_node(&self, tracks: &HashMap<TrackId, AudioTrack>) -> Option<RoutingNode> {
            match self {
                SidechainRoute::TrackEffect(track_id, _) => Some(RoutingNode::Track(*track_id)),
                SidechainRoute::BusEffect(bus_id, _) => Some(RoutingNode::Bus(*bus_id)),
                SidechainRoute::MasterEffect(_) => Some(RoutingNode::Master),
                SidechainRoute::Generator(gen_id) => {
                    // A generator has no routing identity of its own — it's audio
                    // that gets summed into whatever track hosts it. Needs a
                    // generator -> owning track lookup
                    find_track_hosting_generator(tracks, *gen_id).map(RoutingNode::Track)
                }
            }
        }
    }

    // =============================================================================
    // Routing Matrix Types
    // =============================================================================

    /// A node in the routing graph
    #[derive(Serialize, Deserialize, Clone, Copy, PartialEq, Eq, Hash, Debug)]
    pub enum RoutingNode {
        Track(TrackId),
        Bus(BusId),
        Master,
        PluginSidechain(SidechainRoute),
    }

    #[derive(Error, Debug)]
    #[error("Error happened during MixerError processing")]
    pub enum MixerError {
        TypeConversionError,
    }

    impl RoutingNode {
        pub fn try_from_plugin_target(
            plugin_target: PluginTarget,
            tracks: &HashMap<TrackId, AudioTrack>,
        ) -> Result<Self, MixerError> {
            match plugin_target {
                PluginTarget::Generator(generator_id) => {
                    find_track_hosting_generator(tracks, generator_id)
                        .ok_or_else(|| MixerError::TypeConversionError)
                        .map(|id| RoutingNode::Track(id))
                }
                PluginTarget::TrackEffect(track_id, ..) => Ok(RoutingNode::Track(track_id)),
                PluginTarget::BusEffect(bus_id, ..) => Ok(RoutingNode::Bus(bus_id)),
                PluginTarget::MasterEffect(..) => Ok(RoutingNode::Master),
            }
        }
    }
    
    impl From<PluginTarget> for SidechainRoute {
        fn from(value: PluginTarget) -> Self {
            match value {
                PluginTarget::Generator(generator_id) => SidechainRoute::Generator(generator_id),
                PluginTarget::TrackEffect(track_id, effect_id) => SidechainRoute::TrackEffect(track_id, effect_id),
                PluginTarget::BusEffect(bus_id, effect_id) => SidechainRoute::BusEffect(bus_id, effect_id),
                PluginTarget::MasterEffect(effect_id) => SidechainRoute::MasterEffect(effect_id),
            }
        }
    }

    /// A routing connection in the matrix
    #[derive(Serialize, Deserialize, Clone, Debug, PartialEq)]
    pub struct RoutingConnection {
        pub source: RoutingNode,
        pub destination: RoutingNode,
        /// Send level (0.0 = no signal, 1.0 = full signal)
        pub send_level: f32,
        /// If true, this is a "send" (post-fader tap) not the main output
        pub is_send: bool,
        // TODO here: Add is_bypassed bool flag to indicate whether
        // we bypass this connection during the DSP
    }

    impl RoutingConnection {
        pub fn new(source: RoutingNode, destination: RoutingNode) -> Self {
            Self {
                source,
                destination,
                send_level: 1.0,
                is_send: false,
            }
        }

        pub fn new_send(source: RoutingNode, destination: RoutingNode, send_level: f32) -> Self {
            Self {
                source,
                destination,
                send_level,
                is_send: true,
            }
        }
    }

    /// A mixer bus with its own channel strip
    #[derive(Serialize, Deserialize, Clone, Debug, PartialEq)]
    #[serde(default)]
    pub struct BusMixerChannel {
        pub id: BusId,
        pub name: String,
        pub channel: MixerChannel,
    }

    #[derive(Serialize, Deserialize, Clone, Debug, PartialEq)]
    #[serde(default)]
    pub struct TrackMixerChannel {
        pub id: TrackId,
        pub name: String,
        pub channel: MixerChannel,
    }

    impl Default for BusMixerChannel {
        fn default() -> Self {
            Self {
                id: BusId::from(0),
                name: String::new(),
                channel: MixerChannel::default(),
            }
        }
    }

    impl Default for TrackMixerChannel {
        fn default() -> Self {
            Self {
                id: TrackId::from(0),
                name: String::new(),
                channel: MixerChannel::default(),
            }
        }
    }

    impl BusMixerChannel {
        pub fn new(id: BusId, name: &str) -> Self {
            Self {
                id,
                name: name.to_string(),
                channel: MixerChannel::default(),
            }
        }
    }

    /// Custom Error type for better error clarity
    ///
    /// This represents an error that occur due to param setting operation
    #[derive(Error, Debug, Clone)]
    #[error("Mixer param error for track {track_id}: {message}")]
    pub struct MixerSetParamError {
        pub message: String,
        pub track_id: TrackId,
    }

    #[derive(Error, Debug, Clone)]
    #[error("Effect creation error: {message}")]
    pub struct EffectCreationError {
        pub message: String,
    }

    impl MixerSetParamError {
        pub fn new(track_id: TrackId, message: &str) -> Self {
            Self {
                track_id,
                message: message.to_string(),
            }
        }
    }

    #[derive(Error, Debug)]
    #[error("Mixer not found for track {track_id}: {message}")]
    pub struct MixerNotFoundError {
        pub message: String,
        pub track_id: TrackId,
    }

    impl MixerNotFoundError {
        pub fn new(track_id: TrackId, message: &str) -> Self {
            Self {
                track_id,
                message: message.to_string(),
            }
        }
    }

    #[derive(Clone, Copy, Debug)]
    pub enum MixerChannelParams {
        Volume(f32),
        Pan(f32),
        Mute(bool),
        InvertedPhase(bool),
        Solo(bool),
    }

    #[derive(Serialize, Deserialize, Clone, Default, Debug, PartialEq)]
    #[serde(default)]
    pub struct EffectInstance {
        pub id: EffectId,
        pub instance: PluginInstance,
    }

    impl EffectInstance {
        pub fn new(id: EffectId, instance: PluginInstance) -> Self {
            Self {
                id,
                instance: instance,
            }
        }
    }

    #[derive(Serialize, Deserialize, Clone, Default, Debug, PartialEq)]
    #[serde(default)]
    pub struct MixerState {
        /// Per-track mixer channels (volume, pan, effects)
        pub channels: HashMap<TrackId, TrackMixerChannel>,
        /// Master bus channel
        pub master_bus: MixerChannel,
        /// Named buses for grouping/submixing
        pub buses: HashMap<BusId, BusMixerChannel>,
        /// All routing connections in the matrix
        pub routing: Vec<RoutingConnection>,
        /// Counter for generating bus IDs
        pub bus_counter: u32,
    }

    #[derive(Serialize, Deserialize, Clone, Debug, PartialEq)]
    #[serde(default)]
    pub struct MixerChannel {
        pub volume: Param<f32>, //dB
        pub pan: Param<f32>,    // -1.0 to 1.0
        pub mute: bool,
        pub solo: bool,
        pub inverted_phase: bool,

        pub effect_counter: u32,

        // The effects chain (EQ, Compressor) comes AFTER the generator
        pub effects: SmallVec<[EffectInstance; 9]>,
    }

    impl Default for MixerChannel {
        fn default() -> Self {
            Self {
                volume: Param::new_f32(1, "Volume", "MixerChannel", 0.0, -60.0, 6.0, 0.1), // 0 dB = unity gain
                pan: Param::new_f32(2, "Pan", "MixerChannel", 0.0, -1.0, 1.0, 0.01),
                mute: false,
                solo: false,
                effect_counter: 0,
                inverted_phase: false,
                effects: SmallVec::new(),
            }
        }
    }

    impl MixerChannel {
        pub fn add_effect(
            &mut self,
            registry: &mut PluginRegistry,
            effect_registry_id: u32,
        ) -> anyhow::Result<(Box<dyn AudioPlugin + Send + Sync>, String, EffectId)> {
            let effect_id = EffectId::next(&mut self.effect_counter);

            let (effect_plugin, effect_name, _default_params) = {
                if let Some((effect_box, name)) = registry.create_plugin_by_id(effect_registry_id) {
                    let default_params = effect_box.default_parameters();
                    (effect_box, name, default_params)
                } else {
                    let message = format!(
                        "Effect with ID {} not found in registry",
                        effect_registry_id
                    );
                    log::error!("{}", message);
                    // Decrement counters if failed to prevent gaps/orphans
                    self.effect_counter -= 1;

                    return Err(anyhow::anyhow!(message));
                }
            };

            let plugin_instance = PluginInstance::new_with_id(effect_registry_id, &effect_name);

            let effect_instance = EffectInstance::new(effect_id, plugin_instance);
            self.effects.push(effect_instance);

            Ok((effect_plugin, effect_name, effect_id))
        }

        pub fn remove_effect(&mut self, effect_id: EffectId) -> anyhow::Result<()> {
            self.effects.retain(|effect| effect.id != effect_id);

            Ok(())
        }

        /// Get parameter specs of channel's parameter
        pub fn get_channel_specs(&self) -> Vec<ParameterSpec> {
            vec![
                self.volume.to_spec(),
                self.pan.to_spec(),
                // Note: maybe I will change the bool parameter to Param<bool> too
            ]
        }
    }

    impl MixerState {
        /// Add an effect descriptor to a mixer channel by its registry ID.
        pub fn add_effect_descriptor_by_id(
            &mut self,
            registry: &mut PluginRegistry,
            track_id: &TrackId,
            registry_id: u32,
        ) -> anyhow::Result<(EffectTarget, EffectId, Box<dyn AudioPlugin + Send + Sync>)> {
            let mixer_channel = self
                .channels
                .get_mut(track_id)
                .ok_or_else(|| MixerNotFoundError::new(*track_id, "Cannot find the mixer channel"))
                .map_err(|e| anyhow::anyhow!(e))?;

            let (effect_plugin, effect_name, effect_id) =
                mixer_channel.channel.add_effect(registry, registry_id)?;

            log::info!(
                "Effect {} (registry_id={}) added to track {:?}",
                effect_name,
                registry_id,
                track_id
            );

            Ok((EffectTarget::Track(*track_id), effect_id, effect_plugin))
        }

        pub fn remove_effect_by_id(
            &mut self,
            track_id: &TrackId,
            effect_id: EffectId,
        ) -> anyhow::Result<(EffectTarget, EffectId)> {
            let mixer_channel = self
                .channels
                .get_mut(track_id)
                .ok_or_else(|| MixerNotFoundError::new(*track_id, "Cannot find the mixer channel"))
                .map_err(|e| anyhow::anyhow!(e))?;

            // Clone and modify the channel
            mixer_channel.channel.remove_effect(effect_id)?;

            self.remove_routing_for_sidechain(SidechainRoute::TrackEffect(*track_id, effect_id));

            Ok((EffectTarget::Track(*track_id), effect_id))
        }

        /// Get all effect instances from a mixer channel
        pub fn get_effects(
            &self,
            track_id: &TrackId,
        ) -> Result<Vec<EffectInstance>, MixerNotFoundError> {
            let mixer_channel = self
                .channels
                .get(track_id)
                .ok_or_else(|| MixerNotFoundError::new(*track_id, "Cannot find the mixer channel"))?
                .to_owned();

            // Clone and modify the channel
            Ok(mixer_channel.channel.effects.to_vec())
        }

        pub fn add_effect_to_master_bus(
            &mut self,
            registry: &mut PluginRegistry,
            registry_id: u32,
        ) -> anyhow::Result<(Box<dyn AudioPlugin + Send + Sync>, String, EffectId)> {
            let channel = &mut self.master_bus;
            let (effect_plugin, effect_name, effect_id) = channel.add_effect(registry, registry_id)?;

            log::info!(
                "Effect {} (registry_id={}) added to master bus",
                effect_name,
                registry_id
            );
            Ok((effect_plugin, effect_name, effect_id))
        }

        pub fn remove_effect_from_master_bus(&mut self, effect_id: EffectId) -> anyhow::Result<()> {
            let channel = &mut self.master_bus;
            channel.remove_effect(effect_id)?;

            self.remove_routing_for_sidechain(SidechainRoute::MasterEffect(effect_id));

            Ok(())
        }

        // =========================================================================
        // Bus Management
        // =========================================================================

        /// Create a new mixer bus and return its ID
        pub fn create_bus(&mut self, name: String) -> BusId {
            let bus_id = BusId::next(&mut self.bus_counter);
            let bus = BusMixerChannel::new(bus_id, &name);
            self.buses.insert(bus_id, bus);

            // By default, new buses route to master
            self.routing.push(RoutingConnection::new(
                RoutingNode::Bus(bus_id),
                RoutingNode::Master,
            ));

            bus_id
        }

        /// Remove a bus and all routing connections to/from it
        pub fn remove_bus(&mut self, bus_id: BusId) -> anyhow::Result<()> {
            if !self.buses.contains_key(&bus_id) {
                return Err(anyhow::anyhow!("Bus {:?} not found", bus_id));
            }

            // Remove the bus
            self.buses.remove(&bus_id);

            // Remove all routing connections involving this bus
            self.routing.retain(|conn| {
                let touches_bus_directly = conn.source == RoutingNode::Bus(bus_id)
                    || conn.destination == RoutingNode::Bus(bus_id);
                let touches_bus_via_sidechain = matches!(
                    conn.destination,
                    RoutingNode::PluginSidechain(SidechainRoute::BusEffect(b, _)) if b == bus_id
                );
                !(touches_bus_directly || touches_bus_via_sidechain)
            });

            Ok(())
        }

        /// Get a mutable reference to a bus
        pub fn get_bus_mut(&mut self, bus_id: &BusId) -> Option<&mut BusMixerChannel> {
            self.buses.get_mut(bus_id)
        }

        pub fn rename_bus(&mut self, bus_id: BusId, new_name: &str) -> anyhow::Result<()> {
            let bus = self
                .buses
                .get_mut(&bus_id)
                .ok_or_else(|| anyhow::anyhow!("Bus {:?} not found", bus_id))?;

            let old_name = bus.name.clone();
            bus.name = new_name.to_string();

            log::info!("Bus {:?} renamed from {} to {}", bus_id, old_name, new_name);
            Ok(())
        }

        pub fn add_effect_to_bus(
            &mut self,
            registry: &mut PluginRegistry,
            bus_id: BusId,
            registry_id: u32,
        ) -> anyhow::Result<(EffectTarget, EffectId, Box<dyn AudioPlugin + Send + Sync>)> {
            let bus = self
                .buses
                .get_mut(&bus_id)
                .ok_or_else(|| anyhow::anyhow!("Bus {:?} not found", bus_id))?;

            let (effect_plugin, effect_name, effect_id) =
                bus.channel.add_effect(registry, registry_id)?;

            log::info!(
                "Effect {} (registry_id={}) added to bus {:?}",
                effect_name,
                registry_id,
                bus_id
            );

            Ok((EffectTarget::Bus(bus_id), effect_id, effect_plugin))
        }

        pub fn remove_effect_from_bus(
            &mut self,
            bus_id: BusId,
            effect_id: EffectId,
        ) -> anyhow::Result<()> {
            let bus = self
                .buses
                .get_mut(&bus_id)
                .ok_or_else(|| anyhow::anyhow!("Bus {:?} not found", bus_id))?;

            bus.channel.remove_effect(effect_id)?;

            self.remove_routing_for_sidechain(SidechainRoute::BusEffect(bus_id, effect_id));

            Ok(())
        }

        // =========================================================================
        // Routing Management
        // =========================================================================

        pub fn add_routing(
            &mut self,
            connection: RoutingConnection,
            tracks: &HashMap<TrackId, AudioTrack>,
        ) -> anyhow::Result<()> {
            if connection.source == RoutingNode::Master {
                return Err(anyhow::anyhow!("Master cannot be a routing source"));
            }
            if matches!(connection.destination, RoutingNode::Track(_)) {
                return Err(anyhow::anyhow!("Tracks cannot be routing destinations"));
            }
            if matches!(connection.source, RoutingNode::PluginSidechain(_)) {
                return Err(anyhow::anyhow!(
                    "A sidechain slot cannot be a routing source"
                ));
            }
            // Sidechain taps are always sends — there's no "main output" concept
            // for a sidechain slot; it just sums whatever's routed to it.
            if matches!(connection.destination, RoutingNode::PluginSidechain(_)) && !connection.is_send
            {
                return Err(anyhow::anyhow!(
                    "Sidechain routing must be a send (is_send = true)"
                ));
            }
            // Sidechain destination must actually resolve to something real.
            if let RoutingNode::PluginSidechain(route) = connection.destination {
                if route.owner_node(tracks).is_none() {
                    return Err(anyhow::anyhow!(
                        "Sidechain route does not resolve to a live owner"
                    ));
                }
            }

            let exists = self.routing.iter().any(|c| {
                c.source == connection.source
                    && c.destination == connection.destination
                    && c.is_send == connection.is_send
            });
            if exists {
                return Err(anyhow::anyhow!("Routing connection already exists"));
            }

            self.routing.push(connection.clone());
            if self.has_routing_cycle(tracks) {
                self.routing.pop();
                return Err(anyhow::anyhow!("Routing would create a cycle"));
            }

            Ok(())
        }

        /// Remove a routing connection
        pub fn remove_routing(
            &mut self,
            source: RoutingNode,
            destination: RoutingNode,
            is_send: bool,
        ) -> anyhow::Result<()> {
            let original_len = self.routing.len();
            self.routing.retain(|c| {
                !(c.source == source && c.destination == destination && c.is_send == is_send)
            });

            if self.routing.len() == original_len {
                return Err(anyhow::anyhow!("Routing connection not found"));
            }

            Ok(())
        }

        /// Check if the routing graph has a cycle using DFS
        pub fn has_routing_cycle(&self, tracks: &HashMap<TrackId, AudioTrack>) -> bool {
            let mut adj: HashMap<RoutingNode, Vec<RoutingNode>> = HashMap::new();

            // Seed every real node so isolated nodes are still visited.
            let all_nodes = self
                .channels
                .keys()
                .map(|id| RoutingNode::Track(*id))
                .chain(self.buses.keys().map(|id| RoutingNode::Bus(*id)))
                .chain(std::iter::once(RoutingNode::Master));
            for n in all_nodes {
                adj.entry(n).or_default();
            }

            for conn in &self.routing {
                // Resolve PluginSidechain destinations down to the concrete node
                // that must be processed before the sidechain data is readable.
                let dest = match conn.destination {
                    RoutingNode::PluginSidechain(route) => route.owner_node(tracks),
                    other => Some(other),
                };
                // A source that is itself a PluginSidechain doesn't make sense
                // (sidechain destinations aren't audio sources) — skip defensively.
                let src = match conn.source {
                    RoutingNode::PluginSidechain(_) => None,
                    other => Some(other),
                };

                if let (Some(src), Some(dst)) = (src, dest) {
                    adj.entry(src).or_default().push(dst);
                }
            }

            let mut visited = HashSet::new();
            let mut rec_stack = HashSet::new();

            for &node in adj.keys().collect::<Vec<_>>() {
                if !visited.contains(&node) && find_cycle(node, &adj, &mut visited, &mut rec_stack) {
                    return true;
                }
            }

            false
        }

        /// Get topologically sorted routing order for audio thread processing.
        /// Sidechain dependencies are folded in: a node with an unresolved
        /// sidechain source isn't "ready" until that source is scheduled.
        pub fn get_routing_order(&self, tracks: &HashMap<TrackId, AudioTrack>) -> Vec<RoutingNode> {
            let all_nodes: Vec<RoutingNode> = self
                .channels
                .keys()
                .map(|id| RoutingNode::Track(*id))
                .chain(self.buses.keys().map(|id| RoutingNode::Bus(*id)))
                .chain(std::iter::once(RoutingNode::Master))
                .collect();

            let mut in_degree: HashMap<RoutingNode, usize> = HashMap::new();
            let mut adj: HashMap<RoutingNode, Vec<RoutingNode>> = HashMap::new();
            for &n in &all_nodes {
                in_degree.insert(n, 0);
                adj.insert(n, Vec::new());
            }

            for conn in &self.routing {
                let dest = match conn.destination {
                    RoutingNode::PluginSidechain(route) => route.owner_node(tracks),
                    other => Some(other),
                };
                let src = match conn.source {
                    RoutingNode::PluginSidechain(_) => None,
                    other => Some(other),
                };

                if let (Some(src), Some(dst)) = (src, dest) {
                    // Guard against nodes referenced only via routing but not
                    // seeded above (shouldn't happen, but keeps this infallible).
                    adj.entry(src).or_default().push(dst);
                    *in_degree.entry(dst).or_insert(0) += 1;
                }
            }

            // Kahn's algorithm over the unified graph. Tracks with in-degree 0
            // naturally come first, same as before, but now a track that is the
            // *target* of a sidechain route correctly waits on its source.
            let mut queue: Vec<RoutingNode> = in_degree
                .iter()
                .filter(|(_, &deg)| deg == 0)
                .map(|(&n, _)| n)
                .collect();

            let mut order = Vec::with_capacity(all_nodes.len());
            while let Some(node) = queue.pop() {
                order.push(node);
                if let Some(neighbors) = adj.get(&node) {
                    for &neighbor in neighbors {
                        if let Some(deg) = in_degree.get_mut(&neighbor) {
                            *deg -= 1;
                            if *deg == 0 {
                                queue.push(neighbor);
                            }
                        }
                    }
                }
            }

            order
        }

        /// Auto-route a track to master (used when creating new tracks)
        pub fn add_track_default_routing(&mut self, track_id: TrackId) {
            // Check if track already has any routing
            let has_routing = self
                .routing
                .iter()
                .any(|c| c.source == RoutingNode::Track(track_id));

            if !has_routing {
                self.routing.push(RoutingConnection::new(
                    RoutingNode::Track(track_id),
                    RoutingNode::Master,
                ));
            }
        }

        /// Remove all routing for a track (used when deleting tracks).
        /// This includes:
        ///   - connections where the track is the source (its own audio going somewhere)
        ///   - connections targeting a sidechain slot on an effect that lives on this track
        ///   - connections targeting a sidechain slot on this track's generator (if any)
        ///
        /// Must be called with the track's data still present in `tracks` (i.e. before
        /// it's removed from `ApplicationState.tracks`), since it needs to read the
        /// track's generator id to resolve the last case.
        pub fn remove_track_routing(
            &mut self,
            track_id: TrackId,
            tracks: &HashMap<TrackId, AudioTrack>,
        ) {
            let generator_id = tracks
                .get(&track_id)
                .and_then(|t| t.generator.as_ref())
                .map(|g| g.id);

            self.routing.retain(|c| {
                let is_source = c.source == RoutingNode::Track(track_id);

                let is_effect_dest = matches!(
                    c.destination,
                    RoutingNode::PluginSidechain(SidechainRoute::TrackEffect(t, _)) if t == track_id
                );

                let is_generator_dest = generator_id.is_some_and(|gid| {
                    matches!(
                        c.destination,
                        RoutingNode::PluginSidechain(SidechainRoute::Generator(g)) if g == gid
                    )
                });

                !(is_source || is_effect_dest || is_generator_dest)
            });
        }

        pub fn update_routing(
            &mut self,
            connection: RoutingConnection,
            tracks: &HashMap<TrackId, AudioTrack>,
        ) -> anyhow::Result<Box<[RoutingConnection]>> {
            if connection.source == RoutingNode::Master {
                return Err(anyhow::anyhow!("Master cannot be a routing source"));
            }
            if matches!(connection.destination, RoutingNode::Track(_)) {
                return Err(anyhow::anyhow!("Tracks cannot be routing destinations"));
            }
            if matches!(connection.source, RoutingNode::PluginSidechain(_)) {
                return Err(anyhow::anyhow!(
                    "A sidechain slot cannot be a routing source"
                ));
            }
            if matches!(connection.destination, RoutingNode::PluginSidechain(_)) && !connection.is_send
            {
                return Err(anyhow::anyhow!(
                    "Sidechain routing must be a send (is_send = true)"
                ));
            }
            if let RoutingNode::PluginSidechain(route) = connection.destination {
                if route.owner_node(tracks).is_none() {
                    return Err(anyhow::anyhow!(
                        "Sidechain route does not resolve to a live owner"
                    ));
                }
            }

            let mut backed_up_connections = Vec::new();

            if !connection.is_send {
                self.routing.retain(|c| {
                    if c.source == connection.source && !c.is_send {
                        backed_up_connections.push(c.clone());
                        false
                    } else {
                        true
                    }
                });
            } else {
                self.routing.retain(|c| {
                    if c.source == connection.source
                        && c.destination == connection.destination
                        && c.is_send
                    {
                        backed_up_connections.push(c.clone());
                        false
                    } else {
                        true
                    }
                });
            }

            self.routing.push(connection.clone());

            if self.has_routing_cycle(tracks) {
                self.routing.pop();
                self.routing.extend(backed_up_connections);
                return Err(anyhow::anyhow!("Routing would create a feedback cycle"));
            }

            Ok(self.routing.clone().into_boxed_slice())
        }

        /// Remove all routing connections that target a specific sidechain slot.
        fn remove_routing_for_sidechain(&mut self, route: SidechainRoute) {
            self.routing
                .retain(|c| c.destination != RoutingNode::PluginSidechain(route));
        }
    }

    impl ApplicationState {
        /// Get the mixer of a track ID
        pub fn get_mixer_from_track(&self, track_id: &TrackId) -> Option<TrackMixerChannel> {
            // check if the track exists
            if self.tracks.get(track_id).is_none() {
                return None;
            }

            self.mixer.channels.get(track_id).cloned()
        }

        /// Get the entire mixer state
        pub fn get_mixer_state(&self) -> &MixerState {
            return &self.mixer;
        }
    }
    /// Helper to find cycle using DFS over the full RoutingNode graph
    fn find_cycle(
        node: RoutingNode,
        adj: &HashMap<RoutingNode, Vec<RoutingNode>>,
        visited: &mut HashSet<RoutingNode>,
        rec_stack: &mut HashSet<RoutingNode>,
    ) -> bool {
        visited.insert(node);
        rec_stack.insert(node);

        if let Some(neighbors) = adj.get(&node) {
            for &neighbor in neighbors {
                if !visited.contains(&neighbor) {
                    if find_cycle(neighbor, adj, visited, rec_stack) {
                        return true;
                    }
                } else if rec_stack.contains(&neighbor) {
                    return true;
                }
            }
        }

        rec_stack.remove(&node);
        false
    }

    fn find_track_hosting_generator(
        tracks: &HashMap<TrackId, AudioTrack>,
        generator_id: GeneratorId,
    ) -> Option<TrackId> {
        tracks
            .iter()
            .find(|(_, track)| {
                track
                    .generator
                    .as_ref()
                    .is_some_and(|g| g.id == generator_id)
            })
            .map(|(id, _)| *id)
    }
