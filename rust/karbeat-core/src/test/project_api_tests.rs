//! Tests for `api::project_api`

#[cfg(test)]
mod tests {
    use crate::api::project_api;
    use crate::test::helpers::{make_ctx, make_seeded_ctx};

    // ─── get_project_metadata ─────────────────────────────────────────────────

    #[test]
    fn get_project_metadata_happy_path() {
        let ctx = make_ctx();
        let result = project_api::get_project_metadata(&ctx, |m| m.name.clone());
        assert!(result.is_ok());
        // Default name is "Untitled"
        assert_eq!(result.unwrap(), "Untitled");
    }

    #[test]
    fn update_project_metadata_normalizes_and_replaces_metadata() {
        let mut ctx = make_ctx();
        let created_at = ctx.app_state.metadata.created_at;
        let metadata = crate::core::project::ProjectMetadata {
            name: "  New title  ".to_string(),
            author: " Author ".to_string(),
            description: " Description ".to_string(),
            genre: " Electronic ".to_string(),
            version: " 1.0 ".to_string(),
            created_at,
        };

        let updated = project_api::update_project_metadata(&mut ctx, metadata)
            .expect("metadata should be valid");

        assert_eq!(updated.name, "New title");
        assert_eq!(updated.description, "Description");
        assert_eq!(ctx.app_state.metadata.genre, "Electronic");
        assert_eq!(ctx.app_state.metadata.created_at, created_at);
    }

    #[test]
    fn update_project_metadata_rejects_empty_title() {
        let mut ctx = make_ctx();
        let mut metadata = ctx.app_state.metadata.clone();
        metadata.name = "   ".to_string();

        let result = project_api::update_project_metadata(&mut ctx, metadata);

        assert!(result.is_err());
        assert_eq!(ctx.app_state.metadata.name, "Untitled");
    }

    // ─── get_transport_state ──────────────────────────────────────────────────

    #[test]
    fn get_transport_state_happy_path() {
        let ctx = make_ctx();
        let result = project_api::get_transport_state(&ctx, |t| t.bpm);
        assert!(result.is_ok());
        let bpm = result.unwrap();
        assert!(bpm > 0.0, "Default BPM should be positive");
    }

    // ─── get_generator_list ───────────────────────────────────────────────────

    #[test]
    fn get_generator_list_empty_on_fresh_ctx() {
        let ctx = make_ctx();
        let result: Vec<u32> =
            project_api::get_generator_list(&ctx, |id, _g| id).expect("Should succeed");
        assert!(result.is_empty());
    }

    #[test]
    fn get_generator_list_has_generators_in_seeded_ctx() {
        let (ctx, _audio_id, _midi_id, _pat_id) = make_seeded_ctx();
        let result: Vec<u32> =
            project_api::get_generator_list(&ctx, |id, _g| id).expect("Should succeed");
        assert!(
            !result.is_empty(),
            "Seeded ctx should have at least one generator"
        );
    }

    // ─── new_blank_project ────────────────────────────────────────────────────

    #[test]
    fn new_blank_project_resets_state() {
        let (mut ctx, _audio_id, _midi_id, _pat_id) = make_seeded_ctx();
        assert!(
            !ctx.app_state.tracks.is_empty(),
            "Should have tracks before reset"
        );

        let _new_state = project_api::new_blank_project(&mut ctx);
        assert!(
            ctx.app_state.tracks.is_empty(),
            "Tracks should be cleared after new project"
        );
        assert!(
            ctx.app_state.pattern_pool.is_empty(),
            "Patterns should be cleared"
        );
        assert!(
            ctx.app_state.generator_pool.is_empty(),
            "Generators should be cleared"
        );
    }

    // ─── save_project + load_project (roundtrip) ─────────────────────────────

    #[test]
    fn save_project_to_temp_file_succeeds() {
        let mut ctx = make_ctx();
        let dir = tempfile::tempdir().expect("tempdir should be created");
        let path = dir.path().join("test_project.karbeat");
        let path_str = path.to_str().expect("path to str");

        // No audio thread → feedback consumer is None → timeout fires immediately and saves
        let result = project_api::save_project(&mut ctx, path_str);
        assert!(
            result.is_ok(),
            "Save to temp file should succeed: {:?}",
            result.err()
        );
        assert!(path.exists(), "File should have been created on disk");
    }

    #[test]
    fn load_project_from_nonexistent_path_returns_err() {
        let mut ctx = make_ctx();
        let result =
            project_api::load_project(&mut ctx, "/nonexistent/path/project.karbeat", |_| ());
        assert!(result.is_err(), "Loading non-existent file should Err");
    }

    #[test]
    fn load_project_roundtrip_preserves_metadata() {
        let mut ctx = make_ctx();
        // Set custom project metadata
        ctx.app_state.metadata.name = "RoundtripTest".to_string();
        ctx.app_state.metadata.description = "Roundtrip description".to_string();
        ctx.app_state.metadata.genre = "Ambient".to_string();

        let dir = tempfile::tempdir().expect("tempdir");
        let path = dir.path().join("roundtrip.karbeat");
        let path_str = path.to_str().unwrap();

        // Save
        project_api::save_project(&mut ctx, path_str).expect("Save should succeed");

        // Load into a fresh context
        let mut ctx2 = make_ctx();
        ctx2.active_audio_config.write().sample_rate = Some(48_000);
        let loaded_metadata =
            project_api::load_project(&mut ctx2, path_str, |state| state.metadata.clone());
        assert!(loaded_metadata.is_ok(), "{:?}", loaded_metadata.err());
        let loaded_metadata = loaded_metadata.unwrap();
        assert_eq!(loaded_metadata.name, "RoundtripTest");
        assert_eq!(loaded_metadata.description, "Roundtrip description");
        assert_eq!(loaded_metadata.genre, "Ambient");
    }

    // ─── hydrate_live_audio_engine ────────────────────────────────────────────

    #[test]
    fn hydrate_live_audio_engine_empty_state_returns_ok() {
        let mut ctx = make_ctx();
        let result = project_api::hydrate_live_audio_engine(&mut ctx);
        assert!(result.is_ok(), "Hydrating empty state should succeed");
    }

    #[test]
    fn hydrate_live_audio_engine_with_generators_returns_ok() {
        let (mut ctx, _audio_id, _midi_id, _pat_id) = make_seeded_ctx();
        let result = project_api::hydrate_live_audio_engine(&mut ctx);
        assert!(result.is_ok(), "{:?}", result.err());
    }
}
