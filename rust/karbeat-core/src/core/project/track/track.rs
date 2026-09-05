use itertools::Itertools;
use karbeat_plugin_api::traits::AudioPlugin;
use karbeat_plugins::registry::PluginRegistry;

use serde::{Deserialize, Serialize};
use slotmap::SlotMap;

use crate::{
    core::project::{
        ApplicationState, Clip, DawSource, GeneratorInstance, GeneratorInstanceType,
        PluginInstance, TrackMixerChannel,
    },
    shared::{
        GeneratorId, GraphNodeId,
        id::{ClipId, TrackId},
    },
};
use karbeat_utils::color::Color;

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq)]
#[serde(default)]
pub struct AudioTrack {
    pub id: TrackId,
    pub graph_node_id: GraphNodeId,
    pub name: String,
    pub color: Color,
    pub track_type: TrackType,
    /// Timeline order only; clip values live in `ApplicationState::clips_pool`.
    pub clips: Vec<ClipId>,
    pub generator: Option<GeneratorInstance>,
    /// ======================================
    /// Track Sorting Order
    /// Represents the track index position to be displayed in the UI.
    /// Used for preserving layout on load/save and custom reordering.
    /// ======================================
    pub order_idx: usize,
}

impl Default for AudioTrack {
    fn default() -> Self {
        Self {
            id: Default::default(),
            graph_node_id: Default::default(),
            name: Default::default(),
            color: Color::new_from_rgb(255, 255, 255),
            track_type: TrackType::Audio,
            clips: Vec::new(),
            generator: None,
            order_idx: 0,
        }
    }
}

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq)]
pub enum TrackType {
    Audio,
    Midi,
    Automation,
}

pub type RemovedTrackType = TrackType;

impl std::str::FromStr for TrackType {
    type Err = String;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s {
            "audio" => Ok(TrackType::Audio),
            "midi" => Ok(TrackType::Midi),
            "automation" => Ok(TrackType::Automation),
            _ => Err("Invalid track type".into()),
        }
    }
}

impl AudioTrack {
    pub fn new(id: TrackId, name: &str, color: Color, track_type: TrackType) -> Self {
        Self {
            id,
            graph_node_id: Default::default(),
            name: name.to_string(),
            color,
            track_type,
            clips: Vec::new(),
            generator: None,
            order_idx: 0,
        }
    }

    /// ======================================
    /// Set Track Order
    /// Updates the order index, which dictates UI track positioning.
    /// ======================================
    pub fn set_order_idx(&mut self, new_idx: usize) {
        self.order_idx = new_idx;
    }

    pub fn clips(&self) -> &[ClipId] {
        &self.clips
    }

    pub fn clips_to_vec(&self, clips_pool: &SlotMap<ClipId, Clip>) -> Vec<Clip> {
        self.clips
            .iter()
            .filter_map(|id| clips_pool.get(*id).cloned())
            .collect()
    }

    pub fn track_type(&self) -> &TrackType {
        return &self.track_type;
    }

    pub fn get_clip(&self, clips_pool: &SlotMap<ClipId, Clip>, clip_id: &ClipId) -> Option<Clip> {
        self.clips
            .contains(clip_id)
            .then(|| clips_pool.get(*clip_id).cloned())
            .flatten()
    }

    pub fn accepts_clip(&self, clip: &Clip) -> bool {
        matches!(
            (&self.track_type, &clip.source),
            (TrackType::Audio, Some(DawSource::Audio(_)))
                | (TrackType::Midi, Some(DawSource::Midi(_)))
                | (TrackType::Automation, Some(DawSource::Automation(_)))
        )
    }

    /// Add a new clip to the track. it will return Err if
    /// the clip type is incompatible with the track type
    pub fn add_clip(
        &mut self,
        clip_id: ClipId,
        clips_pool: &SlotMap<ClipId, Clip>,
    ) -> anyhow::Result<()> {
        let clip = clips_pool
            .get(clip_id)
            .ok_or_else(|| anyhow::anyhow!("Clip not found in global pool"))?;
        let is_valid = self.accepts_clip(clip);

        if is_valid {
            let start_time = clip.time.start_time_raw();
            let insert_pos = self
                .clips
                .binary_search_by_key(&start_time, |id| clips_pool[*id].time.start_time_raw())
                .unwrap_or_else(|e| e);

            // Insert directly at the sorted position (O(N) memory shift, highly cache-friendly)
            self.clips.insert(insert_pos, clip_id);

            return Ok(());
        } else {
            return Err(anyhow::anyhow!(
                "Warning: Mismatched Clip Source for Track Type"
            ));
        }
    }

