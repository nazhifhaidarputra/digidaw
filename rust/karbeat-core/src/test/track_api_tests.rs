//! Tests for `api::track_api`

#[cfg(test)]
mod tests {
    use crate::api::track_api;
    use crate::shared::id::TrackId;
    use crate::test::helpers::{karbeatzer_v2_registry_id, make_ctx};

    // ─── get_track ───────────────────────────────────────────────────────────

    #[test]
    fn get_track_returns_none_for_missing_id() {
        let ctx = make_ctx();
        let bogus_id = TrackId::from(99999);
        let result = track_api::get_track(&ctx, bogus_id, |t| t.name.clone());
        assert!(result.is_none(), "Should return None for unknown TrackId");
    }

    #[test]
    fn get_track_maps_correctly() {
        let mut ctx = make_ctx();
        let track = track_api::add_new_audio_track(&mut ctx);
        let name = track_api::get_track(&ctx, track.id, |t| t.name.clone());
        assert!(name.is_some());
        assert_eq!(name.unwrap(), track.name);
    }

    // ─── add_new_audio_track ─────────────────────────────────────────────────

    #[test]
    fn add_new_audio_track_increments_count() {
        let mut ctx = make_ctx();
        assert_eq!(ctx.app_state.tracks.len(), 0);
        track_api::add_new_audio_track(&mut ctx);
        assert_eq!(ctx.app_state.tracks.len(), 1);
        track_api::add_new_audio_track(&mut ctx);
        assert_eq!(ctx.app_state.tracks.len(), 2);
    }

    #[test]
    fn add_new_audio_track_uses_user_friendly_default_name() {
        let mut ctx = make_ctx();

        let track = track_api::add_new_audio_track(&mut ctx);

        assert_eq!(track.name, "Audio track");
    }

    // ─── add_midi_track_with_generator_id ────────────────────────────────────

    #[test]
    fn add_midi_track_with_generator_id_happy_path() {
        let mut ctx = make_ctx();
        let result =
            track_api::add_midi_track_with_generator_id(&mut ctx, karbeatzer_v2_registry_id());
        assert!(result.is_ok(), "Should add MIDI track: {:?}", result.err());
        let track = result.unwrap();
        assert!(
            track.generator.is_some(),
            "MIDI track must have a generator"
        );
    }

    #[test]
    fn add_midi_track_with_invalid_registry_id_returns_err() {
        let mut ctx = make_ctx();
        let result = track_api::add_midi_track_with_generator_id(&mut ctx, 0xDEADBEEF);
        assert!(result.is_err(), "Should error on unknown registry ID");
    }

    // ─── change_track_name ───────────────────────────────────────────────────

    #[test]
    fn change_track_name_happy_path() {
        let mut ctx = make_ctx();
        let track = track_api::add_new_audio_track(&mut ctx);
        let result = track_api::change_track_name(&mut ctx, track.id, "My Track");
        assert!(result.is_ok());
        let name = track_api::get_track(&ctx, track.id, |t| t.name.clone()).unwrap();
        assert_eq!(name, "My Track");
    }

    #[test]
    fn change_track_name_exactly_20_chars_ok() {
        let mut ctx = make_ctx();
        let track = track_api::add_new_audio_track(&mut ctx);
        let twenty = "12345678901234567890"; // exactly 20
        assert_eq!(twenty.len(), 20);
        let result = track_api::change_track_name(&mut ctx, track.id, twenty);
        assert!(result.is_ok(), "20-char name should be allowed");
    }

    #[test]
    fn change_track_name_too_long_returns_err() {
        let mut ctx = make_ctx();
        let track = track_api::add_new_audio_track(&mut ctx);
        let too_long = "123456789012345678901"; // 21 chars
        assert_eq!(too_long.len(), 21);
        let result = track_api::change_track_name(&mut ctx, track.id, too_long);
        assert!(result.is_err(), "21-char name should be rejected");
    }

    #[test]
    fn change_track_name_empty_ok() {
        let mut ctx = make_ctx();
        let track = track_api::add_new_audio_track(&mut ctx);
        let result = track_api::change_track_name(&mut ctx, track.id, "");
        assert!(result.is_ok(), "Empty name should be allowed");
    }

    #[test]
    fn change_track_name_missing_track_returns_err() {
        let mut ctx = make_ctx();
        let bogus_id = TrackId::from(99999);
        let result = track_api::change_track_name(&mut ctx, bogus_id, "Ghost");
        assert!(result.is_err());
        let msg = result.unwrap_err().to_string();
        assert!(msg.contains("Track not found"), "Got: {}", msg);
    }

    // ─── change_track_color ──────────────────────────────────────────────────

