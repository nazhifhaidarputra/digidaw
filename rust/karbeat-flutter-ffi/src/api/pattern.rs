use std::collections::HashMap;

use crate::api::context::DawContext;
use flutter_rust_bridge::frb;
use karbeat_core::core::project::{
    GeneratorId, Note, NoteId, track::midi::Pattern, track::note_transform,
};
use karbeat_core::shared::id::*;
use karbeat_core_api::{note_api, pattern_api};

#[derive(Clone)]
#[frb(dart_metadata=("freezed"))]
pub struct UiPattern {
    pub id: u64,
    pub name: String,
    pub length_ticks: u64,

    pub notes: Vec<UiNote>,
}

#[derive(Clone)]
#[frb(dart_metadata=("freezed"))]
pub struct UiNote {
    pub id: u32,
    pub start_tick: u64,
    pub duration: u64,
    pub key: u8, // 0 - 127 MIDI key
    pub velocity: u8,

    pub probability: f32,
    pub micro_offset: i8,
    pub mute: bool,
    /// Stereo placement, -1 (left) to 1 (right).
    pub pan: f32,
    /// Fine pitch in semitones, -2 to 2.
    pub pitch: f32,
}
// Helper to convert internal Note to UiNote
impl From<&Note> for UiNote {
    fn from(n: &Note) -> Self {
        Self {
            id: n.id.into(), // Convert NoteId to u32
            start_tick: n.start_tick,
            duration: n.duration,
            key: n.key,
            velocity: n.velocity,
            probability: n.probability,
            micro_offset: n.micro_offset,
            mute: n.mute,
            pan: n.pan,
            pitch: n.pitch,
        }
    }
}

/// Velocity, pan, and fine pitch for one note; `None` leaves a value unchanged.
#[derive(Clone)]
#[frb(dart_metadata=("freezed"))]
pub struct UiNoteParamUpdate {
    pub note_id: u32,
    pub velocity: Option<u8>,
    pub pan: Option<f32>,
    pub pitch: Option<f32>,
}

/// A complete note to insert, such as a draw-tool copy of a selected note.
#[derive(Clone)]
#[frb(dart_metadata=("freezed"))]
pub struct UiNoteDraft {
    pub key: u8,
    pub start_tick: u64,
    pub duration: u64,
    pub velocity: u8,
    pub pan: f32,
    pub pitch: f32,
}

impl From<UiNoteDraft> for Note {
    fn from(value: UiNoteDraft) -> Self {
        Self {
            id: NoteId::default(),
            start_tick: value.start_tick,
            duration: value.duration,
            key: value.key,
            velocity: value.velocity,
            probability: 1.0,
            micro_offset: 0,
            mute: false,
            pan: value.pan,
            pitch: value.pitch,
        }
    }
}

impl From<&Pattern> for UiPattern {
    fn from(value: &Pattern) -> Self {
        let ui_notes: Vec<UiNote> = value.notes.iter().map(UiNote::from).collect();

        Self {
            id: value.id.to_u64(),
            name: value.name.clone(),
            length_ticks: value.length_ticks,
            notes: ui_notes,
        }
    }
}

pub fn get_pattern(ctx: &DawContext, pattern_id: u64) -> Result<UiPattern, String> {
    crate::api::context::read_ctx!(ctx);
    let pattern_id = PatternId::from_u64(pattern_id);
    let pattern = pattern_api::get_pattern(ctx, &pattern_id).map_err(|e| e.to_string())?;
    let pattern_ui = UiPattern::from(&pattern);
    Ok(pattern_ui)
}

pub fn get_patterns(ctx: &DawContext) -> Result<HashMap<u64, UiPattern>, String> {
    crate::api::context::read_ctx!(ctx);
    let patterns = pattern_api::get_patterns(ctx, |id, pattern| (id, UiPattern::from(pattern)))
        .map_err(|e| e.to_string())?;
    Ok(patterns)
}

pub fn rename_pattern(ctx: &DawContext, pattern_id: u64, new_name: &str) -> Result<(), String> {
    crate::api::context::project_ctx!(ctx);
    pattern_api::rename_pattern(ctx, PatternId::from_u64(pattern_id), new_name)
        .map_err(|error| error.to_string())
}

