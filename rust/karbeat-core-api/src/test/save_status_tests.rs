//! Tests for unsaved-change tracking (`SessionState`) across the API surface.

#[cfg(test)]
mod tests {
    use std::time::Duration;

    use crate::test::helpers::{make_ctx, make_seeded_ctx, mitigation_root};
    use crate::{
        audio_api, automation_api, clipboard_api, mitigation_api, mixer_api, note_api, pattern_api,
        project_api, track_api, transport_api,
    };
    use karbeat_core::commands::MixerChannelTarget;
    use karbeat_core::context::DawContext;
    use karbeat_core::core::mitigation::AutoSaveSettings;
    use karbeat_core::core::project::{MixerChannelParams, ModulationSource};

    fn saved_ctx() -> (
        DawContext,
        karbeat_core::shared::TrackId,
        karbeat_core::shared::TrackId,
        karbeat_core::shared::PatternId,
    ) {
        let (mut ctx, audio, midi, pattern) = make_seeded_ctx();
        let revision = ctx.app_state.session.revision();
        ctx.app_state.session.mark_saved_at(revision);
        assert!(mitigation_api::is_project_saved(&ctx));
        (ctx, audio, midi, pattern)
    }

    fn assert_dirties(name: &str, edit: impl FnOnce(&mut DawContext)) {
        let (mut ctx, ..) = saved_ctx();
        edit(&mut ctx);
        assert!(
            !mitigation_api::is_project_saved(&ctx),
            "{name} should mark the project unsaved"
        );
    }

    #[test]
    fn fresh_and_blank_projects_start_saved() {
        let mut ctx = make_ctx();
        assert!(mitigation_api::is_project_saved(&ctx));

        track_api::add_new_audio_track(&mut ctx);
        assert!(!mitigation_api::is_project_saved(&ctx));

        project_api::new_blank_project(&mut ctx).expect("blank project");
        assert!(mitigation_api::is_project_saved(&ctx));
    }

    #[test]
    fn history_backed_edits_mark_unsaved() {
        let (mut ctx, _, _, pattern) = saved_ctx();
        note_api::add_note(&mut ctx, pattern, 72, 1920, Some(480)).expect("add note");
        assert!(!mitigation_api::is_project_saved(&ctx));
    }

    #[test]
    fn undo_marks_unsaved_even_back_to_the_saved_point() {
        let (mut ctx, _, _, pattern) = make_seeded_ctx();
        note_api::add_note(&mut ctx, pattern, 72, 1920, Some(480)).expect("add note");
        crate::undo(&mut ctx).expect("undo");
        let revision = ctx.app_state.session.revision();
        ctx.app_state.session.mark_saved_at(revision);

        crate::redo(&mut ctx).expect("redo");
        assert!(!mitigation_api::is_project_saved(&ctx));
    }

    #[test]
    fn non_history_project_edits_mark_unsaved() {
        assert_dirties("rename track", |ctx| {
            let track = ctx.app_state.tracks.keys().next().expect("track");
            track_api::change_track_name(ctx, track, "Drums").expect("rename");
        });
        assert_dirties("reorder track", |ctx| {
            let track = ctx.app_state.tracks.keys().next().expect("track");
            track_api::update_track_order(ctx, track, 1).expect("reorder");
        });
        assert_dirties("rename pattern", |ctx| {
            let pattern = ctx.app_state.pattern_pool.keys().next().expect("pattern");
            pattern_api::rename_pattern(ctx, pattern, "Hook").expect("rename");
        });
        assert_dirties("bpm", |ctx| {
            transport_api::set_bpm(ctx, 128.0).unwrap();
        });
        assert_dirties("metadata", |ctx| {
            let mut metadata = ctx.app_state.metadata.clone();
            metadata.name = "Renamed".into();
            project_api::update_project_metadata(ctx, metadata).expect("metadata");
        });
        assert_dirties("create bus", |ctx| {
            mixer_api::create_bus(ctx, "Reverb".into());
        });
        assert_dirties("mixer fader", |ctx| {
            mixer_api::set_mixer_channel_param(
                ctx,
                MixerChannelTarget::Master,
                MixerChannelParams::Volume(-6.0),
            );
        });
        assert_dirties("modulation source", |ctx| {
            automation_api::add_modulation_source(ctx, ModulationSource::LFO { rate_hz: 2.0 });
        });
    }

