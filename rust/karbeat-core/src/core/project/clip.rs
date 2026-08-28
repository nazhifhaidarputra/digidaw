use std::{cmp::Ordering, collections::HashSet};

use anyhow::{Context, anyhow};
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum ResizeEdge {
    Left,
    Right,
}

use crate::core::project::ClipboardContent;
use crate::core::project::track::midi::Pattern;
use crate::core::project::{ApplicationState, DawSource, track::TrackType};
use crate::shared::id::{ClipId, TrackId};
use crate::shared::{AudioSourceId, PatternId};

pub enum ClipSourceType {
    Midi,
    Audio,
}

// ======================================
/// ClipTimeUnit
/// Encapsulates clip timeline positioning with explicit units.
/// Audio clips use raw samples (BPM-independent).
/// MIDI/Automation clips use ticks (960 PPQN, BPM-dependent).
// ======================================
#[derive(Serialize, Deserialize, Clone, Debug)]
pub enum ClipTimeUnit {
    /// Values in raw audio samples (BPM-independent)
    Samples {
        start_time: u64,
        loop_length: u64,
        offset_start: u64,
    },
    /// Values in ticks (960 PPQN, BPM-dependent)
    Ticks {
        start_time: u32,
        loop_length: u32,
        offset_start: u32,
    },
}

impl Default for ClipTimeUnit {
    fn default() -> Self {
        Self::Samples {
            start_time: 0,
            loop_length: 0,
            offset_start: 0,
        }
    }
}

impl ClipTimeUnit {
    /// Get the start time in samples, converting ticks if necessary
    pub fn start_time_samples(&self, bpm: f32, sample_rate: u32) -> u64 {
        match self {
            ClipTimeUnit::Samples { start_time, .. } => *start_time,
            ClipTimeUnit::Ticks { start_time, .. } => {
                let samples_per_tick = Self::samples_per_tick(bpm, sample_rate);
                ((*start_time as f64) * samples_per_tick) as u64
            }
        }
    }

    /// Get the loop length in samples, converting ticks if necessary
    pub fn loop_length_samples(&self, bpm: f32, sample_rate: u32) -> u64 {
        match self {
            ClipTimeUnit::Samples { loop_length, .. } => *loop_length,
            ClipTimeUnit::Ticks { loop_length, .. } => {
                let samples_per_tick = Self::samples_per_tick(bpm, sample_rate);
                ((*loop_length as f64) * samples_per_tick) as u64
            }
        }
    }

    /// Get the offset start in samples, converting ticks if necessary
    pub fn offset_start_samples(&self, bpm: f32, sample_rate: u32) -> u64 {
        match self {
            ClipTimeUnit::Samples { offset_start, .. } => *offset_start,
            ClipTimeUnit::Ticks { offset_start, .. } => {
                let samples_per_tick = Self::samples_per_tick(bpm, sample_rate);
                ((*offset_start as f64) * samples_per_tick) as u64
            }
        }
    }

    /// Get end position (start_time + loop_length) in samples
    pub fn end_samples(&self, bpm: f32, sample_rate: u32) -> u64 {
        self.start_time_samples(bpm, sample_rate) + self.loop_length_samples(bpm, sample_rate)
    }

    /// Get start_time in the native unit (u64 for either variant)
    pub fn start_time_raw(&self) -> u64 {
        match self {
            ClipTimeUnit::Samples { start_time, .. } => *start_time,
            ClipTimeUnit::Ticks { start_time, .. } => *start_time as u64,
        }
    }

    /// Get loop_length in the native unit (u64 for either variant)
    pub fn loop_length_raw(&self) -> u64 {
        match self {
            ClipTimeUnit::Samples { loop_length, .. } => *loop_length,
            ClipTimeUnit::Ticks { loop_length, .. } => *loop_length as u64,
        }
    }

    /// Get offset_start in the native unit (u64 for either variant)
    pub fn offset_start_raw(&self) -> u64 {
        match self {
            ClipTimeUnit::Samples { offset_start, .. } => *offset_start,
            ClipTimeUnit::Ticks { offset_start, .. } => *offset_start as u64,
        }
    }

    /// Returns true if this is SamplesBased
    pub fn is_samples(&self) -> bool {
        matches!(self, ClipTimeUnit::Samples { .. })
    }

