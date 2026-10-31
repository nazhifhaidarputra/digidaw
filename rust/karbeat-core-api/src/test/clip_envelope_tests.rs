//! Tests for soft/hard clip copies and the stacked waveform and clip gain envelopes.

#[cfg(test)]
mod tests {
    use std::sync::Arc;

    use crate as api;
    use crate::test::helpers::{add_dc_audio_source, make_seeded_ctx};
    use crate::{audio_waveform_api, clip_api, plugin_api};
    use karbeat_audio::context::DawContext;
    use karbeat_core::core::project::{
        ClipLoop, ClipModulation, DawSource, EnvelopePoint, Fade, GainEnvelope,
        GeneratorInstanceType, PluginInstance, clip::ClipSourceType,
    };
    use karbeat_core::shared::id::{AudioSourceId, ClipId, TrackId};

    fn fade_in(length: u32) -> GainEnvelope {
        GainEnvelope {
            fade_in: Fade {
                length,
                ..Fade::default()
            },
            ..GainEnvelope::default()
        }
    }

    /// Audio track with two soft copies of one audio clip.
    fn audio_fixture() -> (DawContext, TrackId, AudioSourceId, ClipId, ClipId) {
        let (mut ctx, audio, _, _) = make_seeded_ctx();
        let source = add_dc_audio_source(&mut ctx);
        let original = clip_api::add_clip(
            &mut ctx,
            Some(source.to_u64()),
            ClipSourceType::Audio,
            audio,
            0,
        )
        .expect("audio clip");
        let copy =
            clip_api::batch_duplicate_clip_groups(&mut ctx, audio, vec![original.id], vec![3_840])
                .expect("soft copy")
                .remove(0);
        (ctx, audio, source, original.id, copy.id)
    }

    fn audio_source_of(ctx: &DawContext, clip: ClipId) -> AudioSourceId {
        match ctx.app_state.clips_pool[clip].source {
            Some(DawSource::Audio(id)) => id,
            _ => panic!("expected an audio clip"),
        }
    }

    #[test]
    fn duplicate_is_a_soft_copy_sharing_the_waveform() {
        let (ctx, _, source, original, copy) = audio_fixture();
        assert_eq!(audio_source_of(&ctx, original), source);
        assert_eq!(audio_source_of(&ctx, copy), source);
        assert_eq!(ctx.app_state.asset_library.source_map.len(), 1);
    }

    #[test]
    fn make_unique_hard_copies_the_waveform_and_shares_its_samples() {
        let (mut ctx, audio, source, original, copy) = audio_fixture();

        let made = clip_api::make_clips_unique(&mut ctx, audio, vec![copy]).expect("make unique");
        assert_eq!(made.sources.len(), 1);
        let unique = audio_source_of(&ctx, copy);
        assert_ne!(unique, source);
        assert_eq!(audio_source_of(&ctx, original), source);

        let sources = &ctx.app_state.asset_library.source_map;
        assert_eq!(sources[unique].name, "dc (copy)");
        assert_eq!(sources[unique].id, Some(unique));
        let shared = sources[source].buffer.as_ref().expect("original buffer");
        let copied = sources[unique].buffer.as_ref().expect("copied buffer");
        assert!(
            Arc::ptr_eq(shared, copied),
            "hard copies share sample memory"
        );
        assert_eq!(ctx.app_state.clips_pool[copy].name, "dc (copy)");
    }

    #[test]
    fn make_unique_skips_clips_that_are_already_unique() {
        let (mut ctx, audio, _, original, copy) = audio_fixture();
        let made = clip_api::make_clips_unique(&mut ctx, audio, vec![original, copy])
            .expect("make unique");
        // One copy suffices: the other clip is then the waveform's only user.
        assert_eq!(made.clips.len(), 1);
        assert_eq!(ctx.app_state.asset_library.source_map.len(), 2);

        let label = ctx.history.undo_label();
        let again = clip_api::make_clips_unique(&mut ctx, audio, vec![original, copy])
            .expect("make unique again");
        assert!(again.clips.is_empty());
        assert_eq!(ctx.history.undo_label(), label, "no-op records no history");
    }

