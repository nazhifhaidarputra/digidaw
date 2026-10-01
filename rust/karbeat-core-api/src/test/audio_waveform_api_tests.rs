//! Tests for `api::audio_waveform_api`

#[cfg(test)]
mod tests {
    use crate::{audio_waveform_api, clip_api, clipboard_api};

    use crate::test::helpers::{add_dc_audio_source, make_ctx, make_seeded_ctx};
    use karbeat_core::context::DawContext;
    use karbeat_core::core::project::{ClipboardContent, clip::ClipSourceType};
    use karbeat_core::shared::id::{AudioSourceId, ClipId, TrackId};

    /// Clip IDs listed on a track, in track order.
    fn clips_on(ctx: &DawContext, track: TrackId) -> Vec<ClipId> {
        ctx.app_state.tracks[track].clips.clone()
    }

    #[test]
    fn removing_an_audio_source_deletes_its_clips_and_undoes_in_one_step() {
        let (mut ctx, audio, midi, _) = make_seeded_ctx();
        let source = add_dc_audio_source(&mut ctx);
        let other = add_dc_audio_source(&mut ctx);
        let mut add = |source: AudioSourceId, start: u32| {
            clip_api::add_clip(
                &mut ctx,
                Some(source.to_u64()),
                ClipSourceType::Audio,
                audio,
                start,
            )
            .expect("audio clip")
            .id
        };
        let first = add(source, 0);
        let kept = add(other, 3_840);
        let second = add(source, 7_680);
        clipboard_api::copy_clips(&mut ctx, audio, &[first, kept]);
        let midi_clips = clips_on(&ctx, midi);
        let history_depth = ctx.history.undo_stack.len();

        let removed = audio_waveform_api::remove_audio_source(&mut ctx, source).expect("remove");

        assert_eq!(removed, 2);
        assert!(!ctx.app_state.asset_library.source_map.contains_key(source));
        assert!(ctx.app_state.asset_library.source_map.contains_key(other));
        assert_eq!(clips_on(&ctx, audio), [kept]);
        assert_eq!(clips_on(&ctx, midi), midi_clips);
        assert!(!ctx.app_state.clips_pool.contains_key(first));
        assert!(!ctx.app_state.clips_pool.contains_key(second));
        // Only the clip of the surviving source stays in the clipboard.
        match &ctx.app_state.clipboard {
            ClipboardContent::Clips(clips) => assert_eq!(clips.len(), 1),
            other => panic!("expected copied clips, found {other:?}"),
        }
        assert_eq!(ctx.history.undo_stack.len(), history_depth + 1);
        assert_eq!(ctx.history.undo_label(), Some("Delete Audio Source"));

        for _ in 0..2 {
            crate::undo(&mut ctx).expect("undo");
            assert!(ctx.app_state.asset_library.source_map.contains_key(source));
            assert_eq!(clips_on(&ctx, audio), [first, kept, second]);
            assert!(ctx.app_state.clips_pool.contains_key(first));

            crate::redo(&mut ctx).expect("redo");
            assert!(!ctx.app_state.asset_library.source_map.contains_key(source));
            assert_eq!(clips_on(&ctx, audio), [kept]);
        }
    }

    #[test]
    fn removing_an_unknown_audio_source_changes_nothing() {
        let (mut ctx, audio, ..) = make_seeded_ctx();
        let source = add_dc_audio_source(&mut ctx);
        clip_api::add_clip(
            &mut ctx,
            Some(source.to_u64()),
            ClipSourceType::Audio,
            audio,
            0,
        )
        .expect("audio clip");
        let history_depth = ctx.history.undo_stack.len();

        let result = audio_waveform_api::remove_audio_source(&mut ctx, AudioSourceId::from(99999));

        assert!(result.is_err());
        assert_eq!(clips_on(&ctx, audio).len(), 1);
        assert_eq!(ctx.history.undo_stack.len(), history_depth);
    }

    #[test]
    fn get_audio_waveform_clips_data_empty_state() {
        let ctx = make_ctx();
        let result: Vec<u64> =
            audio_waveform_api::get_audio_waveform_clips_data(&ctx, |id, _w| id.to_u64())
                .expect("Should succeed on empty state");
        assert!(result.is_empty());
    }

    #[test]
    fn get_audio_waveform_for_clip_missing_source_returns_err() {
        let ctx = make_ctx();
        let bogus_id = AudioSourceId::from(99999);
        let result = audio_waveform_api::get_audio_waveform_for_clip(&ctx, &bogus_id);
        assert!(result.is_err(), "Unknown AudioSourceId should return Err");
    }

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

    #[test]
    fn get_audio_waveform_for_clip_all_available_in_tracks_empty_state() {
        let ctx = make_ctx();
        let result: Vec<u64> =
            audio_waveform_api::get_audio_waveform_for_clip_all_available_in_tracks(
                &ctx,
                |id, _w| id,
            )
            .expect("Should succeed");
        assert!(result.is_empty());
    }

    #[test]
    fn get_audio_source_list_empty() {
        let ctx = make_ctx();
        let result: Vec<u64> =
            audio_waveform_api::get_audio_source_list(&ctx, |id, _w| id).expect("Should succeed");
        assert!(result.is_empty());
    }

    #[test]
    fn add_audio_source_invalid_path_returns_err() {
        let mut ctx = make_ctx();
        let result = audio_waveform_api::add_audio_source(&mut ctx, "nonexistent_file_xyz.wav");
        assert!(result.is_err(), "Invalid path should return Err");
    }

    #[test]
    fn add_audio_source_reuses_an_existing_file_source() {
        let mut ctx = make_ctx();
        ctx.active_audio_config.write().sample_rate = Some(48_000);
        let file = tempfile::NamedTempFile::new().expect("audio fixture file");
        let spec = hound::WavSpec {
            channels: 1,
            sample_rate: 48_000,
            bits_per_sample: 16,
            sample_format: hound::SampleFormat::Int,
        };
        let mut writer = hound::WavWriter::new(file.reopen().expect("fixture handle"), spec)
            .expect("fixture writer");
        writer.write_sample(0_i16).expect("fixture sample");
        writer.finalize().expect("finalize fixture");
        let path = file.path().to_str().expect("fixture path");

        let first = audio_waveform_api::add_audio_source(&mut ctx, path)
            .expect("first source import should succeed");
        let second = audio_waveform_api::add_audio_source(&mut ctx, path)
            .expect("second source import should succeed");

        assert_eq!(first, second);
        assert_eq!(ctx.app_state.asset_library.source_map.len(), 1);
    }

    #[test]
    fn get_audio_waveform_unknown_id_returns_err() {
        let ctx = make_ctx();
        let result = audio_waveform_api::get_audio_waveform(&ctx, 99999, |_w| true);
        assert!(result.is_err(), "Unknown source_id should return Err");
    }
}
