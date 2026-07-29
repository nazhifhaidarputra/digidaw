//! Tests for `api::note_api`

#[cfg(test)]
mod tests {
    use crate::api::note_api;
    use crate::shared::id::{NoteId, PatternId};
    use crate::test::helpers::{make_ctx, make_seeded_ctx};

    // ─── add_note ─────────────────────────────────────────────────────────────

    #[test]
    fn add_note_happy_path() {
        let (mut ctx, _audio_id, _midi_id, pattern_id) = make_seeded_ctx();
        let before = ctx.app_state.pattern_pool[&pattern_id].notes.len();
        let result = note_api::add_note(&mut ctx, pattern_id, 72, 5000, Some(960));
        assert!(result.is_ok(), "{:?}", result.err());
        let after = ctx.app_state.pattern_pool[&pattern_id].notes.len();
        assert_eq!(after, before + 1);
    }

    #[test]
    fn add_note_missing_pattern_returns_err() {
        let mut ctx = make_ctx();
        let bogus_id = PatternId::from(99999);
        let result = note_api::add_note(&mut ctx, bogus_id, 60, 0, Some(480));
        assert!(result.is_err());
    }

    #[test]
    fn add_note_key_boundary_min() {
        let (mut ctx, _audio_id, _midi_id, pattern_id) = make_seeded_ctx();
        let result = note_api::add_note(&mut ctx, pattern_id, 0, 10000, Some(480));
        assert!(result.is_ok(), "Key=0 should be accepted");
    }

    #[test]
    fn add_note_key_boundary_max() {
        let (mut ctx, _audio_id, _midi_id, pattern_id) = make_seeded_ctx();
        let result = note_api::add_note(&mut ctx, pattern_id, 127, 11000, Some(480));
        assert!(result.is_ok(), "Key=127 should be accepted");
    }

    #[test]
    fn add_note_zero_duration() {
        let (mut ctx, _audio_id, _midi_id, pattern_id) = make_seeded_ctx();
        // Zero duration: implementation should accept it (no validation in API)
        let result = note_api::add_note(&mut ctx, pattern_id, 60, 20000, Some(0));
        assert!(result.is_ok(), "Zero duration note should be accepted");
    }

    #[test]
    fn add_note_no_duration() {
        let (mut ctx, _audio_id, _midi_id, pattern_id) = make_seeded_ctx();
        let result = note_api::add_note(&mut ctx, pattern_id, 60, 20000, None);
        assert!(result.is_ok(), "None duration should use default");
    }

    // ─── delete_note ──────────────────────────────────────────────────────────

    #[test]
    fn delete_note_happy_path() {
        let (mut ctx, _audio_id, _midi_id, pattern_id) = make_seeded_ctx();
        let note_id = ctx.app_state.pattern_pool[&pattern_id].notes[0].id;
        let before = ctx.app_state.pattern_pool[&pattern_id].notes.len();
        let result = note_api::delete_note(&mut ctx, pattern_id, note_id);
        assert!(result.is_ok(), "{:?}", result.err());
        let after = ctx.app_state.pattern_pool[&pattern_id].notes.len();
        assert_eq!(after, before - 1);
    }

    #[test]
    fn delete_note_missing_pattern_returns_err() {
        let mut ctx = make_ctx();
        let bogus_pat = PatternId::from(99999);
        let bogus_note = NoteId::from(1);
        let result = note_api::delete_note(&mut ctx, bogus_pat, bogus_note);
        assert!(result.is_err());
    }

    #[test]
    fn delete_note_missing_note_returns_err() {
        let (mut ctx, _audio_id, _midi_id, pattern_id) = make_seeded_ctx();
        let bogus_note = NoteId::from(99999);
        let result = note_api::delete_note(&mut ctx, pattern_id, bogus_note);
        assert!(result.is_err());
    }

    // ─── move_note ────────────────────────────────────────────────────────────