    /// Helper: compute samples per tick from BPM and sample_rate
    pub fn samples_per_tick(bpm: f32, sample_rate: u32) -> f64 {
        let bpm = if bpm <= 0.0 { 120.0 } else { bpm };
        let samples_per_beat = (60.0 / (bpm as f64)) * (sample_rate as f64);
        samples_per_beat / 960.0
    }
}

/// Clip struct that holds data for clip in the timeline.
/// Positioning uses ClipTimeUnit to distinguish between sample-based (audio)
/// and tick-based (MIDI/automation) clips.
#[derive(Serialize, Deserialize, Clone, Debug, Default)]
#[serde(default)]
pub struct Clip {
    /// Clip name
    pub name: String,
    /// Clip ID
    pub id: ClipId,
    /// Source of the clip
    pub source: Option<DawSource>,
    /// Timeline position and length — explicit units via enum
    pub time: ClipTimeUnit,
}

fn clip_type_name(clip: &Clip) -> &'static str {
    match clip.source {
        Some(DawSource::Audio(_)) => "audio",
        Some(DawSource::Midi(_)) => "MIDI",
        Some(DawSource::Automation(_)) => "automation",
        None => "untyped",
    }
}

fn track_type_name(track_type: &TrackType) -> &'static str {
    match track_type {
        TrackType::Audio => "audio",
        TrackType::Midi => "MIDI",
        TrackType::Automation => "automation",
    }
}

impl PartialEq for Clip {
    fn eq(&self, other: &Self) -> bool {
        self.time.start_time_raw() == other.time.start_time_raw() && self.id == other.id
    }
}

impl Eq for Clip {}

impl PartialOrd for Clip {
    fn partial_cmp(&self, other: &Self) -> Option<Ordering> {
        // Primary ordering by start_time, then by id for tie-breaking
        match self.time.start_time_raw().cmp(&other.time.start_time_raw()) {
            Ordering::Equal => Some(self.id.cmp(&other.id)),
            ordering => Some(ordering),
        }
    }
}

impl Ord for Clip {
    fn cmp(&self, other: &Self) -> Ordering {
        self.partial_cmp(other).unwrap_or(Ordering::Equal)
    }
}

impl ApplicationState {
    pub fn add_clip_to_track(&mut self, track_id: TrackId, clip: Clip) -> anyhow::Result<()> {
        let track = self
            .tracks
            .get(track_id)
            .ok_or_else(|| anyhow::anyhow!("Track not found"))?;
        if !track.accepts_clip(&clip) {
            return Err(anyhow::anyhow!(
                "Warning: Mismatched Clip Source for Track Type"
            ));
        }

        let clip_id = if self.clips_pool.contains_key(clip.id) {
            let id = clip.id;
            self.clips_pool[id] = clip;
            id
        } else {
            self.clips_pool.insert_with_key(|id| Clip { id, ..clip })
        };
        let track = self
            .tracks
            .get_mut(track_id)
            .ok_or_else(|| anyhow::anyhow!("Track not found"))?;
        track.clips.retain(|id| *id != clip_id);
        track.add_clip(clip_id, &self.clips_pool)?;
        Ok(())
    }

    pub fn delete_clip_from_track(
        &mut self,
        track_id: TrackId,
        clip_id: ClipId,
    ) -> anyhow::Result<Clip> {
        let track = self
            .tracks
            .get_mut(track_id)
            .ok_or_else(|| anyhow::anyhow!("Track not found"))?;
        track.remove_clip(&clip_id)?;
        self.clips_pool
            .get(clip_id)
            .cloned()
            .ok_or_else(|| anyhow::anyhow!("Clip not found in global pool"))
    }

    /// Get a clip from a track by its ID.
    /// Returns an owned clone of the Clip if found.
    pub fn get_clip(&self, track_id: &TrackId, clip_id: &ClipId) -> Option<Clip> {
        self.tracks
            .get(*track_id)
            .and_then(|track| track.get_clip(&self.clips_pool, clip_id))
    }

