use std::{cmp::Ordering, sync::Arc};

use anyhow::anyhow;
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use slotmap::SlotMap;
use thiserror::Error;

pub use super::clip::Clip;
pub use super::clipboard::ClipboardContent;
pub use super::generator::GeneratorInstance;
pub use super::plugin::AudioPlugin;
pub use super::track::{AudioTrack, audio_waveform::AudioWaveform, midi::Pattern};
pub use super::transport::TransportState;

use crate::core::project::{ModulationLinkForOrderedLaneView, ModulationSource};
use crate::core::project::{automation::AutomationLane, mixer::MixerState};

pub use crate::shared::*;

#[derive(Serialize, Deserialize, Clone, Default, Debug)]
pub struct ApplicationState {
    // Things store inside ApplicationState
    // - Project Metadata
    // - Mixer
    // - Tracks timeline
    // - Settings
    //
    // - File explorer to access resources
    // - Audio related stuff (device, source, playback etc)
    pub metadata: ProjectMetadata,
    pub mixer: MixerState,
    pub transport: TransportState,
    pub asset_library: AssetLibrary,

    // All musical data lives here. The timeline just references these.
    pub pattern_pool: SlotMap<PatternId, Pattern>,

    // Generator sources
    pub generator_pool: SlotMap<GeneratorId, GeneratorInstance>,

    // Tracks contain Clips, but Clips are just "Containers"
    pub tracks: SlotMap<TrackId, AudioTrack>,

    // Automation lanes pool (lives at the same level as tracks/patterns/generators)
    pub automation_pool: SlotMap<AutomationId, AutomationLane>,

    // The Generators (LFOs, Macro Knobs, Peak Controllers)
    pub modulation_sources: SlotMap<ModulationId, ModulationSource>,

    // The Cables (Connects a Source to a Target)
    pub modulation_links: SlotMap<ModulationLinkId, ModulationLinkForOrderedLaneView>,

    /// Canonical clip storage. Tracks contain only ordered `ClipId` handles.
    pub clips_pool: SlotMap<ClipId, Clip>,

    // ========== NON-SERIALIZABLE SESSION DATA ===============
    // These fields are marked to be skipped during Save/Load
    #[serde(skip)]
    pub audio_config: AudioHardwareConfig,

    #[serde(skip)]
    pub clipboard: ClipboardContent,
}

pub struct PeakControlMod {}

// pub struct

#[derive(Serialize, Deserialize, Clone, Debug)]
pub enum DawSource {
    /// Points to an AudioWaveform
    Audio(AudioSourceId),

    /// Points to Generators paired with Patterns
    /// Each entry in the vector is a (GeneratorInstance, Pattern) pair.
    /// This allows a single clip to trigger multiple generators (layering) or just one.
    Midi(PatternId),

    /// Points to an Automation ID (Future implementation)
    Automation(AutomationId),
}

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq)]
pub struct ProjectMetadata {
    pub name: String,
    pub author: String,
    #[serde(default)]
    pub description: String,
    #[serde(default)]
    pub genre: String,
    pub version: String,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Error, PartialEq, Eq)]
pub enum ProjectMetadataError {
    #[error("Project title cannot be empty")]
    EmptyTitle,
    #[error("Project metadata field '{field}' exceeds {maximum} characters")]
    FieldTooLong { field: &'static str, maximum: usize },
}

impl ProjectMetadata {
    pub fn normalize_and_validate(mut self) -> Result<Self, ProjectMetadataError> {
        self.name = self.name.trim().to_string();
        self.author = self.author.trim().to_string();
        self.description = self.description.trim().to_string();
        self.genre = self.genre.trim().to_string();
        self.version = self.version.trim().to_string();

        if self.name.is_empty() {
            return Err(ProjectMetadataError::EmptyTitle);
        }

        Self::validate_length("title", &self.name, 120)?;
        Self::validate_length("author", &self.author, 120)?;
        Self::validate_length("description", &self.description, 4000)?;
        Self::validate_length("genre", &self.genre, 80)?;
        Self::validate_length("version", &self.version, 64)?;
        Ok(self)
    }