pub fn add_note(
    ctx: &DawContext,
    pattern_id: u64,
    key: u32,
    start_tick: u64,
    duration: Option<u64>,
) -> Result<UiNote, String> {
    crate::api::context::project_ctx!(ctx);
    let note = note_api::add_note(
        ctx,
        PatternId::from_u64(pattern_id),
        key as u8,
        start_tick,
        duration,
    )
    .map_err(|e| format!("{}", e))?;

    let note_ui = UiNote::from(&note);

    Ok(note_ui)
}

pub fn delete_note(ctx: &DawContext, pattern_id: u64, note_id: u32) -> Result<UiNote, String> {
    crate::api::context::project_ctx!(ctx);
    let note = note_api::delete_note(ctx, PatternId::from_u64(pattern_id), NoteId::from(note_id))
        .map_err(|e| format!("{}", e))?;

    let note_ui = UiNote::from(&note);

    Ok(note_ui)
}

pub fn resize_note(
    ctx: &DawContext,
    pattern_id: u64,
    note_id: u32,
    new_duration: u64,
) -> Result<UiNote, String> {
    crate::api::context::project_ctx!(ctx);
    let note = note_api::resize_note(
        ctx,
        PatternId::from_u64(pattern_id),
        NoteId::from(note_id),
        new_duration,
    )
    .map_err(|e| format!("{}", e))?;

    let note_ui = UiNote::from(&note);
    Ok(note_ui)
}

pub fn move_note(
    ctx: &DawContext,
    pattern_id: u64,
    note_id: u32,
    new_start_tick: u64,
    new_key: u32,
) -> Result<UiNote, String> {
    crate::api::context::project_ctx!(ctx);
    let note = note_api::move_note(
        ctx,
        PatternId::from_u64(pattern_id),
        NoteId::from(note_id),
        new_start_tick,
        new_key as u8,
    )
    .map_err(|e| format!("{}", e))?;

    let ui_note = UiNote::from(&note);
    Ok(ui_note)
}

pub fn change_note_params(
    ctx: &DawContext,
    pattern_id: u64,
    note_id: u32,
    velocity: Option<i64>,
    probability: Option<f32>,
    micro_offset: Option<i64>,
    mute: Option<bool>,
) -> Result<UiNote, String> {
    crate::api::context::project_ctx!(ctx);
    // validate inputs
    let velocity = velocity.and_then(|v| u8::try_from(v).ok());
    let micro_offset = micro_offset.and_then(|m| i8::try_from(m).ok());

    let note = note_api::change_note_params(
        ctx,
        PatternId::from_u64(pattern_id),
        NoteId::from(note_id),
        velocity,
        probability,
        micro_offset,
        mute,
    )
    .map_err(|e| format!("{}", e))?;

    let note_ui = UiNote::from(&note);

    Ok(note_ui)
}

// ==============================================================================
// ======================== BATCH OPERATIONS ====================================
// ==============================================================================

/// Add notes in batch
///
/// ## Parameters
/// * pattern_id: [u64], id of the pattern
/// * new_notes: Vector of tuples that contains (key, start_tick, duration)
pub fn add_notes_batch(
    ctx: &DawContext,
    pattern_id: u64,
    notes: Vec<(u8, u64, Option<u64>)>,
) -> Result<Vec<UiNote>, String> {
    crate::api::context::project_ctx!(ctx);
    let added_notes = note_api::add_notes_batch(ctx, PatternId::from_u64(pattern_id), notes)
        .map_err(|e| e.to_string())?
        .iter()
        .map(|n| n.into())
        .collect();

    Ok(added_notes)
}

/// Delete notes in batch
///
/// ## Parameters
/// * pattern_id: [u64], id of the pattern
/// * note_ids: Vector of notes ID to delete
pub fn delete_notes_batch(
    ctx: &DawContext,
    pattern_id: u64,
    note_ids: Vec<u32>,
) -> Result<(), String> {
    crate::api::context::project_ctx!(ctx);
    note_api::delete_notes_batch(
        ctx,
        PatternId::from_u64(pattern_id),
        note_ids.into_iter().map(NoteId::from).collect(),
    )
    .map_err(|e| e.to_string())
}

