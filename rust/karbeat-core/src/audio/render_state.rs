use crate::core::project::{
    ApplicationState, AssetLibrary, Clip, GeneratorId, TrackId,
    automation::{AutomationCurveType, AutomationPoint},
    mixer::RoutingConnection,
    plugin::AudioPlugin,
    track::{AudioTrack, midi::Pattern},
};
use crate::core::project::{AutomationLane, ModulationLink, ModulationSource};
use crate::shared::id::*;
use hashbrown::HashMap;
use karbeat_host::HostedProcessor;
use karbeat_utils::math::is_power_of_two;
use karbeat_utils::types::NormalizedF64;
use slab::Slab;

// =============================================================================
// Audio Thread Owned Plugin State
// =============================================================================

/// A generator plugin instance owned by the audio thread
pub struct AudioGeneratorInstance {
    pub id: GeneratorId,
    pub track_id: TrackId,
    /// Stable plugin type identifier used to create another instance.
    pub registry_id: u32,
    pub plugin: Box<dyn AudioPlugin>,
}

pub struct AudioEffectInstance {
    pub id: EffectId,
    /// Stable plugin type identifier used to create another instance.
    pub registry_id: u32,
    pub plugin: Box<dyn AudioPlugin>,
}

#[derive(Default, Clone)]
pub struct AudioPluginSnapshotState {
    /// Generator plugins stored in a compact arena.
    pub generators: Vec<GeneratorPluginSnapshot>,

    /// Effect chain per track. Index = TrackId as usize.
    /// Empty tracks simply hold an empty Vec, avoiding `Option` overhead.
    pub track_effects: Vec<Vec<EffectPluginSnapshot>>,

    /// Master effect chain
    pub master_effects: Vec<EffectPluginSnapshot>,

    /// Bus effect chains. Index = BusId as usize.
    pub bus_effects: Vec<Vec<EffectPluginSnapshot>>,
}

#[derive(Clone)]
pub struct GeneratorPluginSnapshot {
    /// Project instance identifier.
    pub id: GeneratorId,
    /// Track that receives this generator's output.
    pub track_id: TrackId,
    /// Stable plugin type identifier used to create the offline instance.
    pub registry_id: u32,
    /// First-party state; hosted state is captured separately on the native UI thread.
    pub serialized_state: Vec<u8>,
    /// Hosted state must be captured by the native owner after the audio snapshot.
    pub host_instance: Option<karbeat_host::HostInstanceId>,
    pub host_bypass: bool,
}

#[derive(Clone)]
pub struct EffectPluginSnapshot {
    /// Project instance identifier.
    pub id: EffectId,
    /// Stable plugin type identifier used to create the offline instance.
    pub registry_id: u32,
    /// First-party state; hosted state is captured separately on the native UI thread.
    pub serialized_state: Vec<u8>,
    pub host_instance: Option<karbeat_host::HostInstanceId>,
    pub host_bypass: bool,
}

/// Audio thread's owned plugin instances - NO locks required for access
/// This is managed via AudioCommand, NOT cloned from ApplicationState
pub struct AudioPluginState {
    /// Generator plugins stored in a compact arena.
    pub generators: Slab<AudioGeneratorInstance>,

    /// Maps stable project IDs to the corresponding arena entries.
    generator_keys: HashMap<GeneratorId, usize>,

    /// Effect chain per track. Index = TrackId as usize.
    /// Empty tracks simply hold an empty Vec, avoiding `Option` overhead.
    pub track_effects: Vec<Vec<AudioEffectInstance>>,

    /// Master effect chain
    pub master_effects: Vec<AudioEffectInstance>,

    /// Bus effect chains. Index = BusId as usize.
    pub bus_effects: Vec<Vec<AudioEffectInstance>>,

    retirement: rtrb::Producer<Box<dyn AudioPlugin>>,
}

