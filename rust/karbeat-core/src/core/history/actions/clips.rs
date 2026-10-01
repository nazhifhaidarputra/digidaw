use std::{collections::HashSet, sync::Arc};

use super::{pools::PoolSwap, swap_slot};
use crate::core::{
    history::{EngineSync, HistoryAction, HistoryError},
    project::{ApplicationState, AudioWaveform, Clip, MadeUnique, Pattern},
};
use crate::shared::id::{AudioSourceId, ClipId, PatternId, TrackId};

/// Clips created, deleted, moved, resized, or renamed on one or more tracks.
///
/// Holds, for the other side of the edit, each touched clip (`None` where the clip does not
/// exist) and each touched track's clip list. Undo and redo swap both with the project. Deleted
/// clips are detached from the clip pool, so they are neither rendered nor saved while deleted
/// and come back under the same key.
#[derive(Debug)]
pub struct ClipsChanged {
    label: &'static str,
    clips: Box<[(ClipId, Option<Clip>)]>,
    track_lists: Box<[(TrackId, Vec<ClipId>)]>,
}

impl ClipsChanged {
    fn swap(&mut self, app: &mut ApplicationState) -> Result<EngineSync, HistoryError> {
        for (id, other) in &mut self.clips {
            swap_slot(&mut app.clips_pool, *id, other, "Clip")?;
        }
        for (track_id, list) in &mut self.track_lists {
            let track = app
                .tracks
                .get_mut(*track_id)
                .ok_or(HistoryError::missing("Track"))?;
            std::mem::swap(&mut track.clips, list);
        }
        Ok(EngineSync::track_graph())
    }
}

impl HistoryAction for ClipsChanged {
    fn undo(&mut self, app: &mut ApplicationState) -> Result<EngineSync, HistoryError> {
        self.swap(app)
    }

    fn redo(&mut self, app: &mut ApplicationState) -> Result<EngineSync, HistoryError> {
        self.swap(app)
    }

    fn label(&self) -> &'static str {
        self.label
    }
}

/// Clips given their own copies of the patterns and audio sources they shared (hard copies).
///
/// Holds the clip changes plus the created pattern and source keys. Undo detaches the copies and
/// points the clips back at the shared content; redo reattaches them under the same keys.
#[derive(Debug)]
pub struct ClipsMadeUnique {
    clips: ClipsChanged,
    patterns: PoolSwap<PatternId, Pattern>,
    sources: PoolSwap<AudioSourceId, Arc<AudioWaveform>>,
}

impl ClipsMadeUnique {
    /// Records the edit from the clip changes and the content it created.
    pub fn new(clips: ClipsChanged, made: &MadeUnique) -> Self {
        Self {
            clips,
            patterns: PoolSwap::from_entries(made.patterns.iter().map(|id| (*id, None)).collect()),
            sources: PoolSwap::from_entries(made.sources.iter().map(|id| (*id, None)).collect()),
        }
    }

    fn swap(&mut self, app: &mut ApplicationState) -> Result<EngineSync, HistoryError> {
        let mut sync = self.clips.swap(app)?;
        self.patterns.swap(&mut app.pattern_pool, "Pattern")?;
        self.sources
            .swap(&mut app.asset_library.source_map, "Audio source")?;
        if !self.sources.is_empty() {
            // New audio sources only reach the engine with a full graph.
            sync.merge(EngineSync::full_graph());
        }
        Ok(sync)
    }
}

swap_action!(ClipsMadeUnique, "Make Clips Unique");

/// An audio source deleted together with the clips that played it.
///
/// Holds the clip changes and the detached waveform. Undo reattaches the source and its clips
/// under the same keys; redo detaches them again.
#[derive(Debug)]
pub struct AudioSourceRemoved {
    clips: ClipsChanged,
    source: PoolSwap<AudioSourceId, Arc<AudioWaveform>>,
}

impl AudioSourceRemoved {
    /// Records the deletion from the clip changes and the waveform the project detached.
    pub fn new(
        clips: ClipsChanged,
        source_id: AudioSourceId,
        waveform: Arc<AudioWaveform>,
    ) -> Self {
        Self {
            clips,
            source: PoolSwap::from_entries(vec![(source_id, Some(waveform))]),
        }
    }

    fn swap(&mut self, app: &mut ApplicationState) -> Result<EngineSync, HistoryError> {
        // The source goes first on undo so its clips never point at a missing waveform; the
        // order does not matter on redo because both end up detached.
        self.source
            .swap(&mut app.asset_library.source_map, "Audio source")?;
        let mut sync = self.clips.swap(app)?;
        // Added and removed audio sources only reach the engine with a full graph.
        sync.merge(EngineSync::full_graph());
        Ok(sync)
    }
}

swap_action!(AudioSourceRemoved, "Delete Audio Source");

/// Captures the tracks and clips a clip edit is about to touch, then builds the
/// [`ClipsChanged`] record once the edit has run.
///
/// ```ignore
/// let recorder = ClipEditRecorder::begin(app, "Move Clips", &[from, to], &clip_ids);
/// app.move_clip_batch(...)?;
/// ctx.push_history(recorder.finish(app));
/// ```
#[derive(Debug)]
pub struct ClipEditRecorder {
    label: &'static str,
    track_lists: Vec<(TrackId, Vec<ClipId>)>,
    before: Vec<(ClipId, Clip)>,
}