/// Move notes in batch
///
/// ## Parameters
/// * pattern_id: [u64], id of the pattern
/// * note_ids: Vector of notes updates (id, )
pub fn move_notes_batch(
    ctx: &DawContext,
    pattern_id: u64,
    updates: Vec<(u32, u64, u8)>,
) -> Result<Vec<UiNote>, String> {
    crate::api::context::project_ctx!(ctx);
    let moved_notes = note_api::move_notes_batch(
        ctx,
        PatternId::from_u64(pattern_id),
        updates
            .into_iter()
            .map(|u| (u.0.into(), u.1, u.2))
            .collect(),
    )
    .map_err(|e| e.to_string())?;

    let moved_notes = moved_notes.iter().map(|n| n.into()).collect();
    Ok(moved_notes)
}

pub fn resize_notes_batch(
    ctx: &DawContext,
    pattern_id: u64,
    updates: Vec<(u32, u64)>,
) -> Result<Vec<UiNote>, String> {
    crate::api::context::project_ctx!(ctx);
    let pattern_id_typed = PatternId::from_u64(pattern_id);
    let updates_proper = updates.into_iter().map(|u| (u.0.into(), u.1)).collect();
    let resized_notes = note_api::resize_notes_batch(ctx, pattern_id_typed, updates_proper)
        .map_err(|e| e.to_string())?;
    let resized_notes = resized_notes.iter().map(|n| n.into()).collect();
    Ok(resized_notes)
}

// ========================= PATTERN PREVIEW TRANSPORT ============================

/// Play a pattern in isolation with a specific generator (looping automatically).
/// This temporarily switches the engine to Pattern playback mode.
pub fn play_pattern_preview(
    ctx: &DawContext,
    pattern_id: u64,
    generator_id: u64,
) -> Result<(), String> {
    crate::api::context::project_ctx!(ctx);
    let pattern_id = PatternId::from_u64(pattern_id);
    let generator_id = GeneratorId::from_u64(generator_id);
    pattern_api::play_pattern_preview(ctx, pattern_id, generator_id).map_err(|e| e.to_string())
}

/// Stop pattern preview without changing song mode. used in stop button inside pattern playback
pub fn stop_pattern_preview_local(
    ctx: &DawContext,
    pattern_id: u64,
    generator_id: u64,
) -> Result<(), String> {
    crate::api::context::project_ctx!(ctx);
    pattern_api::stop_pattern_preview_local(
        ctx,
        PatternId::from_u64(pattern_id),
        GeneratorId::from_u64(generator_id),
    )
    .map_err(|e| e.to_string())
}

/// Stop pattern preview and return to Song mode.
pub fn stop_pattern_preview(ctx: &DawContext) -> Result<(), String> {
    crate::api::context::project_ctx!(ctx);
    pattern_api::stop_pattern_preview(ctx).map_err(|e| e.to_string())
}

// ==============================================================================
// Piano-roll transforms
// ==============================================================================
//
// Each transform applies to `note_ids`, or to the whole pattern when it is empty, is one undo
// step, and returns the updated pattern.

fn note_ids(ids: &[u32]) -> Vec<NoteId> {
    ids.iter().copied().map(NoteId::from).collect()
}

/// Snaps note starts and ends to the nearest multiple of `step_ticks`.
pub fn quantize_notes(
    ctx: &DawContext,
    pattern_id: u64,
    note_ids: Vec<u32>,
    step_ticks: u64,
) -> Result<UiPattern, String> {
    crate::api::context::project_ctx!(ctx);
    note_api::quantize_notes(
        ctx,
        PatternId::from_u64(pattern_id),
        &self::note_ids(&note_ids),
        step_ticks,
    )
    .map(|pattern| UiPattern::from(&pattern))
    .map_err(|e| e.to_string())
}

/// Snaps only note starts to the nearest multiple of `step_ticks`, keeping lengths.
pub fn quantize_note_starts(
    ctx: &DawContext,
    pattern_id: u64,
    note_ids: Vec<u32>,
    step_ticks: u64,
) -> Result<UiPattern, String> {
    crate::api::context::project_ctx!(ctx);
    note_api::quantize_note_starts(
        ctx,
        PatternId::from_u64(pattern_id),
        &self::note_ids(&note_ids),
        step_ticks,
    )
    .map(|pattern| UiPattern::from(&pattern))
    .map_err(|e| e.to_string())
}

/// Stretches each note to the start of the next one.
pub fn legato_notes(
    ctx: &DawContext,
    pattern_id: u64,
    note_ids: Vec<u32>,
) -> Result<UiPattern, String> {
    crate::api::context::project_ctx!(ctx);
    note_api::legato_notes(
        ctx,
        PatternId::from_u64(pattern_id),
        &self::note_ids(&note_ids),
    )
    .map(|pattern| UiPattern::from(&pattern))
    .map_err(|e| e.to_string())
}