    /// Move a clip from one track to another (or within the same track) with a new start time.
    /// The new_start_time is in the clip's native unit (samples for audio, ticks for MIDI).
    /// Returns an error if the track or clip is not found, or if types are incompatible.
    pub fn move_clip(
        &mut self,
        source_track_id: TrackId,
        target_track_id: TrackId,
        clip_id: ClipId,
        new_start_time: u64,
    ) -> anyhow::Result<Clip> {
        let clip = self
            .clips_pool
            .get(clip_id)
            .with_context(|| "Clip not found in global pool")?;
        let target = self
            .tracks
            .get(target_track_id)
            .with_context(|| "Track not found")?;
        if !target.accepts_clip(clip) {
            return Err(anyhow::anyhow!(
                "Cannot move {} clip to {} track",
                clip_type_name(clip),
                track_type_name(&target.track_type)
            ));
        }

        self.tracks
            .get_mut(source_track_id)
            .with_context(|| "Track not found")?
            .remove_clip(&clip_id)?;

        let modified_clip = self
            .clips_pool
            .get_mut(clip_id)
            .with_context(|| "Clip not found in global pool")?;
        match &mut modified_clip.time {
            ClipTimeUnit::Samples { start_time, .. } => {
                *start_time = new_start_time;
            }
            ClipTimeUnit::Ticks { start_time, .. } => {
                *start_time = new_start_time as u32;
            }
        }

        // Add the clip to the target track
        {
            let track = self
                .tracks
                .get_mut(target_track_id)
                .with_context(|| "Track not found")?;

            track
                .add_clip(clip_id, &self.clips_pool)
                .map_err(|e| anyhow::anyhow!("{}", e))?;
        }

        Ok(self.clips_pool[clip_id].clone())
    }

    /// Cut (Slice) a clip at a given point (in the clip's native time unit).
    /// Returns the two resulting clips.
    pub fn slice_clip(
        &mut self,
        track_id: &TrackId,
        clip_id: &ClipId,
        cut_point: u64,
    ) -> anyhow::Result<(Clip, Clip)> {
        let track = self
            .tracks
            .get_mut(*track_id)
            .with_context(|| "Track not found")?;
        if !track.clips.contains(clip_id) {
            return Err(anyhow::anyhow!("Clip not found in track"));
        }
        track.remove_clip(clip_id)?;

        let source = self
            .clips_pool
            .get(*clip_id)
            .cloned()
            .with_context(|| "Clip not found in global pool")?;
        let clip_start = source.time.start_time_raw();
        let clip_length = source.time.loop_length_raw();
        if cut_point <= clip_start || cut_point >= clip_start + clip_length {
            track.add_clip(*clip_id, &self.clips_pool)?;
            return Err(anyhow::anyhow!("Cannot cut clip outside its boundaries"));
        }

        let first_length = cut_point - clip_start;
        let second_length = clip_length - first_length;
        let second_offset = source.time.offset_start_raw() + first_length;
        let left = self.clips_pool.get_mut(*clip_id).unwrap();
        match &mut left.time {
            ClipTimeUnit::Samples { loop_length, .. } => *loop_length = first_length,
            ClipTimeUnit::Ticks { loop_length, .. } => *loop_length = first_length as u32,
        }
        let mut right = source;
        match &mut right.time {
            ClipTimeUnit::Samples {
                start_time,
                loop_length,
                offset_start,
            } => {
                *start_time = cut_point;
                *loop_length = second_length;
                *offset_start = second_offset;
            }
            ClipTimeUnit::Ticks {
                start_time,
                loop_length,
                offset_start,
            } => {
                *start_time = cut_point as u32;
                *loop_length = second_length as u32;
                *offset_start = second_offset as u32;
            }
        }
        let right_clip_id = self.clips_pool.insert_with_key(|id| Clip { id, ..right });
        track.add_clips_bulk(&[*clip_id, right_clip_id], &self.clips_pool);
        let first_clip = self.clips_pool[*clip_id].clone();
        let second_clip = self.clips_pool[right_clip_id].clone();

        Ok((first_clip, second_clip))
    }

