//! Tests for `api::transport_api`

#[cfg(test)]
mod tests {
    use crate::api::transport_api;
    use crate::audio::engine::PlaybackMode;
    use crate::shared::id::{GeneratorId, PatternId};
    use crate::test::helpers::{make_ctx, make_seeded_ctx};

    // ─── set_playing ─────────────────────────────────────────────────────────

    #[test]
    fn set_playing_no_stream_returns_ok() {
        let mut ctx = make_ctx();
        let result = transport_api::set_playing(&mut ctx, true);
        assert!(result.is_ok());
        let result = transport_api::set_playing(&mut ctx, false);
        assert!(result.is_ok());
    }

    // ─── set_playhead ─────────────────────────────────────────────────────────

    #[test]
    fn set_playhead_no_stream_is_noop() {
        let mut ctx = make_ctx();
        transport_api::set_playhead(&mut ctx, 0);
        transport_api::set_playhead(&mut ctx, u32::MAX);
    }

    // ─── set_looping ──────────────────────────────────────────────────────────

    #[test]
    fn set_looping_no_stream_is_noop() {
        let mut ctx = make_ctx();
        transport_api::set_looping(&mut ctx, true);
        transport_api::set_looping(&mut ctx, false);
    }

    // ─── set_bpm ──────────────────────────────────────────────────────────────

    #[test]
    fn set_bpm_updates_transport_state() {
        let mut ctx = make_ctx();
        transport_api::set_bpm(&mut ctx, 140.0);
        // AppState should be updated immediately (independent of ring buffer)
        assert_eq!(ctx.app_state.transport.bpm, 140.0);
    }

    #[test]
    fn set_bpm_zero_is_accepted_no_panic() {
        let mut ctx = make_ctx();
        transport_api::set_bpm(&mut ctx, 0.0);
        assert_eq!(ctx.app_state.transport.bpm, 0.0);
    }

    #[test]
    fn set_bpm_negative_is_accepted_no_panic() {
        // No validation in the API layer — passes through
        let mut ctx = make_ctx();
        transport_api::set_bpm(&mut ctx, -10.0);
        assert_eq!(ctx.app_state.transport.bpm, -10.0);
    }

    // ─── stop_song_playback ───────────────────────────────────────────────────

    #[test]
    fn stop_song_playback_no_stream_is_noop() {
        let mut ctx = make_ctx();
        transport_api::stop_song_playback(&mut ctx);
    }

    // ─── toggle_pattern_playback ─────────────────────────────────────────────

    #[test]
    fn toggle_pattern_playback_no_stream_is_noop() {
        let mut ctx = make_ctx();
        let pat_id = PatternId::from(1);
        let gen_id = GeneratorId::from(1);
        transport_api::toggle_pattern_playback(&mut ctx, pat_id, gen_id);
    }

    // ─── toggle_playing_with_playback ─────────────────────────────────────────

    #[test]
    fn toggle_playing_with_playback_no_stream_is_noop() {
        let mut ctx = make_ctx();
        transport_api::toggle_playing_with_playback(&mut ctx, PlaybackMode::Song);
    }

    // ─── switch_pattern_generator ────────────────────────────────────────────

    #[test]
    fn switch_pattern_generator_no_stream_is_noop() {
        let mut ctx = make_ctx();
        let gen_id = GeneratorId::from(1);
        transport_api::switch_pattern_generator(&mut ctx, gen_id);
    }
}