/// Randomizes timing by up to `timing_ticks` and velocity by up to `velocity_amount`.
pub fn humanize_notes(
    ctx: &DawContext,
    pattern_id: u64,
    note_ids: Vec<u32>,
    timing_ticks: u64,
    velocity_amount: u8,
    seed: u64,
) -> Result<UiPattern, String> {
    crate::api::context::project_ctx!(ctx);
    note_api::humanize_notes(
        ctx,
        PatternId::from_u64(pattern_id),
        &self::note_ids(&note_ids),
        timing_ticks,
        velocity_amount,
        seed,
    )
    .map(|pattern| UiPattern::from(&pattern))
    .map_err(|e| e.to_string())
}

/// Splits notes at every multiple of `step_ticks`.
pub fn chop_notes(
    ctx: &DawContext,
    pattern_id: u64,
    note_ids: Vec<u32>,
    step_ticks: u64,
) -> Result<UiPattern, String> {
    crate::api::context::project_ctx!(ctx);
    note_api::chop_notes(
        ctx,
        PatternId::from_u64(pattern_id),
        &self::note_ids(&note_ids),
        step_ticks,
    )
    .map(|pattern| UiPattern::from(&pattern))
    .map_err(|e| e.to_string())
}

/// Cuts one note in two at `at_tick`.
pub fn slice_note(
    ctx: &DawContext,
    pattern_id: u64,
    note_id: u32,
    at_tick: u64,
) -> Result<UiPattern, String> {
    crate::api::context::project_ctx!(ctx);
    note_api::slice_note(
        ctx,
        PatternId::from_u64(pattern_id),
        NoteId::from(note_id),
        at_tick,
    )
    .map(|pattern| UiPattern::from(&pattern))
    .map_err(|e| e.to_string())
}

/// Transposes notes by `semitones`.
pub fn transpose_notes(
    ctx: &DawContext,
    pattern_id: u64,
    note_ids: Vec<u32>,
    semitones: i32,
) -> Result<UiPattern, String> {
    crate::api::context::project_ctx!(ctx);
    note_api::transpose_notes(
        ctx,
        PatternId::from_u64(pattern_id),
        &self::note_ids(&note_ids),
        semitones,
    )
    .map(|pattern| UiPattern::from(&pattern))
    .map_err(|e| e.to_string())
}

/// Moves notes in time by `delta_ticks`.
pub fn shift_notes(
    ctx: &DawContext,
    pattern_id: u64,
    note_ids: Vec<u32>,
    delta_ticks: i64,
) -> Result<UiPattern, String> {
    crate::api::context::project_ctx!(ctx);
    note_api::shift_notes(
        ctx,
        PatternId::from_u64(pattern_id),
        &self::note_ids(&note_ids),
        delta_ticks,
    )
    .map(|pattern| UiPattern::from(&pattern))
    .map_err(|e| e.to_string())
}

/// Sets velocity, pan, and fine pitch for several notes as one undo step.
pub fn set_note_params_batch(
    ctx: &DawContext,
    pattern_id: u64,
    updates: Vec<UiNoteParamUpdate>,
) -> Result<UiPattern, String> {
    crate::api::context::project_ctx!(ctx);
    let updates: Vec<_> = updates
        .into_iter()
        .map(|update| {
            (
                NoteId::from(update.note_id),
                note_transform::NoteParams {
                    velocity: update.velocity,
                    pan: update.pan,
                    pitch: update.pitch,
                },
            )
        })
        .collect();
    note_api::set_note_params_batch(ctx, PatternId::from_u64(pattern_id), &updates)
        .map(|pattern| UiPattern::from(&pattern))
        .map_err(|e| e.to_string())
}

/// Inserts complete notes, keeping their velocity, pan, and pitch.
pub fn add_note_copies(
    ctx: &DawContext,
    pattern_id: u64,
    notes: Vec<UiNoteDraft>,
) -> Result<UiPattern, String> {
    crate::api::context::project_ctx!(ctx);
    note_api::add_note_copies(
        ctx,
        PatternId::from_u64(pattern_id),
        notes.into_iter().map(Note::from).collect(),
    )
    .map(|pattern| UiPattern::from(&pattern))
    .map_err(|e| e.to_string())
}
