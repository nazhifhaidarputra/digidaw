//! Tests for `api::clip_api`

#[cfg(test)]
mod tests {
    use crate::api::clip_api;
    use crate::core::{
        history::ProjectAction,
        project::{
            ClipboardContent, DawSource,
            clip::{Clip, ClipSourceType, ClipTimeUnit, ResizeEdge},
        },
    };
    use crate::shared::AudioSourceId;
    use crate::shared::id::{ClipId, TrackId};
    use crate::test::helpers::{make_ctx, make_seeded_ctx};

    fn add_midi_clip(
        ctx: &mut crate::context::DawContext,
        track_id: TrackId,
        start: u32,
    ) -> crate::core::project::clip::Clip {
        clip_api::add_clip(ctx, None, ClipSourceType::Midi, track_id, start)
            .expect("add_clip should succeed")
    }

    fn add_audio_clip(ctx: &mut crate::context::DawContext, track_id: TrackId, start: u64) -> Clip {
        let app = &mut ctx.app_state;
        let clip_id = app.clips_pool.insert_with_key(|id| Clip {
            name: "test audio".to_string(),
            id,
            source: Some(DawSource::Audio(AudioSourceId::from(9999))),
            time: ClipTimeUnit::Samples {
                start_time: start,
                loop_length: 48_000,
                offset_start: 0,
            },
        });
        app.tracks
            .get_mut(track_id)
            .expect("audio track should exist")
            .add_clip(clip_id, &app.clips_pool)
            .expect("audio track should accept audio clip");
        app.clips_pool[clip_id].clone()
    }

    #[test]
    fn get_clip_happy_path() {
        let (mut ctx, _audio_id, midi_id, _pat_id) = make_seeded_ctx();
        // The seeded ctx already has one clip on midi_id (from make_seeded_ctx)
        let clips: Vec<_> = ctx.app_state.tracks[midi_id]
            .clips
            .iter()
            .cloned()
            .collect();
        assert!(!clips.is_empty(), "seeded ctx should have clips");
        let clip_id = clips[0];

        let result = clip_api::get_clip(&ctx, midi_id, clip_id, |c| c.id);
        assert!(result.is_ok());
        assert_eq!(result.unwrap(), clip_id);
    }

    #[test]
    fn get_clip_missing_track_returns_err() {
        let ctx = make_ctx();
        let bogus_track = TrackId::from(99999);
        let bogus_clip = ClipId::from(99999);
        let result = clip_api::get_clip(&ctx, bogus_track, bogus_clip, |_| ());
        assert!(result.is_err());
    }

    #[test]
    fn get_clip_missing_clip_returns_err() {
        let (ctx, _audio_id, midi_id, _pat_id) = make_seeded_ctx();
        let bogus_clip = ClipId::from(99999);
        let result = clip_api::get_clip(&ctx, midi_id, bogus_clip, |_| ());
        assert!(result.is_err());
    }

    #[test]
    fn add_clip_happy_path() {
        let (mut ctx, _audio_id, midi_id, _pat_id) = make_seeded_ctx();
        let before = ctx.app_state.tracks[midi_id].clips.len();
        add_midi_clip(&mut ctx, midi_id, 3840); // start at beat 4
        let after = ctx.app_state.tracks[midi_id].clips.len();
        assert_eq!(after, before + 1);
    }

    #[test]
    fn add_clip_invalid_track_returns_err() {
        let mut ctx = make_ctx();
        let bogus_id = TrackId::from(99999);
        let result = clip_api::add_clip(&mut ctx, None, ClipSourceType::Midi, bogus_id, 0);
        assert!(result.is_err());
    }

    #[test]
    fn add_clip_wrong_type_for_audio_track_returns_err() {
        let (mut ctx, audio_id, _midi_id, _pat_id) = make_seeded_ctx();
        // Adding MIDI clip to an Audio track should fail due to type mismatch
        let result = clip_api::add_clip(&mut ctx, None, ClipSourceType::Midi, audio_id, 0);
        assert!(result.is_err(), "MIDI clip on Audio track should fail");
    }

    #[test]
    fn delete_clip_happy_path() {
        let (mut ctx, _audio_id, midi_id, _pat_id) = make_seeded_ctx();
        let clip_id = ctx.app_state.tracks[midi_id].clips[0];
        let before = ctx.app_state.tracks[midi_id].clips.len();

        let result = clip_api::delete_clip(&mut ctx, midi_id, clip_id);
        assert!(result.is_ok());
        let after = ctx.app_state.tracks[midi_id].clips.len();
        assert_eq!(after, before - 1);
    }

