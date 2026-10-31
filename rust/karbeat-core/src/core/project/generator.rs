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

    /// Sets or clears the name a plugin generator is shown under and returns the previous one.
    /// A blank name, or the plugin's own name, clears it. Names are at most 50 bytes.
    pub fn rename_generator(
        &mut self,
        generator_id: GeneratorId,
        display_name: Option<&str>,
    ) -> anyhow::Result<Option<String>> {
        let generator = self
            .generator_pool
            .get_mut(generator_id)
            .ok_or_else(|| anyhow::anyhow!("Generator {generator_id} not found"))?;
        let GeneratorInstanceType::Plugin(plugin) = &mut generator.instance_type else {
            anyhow::bail!("Only plugin generators can be renamed");
        };
        let display_name = display_name
            .map(str::trim)
            .filter(|name| !name.is_empty() && *name != plugin.name);
        if let Some(name) = display_name {
            anyhow::ensure!(name.len() <= 50, "Max character for generator name is 50");
        }
        Ok(self.set_generator_display_name(generator_id, display_name.map(str::to_owned)))
    }

    /// Stores `display_name` on the generator and on the track's copy of it, returning the
    /// previous name.
    pub fn set_generator_display_name(
        &mut self,
        generator_id: GeneratorId,
        display_name: Option<String>,
    ) -> Option<String> {
        for track in self.tracks.values_mut() {
            if let Some(GeneratorInstance {
                id,
                instance_type: GeneratorInstanceType::Plugin(plugin),
            }) = &mut track.generator
                && *id == generator_id
            {
                plugin.display_name.clone_from(&display_name);
            }
        }
        let generator = self.generator_pool.get_mut(generator_id)?;
        let GeneratorInstanceType::Plugin(plugin) = &mut generator.instance_type else {
            return None;
        };
        std::mem::replace(&mut plugin.display_name, display_name)
    }

    /// Deletes a generator source and removes all clips referencing it.
    pub fn remove_generator(&mut self, generator_id: GeneratorId) -> Option<GeneratorId> {
        if self.generator_pool.detach(generator_id).is_none() {
            return None;
        }

        let clips_pool = &mut self.clips_pool;
        for track in self.tracks.values_mut() {
            track.remove_clip_by_source_id(clips_pool, generator_id.to_u64(), true);
        }

        Some(generator_id)
    }
}
