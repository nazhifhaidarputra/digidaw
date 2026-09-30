use karbeat_core::context::DawContext;
use karbeat_core::core::history::actions::{ClipEditRecorder, ClipsMadeUnique};
use karbeat_core::core::project::clip::{
    Clip, ClipSourceType, ClipTimeUnit, MadeUnique, ResizeEdge,
};
use karbeat_core::core::project::envelope::GainEnvelope;
use karbeat_core::shared::id::*;

use crate::audio_analysis_api;

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
///
/// With `stretch`, an audio clip's audio is stretched to the new length instead of trimmed,
/// like the timeline's stretch mode; other clips resize as usual.
pub fn resize_clip(
    ctx: &mut DawContext,
    track_id: TrackId,
    clip_id: ClipId,
    edge: ResizeEdge,
    new_time_val: u64,
    stretch: bool,
) -> anyhow::Result<Clip> {
    let clip = ctx
        .app_state
        .get_clip(&track_id, &clip_id)
        .ok_or_else(|| anyhow::anyhow!("Clip {:?} not found in track {:?}", clip_id, track_id))?;
    if stretch && audio_analysis_api::is_audio_clip(&ctx.app_state, clip_id) {
        let delta = resize_delta(&clip.time, edge, new_time_val, &ctx.app_state);
        let stretched =
            audio_analysis_api::stretch_resize_clips(ctx, track_id, &[clip_id], edge, delta)?;
        // Nothing to stretch when the length did not change.
        return Ok(stretched.into_iter().next().unwrap_or(clip));
    }
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
///
/// With `stretch`, audio clips stretch their audio to the new length; the rest are trimmed
/// or extended.
pub fn batch_resize_clips(
    ctx: &mut DawContext,
    track_id: TrackId,
    clip_ids: Vec<ClipId>,
    edge: ResizeEdge,
    delta_ticks: i64,
    stretch: bool,
) -> anyhow::Result<Vec<Clip>> {
    let (stretching, clip_ids): (Vec<ClipId>, Vec<ClipId>) = clip_ids
        .into_iter()
        .partition(|id| stretch && audio_analysis_api::is_audio_clip(&ctx.app_state, *id));
    let mut stretched = if stretching.is_empty() {
        Vec::new()
    } else {
        audio_analysis_api::stretch_resize_clips(ctx, track_id, &stretching, edge, delta_ticks)?
    };
    if clip_ids.is_empty() {
        return Ok(stretched);
    }
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
    stretched.extend(modified_clips);
    Ok(stretched)
}

/// Tick distance from the dragged edge of `time` to `new_time_val`, the edge's new position.
fn resize_delta(
    time: &ClipTimeUnit,
    edge: ResizeEdge,
    new_time_val: u64,
    app: &karbeat_core::core::project::ApplicationState,
) -> i64 {
    let bpm = app.transport.bpm;
    let sample_rate = app.audio_config.sample_rate;
    let (start, length) = match *time {
        ClipTimeUnit::Audio {
            start_tick,
            loop_length,
            ..
        } => (
            start_tick,
            ClipTimeUnit::samples_to_ticks(loop_length, bpm, sample_rate),
        ),
        ClipTimeUnit::Samples {
            start_time,
            loop_length,
            ..
        } => (start_time, loop_length),
        ClipTimeUnit::Ticks {
            start_time,
            loop_length,
            ..
        } => (u64::from(start_time), u64::from(loop_length)),
    };
    let edge_position = match edge {
        ResizeEdge::Right => start + length,
        ResizeEdge::Left => start,
    };
    new_time_val as i64 - edge_position as i64
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

/// Gives selected clips their own copies of the waveforms or patterns they share (hard copy),
/// as one reversible operation. Clips whose content is already unique are left unchanged.
pub fn make_clips_unique(
    ctx: &mut DawContext,
    track_id: TrackId,
    clip_ids: Vec<ClipId>,
) -> anyhow::Result<MadeUnique> {
    let recorder = ClipEditRecorder::begin(&ctx.app_state, "Make Clips Unique", &[], &clip_ids);
    let made = ctx.app_state.make_clips_unique(track_id, &clip_ids)?;
    if made.clips.is_empty() {
        return Ok(made);
    }
    let clips = recorder.finish(&mut ctx.app_state);
    ctx.push_history(ClipsMadeUnique::new(clips, &made));

    if made.sources.is_empty() {
        ctx.broadcast_track_graph();
    } else {
        ctx.broadcast_full_graph();
    }
    Ok(made)
}

/// Replaces an audio clip's own gain envelope as one reversible operation.
pub fn set_clip_envelope(
    ctx: &mut DawContext,
    clip_id: ClipId,
    envelope: GainEnvelope,
) -> anyhow::Result<Clip> {
    let recorder = ClipEditRecorder::begin(&ctx.app_state, "Edit Clip Envelope", &[], &[clip_id]);
    let clip = ctx.app_state.set_clip_envelope(clip_id, envelope)?;
    let action = recorder.finish(&mut ctx.app_state);
    ctx.push_history(action);

    ctx.broadcast_track_graph();
    Ok(clip)
}
