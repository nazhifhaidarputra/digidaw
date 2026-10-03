//! Tests for tempo fitting, offline renders and beat grid commits.

#[cfg(test)]
mod tests {
    use std::sync::Arc;

    use karbeat_core::{
        context::DawContext,
        core::project::{
            AudioSourceId, DawSource,
            clip::{ClipSourceType, ClipTimeUnit, ResizeEdge},
            track::audio_waveform::{AudioSampleMode, AudioWaveform, BeatGrid},
        },
        shared::id::{ClipId, TrackId},
    };

    use crate::audio_analysis_api::{
        begin_fit_to_tempo, begin_refresh_render, cancel_stale_renders, commit_beat_grid,
        commit_render, execute_render, set_sample_mode, set_waveform_edits, set_waveform_pitch,
        sources_needing_render,
    };
    use crate::clip_api::{batch_resize_clips, resize_clip};
    use crate::test::helpers::{add_dc_audio_source, make_ctx};

    fn source(ctx: &DawContext, id: AudioSourceId) -> &AudioWaveform {
        &ctx.app_state.asset_library.source_map[id]
    }

    fn frames(buffer: &memmap2::Mmap, channels: usize) -> usize {
        buffer.len() / std::mem::size_of::<f32>() / channels
    }

    /// A source whose tempo detection found 120 BPM, in a 100 BPM project.
    fn setup() -> (DawContext, AudioSourceId) {
        let mut ctx = make_ctx();
        ctx.app_state.transport.bpm = 100.0;
        let id = add_dc_audio_source(&mut ctx);
        let waveform = Arc::make_mut(&mut ctx.app_state.asset_library.source_map[id]);
        waveform.original_bpm = Some(120.0);
        waveform.beat_grid = Some(BeatGrid {
            bpm: 120.0,
            confidence: 1.0,
            beats: vec![0.0, 0.5],
            downbeats: vec![0.0],
        });
        (ctx, id)
    }

    fn fit(ctx: &mut DawContext, id: AudioSourceId, warp: bool) {
        let pending = begin_fit_to_tempo(ctx, id, warp).unwrap();
        let completed = execute_render(pending, &|| false, &mut |_| {}).unwrap();
        assert!(commit_render(ctx, completed));
    }

    #[test]
    fn fit_renders_to_the_project_tempo_and_undo_restores_the_source() {
        let (mut ctx, id) = setup();

        fit(&mut ctx, id, false);

        let fitted = source(&ctx, id);
        assert_eq!(fitted.sample_mode, AudioSampleMode::Stretch);
        assert_eq!(fitted.original_bpm, Some(120.0));
        let edited = fitted.edited.as_ref().unwrap();
        assert!((edited.edits.time_ratio - 1.2).abs() < 1e-6);
        let rendered = Arc::clone(edited.buffer.as_ref().unwrap());
        assert!(frames(&rendered, 2).abs_diff(57_600) < 600);
        assert!((fitted.playback_bpm().unwrap() - 100.0).abs() < 1e-3);
        assert!(fitted.tempo_rate(100.0) > 0.999);

        crate::undo(&mut ctx).unwrap();
        let restored = source(&ctx, id);
        assert_eq!(restored.sample_mode, AudioSampleMode::Default);
        assert!(restored.edited.is_none());

        crate::redo(&mut ctx).unwrap();
        let redone = source(&ctx, id).edited.as_ref().unwrap();
        assert!(Arc::ptr_eq(redone.buffer.as_ref().unwrap(), &rendered));
    }

    #[test]
    fn render_is_discarded_when_the_source_changed_meanwhile() {
        let (mut ctx, id) = setup();
        let pending = begin_fit_to_tempo(&ctx, id, false).unwrap();
        let completed = execute_render(pending, &|| false, &mut |_| {}).unwrap();

        Arc::make_mut(&mut ctx.app_state.asset_library.source_map[id]).sample_mode =
            AudioSampleMode::Resampled;

        assert!(!commit_render(&mut ctx, completed));
        assert!(source(&ctx, id).edited.is_none());
    }

    #[test]
    fn cancelled_render_returns_an_error() {
        let (ctx, id) = setup();
        let pending = begin_fit_to_tempo(&ctx, id, false).unwrap();
        assert!(execute_render(pending, &|| true, &mut |_| {}).is_err());
    }

