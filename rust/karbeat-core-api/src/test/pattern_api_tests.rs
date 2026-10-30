//! Tests for `api::pattern_api`

#[cfg(test)]
mod tests {
    use crate::pattern_api;
    use crate::test::helpers::{make_ctx, make_seeded_ctx};
    use crate::{clip_api, clipboard_api};
    use karbeat_core::core::project::{ClipboardContent, DawSource, clip::ClipSourceType};
    use karbeat_core::shared::id::{GeneratorId, PatternId};

    #[test]
    fn get_pattern_happy_path() {
        let (ctx, _audio_id, _midi_id, pattern_id) = make_seeded_ctx();
        let result = pattern_api::get_pattern(&ctx, &pattern_id);
        assert!(result.is_ok(), "{:?}", result.err());
        assert_eq!(result.unwrap().id, pattern_id);
    }

    #[test]
    fn get_pattern_missing_returns_err() {
        let ctx = make_ctx();
        let bogus_id = PatternId::from(99999);
        let result = pattern_api::get_pattern(&ctx, &bogus_id);
        assert!(result.is_err());
    }

    #[test]
    fn get_patterns_empty_pool_returns_empty() {
        let ctx = make_ctx();
        let result: Vec<u64> =
            pattern_api::get_patterns(&ctx, |id, _p| id).expect("Should succeed");
        assert!(result.is_empty());
    }

    #[test]
    fn get_patterns_maps_all_in_pool() {
        let (ctx, _audio_id, _midi_id, _pattern_id) = make_seeded_ctx();
        let ids: Vec<u64> = pattern_api::get_patterns(&ctx, |id, _p| id).expect("Should succeed");
        assert!(
            !ids.is_empty(),
            "Seeded context should have at least one pattern"
        );
        assert_eq!(ids.len(), ctx.app_state.pattern_pool.len());
    }

    #[test]
    fn rename_pattern_cascades_only_to_clips_with_the_default_name() {
        let (mut ctx, _audio_id, midi_id, pattern_id) = make_seeded_ctx();
        let custom_clip_id = ctx.app_state.tracks[midi_id].clips[0];
        ctx.app_state
            .rename_clip(custom_clip_id, "Custom clip")
            .expect("clip should exist");
        let default_clip = crate::clip_api::add_clip(
            &mut ctx,
            Some(pattern_id.into()),
            ClipSourceType::Midi,
            midi_id,
            960,
        )
        .expect("clip should be added");

        pattern_api::rename_pattern(&mut ctx, pattern_id, "Renamed Pattern")
            .expect("pattern should be renamed");

        assert_eq!(
            ctx.app_state.pattern_pool[pattern_id].name,
            "Renamed Pattern"
        );
        assert_eq!(ctx.app_state.clips_pool[custom_clip_id].name, "Custom clip");
        assert_eq!(
            ctx.app_state.clips_pool[default_clip.id].name,
            "Renamed Pattern"
        );
        assert!(matches!(
            ctx.app_state.clips_pool[default_clip.id].source,
            Some(DawSource::Midi(id)) if id == pattern_id
        ));
    }

