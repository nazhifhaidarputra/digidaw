use crate::context::DawContext;
use crate::core::history::actions::ClipEditRecorder;
use crate::core::project::clip::{Clip, ClipSourceType, ResizeEdge};
use crate::shared::id::*;

/// Resolves a clip through its track and maps the borrowed clip value.
pub fn get_clip<T, F>(
    ctx: &DawContext,
    track_id: TrackId,
    clip_id: ClipId,
    mapper: F,
) -> anyhow::Result<T>
where
    F: FnOnce(&Clip) -> T,
{
    let app = &ctx.app_state;
    let clip = app
        .get_clip(&track_id, &clip_id)
        .ok_or_else(|| anyhow::anyhow!("Clip {:?} not found in track {:?}", clip_id, track_id))?;

    Ok(mapper(&clip))
}

/// Creates a clip on a compatible track, records history, and updates the render graph.
pub fn add_clip(
    ctx: &mut DawContext,
    source_id: Option<u64>,
    source_type: ClipSourceType,
    track_id: TrackId,
    start_time: u32,
) -> anyhow::Result<Clip> {
    let recorder = ClipEditRecorder::begin(&ctx.app_state, "Add Clip", &[track_id], &[]);
    let clip = ctx
        .app_state
        .create_new_clip(source_id, source_type, track_id, start_time)
        .map_err(|error| {
            log::error!("Error creating clip: {error:?}");
            error
        })?;
    let action = recorder.finish(&mut ctx.app_state);
    ctx.push_history(action);

    ctx.broadcast_track_graph();

    Ok(clip)
}

#[inline(always)]
/// Renames an existing clip and records the reversible project mutation.
pub fn rename_clip(ctx: &mut DawContext, clip_id: ClipId, new_name: &str) -> anyhow::Result<()> {
    let recorder = ClipEditRecorder::begin(&ctx.app_state, "Rename Clip", &[], &[clip_id]);
    ctx.app_state.rename_clip(clip_id, new_name)?;
    let action = recorder.finish(&mut ctx.app_state);
    ctx.push_history(action);
    Ok(())
}

/// Removes a clip from its track and project pool, recording enough state for undo.
pub fn delete_clip(
    ctx: &mut DawContext,
    track_id: TrackId,
    clip_id: ClipId,
) -> anyhow::Result<Clip> {
    let recorder = ClipEditRecorder::begin(&ctx.app_state, "Delete Clip", &[track_id], &[clip_id]);
    let deleted_clip = ctx.app_state.delete_clip_from_track(track_id, clip_id)?;
    let action = recorder.finish(&mut ctx.app_state);
    ctx.push_history(action);

    ctx.broadcast_track_graph();

    Ok(deleted_clip)
}

/// Moves a clip to a compatible track and start tick as one reversible operation.
pub fn move_clip(
    ctx: &mut DawContext,
    source_track_id: TrackId,
    target_track_id: TrackId,
    clip_id: ClipId,
    new_start_time: u64,
) -> anyhow::Result<Clip> {
    ctx.app_state
        .get_clip(&source_track_id, &clip_id)
        .ok_or_else(|| anyhow::anyhow!("Clip {clip_id} not found in track {source_track_id}"))?;
    let recorder = ClipEditRecorder::begin(
        &ctx.app_state,
        "Move Clip",
        &[source_track_id, target_track_id],
        &[clip_id],
    );
    let modified_clip = ctx
        .app_state
        .move_clip(source_track_id, target_track_id, clip_id, new_start_time)
        .map_err(|e| anyhow::anyhow!("{e}"))?;
    let action = recorder.finish(&mut ctx.app_state);
    ctx.push_history(action);

    ctx.broadcast_track_graph();

    Ok(modified_clip)
}

/// Changes a clip boundary while preserving the clip type's source/pattern semantics.
pub fn resize_clip(
    ctx: &mut DawContext,
    track_id: TrackId,
    clip_id: ClipId,
    edge: ResizeEdge,
    new_time_val: u64,
) -> anyhow::Result<Clip> {
    ctx.app_state
        .get_clip(&track_id, &clip_id)
        .ok_or_else(|| anyhow::anyhow!("Clip {:?} not found in track {:?}", clip_id, track_id))?;
    let recorder = ClipEditRecorder::begin(&ctx.app_state, "Resize Clip", &[track_id], &[clip_id]);
    let modified_clip = ctx
        .app_state
        .resize_clip(track_id, clip_id, edge, new_time_val)
        .map_err(|e| anyhow::anyhow!("{}", e))?;
    let action = recorder.finish(&mut ctx.app_state);
    ctx.push_history(action);

    ctx.broadcast_track_graph();
    Ok(modified_clip)
}