    #[test]
    fn move_note_happy_path() {
        let (mut ctx, _audio_id, _midi_id, pattern_id) = make_seeded_ctx();
        let note_id = ctx.app_state.pattern_pool[&pattern_id].notes[0].id;
        let result = note_api::move_note(&mut ctx, pattern_id, note_id, 9999, 65);
        assert!(result.is_ok(), "{:?}", result.err());
        let note = result.unwrap();
        assert_eq!(note.start_tick, 9999);
        assert_eq!(note.key, 65);
    }

    #[test]
    fn move_note_missing_note_returns_err() {
        let (mut ctx, _audio_id, _midi_id, pattern_id) = make_seeded_ctx();
        let bogus_note = NoteId::from(99999);
        let result = note_api::move_note(&mut ctx, pattern_id, bogus_note, 100, 60);
        assert!(result.is_err());
    }

    // ─── resize_note ──────────────────────────────────────────────────────────

    #[test]
    fn resize_note_happy_path() {
        let (mut ctx, _audio_id, _midi_id, pattern_id) = make_seeded_ctx();
        let note_id = ctx.app_state.pattern_pool[&pattern_id].notes[0].id;
        let result = note_api::resize_note(&mut ctx, pattern_id, note_id, 960);
        assert!(result.is_ok(), "{:?}", result.err());
        assert_eq!(result.unwrap().duration, 960);
    }

    #[test]
    fn resize_note_to_zero_duration() {
        let (mut ctx, _audio_id, _midi_id, pattern_id) = make_seeded_ctx();
        let note_id = ctx.app_state.pattern_pool[&pattern_id].notes[0].id;
        // Zero duration: no validation in API layer, just passes through
        let result = note_api::resize_note(&mut ctx, pattern_id, note_id, 0);
        assert!(result.is_ok(), "Zero resize should be accepted");
    }

    #[test]
    fn resize_note_missing_note_returns_err() {
        let (mut ctx, _audio_id, _midi_id, pattern_id) = make_seeded_ctx();
        let bogus_note = NoteId::from(99999);
        let result = note_api::resize_note(&mut ctx, pattern_id, bogus_note, 480);
        assert!(result.is_err());
    }

    // ─── change_note_params ───────────────────────────────────────────────────

    #[test]
    fn change_note_params_all_none_returns_unchanged_note() {
        let (mut ctx, _audio_id, _midi_id, pattern_id) = make_seeded_ctx();
        let note_id = ctx.app_state.pattern_pool[&pattern_id].notes[0].id;
        let original_velocity = ctx.app_state.pattern_pool[&pattern_id].notes[0].velocity;
        let result =
            note_api::change_note_params(&mut ctx, pattern_id, note_id, None, None, None, None);
        assert!(result.is_ok());
        assert_eq!(result.unwrap().velocity, original_velocity);
    }

    #[test]
    fn change_note_params_velocity_min() {
        let (mut ctx, _audio_id, _midi_id, pattern_id) = make_seeded_ctx();
        let note_id = ctx.app_state.pattern_pool[&pattern_id].notes[0].id;
        let result =
            note_api::change_note_params(&mut ctx, pattern_id, note_id, Some(0), None, None, None);
        assert!(result.is_ok());
        assert_eq!(result.unwrap().velocity, 0);
    }

    #[test]
    fn change_note_params_velocity_max() {
        let (mut ctx, _audio_id, _midi_id, pattern_id) = make_seeded_ctx();
        let note_id = ctx.app_state.pattern_pool[&pattern_id].notes[0].id;
        let result = note_api::change_note_params(
            &mut ctx,
            pattern_id,
            note_id,
            Some(127),
            None,
            None,
            None,
        );
        assert!(result.is_ok());
        assert_eq!(result.unwrap().velocity, 127);
    }

    #[test]
    fn change_note_params_mute() {
        let (mut ctx, _audio_id, _midi_id, pattern_id) = make_seeded_ctx();
        let note_id = ctx.app_state.pattern_pool[&pattern_id].notes[0].id;
        let result = note_api::change_note_params(
            &mut ctx,
            pattern_id,
            note_id,
            None,
            None,
            None,
            Some(true),
        );
        assert!(result.is_ok());
        assert!(result.unwrap().mute);
    }

