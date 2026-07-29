use crate::api::project::UiTrackType;
use crate::api::track::UiResizeEdge;
use crate::api::{pattern::UiNote, project::UiClip};
use karbeat_core::api::{self, clip_api, clipboard_api, note_api};
use karbeat_core::context::DawContext;
use karbeat_core::core::project::clip::ClipTimeUnit;
use karbeat_core::core::project::clipboard::ClipboardContent;
use karbeat_core::core::project::{NoteId, PatternId};

use karbeat_core::shared::id::*;

// =======================================
// Data type definition
// =======================================

#[derive(Clone, Default)]

/// UI-compatible representation of [ClipboardContent](karbeat_core::core::project::clipboard::ClipboardContent)
pub enum UiClipboardContent {
    #[default]
    Empty,
    Notes(Vec<UiNote>), // A list of notes (for Pattern View)
    Clips(Vec<UiClip>), // A list of clips (for Track View)
}

impl From<&ClipboardContent> for UiClipboardContent {
    fn from(clipboard: &ClipboardContent) -> Self {
        match clipboard {
            ClipboardContent::Empty => UiClipboardContent::Empty,
            ClipboardContent::Notes(notes) => {
                let ui_notes = notes.iter().map(UiNote::from).collect();
                UiClipboardContent::Notes(ui_notes)
            }
            ClipboardContent::Clips(clips) => {
                let ui_clips = clips.iter().map(UiClip::from).collect();
                UiClipboardContent::Clips(ui_clips)
            }
        }
    }
}

// Note: Session state (clip selection, preview generator) is now managed
// entirely in the Flutter frontend. Only clipboard and editing APIs remain here.

/// Undo the last action.
pub fn undo(ctx: &mut DawContext) -> Result<(), String> {
    api::undo(ctx)?;
    Ok(())
}

/// Redo the last undone action.
pub fn redo(ctx: &mut DawContext) -> Result<(), String> {
    api::redo(ctx)?;
    Ok(())
}

// =============================================
// Pattern Note Actions
// =============================================

/// Copy selected pattern notes to the clipboard.
pub fn copy_pattern_notes(
    ctx: &mut DawContext,
    pattern_id: u32,
    note_ids: Vec<u32>,
) -> Result<UiClipboardContent, String> {
    let pattern_id = PatternId::from(pattern_id);
    let note_ids: Vec<NoteId> = note_ids.into_iter().map(NoteId::from).collect();

    clipboard_api::copy_pattern_notes(ctx, pattern_id, note_ids, |clipboard| {
        UiClipboardContent::from(clipboard)
    })
    .map_err(|e| e.to_string())
}

/// Cut pattern notes: copies them to clipboard then deletes with history.
pub fn cut_pattern_notes(
    ctx: &mut DawContext,
    pattern_id: u32,
    note_ids: Vec<u32>,
) -> Result<(), String> {
    clipboard_api::cut_notes(
        ctx,
        pattern_id.into(),
        note_ids.into_iter().map(|note_id| note_id.into()).collect(),
    )
    .map_err(|e| e.to_string())?;
    Ok(())
}

/// Paste: Reads clipboard, creates new notes, creates Batch Add action
pub fn paste_pattern_notes(
    ctx: &mut DawContext,
    target_pattern_id: u32,
    playhead_tick: u64,
    target_key: Option<u8>,
) -> Result<Vec<UiNote>, String> {
    let notes = clipboard_api::paste_notes(
        ctx,
        PatternId::from(target_pattern_id),
        playhead_tick,
        target_key,
        |note| UiNote::from(note),
    )
    .map_err(|e| format!("{}", e))?;
    Ok(notes)
}

/// Delete notes in group. useful for range and group deletion
pub fn delete_pattern_notes(
    ctx: &mut DawContext,
    pattern_id: u32,
    note_ids: Vec<u32>,
) -> Result<(), String> {
    let note_ids_typed = note_ids
        .into_iter()
        .map(karbeat_core::core::project::NoteId::from)
        .collect();
    note_api::delete_notes_batch(ctx, PatternId::from(pattern_id), note_ids_typed)
        .map_err(|e| format!("{}", e))?;

    Ok(())
}