impl Default for AudioPluginState {
    fn default() -> Self {
        let (retirement, mut consumer) =
            rtrb::RingBuffer::<Box<dyn AudioPlugin>>::new(1_024);
        std::thread::spawn(move || {
            loop {
                // Checked before pop: once abandoned no push can follow, so empty is final.
                let abandoned = consumer.is_abandoned();
                match consumer.pop() {
                    Ok(plugin) => plugin.retire(),
                    Err(rtrb::PopError::Empty) if abandoned => break,
                    Err(rtrb::PopError::Empty) => {
                        std::thread::sleep(std::time::Duration::from_millis(10));
                    }
                }
            }
        });
        Self {
            generators: Slab::new(),
            generator_keys: HashMap::new(),
            track_effects: Vec::new(),
            master_effects: Vec::new(),
            bus_effects: Vec::new(),
            retirement,
        }
    }
}

impl AudioPluginState {
    pub fn retire_plugin(&mut self, plugin: Box<dyn AudioPlugin>) {
        Self::enqueue_retirement(&mut self.retirement, plugin);
    }

    fn enqueue_retirement(
        retirement: &mut rtrb::Producer<Box<dyn AudioPlugin>>,
        plugin: Box<dyn AudioPlugin>,
    ) {
        if plugin.as_any().is::<HostedProcessor>() {
            plugin.retire();
            return;
        }
        if let Err(rtrb::PushError::Full(plugin)) = retirement.push(plugin) {
            std::mem::forget(plugin);
        }
    }

    pub fn plugin(&self, target: &crate::audio::event::PluginTarget) -> Option<&dyn AudioPlugin> {
        use crate::audio::event::PluginTarget;
        let effect = match target {
            PluginTarget::Generator(id) => return self.get_generator(*id).map(|generator| generator.plugin.as_ref()),
            PluginTarget::TrackEffect(track, effect) => self.track_effects.get(usize::try_from(track.to_u32()).ok()?)?.iter().find(|entry| entry.id == *effect),
            PluginTarget::BusEffect(bus, effect) => self.bus_effects.get(usize::try_from(bus.to_u32()).ok()?)?.iter().find(|entry| entry.id == *effect),
            PluginTarget::MasterEffect(effect) => self.master_effects.iter().find(|entry| entry.id == *effect),
        }?;
        Some(effect.plugin.as_ref())
    }

    // ==========================================
    // Generators
    // ==========================================

    /// Insert a generator or replace the existing instance with the same ID.
    pub fn insert_generator(&mut self, instance: AudioGeneratorInstance) {
        if let Some(&key) = self.generator_keys.get(&instance.id) {
            let previous = std::mem::replace(&mut self.generators[key], instance).plugin;
            self.retire_plugin(previous);
            return;
        }

        let id = instance.id;
        let key = self.generators.insert(instance);
        self.generator_keys.insert(id, key);
    }

    /// Remove a generator without shifting other arena entries.
    pub fn remove_generator(&mut self, id: GeneratorId) {
        if let Some(key) = self.generator_keys.remove(&id) {
            let plugin = self.generators.remove(key).plugin;
            self.retire_plugin(plugin);
        }
    }

    /// Remove every generator and its ID-to-arena-key mapping.
    pub fn clear_generators(&mut self) {
        let retirement = &mut self.retirement;
        for generator in self.generators.drain() {
            Self::enqueue_retirement(retirement, generator.plugin);
        }
        self.generator_keys.clear();
    }

    /// Return hosted endpoints before replacing or dropping effect chains.
    pub fn clear_effects(&mut self) {
        let retirement = &mut self.retirement;
        for chain in self
            .track_effects
            .iter_mut()
            .chain(self.bus_effects.iter_mut())
        {
            for effect in chain.drain(..) {
                Self::enqueue_retirement(retirement, effect.plugin);
            }
        }
        for effect in self.master_effects.drain(..) {
            Self::enqueue_retirement(retirement, effect.plugin);
        }
        self.track_effects.clear();
        self.bus_effects.clear();
    }

    /// Get a mutable reference to a specific generator
    #[inline]
    pub fn get_generator_mut(&mut self, id: GeneratorId) -> Option<&mut AudioGeneratorInstance> {
        let key = *self.generator_keys.get(&id)?;
        self.generators.get_mut(key)
    }

    /// Get an immutable reference to a specific generator
    #[inline]
    pub fn get_generator(&self, id: GeneratorId) -> Option<&AudioGeneratorInstance> {
        let key = *self.generator_keys.get(&id)?;
        self.generators.get(key)
    }

