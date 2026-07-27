//! Tests for `api::undo` and `api::redo` (api-level wrappers around HistoryManager)

#[cfg(test)]
mod tests {
    use crate::api::{self, clip_api, note_api};
    use crate::core::history::ProjectAction;
    use crate::test::helpers::{make_ctx, make_seeded_ctx};

    // ─── undo with empty history ─────────────────────────────────────────────

    #[test]
    fn undo_with_empty_history_returns_err() {
        let mut ctx = make_ctx();
        let result = api::undo(&mut ctx);
        assert!(result.is_err());
        let msg = result.unwrap_err();
        assert!(msg.contains("Nothing to undo"), "Got: {}", msg);
    }

    // ─── redo with empty redo stack ──────────────────────────────────────────

    #[test]
    fn redo_with_empty_redo_stack_returns_err() {
        let mut ctx = make_ctx();
        let result = api::redo(&mut ctx);
        assert!(result.is_err());
        let msg = result.unwrap_err();
        assert!(msg.contains("Nothing to redo"), "Got: {}", msg);
    }

    // ─── undo then redo note add ──────────────────────────────────────────────

    #[test]
    fn undo_then_redo_note_add() {
        let (mut ctx, _audio_id, _midi_id, pattern_id) = make_seeded_ctx();
        let before = ctx.app_state.pattern_pool[&pattern_id].notes.len();

        // Add a note
        let note =
            note_api::add_note(&mut ctx, pattern_id, 72, 50000, Some(480)).expect("add note");
        assert_eq!(
            ctx.app_state.pattern_pool[&pattern_id].notes.len(),
            before + 1
        );

        // Undo → note should be gone
        api::undo(&mut ctx).expect("undo should succeed");
        assert_eq!(
            ctx.app_state.pattern_pool[&pattern_id].notes.len(),
            before,
            "Undo should remove the added note"
        );

        // Redo → note should be back
        api::redo(&mut ctx).expect("redo should succeed");
        assert_eq!(
            ctx.app_state.pattern_pool[&pattern_id].notes.len(),
            before + 1,
            "Redo should restore the note"
        );
    }

    // ─── undo then redo clip move ─────────────────────────────────────────────

    #[test]
    fn undo_then_redo_clip_move() {
        let (mut ctx, _audio_id, midi_id, _pat_id) = make_seeded_ctx();
        let clip = ctx.app_state.tracks[&midi_id].clips[0].clone();
        let original_start = clip.time.start_time_raw();

        // Move clip to a different position
        clip_api::move_clip(&mut ctx, midi_id, midi_id, clip.id, 9600).expect("move clip");
        let moved_start = ctx.app_state.tracks[&midi_id]
            .clips
            .iter()
            .find(|c| c.id == clip.id)
            .map(|c| c.time.start_time_raw())
            .expect("clip should still exist");
        assert_eq!(moved_start, 9600);

        // Undo → clip should be at original position
        api::undo(&mut ctx).expect("undo move clip");
        let after_undo = ctx.app_state.tracks[&midi_id]
            .clips
            .iter()
            .find(|c| c.id == clip.id)
            .map(|c| c.time.start_time_raw())
            .expect("clip should still exist after undo");
        assert_eq!(
            after_undo, original_start,
            "Undo should restore original position"
        );

        // Redo → clip moved again
        api::redo(&mut ctx).expect("redo move clip");
        let after_redo = ctx.app_state.tracks[&midi_id]
            .clips
            .iter()
            .find(|c| c.id == clip.id)
            .map(|c| c.time.start_time_raw())
            .expect("clip should exist after redo");
        assert_eq!(after_redo, 9600, "Redo should re-apply the move");
    }

    // ─── batch undo reverses in reverse order ─────────────────────────────────

    #[test]
    fn batch_undo_reverses_actions_in_correct_order() {
        let (mut ctx, _audio_id, _midi_id, pattern_id) = make_seeded_ctx();

        // Add 3 notes at once using batch — produces a Batch history entry
        note_api::add_notes_batch(
            &mut ctx,
            pattern_id,
            vec![
                (60, 40000, Some(480)),
                (62, 41000, Some(480)),
                (64, 42000, Some(480)),
            ],
        )
        .expect("batch add");

        let before_undo = ctx.app_state.pattern_pool[&pattern_id].notes.len();
        assert!(before_undo >= 3, "Should have at least the 3 batch notes");

        // Undo the Batch action → all 3 notes should be removed
        api::undo(&mut ctx).expect("undo batch");
        let after_undo = ctx.app_state.pattern_pool[&pattern_id].notes.len();
        assert_eq!(
            after_undo,
            before_undo - 3,
            "All 3 batch notes should be undone"
        );
    }

    // ─── undo clears redo stack on new action ─────────────────────────────────

    #[test]
    fn new_action_after_undo_clears_redo_stack() {
        let (mut ctx, _audio_id, _midi_id, pattern_id) = make_seeded_ctx();

        // Add and undo a note
        note_api::add_note(&mut ctx, pattern_id, 60, 50000, Some(480)).unwrap();
        api::undo(&mut ctx).unwrap();
        assert!(
            !ctx.history.redo_stack.is_empty(),
            "Redo stack should be non-empty after undo"
        );

        // Add another note → redo stack should be cleared
        note_api::add_note(&mut ctx, pattern_id, 62, 51000, Some(480)).unwrap();
        assert!(
            ctx.history.redo_stack.is_empty(),
            "New action should clear the redo stack"
        );
    }
}