    #[test]
    fn make_unique_clones_a_shared_pattern() {
        let (mut ctx, _, midi, pattern) = make_seeded_ctx();
        let first = ctx.app_state.tracks[midi].clips[0];
        let second =
            clip_api::batch_duplicate_clip_groups(&mut ctx, midi, vec![first], vec![7_680])
                .expect("soft copy")
                .remove(0)
                .id;

        let made = clip_api::make_clips_unique(&mut ctx, midi, vec![second]).expect("make unique");
        let [new_pattern] = made.patterns[..] else {
            panic!("expected one new pattern");
        };
        assert_ne!(new_pattern, pattern);
        assert!(matches!(
            ctx.app_state.clips_pool[second].source,
            Some(DawSource::Midi(id)) if id == new_pattern
        ));
        let patterns = &ctx.app_state.pattern_pool;
        assert_eq!(patterns[new_pattern].notes, patterns[pattern].notes);
        assert_eq!(patterns[new_pattern].id, new_pattern);
    }

    #[test]
    fn make_unique_undo_and_redo_restore_the_pools() {
        let (mut ctx, audio, source, _, copy) = audio_fixture();
        clip_api::make_clips_unique(&mut ctx, audio, vec![copy]).expect("make unique");
        let unique = audio_source_of(&ctx, copy);
        assert_eq!(ctx.history.undo_label(), Some("Make Clips Unique"));

        for _ in 0..2 {
            api::undo(&mut ctx).expect("undo");
            assert_eq!(audio_source_of(&ctx, copy), source);
            assert!(!ctx.app_state.asset_library.source_map.contains_key(unique));

            api::redo(&mut ctx).expect("redo");
            assert_eq!(audio_source_of(&ctx, copy), unique);
            assert!(ctx.app_state.asset_library.source_map.contains_key(unique));
        }
    }

    #[test]
    fn clip_envelope_is_per_clip_and_undoable() {
        let (mut ctx, _, _, original, copy) = audio_fixture();
        clip_api::set_clip_envelope(&mut ctx, copy, fade_in(480)).expect("set envelope");
        assert!(ctx.app_state.clips_pool[original].envelope.is_none());
        assert_eq!(
            ctx.app_state.clips_pool[copy]
                .envelope
                .as_deref()
                .map(|e| e.fade_in.length),
            Some(480)
        );

        api::undo(&mut ctx).expect("undo");
        assert!(ctx.app_state.clips_pool[copy].envelope.is_none());
        api::redo(&mut ctx).expect("redo");
        assert!(ctx.app_state.clips_pool[copy].envelope.is_some());

        clip_api::set_clip_envelope(&mut ctx, copy, GainEnvelope::default())
            .expect("clear envelope");
        assert!(
            ctx.app_state.clips_pool[copy].envelope.is_none(),
            "an identity envelope is stored as None"
        );
    }

    #[test]
    fn clip_envelope_is_rejected_on_midi_clips() {
        let (mut ctx, _, midi, _) = make_seeded_ctx();
        let clip = ctx.app_state.tracks[midi].clips[0];
        assert!(clip_api::set_clip_envelope(&mut ctx, clip, fade_in(10)).is_err());
    }

    #[test]
    fn slicing_keeps_the_clip_envelope_on_both_halves() {
        let (mut ctx, audio, _, original, _) = audio_fixture();
        let envelope = GainEnvelope {
            points: vec![EnvelopePoint {
                position: 1_000,
                gain: 0.5,
                ..EnvelopePoint::default()
            }],
            ..GainEnvelope::default()
        };
        clip_api::set_clip_envelope(&mut ctx, original, envelope).expect("set envelope");
        let (left, right) = clip_api::slice_clip(&mut ctx, audio, original, 960).expect("slice");
        let (Some(left), Some(right)) = (left.envelope, right.envelope) else {
            panic!("both halves keep the envelope");
        };
        assert!(Arc::ptr_eq(&left, &right));
    }