    /// Resize a clip by updating its time fields.
    /// Supports both left (slip edit) and right edge resizing.
    /// - `edge`: Which edge is being dragged (Left or Right)
    /// - `new_time_val`: The new timeline position for the dragged edge (in native units)
    pub fn resize_clip(
        &mut self,
        track_id: TrackId,
        clip_id: ClipId,
        edge: ResizeEdge,
        new_time_val: u64,
    ) -> anyhow::Result<Clip> {
        let track = self
            .tracks
            .get_mut(track_id)
            .with_context(|| "Track not found")?;
        track.remove_clip(&clip_id)?;
        let modified_clip = self
            .clips_pool
            .get_mut(clip_id)
            .with_context(|| "Clip not found in global pool")?;
        let old_start = modified_clip.time.start_time_raw();
        let old_end = old_start + modified_clip.time.loop_length_raw();
        let old_offset = modified_clip.time.offset_start_raw();
        match edge {
            ResizeEdge::Right if new_time_val > old_start => match &mut modified_clip.time {
                ClipTimeUnit::Samples { loop_length, .. } => {
                    *loop_length = new_time_val - old_start
                }
                ClipTimeUnit::Ticks { loop_length, .. } => {
                    *loop_length = (new_time_val - old_start) as u32
                }
            },
            ResizeEdge::Left if new_time_val < old_end => {
                let new_offset = old_offset as i64 + new_time_val as i64 - old_start as i64;
                if new_offset >= 0 {
                    match &mut modified_clip.time {
                        ClipTimeUnit::Samples {
                            start_time,
                            loop_length,
                            offset_start,
                        } => {
                            *start_time = new_time_val;
                            *loop_length = old_end - new_time_val;
                            *offset_start = new_offset as u64;
                        }
                        ClipTimeUnit::Ticks {
                            start_time,
                            loop_length,
                            offset_start,
                        } => {
                            *start_time = new_time_val as u32;
                            *loop_length = (old_end - new_time_val) as u32;
                            *offset_start = new_offset as u32;
                        }
                    }
                }
            }
            _ => {}
        }
        track.add_clip(clip_id, &self.clips_pool)?;
        Ok(self.clips_pool[clip_id].clone())
    }

    /// Create a new clip and add it to the track.
    /// - `start_time`: Position on the timeline in ticks (from the UI).
    ///   For audio clips, this will be converted to samples at creation time.
    pub fn create_new_clip(
        &mut self,
        source_id: Option<u32>,
        source_type: ClipSourceType,
        track_id: TrackId,
        start_time: u32,
    ) -> anyhow::Result<Clip> {
        if !self.tracks.contains_key(track_id) {
            return Err(anyhow::anyhow!("Track not found"));
        }
        let clip = match source_type {
            ClipSourceType::Audio => {
                let source_id =
                    source_id.ok_or_else(|| anyhow::anyhow!("Audio clip needs source id"))?;
                let source_id = AudioSourceId::from(source_id);
                // check the source
                let audio_source = self
                    .asset_library
                    .source_map
                    .get(source_id)
                    .ok_or_else(|| {
                        anyhow::anyhow!("The audio source is not available in the library")
                    })?
                    .clone();

                let project_sample_rate = self.audio_config.sample_rate as f64;
                let source_sample_rate = audio_source.sample_rate as f64;
                let buffer_len = crate::utils::get_waveform_buffer(&audio_source.buffer)
                    .map(|b| b.len())
                    .unwrap_or(0);
                let source_frames = (buffer_len as u64) / (audio_source.channels as u64);

                // clip length in samples (resampled to project sample rate)
                let timeline_length_samples = if source_sample_rate > 0.0 {
                    ((source_frames as f64) * (project_sample_rate / source_sample_rate)) as u64
                } else {
                    source_frames // Fallback to avoid division by zero
                };

                // Convert the incoming start_time (ticks) to samples
                let bpm = if self.transport.bpm == 0.0 {
                    120.0
                } else {
                    self.transport.bpm
                };
                let samples_per_tick =
                    ClipTimeUnit::samples_per_tick(bpm, self.audio_config.sample_rate);
                let start_time_samples = ((start_time as f64) * samples_per_tick) as u64;

                let new_clip_id = self.clips_pool.insert_with_key(|id| Clip {
                    name: audio_source.name.clone(),
                    id,
                    source: Some(DawSource::Audio(source_id)),
                    time: ClipTimeUnit::Samples {
                        start_time: start_time_samples,
                        loop_length: timeline_length_samples,
                        offset_start: 0,
                    },
                });
                if let Err(error) = self
                    .tracks
                    .get_mut(track_id)
                    .with_context(|| "Track not found")?
                    .add_clip(new_clip_id, &self.clips_pool)
                {
                    self.clips_pool.remove(new_clip_id);
                    return Err(error);
                }
                self.clips_pool[new_clip_id].clone()
            }
            ClipSourceType::Midi => {
                // Use existing pattern if source_id provided, otherwise create new
                let (pattern_id, timeline_length) = if let Some(id) = source_id {
                    let pattern_id = PatternId::from(id);
                    let pattern = self
                        .pattern_pool
                        .get(pattern_id)
                        .ok_or_else(|| anyhow::anyhow!("Pattern {} not found", id))?;

                    // Length is in ticks
                    let length = pattern.length_ticks as u32;
                    (pattern_id, length)
                } else {
                    // Create new pattern
                    let default_ticks = 4 * 960;
                    let timeline_length = 4 * 960; // 4 beats
                    let new_pattern_id = self.pattern_pool.insert_with_key(|id| Pattern {
                        id,
                        name: format!("Pattern {}", id),
                        length_ticks: default_ticks,
                        notes: Vec::new(),
                        next_note_id: 0,
                    });
                    (new_pattern_id, timeline_length)
                };

                let pattern_name = self
                    .pattern_pool
                    .get(pattern_id)
                    .map(|p| p.name.clone())
                    .unwrap_or_else(|| format!("Pattern {}", pattern_id.to_u32()));

                let new_clip_id = self.clips_pool.insert_with_key(|id| Clip {
                    name: pattern_name,
                    id,
                    source: Some(DawSource::Midi(pattern_id)),
                    time: ClipTimeUnit::Ticks {
                        start_time,
                        loop_length: timeline_length,
                        offset_start: 0,
                    },
                });
                if let Err(error) = self
                    .tracks
                    .get_mut(track_id)
                    .with_context(|| "Track not found")?
                    .add_clip(new_clip_id, &self.clips_pool)
                {
                    self.clips_pool.remove(new_clip_id);
                    return Err(error);
                }
                self.clips_pool[new_clip_id].clone()
            }
        };

        Ok(clip)
    }