    fn validate_length(
        field: &'static str,
        value: &str,
        maximum: usize,
    ) -> Result<(), ProjectMetadataError> {
        if value.chars().count() > maximum {
            return Err(ProjectMetadataError::FieldTooLong { field, maximum });
        }
        Ok(())
    }
}

impl Default for ProjectMetadata {
    fn default() -> Self {
        Self {
            name: "Untitled".to_string(),
            author: Default::default(),
            description: Default::default(),
            genre: Default::default(),
            version: Default::default(),
            created_at: Utc::now(),
        }
    }
}

#[cfg(test)]
mod project_metadata_tests {
    use super::ProjectMetadata;

    #[test]
    fn legacy_metadata_without_description_or_genre_still_loads() {
        let json = r#"{
            "name":"Legacy",
            "author":"Author",
            "version":"1",
            "created_at":"2025-01-01T00:00:00Z"
        }"#;

        let metadata: ProjectMetadata = serde_json::from_str(json).expect("legacy metadata");

        assert_eq!(metadata.description, "");
        assert_eq!(metadata.genre, "");
    }

    #[test]
    fn new_metadata_fields_roundtrip() {
        let metadata = ProjectMetadata {
            name: "Project".to_string(),
            author: "Author".to_string(),
            description: "Description".to_string(),
            genre: "Electronic".to_string(),
            version: "2".to_string(),
            ..ProjectMetadata::default()
        };

        let encoded = serde_json::to_string(&metadata).expect("serialize metadata");
        let decoded: ProjectMetadata =
            serde_json::from_str(&encoded).expect("deserialize metadata");

        assert_eq!(decoded.name, metadata.name);
        assert_eq!(decoded.description, metadata.description);
        assert_eq!(decoded.genre, metadata.genre);
    }
}

#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct Note {
    pub id: NoteId,
    pub start_tick: u64,
    pub duration: u64,
    pub key: u8, // 21 - 127 MIDI key (Keep LB at A0)
    pub velocity: u8,

    pub probability: f32,
    pub micro_offset: i8,
    pub mute: bool,
}

impl PartialEq for Note {
    fn eq(&self, other: &Self) -> bool {
        self.start_tick == other.start_tick
    }
}

impl Eq for Note {}

impl PartialOrd for Note {
    fn partial_cmp(&self, other: &Self) -> Option<Ordering> {
        Some(self.cmp(other))
    }
}

impl Ord for Note {
    fn cmp(&self, other: &Self) -> Ordering {
        match self.start_tick.cmp(&other.start_tick) {
            Ordering::Equal => {
                // Secondary: if start times are equal, sort by key (pitch)
                match self.key.cmp(&other.key) {
                    Ordering::Equal => {
                        // Tertiary: if keys are equal, sort by velocity
                        self.velocity.cmp(&other.velocity)
                    }
                    other => other,
                }
            }
            other => other,
        }
    }
}

#[derive(Serialize, Deserialize, Clone, Debug, Default)]
pub struct AssetLibrary {
    pub source_map: SlotMap<AudioSourceId, Arc<AudioWaveform>>,
}

#[derive(Clone, Debug, PartialEq)]
pub struct AudioHardwareConfig {
    pub selected_input_device: String,
    pub selected_output_device: String,
    pub sample_rate: u32,
    pub buffer_size: u32,
    pub cpu_load: f32, // For UI monitoring
}

impl Default for AudioHardwareConfig {
    fn default() -> Self {
        Self {
            selected_input_device: Default::default(),
            selected_output_device: Default::default(),
            sample_rate: 48000,
            buffer_size: 1024,
            cpu_load: Default::default(),
        }
    }
}

impl ApplicationState {
    /// Deletes an audio source and removes all clips referencing it.
    pub fn remove_audio_source(
        &mut self,
        source_id: AudioSourceId,
    ) -> anyhow::Result<AudioSourceId> {
        // we check whether the source exists
        let library = &mut self.asset_library;

        if library.source_map.remove(source_id).is_none() {
            return Err(anyhow!("Source does not exist"));
        }

        // cascade delete
        let clips_pool = &mut self.clips_pool;
        for track in self.tracks.values_mut() {
            track.remove_clip_by_source_id(clips_pool, source_id.to_u64(), false);
        }

        Ok(source_id)
    }

