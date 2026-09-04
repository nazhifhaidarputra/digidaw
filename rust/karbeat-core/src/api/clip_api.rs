use crate::context::DawContext;
use crate::core::history::ProjectAction;
use crate::core::project::clip::{Clip, ClipSourceType, ResizeEdge};
use crate::shared::id::*;

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

pub fn add_clip(
    ctx: &mut DawContext,
    source_id: Option<u32>,
    source_type: ClipSourceType,
    track_id: TrackId,
    start_time: u32,
) -> anyhow::Result<Clip> {
    // 1. Mutate state
    let clip = {
        let app = &mut ctx.app_state;
        let res = app.create_new_clip(source_id, source_type, track_id, start_time);

        res.map_err(|error| {
            log::error!("Error creating clip: {error:?}");
            error
        })?
    };

    // 2. Update history
    ctx.push_history(ProjectAction::AddClip {
        track_id,
        clip: clip.clone(),
    });

    ctx.broadcast_track_graph();

    Ok(clip)
}

#[inline(always)]
pub fn rename_clip(ctx: &mut DawContext, clip_id: ClipId, new_name: &str) -> anyhow::Result<()> {
    let app = &mut ctx.app_state;

    app.rename_clip(clip_id, new_name)?;

    // TODO: Add ProjectAction::Rename clip
    // ctx.push_history(action);
    Ok(())
}

pub fn delete_clip(
    ctx: &mut DawContext,
    track_id: TrackId,
    clip_id: ClipId,
) -> anyhow::Result<Clip> {
    // 1. Mutate state
    let app = &mut ctx.app_state;
    let deleted_clip = app.delete_clip_from_track(track_id, clip_id)?;

    // 2. Update history
    ctx.push_history(ProjectAction::DeleteClip {
        track_id,
        clip: deleted_clip.clone(),
    });

    ctx.broadcast_track_graph();

    Ok(deleted_clip)
}

pub fn move_clip(
    ctx: &mut DawContext,
    source_track_id: TrackId,
    target_track_id: TrackId,
    clip_id: ClipId,
    new_start_time: u64,
) -> anyhow::Result<Clip> {
    // 1. Capture old state if we want to support undo for single move
    let app = &mut ctx.app_state;
    let old_clip = app.get_clip(&source_track_id, &clip_id).ok_or_else(|| {
        anyhow::anyhow!(
            "Clip {:?} not found in track {:?}",
            clip_id,
            source_track_id
        )
    })?;

    // 2. Mutate state
    let modified_clip = app
        .move_clip(source_track_id, target_track_id, clip_id, new_start_time)
        .map_err(|e| anyhow::anyhow!("{}", e))?;

    // 3. Update history
    ctx.push_history(ProjectAction::MoveClip {
        old_track_id: source_track_id,
        new_track_id: target_track_id,
        clip_id,
        old_start_time: old_clip.time.start_time_raw(),
        new_start_time: modified_clip.time.start_time_raw(),
    });

    ctx.broadcast_track_graph();

    Ok(modified_clip)
}

pub fn resize_clip(
    ctx: &mut DawContext,
    track_id: TrackId,
    clip_id: ClipId,
    edge: ResizeEdge,
    new_time_val: u64,
) -> anyhow::Result<Clip> {
    // 1. Capture old state
    let app = &mut ctx.app_state;
    let old_clip = app
        .get_clip(&track_id, &clip_id)
        .ok_or_else(|| anyhow::anyhow!("Clip {:?} not found in track {:?}", clip_id, track_id))?;

    // 2. Mutate state
    let modified_clip = app
        .resize_clip(track_id, clip_id, edge, new_time_val)
        .map_err(|e| anyhow::anyhow!("{}", e))?;

    // 3. Update history
    ctx.push_history(ProjectAction::ResizeClip {
        track_id,
        old_clip,
        new_clip: modified_clip.clone(),
    });

    ctx.broadcast_track_graph();
    Ok(modified_clip)
}

pub fn slice_clip(
    ctx: &mut DawContext,
    track_id: TrackId,
    clip_id: ClipId,
    cut_point: u64,
) -> anyhow::Result<(Clip, Clip)> {
    // 1. Capture old state
    let app = &mut ctx.app_state;
    let old_clip = app
        .get_clip(&track_id, &clip_id)
        .ok_or_else(|| anyhow::anyhow!("Clip {:?} not found in track {:?}", clip_id, track_id))?;

    // 2. Mutate state
    let (c1, c2) = app
        .slice_clip(&track_id, &clip_id, cut_point)
        .map_err(|e| anyhow::anyhow!("{}", e))?;

    // 3. Update history (as a batch: delete old, add two new)
    ctx.push_history(ProjectAction::Batch(vec![
        ProjectAction::DeleteClip {
            track_id,
            clip: old_clip,
        },
        ProjectAction::AddClip {
            track_id,
            clip: c1.clone(),
        },
        ProjectAction::AddClip {
            track_id,
            clip: c2.clone(),
        },
    ]));

    ctx.broadcast_track_graph();
    Ok((c1, c2))
}

