use crate::context::DawContext;
use crate::core::history::ProjectAction;
use crate::core::project::track::midi::Pattern;
use crate::core::project::track::note_transform::{self, NoteEdit, NoteParams};
use crate::core::project::{Note, NoteId};
use crate::shared::id::*;

/// Adds a note to a MIDI pattern, records history, and republishes the track graph.
pub fn add_note(
    ctx: &mut DawContext,
    pattern_id: PatternId,
    key: u8,
    start_tick: u64,
    duration: Option<u64>,
) -> anyhow::Result<Note> {
    // 1. Mutate state
    let note = ctx
        .app_state
        .add_note_to_pattern(pattern_id, key, start_tick, duration)?;

    // 2. Update history
    ctx.push_history(ProjectAction::AddNote {
        pattern_id,
        note: note.clone(),
    });
    ctx.broadcast_track_graph();
    Ok(note)
}

/// Removes one note from a MIDI pattern and records the removed note for undo.
pub fn delete_note(
    ctx: &mut DawContext,
    pattern_id: PatternId,
    note_id: NoteId,
) -> anyhow::Result<Note> {
    // 1. Mutate state
    let note = ctx
        .app_state
        .delete_note_from_pattern(pattern_id, note_id)?;

    // 2. Update history
    ctx.push_history(ProjectAction::DeleteNote {
        pattern_id,
        note: note.clone(),
    });

    ctx.broadcast_track_graph();

    Ok(note)
}

/// Changes a note's start tick and key while preserving its remaining parameters.
pub fn move_note(
    ctx: &mut DawContext,
    pattern_id: PatternId,
    note_id: NoteId,
    new_start_tick: u64,
    new_key: u8,
) -> anyhow::Result<Note> {
    // 1. Mutate state
    let (note, old_tick, old_key) =
        ctx.app_state
            .move_note_in_pattern(pattern_id, note_id, new_start_tick, new_key)?;

    // 2. Update history
    ctx.push_history(ProjectAction::MoveNote {
        pattern_id,
        note_id,
        old_tick,
        old_key,
        new_tick: new_start_tick,
        new_key,
    });

    ctx.broadcast_track_graph();
    Ok(note)
}

/// Changes a note's duration and records its previous duration for undo.
pub fn resize_note(
    ctx: &mut DawContext,
    pattern_id: PatternId,
    note_id: NoteId,
    new_duration: u64,
) -> anyhow::Result<Note> {
    // 1. Mutate state
    let (note, old_duration) =
        ctx.app_state
            .resize_note_in_pattern(pattern_id, note_id, new_duration)?;

    // 2. Update history
    ctx.push_history(ProjectAction::ResizeNote {
        pattern_id,
        note_id,
        old_duration,
        new_duration,
    });

    ctx.broadcast_track_graph();

    Ok(note)
}

/// Updates optional velocity, release velocity, and mute values for one note.
pub fn change_note_params(
    ctx: &mut DawContext,
    pattern_id: PatternId,
    note_id: NoteId,
    velocity: Option<u8>,
    probability: Option<f32>,
    micro_offset: Option<i8>,
    mute: Option<bool>,
) -> anyhow::Result<Note> {
    let note = ctx.app_state.change_note_params_in_pattern(
        pattern_id,
        note_id,
        velocity,
        probability,
        micro_offset,
        mute,
    )?;

    ctx.broadcast_track_graph();
    Ok(note)
}

/// Add notes in batch
///
/// ## Parameters
/// * pattern_id: [PatternId]
/// * new_notes: Vector of tuples that contains (key, start_tick, duration)
pub fn add_notes_batch(
    ctx: &mut DawContext,
    pattern_id: PatternId,
    notes_data: Vec<(u8, u64, Option<u64>)>,
) -> anyhow::Result<Vec<Note>> {
    // 1. Mutate state
    let added_notes = ctx
        .app_state
        .add_notes_to_pattern_batch(pattern_id, &notes_data)?;

    // 2. Update history
    if !added_notes.is_empty() {
        let mut actions = Vec::with_capacity(added_notes.len());
        for note in &added_notes {
            actions.push(ProjectAction::AddNote {
                pattern_id,
                note: note.clone(),
            });
        }
        if actions.len() == 1 {
            ctx.push_history(actions.remove(0));
        } else {
            ctx.push_history(ProjectAction::Batch(actions));
        }
        ctx.broadcast_track_graph();
    }

    Ok(added_notes)
}

