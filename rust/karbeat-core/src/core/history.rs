use crate::{
    core::project::{ApplicationState, Clip, ClipId, Note, NoteId, TrackId},
    shared::id::*,
};
use thiserror::Error;

pub const DEFAULT_HISTORY_LIMIT: usize = 100;
pub const MAX_HISTORY_LIMIT: usize = 1000;

#[derive(Debug, Error, PartialEq, Eq)]
pub enum HistoryLimitError {
    #[error("History limit {requested} exceeds the maximum of {maximum}")]
    TooLarge { requested: usize, maximum: usize },
}

/// Every action to the projects that are stored in history
#[derive(Debug, Clone)]
pub enum ProjectAction {
    AddNote {
        pattern_id: PatternId,
        note: Note,
    },
    DeleteNote {
        pattern_id: PatternId,
        note: Note,
    },
    MoveNote {
        pattern_id: PatternId,
        note_id: NoteId,
        old_tick: u64,
        old_key: u8,
        new_tick: u64,
        new_key: u8,
    },
    ResizeNote {
        pattern_id: PatternId,
        note_id: NoteId,
        old_duration: u64,
        new_duration: u64,
    },
    AddClip {
        track_id: TrackId,
        clip: Clip,
    },
    DeleteClip {
        track_id: TrackId,
        clip: Clip, // Store full clip data to enable undo
    },
    MoveClip {
        old_track_id: TrackId,
        new_track_id: TrackId,
        clip_id: ClipId,
        old_start_time: u64,
        new_start_time: u64,
    },
    ResizeClip {
        track_id: TrackId,
        old_clip: Clip, // Store full clip state before resize
        new_clip: Clip, // Store full clip state after resize
    },
    /// Groups multiple actions into one Undo/Redo step (e.g. Paste)
    Batch(Vec<ProjectAction>),
    // TODO: Add history for creating or removing track
    // TODO: Add history for adding automation
}

#[derive(Clone, Default)]
pub struct HistoryManager {
    pub undo_stack: Vec<ProjectAction>,
    pub redo_stack: Vec<ProjectAction>,
    pub max_history: usize,
}

impl HistoryManager {
    pub fn new() -> Self {
        Self {
            undo_stack: Vec::with_capacity(DEFAULT_HISTORY_LIMIT),
            redo_stack: Vec::with_capacity(DEFAULT_HISTORY_LIMIT),
            max_history: DEFAULT_HISTORY_LIMIT,
        }
    }

    pub fn set_max_history(&mut self, limit: usize) -> Result<(), HistoryLimitError> {
        if limit > MAX_HISTORY_LIMIT {
            return Err(HistoryLimitError::TooLarge {
                requested: limit,
                maximum: MAX_HISTORY_LIMIT,
            });
        }

        self.max_history = limit;
        Self::trim_oldest(&mut self.undo_stack, limit);
        Self::trim_oldest(&mut self.redo_stack, limit);
        Ok(())
    }

    fn trim_oldest(stack: &mut Vec<ProjectAction>, limit: usize) {
        let remove_count = stack.len().saturating_sub(limit);
        if remove_count > 0 {
            stack.drain(..remove_count);
        }
    }

    pub fn push(&mut self, action: ProjectAction) {
        self.undo_stack.push(action);
        self.redo_stack.clear();

        Self::trim_oldest(&mut self.undo_stack, self.max_history);
    }

    pub fn undo(&mut self, app: &mut ApplicationState) -> Result<(), String> {
        let action = self.undo_stack.pop().ok_or("Nothing to undo")?;
        self.apply_inverse(&action, app)?;
        self.redo_stack.push(action);
        Ok(())
    }

    pub fn redo(&mut self, app: &mut ApplicationState) -> Result<(), String> {
        let action = self.redo_stack.pop().ok_or("Nothing to redo")?;
        self.apply_forward(&action, app)?;
        self.undo_stack.push(action);
        Ok(())
    }

