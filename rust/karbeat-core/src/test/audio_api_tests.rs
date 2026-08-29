//! Tests for `api::audio_api`

#[cfg(test)]
mod tests {
    use crate::api::audio_api;
    use crate::api::track_api;
    use crate::commands::AudioCommand;
    use crate::shared::id::{AudioSourceId, TrackId};
    use crate::test::helpers::make_ctx;
    use rtrb::RingBuffer;

    #[test]
    fn get_audio_source_missing_returns_none() {
        let ctx = make_ctx();
        let bogus_id = AudioSourceId::from(99999);
        let result = audio_api::get_audio_source(&ctx, bogus_id, |_w| true);
        assert!(result.is_none(), "Unknown AudioSourceId should return None");
    }

    #[test]
    fn play_source_preview_missing_returns_err() {
        let mut ctx = make_ctx();
        let bogus_id = AudioSourceId::from(99999);
        let result = audio_api::play_source_preview(&mut ctx, bogus_id);
        assert!(result.is_err());
        let msg = result.unwrap_err().to_string();
        assert!(msg.contains("Audio source not found"), "Got: {}", msg);
    }

    #[test]
    fn stop_all_previews_with_no_stream_is_noop() {
        // Should not panic even though ring buffer is None
        let mut ctx = make_ctx();
        audio_api::stop_all_previews(&mut ctx);
    }

    #[test]
    fn play_file_preview_queues_a_fifteen_second_limit_without_importing() {
        let mut ctx = make_ctx();
        ctx.active_audio_config.write().sample_rate = Some(48_000);
        let (producer, mut consumer) = RingBuffer::<AudioCommand>::new(4);
        *ctx.command_sender.lock() = Some(producer);

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

        audio_api::play_file_preview(&mut ctx, file.path().to_str().expect("fixture path"))
            .expect("file preview should queue");

        match consumer.pop().expect("preview command") {
            AudioCommand::PlayPreview { max_frames, .. } => {
                assert_eq!(max_frames, 48_000 * 15);
            }
            _ => panic!("expected a browser preview command"),
        }
        assert!(ctx.app_state.asset_library.source_map.is_empty());
    }

    #[test]
    fn set_metronome_active_with_no_stream_is_noop() {
        let mut ctx = make_ctx();
        audio_api::set_metronome_active(&mut ctx, true);
        audio_api::set_metronome_active(&mut ctx, false);
    }

    #[test]
    fn get_audio_config_always_calls_mapper() {
        let ctx = make_ctx();
        let sample_rate = audio_api::get_audio_config(&ctx, |cfg| cfg.sample_rate);
        // Default sample rate is 48000
        assert!(sample_rate > 0, "Sample rate should be positive");
    }

    #[test]
    fn drain_position_feedback_returns_empty_when_no_stream() {
        let mut ctx = make_ctx();
        let results: Vec<u64> = audio_api::drain_position_feedback(&mut ctx, |_| 0u64);
        assert!(
            results.is_empty(),
            "Should return empty vec when consumer is None"
        );
    }

    #[test]
    fn play_preview_note_missing_track_returns_err() {
        let mut ctx = make_ctx();
        let bogus_id = TrackId::from(99999);
        let result = audio_api::play_preview_note(&mut ctx, bogus_id, 60, 100, true);
        assert!(result.is_err(), "Missing TrackId should return Err");
    }

    #[test]
    fn play_preview_note_on_audio_track_without_generator_returns_err() {
        let mut ctx = make_ctx();
        // Audio tracks have no generator
        let audio_track = track_api::add_new_audio_track(&mut ctx);
        let result = audio_api::play_preview_note(&mut ctx, audio_track.id, 60, 100, true);
        assert!(result.is_err(), "Audio track has no generator, should Err");
        let msg = result.unwrap_err().to_string();
        assert!(msg.contains("no generator"), "Got: {}", msg);
    }

    #[test]
    fn play_preview_note_generator_always_ok() {
        let mut ctx = make_ctx();
        // Generator ID directly (no lookup)
        use crate::shared::id::GeneratorId;
        let gen_id = GeneratorId::from(1);
        let result = audio_api::play_preview_note_generator(&mut ctx, gen_id, 60, 100, true);
        assert!(
            result.is_ok(),
            "Direct generator path should always succeed"
        );
    }
}
