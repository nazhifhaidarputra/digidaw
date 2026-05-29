use std::{ cmp::Ordering, sync::Arc };

use chrono::{ DateTime, Utc };
use hashbrown::HashMap;
use indexmap::IndexMap;

use anyhow::anyhow;
use serde::{ Deserialize, Serialize };

pub use super::clipboard::ClipboardContent;
pub use super::generator::{ GeneratorInstance };
pub use super::plugin::{ AudioPlugin };
pub use super::track::{ audio_waveform::AudioWaveform, midi::Pattern, AudioTrack };
pub use super::transport::TransportState;

use crate::core::project::plugin::modulation::ModulationEvent;
use crate::core::project::{
    automation::{ AutomationLane, AutomationPoint, AutomationTarget },
    mixer::MixerState,
};

pub use crate::shared::*;

#[derive(Serialize, Deserialize, Clone, Default, Debug, PartialEq)]
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
    pub asset_library: Arc<AssetLibrary>,

    // All musical data lives here. The timeline just references these.
    pub pattern_pool: IndexMap<PatternId, Arc<Pattern>>,
    pub pattern_counter: u32,

    // Generator sources
    pub generator_pool: IndexMap<GeneratorId, Arc<GeneratorInstance>>,
    pub generator_counter: u32,

    // Tracks contain Clips, but Clips are just "Containers"
    pub tracks: IndexMap<TrackId, Arc<AudioTrack>>,
    pub track_counter: u32,

    // Automation lanes pool (lives at the same level as tracks/patterns/generators)
    pub automation_pool: IndexMap<AutomationId, Arc<AutomationLane>>,
    pub automation_counter: u32,

    pub modulation_pool: HashMap<ModulationId, ModulationEvent>,
    pub modulation_counter: u32,

    // Counter for clips
    pub clip_counter: u32,

    // Max samples index in the timeline
    pub max_sample_index: u32,

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
    pub version: String,
    pub created_at: DateTime<Utc>,
}

impl Default for ProjectMetadata {
    fn default() -> Self {
        Self {
            name: "Untitled".to_string(),
            author: Default::default(),
            version: Default::default(),
            created_at: Utc::now(),
        }
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

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq)]
pub struct AssetLibrary {
    pub next_id: u32,
    pub source_map: HashMap<AudioSourceId, Arc<AudioWaveform>>,
}

impl Default for AssetLibrary {
    fn default() -> Self {
        Self {
            next_id: 1,
            source_map: HashMap::new(),
        }
    }
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
            buffer_size: 256,
            cpu_load: Default::default(),
        }
    }
}

impl ApplicationState {
    pub fn update_max_sample_index(&mut self) {
        // Grab the absolute time context
        let bpm = self.transport.bpm;
        let sample_rate = self.audio_config.sample_rate;
        self.max_sample_index = self.tracks
            .values_mut()
            .map(|t| {
                let track_mut = Arc::make_mut(t);
                track_mut.update_max_sample_index(bpm, sample_rate);
                track_mut.max_sample_index
            })
            .max()
            .unwrap_or(0);
    }

    /// Deletes an audio source and removes all clips referencing it.
    pub fn remove_audio_source(
        &mut self,
        source_id: AudioSourceId
    ) -> anyhow::Result<AudioSourceId> {
        // we check whether the source exists
        let library = Arc::make_mut(&mut self.asset_library);

        if library.source_map.remove(&source_id).is_none() {
            return Err(anyhow!("Source does not exist"));
        }

        // cascade delete
        for track_arc in self.tracks.values_mut() {
            let track = Arc::make_mut(track_arc);
            track.remove_clip_by_source_id(source_id, false);
        }

        self.update_max_sample_index();

        Ok(source_id)
    }

    /// reset current application state to default
    pub fn new_blank_project(&mut self) {
        *self = ApplicationState::default();
    }

    // =========================================================================
    // Automation Pool Management
    // =========================================================================