    #[test]
    fn delete_clip_missing_clip_returns_err() {
        let (mut ctx, _audio_id, midi_id, _pat_id) = make_seeded_ctx();
        let bogus_clip = ClipId::from(99999);
        let result = clip_api::delete_clip(&mut ctx, midi_id, bogus_clip);
        assert!(result.is_err());
    }

    #[test]
    fn move_clip_same_track_changes_start_time() {
        let (mut ctx, _audio_id, midi_id, _pat_id) = make_seeded_ctx();
        let clip_id = ctx.app_state.tracks[midi_id].clips[0];
        let result = clip_api::move_clip(&mut ctx, midi_id, midi_id, clip_id, 9600);
        assert!(result.is_ok(), "{:?}", result.err());
        let new_start = result.unwrap().time.start_time_raw();
        assert_eq!(new_start, 9600);
    }

    #[test]
    fn move_audio_clip_to_midi_track_returns_err_without_mutating() {
        let (mut ctx, audio_id, midi_id, _pat_id) = make_seeded_ctx();
        let clip = add_audio_clip(&mut ctx, audio_id, 24_000);

        let result = clip_api::move_clip(&mut ctx, audio_id, midi_id, clip.id, 48_000);

        let error = result.expect_err("audio-to-MIDI move must fail");
        assert!(
            error
                .to_string()
                .contains("Cannot move audio clip to MIDI track")
        );
        assert!(ctx.app_state.tracks[audio_id].clips.contains(&clip.id));
        assert!(!ctx.app_state.tracks[midi_id].clips.contains(&clip.id));
        assert_eq!(
            ctx.app_state.clips_pool[clip.id].time.start_time_raw(),
            24_000
        );
    }

    #[test]
    fn batch_move_audio_clip_to_midi_track_is_atomic_error() {
        let (mut ctx, audio_id, midi_id, _pat_id) = make_seeded_ctx();
        let clip = add_audio_clip(&mut ctx, audio_id, 24_000);

        let result = clip_api::batch_move_clips(&mut ctx, audio_id, midi_id, vec![clip.id], 24_000);

        let error = result.expect_err("audio-to-MIDI batch move must fail");
        assert!(
            error
                .to_string()
                .contains("Cannot move audio clip to MIDI track")
        );
        assert!(ctx.app_state.tracks[audio_id].clips.contains(&clip.id));
        assert!(!ctx.app_state.tracks[midi_id].clips.contains(&clip.id));
        assert_eq!(
            ctx.app_state.clips_pool[clip.id].time.start_time_raw(),
            24_000
        );
    }

    #[test]
    fn move_clip_missing_source_track_returns_err() {
        let mut ctx = make_ctx();
        let bogus_src = TrackId::from(99998);
        let bogus_tgt = TrackId::from(99999);
        let bogus_clip = ClipId::from(99999);
        let result = clip_api::move_clip(&mut ctx, bogus_src, bogus_tgt, bogus_clip, 0);
        assert!(result.is_err());
    }

    #[test]
    fn move_clip_missing_clip_returns_err() {
        let (mut ctx, _audio_id, midi_id, _pat_id) = make_seeded_ctx();
        let bogus_clip = ClipId::from(99999);
        let result = clip_api::move_clip(&mut ctx, midi_id, midi_id, bogus_clip, 100);
        assert!(result.is_err());
    }

    #[test]
    fn resize_clip_right_edge_extends_length() {
        let (mut ctx, _audio_id, midi_id, _pat_id) = make_seeded_ctx();
        let clip_id = ctx.app_state.tracks[midi_id].clips[0];
        let clip = ctx.app_state.clips_pool[clip_id].clone();
        let original_start = clip.time.start_time_raw();
        let original_length = clip.time.loop_length_raw();

        // Extend right edge by doubling
        let new_end = original_start + original_length * 2;
        let result = clip_api::resize_clip(&mut ctx, midi_id, clip.id, ResizeEdge::Right, new_end);
        assert!(result.is_ok(), "{:?}", result.err());
        let new_clip = result.unwrap();
        assert_eq!(
            new_clip.time.start_time_raw(),
            original_start,
            "Start should not change"
        );
        assert!(
            new_clip.time.loop_length_raw() > original_length,
            "Length should increase"
        );
    }

