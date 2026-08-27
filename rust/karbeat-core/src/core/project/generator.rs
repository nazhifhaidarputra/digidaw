use serde::{Deserialize, Serialize};

use crate::{
    core::project::{ApplicationState, plugin::instance::PluginInstance},
    shared::id::GeneratorId,
};

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq, Default)]
#[serde(default)]
pub struct GeneratorInstance {
    pub id: GeneratorId,
    pub instance_type: GeneratorInstanceType,
}

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq)]
pub enum GeneratorInstanceType {
    // A Synth (Internal or VST)
    Plugin(PluginInstance),

    // A Sampler (Plays a file from AssetLibrary)
    Sampler { asset_id: u32, root_note: u8 },
}

// Default implementation for GeneratorInstanceType
impl Default for GeneratorInstanceType {
    fn default() -> Self {
        Self::Plugin(PluginInstance::default())
    }
}

impl ApplicationState {
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
