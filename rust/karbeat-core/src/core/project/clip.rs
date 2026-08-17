use std::cmp::Ordering;

use anyhow::{anyhow, Context};
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum ResizeEdge {
    Left,
    Right,
}

use crate::core::project::track::midi::Pattern;
use crate::core::project::ClipboardContent;
use crate::core::project::{track::TrackType, ApplicationState, DawSource};
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
        // Get the track
        match self.tracks.get_mut(&track_id) {
            Some(track) => {
                // Add Clip & Check bounds
                // We pass the Clip by value. The track takes ownership and wraps it in Arc.
                let _ = track.add_clip(clip)?;
            }
            _ => {
                return Err(anyhow::anyhow!("Track not found"));
            }
        }
        Ok(())
    }

    pub fn delete_clip_from_track(
        &mut self,
        track_id: TrackId,
        clip_id: ClipId,
    ) -> anyhow::Result<Clip> {
        let deleted_clip = (if let Some(track) = self.tracks.get_mut(&track_id) {
            match track.remove_clip(&clip_id) {
                Ok(clip) => Ok(clip),
                Err(e) => Err(e),
            }
        } else {
            Err(anyhow::anyhow!("Track not found"))
        })?;

        Ok(deleted_clip)
    }

    /// Get a clip from a track by its ID.
    /// Returns an owned clone of the Clip if found.
    pub fn get_clip(&self, track_id: &TrackId, clip_id: &ClipId) -> Option<Clip> {
        self.tracks
            .get(track_id)
            .and_then(|track| track.get_clip(clip_id))
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
        // First, extract the clip from the source track
        let clip = {
            let track = self
                .tracks
                .get_mut(&source_track_id)
                .with_context(|| "Track not found")?;

            let clip = track.remove_clip(&clip_id)?;

            clip.clone()
        };

        // Update the clip's start time (preserving the time unit variant)
        let mut modified_clip = clip;
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
                .get_mut(&target_track_id)
                .with_context(|| "Track not found")?;

            track
                .add_clip(modified_clip.clone())
                .map_err(|e| anyhow::anyhow!("{}", e))?;
        }

        Ok(modified_clip)
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
            .get_mut(track_id)
            .with_context(|| "Track not found")?;

        let (first_clip, second_clip) =
            track.slice_clip(clip_id, cut_point, &mut self.clip_counter)?;

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
            .get_mut(&track_id)
            .with_context(|| "Track not found")?;

        let modified_clip = track.resize_clip(clip_id, edge, new_time_val)?;
        Ok(modified_clip)
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
        let clip = match source_type {
            ClipSourceType::Audio => {
                let source_id =
                    source_id.ok_or_else(|| anyhow::anyhow!("Audio clip needs source id"))?;
                let source_id = AudioSourceId::from(source_id);
                // check the source
                let audio_source = self
                    .asset_library
                    .source_map
                    .get(&source_id)
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

                let new_clip_id = ClipId::next(&mut self.clip_counter);

                let clip = Clip {
                    name: audio_source.name.clone(),
                    id: new_clip_id,
                    source: Some(DawSource::Audio(source_id)),
                    time: ClipTimeUnit::Samples {
                        start_time: start_time_samples,
                        loop_length: timeline_length_samples,
                        offset_start: 0,
                    },
                };
                self.add_clip_to_track(track_id, clip.clone())?;

                clip
            }
            ClipSourceType::Midi => {
                // Use existing pattern if source_id provided, otherwise create new
                let (pattern_id, timeline_length) = if let Some(id) = source_id {
                    let pattern_id = PatternId::from(id);
                    let pattern = self
                        .pattern_pool
                        .get(&pattern_id)
                        .ok_or_else(|| anyhow::anyhow!("Pattern {} not found", id))?;

                    // Length is in ticks
                    let length = pattern.length_ticks as u32;
                    (pattern_id, length)
                } else {
                    // Create new pattern
                    let new_pattern_id = PatternId::next(&mut self.pattern_counter);
                    let default_ticks = 4 * 960;
                    let timeline_length = 4 * 960; // 4 beats

                    let pattern = Pattern {
                        id: new_pattern_id,
                        name: format!("Pattern {}", new_pattern_id.to_u32()),
                        length_ticks: default_ticks,
                        notes: Vec::new(),
                        next_note_id: 0,
                    };
                    self.pattern_pool.insert(new_pattern_id, pattern);
                    (new_pattern_id, timeline_length)
                };

                let pattern_name = self
                    .pattern_pool
                    .get(&pattern_id)
                    .map(|p| p.name.clone())
                    .unwrap_or_else(|| format!("Pattern {}", pattern_id.to_u32()));

                let new_clip_id = ClipId::next(&mut self.clip_counter);
                let clip = Clip {
                    name: pattern_name,
                    id: new_clip_id,
                    source: Some(DawSource::Midi(pattern_id)),
                    time: ClipTimeUnit::Ticks {
                        start_time,
                        loop_length: timeline_length,
                        offset_start: 0,
                    },
                };

                self.add_clip_to_track(track_id, clip.clone())?;
                clip
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
        let target_type = self
            .tracks
            .get(&target_track_id)
            .ok_or("Target track not found")?
            .track_type
            .clone();

        let mut clips_to_move = Vec::with_capacity(clip_ids.len());

        // 1. Extract clips from the source track safely
        {
            let source_track = self
                .tracks
                .get_mut(&source_track_id)
                .ok_or("Source track not found")?;

            for clip in source_track.clips.iter() {
                if clip_ids.contains(&clip.id) {
                    // Check compatibility if moving cross-track
                    if source_track_id != target_track_id {
                        let is_compatible = match (&target_type, &clip.source) {
                            (TrackType::Audio, Some(DawSource::Audio(_))) => true,
                            (TrackType::Midi, Some(DawSource::Midi(_))) => true,
                            (TrackType::Automation, Some(DawSource::Automation(_))) => true,
                            _ => false,
                        };
                        if !is_compatible {
                            continue; // Skip incompatible clips
                        }
                    }
                    clips_to_move.push(clip.clone());
                }
            }

            // Remove extracted clips in O(N) without multiple memory shifts
            let move_ids: Vec<_> = clips_to_move.iter().map(|c| c.id).collect();
            source_track.clips.retain(|c| !move_ids.contains(&c.id));
        }

        // 2. Modify clips
        for clip in &mut clips_to_move {
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
            .get_mut(&target_track_id)
            .ok_or("Target track not found")?;

        target_track.add_clips_bulk(&clips_to_move);

        Ok(clips_to_move)
    }

    /// Batch resize clips by a delta (in native units).
    pub fn resize_clip_batch(
        &mut self,
        track_id: TrackId,
        clip_ids: Vec<ClipId>,
        edge: ResizeEdge,
        delta: i64,
    ) -> Result<Vec<Clip>, String> {
        let track = self.tracks.get_mut(&track_id).ok_or("Track not found")?;

        // 1. Extract the clips
        let mut clips_to_resize = Vec::with_capacity(clip_ids.len());
        for clip in track.clips.iter() {
            if clip_ids.contains(&clip.id) {
                clips_to_resize.push(clip.clone());
            }
        }

        // Remove them in a single O(N) pass
        let resize_ids: Vec<_> = clips_to_resize.iter().map(|c| c.id).collect();
        track.clips.retain(|c| !resize_ids.contains(&c.id));

        // 2. Modify them
        for modified_clip in &mut clips_to_resize {
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
        track.add_clips_bulk(&clips_to_resize);

        Ok(clips_to_resize)
    }

    pub fn copy_clip_batch(
        &mut self,
        source_track_id: TrackId,
        clip_ids: &[ClipId],
    ) -> anyhow::Result<()> {
        let track_arc = self
            .tracks
            .get(&source_track_id)
            .ok_or_else(|| anyhow!("Track not found"))?;

        let copied_clips: Vec<_> = track_arc
            .clips
            .iter()
            .filter_map(|clip| {
                if clip_ids.contains(&clip.id) {
                    Some(clip.clone())
                } else {
                    None
                }
            })
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

        for mut clip in copied_clips {
            clip.id = ClipId::next(&mut self.clip_counter);

            let old_start = clip.time.start_time_raw() as i64;
            let new_start = (old_start + delta).max(0) as u64;

            match &mut clip.time {
                ClipTimeUnit::Samples { start_time, .. } => *start_time = new_start,
                ClipTimeUnit::Ticks { start_time, .. } => *start_time = new_start as u32,
            }

            pasted_clips.push(clip);
        }

        let target_track = self
            .tracks
            .get_mut(&target_track_id)
            .ok_or_else(|| anyhow!("Target track not found"))?;

        // Use optimized bulk insert
        target_track.add_clips_bulk(&pasted_clips);

        Ok(pasted_clips)
    }

    pub fn cut_clipboard_clip_batch(
        &mut self,
        source_track_id: TrackId,
        clip_ids: &[ClipId],
    ) -> Vec<Clip> {
        let _ = self.copy_clip_batch(source_track_id, clip_ids);

        let mut deleted_clips = Vec::new();
        if let Some(track) = self.tracks.get_mut(&source_track_id) {
            deleted_clips.extend(
                track
                    .clips
                    .iter()
                    .filter(|c| clip_ids.contains(&c.id))
                    .cloned(),
            );

            // Delete clips in a single O(N) pass
            track.clips.retain(|c| !clip_ids.contains(&c.id));
        }

        deleted_clips
    }
}