    #[test]
    fn resize_clip_missing_track_returns_err() {
        let mut ctx = make_ctx();
        let bogus_track = TrackId::from(99999);
        let bogus_clip = ClipId::from(99999);
        let result =
            clip_api::resize_clip(&mut ctx, bogus_track, bogus_clip, ResizeEdge::Right, 1000);
        assert!(result.is_err());
    }

    #[test]
    fn slice_clip_at_midpoint() {
        let (mut ctx, _audio_id, midi_id, _pat_id) = make_seeded_ctx();
        let clip_id = ctx.app_state.tracks[midi_id].clips[0];
        let clip = ctx.app_state.clips_pool[clip_id].clone();
        let start = clip.time.start_time_raw();
        let len = clip.time.loop_length_raw();
        let midpoint = start + len / 2;

        let result = clip_api::slice_clip(&mut ctx, midi_id, clip.id, midpoint);
        assert!(result.is_ok(), "{:?}", result.err());
        let (left, right) = result.unwrap();
        assert!(left.time.loop_length_raw() > 0);
        assert!(right.time.loop_length_raw() > 0);
        assert_eq!(
            left.time.start_time_raw() + left.time.loop_length_raw(),
            midpoint
        );
        assert_eq!(right.time.start_time_raw(), midpoint);
    }

    #[test]
    fn slice_clip_outside_boundaries_returns_err() {
        let (mut ctx, _audio_id, midi_id, _pat_id) = make_seeded_ctx();
        let clip_id = ctx.app_state.tracks[midi_id].clips[0];
        let clip = ctx.app_state.clips_pool[clip_id].clone();
        // Cut point before clip start
        let result = clip_api::slice_clip(&mut ctx, midi_id, clip.id, 0);
        assert!(result.is_err(), "Cut outside bounds should Err");
    }

    #[test]
    fn slice_clip_missing_clip_returns_err() {
        let (mut ctx, _audio_id, midi_id, _pat_id) = make_seeded_ctx();
        let bogus_clip = ClipId::from(99999);
        let result = clip_api::slice_clip(&mut ctx, midi_id, bogus_clip, 500);
        assert!(result.is_err());
    }

    #[test]
    fn batch_delete_clips_all_valid() {
        let (mut ctx, _audio_id, midi_id, _pat_id) = make_seeded_ctx();
        // Add a second clip
        add_midi_clip(&mut ctx, midi_id, 9600);
        let clip_ids: Vec<ClipId> = ctx.app_state.tracks[midi_id]
            .clips
            .iter()
            .copied()
            .collect();
        assert!(clip_ids.len() >= 2);

        let result = clip_api::batch_delete_clips(&mut ctx, midi_id, clip_ids);
        assert!(result.is_ok());
        assert!(ctx.app_state.tracks[midi_id].clips.is_empty());
    }

    #[test]
    fn batch_delete_clips_partial_invalid_ids_silently_skipped() {
        let (mut ctx, _audio_id, midi_id, _pat_id) = make_seeded_ctx();
        let valid_id = ctx.app_state.tracks[midi_id].clips[0];
        let bogus_id = ClipId::from(99999);

        // Mix of valid + invalid
        let result = clip_api::batch_delete_clips(&mut ctx, midi_id, vec![valid_id, bogus_id]);
        assert!(
            result.is_ok(),
            "Should succeed even with invalid IDs mixed in"
        );
    }

    #[test]
    fn batch_delete_clips_empty_list_is_noop() {
        let (mut ctx, _audio_id, midi_id, _pat_id) = make_seeded_ctx();
        let before = ctx.app_state.tracks[midi_id].clips.len();
        let result = clip_api::batch_delete_clips(&mut ctx, midi_id, vec![]);
        assert!(result.is_ok());
        assert_eq!(ctx.app_state.tracks[midi_id].clips.len(), before);
    }

    #[test]
    fn batch_move_clips_with_positive_delta() {
        let (mut ctx, _audio_id, midi_id, _pat_id) = make_seeded_ctx();
        let clip_id = ctx.app_state.tracks[midi_id].clips[0];
        let clip = ctx.app_state.clips_pool[clip_id].clone();
        let old_start = clip.time.start_time_raw();

        let result = clip_api::batch_move_clips(&mut ctx, midi_id, midi_id, vec![clip.id], 960);
        assert!(result.is_ok(), "{:?}", result.err());
        let moved = result.unwrap();
        assert!(!moved.is_empty());
        assert_eq!(moved[0].time.start_time_raw(), old_start + 960);
    }

