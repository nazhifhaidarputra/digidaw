//! Shared test helpers and fixtures for karbeat-core API tests.
//!
//! The `DawContext::new()` used here intentionally has no audio thread —
//! all ring-buffer fields are `None`, so `broadcast_*` and `send_audio_command`
//! calls silently no-op, keeping tests fast and deterministic.

use karbeat_utils::hash::hash_str;

use crate::{
    api::{clip_api, note_api, track_api},
    context::DawContext,
    core::project::{
        DawSource,
        clip::{Clip, ClipSourceType, ClipTimeUnit},
    },
    shared::id::{ClipId, PatternId, TrackId},
};

/// Returns a fresh, empty `DawContext` with no audio stream attached.
pub fn make_ctx() -> DawContext {
    DawContext::new()
}

/// Registry ID for "Karbeatzer V2" (synth generator built into karbeat-plugins).
/// Computed as `hash_str("synth_karbeatzer_v2")`.
pub fn karbeatzer_v2_registry_id() -> u32 {
    hash_str("synth_karbeatzer_v2")
}

/// Registry ID for "My Retro" (synth generator).
pub fn my_retro_registry_id() -> u32 {
    hash_str("synth_my_retro")
}

/// Registry ID for "Parametric EQ" (effect plugin).
pub fn param_eq_registry_id() -> u32 {
    hash_str("effect_param_eq")
}

/// Registry ID for the built-in sidechain compressor effect.
pub fn sidechain_compressor_registry_id() -> u32 {
    hash_str("effect_digidaw_sidechain_comp")
}

/// A seeded context with:
/// - 1 audio track
/// - 1 MIDI track backed by Karbeatzer V2
/// - 1 pattern (inside the MIDI track's clip) with 3 notes
///
/// Returns `(ctx, audio_track_id, midi_track_id, pattern_id)`.
pub fn make_seeded_ctx() -> (DawContext, TrackId, TrackId, PatternId) {
    let mut ctx = make_ctx();

    // 1. Audio track
    let audio_track = track_api::add_new_audio_track(&mut ctx);
    let audio_track_id = audio_track.id;

    // 2. MIDI track with Karbeatzer V2
    let midi_track =
        track_api::add_midi_track_with_generator_id(&mut ctx, karbeatzer_v2_registry_id())
            .expect("Karbeatzer V2 should be in the default registry");
    let midi_track_id = midi_track.id;

    // 3. Add a MIDI clip to the MIDI track (creates a new pattern automatically)
    let clip = clip_api::add_clip(&mut ctx, None, ClipSourceType::Midi, midi_track_id, 0)
        .expect("Should add a MIDI clip");

    // Extract the pattern ID from the clip source
    let pattern_id = match clip.source {
        Some(DawSource::Midi(pid)) => pid,
        _ => panic!("Expected a MIDI source clip"),
    };

    // 4. Add 3 notes to the pattern
    note_api::add_note(&mut ctx, pattern_id, 60, 0, Some(480)).expect("add note 1");
    note_api::add_note(&mut ctx, pattern_id, 64, 480, Some(480)).expect("add note 2");
    note_api::add_note(&mut ctx, pattern_id, 67, 960, Some(480)).expect("add note 3");

    (ctx, audio_track_id, midi_track_id, pattern_id)
}

/// Build a minimal MIDI clip with tick-based time (for use in tests that need a clip directly).
pub fn make_midi_clip_at(start_ticks: u32, length_ticks: u32, pattern_id: PatternId) -> Clip {
    Clip {
        name: "test clip".to_string(),
        id: ClipId::from(9999),
        source: Some(DawSource::Midi(pattern_id)),
        time: ClipTimeUnit::Ticks {
            start_time: start_ticks,
            loop_length: length_ticks,
            offset_start: 0,
        },
    }
}
