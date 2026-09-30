//! Tests for `api::undo` and `api::redo` (api-level wrappers around HistoryManager)

#[cfg(test)]
mod tests {
    use crate as api;
    use crate::{clip_api, note_api};

    use crate::test::helpers::{make_ctx, make_seeded_ctx};

    #[test]
    fn undo_with_empty_history_returns_err() {
        let mut ctx = make_ctx();
        let result = api::undo(&mut ctx);
        assert!(result.is_err());
        let msg = result.unwrap_err();
        assert!(msg.contains("Nothing to undo"), "Got: {}", msg);
    }

    #[test]
    fn redo_with_empty_redo_stack_returns_err() {
        let mut ctx = make_ctx();
        let result = api::redo(&mut ctx);
        assert!(result.is_err());
        let msg = result.unwrap_err();
        assert!(msg.contains("Nothing to redo"), "Got: {}", msg);
    }

    #[test]
    fn undo_then_redo_note_add() {
        let (mut ctx, _audio_id, _midi_id, pattern_id) = make_seeded_ctx();
        let before = ctx.app_state.pattern_pool[pattern_id].notes.len();

        // Add a note
        let note =
            note_api::add_note(&mut ctx, pattern_id, 72, 50000, Some(480)).expect("add note");
        assert_eq!(
            ctx.app_state.pattern_pool[pattern_id].notes.len(),
            before + 1
        );

        // Undo → note should be gone
        api::undo(&mut ctx).expect("undo should succeed");
        assert_eq!(
            ctx.app_state.pattern_pool[pattern_id].notes.len(),
            before,
            "Undo should remove the added note"
        );

        // Redo → note should be back
        api::redo(&mut ctx).expect("redo should succeed");
        assert_eq!(
            ctx.app_state.pattern_pool[pattern_id].notes.len(),
            before + 1,
            "Redo should restore the note"
        );
    }

    #[test]
    fn undo_then_redo_clip_move() {
        let (mut ctx, _audio_id, midi_id, _pat_id) = make_seeded_ctx();
        let clip_id = ctx.app_state.tracks[midi_id].clips[0];
        let clip = ctx.app_state.clips_pool[clip_id].clone();
        let original_start = clip.time.start_time_raw();

        // Move clip to a different position
        clip_api::move_clip(&mut ctx, midi_id, midi_id, clip.id, 9600).expect("move clip");
        let moved_start = ctx.app_state.clips_pool[clip.id].time.start_time_raw();
        assert_eq!(moved_start, 9600);

        // Undo → clip should be at original position
        api::undo(&mut ctx).expect("undo move clip");
        let after_undo = ctx.app_state.clips_pool[clip.id].time.start_time_raw();
        assert_eq!(
            after_undo, original_start,
            "Undo should restore original position"
        );

        // Redo → clip moved again
        api::redo(&mut ctx).expect("redo move clip");
        let after_redo = ctx.app_state.clips_pool[clip.id].time.start_time_raw();
        assert_eq!(after_redo, 9600, "Redo should re-apply the move");
    }

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

        let before_undo = ctx.app_state.pattern_pool[pattern_id].notes.len();
        assert!(before_undo >= 3, "Should have at least the 3 batch notes");

        // Undo the Batch action → all 3 notes should be removed
        api::undo(&mut ctx).expect("undo batch");
        let after_undo = ctx.app_state.pattern_pool[pattern_id].notes.len();
        assert_eq!(
            after_undo,
            before_undo - 3,
            "All 3 batch notes should be undone"
        );
    }

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

    fn pattern_spans(
        ctx: &karbeat_core::context::DawContext,
        pattern_id: karbeat_core::shared::PatternId,
    ) -> Vec<(u32, u64, u64, u8)> {
        ctx.app_state.pattern_pool[pattern_id]
            .notes
            .iter()
            .map(|n| (n.id.to_u32(), n.start_tick, n.duration, n.key))
            .collect()
    }

    #[test]
    fn chop_then_undo_restores_the_original_notes() {
        let (mut ctx, _audio_id, _midi_id, pattern_id) = make_seeded_ctx();
        let note = note_api::add_note(&mut ctx, pattern_id, 60, 1000, Some(960)).unwrap();
        let before = pattern_spans(&ctx, pattern_id);

        let chopped = note_api::chop_notes(&mut ctx, pattern_id, &[note.id], 240).unwrap();
        assert_eq!(
            chopped
                .notes
                .iter()
                .filter(|n| n.key == 60 && n.start_tick >= 1000)
                .count(),
            5
        );
        let after = pattern_spans(&ctx, pattern_id);

        api::undo(&mut ctx).expect("undo chop");
        assert_eq!(pattern_spans(&ctx, pattern_id), before);
        api::redo(&mut ctx).expect("redo chop");
        assert_eq!(pattern_spans(&ctx, pattern_id), after);
    }

    #[test]
    fn transpose_and_params_undo_independently() {
        let (mut ctx, _audio_id, _midi_id, pattern_id) = make_seeded_ctx();
        let note = note_api::add_note(&mut ctx, pattern_id, 60, 0, Some(480)).unwrap();

        note_api::transpose_notes(&mut ctx, pattern_id, &[note.id], 12).unwrap();
        note_api::set_note_params_batch(
            &mut ctx,
            pattern_id,
            &[(
                note.id,
                karbeat_core::core::project::track::note_transform::NoteParams {
                    velocity: Some(40),
                    pan: Some(-0.5),
                    pitch: Some(1.0),
                },
            )],
        )
        .unwrap();
        let find = |ctx: &karbeat_core::context::DawContext| {
            ctx.app_state.pattern_pool[pattern_id]
                .notes
                .iter()
                .find(|n| n.id == note.id)
                .cloned()
                .unwrap()
        };
        let edited = find(&ctx);
        assert_eq!(
            (edited.key, edited.velocity, edited.pan, edited.pitch),
            (72, 40, -0.5, 1.0)
        );

        api::undo(&mut ctx).expect("undo params");
        let transposed = find(&ctx);
        assert_eq!(
            (transposed.key, transposed.velocity, transposed.pan),
            (72, 100, 0.0)
        );

        api::undo(&mut ctx).expect("undo transpose");
        assert_eq!(find(&ctx).key, 60);
    }
}
