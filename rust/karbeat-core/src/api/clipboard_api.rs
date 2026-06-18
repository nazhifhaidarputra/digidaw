use crate::{
    context::DawContext,
    core::{
        history::ProjectAction,
        project::{clip::ClipTimeUnit, Clip, ClipboardContent, Note},
    },
    shared::{ClipId, NoteId, PatternId, TrackId},
};

pub fn get_clipboard_contents<T, F>(ctx: &DawContext, mapper: F) -> T
where
    F: FnOnce(&ClipboardContent) -> T,
{
    let app = &ctx.app_state;
    mapper(&app.clipboard)
}

pub fn copy_pattern_notes<T, F>(
    ctx: &mut DawContext,
    pattern_id: PatternId,
    note_ids: Vec<NoteId>,
    mapper: F,
) -> anyhow::Result<T>
where
    F: FnOnce(&ClipboardContent) -> T,
{
    let app = &mut ctx.app_state;

    app.copy_pattern_notes_batch(pattern_id, &note_ids)?;

    // Pass the internal reference to the closure before the lock drops
    Ok(mapper(&app.clipboard))
}

pub fn paste_notes<T, F>(
    ctx: &mut DawContext,
    target_pattern_id: PatternId,
    playhead_tick: u64,
    target_key: Option<u8>,
    mapper: F,
) -> anyhow::Result<Vec<T>>
where
    F: Fn(&Note) -> T,
{
    let app = &mut ctx.app_state;
    let inserted_notes =
        app.paste_pattern_notes_batch(&target_pattern_id, playhead_tick, target_key)?;

    if inserted_notes.is_empty() {
        return Ok(Vec::new());
    }

    let mut actions = Vec::with_capacity(inserted_notes.len());
    for note in inserted_notes.iter() {
        actions.push(ProjectAction::AddNote {
            pattern_id: target_pattern_id,
            note: note.clone(),
        });
    }

    let history = &mut ctx.history;
    if actions.len() == 1 {
        history.push(actions.remove(0));
    } else {
        history.push(ProjectAction::Batch(actions));
    }

    ctx.broadcast_track_graph();
    Ok(inserted_notes.iter().map(mapper).collect())
}

pub fn cut_notes(
    ctx: &mut DawContext,
    pattern_id: PatternId,
    note_ids: Vec<NoteId>,
) -> anyhow::Result<()> {
    if note_ids.is_empty() {
        return Ok(());
    }

    // 1. Mutate state
    let app = &mut ctx.app_state;
    let deleted_notes = app.cut_pattern_notes_batch(pattern_id, &note_ids)?;

    if deleted_notes.is_empty() {
        return Ok(());
    }

    // 2. Update history
    let mut actions = Vec::with_capacity(deleted_notes.len());
    for note in deleted_notes {
        actions.push(ProjectAction::DeleteNote { pattern_id, note });
    }

    // let mut history = get_history_lock();
    if actions.len() == 1 {
        ctx.push_history(actions.remove(0));
    } else {
        ctx.push_history(ProjectAction::Batch(actions));
    }

    // 3. Notify UI
    ctx.broadcast_track_graph();
    Ok(())
}

pub fn copy_clips(ctx: &mut DawContext, source_track_id: TrackId, clip_ids: &[ClipId]) {
    if clip_ids.is_empty() {
        return;
    }

    let app = &mut ctx.app_state;
    let _ = app.copy_clip_batch(source_track_id, clip_ids);
}

pub fn cut_clips(ctx: &mut DawContext, source_track_id: TrackId, clip_ids: Vec<ClipId>) {
    if clip_ids.is_empty() {
        return;
    }

    // 1. Mutate state
    let app = &mut ctx.app_state;
    let deleted_clips = app.cut_clipboard_clip_batch(source_track_id, &clip_ids);

    if deleted_clips.is_empty() {
        return;
    }

    // 2. Update history
    let mut actions = Vec::with_capacity(deleted_clips.len());
    for clip in deleted_clips {
        actions.push(ProjectAction::DeleteClip {
            track_id: source_track_id,
            clip,
        });
    }

    if actions.len() == 1 {
        ctx.push_history(actions.remove(0));
    } else {
        ctx.push_history(ProjectAction::Batch(actions));
    }

    ctx.broadcast_track_graph();
}

pub fn paste_clips(
    ctx: &mut DawContext,
    target_track_id: TrackId,
    paste_start_time: ClipTimeUnit,
) -> anyhow::Result<Vec<Clip>> {
    // Mutate state
    let app = &mut ctx.app_state;
    let pasted_clips = app.paste_clip_batch(target_track_id, paste_start_time)?;

    if pasted_clips.is_empty() {
        return Ok(Vec::new());
    }

    // 2. Update history
    let mut actions = Vec::with_capacity(pasted_clips.len());
    for clip in pasted_clips.clone() {
        actions.push(ProjectAction::AddClip {
            track_id: target_track_id,
            clip,
        });
    }

    if actions.len() == 1 {
        ctx.push_history(actions.remove(0));
    } else {
        ctx.push_history(ProjectAction::Batch(actions));
    }

    ctx.broadcast_track_graph();
    Ok(pasted_clips)
}