    // ==========================================
    // Track Effects
    // ==========================================

    /// Add an effect to a track's chain, resizing the tracks array if needed
    pub fn add_track_effect(&mut self, track_id_index: usize, effect: AudioEffectInstance) {
        if track_id_index >= self.track_effects.len() {
            self.track_effects.resize_with(track_id_index + 1, Vec::new);
        }
        self.track_effects[track_id_index].push(effect);
    }

    #[inline]
    pub fn get_track_effects_mut(
        &mut self,
        track_id_index: usize,
    ) -> Option<&mut Vec<AudioEffectInstance>> {
        self.track_effects.get_mut(track_id_index)
    }

    #[inline]
    pub fn get_track_effects(&self, track_id_index: usize) -> Option<&Vec<AudioEffectInstance>> {
        self.track_effects.get(track_id_index)
    }

    // ==========================================
    // Bus Effects
    // ==========================================

    /// Add an effect to a bus's chain, resizing the buses array if needed
    pub fn add_bus_effect(&mut self, bus_id_index: usize, effect: AudioEffectInstance) {
        if bus_id_index >= self.bus_effects.len() {
            self.bus_effects.resize_with(bus_id_index + 1, Vec::new);
        }
        self.bus_effects[bus_id_index].push(effect);
    }

    pub fn add_bus(&mut self, bus_id_index: usize) {
        if bus_id_index >= self.bus_effects.len() {
            self.bus_effects.resize_with(bus_id_index + 1, Vec::new);
        }
        let retirement = &mut self.retirement;
        for effect in self.bus_effects[bus_id_index].drain(..) {
            Self::enqueue_retirement(retirement, effect.plugin);
        }
    }

    pub fn remove_bus(&mut self, bus_id_index: usize) {
        let retirement = &mut self.retirement;
        if let Some(bus) = self.bus_effects.get_mut(bus_id_index) {
            for effect in bus.drain(..) {
                Self::enqueue_retirement(retirement, effect.plugin);
            }
        }
    }

    #[inline]
    pub fn get_bus_effects_mut(
        &mut self,
        bus_id_index: usize,
    ) -> Option<&mut Vec<AudioEffectInstance>> {
        self.bus_effects.get_mut(bus_id_index)
    }

    #[inline]
    pub fn get_bus_effects(&self, bus_id_index: usize) -> Option<&Vec<AudioEffectInstance>> {
        self.bus_effects.get(bus_id_index)
    }
}

impl Drop for AudioPluginState {
    fn drop(&mut self) {
        self.clear_generators();
        self.clear_effects();
    }
}

impl From<&AudioGeneratorInstance> for GeneratorPluginSnapshot {
    fn from(value: &AudioGeneratorInstance) -> Self {
        let hosted = value.plugin.as_any().downcast_ref::<HostedProcessor>();
        let host_instance = hosted.map(|plugin| plugin.instance);
        Self {
            id: value.id,
            track_id: value.track_id,
            registry_id: value.registry_id,
            serialized_state: if host_instance.is_some() {
                Vec::new()
            } else {
                value.plugin.get_state()
            },
            host_instance,
            host_bypass: hosted.is_some_and(HostedProcessor::is_bypassed),
        }
    }
}

impl From<&AudioEffectInstance> for EffectPluginSnapshot {
    fn from(value: &AudioEffectInstance) -> Self {
        let hosted = value.plugin.as_any().downcast_ref::<HostedProcessor>();
        let host_instance = hosted.map(|plugin| plugin.instance);
        Self {
            id: value.id,
            registry_id: value.registry_id,
            serialized_state: if host_instance.is_some() {
                Vec::new()
            } else {
                value.plugin.get_state()
            },
            host_instance,
            host_bypass: hosted.is_some_and(HostedProcessor::is_bypassed),
        }
    }
}

impl From<&AudioPluginState> for AudioPluginSnapshotState {
    fn from(value: &AudioPluginState) -> Self {
        Self {
            generators: value.generators.iter().map(|(_, g)| g.into()).collect(),
            track_effects: value
                .track_effects
                .iter()
                .map(|chain| chain.iter().map(EffectPluginSnapshot::from).collect())
                .collect(),
            master_effects: value
                .master_effects
                .iter()
                .map(EffectPluginSnapshot::from)
                .collect(),
            bus_effects: value
                .bus_effects
                .iter()
                .map(|chain| chain.iter().map(EffectPluginSnapshot::from).collect())
                .collect(),
        }
    }
}