    /// Batch move clips by a delta (in native units).
    pub fn move_clip_batch(
        &mut self,
        source_track_id: TrackId,
        target_track_id: TrackId,
        clip_ids: Vec<ClipId>,
        delta: i64,
    ) -> Result<Vec<Clip>, String> {
        // Validate the complete operation before mutating anything. A batch is
        // atomic: incompatible or missing clips must fail instead of silently
        // returning a partial/empty success.
        let requested_ids: HashSet<_> = clip_ids.into_iter().collect();
        let ids_to_move = {
            let source_track = self
                .tracks
                .get(source_track_id)
                .ok_or("Source track not found")?;
            let target_track = self
                .tracks
                .get(target_track_id)
                .ok_or("Target track not found")?;

            for id in &requested_ids {
                if !source_track.clips.contains(id) {
                    return Err(format!("Clip {id:?} not found in source track"));
                }

                let clip = self
                    .clips_pool
                    .get(*id)
                    .ok_or_else(|| format!("Clip {id:?} not found in global pool"))?;
                if !target_track.accepts_clip(clip) {
                    return Err(format!(
                        "Cannot move {} clip to {} track",
                        clip_type_name(clip),
                        track_type_name(&target_track.track_type),
                    ));
                }
            }

            source_track
                .clips
                .iter()
                .filter(|id| requested_ids.contains(id))
                .copied()
                .collect::<Vec<_>>()
        };

        // 1. Extract clips from the source track safely
        {
            let source_track = self
                .tracks
                .get_mut(source_track_id)
                .ok_or("Source track not found")?;

            // Remove extracted clips in O(N) without multiple memory shifts
            source_track.clips.retain(|id| !ids_to_move.contains(id));
        }

        // 2. Modify clips
        for id in &ids_to_move {
            let clip = &mut self.clips_pool[*id];
            let old_start = clip.time.start_time_raw() as i64;
            let new_start = (old_start + delta).max(0) as u64;
            match &mut clip.time {
                ClipTimeUnit::Samples { start_time, .. } => *start_time = new_start,
                ClipTimeUnit::Ticks { start_time, .. } => *start_time = new_start as u32,
            }
        }

        // 3. Insert them all at once and sort ONLY ONCE
        let target_track = self
            .tracks
            .get_mut(target_track_id)
            .ok_or("Target track not found")?;

        target_track.add_clips_bulk(&ids_to_move, &self.clips_pool);

        Ok(ids_to_move
            .iter()
            .map(|id| self.clips_pool[*id].clone())
            .collect())
    }