    // ─── add_notes_batch ─────────────────────────────────────────────────────

    #[test]
    fn add_notes_batch_empty_list_is_noop() {
        let (mut ctx, _audio_id, _midi_id, pattern_id) = make_seeded_ctx();
        let before = ctx.app_state.pattern_pool[&pattern_id].notes.len();
        let result = note_api::add_notes_batch(&mut ctx, pattern_id, vec![]);
        assert!(result.is_ok());
        assert_eq!(result.unwrap().len(), 0);
        let after = ctx.app_state.pattern_pool[&pattern_id].notes.len();
        assert_eq!(before, after);
    }

    #[test]
    fn add_notes_batch_single_does_not_use_batch_history() {
        // API-level behaviour: 1 note → single AddNote (not Batch)
        // We verify this indirectly: history undo_stack grows by 1
        let (mut ctx, _audio_id, _midi_id, pattern_id) = make_seeded_ctx();
        let before_hist = ctx.history.undo_stack.len();
        note_api::add_notes_batch(&mut ctx, pattern_id, vec![(60, 30000, Some(480))]).unwrap();
        assert_eq!(ctx.history.undo_stack.len(), before_hist + 1);
    }

    #[test]
    fn add_notes_batch_multiple_adds_batch_to_history() {
        let (mut ctx, _audio_id, _midi_id, pattern_id) = make_seeded_ctx();
        let before_hist = ctx.history.undo_stack.len();
        note_api::add_notes_batch(
            &mut ctx,
            pattern_id,
            vec![
                (60, 30000, Some(480)),
                (62, 31000, Some(480)),
                (64, 32000, Some(480)),
            ],
        )
        .unwrap();
        assert_eq!(ctx.history.undo_stack.len(), before_hist + 1);
        // The top entry should be a Batch
        use crate::core::history::ProjectAction;
        assert!(
            matches!(ctx.history.undo_stack.last(), Some(ProjectAction::Batch(_))),
            "Multiple notes should produce a Batch history entry"
        );
    }

    // ─── delete_notes_batch ───────────────────────────────────────────────────

    #[test]
    fn delete_notes_batch_happy_path() {
        let (mut ctx, _audio_id, _midi_id, pattern_id) = make_seeded_ctx();
        let note_ids: Vec<_> = ctx.app_state.pattern_pool[&pattern_id]
            .notes
            .iter()
            .map(|n| n.id)
            .collect();
        let result = note_api::delete_notes_batch(&mut ctx, pattern_id, note_ids);
        assert!(result.is_ok());
        assert!(ctx.app_state.pattern_pool[&pattern_id].notes.is_empty());
    }

    // ─── move_notes_batch ─────────────────────────────────────────────────────

    #[test]
    fn move_notes_batch_happy_path() {
        let (mut ctx, _audio_id, _midi_id, pattern_id) = make_seeded_ctx();
        let updates: Vec<_> = ctx.app_state.pattern_pool[&pattern_id]
            .notes
            .iter()
            .map(|n| (n.id, n.start_tick + 100, n.key))
            .collect();
        let result = note_api::move_notes_batch(&mut ctx, pattern_id, updates);
        assert!(result.is_ok(), "{:?}", result.err());
        let notes = result.unwrap();
        assert!(!notes.is_empty());
    }

    // ─── resize_notes_batch ───────────────────────────────────────────────────

    #[test]
    fn resize_notes_batch_happy_path() {
        let (mut ctx, _audio_id, _midi_id, pattern_id) = make_seeded_ctx();
        let updates: Vec<_> = ctx.app_state.pattern_pool[&pattern_id]
            .notes
            .iter()
            .map(|n| (n.id, 960u64))
            .collect();
        let result = note_api::resize_notes_batch(&mut ctx, pattern_id, updates);
        assert!(result.is_ok(), "{:?}", result.err());
        let notes = result.unwrap();
        assert!(notes.iter().all(|n| n.duration == 960));
    }
}
