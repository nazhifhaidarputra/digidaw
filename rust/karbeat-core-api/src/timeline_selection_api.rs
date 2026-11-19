//! Edits of a timeline selection that spans several tracks and automation lanes.
//!
//! A selection never moves anything to another track or lane. Each edit runs the per-track clip
//! edits and per-lane region edits, then folds what they recorded into one undo step.

use karbeat_audio::context::DawContext;
use karbeat_core::{
    core::project::ResizeEdge,
    shared::{AutomationId, AutomationRegionId, ClipId, TrackId},
};

use crate::{automation_api, clip_api};

/// Clips and automation regions selected together on the timeline.
#[derive(Clone, Debug, Default)]
pub struct TimelineSelection {
    /// Selected clips, grouped by the track that holds them.
    pub clips: Vec<(TrackId, Vec<ClipId>)>,
    /// Selected regions, grouped by the automation lane that holds them.
    pub regions: Vec<(AutomationId, Vec<AutomationRegionId>)>,
}

impl TimelineSelection {
    /// Closest move to `delta_ticks` that keeps every clip at or after tick zero and every
    /// region clear of the regions it would run into.
    pub fn clamp_move(&self, ctx: &DawContext, delta_ticks: i64) -> i64 {
        let app = &ctx.app_state;
        let mut delta = delta_ticks;
        for clip_id in self.clips.iter().flat_map(|(_, clips)| clips) {
            if let Some(clip) = app.clips_pool.get(*clip_id) {
                let start = i64::try_from(clip.time.start_time_raw()).unwrap_or(i64::MAX);
                delta = delta.max(start.saturating_neg());
            }
        }
        for (lane_id, region_ids) in &self.regions {
            if let Some(lane) = app.automation_pool.get(*lane_id) {
                delta = clamp_toward_zero(delta, lane.clamp_region_move(region_ids, delta));
            }
        }
        delta
    }

    /// Closest resize to `delta_ticks` that keeps every region at least one tick long and clear
    /// of its neighbours. Clip limits are left to the clip edit.
    pub fn clamp_resize(&self, ctx: &DawContext, edge: ResizeEdge, delta_ticks: i64) -> i64 {
        let app = &ctx.app_state;
        let mut delta = delta_ticks;
        for (lane_id, region_ids) in &self.regions {
            if let Some(lane) = app.automation_pool.get(*lane_id) {
                delta = clamp_toward_zero(delta, lane.clamp_region_resize(region_ids, edge, delta));
            }
        }
        delta
    }
}

/// The smaller of two moves in the same direction as `delta`.
fn clamp_toward_zero(delta: i64, limit: i64) -> i64 {
    if delta >= 0 {
        delta.min(limit.max(0))
    } else {
        delta.max(limit.min(0))
    }
}

/// Runs `edit` and folds the steps it records into one undo step named `label`, even when it
/// fails part way, so one undo reverts whatever it did.
fn as_one_step<T>(
    ctx: &mut DawContext,
    label: &'static str,
    edit: impl FnOnce(&mut DawContext) -> anyhow::Result<T>,
) -> anyhow::Result<T> {
    let mark = ctx.history.mark();
    let result = edit(ctx);
    ctx.history.group_since(mark, label);
    result
}

/// Moves every selected clip and region by the same number of ticks, on its own track or lane.
/// Returns the move applied after clamping with [`TimelineSelection::clamp_move`].
pub fn move_selection(
    ctx: &mut DawContext,
    selection: &TimelineSelection,
    delta_ticks: i64,
) -> anyhow::Result<i64> {
    let delta = selection.clamp_move(ctx, delta_ticks);
    if delta == 0 {
        return Ok(0);
    }
    as_one_step(ctx, "Move Selection", |ctx| {
        for (track_id, clip_ids) in &selection.clips {
            clip_api::batch_move_clips(ctx, *track_id, *track_id, clip_ids.clone(), delta)?;
        }
        for (lane_id, region_ids) in &selection.regions {
            automation_api::move_automation_regions(ctx, *lane_id, region_ids, delta)?;
        }
        Ok(delta)
    })
}

/// Moves one edge of every selected clip and region by the same number of ticks. With
/// `stretch`, audio clips stretch their audio. Returns the resize applied after clamping with
/// [`TimelineSelection::clamp_resize`].
pub fn resize_selection(
    ctx: &mut DawContext,
    selection: &TimelineSelection,
    edge: ResizeEdge,
    delta_ticks: i64,
    stretch: bool,
) -> anyhow::Result<i64> {
    let delta = selection.clamp_resize(ctx, edge, delta_ticks);
    if delta == 0 {
        return Ok(0);
    }
    as_one_step(ctx, "Resize Selection", |ctx| {
        for (track_id, clip_ids) in &selection.clips {
            clip_api::batch_resize_clips(ctx, *track_id, clip_ids.clone(), edge, delta, stretch)?;
        }
        for (lane_id, region_ids) in &selection.regions {
            automation_api::resize_automation_regions(ctx, *lane_id, region_ids, edge, delta)?;
        }
        Ok(delta)
    })
}

/// Deletes every selected clip and region.
pub fn delete_selection(ctx: &mut DawContext, selection: &TimelineSelection) -> anyhow::Result<()> {
    as_one_step(ctx, "Delete Selection", |ctx| {
        for (track_id, clip_ids) in &selection.clips {
            clip_api::batch_delete_clips(ctx, *track_id, clip_ids.clone())?;
        }
        for (lane_id, region_ids) in &selection.regions {
            automation_api::delete_automation_regions(ctx, *lane_id, region_ids)?;
        }
        Ok(())
    })
}

/// Cuts every listed clip and region at `at_tick`. Callers list only what the tick cuts through.
pub fn slice_selection(
    ctx: &mut DawContext,
    selection: &TimelineSelection,
    at_tick: u32,
) -> anyhow::Result<()> {
    as_one_step(ctx, "Slice Selection", |ctx| {
        for (track_id, clip_ids) in &selection.clips {
            for clip_id in clip_ids {
                clip_api::slice_clip(ctx, *track_id, *clip_id, u64::from(at_tick))?;
            }
        }
        for (lane_id, region_ids) in &selection.regions {
            for region_id in region_ids {
                automation_api::slice_automation_region(ctx, *lane_id, *region_id, at_tick)?;
            }
        }
        Ok(())
    })
}

#[cfg(test)]
mod tests {
    use super::clamp_toward_zero;

    #[test]
    fn clamping_keeps_the_direction_and_takes_the_tighter_limit() {
        assert_eq!(clamp_toward_zero(100, 40), 40);
        assert_eq!(clamp_toward_zero(100, -5), 0);
        assert_eq!(clamp_toward_zero(-100, -40), -40);
        assert_eq!(clamp_toward_zero(-100, 10), 0);
    }
}