    fn apply_inverse(
        &self,
        action: &ProjectAction,
        app: &mut ApplicationState,
    ) -> Result<(), String> {
        match action {
            ProjectAction::AddNote { pattern_id, note } => {
                // Inverse: Delete the note
                let pattern = app
                    .pattern_pool
                    .get_mut(*pattern_id)
                    .ok_or("Pattern not found")?;
                let p = pattern;
                let index = p
                    .notes
                    .iter()
                    .position(|n| n.id == note.id)
                    .ok_or("Note not found")?;

                p.delete_note(index).map_err(|e| e.to_string())?;
            }
            ProjectAction::DeleteNote { pattern_id, note } => {
                // Inverse: Add the note back
                let pattern = app
                    .pattern_pool
                    .get_mut(*pattern_id)
                    .ok_or("Pattern not found")?;
                let p = pattern;
                p.restore_note(note.clone()).map_err(|e| e.to_string())?;
            }
            ProjectAction::MoveNote {
                pattern_id,
                note_id,
                old_tick,
                old_key,
                ..
            } => {
                // Inverse: Move to old position
                let pattern = app
                    .pattern_pool
                    .get_mut(*pattern_id)
                    .ok_or("Pattern not found")?;
                let p = pattern;
                let index = p
                    .notes
                    .iter()
                    .position(|n| n.id == *note_id)
                    .ok_or("Note not found")?;
                p.move_note(index, *old_tick, *old_key)
                    .map_err(|e| e.to_string())?;
            }
            ProjectAction::ResizeNote {
                pattern_id,
                note_id,
                old_duration,
                ..
            } => {
                let pattern = app
                    .pattern_pool
                    .get_mut(*pattern_id)
                    .ok_or("Pattern not found")?;
                let p = pattern;
                let index = p
                    .notes
                    .iter()
                    .position(|n| n.id == *note_id)
                    .ok_or("Note not found")?;
                p.resize_note(index, *old_duration)
                    .map_err(|e| e.to_string())?;
            }
            ProjectAction::Batch(actions) => {
                // Inverse of Batch: Undo actions in REVERSE order
                for action in actions.iter().rev() {
                    self.apply_inverse(action, app)?;
                }
            }
            ProjectAction::AddClip { track_id, clip } => {
                // Inverse of AddClip: Delete the clip
                app.delete_clip_from_track(*track_id, clip.id)
                    .map_err(|e| e.to_string())?;
            }
            ProjectAction::DeleteClip { track_id, clip } => {
                // Inverse of DeleteClip: Restore the clip to the track
                app.add_clip_to_track(*track_id, clip.clone())
                    .map_err(|e| format!("{}", e))?;
            }
            ProjectAction::MoveClip {
                old_track_id,
                new_track_id,
                clip_id,
                old_start_time,
                ..
            } => {
                // Inverse: Move clip back to old_track_id with old_start_time
                app.move_clip(*new_track_id, *old_track_id, *clip_id, *old_start_time)
                    .map_err(|e| e.to_string())?;
            }
            ProjectAction::ResizeClip {
                track_id, old_clip, ..
            } => {
                app.add_clip_to_track(*track_id, old_clip.clone())
                    .map_err(|e| e.to_string())?;
            }
        }

        Ok(())
    }

