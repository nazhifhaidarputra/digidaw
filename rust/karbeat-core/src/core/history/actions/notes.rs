use crate::core::{
    history::{EngineSync, HistoryAction, HistoryError},
    project::{ApplicationState, Note, NoteId, Pattern},
};
use crate::shared::id::PatternId;

fn pattern_mut(
    app: &mut ApplicationState,
    pattern_id: PatternId,
) -> Result<&mut Pattern, HistoryError> {
    app.pattern_pool
        .get_mut(pattern_id)
        .ok_or(HistoryError::missing("Pattern"))
}

fn note_mut(pattern: &mut Pattern, id: NoteId) -> Result<&mut Note, HistoryError> {
    pattern
        .notes
        .iter_mut()
        .find(|note| note.id == id)
        .ok_or(HistoryError::missing("Note"))
}

/// Notes added, removed, or rewritten in one pattern.
///
/// Each entry holds the note as it is on the other side of the edit; `None` means the note does
/// not exist there. Undo and redo swap every entry with the pattern.
#[derive(Debug)]
pub struct NotesChanged {
    label: &'static str,
    pattern_id: PatternId,
    notes: Box<[(NoteId, Option<Note>)]>,
}

impl NotesChanged {
    /// Records an edit from each touched note's state *before* the edit: `Some` for notes that
    /// existed (changed or deleted), `None` for notes the edit added.
    pub fn new(
        label: &'static str,
        pattern_id: PatternId,
        before: impl IntoIterator<Item = (NoteId, Option<Note>)>,
    ) -> Self {
        Self {
            label,
            pattern_id,
            notes: before.into_iter().collect(),
        }
    }

    /// Records notes the edit added.
    pub fn added<'a>(
        label: &'static str,
        pattern_id: PatternId,
        added: impl IntoIterator<Item = &'a Note>,
    ) -> Self {
        Self::new(
            label,
            pattern_id,
            added.into_iter().map(|note| (note.id, None)),
        )
    }

    /// Records notes the edit deleted, or rewrote from these previous states.
    pub fn replaced(
        label: &'static str,
        pattern_id: PatternId,
        before: impl IntoIterator<Item = Note>,
    ) -> Self {
        Self::new(
            label,
            pattern_id,
            before.into_iter().map(|note| (note.id, Some(note))),
        )
    }

    /// Whether the edit touched no notes.
    pub fn is_empty(&self) -> bool {
        self.notes.is_empty()
    }

    fn swap(&mut self, app: &mut ApplicationState) -> Result<EngineSync, HistoryError> {
        let pattern = pattern_mut(app, self.pattern_id)?;
        for (id, other) in &mut self.notes {
            let index = pattern.notes.iter().position(|note| note.id == *id);
            match (index, other.take()) {
                (Some(index), Some(note)) => {
                    let current = pattern
                        .notes
                        .get_mut(index)
                        .ok_or(HistoryError::missing("Note"))?;
                    *other = Some(std::mem::replace(current, note));
                }
                (Some(index), None) => *other = Some(pattern.notes.swap_remove(index)),
                (None, Some(note)) => pattern.notes.push(note),
                (None, None) => return Err(HistoryError::missing("Note")),
            }
        }
        pattern.sort_notes_unstable();
        Ok(EngineSync::track_graph())
    }
}

impl HistoryAction for NotesChanged {
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

/// Position of one moved note on the other side of the edit.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct NoteMove {
    /// Moved note.
    pub id: NoteId,
    /// Start tick on the other side of the edit.
    pub tick: u64,
    /// MIDI key on the other side of the edit.
    pub key: u8,
}

/// Notes moved in time or pitch. Stores only positions, not whole notes.
#[derive(Debug)]
pub struct NotesMoved {
    pattern_id: PatternId,
    moves: Box<[NoteMove]>,
}

impl NotesMoved {
    /// Records moves from each note's position *before* the edit.
    pub fn new(pattern_id: PatternId, before: impl IntoIterator<Item = NoteMove>) -> Self {
        Self {
            pattern_id,
            moves: before.into_iter().collect(),
        }
    }

    fn swap(&mut self, app: &mut ApplicationState) -> Result<EngineSync, HistoryError> {
        let pattern = pattern_mut(app, self.pattern_id)?;
        for moved in &mut self.moves {
            let note = note_mut(pattern, moved.id)?;
            std::mem::swap(&mut note.start_tick, &mut moved.tick);
            std::mem::swap(&mut note.key, &mut moved.key);
        }
        pattern.sort_notes_unstable();
        Ok(EngineSync::track_graph())
    }
}

impl HistoryAction for NotesMoved {
    fn undo(&mut self, app: &mut ApplicationState) -> Result<EngineSync, HistoryError> {
        self.swap(app)
    }

    fn redo(&mut self, app: &mut ApplicationState) -> Result<EngineSync, HistoryError> {
        self.swap(app)
    }

    fn label(&self) -> &'static str {
        "Move Notes"
    }
}

/// Notes resized. Stores only durations, not whole notes.
#[derive(Debug)]
pub struct NotesResized {
    pattern_id: PatternId,
    durations: Box<[(NoteId, u64)]>,
}

