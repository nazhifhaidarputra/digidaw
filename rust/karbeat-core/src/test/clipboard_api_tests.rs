//! Tests for `api::clipboard_api`

#[cfg(test)]
mod tests {
    use crate::api::clipboard_api;

    use crate::core::project::ClipboardContent;
    use crate::shared::id::PatternId;
    use crate::test::helpers::{make_ctx, make_seeded_ctx};

    #[test]
    fn get_clipboard_contents_initial_empty() {
        let ctx = make_ctx();
        let is_empty =
            clipboard_api::get_clipboard_contents(&ctx, |cb| matches!(cb, ClipboardContent::Empty));
        assert!(is_empty, "Fresh state clipboard should be Empty");
    }

    #[test]
    fn copy_pattern_notes_happy_path() {
        let (mut ctx, _audio_id, _midi_id, pattern_id) = make_seeded_ctx();
        let note_ids: Vec<_> = ctx.app_state.pattern_pool[pattern_id]
            .notes
            .iter()
            .map(|n| n.id)
            .collect();
        assert!(!note_ids.is_empty());

        let result = clipboard_api::copy_pattern_notes(&mut ctx, pattern_id, note_ids, |cb| {
            matches!(cb, ClipboardContent::Notes(_))
        });
        assert!(result.is_ok());
        assert!(result.unwrap(), "Clipboard should contain notes after copy");
    }

    #[test]
    fn copy_pattern_notes_missing_pattern_returns_err() {
        let mut ctx = make_ctx();
        let bogus_id = PatternId::from(99999);
        let result = clipboard_api::copy_pattern_notes(&mut ctx, bogus_id, vec![], |_cb| ());
        assert!(result.is_err());
    }

    #[test]
    fn paste_notes_empty_clipboard_returns_empty() {
        let (mut ctx, _audio_id, _midi_id, pattern_id) = make_seeded_ctx();
        // Clipboard is still empty (never copied)
        let result = clipboard_api::paste_notes(&mut ctx, pattern_id, 0, None, |n| n.id);
        assert!(result.is_ok());
        assert!(
            result.unwrap().is_empty(),
            "Paste with empty clipboard should return empty"
        );
    }

    #[test]
    fn paste_notes_with_copied_content() {
        let (mut ctx, _audio_id, _midi_id, pattern_id) = make_seeded_ctx();
        let note_ids: Vec<_> = ctx.app_state.pattern_pool[pattern_id]
            .notes
            .iter()
            .map(|n| n.id)
            .collect();

        // Copy notes
        clipboard_api::copy_pattern_notes(&mut ctx, pattern_id, note_ids, |_| ()).unwrap();

        // Paste at tick 2000
        let result = clipboard_api::paste_notes(&mut ctx, pattern_id, 2000, None, |n| n.id);
        assert!(result.is_ok(), "{:?}", result.err());
        assert!(
            !result.unwrap().is_empty(),
            "Paste should return pasted notes"
        );
    }

    #[test]
    fn paste_notes_with_target_key_override() {
        let (mut ctx, _audio_id, _midi_id, pattern_id) = make_seeded_ctx();
        let note_ids: Vec<_> = ctx.app_state.pattern_pool[pattern_id]
            .notes
            .iter()
            .map(|n| n.id)
            .collect();

        clipboard_api::copy_pattern_notes(&mut ctx, pattern_id, note_ids, |_| ()).unwrap();

        // Paste with key override to key=48 (C3)
        let result = clipboard_api::paste_notes(&mut ctx, pattern_id, 5000, Some(48), |n| n.key);
        assert!(result.is_ok());
        let keys = result.unwrap();
        assert!(!keys.is_empty());
        // All pasted notes should have key=48
        assert!(
            keys.iter().all(|&k| k == 48),
            "All notes should be remapped to key 48"
        );
    }

    #[test]
    fn cut_notes_empty_list_is_noop() {
        let (mut ctx, _audio_id, _midi_id, pattern_id) = make_seeded_ctx();
        let before = ctx.app_state.pattern_pool[pattern_id].notes.len();
        let result = clipboard_api::cut_notes(&mut ctx, pattern_id, vec![]);
        assert!(result.is_ok());
        let after = ctx.app_state.pattern_pool[pattern_id].notes.len();
        assert_eq!(before, after, "Empty cut should not remove notes");
    }

