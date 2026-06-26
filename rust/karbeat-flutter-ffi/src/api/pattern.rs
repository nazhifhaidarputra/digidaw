use std::collections::HashMap;

use flutter_rust_bridge::frb;
use karbeat_core::shared::id::*;
use karbeat_core::{
    api::{note_api, pattern_api},
    context::DawContext,
    core::project::{track::midi::Pattern, GeneratorId, Note, NoteId},
};

#[derive(Clone)]
#[frb(dart_metadata=("freezed"))]
pub struct UiPattern {
    pub id: u32,
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
        }
    }
}

impl From<&Pattern> for UiPattern {
    fn from(value: &Pattern) -> Self {
        let ui_notes: Vec<UiNote> = value.notes.iter().map(UiNote::from).collect();

        Self {
            id: value.id.into(), // Convert PatternId to u32
            name: value.name.clone(),
            length_ticks: value.length_ticks,
            notes: ui_notes,
        }
    }
}

pub fn get_pattern(ctx: &DawContext, pattern_id: u32) -> Result<UiPattern, String> {
    let pattern_id = PatternId::from(pattern_id);
    let pattern = pattern_api::get_pattern(ctx, &pattern_id).map_err(|e| e.to_string())?;
    let pattern_ui = UiPattern::from(&pattern);
    Ok(pattern_ui)
}

pub fn get_patterns(ctx: &DawContext) -> Result<HashMap<u32, UiPattern>, String> {
    let patterns = pattern_api::get_patterns(ctx, |id, pattern| (id, UiPattern::from(pattern)))
        .map_err(|e| e.to_string())?;
    Ok(patterns)
}

pub fn add_note(
    ctx: &mut DawContext,
    pattern_id: u32,
    key: u32,
    start_tick: u64,
    duration: Option<u64>,
) -> Result<UiNote, String> {
    let note = note_api::add_note(
        ctx,
        PatternId::from(pattern_id),
        key as u8,
        start_tick,
        duration,
    )
    .map_err(|e| format!("{}", e))?;

    let note_ui = UiNote::from(&note);

    Ok(note_ui)
}

pub fn delete_note(ctx: &mut DawContext, pattern_id: u32, note_id: u32) -> Result<UiNote, String> {
    let note = note_api::delete_note(ctx, PatternId::from(pattern_id), NoteId::from(note_id))
        .map_err(|e| format!("{}", e))?;

    let note_ui = UiNote::from(&note);

    Ok(note_ui)
}

pub fn resize_note(
    ctx: &mut DawContext,
    pattern_id: u32,
    note_id: u32,
    new_duration: u64,
) -> Result<UiNote, String> {
    let note = note_api::resize_note(
        ctx,
        PatternId::from(pattern_id),
        NoteId::from(note_id),
        new_duration,
    )
    .map_err(|e| format!("{}", e))?;

    let note_ui = UiNote::from(&note);
    Ok(note_ui)
}

pub fn move_note(
    ctx: &mut DawContext,
    pattern_id: u32,
    note_id: u32,
    new_start_tick: u64,
    new_key: u32,
) -> Result<UiNote, String> {
    let note = note_api::move_note(
        ctx,
        PatternId::from(pattern_id),
        NoteId::from(note_id),
        new_start_tick,
        new_key as u8,
    )
    .map_err(|e| format!("{}", e))?;

    let ui_note = UiNote::from(&note);
    Ok(ui_note)
}

pub fn change_note_params(
    ctx: &mut DawContext,
    pattern_id: u32,
    note_id: u32,
    velocity: Option<i64>,
    probability: Option<f32>,
    micro_offset: Option<i64>,
    mute: Option<bool>,
) -> Result<UiNote, String> {
    // validate inputs
    let velocity = velocity.and_then(|v| u8::try_from(v).ok());
    let micro_offset = micro_offset.and_then(|m| i8::try_from(m).ok());

    let note = note_api::change_note_params(
        ctx,
        PatternId::from(pattern_id),
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
/// * pattern_id: [u32], id of the pattern
/// * new_notes: Vector of tuples that contains (key, start_tick, duration)
pub fn add_notes_batch(
    ctx: &mut DawContext,
    pattern_id: u32,
    notes: Vec<(u8, u64, Option<u64>)>,
) -> Result<Vec<UiNote>, String> {
    let added_notes = note_api::add_notes_batch(ctx, pattern_id.into(), notes)
        .map_err(|e| e.to_string())?
        .iter()
        .map(|n| n.into())
        .collect();
    Ok(added_notes);
}

/// Delete notes in batch
///
/// ## Parameters
/// * pattern_id: [u32], id of the pattern
/// * note_ids: Vector of notes ID to delete
pub fn delete_notes_batch(
    ctx: &mut DawContext,
    pattern_id: u32,
    note_ids: Vec<u32>,
) -> Result<(), String> {
    note_api::delete_notes_batch(
        ctx,
        pattern_id.into(),
        note_ids.into_iter().map(NoteId::from).collect(),
    )
    .map_err(|e| e.to_string())
}

/// Move notes in batch
///
/// ## Parameters
/// * pattern_id: [u32], id of the pattern
/// * note_ids: Vector of notes updates (id, )
pub fn move_notes_batch(
    ctx: &mut DawContext,
    pattern_id: u32,
    updates: Vec<(u32, u64, u8)>,
) -> Result<Vec<UiNote>, String> {
    let moved_notes = note_api::move_notes_batch(
        ctx,
        pattern_id.into(),
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
    ctx: &mut DawContext,
    pattern_id: u32,
    updates: Vec<(u32, u64)>,
) -> Result<Vec<UiNote>, String> {
    let pattern_id_typed: PatternId = pattern_id.into();
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
    ctx: &mut DawContext,
    pattern_id: u32,
    generator_id: u32,
) -> Result<(), String> {
    let pattern_id = PatternId::from(pattern_id);
    let generator_id = GeneratorId::from(generator_id);
    pattern_api::play_pattern_preview(ctx, pattern_id, generator_id).map_err(|e| e.to_string())
}

/// Stop pattern preview without changing song mode. used in stop button inside pattern playback
pub fn stop_pattern_preview_local(
    ctx: &mut DawContext,
    pattern_id: u32,
    generator_id: u32,
) -> Result<(), String> {
    pattern_api::stop_pattern_preview_local(
        ctx,
        PatternId::from(pattern_id),
        GeneratorId::from(generator_id),
    )
    .map_err(|e| e.to_string())
}

/// Stop pattern preview and return to Song mode.
pub fn stop_pattern_preview(ctx: &mut DawContext) -> Result<(), String> {
    pattern_api::stop_pattern_preview(ctx).map_err(|e| e.to_string())
}