pub fn batch_delete_clips(
    ctx: &mut DawContext,
    track_id: TrackId,
    clip_ids: Vec<ClipId>,
) -> anyhow::Result<()> {
    let mut deleted_actions = Vec::new();

    // 1. Mutate state and wllect actions
    let app = &mut ctx.app_state;
    for clip_id in clip_ids {
        if let Ok(deleted_clip) = app.delete_clip_from_track(track_id, clip_id) {
            deleted_actions.push(ProjectAction::DeleteClip {
                track_id,
                clip: deleted_clip.clone(),
            });
        }
    }

    // 2. Update history
    if !deleted_actions.is_empty() {
        if deleted_actions.len() == 1 {
            ctx.push_history(deleted_actions.remove(0));
        } else {
            ctx.push_history(ProjectAction::Batch(deleted_actions));
        }
    }
    ctx.broadcast_track_graph();
    Ok(())
}

pub fn batch_move_clips(
    ctx: &mut DawContext,
    source_track_id: TrackId,
    target_track_id: TrackId,
    clip_ids: Vec<ClipId>,
    delta_ticks: i64,
) -> anyhow::Result<Vec<Clip>> {
    let app = &mut ctx.app_state;
    // 1. Capture old states
    let old_clips = clip_ids
        .iter()
        .filter_map(|id| app.get_clip(&source_track_id, id))
        .collect::<Vec<_>>();

    // 2. Mutate state
    let modified_clips = app
        .move_clip_batch(source_track_id, target_track_id, clip_ids, delta_ticks)
        .map_err(|e| anyhow::anyhow!("{}", e))?;

    // 3. Update history
    let mut history_actions = Vec::new();
    for (old, new) in old_clips.iter().zip(modified_clips.iter()) {
        history_actions.push(ProjectAction::MoveClip {
            old_track_id: source_track_id,
            new_track_id: target_track_id,
            clip_id: new.id,
            old_start_time: old.time.start_time_raw(),
            new_start_time: new.time.start_time_raw(),
        });
    }

    if !history_actions.is_empty() {
        // let mut history = get_history_lock();
        if history_actions.len() == 1 {
            ctx.push_history(history_actions.remove(0));
        } else {
            ctx.push_history(ProjectAction::Batch(history_actions));
        }
    }
    ctx.broadcast_track_graph();
    Ok(modified_clips)
}

pub fn batch_resize_clips(
    ctx: &mut DawContext,
    track_id: TrackId,
    clip_ids: Vec<ClipId>,
    edge: ResizeEdge,
    delta_ticks: i64,
) -> anyhow::Result<Vec<Clip>> {
    // 1. Capture old states
    let app = &mut ctx.app_state;
    let old_clips = clip_ids
        .iter()
        .filter_map(|id| app.get_clip(&track_id, id))
        .collect::<Vec<_>>();

    // 2. Mutate state
    let modified_clips = app
        .resize_clip_batch(track_id, clip_ids, edge, delta_ticks)
        .map_err(|e| anyhow::anyhow!("{}", e))?;

    // 3. Update history

    let mut history_actions = Vec::new();
    for (old, new) in old_clips.iter().zip(modified_clips.iter()) {
        history_actions.push(ProjectAction::ResizeClip {
            track_id,
            old_clip: old.clone(),
            new_clip: new.clone(),
        });
    }

    if !history_actions.is_empty() {
        if history_actions.len() == 1 {
            ctx.push_history(history_actions.remove(0));
        } else {
            ctx.push_history(ProjectAction::Batch(history_actions));
        }
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
    let duplicated = ctx
        .app_state
        .duplicate_clip_groups(track_id, &clip_ids, &group_start_times)
        .map_err(anyhow::Error::msg)?;

    if duplicated.is_empty() {
        return Ok(duplicated);
    }

    let actions = duplicated
        .iter()
        .cloned()
        .map(|clip| ProjectAction::AddClip { track_id, clip })
        .collect();
    ctx.push_history(ProjectAction::Batch(actions));
    ctx.broadcast_track_graph();

    Ok(duplicated)
}