    fn apply_forward(
        &self,
        action: &ProjectAction,
        app: &mut super::project::ApplicationState,
    ) -> Result<(), String> {
        match action {
            ProjectAction::AddNote { pattern_id, note } => {
                let pattern = app
                    .pattern_pool
                    .get_mut(*pattern_id)
                    .ok_or("Pattern not found")?;
                let p = pattern;
                p.restore_note(note.clone()).map_err(|e| e.to_string())?;
            }
            ProjectAction::DeleteNote { pattern_id, note } => {
                let pattern = app
                    .pattern_pool
                    .get_mut(*pattern_id)
                    .ok_or("Pattern not found")?;
                let p = pattern;
                let index = p
                    .notes
                    .iter()
                    .position(|n| n.id == note.id)
                    .ok_or("Note not found")?;
                p.delete_note(index).map_err(|e| e.to_string())?;
            }
            ProjectAction::MoveNote {
                pattern_id,
                note_id,
                new_tick,
                new_key,
                ..
            } => {
                let pattern = app
                    .pattern_pool
                    .get_mut(*pattern_id)
                    .ok_or("Pattern not found")?;
                let p = pattern;
                let index = p
                    .notes
                    .iter()
                    .position(|n| n.id == *note_id)
                    .ok_or("Note not found")?;
                p.move_note(index, *new_tick, *new_key)
                    .map_err(|e| e.to_string())?;
            }
            ProjectAction::ResizeNote {
                pattern_id,
                note_id,
                new_duration,
                ..
            } => {
                let pattern = app
                    .pattern_pool
                    .get_mut(*pattern_id)
                    .ok_or("Pattern not found")?;
                let p = pattern;
                let index = p
                    .notes
                    .iter()
                    .position(|n| n.id == *note_id)
                    .ok_or("Note not found")?;
                p.resize_note(index, *new_duration)
                    .map_err(|e| e.to_string())?;
            }
            ProjectAction::Batch(actions) => {
                // Forward of Batch: Apply actions in NORMAL order
                for action in actions.iter() {
                    self.apply_forward(action, app)?;
                }
            }
            ProjectAction::AddClip { track_id, clip } => {
                app.add_clip_to_track(*track_id, clip.clone())
                    .map_err(|e| e.to_string())?;
            }
            ProjectAction::DeleteClip { track_id, clip } => {
                // Forward: Delete the clip from the track
                app.delete_clip_from_track(*track_id, clip.id)
                    .map_err(|e| e.to_string())?;
            }
            ProjectAction::MoveClip {
                old_track_id,
                new_track_id,
                clip_id,
                new_start_time,
                ..
            } => {
                // Forward: Move clip from old_track_id to new_track_id with new_start_time
                app.move_clip(*old_track_id, *new_track_id, *clip_id, *new_start_time)
                    .map_err(|e| e.to_string())?;
            }
            ProjectAction::ResizeClip {
                track_id, new_clip, ..
            } => {
                app.add_clip_to_track(*track_id, new_clip.clone())
                    .map_err(|e| e.to_string())?;
            }
        }
        Ok(())
    }
}

#[cfg(test)]
#[allow(
    clippy::expect_used,
    reason = "history tests fail immediately when a deterministic state transition is rejected"
)]
mod history_limit_tests {
    use super::{HistoryManager, MAX_HISTORY_LIMIT, ProjectAction};

    fn action() -> ProjectAction {
        ProjectAction::Batch(Vec::new())
    }

    #[test]
    fn reducing_limit_trims_oldest_undo_and_redo_entries() {
        let mut history = HistoryManager::new();
        history.undo_stack = vec![action(), action(), action()];
        history.redo_stack = vec![action(), action()];

        history.set_max_history(1).expect("valid history limit");

        assert_eq!(history.undo_stack.len(), 1);
        assert_eq!(history.redo_stack.len(), 1);
        assert_eq!(history.max_history, 1);
    }

    #[test]
    fn zero_disables_and_clears_history() {
        let mut history = HistoryManager::new();
        history.push(action());

        history.set_max_history(0).expect("zero is supported");
        history.push(action());

        assert!(history.undo_stack.is_empty());
        assert!(history.redo_stack.is_empty());
    }

    #[test]
    fn rejects_limits_above_the_supported_maximum() {
        let mut history = HistoryManager::new();

        let result = history.set_max_history(MAX_HISTORY_LIMIT + 1);

        assert!(result.is_err());
        assert_eq!(history.max_history, 100);
    }
}
