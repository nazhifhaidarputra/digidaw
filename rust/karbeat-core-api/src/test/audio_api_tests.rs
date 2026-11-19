//! Tests for `api::audio_api`

#[cfg(test)]
mod tests {
    use crate::audio_api;
    use crate::test::helpers::make_ctx;
    use crate::track_api;
    use hound::{SampleFormat, WavSpec, WavWriter};
    use karbeat_audio::commands::AudioCommand;
    use karbeat_core::shared::id::{AudioSourceId, GeneratorId, TrackId};
    use rtrb::RingBuffer;
    use std::f32::consts::TAU;
    use tempfile::tempdir;

    /// Sign changes in the middle half of `samples`, away from the stretcher's edges.
    fn zero_crossings(samples: &[f32]) -> usize {
        let quarter = samples.len().div_euclid(4);
        let middle = samples
            .get(quarter..samples.len().saturating_sub(quarter))
            .unwrap_or_default();
        middle
            .windows(2)
            .filter(|pair| matches!(pair, [a, b] if (*a < 0.0) != (*b < 0.0)))
            .count()
    }

    #[test]
    fn rendered_metronome_sound_is_read_back_with_an_octave_up_downbeat_of_equal_length() {
        let source_dir = tempdir().expect("source folder");
        let source = source_dir.path().join("click.wav");
        let spec = WavSpec {
            channels: 2,
            sample_rate: 44_100,
            bits_per_sample: 16,
            sample_format: SampleFormat::Int,
        };
        let frames = 11_025;
        let mut writer = WavWriter::create(&source, spec).expect("source writer");
        for frame in 0..frames {
            let value = (frame as f32 * 441.0 * TAU / 44_100.0).sin() * 0.5;
            let sample = (value * f32::from(i16::MAX)) as i16;
            writer.write_sample(sample).expect("left sample");
            writer.write_sample(sample).expect("right sample");
        }
        writer.finalize().expect("finalize source");
        let folder = tempdir().expect("metronome folder");

        audio_api::render_metronome_sound(source.to_str().expect("source path"), folder.path())
            .expect("render clicks");
        let click = audio_api::read_metronome_sound(folder.path()).expect("read clicks");

        assert_eq!(click.sample_rate, 44_100);
        assert_eq!(click.offbeat.len(), frames);
        assert_eq!(click.downbeat.len(), frames);
        let ratio = zero_crossings(&click.downbeat) as f32 / zero_crossings(&click.offbeat) as f32;
        assert!((1.8..2.2).contains(&ratio), "downbeat pitch ratio {ratio}");
    }

    #[test]
    fn reading_a_metronome_folder_without_clicks_fails() {
        let folder = tempdir().expect("metronome folder");

        assert!(audio_api::read_metronome_sound(folder.path()).is_err());
    }

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
    fn play_preview_note_generator_without_audio_stream_returns_err() {
        let mut ctx = make_ctx();
        let gen_id = GeneratorId::from(1);
        let result = audio_api::play_preview_note_generator(&mut ctx, gen_id, 60, 100, true);
        assert!(result.is_err(), "An unavailable audio queue should fail");
        assert!(
            result.unwrap_err().to_string().contains("not initialized"),
            "The error should identify the unavailable audio stream"
        );
    }
}