    #[test]
    fn change_track_color_valid_hex6() {
        let mut ctx = make_ctx();
        let track = track_api::add_new_audio_track(&mut ctx);
        let result = track_api::change_track_color(&mut ctx, track.id, "#FF8A65");
        assert!(result.is_ok(), "Valid #RRGGBB should be accepted");
    }

    #[test]
    fn change_track_color_valid_hex8() {
        let mut ctx = make_ctx();
        let track = track_api::add_new_audio_track(&mut ctx);
        let result = track_api::change_track_color(&mut ctx, track.id, "#FF8A65FF");
        assert!(result.is_ok(), "Valid #RRGGBBAA should be accepted");
    }

    #[test]
    fn change_track_color_invalid_format_returns_err() {
        let mut ctx = make_ctx();
        let track = track_api::add_new_audio_track(&mut ctx);
        let result = track_api::change_track_color(&mut ctx, track.id, "notacolor");
        assert!(result.is_err(), "Invalid color string should return Err");
    }

    #[test]
    fn change_track_color_missing_track_returns_err() {
        let mut ctx = make_ctx();
        let bogus_id = TrackId::from(99999);
        let result = track_api::change_track_color(&mut ctx, bogus_id, "#FF0000");
        assert!(result.is_err());
    }

    // ─── get_tracks ──────────────────────────────────────────────────────────

    #[test]
    fn get_tracks_returns_all() {
        let mut ctx = make_ctx();
        track_api::add_new_audio_track(&mut ctx);
        track_api::add_new_audio_track(&mut ctx);
        let names: Vec<String> = track_api::get_tracks(&ctx, |_id, t| t.name.clone());
        assert_eq!(names.len(), 2);
    }

    // ─── get_tracks_ordered ──────────────────────────────────────────────────

    #[test]
    fn get_tracks_ordered_respects_index() {
        let mut ctx = make_ctx();
        track_api::add_new_audio_track(&mut ctx);
        track_api::add_new_audio_track(&mut ctx);
        track_api::add_new_audio_track(&mut ctx);
        let ordered: Vec<usize> = track_api::get_tracks_ordered(&ctx, |_id, t| t.order_idx)
            .expect("get_tracks_ordered should succeed");
        let mut sorted = ordered.clone();
        sorted.sort();
        assert_eq!(
            ordered, sorted,
            "Tracks should be in ascending order_idx order"
        );
    }

    // ─── delete_track ────────────────────────────────────────────────────────

    #[test]
    fn delete_track_removes_it() {
        let mut ctx = make_ctx();
        let track = track_api::add_new_audio_track(&mut ctx);
        assert_eq!(ctx.app_state.tracks.len(), 1);
        let result = track_api::delete_track(&mut ctx, track.id);
        assert!(result.is_ok());
        assert_eq!(ctx.app_state.tracks.len(), 0);
    }

    #[test]
    fn delete_track_missing_id_returns_err() {
        let mut ctx = make_ctx();
        let bogus_id = TrackId::from(99999);
        let result = track_api::delete_track(&mut ctx, bogus_id);
        assert!(result.is_err());
    }

    // ─── update_track_order ──────────────────────────────────────────────────

    #[test]
    fn update_track_order_valid() {
        let mut ctx = make_ctx();
        let t1 = track_api::add_new_audio_track(&mut ctx);
        let t2 = track_api::add_new_audio_track(&mut ctx);
        // Move t1 (currently at idx 0) to position 1
        let result = track_api::update_track_order(&mut ctx, t1.id, 1);
        assert!(result.is_ok(), "{:?}", result.err());
        // After reorder, t1 should now have order_idx 1
        let t1_new_idx = track_api::get_track(&ctx, t1.id, |t| t.order_idx).unwrap();
        let t2_new_idx = track_api::get_track(&ctx, t2.id, |t| t.order_idx).unwrap();
        assert_eq!(t1_new_idx, 1);
        assert_eq!(t2_new_idx, 0);
    }

    #[test]
    fn update_track_order_missing_track_returns_err() {
        let mut ctx = make_ctx();
        let bogus_id = TrackId::from(99999);
        let result = track_api::update_track_order(&mut ctx, bogus_id, 0);
        assert!(result.is_err());
    }

    #[test]
    fn update_track_order_out_of_bounds_clamps() {
        // The implementation clamps OOB to len-1, so it should succeed (not panic)
        let mut ctx = make_ctx();
        let track = track_api::add_new_audio_track(&mut ctx);
        let result = track_api::update_track_order(&mut ctx, track.id, 9999);
        assert!(result.is_ok(), "OOB index should clamp, not error");
    }
}