    /// Remove the clip, change max_index_sample if the deleted clip are the latest end sample index
    pub fn remove_clip(&mut self, clip_id: &ClipId) -> anyhow::Result<ClipId> {
        let idx = self
            .clips
            .iter()
            .position(|id| id == clip_id)
            .ok_or_else(|| anyhow::anyhow!("Clip not found"))?;

        // Vec::remove shifts the remaining elements automatically
        Ok(self.clips.remove(idx))
    }

    /// Remove all clips that have the same source ID (only remove
    /// audio clip because it needs a cascading remove upon an audio source deletion)
    pub fn remove_clip_by_source_id(
        &mut self,
        clips_pool: &mut SlotMap<ClipId, Clip>,
        source_id: u64,
        is_generator: bool,
    ) {
        let removed: Vec<_> = self
            .clips
            .iter()
            .copied()
            .filter(
                |id| match clips_pool.get(*id).and_then(|clip| clip.source.as_ref()) {
                    Some(DawSource::Audio(sid)) => !is_generator && sid.to_u64() == source_id,
                    _ => false,
                },
            )
            .collect();
        self.clips.retain(|id| !removed.contains(id));
        for id in removed {
            clips_pool.remove(id);
        }
    }

    /// Optimized for adding multiple clips (e.g., Paste / Duplicate).
    pub fn add_clips_bulk(&mut self, new_clips: &[ClipId], clips_pool: &SlotMap<ClipId, Clip>) {
        self.clips.extend_from_slice(new_clips);
        self.clips
            .sort_by_key(|id| clips_pool[*id].time.start_time_raw());
    }
}

impl ApplicationState {
    /// Update Track Order (Drag and Drop Support)
    /// Shifts other tracks to maintain a perfect sequence without gaps or duplicates.
    pub fn update_track_order(&mut self, track_id: TrackId, new_idx: usize) -> anyhow::Result<()> {
        let mut tracks: Vec<_> = self.tracks.values().cloned().collect();
        tracks.sort_by_key(|t| t.order_idx);

        // Find the track's current sorted position
        let current_pos = tracks
            .iter()
            .position(|t| t.id == track_id)
            .ok_or_else(|| anyhow::anyhow!("Track {:?} not found", track_id))?;

        // Clamp the target to prevent out-of-bounds
        let target_idx = new_idx.min(tracks.len().saturating_sub(1));

        // Move the track in the sorted vector
        let track = tracks.remove(current_pos);
        tracks.insert(target_idx, track);

        // Re-apply sequential indices to ALL tracks
        for (i, t) in tracks.iter().enumerate() {
            if t.order_idx != i {
                if let Some(track) = self.tracks.get_mut(t.id) {
                    track.set_order_idx(i);
                }
            }
        }

        Ok(())
    }

    /// Normalizes track order indices to ensure they are sequential (0, 1, 2, ...)
    /// Call this after removing tracks or loading a project from disk.
    pub fn normalize_track_orders(&mut self) {
        let mut tracks_sorted: Vec<_> = self.tracks.values().cloned().collect();
        tracks_sorted.sort_by_key(|t| t.order_idx);

        for (new_idx, track) in tracks_sorted.into_iter().enumerate() {
            if track.order_idx != new_idx {
                if let Some(t) = self.tracks.get_mut(track.id) {
                    t.set_order_idx(new_idx);
                }
            }
        }
    }

    pub fn add_new_audio_track(&mut self) -> AudioTrack {
        let track_order = self
            .tracks
            .values()
            .map(|t| t.order_idx)
            .max()
            .map(|m| m + 1)
            .unwrap_or(0);
        let new_track_id = self.tracks.insert_with_key(|id| AudioTrack {
            track_type: TrackType::Audio,
            id,
            name: "Audio track".to_string(),
            order_idx: track_order,
            ..Default::default()
        });
        // Create a corresponding mixer channel and default routing
        self.mixer.channels.insert(
            new_track_id,
            TrackMixerChannel {
                id: new_track_id,
                ..Default::default()
            },
        );
        self.mixer.add_track_default_routing(new_track_id);
        if let Some(node_id) = self
            .mixer
            .graph_node_id(crate::core::project::RoutingNode::Track(new_track_id))
        {
            self.tracks[new_track_id].graph_node_id = node_id;
            self.mixer.channels[new_track_id].graph_node_id = node_id;
        }
        let new_track = self.tracks[new_track_id].clone();
        new_track
    }