    #[test]
    fn cut_notes_removes_notes_and_sets_clipboard() {
        let (mut ctx, _audio_id, _midi_id, pattern_id) = make_seeded_ctx();
        let note_ids: Vec<_> = ctx.app_state.pattern_pool[pattern_id]
            .notes
            .iter()
            .map(|n| n.id)
            .collect();
        let count = note_ids.len();

        let result = clipboard_api::cut_notes(&mut ctx, pattern_id, note_ids);
        assert!(result.is_ok());
        assert!(
            ctx.app_state.pattern_pool[pattern_id].notes.is_empty(),
            "All notes should have been cut"
        );
        let has_notes = clipboard_api::get_clipboard_contents(&ctx, |cb| {
            matches!(cb, ClipboardContent::Notes(_))
        });
        assert!(has_notes, "Clipboard should contain notes after cut");
    }


    #[test]
    fn copy_clips_empty_ids_leaves_clipboard_empty() {
        let (mut ctx, _audio_id, midi_id, _pat_id) = make_seeded_ctx();
        clipboard_api::copy_clips(&mut ctx, midi_id, &[]);
        let is_empty =
            clipboard_api::get_clipboard_contents(&ctx, |cb| matches!(cb, ClipboardContent::Empty));
        assert!(is_empty, "Copying empty slice should leave clipboard empty");
    }

    #[test]
    fn copy_clips_happy_path() {
        let (mut ctx, _audio_id, midi_id, _pat_id) = make_seeded_ctx();
        let clip_ids: Vec<_> = ctx.app_state.tracks[midi_id]
            .clips
            .iter()
            .copied()
            .collect();
        clipboard_api::copy_clips(&mut ctx, midi_id, &clip_ids);
        let has_clips = clipboard_api::get_clipboard_contents(&ctx, |cb| {
            matches!(cb, ClipboardContent::Clips(_))
        });
        assert!(has_clips, "Clipboard should contain clips after copy");
    }

    #[test]
    fn cut_clips_empty_ids_is_noop() {
        let (mut ctx, _audio_id, midi_id, _pat_id) = make_seeded_ctx();
        let before = ctx.app_state.tracks[midi_id].clips.len();
        clipboard_api::cut_clips(&mut ctx, midi_id, vec![]);
        let after = ctx.app_state.tracks[midi_id].clips.len();
        assert_eq!(before, after);
    }

    #[test]
    fn cut_clips_removes_from_track() {
        let (mut ctx, _audio_id, midi_id, _pat_id) = make_seeded_ctx();
        let clip_ids: Vec<_> = ctx.app_state.tracks[midi_id]
            .clips
            .iter()
            .copied()
            .collect();
        let count = clip_ids.len();
        clipboard_api::cut_clips(&mut ctx, midi_id, clip_ids);
        assert!(
            ctx.app_state.tracks[midi_id].clips.is_empty(),
            "All clips should be cut"
        );
    }

    #[test]
    fn paste_clips_empty_clipboard_returns_err() {
        let (mut ctx, _audio_id, midi_id, _pat_id) = make_seeded_ctx();
        // Clipboard is empty
        let paste_pos = crate::core::project::clip::ClipTimeUnit::Ticks {
            start_time: 0,
            loop_length: 0,
            offset_start: 0,
        };
        let result = clipboard_api::paste_clips(&mut ctx, midi_id, paste_pos);
        // paste_clip_batch returns Err when clipboard doesn't contain clips
        assert!(result.is_err(), "Paste with empty clipboard should Err");
    }

    #[test]
    fn paste_clips_happy_path() {
        let (mut ctx, _audio_id, midi_id, _pat_id) = make_seeded_ctx();
        // Copy first
        let clip_ids: Vec<_> = ctx.app_state.tracks[midi_id]
            .clips
            .iter()
            .copied()
            .collect();
        clipboard_api::copy_clips(&mut ctx, midi_id, &clip_ids);

        let paste_pos = crate::core::project::clip::ClipTimeUnit::Ticks {
            start_time: 9600,
            loop_length: 0,
            offset_start: 0,
        };
        let result = clipboard_api::paste_clips(&mut ctx, midi_id, paste_pos);
        assert!(result.is_ok(), "{:?}", result.err());
        assert!(!result.unwrap().is_empty());
    }
}
