use serde::{Deserialize, Serialize};

use crate::{
    core::project::{ApplicationState, plugin::instance::PluginInstance},
    shared::id::GeneratorId,
};

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq, Default)]
#[serde(default)]
/// Serializable sound source that can be assigned to a track.
pub struct GeneratorInstance {
    /// Stable project identity of the generator.
    pub id: GeneratorId,
    /// Concrete generator implementation and its saved state.
    pub instance_type: GeneratorInstanceType,
}

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq)]
/// Supported project generator implementations.
pub enum GeneratorInstanceType {
    /// Built-in or externally hosted instrument plugin.
    Plugin(PluginInstance),

    /// Sampler source backed by an asset-library entry.
    Sampler {
        /// Asset-library identifier of the sampled audio.
        asset_id: u32,
        /// MIDI note that plays the sample at its original pitch.
        root_note: u8,
    },
}

// Default implementation for GeneratorInstanceType
impl Default for GeneratorInstanceType {
    fn default() -> Self {
        Self::Plugin(PluginInstance::default())
    }
}

impl ApplicationState {
    /// Inserts a generator into the global pool and returns its assigned stable ID.
    pub fn add_generator(&mut self, instance_type: GeneratorInstanceType) -> GeneratorId {
        self.generator_pool
            .insert_with_key(|id| GeneratorInstance { id, instance_type })
    }

    /// Deletes a generator source and removes all clips referencing it.
    pub fn remove_generator(&mut self, generator_id: GeneratorId) -> Option<GeneratorId> {
        if self.generator_pool.remove(generator_id).is_none() {
            return None;
        }

        let clips_pool = &mut self.clips_pool;
        for track in self.tracks.values_mut() {
            track.remove_clip_by_source_id(clips_pool, generator_id.to_u64(), true);
        }

        Some(generator_id)
    }
}