/// Removes selected notes from one pattern as a single history action.
pub fn delete_notes_batch(
    ctx: &mut DawContext,
    pattern_id: PatternId,
    note_ids: Vec<NoteId>,
) -> anyhow::Result<()> {
    // 1. Mutate state
    let deleted_notes = ctx
        .app_state
        .delete_notes_from_pattern_batch(pattern_id, &note_ids)?;

    // 2. Update history
    if !deleted_notes.is_empty() {
        let mut actions = Vec::with_capacity(deleted_notes.len());
        for note in deleted_notes {
            actions.push(ProjectAction::DeleteNote { pattern_id, note });
        }
        if actions.len() == 1 {
            ctx.push_history(actions.remove(0));
        } else {
            ctx.push_history(ProjectAction::Batch(actions));
        }
        ctx.broadcast_track_graph();
    }

    Ok(())
}

/// Updates is Vec of (note_id, new_tick, new_key)
pub fn move_notes_batch(
    ctx: &mut DawContext,
    pattern_id: PatternId,
    updates: Vec<(NoteId, u64, u8)>, // (note_id, new_tick, new_key)
) -> anyhow::Result<Vec<Note>> {
    // 1. Mutate state
    let moved_data = ctx
        .app_state
        .move_notes_in_pattern_batch(pattern_id, &updates)?;

    // 2. Update history
    let mut final_notes = Vec::with_capacity(moved_data.len());
    if !moved_data.is_empty() {
        let mut actions = Vec::with_capacity(moved_data.len());
        for (note, old_tick, old_key) in moved_data {
            actions.push(ProjectAction::MoveNote {
                pattern_id,
                note_id: note.id,
                old_tick,
                old_key,
                new_tick: note.start_tick,
                new_key: note.key,
            });
            final_notes.push(note);
        }
        // let mut history = get_history_lock();
        if actions.len() == 1 {
            ctx.push_history(actions.remove(0));
        } else {
            ctx.push_history(ProjectAction::Batch(actions));
        }
        ctx.broadcast_track_graph();
    }

    Ok(final_notes)
}

/// updates is Vec of (note id, new size)
pub fn resize_notes_batch(
    ctx: &mut DawContext,
    pattern_id: PatternId,
    updates: Vec<(NoteId, u64)>, // (note_id, new_duration)
) -> anyhow::Result<Vec<Note>> {
    // 1. Mutate state
    let resized_data = ctx
        .app_state
        .resize_notes_in_pattern_batch(pattern_id, &updates)?;

    // 2. Update history
    let mut final_notes = Vec::with_capacity(resized_data.len());
    if !resized_data.is_empty() {
        let mut actions = Vec::with_capacity(resized_data.len());
        for (note, old_duration) in resized_data {
            actions.push(ProjectAction::ResizeNote {
                pattern_id,
                note_id: note.id,
                old_duration,
                new_duration: note.duration,
            });
            final_notes.push(note);
        }
        if actions.len() == 1 {
            ctx.push_history(actions.remove(0));
        } else {
            ctx.push_history(ProjectAction::Batch(actions));
        }
        ctx.broadcast_track_graph();
    }

    Ok(final_notes)
}

// ==============================================================================
// Piano-roll transforms
// ==============================================================================
//
// Each transform applies to the given notes, or to the whole pattern when `note_ids` is empty,
// commits as one undo step, and returns the resulting pattern.

fn commit_note_edit(
    ctx: &mut DawContext,
    pattern_id: PatternId,
    edit: NoteEdit,
) -> anyhow::Result<Pattern> {
    let mut actions = ctx.app_state.apply_note_edit(pattern_id, edit)?;
    if !actions.is_empty() {
        if actions.len() == 1 {
            ctx.push_history(actions.remove(0));
        } else {
            ctx.push_history(ProjectAction::Batch(actions));
        }
        ctx.broadcast_track_graph();
    }
    ctx.app_state
        .pattern_pool
        .get(pattern_id)
        .cloned()
        .ok_or_else(|| anyhow::anyhow!("Pattern {} not found", pattern_id.to_u32()))
}

fn transform_notes(
    ctx: &mut DawContext,
    pattern_id: PatternId,
    note_ids: &[NoteId],
    transform: impl FnOnce(&[Note]) -> anyhow::Result<NoteEdit>,
) -> anyhow::Result<Pattern> {
    let notes = ctx.app_state.pattern_notes_for(pattern_id, note_ids)?;
    let edit = transform(&notes)?;
    commit_note_edit(ctx, pattern_id, edit)
}

/// Snaps note starts and ends to the nearest multiple of `step_ticks`.
pub fn quantize_notes(
    ctx: &mut DawContext,
    pattern_id: PatternId,
    note_ids: &[NoteId],
    step_ticks: u64,
) -> anyhow::Result<Pattern> {
    anyhow::ensure!(step_ticks > 0, "Quantize step must be positive");
    transform_notes(ctx, pattern_id, note_ids, |notes| {
        Ok(note_transform::quantize(notes, step_ticks))
    })
}