impl ClipEditRecorder {
    /// Snapshots the clip lists of `tracks` and the current values of `clips`.
    ///
    /// Every track whose clip list the edit changes must be listed. `clips` are the existing
    /// clips the edit changes or deletes; clips it creates are found automatically.
    pub fn begin(
        app: &ApplicationState,
        label: &'static str,
        tracks: &[TrackId],
        clips: &[ClipId],
    ) -> Self {
        let mut track_lists: Vec<(TrackId, Vec<ClipId>)> = Vec::with_capacity(tracks.len());
        for track_id in tracks {
            if track_lists.iter().any(|(id, _)| id == track_id) {
                continue;
            }
            if let Some(track) = app.tracks.get(*track_id) {
                track_lists.push((*track_id, track.clips.clone()));
            }
        }
        let before = clips
            .iter()
            .filter_map(|id| app.clips_pool.get(*id).map(|clip| (*id, clip.clone())))
            .collect();
        Self {
            label,
            track_lists,
            before,
        }
    }

    /// Builds the record after the edit ran.
    ///
    /// Clips that were listed on a touched track and no longer are on any touched track are
    /// detached from the pool: the edit deleted them.
    pub fn finish(self, app: &mut ApplicationState) -> ClipsChanged {
        let listed_before: HashSet<ClipId> = self
            .track_lists
            .iter()
            .flat_map(|(_, list)| list.iter().copied())
            .collect();
        let listed_after: HashSet<ClipId> = self
            .track_lists
            .iter()
            .filter_map(|(track_id, _)| app.tracks.get(*track_id))
            .flat_map(|track| track.clips.iter().copied())
            .collect();

        let mut clips: Vec<(ClipId, Option<Clip>)> = Vec::new();
        for (id, clip) in self.before {
            if listed_before.contains(&id) && !listed_after.contains(&id) {
                app.clips_pool.detach(id);
            }
            clips.push((id, Some(clip)));
        }
        for id in listed_after.difference(&listed_before) {
            if !clips.iter().any(|(existing, _)| existing == id) {
                clips.push((*id, None));
            }
        }

        ClipsChanged {
            label: self.label,
            clips: clips.into_boxed_slice(),
            track_lists: self.track_lists.into_boxed_slice(),
        }
    }
}

#[cfg(test)]
#[allow(
    clippy::expect_used,
    reason = "clip history tests fail immediately when fixtures cannot be built"
)]
mod tests {
    use super::*;
    use crate::core::project::clip::ClipSourceType;

    fn state(app: &ApplicationState, track: TrackId) -> Vec<(ClipId, u64, String)> {
        app.tracks[track]
            .clips
            .iter()
            .map(|id| {
                let clip = &app.clips_pool[*id];
                (*id, clip.time.start_time_raw(), clip.name.clone())
            })
            .collect()
    }

    #[test]
    fn deleted_clips_leave_the_pool_and_return_with_the_same_key() {
        let mut app = ApplicationState::default();
        let midi = app
            .add_new_midi_track_with_generator_id(
                &mut karbeat_plugins::registry::PluginRegistry::new_with_defaults(),
                karbeat_utils::hash::hash_str("synth_karbeatzer_v2"),
            )
            .expect("midi track")
            .0
            .id;
        let clip = app
            .create_new_clip(None, ClipSourceType::Midi, midi, 0)
            .expect("clip");
        let original = state(&app, midi);

        let recorder = ClipEditRecorder::begin(&app, "Delete Clip", &[midi], &[clip.id]);
        app.delete_clip_from_track(midi, clip.id).expect("delete");
        let mut action = recorder.finish(&mut app);
        assert!(!app.clips_pool.contains_key(clip.id));

        for _ in 0..2 {
            assert_eq!(
                action.undo(&mut app).expect("undo"),
                EngineSync::track_graph()
            );
            assert_eq!(state(&app, midi), original);
            assert_eq!(
                action.redo(&mut app).expect("redo"),
                EngineSync::track_graph()
            );
            assert!(state(&app, midi).is_empty());
            assert!(!app.clips_pool.contains_key(clip.id));
        }
    }

    #[test]
    fn created_and_moved_clips_round_trip() {
        let mut app = ApplicationState::default();
        let midi = app
            .add_new_midi_track_with_generator_id(
                &mut karbeat_plugins::registry::PluginRegistry::new_with_defaults(),
                karbeat_utils::hash::hash_str("synth_karbeatzer_v2"),
            )
            .expect("midi track")
            .0
            .id;
        let existing = app
            .create_new_clip(None, ClipSourceType::Midi, midi, 0)
            .expect("clip");
        let before = state(&app, midi);

        let recorder = ClipEditRecorder::begin(&app, "Edit Clips", &[midi], &[existing.id]);
        app.move_clip(midi, midi, existing.id, 1920).expect("move");
        let created = app
            .create_new_clip(None, ClipSourceType::Midi, midi, 3840)
            .expect("new clip");
        let mut action = recorder.finish(&mut app);
        let after = state(&app, midi);

        assert_eq!(
            action.undo(&mut app).expect("undo"),
            EngineSync::track_graph()
        );
        assert_eq!(state(&app, midi), before);
        assert!(!app.clips_pool.contains_key(created.id));
        assert_eq!(
            action.redo(&mut app).expect("redo"),
            EngineSync::track_graph()
        );
        assert_eq!(state(&app, midi), after);
    }
}
