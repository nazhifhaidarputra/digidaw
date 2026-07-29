//! Tests for `api::clip_api`

#[cfg(test)]
mod tests {
    use crate::api::{clip_api, track_api};
    use crate::core::project::clip::{ClipSourceType, ClipTimeUnit, ResizeEdge};
    use crate::shared::id::{ClipId, TrackId};
    use crate::test::helpers::{make_ctx, make_seeded_ctx};

    // ─── Helper: add a MIDI clip to the given MIDI track ─────────────────────

    fn add_midi_clip(
        ctx: &mut crate::context::DawContext,
        track_id: TrackId,
        start: u32,
    ) -> crate::core::project::clip::Clip {
        clip_api::add_clip(ctx, None, ClipSourceType::Midi, track_id, start)
            .expect("add_clip should succeed")
    }

    // ─── get_clip ────────────────────────────────────────────────────────────

    #[test]
    fn get_clip_happy_path() {
        let (mut ctx, _audio_id, midi_id, _pat_id) = make_seeded_ctx();
        // The seeded ctx already has one clip on midi_id (from make_seeded_ctx)
        let clips: Vec<_> = ctx.app_state.tracks[&midi_id]
            .clips
            .iter()
            .cloned()
            .collect();
        assert!(!clips.is_empty(), "seeded ctx should have clips");
        let clip_id = clips[0].id;

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
        let (mut ctx, _audio_id, midi_id, _pat_id) = make_seeded_ctx();
        let bogus_clip = ClipId::from(99999);
        let result = clip_api::get_clip(&ctx, midi_id, bogus_clip, |_| ());
        assert!(result.is_err());
    }

    // ─── add_clip ─────────────────────────────────────────────────────────────

    #[test]
    fn add_clip_happy_path() {
        let (mut ctx, _audio_id, midi_id, _pat_id) = make_seeded_ctx();
        let before = ctx.app_state.tracks[&midi_id].clips.len();
        add_midi_clip(&mut ctx, midi_id, 3840); // start at beat 4
        let after = ctx.app_state.tracks[&midi_id].clips.len();
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

    // ─── delete_clip ──────────────────────────────────────────────────────────

    #[test]
    fn delete_clip_happy_path() {
        let (mut ctx, _audio_id, midi_id, _pat_id) = make_seeded_ctx();
        let clip_id = ctx.app_state.tracks[&midi_id].clips[0].id;
        let before = ctx.app_state.tracks[&midi_id].clips.len();

        let result = clip_api::delete_clip(&mut ctx, midi_id, clip_id);
        assert!(result.is_ok());
        let after = ctx.app_state.tracks[&midi_id].clips.len();
        assert_eq!(after, before - 1);
    }

    #[test]
    fn delete_clip_missing_clip_returns_err() {
        let (mut ctx, _audio_id, midi_id, _pat_id) = make_seeded_ctx();
        let bogus_clip = ClipId::from(99999);
        let result = clip_api::delete_clip(&mut ctx, midi_id, bogus_clip);
        assert!(result.is_err());
    }

    // ─── move_clip ────────────────────────────────────────────────────────────

    #[test]
    fn move_clip_same_track_changes_start_time() {
        let (mut ctx, _audio_id, midi_id, _pat_id) = make_seeded_ctx();
        let clip_id = ctx.app_state.tracks[&midi_id].clips[0].id;
        let result = clip_api::move_clip(&mut ctx, midi_id, midi_id, clip_id, 9600);
        assert!(result.is_ok(), "{:?}", result.err());
        let new_start = result.unwrap().time.start_time_raw();
        assert_eq!(new_start, 9600);
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

    // ─── resize_clip ──────────────────────────────────────────────────────────

    #[test]
    fn resize_clip_right_edge_extends_length() {
        let (mut ctx, _audio_id, midi_id, _pat_id) = make_seeded_ctx();
        let clip = ctx.app_state.tracks[&midi_id].clips[0].clone();
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

    // ─── slice_clip ───────────────────────────────────────────────────────────

    #[test]
    fn slice_clip_at_midpoint() {
        let (mut ctx, _audio_id, midi_id, _pat_id) = make_seeded_ctx();
        let clip = ctx.app_state.tracks[&midi_id].clips[0].clone();
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
        let clip = ctx.app_state.tracks[&midi_id].clips[0].clone();
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

    // ─── batch_delete_clips ──────────────────────────────────────────────────

    #[test]
    fn batch_delete_clips_all_valid() {
        let (mut ctx, _audio_id, midi_id, _pat_id) = make_seeded_ctx();
        // Add a second clip
        add_midi_clip(&mut ctx, midi_id, 9600);
        let clip_ids: Vec<ClipId> = ctx.app_state.tracks[&midi_id]
            .clips
            .iter()
            .map(|c| c.id)
            .collect();
        assert!(clip_ids.len() >= 2);

        let result = clip_api::batch_delete_clips(&mut ctx, midi_id, clip_ids);
        assert!(result.is_ok());
        assert!(ctx.app_state.tracks[&midi_id].clips.is_empty());
    }

    #[test]
    fn batch_delete_clips_partial_invalid_ids_silently_skipped() {
        let (mut ctx, _audio_id, midi_id, _pat_id) = make_seeded_ctx();
        let valid_id = ctx.app_state.tracks[&midi_id].clips[0].id;
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
        let before = ctx.app_state.tracks[&midi_id].clips.len();
        let result = clip_api::batch_delete_clips(&mut ctx, midi_id, vec![]);
        assert!(result.is_ok());
        assert_eq!(ctx.app_state.tracks[&midi_id].clips.len(), before);
    }

    // ─── batch_move_clips ─────────────────────────────────────────────────────

    #[test]
    fn batch_move_clips_with_positive_delta() {
        let (mut ctx, _audio_id, midi_id, _pat_id) = make_seeded_ctx();
        let clip = ctx.app_state.tracks[&midi_id].clips[0].clone();
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

    // ─── batch_resize_clips ───────────────────────────────────────────────────

    #[test]
    fn batch_resize_clips_right_edge_extends() {
        let (mut ctx, _audio_id, midi_id, _pat_id) = make_seeded_ctx();
        let clip = ctx.app_state.tracks[&midi_id].clips[0].clone();
        let original_length = clip.time.loop_length_raw();

        let result =
            clip_api::batch_resize_clips(&mut ctx, midi_id, vec![clip.id], ResizeEdge::Right, 960);
        assert!(result.is_ok(), "{:?}", result.err());
        let resized = result.unwrap();
        assert!(!resized.is_empty());
        assert!(resized[0].time.loop_length_raw() > original_length);
    }
}