    /// Add a new MIDI track with a generator by its registry ID.
    pub fn add_new_midi_track_with_generator_id(
        &mut self,
        registry: &mut PluginRegistry,
        registry_id: u32,
    ) -> anyhow::Result<(AudioTrack, GeneratorId, Box<dyn AudioPlugin + Send + Sync>)> {
        // Create the plugin via registry using ID
        let (generator_plugin, generator_name) = {
            if let Some((generator_box, name)) = registry.create_plugin_by_id(registry_id) {
                (generator_box, name)
            } else {
                let message = format!("Generator with ID {} not found in registry", registry_id);
                log::error!("{}", message);
                return Err(anyhow::anyhow!("{}", message));
            }
        };

        // Create plugin instance descriptor with registry ID
        let plugin_instance = PluginInstance::new_with_id(registry_id, &generator_name);

        let gen_id = self.generator_pool.insert_with_key(|id| GeneratorInstance {
            id,
            instance_type: GeneratorInstanceType::Plugin(plugin_instance),
        });
        let generator = self.generator_pool[gen_id].clone();
        let track_order = self
            .tracks
            .values()
            .map(|t| t.order_idx)
            .max()
            .map(|m| m + 1)
            .unwrap_or(0);
        let track_id = self.tracks.insert_with_key(|id| AudioTrack {
            track_type: TrackType::Midi,
            id,
            name: generator_name.clone(),
            color: Color::new_from_string("#FF8A65").unwrap_or(Color::default()),
            generator: Some(generator),
            order_idx: track_order,
            ..Default::default()
        });
        // Create a corresponding mixer channel and default routing
        self.mixer.channels.insert(
            track_id,
            TrackMixerChannel {
                id: track_id,
                ..Default::default()
            },
        );
        self.mixer.add_track_default_routing(track_id);
        if let Some(node_id) = self
            .mixer
            .graph_node_id(crate::core::project::RoutingNode::Track(track_id))
        {
            self.tracks[track_id].graph_node_id = node_id;
            self.mixer.channels[track_id].graph_node_id = node_id;
        }
        let new_track = self.tracks[track_id].clone();

        log::info!(
            "New MIDI track with generator {} (registry_id={}) is successfully created",
            generator_name,
            registry_id
        );
        Ok((new_track, gen_id, generator_plugin))
    }

    /// Remove a track and clean up its mixer channel, routing, generator, and automation lanes.
    pub fn remove_track(&mut self, track_id: TrackId) -> anyhow::Result<RemovedTrackType> {
        let mut deleted_track_type = RemovedTrackType::Audio;
        // Get the generator ID before removing the track
        let generator_id = self
            .tracks
            .get(track_id)
            .and_then(|t| t.generator.as_ref().map(|g| g.id));

        // Remove the mixer channel
        self.mixer.channels.remove(track_id);

        // Remove all routing connections for this track
        self.mixer.remove_track_routing(track_id, &self.tracks);

        // Remove the generator from the pool if the track had one
        if let Some(gen_id) = generator_id {
            self.generator_pool.remove(gen_id);
            deleted_track_type = RemovedTrackType::Midi;
        }

        // Remove all automation lanes for this track
        self.remove_modulations_for_track(track_id);

        // Remove the track and its globally-owned clips.
        let Some(track) = self.tracks.remove(track_id) else {
            return Err(anyhow::anyhow!("Track {:?} not found", track_id));
        };
        for clip_id in track.clips {
            self.clips_pool.remove(clip_id);
        }

        self.normalize_track_orders();

        Ok(deleted_track_type)
    }

    // Get the track ordered by index
    pub fn get_track_ordered_by_index(&self) -> Box<[AudioTrack]> {
        self.tracks
            .values()
            .sorted_by_key(|t| t.order_idx)
            .cloned()
            .collect()
    }
}
