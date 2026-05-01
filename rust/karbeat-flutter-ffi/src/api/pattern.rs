use std::collections::HashMap;

use karbeat_core::shared::id::*;
use karbeat_core::{
    api::{note_api, pattern_api},
    core::project::{track::midi::Pattern, GeneratorId, Note, NoteId},
};

#[derive(Clone)]
pub struct UiPattern {
    pub id: u32,
    pub name: String,
    pub length_ticks: u64,

    pub notes: Vec<UiNote>,
}

#[derive(Clone)]
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

pub fn get_pattern(pattern_id: u32) -> Result<UiPattern, String> {
    let pattern_id = PatternId::from(pattern_id);
    let pattern_arc = pattern_api::get_pattern(&pattern_id).map_err(|e| e.to_string())?;
    let pattern_ui = UiPattern::from(pattern_arc.as_ref());
    Ok(pattern_ui)
}

pub fn get_patterns() -> Result<HashMap<u32, UiPattern>, String> {
    let patterns = pattern_api::get_patterns(|id, pattern| (id, UiPattern::from(pattern)))
        .map_err(|e| e.to_string())?;
    Ok(patterns)
}

pub fn add_note(
    pattern_id: u32,
    key: u32,
    start_tick: u64,
    duration: Option<u64>,
) -> Result<UiNote, String> {
    let note = note_api::add_note(PatternId::from(pattern_id), key as u8, start_tick, duration)
        .map_err(|e| format!("{}", e))?;

    let note_ui = UiNote::from(&note);

    Ok(note_ui)
}

pub fn delete_note(pattern_id: u32, note_id: u32) -> Result<UiNote, String> {
    let note = note_api::delete_note(PatternId::from(pattern_id), NoteId::from(note_id))
        .map_err(|e| format!("{}", e))?;

    let note_ui = UiNote::from(&note);

    Ok(note_ui)
}

pub fn resize_note(pattern_id: u32, note_id: u32, new_duration: u64) -> Result<UiNote, String> {
    let note = note_api::resize_note(
        PatternId::from(pattern_id),
        NoteId::from(note_id),
        new_duration,
    )
    .map_err(|e| format!("{}", e))?;

    let note_ui = UiNote::from(&note);
    Ok(note_ui)
}

pub fn move_note(
    pattern_id: u32,
    note_id: u32,
    new_start_tick: u64,
    new_key: u32,
) -> Result<UiNote, String> {
    let note = note_api::move_note(
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
pub fn add_notes_batch(pattern_id: u32, notes: Vec<(u8, u64, Option<u64>)>) -> Result<(), String> {
    let _ = note_api::add_notes_batch(pattern_id.into(), notes).map_err(|e| e.to_string())?;
    Ok(())
}

/// Delete notes in batch
///
/// ## Parameters
/// * pattern_id: [u32], id of the pattern
/// * note_ids: Vector of notes ID to delete
pub fn delete_notes_batch(pattern_id: u32, note_ids: Vec<u32>) -> Result<(), String> {
    note_api::delete_notes_batch(
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
pub fn move_notes_batch(pattern_id: u32, updates: Vec<(u32, u64, u8)>) -> Result<(), String> {
    let _ = note_api::move_notes_batch(
        pattern_id.into(),
        updates
            .into_iter()
            .map(|u| (u.0.into(), u.1, u.2))
            .collect(),
    )
    .map_err(|e| e.to_string())?;
    Ok(())
}

pub fn resize_notes_batch(pattern_id: u32, updates: Vec<(u32, u64)>) -> Result<(), String> {
    let pattern_id_typed: PatternId = pattern_id.into();
    let updates_proper = updates.into_iter().map(|u| (u.0.into(), u.1)).collect();
    let _ = note_api::resize_notes_batch(pattern_id_typed, updates_proper)
        .map_err(|e| e.to_string())?;
    Ok(())
}

// ========================= PATTERN PREVIEW TRANSPORT ============================

/// Play a pattern in isolation with a specific generator (looping automatically).
/// This temporarily switches the engine to Pattern playback mode.
pub fn play_pattern_preview(pattern_id: u32, generator_id: u32) -> Result<(), String> {
    let pattern_id = PatternId::from(pattern_id);
    let generator_id = GeneratorId::from(generator_id);
    pattern_api::play_pattern_preview(pattern_id, generator_id).map_err(|e| e.to_string())
}

/// Stop pattern preview without changing song mode. used in stop button inside pattern playback
pub fn stop_pattern_preview_local(pattern_id: u32, generator_id: u32) -> Result<(), String> {
    pattern_api::stop_pattern_preview_local(
        PatternId::from(pattern_id),
        GeneratorId::from(generator_id),
    )
    .map_err(|e| e.to_string())
}

/// Stop pattern preview and return to Song mode.
pub fn stop_pattern_preview() -> Result<(), String> {
    pattern_api::stop_pattern_preview().map_err(|e| e.to_string())
}