    /// Batch resize clips by a delta (in native units).
    pub fn resize_clip_batch(
        &mut self,
        track_id: TrackId,
        clip_ids: Vec<ClipId>,
        edge: ResizeEdge,
        delta: i64,
    ) -> Result<Vec<Clip>, String> {
        let track = self.tracks.get_mut(track_id).ok_or("Track not found")?;
        let resize_ids: Vec<_> = track
            .clips
            .iter()
            .copied()
            .filter(|id| clip_ids.contains(id))
            .collect();
        track.clips.retain(|id| !resize_ids.contains(id));

        // 2. Modify them
        for id in &resize_ids {
            let modified_clip = &mut self.clips_pool[*id];
            let old_start = modified_clip.time.start_time_raw();
            let old_length = modified_clip.time.loop_length_raw();
            let old_end = old_start + old_length;
            let old_offset = modified_clip.time.offset_start_raw();

            match edge {
                ResizeEdge::Right => {
                    let new_end = ((old_end as i64) + delta).max((old_start as i64) + 10) as u64;
                    let new_length = new_end - old_start;
                    match &mut modified_clip.time {
                        ClipTimeUnit::Samples { loop_length, .. } => *loop_length = new_length,
                        ClipTimeUnit::Ticks { loop_length, .. } => *loop_length = new_length as u32,
                    }
                }
                ResizeEdge::Left => {
                    let new_start =
                        ((old_start as i64) + delta).clamp(0, (old_end as i64) - 10) as u64;
                    let d = (new_start as i64) - (old_start as i64);
                    let new_offset = ((old_offset as i64) + d).max(0) as u64;
                    let new_length = old_end - new_start;

                    match &mut modified_clip.time {
                        ClipTimeUnit::Samples {
                            start_time,
                            loop_length,
                            offset_start,
                        } => {
                            *start_time = new_start;
                            *loop_length = new_length;
                            *offset_start = new_offset;
                        }
                        ClipTimeUnit::Ticks {
                            start_time,
                            loop_length,
                            offset_start,
                        } => {
                            *start_time = new_start as u32;
                            *loop_length = new_length as u32;
                            *offset_start = new_offset as u32;
                        }
                    }
                }
            }
        }

        // 3. Bulk insert and single sort
        track.add_clips_bulk(&resize_ids, &self.clips_pool);

        Ok(resize_ids
            .iter()
            .map(|id| self.clips_pool[*id].clone())
            .collect())
    }

    /// Duplicate a selected clip group at every requested group start.
    ///
    /// Start positions use the selected clips' native timeline unit (samples
    /// for audio, ticks for MIDI/automation). The complete operation is
    /// validated and all clone templates are built before state is mutated, so
    /// callers never observe a partially-created draw gesture.
    pub fn duplicate_clip_groups(
        &mut self,
        track_id: TrackId,
        clip_ids: &[ClipId],
        group_start_times: &[u64],
    ) -> Result<Vec<Clip>, String> {
        if clip_ids.is_empty() || group_start_times.is_empty() {
            return Ok(Vec::new());
        }

        let requested_ids: HashSet<_> = clip_ids.iter().copied().collect();
        if requested_ids.len() != clip_ids.len() {
            return Err("Duplicate source clip IDs are not allowed".to_string());
        }

        let source_clips = {
            let track = self.tracks.get(track_id).ok_or("Track not found")?;

            for clip_id in &requested_ids {
                if !track.clips.contains(clip_id) {
                    return Err(format!("Clip {clip_id:?} not found in track"));
                }
                let clip = self
                    .clips_pool
                    .get(*clip_id)
                    .ok_or_else(|| format!("Clip {clip_id:?} not found in global pool"))?;
                if !track.accepts_clip(clip) {
                    return Err(format!("Clip {clip_id:?} is incompatible with track"));
                }
            }

            // Follow track order so relative offsets and returned clips are
            // deterministic regardless of the input ID order.
            track
                .clips
                .iter()
                .filter(|id| requested_ids.contains(id))
                .map(|id| self.clips_pool[*id].clone())
                .collect::<Vec<_>>()
        };

        let source_start = source_clips
            .iter()
            .map(|clip| clip.time.start_time_raw())
            .min()
            .ok_or("No source clips found")?;
        let source_is_samples = source_clips[0].time.is_samples();
        if source_clips
            .iter()
            .any(|clip| clip.time.is_samples() != source_is_samples)
        {
            return Err("Cannot duplicate clips with mixed timeline units".to_string());
        }

        let mut templates = Vec::with_capacity(source_clips.len() * group_start_times.len());
        for &group_start in group_start_times {
            for source in &source_clips {
                let relative_start = source
                    .time
                    .start_time_raw()
                    .checked_sub(source_start)
                    .ok_or("Invalid source clip start time")?;
                let new_start = group_start
                    .checked_add(relative_start)
                    .ok_or("Duplicated clip start time overflow")?;
                let mut template = source.clone();
                match &mut template.time {
                    ClipTimeUnit::Samples { start_time, .. } => *start_time = new_start,
                    ClipTimeUnit::Ticks { start_time, .. } => {
                        *start_time = u32::try_from(new_start)
                            .map_err(|_| "Duplicated clip tick exceeds u32 range")?;
                    }
                }
                templates.push(template);
            }
        }

        // No fallible work remains after this point.
        let mut new_ids = Vec::with_capacity(templates.len());
        let mut duplicated = Vec::with_capacity(templates.len());
        for template in templates {
            let id = self
                .clips_pool
                .insert_with_key(|id| Clip { id, ..template });
            new_ids.push(id);
            duplicated.push(self.clips_pool[id].clone());
        }

        self.tracks
            .get_mut(track_id)
            .expect("track was validated before mutation")
            .add_clips_bulk(&new_ids, &self.clips_pool);

        Ok(duplicated)
    }