    #[test]
    fn waveform_envelope_is_shared_by_soft_copies_only() {
        let (mut ctx, audio, source, _, copy) = audio_fixture();
        clip_api::make_clips_unique(&mut ctx, audio, vec![copy]).expect("make unique");
        let unique = audio_source_of(&ctx, copy);

        audio_waveform_api::set_audio_source_envelope(&mut ctx, source, fade_in(100))
            .expect("waveform envelope");
        let sources = &ctx.app_state.asset_library.source_map;
        assert_eq!(sources[source].envelope.fade_in.length, 100);
        assert_eq!(sources[unique].envelope, GainEnvelope::default());

        assert_eq!(ctx.history.undo_label(), Some("Edit Waveform Envelope"));
        api::undo(&mut ctx).expect("undo");
        assert_eq!(
            ctx.app_state.asset_library.source_map[source].envelope,
            GainEnvelope::default()
        );
        api::redo(&mut ctx).expect("redo");
        assert_eq!(
            ctx.app_state.asset_library.source_map[source]
                .envelope
                .fade_in
                .length,
            100
        );
    }

    fn stutter() -> ClipModulation {
        ClipModulation::new(
            Vec::new(),
            Vec::new(),
            ClipLoop {
                enabled: true,
                time: 12_000,
                curve: Vec::new(),
            },
        )
    }

    #[test]
    fn clip_modulation_is_per_clip_and_undoable() {
        let (mut ctx, _, _, original, copy) = audio_fixture();
        clip_api::set_clip_modulation(&mut ctx, copy, stutter()).expect("set modulation");
        assert!(ctx.app_state.clips_pool[original].modulation.is_none());
        assert!(ctx.app_state.clips_pool[copy].modulation.is_some());
        assert_eq!(ctx.history.undo_label(), Some("Edit Clip Modulation"));

        api::undo(&mut ctx).expect("undo");
        assert!(ctx.app_state.clips_pool[copy].modulation.is_none());
        api::redo(&mut ctx).expect("redo");
        assert!(ctx.app_state.clips_pool[copy].modulation.is_some());

        clip_api::set_clip_modulation(&mut ctx, copy, ClipModulation::default())
            .expect("clear modulation");
        assert!(
            ctx.app_state.clips_pool[copy].modulation.is_none(),
            "an identity modulation is stored as None"
        );
    }

    #[test]
    fn clip_modulation_is_rejected_on_midi_clips() {
        let (mut ctx, _, midi, _) = make_seeded_ctx();
        let clip = ctx.app_state.tracks[midi].clips[0];
        assert!(clip_api::set_clip_modulation(&mut ctx, clip, stutter()).is_err());
    }

    #[test]
    fn slicing_keeps_the_modulation_on_both_halves() {
        let (mut ctx, audio, _, original, _) = audio_fixture();
        clip_api::set_clip_modulation(&mut ctx, original, stutter()).expect("set modulation");
        let (left, right) = clip_api::slice_clip(&mut ctx, audio, original, 960).expect("slice");
        let (Some(left), Some(right)) = (left.modulation, right.modulation) else {
            panic!("both halves keep the modulation");
        };
        assert!(Arc::ptr_eq(&left, &right));
    }

    #[test]
    fn clip_modulation_survives_a_save_and_load_of_the_clip() {
        let (mut ctx, _, _, _, copy) = audio_fixture();
        clip_api::set_clip_modulation(&mut ctx, copy, stutter()).expect("set modulation");
        let clip = &ctx.app_state.clips_pool[copy];
        let json = serde_json::to_string(clip).expect("serialize");
        let restored: karbeat_core::core::project::Clip =
            serde_json::from_str(&json).expect("deserialize");
        assert_eq!(restored.modulation, clip.modulation);
    }

    #[test]
    fn trim_plays_the_part_between_its_points_and_is_undoable() {
        let (mut ctx, _, source, _, _) = audio_fixture();
        audio_waveform_api::set_audio_source_trim(&mut ctx, source, 1_000, 3_000).expect("trim");
        let waveform = &ctx.app_state.asset_library.source_map[source];
        assert_eq!((waveform.trim_start, waveform.trim_end), (1_000, 3_000));
        assert_eq!(
            waveform.get_playable_buffer().map(<[f32]>::len),
            Some(4_000)
        );

        assert_eq!(ctx.history.undo_label(), Some("Trim Audio"));
        api::undo(&mut ctx).expect("undo");
        let waveform = &ctx.app_state.asset_library.source_map[source];
        assert_eq!(waveform.trim_start, 0);
        api::redo(&mut ctx).expect("redo");
        let waveform = &ctx.app_state.asset_library.source_map[source];
        assert_eq!(waveform.trim_start, 1_000);
    }