    /// Add an automation lane to the pool.
    pub fn add_automation_lane(
        &mut self,
        target: AutomationTarget,
        label: impl Into<String>,
        min: f32,
        max: f32,
        default_value: f32
    ) -> anyhow::Result<(AutomationId, ModulationId)> {
        if self.modulation_pool.values().any(|m| m.target() == &target) {
            return Err(anyhow!("A modulation mapping for this target already exists"));
        }

        let lane_id = AutomationId::next(&mut self.automation_counter);
        let lane = AutomationLane::new(lane_id, label, min, max, default_value);
        self.automation_pool.insert(lane_id, Arc::new(lane));

        let mod_id = ModulationId::next(&mut self.modulation_counter);
        let mod_event = ModulationEvent::Automation {
            lane_id,
            target,
        };
        self.modulation_pool.insert(mod_id, mod_event);

        log::info!("Added automation lane {:?} mapped via mod {:?}", lane_id, mod_id);
        Ok((lane_id, mod_id))
    }

    /// Add an automation lane specifically validated for a Track target.
    pub fn add_automation_lane_for_track(
        &mut self,
        track_id: TrackId,
        target: AutomationTarget,
        label: impl Into<String>,
        min: f32,
        max: f32,
        default_value: f32
    ) -> anyhow::Result<(AutomationId, ModulationId)> {
        if !target.references_track(track_id) {
            return Err(anyhow!("Target does not reference the specified track"));
        }
        self.add_automation_lane(target, label, min, max, default_value)
    }

    // Get all Modulations AND their associated Automation Lanes for a specific Track.
    pub fn get_automation_lanes_for_track(
        &self,
        track_id: TrackId
    ) -> Vec<(ModulationId, AutomationId, Arc<AutomationLane>)> {
        self.modulation_pool
            .iter()
            .filter_map(|(mod_id, m_event)| {
                if m_event.target().references_track(track_id) {
                    if let ModulationEvent::Automation { lane_id, .. } = m_event {
                        if let Some(lane) = self.automation_pool.get(lane_id) {
                            return Some((*mod_id, *lane_id, lane.clone()));
                        }
                    }
                }
                None
            })
            .collect()
    }

    /// Completely remove all Modulations and orphaned Automation Lanes for a Track.
    pub fn remove_modulations_for_track(&mut self, track_id: TrackId) {
        let mut orphaned_lanes = Vec::new();

        self.modulation_pool.retain(|_, m| {
            let references = m.target().references_track(track_id);
            if references {
                // If it's an automation routing, mark the pure data lane for deletion too
                if let ModulationEvent::Automation { lane_id, .. } = m {
                    orphaned_lanes.push(*lane_id);
                }
            }
            !references // Keep it if it DOES NOT reference the track
        });

        // Clean up the pure data lanes so we don't leak memory
        for lane_id in orphaned_lanes {
            self.automation_pool.shift_remove(&lane_id);
        }
    }

    /// Add a Host LFO to control a parameter
    pub fn add_lfo_modulation(
        &mut self,
        target: AutomationTarget,
        rate_hz: f32,
        depth: f32,
        base_value: f32
    ) -> anyhow::Result<ModulationId> {
        if self.modulation_pool.values().any(|m| m.target() == &target) {
            return Err(anyhow!("A modulation mapping for this target already exists"));
        }

        let mod_id = ModulationId::next(&mut self.modulation_counter);
        let mod_event = ModulationEvent::LFO {
            rate_hz,
            depth,
            base_value,
            target,
        };
        self.modulation_pool.insert(mod_id, mod_event);

        log::info!("Added LFO modulation {:?}", mod_id);
        Ok(mod_id)
    }

    /// Remove an automation lane from the pool by its ID.
    pub fn remove_automation_lane(&mut self, lane_id: AutomationId) -> anyhow::Result<()> {
        if self.automation_pool.shift_remove(&lane_id).is_none() {
            return Err(anyhow!("Automation lane {:?} not found", lane_id));
        }

        // Find and remove the modulation event that was routing this lane
        self.modulation_pool.retain(|_, m| {
            if let ModulationEvent::Automation { lane_id: linked_lane_id, .. } = m {
                *linked_lane_id != lane_id
            } else {
                true
            }
        });

        log::info!("Removed automation lane {:?}", lane_id);
        Ok(())
    }