    pub fn copy_clip_batch(
        &mut self,
        source_track_id: TrackId,
        clip_ids: &[ClipId],
    ) -> anyhow::Result<()> {
        let track_arc = self
            .tracks
            .get(source_track_id)
            .ok_or_else(|| anyhow!("Track not found"))?;

        let copied_clips: Vec<_> = track_arc
            .clips
            .iter()
            .filter(|id| clip_ids.contains(id))
            .filter_map(|id| self.clips_pool.get(*id).cloned())
            .collect();

        if copied_clips.is_empty() {
            self.clipboard = ClipboardContent::Empty;
        } else {
            self.clipboard = ClipboardContent::Clips(copied_clips);
        }

        Ok(())
    }

    pub fn paste_clip_batch(
        &mut self,
        target_track_id: TrackId,
        start_pos: ClipTimeUnit,
    ) -> anyhow::Result<Vec<Clip>> {
        let copied_clips = match &self.clipboard {
            ClipboardContent::Clips(clips) => clips.clone(),
            _ => return Err(anyhow::anyhow!("Clipboard does not contain clips")),
        };

        if copied_clips.is_empty() {
            return Err(anyhow::anyhow!("Clipboard is empty"));
        }

        let min_time_raw = copied_clips
            .iter()
            .map(|c| c.time.start_time_raw())
            .min()
            .unwrap_or(0);

        let target_time_raw = start_pos.start_time_raw();
        let delta = (target_time_raw as i64) - (min_time_raw as i64);

        let mut pasted_clips = Vec::with_capacity(copied_clips.len());

        let mut pasted_ids = Vec::with_capacity(copied_clips.len());
        for mut clip in copied_clips {
            let old_start = clip.time.start_time_raw() as i64;
            let new_start = (old_start + delta).max(0) as u64;

            match &mut clip.time {
                ClipTimeUnit::Samples { start_time, .. } => *start_time = new_start,
                ClipTimeUnit::Ticks { start_time, .. } => *start_time = new_start as u32,
            }

            let id = self.clips_pool.insert_with_key(|id| Clip { id, ..clip });
            pasted_clips.push(self.clips_pool[id].clone());
            pasted_ids.push(id);
        }

        let target_track = self
            .tracks
            .get_mut(target_track_id)
            .ok_or_else(|| anyhow!("Target track not found"))?;

        // Use optimized bulk insert
        target_track.add_clips_bulk(&pasted_ids, &self.clips_pool);

        Ok(pasted_clips)
    }

    pub fn cut_clipboard_clip_batch(
        &mut self,
        source_track_id: TrackId,
        clip_ids: &[ClipId],
    ) -> Vec<Clip> {
        let _ = self.copy_clip_batch(source_track_id, clip_ids);

        let mut deleted_clips = Vec::new();
        if let Some(track) = self.tracks.get_mut(source_track_id) {
            deleted_clips.extend(track.clips.iter().filter_map(|id| {
                clip_ids
                    .contains(id)
                    .then(|| self.clips_pool.get(*id).cloned())
                    .flatten()
            }));

            // Delete clips in a single O(N) pass
            track.clips.retain(|id| !clip_ids.contains(id));
        }

        deleted_clips
    }
}