/// Snaps only note starts to the nearest multiple of `step_ticks`, keeping lengths.
pub fn quantize_note_starts(
    ctx: &mut DawContext,
    pattern_id: PatternId,
    note_ids: &[NoteId],
    step_ticks: u64,
) -> anyhow::Result<Pattern> {
    anyhow::ensure!(step_ticks > 0, "Quantize step must be positive");
    transform_notes(ctx, pattern_id, note_ids, |notes| {
        Ok(note_transform::quantize_start(notes, step_ticks))
    })
}

/// Stretches each note to the start of the next note so the line plays legato.
pub fn legato_notes(
    ctx: &mut DawContext,
    pattern_id: PatternId,
    note_ids: &[NoteId],
) -> anyhow::Result<Pattern> {
    transform_notes(ctx, pattern_id, note_ids, |notes| {
        Ok(note_transform::legato(notes))
    })
}

/// Randomizes note timing by up to `timing_ticks` and velocity by up to `velocity_amount`.
/// The same `seed` reproduces the same result.
pub fn humanize_notes(
    ctx: &mut DawContext,
    pattern_id: PatternId,
    note_ids: &[NoteId],
    timing_ticks: u64,
    velocity_amount: u8,
    seed: u64,
) -> anyhow::Result<Pattern> {
    transform_notes(ctx, pattern_id, note_ids, |notes| {
        Ok(note_transform::humanize(
            notes,
            timing_ticks,
            velocity_amount,
            seed,
        ))
    })
}

/// Splits notes into pieces at every multiple of `step_ticks`.
pub fn chop_notes(
    ctx: &mut DawContext,
    pattern_id: PatternId,
    note_ids: &[NoteId],
    step_ticks: u64,
) -> anyhow::Result<Pattern> {
    anyhow::ensure!(step_ticks > 0, "Chop step must be positive");
    transform_notes(ctx, pattern_id, note_ids, |notes| {
        Ok(note_transform::chop(notes, step_ticks))
    })
}

/// Cuts one note in two at `at_tick`.
pub fn slice_note(
    ctx: &mut DawContext,
    pattern_id: PatternId,
    note_id: NoteId,
    at_tick: u64,
) -> anyhow::Result<Pattern> {
    transform_notes(ctx, pattern_id, &[note_id], |notes| {
        let note = notes
            .first()
            .ok_or_else(|| anyhow::anyhow!("Note {} not found", note_id.to_u32()))?;
        Ok(note_transform::slice(note, at_tick))
    })
}

/// Transposes notes by `semitones`; fails if any note would leave the MIDI range.
pub fn transpose_notes(
    ctx: &mut DawContext,
    pattern_id: PatternId,
    note_ids: &[NoteId],
    semitones: i32,
) -> anyhow::Result<Pattern> {
    transform_notes(ctx, pattern_id, note_ids, |notes| {
        note_transform::transpose(notes, semitones)
    })
}

/// Moves notes by `delta_ticks` in time, stopping the group at tick 0.
pub fn shift_notes(
    ctx: &mut DawContext,
    pattern_id: PatternId,
    note_ids: &[NoteId],
    delta_ticks: i64,
) -> anyhow::Result<Pattern> {
    transform_notes(ctx, pattern_id, note_ids, |notes| {
        Ok(note_transform::shift(notes, delta_ticks))
    })
}

/// Sets velocity, pan, and fine pitch per note, as one undo step.
pub fn set_note_params_batch(
    ctx: &mut DawContext,
    pattern_id: PatternId,
    updates: &[(NoteId, NoteParams)],
) -> anyhow::Result<Pattern> {
    let ids: Vec<NoteId> = updates.iter().map(|(id, _)| *id).collect();
    if ids.is_empty() {
        return commit_note_edit(ctx, pattern_id, NoteEdit::default());
    }
    transform_notes(ctx, pattern_id, &ids, |notes| {
        Ok(NoteEdit {
            updates: notes
                .iter()
                .filter_map(|note| {
                    let (_, params) = updates.iter().find(|(id, _)| *id == note.id)?;
                    Some(note_transform::with_params(note, *params))
                })
                .collect(),
            additions: Vec::new(),
        })
    })
}

/// Inserts complete notes, keeping each one's velocity, pan, and pitch, such as when the draw
/// tool stamps copies of the selected notes.
pub fn add_note_copies(
    ctx: &mut DawContext,
    pattern_id: PatternId,
    notes: Vec<Note>,
) -> anyhow::Result<Pattern> {
    commit_note_edit(
        ctx,
        pattern_id,
        NoteEdit {
            updates: Vec::new(),
            additions: notes,
        },
    )
}