impl NotesResized {
    /// Records resizes from each note's duration *before* the edit.
    pub fn new(pattern_id: PatternId, before: impl IntoIterator<Item = (NoteId, u64)>) -> Self {
        Self {
            pattern_id,
            durations: before.into_iter().collect(),
        }
    }

    fn swap(&mut self, app: &mut ApplicationState) -> Result<EngineSync, HistoryError> {
        let pattern = pattern_mut(app, self.pattern_id)?;
        for (id, duration) in &mut self.durations {
            let note = note_mut(pattern, *id)?;
            std::mem::swap(&mut note.duration, duration);
        }
        pattern.sort_notes_unstable();
        Ok(EngineSync::track_graph())
    }
}

impl HistoryAction for NotesResized {
    fn undo(&mut self, app: &mut ApplicationState) -> Result<EngineSync, HistoryError> {
        self.swap(app)
    }

    fn redo(&mut self, app: &mut ApplicationState) -> Result<EngineSync, HistoryError> {
        self.swap(app)
    }

    fn label(&self) -> &'static str {
        "Resize Notes"
    }
}

#[cfg(test)]
#[allow(
    clippy::expect_used,
    reason = "note history tests fail immediately when fixtures cannot be built"
)]
mod tests {
    use super::*;

    fn app_with_pattern() -> (ApplicationState, PatternId) {
        let mut app = ApplicationState::default();
        let pattern_id = app.pattern_pool.insert_with_key(|id| Pattern {
            id,
            ..Pattern::default()
        });
        (app, pattern_id)
    }

    fn notes(app: &ApplicationState, pattern_id: PatternId) -> Vec<(u32, u64, u8, u64)> {
        app.pattern_pool[pattern_id]
            .notes
            .iter()
            .map(|n| (n.id.into(), n.start_tick, n.key, n.duration))
            .collect()
    }

    /// History cost per note. The previous `ProjectAction` enum spent at least 168 bytes per
    /// note in a batch, because every variant was as large as `ResizeClip` (a track ID plus two
    /// 80-byte clips): a 1,000-note paste kept ~168 KB, now ~48 KB, and a 1,000-note move ~24 KB.
    #[test]
    fn per_note_records_stay_compact() {
        assert!(std::mem::size_of::<(NoteId, Option<Note>)>() <= 48);
        assert!(std::mem::size_of::<NoteMove>() <= 24);
        assert!(std::mem::size_of::<(NoteId, u64)>() <= 16);
    }

    #[test]
    fn added_deleted_and_rewritten_notes_round_trip() {
        let (mut app, pattern_id) = app_with_pattern();
        let first = app
            .add_note_to_pattern(pattern_id, 60, 0, Some(480))
            .expect("first note");
        let second = app
            .add_note_to_pattern(pattern_id, 64, 480, Some(480))
            .expect("second note");
        let original = notes(&app, pattern_id);

        // One edit that rewrites the first note, deletes the second, and adds a third.
        let mut rewritten = first.clone();
        rewritten.velocity = 10;
        app.pattern_pool[pattern_id].notes[0] = rewritten;
        app.delete_note_from_pattern(pattern_id, second.id)
            .expect("delete");
        let added = app
            .add_note_to_pattern(pattern_id, 67, 960, Some(480))
            .expect("added note");
        let edited = notes(&app, pattern_id);
        let mut action = NotesChanged::new(
            "Edit Notes",
            pattern_id,
            [
                (first.id, Some(first)),
                (second.id, Some(second)),
                (added.id, None),
            ],
        );

        for _ in 0..2 {
            assert_eq!(
                action.undo(&mut app).expect("undo"),
                EngineSync::track_graph()
            );
            assert_eq!(notes(&app, pattern_id), original);
            assert_eq!(
                action.redo(&mut app).expect("redo"),
                EngineSync::track_graph()
            );
            assert_eq!(notes(&app, pattern_id), edited);
        }
    }

    #[test]
    fn moves_and_resizes_round_trip() {
        let (mut app, pattern_id) = app_with_pattern();
        let note = app
            .add_note_to_pattern(pattern_id, 60, 0, Some(480))
            .expect("note");
        app.move_note_in_pattern(pattern_id, note.id, 960, 62)
            .expect("move");
        app.resize_note_in_pattern(pattern_id, note.id, 240)
            .expect("resize");
        let mut moved = NotesMoved::new(
            pattern_id,
            [NoteMove {
                id: note.id,
                tick: 0,
                key: 60,
            }],
        );
        let mut resized = NotesResized::new(pattern_id, [(note.id, 480)]);

        assert_eq!(
            resized.undo(&mut app).expect("undo resize"),
            EngineSync::track_graph()
        );
        assert_eq!(
            moved.undo(&mut app).expect("undo move"),
            EngineSync::track_graph()
        );
        assert_eq!(notes(&app, pattern_id), vec![(note.id.into(), 0, 60, 480)]);

        assert_eq!(
            moved.redo(&mut app).expect("redo move"),
            EngineSync::track_graph()
        );
        assert_eq!(
            resized.redo(&mut app).expect("redo resize"),
            EngineSync::track_graph()
        );
        assert_eq!(
            notes(&app, pattern_id),
            vec![(note.id.into(), 960, 62, 240)]
        );
    }
}