    #[test]
    fn batch_move_clips_empty_list_returns_empty() {
        let (mut ctx, _audio_id, midi_id, _pat_id) = make_seeded_ctx();
        let result = clip_api::batch_move_clips(&mut ctx, midi_id, midi_id, vec![], 100);
        assert!(result.is_ok());
        assert!(result.unwrap().is_empty());
    }

    #[test]
    fn batch_resize_clips_right_edge_extends() {
        let (mut ctx, _audio_id, midi_id, _pat_id) = make_seeded_ctx();
        let clip_id = ctx.app_state.tracks[midi_id].clips[0];
        let clip = ctx.app_state.clips_pool[clip_id].clone();
        let original_length = clip.time.loop_length_raw();

        let result =
            clip_api::batch_resize_clips(&mut ctx, midi_id, vec![clip.id], ResizeEdge::Right, 960);
        assert!(result.is_ok(), "{:?}", result.err());
        let resized = result.unwrap();
        assert!(!resized.is_empty());
        assert!(resized[0].time.loop_length_raw() > original_length);
    }

    #[test]
    fn batch_duplicate_clip_groups_is_atomic_and_does_not_touch_clipboard() {
        let (mut ctx, _audio_id, midi_id, _pat_id) = make_seeded_ctx();
        let second = add_midi_clip(&mut ctx, midi_id, 4_800);
        let first_id = ctx.app_state.tracks[midi_id].clips[0];
        let source_ids = vec![first_id, second.id];
        let clip_count_before = ctx.app_state.tracks[midi_id].clips.len();
        let history_count_before = ctx.history.undo_stack.len();

        assert!(matches!(ctx.app_state.clipboard, ClipboardContent::Empty));

        let duplicated = clip_api::batch_duplicate_clip_groups(
            &mut ctx,
            midi_id,
            source_ids,
            vec![9_600, 19_200],
        )
        .expect("batch duplicate should succeed");

        let starts = duplicated
            .iter()
            .map(|clip| clip.time.start_time_raw())
            .collect::<Vec<_>>();
        assert_eq!(starts, vec![9_600, 14_400, 19_200, 24_000]);
        assert_eq!(
            ctx.app_state.tracks[midi_id].clips.len(),
            clip_count_before + 4
        );
        assert!(matches!(ctx.app_state.clipboard, ClipboardContent::Empty));
        assert_eq!(ctx.history.undo_stack.len(), history_count_before + 1);
        assert!(matches!(
            ctx.history.undo_stack.last(),
            Some(ProjectAction::Batch(actions)) if actions.len() == 4
        ));

        ctx.history
            .undo(&mut ctx.app_state)
            .expect("one undo should remove the complete draw batch");
        assert_eq!(ctx.app_state.tracks[midi_id].clips.len(), clip_count_before);
    }

    #[test]
    fn batch_duplicate_audio_clip_groups_uses_sample_positions() {
        let (mut ctx, audio_id, _midi_id, _pat_id) = make_seeded_ctx();
        let source = add_audio_clip(&mut ctx, audio_id, 24_000);

        let duplicated = clip_api::batch_duplicate_clip_groups(
            &mut ctx,
            audio_id,
            vec![source.id],
            vec![72_000, 120_000],
        )
        .expect("audio batch duplicate should succeed");

        assert_eq!(
            duplicated
                .iter()
                .map(|clip| clip.time.start_time_raw())
                .collect::<Vec<_>>(),
            vec![72_000, 120_000]
        );
        assert!(duplicated.iter().all(|clip| clip.time.is_samples()));
        assert!(matches!(ctx.app_state.clipboard, ClipboardContent::Empty));
    }

    #[test]
    fn batch_duplicate_clip_groups_rejects_invalid_source_without_mutating() {
        let (mut ctx, _audio_id, midi_id, _pat_id) = make_seeded_ctx();
        let valid_id = ctx.app_state.tracks[midi_id].clips[0];
        let invalid_id = ClipId::from(999_999);
        let clip_count_before = ctx.app_state.tracks[midi_id].clips.len();
        let pool_count_before = ctx.app_state.clips_pool.len();
        let history_count_before = ctx.history.undo_stack.len();

        let result = clip_api::batch_duplicate_clip_groups(
            &mut ctx,
            midi_id,
            vec![valid_id, invalid_id],
            vec![9_600],
        );

        assert!(result.is_err());
        assert_eq!(ctx.app_state.tracks[midi_id].clips.len(), clip_count_before);
        assert_eq!(ctx.app_state.clips_pool.len(), pool_count_before);
        assert_eq!(ctx.history.undo_stack.len(), history_count_before);
    }
}