    /// Get all modulations that reference a specific track.
    pub fn get_modulations_for_track(
        &self,
        track_id: TrackId
    ) -> Vec<(&ModulationId, &ModulationEvent)> {
        self.modulation_pool
            .iter()
            .filter(|(_, m)| m.target().references_track(track_id))
            .collect()
    }

    /// Add an automation lane specifically validated for a Bus target.
    pub fn add_automation_lane_for_bus(
        &mut self,
        bus_id: BusId,
        target: AutomationTarget,
        label: impl Into<String>,
        min: f32,
        max: f32,
        default_value: f32
    ) -> anyhow::Result<(AutomationId, ModulationId)> {
        if !target.references_bus(bus_id) {
            return Err(anyhow!("Target does not reference the specified bus"));
        }
        self.add_automation_lane(target, label, min, max, default_value)
    }

    /// Get all Modulations AND their associated Automation Lanes for a specific Bus.
    pub fn get_automation_lanes_for_bus(
        &self,
        bus_id: BusId
    ) -> Vec<(ModulationId, AutomationId, Arc<AutomationLane>)> {
        self.modulation_pool
            .iter()
            .filter_map(|(mod_id, m_event)| {
                if m_event.target().references_bus(bus_id) {
                    if let ModulationEvent::Automation { lane_id, .. } = m_event {
                        if let Some(lane) = self.automation_pool.get(lane_id) {
                            return Some((mod_id.to_owned(), lane_id.to_owned(), lane.clone()));
                        }
                    }
                }
                None
            })
            .collect()
    }

    /// Completely remove all Modulations and orphaned Automation Lanes for a Bus.
    pub fn remove_modulations_for_bus(&mut self, bus_id: BusId) {
        let mut orphaned_lanes = Vec::new();

        self.modulation_pool.retain(|_, m| {
            let references = m.target().references_bus(bus_id);
            if references {
                if let ModulationEvent::Automation { lane_id, .. } = m {
                    orphaned_lanes.push(*lane_id);
                }
            }
            !references
        });

        for lane_id in orphaned_lanes {
            self.automation_pool.shift_remove(&lane_id);
        }
    }

    /// Add an automation point to a lane.
    pub fn add_automation_point(
        &mut self,
        lane_id: AutomationId,
        time_ticks: u32,
        value: f32
    ) -> anyhow::Result<()> {
        let lane_arc = self.automation_pool
            .get_mut(&lane_id)
            .ok_or_else(|| anyhow!("Automation lane {:?} not found", lane_id))?;

        let lane = Arc::make_mut(lane_arc);
        let point = AutomationPoint::with_curve(
            time_ticks,
            value,
            super::AutomationCurveType::Linear,
            lane.min,
            lane.max
        );
        lane.add_point(point);
        Ok(())
    }

    /// Remove an automation point from a lane by its index.
    pub fn remove_automation_point(
        &mut self,
        lane_id: AutomationId,
        point_index: usize
    ) -> anyhow::Result<AutomationPoint> {
        let lane_arc = self.automation_pool
            .get_mut(&lane_id)
            .ok_or_else(|| anyhow!("Automation lane {:?} not found", lane_id))?;

        let lane = Arc::make_mut(lane_arc);
        lane.remove_point(point_index).ok_or_else(|| {
            anyhow!(
                "Point index {} out of bounds (lane has {} points)",
                point_index,
                lane.points.len()
            )
        })
    }

    /// Update an automation point (move in time and/or value).
    /// returns (old_index, new_index)
    pub fn update_automation_point(
        &mut self,
        lane_id: AutomationId,
        point_index: usize,
        time_ticks: u32,
        value: f32
    ) -> anyhow::Result<(usize, usize)> {
        let lane_arc = self.automation_pool
            .get_mut(&lane_id)
            .ok_or_else(|| anyhow!("Automation lane {:?} not found", lane_id))?;

        let lane = Arc::make_mut(lane_arc);
        match lane.update_point(point_index, time_ticks, value) {
            Some(new_index) => Ok((point_index, new_index)),
            None =>
                Err(
                    anyhow!(
                        "Point index {} out of bounds (lane has {} points)",
                        point_index,
                        lane.points.len()
                    )
                ),
        }
    }
}