    #[test]
    fn beat_by_beat_fit_needs_detected_beats() {
        let mut ctx = make_ctx();
        let id = add_dc_audio_source(&mut ctx);
        assert!(begin_fit_to_tempo(&ctx, id, true).is_err());

        assert!(commit_beat_grid(
            &mut ctx,
            id,
            BeatGrid {
                bpm: 120.0,
                confidence: 1.0,
                beats: vec![0.0, 0.5],
                downbeats: vec![0.0],
            }
        ));
        fit(&mut ctx, id, true);
        assert!(source(&ctx, id).edited.as_ref().unwrap().edits.warp);
    }

    #[test]
    fn detected_tempo_is_undoable() {
        let mut ctx = make_ctx();
        let id = add_dc_audio_source(&mut ctx);
        let grid = BeatGrid {
            bpm: 128.0,
            confidence: 0.8,
            beats: vec![0.1, 0.57],
            downbeats: vec![0.1],
        };

        assert!(commit_beat_grid(&mut ctx, id, grid.clone()));
        assert_eq!(source(&ctx, id).original_bpm, Some(128.0));
        assert_eq!(source(&ctx, id).beat_grid.as_ref(), Some(&grid));

        crate::undo(&mut ctx).unwrap();
        assert_eq!(source(&ctx, id).original_bpm, None);
        assert!(source(&ctx, id).beat_grid.is_none());
    }

    #[test]
    fn fitting_needs_a_known_tempo() {
        let mut ctx = make_ctx();
        let id = add_dc_audio_source(&mut ctx);
        assert_eq!(source(&ctx, id).original_bpm, None);
        assert!(begin_fit_to_tempo(&ctx, id, false).is_err());
    }

    #[test]
    fn tempo_change_refits_stretched_sources() {
        let (mut ctx, id) = setup();
        assert!(sources_needing_render(&ctx).is_empty());
        fit(&mut ctx, id, false);

        ctx.app_state.transport.bpm = 150.0;
        assert_eq!(sources_needing_render(&ctx), vec![id]);
        let pending = begin_refresh_render(&ctx, id).unwrap().unwrap();
        let completed = execute_render(pending, &|| false, &mut |_| {}).unwrap();
        assert!(commit_render(&mut ctx, completed));

        let refitted = source(&ctx, id);
        let edited = refitted.edited.as_ref().unwrap();
        assert!((edited.edits.time_ratio - 0.8).abs() < 1e-6);
        assert!(frames(edited.buffer.as_ref().unwrap(), 2).abs_diff(38_400) < 600);
        assert!((refitted.playback_bpm().unwrap() - 150.0).abs() < 1e-3);
    }

    #[test]
    fn refresh_skips_a_render_that_already_matches_the_tempo() {
        let (mut ctx, id) = setup();
        fit(&mut ctx, id, false);
        assert!(begin_refresh_render(&ctx, id).unwrap().is_none());
    }

    #[test]
    fn a_render_for_an_old_tempo_is_not_committed() {
        let (mut ctx, id) = setup();
        fit(&mut ctx, id, false);
        ctx.app_state.transport.bpm = 150.0;
        let pending = begin_refresh_render(&ctx, id).unwrap().unwrap();
        let completed = execute_render(pending, &|| false, &mut |_| {}).unwrap();

        ctx.app_state.transport.bpm = 160.0;
        assert!(!commit_render(&mut ctx, completed));
        let kept = source(&ctx, id).edited.as_ref().unwrap();
        assert!((kept.edits.time_ratio - 1.2).abs() < 1e-6);
    }

    #[test]
    fn a_render_that_ignores_the_tempo_survives_a_tempo_change() {
        let mut ctx = make_ctx();
        let id = ramp_source(&mut ctx);
        assert!(set_waveform_edits(&mut ctx, id, false, false, true).unwrap());
        let pending = begin_refresh_render(&ctx, id).unwrap().unwrap();
        let completed = execute_render(pending, &|| false, &mut |_| {}).unwrap();

        ctx.app_state.transport.bpm += 20.0;
        assert!(commit_render(&mut ctx, completed));
    }

    #[test]
    fn a_tempo_change_cancels_a_running_stretch_render() {
        let (mut ctx, id) = setup();
        fit(&mut ctx, id, false);
        ctx.app_state.transport.bpm = 150.0;
        let pending = begin_refresh_render(&ctx, id).unwrap().unwrap();
        let running = pending.track();
        assert_eq!(cancel_stale_renders(&ctx), 0);
        assert!(!running.is_stale());

        ctx.app_state.transport.bpm = 160.0;
        assert_eq!(cancel_stale_renders(&ctx), 1);
        assert!(running.is_stale());
    }

