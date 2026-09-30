use karbeat_core::context::DawContext;
use karbeat_core::core::history::actions::{CueMarkersChanged, LoopRegionChanged};
use karbeat_core::core::project::{CueMarker, LoopRegion};
use karbeat_core::shared::id::CueMarkerId;
use karbeat_utils::color::Color;

/// Sets the song loop region, or clears it with `None`, and queues it to the audio thread.
///
/// Setting the region it already has records nothing.
pub fn set_loop_region(ctx: &mut DawContext, region: Option<(u64, u64)>) -> anyhow::Result<()> {
    let region = region
        .map(|(start, end)| LoopRegion::new(start, end))
        .transpose()?;
    if ctx.app_state.timeline.loop_region == region {
        return Ok(());
    }
    let previous = std::mem::replace(&mut ctx.app_state.timeline.loop_region, region);
    ctx.push_history(LoopRegionChanged::new(previous));
    ctx.broadcast_loop_region();
    Ok(())
}

/// Adds a cue marker at `tick`. Without a name it is numbered after the existing markers.
pub fn add_cue_marker(
    ctx: &mut DawContext,
    tick: u64,
    name: Option<String>,
) -> anyhow::Result<CueMarkerId> {
    let timeline = &mut ctx.app_state.timeline;
    let name = name.unwrap_or_else(|| format!("Marker {}", timeline.markers.len() + 1));
    let previous = timeline.markers.clone();
    let id = timeline.add_marker(CueMarker {
        name,
        tick,
        ..CueMarker::default()
    })?;
    ctx.push_history(CueMarkersChanged::new(previous, "Add Cue Marker"));
    Ok(id)
}

/// Replaces a cue marker's name, position, and color (`#RRGGBB` or `#RRGGBBAA`).
///
/// An edit that only changes the position is recorded as a move, so dragging a marker undoes
/// in one step.
pub fn update_cue_marker(
    ctx: &mut DawContext,
    id: CueMarkerId,
    name: String,
    tick: u64,
    color: &str,
) -> anyhow::Result<()> {
    let color = Color::new_from_string(color).ok_or_else(|| {
        anyhow::anyhow!("Invalid color format. Use hex string like #RRGGBB or #RRGGBBAA")
    })?;
    let timeline = &mut ctx.app_state.timeline;
    let current = timeline
        .markers
        .get(id)
        .ok_or_else(|| anyhow::anyhow!("Cue marker not found"))?;
    let updated = CueMarker { name, tick, color };
    if *current == updated {
        return Ok(());
    }
    let only_moved = current.name == updated.name.trim() && current.color == updated.color;
    let previous = timeline.markers.clone();
    timeline.update_marker(id, updated)?;
    ctx.push_history(if only_moved {
        CueMarkersChanged::moved(previous, id)
    } else {
        CueMarkersChanged::new(previous, "Edit Cue Marker")
    });
    Ok(())
}

/// Removes a cue marker.
pub fn remove_cue_marker(ctx: &mut DawContext, id: CueMarkerId) -> anyhow::Result<()> {
    let timeline = &mut ctx.app_state.timeline;
    let previous = timeline.markers.clone();
    timeline.remove_marker(id)?;
    ctx.push_history(CueMarkersChanged::new(previous, "Remove Cue Marker"));
    Ok(())
}
