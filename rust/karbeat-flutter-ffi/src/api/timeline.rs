//! api/timeline.rs
//! Song loop region and cue markers. Every edit returns the whole timeline, which is small.

use flutter_rust_bridge::frb;
use karbeat_core::core::project::{LoopRegion, TimelineState};
use karbeat_core::shared::id::CueMarkerId;
use karbeat_core_api::timeline_api;

use crate::api::context::DawContext;

#[derive(Clone, Copy)]
#[frb(dart_metadata=("freezed"))]
pub struct UiLoopRegion {
    pub start_tick: u64,
    pub end_tick: u64,
}

impl From<LoopRegion> for UiLoopRegion {
    fn from(region: LoopRegion) -> Self {
        Self {
            start_tick: region.start_tick,
            end_tick: region.end_tick,
        }
    }
}

#[derive(Clone)]
#[frb(dart_metadata=("freezed"))]
pub struct UiCueMarker {
    pub id: u64,
    pub name: String,
    pub tick: u64,
    /// Hex color, `#RRGGBBAA`.
    pub color: String,
}

#[derive(Clone, Default)]
#[frb(dart_metadata=("freezed"))]
pub struct UiTimelineState {
    pub loop_region: Option<UiLoopRegion>,
    /// Markers ordered by position.
    pub markers: Vec<UiCueMarker>,
}

impl From<&TimelineState> for UiTimelineState {
    fn from(timeline: &TimelineState) -> Self {
        Self {
            loop_region: timeline.loop_region.map(UiLoopRegion::from),
            markers: timeline
                .markers_by_tick()
                .into_iter()
                .map(|(id, marker)| UiCueMarker {
                    id: id.to_u64(),
                    name: marker.name.clone(),
                    tick: marker.tick,
                    color: marker.color.to_string(),
                })
                .collect(),
        }
    }
}

/// Current loop region and cue markers.
pub fn get_timeline_state(ctx: &DawContext) -> UiTimelineState {
    UiTimelineState::from(&ctx.read().app_state.timeline)
}

/// Sets the song loop region, or clears it with `None`.
pub fn set_loop_region(
    ctx: &DawContext,
    region: Option<UiLoopRegion>,
) -> Result<UiTimelineState, String> {
    let mut ctx = ctx.project_write();
    timeline_api::set_loop_region(
        &mut ctx,
        region.map(|region| (region.start_tick, region.end_tick)),
    )
    .map_err(|e| e.to_string())?;
    Ok(UiTimelineState::from(&ctx.app_state.timeline))
}

/// Adds a cue marker at `tick`; without a name it is numbered.
pub fn add_cue_marker(
    ctx: &DawContext,
    tick: u64,
    name: Option<String>,
) -> Result<UiTimelineState, String> {
    let mut ctx = ctx.project_write();
    timeline_api::add_cue_marker(&mut ctx, tick, name).map_err(|e| e.to_string())?;
    Ok(UiTimelineState::from(&ctx.app_state.timeline))
}

/// Replaces a cue marker's name, position, and color (`#RRGGBB` or `#RRGGBBAA`).
pub fn update_cue_marker(
    ctx: &DawContext,
    id: u64,
    name: String,
    tick: u64,
    color: String,
) -> Result<UiTimelineState, String> {
    let mut ctx = ctx.project_write();
    timeline_api::update_cue_marker(&mut ctx, CueMarkerId::from_u64(id), name, tick, &color)
        .map_err(|e| e.to_string())?;
    Ok(UiTimelineState::from(&ctx.app_state.timeline))
}

/// Removes a cue marker.
pub fn remove_cue_marker(ctx: &DawContext, id: u64) -> Result<UiTimelineState, String> {
    let mut ctx = ctx.project_write();
    timeline_api::remove_cue_marker(&mut ctx, CueMarkerId::from_u64(id))
        .map_err(|e| e.to_string())?;
    Ok(UiTimelineState::from(&ctx.app_state.timeline))
}