    #[test]
    fn undo_cancels_a_render_of_the_undone_edit() {
        let (mut ctx, id) = setup();
        fit(&mut ctx, id, false);
        assert!(set_waveform_edits(&mut ctx, id, true, false, false).unwrap());
        let pending = begin_refresh_render(&ctx, id).unwrap().unwrap();
        let running = pending.track();

        // Undo brings back the fitted render: nothing needs rendering, yet the normalize
        // render in flight is stale.
        crate::undo(&mut ctx).unwrap();
        assert!(sources_needing_render(&ctx).is_empty());
        assert_eq!(cancel_stale_renders(&ctx), 1);
        assert!(running.is_stale());
    }

    #[test]
    fn a_render_stops_once_it_goes_stale() {
        let mut ctx = make_ctx();
        let id = long_source(&mut ctx, 70.0);
        Arc::make_mut(&mut ctx.app_state.asset_library.source_map[id]).original_bpm = Some(120.0);
        ctx.app_state.transport.bpm = 100.0;
        let pending = begin_fit_to_tempo(&ctx, id, false).unwrap();

        // The tempo changes while the render runs; only the stale check can stop it.
        let mut cancelled = 0;
        let result = execute_render(pending, &|| false, &mut |fraction| {
            if fraction > 0.0 && cancelled == 0 {
                ctx.app_state.transport.bpm = 90.0;
                cancelled = cancel_stale_renders(&ctx);
            }
        });
        assert_eq!(cancelled, 1);
        assert!(result.is_err());
    }

    #[test]
    fn a_long_source_renders_to_the_exact_stretched_length() {
        let mut ctx = make_ctx();
        let id = long_source(&mut ctx, 70.0);
        Arc::make_mut(&mut ctx.app_state.asset_library.source_map[id]).original_bpm = Some(120.0);
        ctx.app_state.transport.bpm = 100.0;
        fit(&mut ctx, id, false);
        let edited = source(&ctx, id).edited.as_ref().unwrap();
        let expected = (70.0 * 48_000.0 * 1.2_f64).round() as usize;
        let rendered = frames(edited.buffer.as_ref().unwrap(), 2);
        // Chunked renders are exact; a single-thread pool renders in one pass, within 1%.
        assert!(
            rendered.abs_diff(expected) <= expected / 100,
            "{rendered} of {expected}"
        );
    }

    /// A stereo 220 Hz source of `seconds` at 48 kHz.
    fn long_source(ctx: &mut DawContext, seconds: f64) -> AudioSourceId {
        let frames = (seconds * 48_000.0) as usize;
        let samples: Vec<f32> = (0..frames)
            .flat_map(|frame| {
                let value = (frame as f32 * 220.0 * std::f32::consts::TAU / 48_000.0).sin() * 0.5;
                [value, value]
            })
            .collect();
        let bytes: &[u8] = bytemuck::cast_slice(&samples);
        let mut map = memmap2::MmapOptions::new()
            .len(bytes.len())
            .map_anon()
            .unwrap();
        map.copy_from_slice(bytes);
        let buffer = Arc::new(map.make_read_only().unwrap());
        ctx.app_state
            .asset_library
            .source_map
            .insert_with_key(|id| {
                Arc::new(AudioWaveform {
                    id: Some(id),
                    buffer: Some(buffer),
                    sample_rate: 48_000,
                    channels: 2,
                    duration: seconds,
                    ..AudioWaveform::default()
                })
            })
    }

    /// A source whose left channel counts 0, 1, 2 ... and right channel is its negative.
    fn ramp_source(ctx: &mut DawContext) -> AudioSourceId {
        let samples: Vec<f32> = (0..4_800)
            .flat_map(|frame| {
                let value = frame as f32 / 4_800.0;
                [value, -value]
            })
            .collect();
        let bytes: &[u8] = bytemuck::cast_slice(&samples);
        let mut map = memmap2::MmapOptions::new()
            .len(bytes.len())
            .map_anon()
            .unwrap();
        map.copy_from_slice(bytes);
        let buffer = Arc::new(map.make_read_only().unwrap());
        ctx.app_state
            .asset_library
            .source_map
            .insert_with_key(|id| {
                Arc::new(AudioWaveform {
                    id: Some(id),
                    buffer: Some(buffer),
                    sample_rate: 48_000,
                    channels: 2,
                    ..AudioWaveform::default()
                })
            })
    }