// =============================================
// Clip Actions
// =============================================

/// Copy selected clips to the clipboard.
/// Each (track_id, clip_id) pair identifies a clip to copy.
pub fn copy_clips(ctx: &mut DawContext, track_id: u32, clip_ids: Vec<u32>) {
    let track_id = TrackId::from(track_id);
    let clip_ids: Vec<ClipId> = clip_ids.into_iter().map(ClipId::from).collect();

    clipboard_api::copy_clips(ctx, track_id, &clip_ids)
}

/// Cut selected clips: copies them to clipboard then deletes with history.
pub fn cut_clips(ctx: &mut DawContext, track_id: u32, clip_ids: Vec<u32>) -> Result<(), String> {
    let clip_ids_typed = clip_ids.into_iter().map(|c| c.into()).collect();
    clipboard_api::cut_clips(ctx, track_id.into(), clip_ids_typed);

    Ok(())
}

/// Paste clips from clipboard to a target track at a specified start time.
/// Clips are offset relative to the earliest clip's start time.
pub fn paste_clips(
    ctx: &mut DawContext,
    target_track_id: u32,
    paste_start_time: u32,
    track_type: UiTrackType,
) -> Result<Vec<UiClip>, String> {
    let clip_time_unit = match track_type {
        UiTrackType::Audio => ClipTimeUnit::Samples {
            start_time: paste_start_time as u64,
            loop_length: 0,
            offset_start: 0,
        },
        UiTrackType::Midi => ClipTimeUnit::Ticks {
            start_time: paste_start_time,
            loop_length: 0,
            offset_start: 0,
        },
        UiTrackType::Automation => ClipTimeUnit::Ticks {
            start_time: paste_start_time,
            loop_length: 0,
            offset_start: 0,
        },
    };
    let pasted_clips =
        clipboard_api::paste_clips(ctx, TrackId::from(target_track_id), clip_time_unit)
            .map_err(|e| e.to_string())?;

    Ok(pasted_clips.iter().map(UiClip::from).collect())
}

/// Delete specified clips from a track with history support.
pub fn delete_clips(ctx: &mut DawContext, track_id: u32, clip_ids: Vec<u32>) -> Result<(), String> {
    let clip_ids_typed = clip_ids.into_iter().map(ClipId::from).collect();
    clip_api::batch_delete_clips(ctx, TrackId::from(track_id), clip_ids_typed)
        .map_err(|e| format!("{}", e))?;

    Ok(())
}

/// Move a clip from one track to another (or within the same track) with a new start time.
pub fn move_clip(
    ctx: &mut DawContext,
    old_track_id: u32,
    new_track_id: u32,
    clip_id: u32,
    new_start_time: u64,
) -> Result<(), String> {
    clip_api::move_clip(
        ctx,
        TrackId::from(old_track_id),
        TrackId::from(new_track_id),
        ClipId::from(clip_id),
        new_start_time,
    )
    .map_err(|e| format!("{}", e))?;

    Ok(())
}

/// Resize a clip by updating its start_time, offset_start, and/or loop_length.
/// Supports both left (slip edit) and right edge resizing with history support.
pub fn resize_clip(
    ctx: &mut DawContext,
    track_id: u32,
    clip_id: u32,
    edge: UiResizeEdge,
    new_time_val: u64,
) -> Result<(), String> {
    clip_api::resize_clip(
        ctx,
        TrackId::from(track_id),
        ClipId::from(clip_id),
        edge.into(),
        new_time_val,
    )
    .map_err(|e| format!("{}", e))?;

    Ok(())
}

// ==================================
// Getters
// ==================================

pub fn get_clipboard_contents(ctx: &DawContext) -> UiClipboardContent {
    clipboard_api::get_clipboard_contents(ctx, |clipboard_ref| {
        UiClipboardContent::from(clipboard_ref)
    })
}