    /// reset current application state to default
    pub fn new_blank_project(&mut self) {
        let current_audio_config = self.audio_config.clone();
        let current_clipboard = self.clipboard.clone();

        *self = ApplicationState::default();

        self.audio_config = current_audio_config;
        self.clipboard = current_clipboard;
    }
}

#[cfg(test)]
mod slotmap_persistence_tests {
    use super::*;
    use crate::core::project::{
        AutomationLane, AutomationPoint, Clip, PluginInstance, RoutingNode,
    };
    use karbeat_utils::types::NormalizedF64;

    #[test]
    fn entity_and_graph_keys_survive_project_serialization() {
        let mut state = ApplicationState::default();
        let track = state.add_new_audio_track();
        let bus_id = state.mixer.create_bus("Reverb".into());

        let pattern_id = state.pattern_pool.insert_with_key(|id| Pattern {
            id,
            name: "Persistent pattern".into(),
            ..Pattern::default()
        });
        let note = state.pattern_pool[pattern_id]
            .add_note(60, 0, Some(960))
            .expect("valid note");

        let automation_id = state
            .automation_pool
            .insert_with_key(|id| AutomationLane::new(id, "Volume", 0.0, 1.0, 0.5));
        let point_id = state.automation_pool[automation_id]
            .add_point(AutomationPoint::new(480, NormalizedF64::new(0.75)));

        let generator_id = state.add_generator(Default::default());
        let modulation_id = state.add_modulation_source(ModulationSource::LFO { rate_hz: 1.0 });

        let clip_id = state.clips_pool.insert_with_key(|id| Clip {
            id,
            source: Some(DawSource::Midi(pattern_id)),
            ..Clip::default()
        });
        state.tracks[track.id].clips.push(clip_id);

        let effect_id = state
            .mixer
            .master_bus
            .effects
            .insert(PluginInstance::default());

        let track_node_id = track.graph_node_id;
        let bus_node_id = state.mixer.buses[bus_id].graph_node_id;
        let master_node_id = state.mixer.master_node_id;

        let bytes = rmp_serde::to_vec(&state).expect("serialize application state");
        let mut restored: ApplicationState =
            rmp_serde::from_slice(&bytes).expect("deserialize application state");

        assert_eq!(restored.tracks[track.id].id, track.id);
        assert_eq!(restored.pattern_pool[pattern_id].id, pattern_id);
        assert_eq!(restored.pattern_pool[pattern_id].notes[0].id, note.id);
        assert!(
            restored.pattern_pool[pattern_id]
                .notes
                .iter()
                .any(|n| n.id == note.id)
        );
        assert_eq!(restored.automation_pool[automation_id].id, automation_id);
        assert_eq!(
            restored.automation_pool[automation_id].points[0].id,
            point_id
        );
        assert_eq!(restored.generator_pool[generator_id].id, generator_id);
        assert!(restored.modulation_sources.contains_key(modulation_id));
        assert_eq!(restored.clips_pool[clip_id].id, clip_id);
        assert!(restored.mixer.master_bus.effects.get(effect_id).is_some());
        assert_eq!(
            restored.mixer.graph_node(track_node_id),
            Some(RoutingNode::Track(track.id))
        );
        assert_eq!(
            restored.mixer.graph_node(bus_node_id),
            Some(RoutingNode::Bus(bus_id))
        );
        assert_eq!(
            restored.mixer.graph_node(master_node_id),
            Some(RoutingNode::Master)
        );

        let next_note = restored.pattern_pool[pattern_id]
            .add_note(62, 960, Some(960))
            .expect("next note");
        let next_point = restored.automation_pool[automation_id]
            .add_point(AutomationPoint::new(960, NormalizedF64::new(0.25)));
        assert_ne!(next_note.id, note.id);
        assert_ne!(next_point, point_id);
    }

    #[test]
    fn reused_slots_receive_a_new_generation() {
        let mut state = ApplicationState::default();
        let old_id = state.add_new_audio_track().id;
        state.remove_track(old_id).expect("remove track");
        let new_id = state.add_new_audio_track().id;

        assert_eq!(old_id.to_u32(), new_id.to_u32());
        assert_ne!(old_id.to_u64(), new_id.to_u64());
        assert!(!state.tracks.contains_key(old_id));
        assert!(state.tracks.contains_key(new_id));
    }
}