    fn rendered(ctx: &DawContext, id: AudioSourceId) -> Vec<f32> {
        let buffer = source(ctx, id)
            .edited
            .as_ref()
            .unwrap()
            .buffer
            .clone()
            .unwrap();
        bytemuck::cast_slice::<u8, f32>(&buffer[..]).to_vec()
    }

    fn refresh(ctx: &mut DawContext, id: AudioSourceId) {
        let pending = begin_refresh_render(ctx, id).unwrap().unwrap();
        let completed = execute_render(pending, &|| false, &mut |_| {}).unwrap();
        assert!(commit_render(ctx, completed));
    }

    #[test]
    fn reverse_invert_and_normalize_render_without_stretching() {
        let mut ctx = make_ctx();
        let id = ramp_source(&mut ctx);
        assert!(set_waveform_edits(&mut ctx, id, true, true, true).unwrap());
        refresh(&mut ctx, id);

        let output = rendered(&ctx, id);
        assert_eq!(output.len(), 4_800 * 2);
        // Reversed: the last frame first. Inverted: left becomes negative.
        let last = 4_799.0 / 4_800.0;
        assert_eq!(&output[..2], &[-last, last]);
        assert_eq!(&output[output.len() - 2..], &[-0.0, 0.0]);
        let waveform = source(&ctx, id);
        assert!((waveform.playback_gain() - 1.0 / last).abs() < 1e-4);
        assert!(waveform.normalized);
    }

    #[test]
    fn edits_are_undoable_and_drop_the_stale_render() {
        let mut ctx = make_ctx();
        let id = ramp_source(&mut ctx);
        assert!(set_waveform_edits(&mut ctx, id, false, false, true).unwrap());
        refresh(&mut ctx, id);
        assert!(set_waveform_edits(&mut ctx, id, false, true, true).unwrap());
        assert!(source(&ctx, id).edited.as_ref().unwrap().buffer.is_none());

        crate::undo(&mut ctx).unwrap();
        let edits = &source(&ctx, id).edited.as_ref().unwrap().edits;
        assert!(edits.reverse && !edits.invert);
        crate::undo(&mut ctx).unwrap();
        assert!(source(&ctx, id).edited.is_none());
        assert!(!set_waveform_edits(&mut ctx, id, false, false, false).unwrap());
    }

    /// A one-second stereo 440 Hz sine source.
    fn sine_source(ctx: &mut DawContext) -> AudioSourceId {
        let samples: Vec<f32> = (0..48_000)
            .flat_map(|frame| {
                let value = (frame as f32 * 440.0 * std::f32::consts::TAU / 48_000.0).sin() * 0.5;
                [value, value]
            })
            .collect();
        let bytes: &[u8] = bytemuck::cast_slice(&samples);
        let mut map = memmap2::MmapOptions::new()
            .len(bytes.len())
            .map_anon()
            .unwrap();
        map.copy_from_slice(bytes);
        let buffer = Arc::new(map.make_read_only().unwrap());
        ctx.app_state
            .asset_library
            .source_map
            .insert_with_key(|id| {
                Arc::new(AudioWaveform {
                    id: Some(id),
                    buffer: Some(buffer),
                    sample_rate: 48_000,
                    channels: 2,
                    ..AudioWaveform::default()
                })
            })
    }

    /// Rising zero crossings of the left channel in the middle half second.
    fn middle_crossings(interleaved: &[f32]) -> usize {
        let left: Vec<f32> = interleaved.iter().step_by(2).copied().collect();
        left[12_000..36_000]
            .windows(2)
            .filter(|pair| pair[0] < 0.0 && pair[1] >= 0.0)
            .count()
    }

    #[test]
    fn pitch_edit_renders_and_is_undoable() {
        let mut ctx = make_ctx();
        let id = sine_source(&mut ctx);
        assert!(set_waveform_pitch(&mut ctx, id, 12.0, false).unwrap());
        refresh(&mut ctx, id);

        let output = rendered(&ctx, id);
        let frames = output.len() / 2;
        assert!(frames.abs_diff(48_000) <= 480, "{frames} frames");
        // An octave up doubles the 220 crossings of 440 Hz over half a second.
        let crossings = middle_crossings(&output);
        assert!((400..=480).contains(&crossings), "{crossings} crossings");

        assert!(set_waveform_pitch(&mut ctx, id, 100.0, true).unwrap());
        let edits = &source(&ctx, id).edited.as_ref().unwrap().edits;
        assert_eq!(edits.pitch_semitones, 24.0);
        assert!(edits.preserve_formants);
        assert!(set_waveform_pitch(&mut ctx, id, f32::NAN, false).is_err());

        crate::undo(&mut ctx).unwrap();
        let edits = &source(&ctx, id).edited.as_ref().unwrap().edits;
        assert_eq!(edits.pitch_semitones, 12.0);
        crate::undo(&mut ctx).unwrap();
        assert!(source(&ctx, id).edited.is_none());
    }