    #[test]
    fn deleting_a_pattern_removes_its_clips_and_undoes_in_one_step() {
        let (mut ctx, _audio_id, midi_id, pattern_id) = make_seeded_ctx();
        let original_clip = ctx.app_state.tracks[midi_id].clips[0];
        let second_clip = clip_api::add_clip(
            &mut ctx,
            Some(pattern_id.into()),
            ClipSourceType::Midi,
            midi_id,
            960,
        )
        .expect("second clip");
        let kept_clip = clip_api::add_clip(&mut ctx, None, ClipSourceType::Midi, midi_id, 1920)
            .expect("kept clip");
        let Some(DawSource::Midi(kept_pattern)) = kept_clip.source else {
            panic!("Expected a MIDI source clip");
        };
        clipboard_api::copy_clips(&mut ctx, midi_id, &[original_clip, kept_clip.id]);
        let history_depth = ctx.history.undo_stack.len();

        let removed = pattern_api::delete_pattern(&mut ctx, pattern_id).expect("delete");

        assert_eq!(removed, 2);
        assert!(!ctx.app_state.pattern_pool.contains_key(pattern_id));
        assert!(ctx.app_state.pattern_pool.contains_key(kept_pattern));
        assert_eq!(ctx.app_state.tracks[midi_id].clips, [kept_clip.id]);
        assert!(!ctx.app_state.clips_pool.contains_key(original_clip));
        assert!(!ctx.app_state.clips_pool.contains_key(second_clip.id));
        assert!(ctx.app_state.clips_pool.contains_key(kept_clip.id));
        // Only the clip of the surviving pattern stays in the clipboard.
        match &ctx.app_state.clipboard {
            ClipboardContent::Clips(clips) => {
                assert_eq!(clips.len(), 1);
                assert_eq!(clips[0].id, kept_clip.id);
            }
            other => panic!("expected copied clips, found {other:?}"),
        }
        assert_eq!(ctx.history.undo_stack.len(), history_depth + 1);
        assert_eq!(ctx.history.undo_label(), Some("Delete Pattern"));

        for _ in 0..2 {
            crate::undo(&mut ctx).expect("undo");
            assert!(ctx.app_state.pattern_pool.contains_key(pattern_id));
            assert_eq!(ctx.app_state.pattern_pool[pattern_id].notes.len(), 3);
            assert_eq!(
                ctx.app_state.tracks[midi_id].clips,
                [original_clip, second_clip.id, kept_clip.id]
            );
            assert!(ctx.app_state.clips_pool.contains_key(original_clip));

            crate::redo(&mut ctx).expect("redo");
            assert!(!ctx.app_state.pattern_pool.contains_key(pattern_id));
            assert_eq!(ctx.app_state.tracks[midi_id].clips, [kept_clip.id]);
        }
    }

    #[test]
    fn deleting_an_unknown_pattern_changes_nothing() {
        let (mut ctx, _audio_id, midi_id, _pattern_id) = make_seeded_ctx();
        let clips = ctx.app_state.tracks[midi_id].clips.clone();
        let history_depth = ctx.history.undo_stack.len();

        let result = pattern_api::delete_pattern(&mut ctx, PatternId::from(99999));

        assert!(result.is_err());
        assert_eq!(ctx.app_state.tracks[midi_id].clips, clips);
        assert_eq!(ctx.history.undo_stack.len(), history_depth);
    }

    #[test]
    fn play_pattern_preview_missing_pattern_returns_err() {
        let mut ctx = make_ctx();
        let bogus_pat = PatternId::from(99999);
        let bogus_gen = GeneratorId::from(1);
        let result = pattern_api::play_pattern_preview(&mut ctx, bogus_pat, bogus_gen);
        assert!(result.is_err());
    }

    #[test]
    fn play_pattern_preview_no_stream_returns_ok() {
        // Ring buffer is None so try_send_audio_command_chain no-ops and returns Ok
        let (mut ctx, _audio_id, _midi_id, pattern_id) = make_seeded_ctx();
        let gen_id = ctx
            .app_state
            .generator_pool
            .keys()
            .next()
            .expect("Seeded ctx should have a generator");
        let result = pattern_api::play_pattern_preview(&mut ctx, pattern_id, gen_id);
        assert!(result.is_ok(), "No-stream should silently succeed");
    }

    #[test]
    fn stop_pattern_preview_local_no_stream_returns_ok() {
        let (mut ctx, _audio_id, _midi_id, pattern_id) = make_seeded_ctx();
        let gen_id = ctx
            .app_state
            .generator_pool
            .keys()
            .next()
            .expect("Seeded ctx should have a generator");
        let result = pattern_api::stop_pattern_preview_local(&mut ctx, pattern_id, gen_id);
        assert!(result.is_ok());
    }

    #[test]
    fn stop_pattern_preview_no_stream_returns_ok() {
        let mut ctx = make_ctx();
        let result = pattern_api::stop_pattern_preview(&mut ctx);
        assert!(result.is_ok());
    }
}
