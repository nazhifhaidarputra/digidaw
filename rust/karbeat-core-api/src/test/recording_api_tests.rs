//! Tests for turning recorded takes into clips.

#[cfg(test)]
mod tests {
    use crate as api;
    use crate::{audio_waveform_api, recording_api, track_api};
    use karbeat_audio::recording::RecordedTake;
    use karbeat_core::core::project::{DawSource, TrackInputSettings};

    use crate::test::helpers::make_ctx;
    use karbeat_audio::commands::AudioCommand;

    /// A context whose audio commands queue up on the returned consumer, standing in for the
    /// engine.
    fn ctx_with_engine_queue() -> (
        karbeat_audio::context::DawContext,
        rtrb::Consumer<AudioCommand>,
    ) {
        let ctx = make_ctx();
        let (producer, consumer) = rtrb::RingBuffer::new(64);
        *ctx.command_sender.lock() = Some(producer);
        (ctx, consumer)
    }

    /// A finished take of `frames` stereo frames written to `dir`.
    fn recorded_take(
        dir: &tempfile::TempDir,
        track_id: karbeat_core::shared::TrackId,
        frames: u64,
    ) -> RecordedTake {
        let path = dir.path().join("Recording_2026-10-30T14-05-33+07-00.wav");
        let spec = hound::WavSpec {
            channels: 2,
            sample_rate: 48_000,
            bits_per_sample: 32,
            sample_format: hound::SampleFormat::Float,
        };
        let mut writer = hound::WavWriter::create(&path, spec).expect("take fixture");
        for _ in 0..frames * 2 {
            writer.write_sample(0.25_f32).expect("take sample");
        }
        writer.finalize().expect("take fixture");
        RecordedTake {
            track_id,
            path,
            name: "Recording_2026-10-30T14:05:33+07:00".into(),
            start_playhead_samples: 48_000,
            frames,
            sample_rate: 48_000,
        }
    }

    #[test]
    fn a_take_becomes_a_named_clip_where_it_started_and_undo_removes_it() {
        let mut ctx = make_ctx();
        ctx.app_state.transport.bpm = 120.0;
        ctx.app_state.audio_config.sample_rate = 48_000;
        ctx.audio_runtime_settings.write().requested_dsp.sample_rate = 48_000;
        let track = track_api::add_new_audio_track(&mut ctx);
        let dir = tempfile::tempdir().expect("temporary dir");
        let take = recorded_take(&dir, track.id, 24_000);

        let pending = recording_api::begin_take_import(&ctx, &take).expect("import begins");
        let completed = audio_waveform_api::execute_audio_import(pending).expect("decodes");
        let updated = recording_api::commit_take(&mut ctx, &take, completed).expect("commits");

        assert_eq!(updated.clips.len(), 1);
        let clip = &ctx.app_state.clips_pool[updated.clips[0]];
        assert_eq!(clip.name, "Recording_2026-10-30T14:05:33+07:00");
        // One second at 120 BPM is two beats of 960 ticks.
        assert_eq!(clip.time.start_time_raw(), 1_920);
        let Some(DawSource::Audio(source_id)) = clip.source else {
            panic!("a take is an audio clip");
        };
        assert_eq!(
            ctx.app_state.asset_library.source_map[source_id].name,
            "Recording_2026-10-30T14:05:33+07:00"
        );

        api::undo(&mut ctx).expect("the take can be undone");
        assert!(ctx.app_state.tracks[track.id].clips.is_empty());
    }

    #[test]
    fn a_take_that_never_played_adds_nothing() {
        let (mut ctx, mut engine) = ctx_with_engine_queue();
        let track = track_api::add_new_audio_track(&mut ctx);
        recording_api::start_track_recording(&mut ctx, track.id).expect("arms the track");
        assert_eq!(recording_api::recording_tracks(&ctx), vec![track.id]);
        assert!(recording_api::start_track_recording(&mut ctx, track.id).is_err());

        let finisher = recording_api::end_track_recording(&mut ctx, track.id).expect("ends");
        // The engine drops the take it never recorded into.
        drop(std::iter::from_fn(|| engine.pop().ok()).collect::<Vec<_>>());
        assert_eq!(finisher.wait().expect("the writer finishes"), None);
        assert!(recording_api::recording_tracks(&ctx).is_empty());
        assert!(ctx.app_state.tracks[track.id].clips.is_empty());
    }

    #[test]
    fn arming_without_an_engine_leaves_no_take() {
        let mut ctx = make_ctx();
        let track = track_api::add_new_audio_track(&mut ctx);
        assert!(recording_api::start_track_recording(&mut ctx, track.id).is_err());
        assert!(recording_api::recording_tracks(&ctx).is_empty());
    }

    #[test]
    fn arming_turns_the_input_on_and_midi_tracks_cannot_record() {
        let (mut ctx, _engine) = ctx_with_engine_queue();
        let track = track_api::add_new_audio_track(&mut ctx);
        let started = recording_api::start_track_recording(&mut ctx, track.id).expect("arms");
        assert!(started.enabled_input);
        assert!(ctx.audio_runtime_settings.read().requested_input.enabled);
        let again = track_api::add_new_audio_track(&mut ctx);
        let second = recording_api::start_track_recording(&mut ctx, again.id).expect("arms");
        assert!(!second.enabled_input);

        let (seeded, ..) = crate::test::helpers::make_seeded_ctx();
        let midi = seeded
            .app_state
            .tracks
            .iter()
            .find(|(_, track)| track.generator.is_some())
            .map(|(id, _)| id)
            .expect("the seeded project has a MIDI track");
        let mut seeded = seeded;
        assert!(recording_api::start_track_recording(&mut seeded, midi).is_err());
    }

    #[test]
    fn track_input_settings_apply_only_to_audio_tracks() {
        let mut ctx = make_ctx();
        let track = track_api::add_new_audio_track(&mut ctx);
        let input = TrackInputSettings {
            first_channel: 1,
            channels: 1,
            monitor: true,
        };
        let updated = track_api::set_track_input(&mut ctx, track.id, input).expect("sets input");
        assert_eq!(updated.input, input);
        let invalid = TrackInputSettings {
            channels: 3,
            ..input
        };
        assert!(track_api::set_track_input(&mut ctx, track.id, invalid).is_err());
    }
}