    #[test]
    fn leaving_stretch_mode_drops_the_tempo_fit() {
        let (mut ctx, id) = setup();
        fit(&mut ctx, id, false);
        assert!(!set_sample_mode(&mut ctx, id, AudioSampleMode::Resampled).unwrap());
        let waveform = source(&ctx, id);
        assert_eq!(waveform.sample_mode, AudioSampleMode::Resampled);
        assert!(waveform.edited.is_none());

        crate::undo(&mut ctx).unwrap();
        assert_eq!(source(&ctx, id).sample_mode, AudioSampleMode::Stretch);
        assert!(source(&ctx, id).edited.as_ref().unwrap().buffer.is_some());
    }

    #[test]
    fn stretch_without_a_detected_tempo_anchors_to_the_project_tempo() {
        let mut ctx = make_ctx();
        ctx.app_state.transport.bpm = 157.0;
        let id = add_dc_audio_source(&mut ctx);

        // Entering Stretch at 157 BPM: the audio plays as placed.
        assert!(!set_sample_mode(&mut ctx, id, AudioSampleMode::Stretch).unwrap());
        assert_eq!(source(&ctx, id).original_bpm, Some(157.0));
        assert_eq!(source(&ctx, id).tempo_rate(157.0), 1.0);

        // Raising the tempo to 160 stretches by 160/157.
        ctx.app_state.transport.bpm = 160.0;
        let rate = source(&ctx, id).tempo_rate(160.0);
        assert!((rate - 160.0 / 157.0).abs() < 1e-9, "rate {rate}");
        assert_eq!(sources_needing_render(&ctx), vec![id]);
        refresh(&mut ctx, id);
        let edited = source(&ctx, id).edited.as_ref().unwrap();
        assert!((edited.edits.time_ratio - 157.0 / 160.0).abs() < 1e-6);

        // Back to Default forgets the anchor; Stretch again anchors to the tempo then.
        assert!(!set_sample_mode(&mut ctx, id, AudioSampleMode::Default).unwrap());
        assert_eq!(source(&ctx, id).original_bpm, None);
        assert!(source(&ctx, id).edited.is_none());
        set_sample_mode(&mut ctx, id, AudioSampleMode::Stretch).unwrap();
        assert_eq!(source(&ctx, id).original_bpm, Some(160.0));
        crate::undo(&mut ctx).unwrap();
        assert_eq!(source(&ctx, id).original_bpm, None);
    }

    /// A 120 BPM project with one clip of an undetected source on a new audio track.
    fn clip_setup() -> (DawContext, AudioSourceId, TrackId, ClipId) {
        clip_setup_at(0)
    }

    fn clip_setup_at(start_tick: u32) -> (DawContext, AudioSourceId, TrackId, ClipId) {
        let mut ctx = make_ctx();
        ctx.app_state.transport.bpm = 120.0;
        let source = add_dc_audio_source(&mut ctx);
        let track = ctx.app_state.add_new_audio_track().id;
        let clip = ctx
            .app_state
            .create_new_clip(
                Some(source.to_u64()),
                ClipSourceType::Audio,
                track,
                start_tick,
            )
            .unwrap()
            .id;
        (ctx, source, track, clip)
    }

    /// Start tick, length in ticks and content offset of an audio clip.
    fn span(ctx: &DawContext, clip: ClipId) -> (u64, u64, u64) {
        let app = &ctx.app_state;
        match app.clips_pool[clip].time {
            ClipTimeUnit::Audio {
                start_tick,
                loop_length,
                offset_start,
            } => (
                start_tick,
                ClipTimeUnit::samples_to_ticks(
                    loop_length,
                    app.transport.bpm,
                    app.audio_config.sample_rate,
                ),
                offset_start,
            ),
            _ => panic!("not an audio clip"),
        }
    }

    fn clip_source(ctx: &DawContext, clip: ClipId) -> AudioSourceId {
        match ctx.app_state.clips_pool[clip].source {
            Some(DawSource::Audio(source)) => source,
            _ => panic!("not an audio clip"),
        }
    }

