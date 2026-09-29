//! Tests for soft/hard clip copies and the stacked waveform and clip gain envelopes.

#[cfg(test)]
mod tests {
    use std::sync::Arc;

    use crate::api::{self, audio_waveform_api, clip_api};
    use crate::context::DawContext;
    use crate::core::project::{
        DawSource, EnvelopePoint, Fade, GainEnvelope, clip::ClipSourceType,
    };
    use crate::shared::id::{AudioSourceId, ClipId, TrackId};
    use crate::test::helpers::{add_dc_audio_source, make_seeded_ctx};

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
}