// =============================================================================
// Cloneable Graph State (metadata only, no plugin instances)
// =============================================================================

/// Lightweight automation lane snapshot for the audio thread.
/// Contains only the data needed for real-time interpolation.
#[derive(Clone, Debug)]
pub struct AudioAutomationLane {
    pub points: Vec<AutomationPoint>,
    pub enabled: bool,
    pub min: f64,
    pub max: f64,
    pub default_value: NormalizedF64,
}

impl From<AutomationLane> for AudioAutomationLane {
    fn from(l: AutomationLane) -> Self {
        Self {
            points: l.points,
            enabled: l.enabled,
            min: l.min,
            max: l.max,
            default_value: l.default_value,
        }
    }
}

impl AudioAutomationLane {
    /// Get the normalized value at a given time in ticks.
    /// Returns `default_value` (normalized) if disabled or no points.
    #[inline]
    pub fn value_at_ticks(&self, time_ticks: u32) -> f64 {
        if !self.enabled || self.points.is_empty() {
            return *self.default_value;
        }
        *interpolate_points(&self.points, time_ticks)
    }
}

/// Interpolate sorted automation points at the given time in ticks.
/// Returns a normalized value (0.0–1.0).
#[inline]
fn interpolate_points(points: &[AutomationPoint], time_ticks: u32) -> NormalizedF64 {
    // Before first point
    if time_ticks <= points[0].time_ticks {
        return points[0].value;
    }

    // After last point
    let last = &points[points.len() - 1];
    if time_ticks >= last.time_ticks {
        return last.value;
    }

    // Binary search for the surrounding pair
    let idx = points
        .binary_search_by(|p| p.time_ticks.cmp(&time_ticks))
        .unwrap_or_else(|i| i);

    if idx == 0 {
        return points[0].value;
    }

    let p1 = &points[idx - 1];
    let p2 = &points[idx];
    let duration = p2.time_ticks.saturating_sub(p1.time_ticks);
    if duration == 0 {
        return p1.value;
    }

    let t = ((time_ticks - p1.time_ticks) as f64) / (duration as f64);

    match p1.curve_type {
        AutomationCurveType::Linear => {
            NormalizedF64::new(p1.value.get() + (p2.value.get() - p1.value.get()) * t)
        }
        AutomationCurveType::Exponential => {
            let v1 = p1.value.max(0.0001);
            let v2 = p2.value.max(0.0001);
            NormalizedF64::new(v1 * (v2 / v1).powf(t))
        }
        AutomationCurveType::Step => p1.value,
    }
}

/// Structural State: Tracks, Patterns, Routing, Assets (Heavy, changes rarely)
#[derive(Default, Clone)]
pub struct AudioGraphState {
    pub tracks: Box<[AudioTrack]>,
    pub clips: HashMap<ClipId, Clip>,
    pub patterns: HashMap<PatternId, Pattern>,
    /// Routing connections — owned and mutated directly by the audio thread
    /// via the UpdateRouting ring-buffer command.
    pub routing: Box<[RoutingConnection]>,
    /// IDs of all active buses — used for buffer allocation in PreparePlugin.
    pub bus_ids: Vec<BusId>,
    pub asset_library: AssetLibrary,
    /// Automation lanes for real-time parameter modulation
    pub automation_lanes: HashMap<AutomationId, AudioAutomationLane>,
    pub max_sample_index: u32,
    pub sample_rate: u32,
    pub buffer_size: usize,

    pub modulation_sources: HashMap<ModulationId, ModulationSource>,
    pub modulation_links: HashMap<ModulationLinkId, ModulationLink>,
}

