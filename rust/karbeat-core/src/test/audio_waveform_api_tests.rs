//! Tests for `api::audio_waveform_api`

#[cfg(test)]
mod tests {
    use crate::api::audio_waveform_api;
    use crate::api::track_api;
    use crate::core::project::clip::ClipSourceType;
    use crate::shared::id::{AudioSourceId, TrackId};
    use crate::test::helpers::{make_ctx, make_seeded_ctx};

    // ─── get_audio_waveform_clips_data ───────────────────────────────────────

    #[test]
    fn get_audio_waveform_clips_data_empty_state() {
        let ctx = make_ctx();
        let result: Vec<u32> =
            audio_waveform_api::get_audio_waveform_clips_data(&ctx, |id, _w| id.to_u32())
                .expect("Should succeed on empty state");
        assert!(result.is_empty());
    }

    // ─── get_audio_waveform_for_clip ─────────────────────────────────────────

    #[test]
    fn get_audio_waveform_for_clip_missing_source_returns_err() {
        let ctx = make_ctx();
        let bogus_id = AudioSourceId::from(99999);
        let result = audio_waveform_api::get_audio_waveform_for_clip(&ctx, &bogus_id);
        assert!(result.is_err(), "Unknown AudioSourceId should return Err");
    }

    // ─── get_audio_waveform_for_clip_only_in_specific_track ──────────────────

    #[test]
    fn get_audio_waveform_for_clip_only_in_specific_track_missing_track_returns_none() {
        let ctx = make_ctx();
        let bogus_id = TrackId::from(99999);
        let result: Option<Vec<u32>> =
            audio_waveform_api::get_audio_waveform_for_clip_only_in_specific_track(
                &ctx,
                &bogus_id,
                |id, _w| id.to_u32(),
            );
        assert!(result.is_none(), "Missing TrackId should return None");
    }

    #[test]
    fn get_audio_waveform_for_clip_only_in_specific_track_midi_track_returns_empty() {
        // MIDI tracks are not audio tracks → should return Some(empty), not None
        let (ctx, _audio_id, midi_id, _pat_id) = make_seeded_ctx();
        let result: Option<Vec<u32>> =
            audio_waveform_api::get_audio_waveform_for_clip_only_in_specific_track(
                &ctx,
                &midi_id,
                |id, _w| id.to_u32(),
            );
        assert!(result.is_some(), "MIDI track should return Some(...)");
        assert!(
            result.unwrap().is_empty(),
            "MIDI track should have empty audio waveform list"
        );
    }

    // ─── get_audio_waveform_for_clip_all_available_in_tracks ─────────────────

    #[test]
    fn get_audio_waveform_for_clip_all_available_in_tracks_empty_state() {
        let ctx = make_ctx();
        let result: Vec<u32> =
            audio_waveform_api::get_audio_waveform_for_clip_all_available_in_tracks(
                &ctx,
                |id, _w| id,
            )
            .expect("Should succeed");
        assert!(result.is_empty());
    }

    // ─── get_audio_source_list ───────────────────────────────────────────────

    #[test]
    fn get_audio_source_list_empty() {
        let ctx = make_ctx();
        let result: Vec<u32> =
            audio_waveform_api::get_audio_source_list(&ctx, |id, _w| id).expect("Should succeed");
        assert!(result.is_empty());
    }

    // ─── add_audio_source ────────────────────────────────────────────────────

    #[test]
    fn add_audio_source_invalid_path_returns_err() {
        let mut ctx = make_ctx();
        let result = audio_waveform_api::add_audio_source(&mut ctx, "nonexistent_file_xyz.wav");
        assert!(result.is_err(), "Invalid path should return Err");
    }

    // ─── get_audio_waveform ──────────────────────────────────────────────────

    #[test]
    fn get_audio_waveform_unknown_id_returns_err() {
        let ctx = make_ctx();
        let result = audio_waveform_api::get_audio_waveform(&ctx, 99999, |_w| true);
        assert!(result.is_err(), "Unknown source_id should return Err");
    }
}