/// Splits a clip at an interior project tick and returns the newly created right-hand clip.
pub fn slice_clip(
    ctx: &mut DawContext,
    track_id: TrackId,
    clip_id: ClipId,
    cut_point: u64,
) -> anyhow::Result<(Clip, Clip)> {
    ctx.app_state
        .get_clip(&track_id, &clip_id)
        .ok_or_else(|| anyhow::anyhow!("Clip {:?} not found in track {:?}", clip_id, track_id))?;
    let recorder = ClipEditRecorder::begin(&ctx.app_state, "Slice Clip", &[track_id], &[clip_id]);
    let (c1, c2) = ctx
        .app_state
        .slice_clip(&track_id, &clip_id, cut_point)
        .map_err(|e| anyhow::anyhow!("{}", e))?;
    let action = recorder.finish(&mut ctx.app_state);
    ctx.push_history(action);

    ctx.broadcast_track_graph();
    Ok((c1, c2))
}

/// Deletes selected clips in one history entry and returns the clips actually removed.
pub fn batch_delete_clips(
    ctx: &mut DawContext,
    track_id: TrackId,
    clip_ids: Vec<ClipId>,
) -> anyhow::Result<()> {
    let recorder = ClipEditRecorder::begin(&ctx.app_state, "Delete Clips", &[track_id], &clip_ids);
    let mut deleted_any = false;
    for clip_id in clip_ids {
        deleted_any |= ctx
            .app_state
            .delete_clip_from_track(track_id, clip_id)
            .is_ok();
    }
    if deleted_any {
        let action = recorder.finish(&mut ctx.app_state);
        ctx.push_history(action);
    }
    ctx.broadcast_track_graph();
    Ok(())
}

/// Applies a common track/tick movement to selected clips as one reversible mutation.
pub fn batch_move_clips(
    ctx: &mut DawContext,
    source_track_id: TrackId,
    target_track_id: TrackId,
    clip_ids: Vec<ClipId>,
    delta_ticks: i64,
) -> anyhow::Result<Vec<Clip>> {
    let recorder = ClipEditRecorder::begin(
        &ctx.app_state,
        "Move Clips",
        &[source_track_id, target_track_id],
        &clip_ids,
    );
    let modified_clips = ctx
        .app_state
        .move_clip_batch(source_track_id, target_track_id, clip_ids, delta_ticks)
        .map_err(|e| anyhow::anyhow!("{}", e))?;
    if !modified_clips.is_empty() {
        let action = recorder.finish(&mut ctx.app_state);
        ctx.push_history(action);
    }
    ctx.broadcast_track_graph();
    Ok(modified_clips)
}

/// Resizes selected clips as one reversible mutation and republishes the track graph once.
pub fn batch_resize_clips(
    ctx: &mut DawContext,
    track_id: TrackId,
    clip_ids: Vec<ClipId>,
    edge: ResizeEdge,
    delta_ticks: i64,
) -> anyhow::Result<Vec<Clip>> {
    let recorder = ClipEditRecorder::begin(&ctx.app_state, "Resize Clips", &[track_id], &clip_ids);
    let modified_clips = ctx
        .app_state
        .resize_clip_batch(track_id, clip_ids, edge, delta_ticks)
        .map_err(|e| anyhow::anyhow!("{}", e))?;
    if !modified_clips.is_empty() {
        let action = recorder.finish(&mut ctx.app_state);
        ctx.push_history(action);
    }

    ctx.broadcast_track_graph();
    Ok(modified_clips)
}

/// Atomically duplicate a selected clip group at predetermined native-unit
/// start positions. This operation does not read or modify the clipboard.
pub fn batch_duplicate_clip_groups(
    ctx: &mut DawContext,
    track_id: TrackId,
    clip_ids: Vec<ClipId>,
    group_start_times: Vec<u64>,
) -> anyhow::Result<Vec<Clip>> {
    let recorder = ClipEditRecorder::begin(&ctx.app_state, "Duplicate Clips", &[track_id], &[]);
    let duplicated = ctx
        .app_state
        .duplicate_clip_groups(track_id, &clip_ids, &group_start_times)
        .map_err(anyhow::Error::msg)?;

    if duplicated.is_empty() {
        return Ok(duplicated);
    }

    let action = recorder.finish(&mut ctx.app_state);

    ctx.push_history(action);
    ctx.broadcast_track_graph();

    Ok(duplicated)
}