impl From<&ApplicationState> for AudioGraphState {
    fn from(app: &ApplicationState) -> Self {
        let mut tracks_vec: Vec<AudioTrack> = app.tracks.values().cloned().collect();
        tracks_vec.sort_by_key(|t| t.id);

        let modulation_links = app
            .modulation_links
            .iter()
            .map(|(id, view)| (id, view.prop.clone()))
            .collect();

        Self {
            tracks: tracks_vec.into_boxed_slice(),
            clips: app
                .clips_pool
                .iter()
                .map(|(id, clip)| (id, clip.clone()))
                .collect(),
            patterns: app
                .pattern_pool
                .iter()
                .map(|(id, pattern)| (id, pattern.clone()))
                .collect(),
            routing: app.mixer.routing.clone().into_boxed_slice(),
            bus_ids: app.mixer.buses.keys().collect(),
            asset_library: app.asset_library.clone(),
            automation_lanes: app
                .automation_pool
                .clone()
                .into_iter()
                .map(|(id, l)| (id, l.into()))
                .collect(),
            max_sample_index: 0,
            sample_rate: app.audio_config.sample_rate,
            buffer_size: if is_power_of_two(app.audio_config.buffer_size.into()) {
                app.audio_config.buffer_size as usize
            } else {
                64
            },
            modulation_sources: app
                .modulation_sources
                .iter()
                .map(|(id, source)| (id, source.clone()))
                .collect(),
            modulation_links,
        }
    }
}

/// Consolidated State wrapper for the Audio Thread.
/// Contains only structural/graph data. Runtime transport state
/// is owned directly by AudioEngine.
#[derive(Clone, Default)]
pub struct AudioRenderState {
    pub graph: AudioGraphState,
}

impl From<&ApplicationState> for AudioRenderState {
    fn from(app: &ApplicationState) -> Self {
        Self {
            graph: AudioGraphState::from(app),
        }
    }
}

#[cfg(test)]
#[allow(clippy::unwrap_used, clippy::expect_used)]
mod tests {
    use std::sync::{
        Arc,
        atomic::{AtomicUsize, Ordering},
    };

    use karbeat_plugin_api::{
        prelude::ParameterSpec,
        traits::{AudioPlugin, HashMap},
        types::{AudioBuffers, BusConfig, PluginCategory, ProcessContext},
    };

    use super::AudioPluginState;

    struct CountingPlugin(Arc<AtomicUsize>);

    impl AudioPlugin for CountingPlugin {
        fn retire(self: Box<Self>) {
            self.0.fetch_add(1, Ordering::SeqCst);
        }
        fn name(&self) -> &str {
            "Counting plugin"
        }
        fn category(&self) -> PluginCategory {
            PluginCategory::Effect
        }
        fn prepare(&mut self, _: f32, _: usize) {}
        fn reset(&mut self) {}
        fn set_io_layout(&mut self, _: &[BusConfig], _: &[BusConfig]) {}
        fn process(&mut self, _: &mut AudioBuffers, _: &ProcessContext) {}
        fn set_parameter(&mut self, _: u32, _: f32) {}
        fn get_parameter(&self, _: u32) -> f32 {
            0.0
        }
        fn apply_automation(&mut self, _: u32, _: f32) {}
        fn clear_automation(&mut self, _: u32) {}
        fn default_parameters(&self) -> HashMap<u32, f32> {
            HashMap::new()
        }
        fn static_parameter_specs() -> Vec<ParameterSpec> {
            Vec::new()
        }
        fn get_parameter_specs(&self) -> Vec<ParameterSpec> {
            Vec::new()
        }
        fn as_any(&self) -> &dyn std::any::Any {
            self
        }
    }

    #[test]
    fn plugins_queued_before_state_drop_are_all_retired() {
        const ROUNDS: usize = 25;
        const PER_ROUND: usize = 16;
        let retired = Arc::new(AtomicUsize::new(0));

        for _ in 0..ROUNDS {
            let mut state = AudioPluginState::default();
            for _ in 0..PER_ROUND {
                state.retire_plugin(Box::new(CountingPlugin(Arc::clone(&retired))));
            }
            drop(state);
        }

        let expected = ROUNDS * PER_ROUND;
        let deadline = std::time::Instant::now() + std::time::Duration::from_secs(5);
        while retired.load(Ordering::SeqCst) < expected && std::time::Instant::now() < deadline {
            std::thread::sleep(std::time::Duration::from_millis(5));
        }
        assert_eq!(retired.load(Ordering::SeqCst), expected);
    }
}