    #[test]
    fn stretch_mode_resize_stretches_the_audio() {
        let (mut ctx, _, track, clip) = clip_setup();
        let (start, length, _) = span(&ctx, clip);

        batch_resize_clips(
            &mut ctx,
            track,
            vec![clip],
            ResizeEdge::Right,
            length as i64 / 2,
            true,
        )
        .unwrap();

        // 1.5x as long: the source now plays at 120/180 of its speed, pitch kept.
        let (new_start, new_length, _) = span(&ctx, clip);
        assert_eq!(new_start, start);
        assert!(new_length.abs_diff(length * 3 / 2) <= 1, "{new_length}");
        let waveform = source(&ctx, clip_source(&ctx, clip));
        assert_eq!(waveform.sample_mode, AudioSampleMode::Stretch);
        assert!((waveform.original_bpm.unwrap() - 180.0).abs() < 1e-3);
        assert!((waveform.tempo_rate(120.0) - 2.0 / 3.0).abs() < 1e-6);

        // One undo restores the length, the mode and the unknown tempo.
        crate::undo(&mut ctx).unwrap();
        assert_eq!(span(&ctx, clip).1, length);
        let waveform = source(&ctx, clip_source(&ctx, clip));
        assert_eq!(waveform.sample_mode, AudioSampleMode::Default);
        assert_eq!(waveform.original_bpm, None);
    }

    #[test]
    fn left_edge_stretch_keeps_the_end_in_place() {
        let (mut ctx, _, track, clip) = clip_setup_at(96_000);
        let (start, length, _) = span(&ctx, clip);
        let end = start + length;

        batch_resize_clips(
            &mut ctx,
            track,
            vec![clip],
            ResizeEdge::Left,
            -(length as i64 / 2),
            true,
        )
        .unwrap();

        let (new_start, new_length, _) = span(&ctx, clip);
        assert!((new_start + new_length).abs_diff(end) <= 1);
        assert!(new_length.abs_diff(length * 3 / 2) <= 1);
    }

    #[test]
    fn stretching_a_shared_source_makes_the_clip_unique() {
        let (mut ctx, source_id, track, clip) = clip_setup();
        let (_, length, _) = span(&ctx, clip);
        let other = ctx
            .app_state
            .create_new_clip(
                Some(source_id.to_u64()),
                ClipSourceType::Audio,
                track,
                100_000,
            )
            .unwrap()
            .id;

        batch_resize_clips(
            &mut ctx,
            track,
            vec![clip],
            ResizeEdge::Right,
            length as i64,
            true,
        )
        .unwrap();

        assert_ne!(clip_source(&ctx, clip), source_id);
        assert_eq!(clip_source(&ctx, other), source_id);
        assert_eq!(span(&ctx, other).1, length);
        let original = &ctx.app_state.asset_library.source_map[source_id];
        assert_eq!(original.sample_mode, AudioSampleMode::Default);
    }

    #[test]
    fn resize_trims_when_stretching_is_off() {
        let (mut ctx, source_id, track, clip) = clip_setup();
        let (_, length, _) = span(&ctx, clip);
        batch_resize_clips(
            &mut ctx,
            track,
            vec![clip],
            ResizeEdge::Right,
            -(length as i64 / 2),
            false,
        )
        .unwrap();
        assert!(span(&ctx, clip).1.abs_diff(length / 2) <= 1);
        let waveform = source(&ctx, source_id);
        assert_eq!(waveform.sample_mode, AudioSampleMode::Default);
        assert_eq!(waveform.original_bpm, None);
    }

    #[test]
    fn stretch_mode_resize_to_the_same_length_changes_nothing() {
        let (mut ctx, source_id, track, clip) = clip_setup();
        let (start, length, offset) = span(&ctx, clip);

        let resized = resize_clip(
            &mut ctx,
            track,
            clip,
            ResizeEdge::Right,
            start + length,
            true,
        )
        .unwrap();

        assert_eq!(resized.id, clip);
        assert_eq!(span(&ctx, clip), (start, length, offset));
        assert_eq!(
            source(&ctx, source_id).sample_mode,
            AudioSampleMode::Default
        );
    }

    #[test]
    fn source_without_edits_needs_no_render() {
        let (ctx, id) = setup();
        assert!(begin_refresh_render(&ctx, id).unwrap().is_none());
        assert!(sources_needing_render(&ctx).is_empty());
    }
}