    #[test]
    fn trim_rejects_empty_and_out_of_range_parts() {
        let (mut ctx, _, source, _, _) = audio_fixture();
        for (start, end) in [(10, 10), (20, 10), (0, 48_001), (48_000, 0)] {
            assert!(
                audio_waveform_api::set_audio_source_trim(&mut ctx, source, start, end).is_err(),
                "{start}..{end}"
            );
        }
    }

    #[test]
    fn trim_keeps_envelope_points_on_the_same_audio() {
        let (mut ctx, _, source, _, _) = audio_fixture();
        let envelope = GainEnvelope {
            points: vec![EnvelopePoint {
                position: 2_000,
                gain: 0.5,
                ..EnvelopePoint::default()
            }],
            ..GainEnvelope::default()
        };
        audio_waveform_api::set_audio_source_envelope(&mut ctx, source, envelope)
            .expect("envelope");
        audio_waveform_api::set_audio_source_trim(&mut ctx, source, 500, 0).expect("trim");
        let waveform = &ctx.app_state.asset_library.source_map[source];
        assert_eq!(waveform.envelope.points[0].position, 1_500);

        api::undo(&mut ctx).expect("undo");
        let waveform = &ctx.app_state.asset_library.source_map[source];
        assert_eq!(waveform.envelope.points[0].position, 2_000);
    }

    #[test]
    fn new_clips_of_a_trimmed_source_take_the_trimmed_length() {
        let (mut ctx, audio, source, _, _) = audio_fixture();
        audio_waveform_api::set_audio_source_trim(&mut ctx, source, 1_000, 3_000).expect("trim");
        let clip = clip_api::add_clip(
            &mut ctx,
            Some(source.to_u64()),
            ClipSourceType::Audio,
            audio,
            0,
        )
        .expect("clip");
        assert_eq!(clip.time.loop_length_raw(), 2_000);
    }

    #[test]
    fn generator_rename_labels_the_instance_and_is_undoable() {
        let (mut ctx, _, midi, _) = make_seeded_ctx();
        let id = ctx
            .app_state
            .add_generator(GeneratorInstanceType::Plugin(PluginInstance::new("Vital")));
        let label = |ctx: &DawContext| match &ctx.app_state.generator_pool[id].instance_type {
            GeneratorInstanceType::Plugin(plugin) => plugin.label(),
            GeneratorInstanceType::Sampler { .. } => panic!("expected a plugin"),
        };
        ctx.app_state.tracks[midi].generator = Some(ctx.app_state.generator_pool[id].clone());

        plugin_api::rename_generator(&mut ctx, id, Some("  Lead 1 ")).expect("rename");
        assert_eq!(label(&ctx), "Lead 1 (Vital)");
        assert_eq!(
            ctx.app_state.tracks[midi].generator,
            Some(ctx.app_state.generator_pool[id].clone()),
            "the track's copy follows"
        );
        assert_eq!(ctx.history.undo_label(), Some("Rename Generator"));

        api::undo(&mut ctx).expect("undo");
        assert_eq!(label(&ctx), "Vital");
        api::redo(&mut ctx).expect("redo");
        assert_eq!(label(&ctx), "Lead 1 (Vital)");

        for blank in [Some(""), Some("   "), Some("Vital"), None] {
            plugin_api::rename_generator(&mut ctx, id, Some("Lead 1")).expect("rename");
            plugin_api::rename_generator(&mut ctx, id, blank).expect("clear");
            assert_eq!(label(&ctx), "Vital", "{blank:?}");
        }
        let long = "x".repeat(51);
        assert!(plugin_api::rename_generator(&mut ctx, id, Some(&long)).is_err());
    }
}
