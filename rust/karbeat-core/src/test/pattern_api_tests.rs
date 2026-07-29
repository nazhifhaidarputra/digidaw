//! Tests for `api::pattern_api`

#[cfg(test)]
mod tests {
    use crate::api::pattern_api;
    use crate::shared::id::{GeneratorId, PatternId};
    use crate::test::helpers::{make_ctx, make_seeded_ctx};

    // ─── get_pattern ──────────────────────────────────────────────────────────

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

    // ─── get_patterns ────────────────────────────────────────────────────────

    #[test]
    fn get_patterns_empty_pool_returns_empty() {
        let ctx = make_ctx();
        let result: Vec<u32> =
            pattern_api::get_patterns(&ctx, |id, _p| id).expect("Should succeed");
        assert!(result.is_empty());
    }

    #[test]
    fn get_patterns_maps_all_in_pool() {
        let (ctx, _audio_id, _midi_id, _pattern_id) = make_seeded_ctx();
        let ids: Vec<u32> = pattern_api::get_patterns(&ctx, |id, _p| id).expect("Should succeed");
        assert!(
            !ids.is_empty(),
            "Seeded context should have at least one pattern"
        );
        assert_eq!(ids.len(), ctx.app_state.pattern_pool.len());
    }

    // ─── play_pattern_preview ─────────────────────────────────────────────────

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
            .cloned()
            .expect("Seeded ctx should have a generator");
        let result = pattern_api::play_pattern_preview(&mut ctx, pattern_id, gen_id);
        assert!(result.is_ok(), "No-stream should silently succeed");
    }

    // ─── stop_pattern_preview_local ──────────────────────────────────────────

    #[test]
    fn stop_pattern_preview_local_no_stream_returns_ok() {
        let (mut ctx, _audio_id, _midi_id, pattern_id) = make_seeded_ctx();
        let gen_id = ctx
            .app_state
            .generator_pool
            .keys()
            .next()
            .cloned()
            .expect("Seeded ctx should have a generator");
        let result = pattern_api::stop_pattern_preview_local(&mut ctx, pattern_id, gen_id);
        assert!(result.is_ok());
    }

    // ─── stop_pattern_preview ────────────────────────────────────────────────

    #[test]
    fn stop_pattern_preview_no_stream_returns_ok() {
        let mut ctx = make_ctx();
        let result = pattern_api::stop_pattern_preview(&mut ctx);
        assert!(result.is_ok());
    }
}