    #[test]
    fn transport_preview_and_clipboard_copy_keep_project_saved() {
        let (mut ctx, _, _, pattern) = saved_ctx();
        let note_ids = ctx
            .app_state
            .pattern_pool
            .get(pattern)
            .expect("seeded pattern")
            .notes
            .iter()
            .map(|note| note.id)
            .collect();

        transport_api::set_playing(&mut ctx, true).expect("play without a stream");
        transport_api::set_playhead(&mut ctx, 1024);
        transport_api::set_looping(&mut ctx, true);
        transport_api::stop_song_playback(&mut ctx);
        audio_api::set_metronome_active(&mut ctx, true);
        audio_api::stop_all_previews(&mut ctx);
        clipboard_api::copy_pattern_notes(&mut ctx, pattern, note_ids, |_| ()).expect("copy notes");
        mitigation_api::set_auto_save_settings(&mut ctx, AutoSaveSettings::default())
            .expect("settings");

        assert!(mitigation_api::is_project_saved(&ctx));
    }

    #[test]
    fn edit_during_save_keeps_project_unsaved() {
        let (mut ctx, _, _, pattern) = make_seeded_ctx();
        let dir = tempfile::tempdir().expect("tempdir");
        let path = dir.path().join("race.dgdaw");
        let path = path.to_str().expect("utf-8 path");

        let pending = project_api::begin_save_project(&ctx, path);
        note_api::add_note(&mut ctx, pattern, 72, 1920, Some(480)).expect("edit during save");
        let completed = project_api::execute_save_project(pending).expect("save");
        project_api::commit_save_project(&mut ctx, completed);

        assert!(!mitigation_api::is_project_saved(&ctx));
        assert_eq!(
            ctx.app_state.session.file_path(),
            Some(std::path::Path::new(path))
        );

        project_api::save_project(&mut ctx, path).expect("second save");
        assert!(mitigation_api::is_project_saved(&ctx));
    }

    #[test]
    fn loaded_project_is_saved_and_remembers_its_file() {
        let (mut ctx, ..) = make_seeded_ctx();
        let dir = tempfile::tempdir().expect("tempdir");
        let path = dir.path().join("loaded.dgdaw");
        let path = path.to_str().expect("utf-8 path");
        project_api::save_project(&mut ctx, path).expect("save");

        let mut loaded_ctx = make_ctx();
        track_api::add_new_audio_track(&mut loaded_ctx);
        project_api::load_project(&mut loaded_ctx, path, |_| ()).expect("load");

        assert!(mitigation_api::is_project_saved(&loaded_ctx));
        assert_eq!(
            loaded_ctx.app_state.session.file_path(),
            Some(std::path::Path::new(path))
        );
    }

    #[test]
    fn auto_save_writes_recovery_without_marking_saved() {
        let mut ctx = make_ctx();
        mitigation_api::configure(&mut ctx, &mitigation_root("auto_save"), "test")
            .expect("configure");
        assert!(mitigation_api::begin_auto_save(&ctx).is_none());

        track_api::add_new_audio_track(&mut ctx);
        let pending = mitigation_api::begin_auto_save(&ctx).expect("dirty project auto saves");
        let revision = mitigation_api::execute_auto_save(pending).expect("auto save");
        mitigation_api::commit_auto_save(&mut ctx, revision);

        assert!(!mitigation_api::is_project_saved(&ctx));
        assert!(mitigation_api::begin_auto_save(&ctx).is_none());

        let recovered = mitigation_api::load_recovery_file(&ctx, 48_000).expect("recover");
        assert_eq!(recovered.tracks.len(), 1);
        assert!(!recovered.session.is_saved());

        mitigation_api::mark_clean_shutdown(&ctx).expect("clean shutdown");
        assert!(mitigation_api::load_recovery_file(&ctx, 48_000).is_err());
    }

    #[test]
    fn suspending_the_session_keeps_the_recovery_copy() {
        let mut ctx = make_ctx();
        mitigation_api::configure(&mut ctx, &mitigation_root("suspend"), "test")
            .expect("configure");
        track_api::add_new_audio_track(&mut ctx);
        let pending = mitigation_api::begin_auto_save(&ctx).expect("dirty project auto saves");
        mitigation_api::execute_auto_save(pending).expect("auto save");
        let marker = ctx
            .mitigation
            .as_ref()
            .expect("configured")
            .session_marker
            .clone();

        mitigation_api::set_session_suspended(&ctx, true).expect("suspend");
        assert!(!marker.exists());
        assert!(mitigation_api::load_recovery_file(&ctx, 48_000).is_ok());

        mitigation_api::set_session_suspended(&ctx, false).expect("resume");
        assert!(marker.exists());
    }

    #[test]
    fn disabled_auto_save_does_nothing() {
        let mut ctx = make_ctx();
        mitigation_api::configure(&mut ctx, &mitigation_root("auto_save_disabled"), "test")
            .expect("configure");
        mitigation_api::set_auto_save_settings(
            &mut ctx,
            AutoSaveSettings {
                every_seconds: Duration::from_secs(60),
                is_enabled: false,
            },
        )
        .expect("settings");

        track_api::add_new_audio_track(&mut ctx);
        assert!(mitigation_api::begin_auto_save(&ctx).is_none());
    }
}
