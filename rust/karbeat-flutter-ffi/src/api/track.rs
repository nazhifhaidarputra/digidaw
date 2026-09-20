// rust\src\api\track.rs

use crate::api::project::{UiClip, UiTrack};
use crate::api::context::DawContext;
use karbeat_core::api::{clip_api, track_api};
use karbeat_core::core::project::clip::ResizeEdge;
use karbeat_core::shared::id::*;

pub enum UiSourceType {
    Audio,
    Midi,
}

pub enum UiResizeEdge {
    Left,
    Right,
}

impl From<ResizeEdge> for UiResizeEdge {
    fn from(value: ResizeEdge) -> Self {
        match value {
            ResizeEdge::Left => UiResizeEdge::Left,
            ResizeEdge::Right => UiResizeEdge::Right,
        }
    }
}

impl From<&UiResizeEdge> for ResizeEdge {
    fn from(value: &UiResizeEdge) -> Self {
        match value {
            UiResizeEdge::Left => ResizeEdge::Left,
            UiResizeEdge::Right => ResizeEdge::Right,
        }
    }
}

impl From<UiResizeEdge> for ResizeEdge {
    fn from(value: UiResizeEdge) -> Self {
        match value {
            UiResizeEdge::Left => ResizeEdge::Left,
            UiResizeEdge::Right => ResizeEdge::Right,
        }
    }
}

pub fn create_clip(
    ctx: &DawContext,
    source_id: Option<u64>,
    source_type: UiSourceType,
    track_id: u64,
    start_time: u32,
) -> Result<UiClip, String> {
    crate::api::context::project_ctx!(ctx);
    let track_id = TrackId::from_u64(track_id);
    let core_source_type = match source_type {
        UiSourceType::Audio => karbeat_core::core::project::clip::ClipSourceType::Audio,
        UiSourceType::Midi => karbeat_core::core::project::clip::ClipSourceType::Midi,
    };

    let clip = clip_api::add_clip(ctx, source_id, core_source_type, track_id, start_time)
        .map_err(|e| format!("{}", e))?;

    let ui_clip = UiClip::from(&clip);
    Ok(ui_clip)
}

pub fn delete_clip(ctx: &DawContext, track_id: u64, clip_id: u64) -> Result<(), String> {
    crate::api::context::project_ctx!(ctx);
    let track_id = TrackId::from_u64(track_id);
    let clip_id = ClipId::from_u64(clip_id);

    clip_api::delete_clip(ctx, track_id, clip_id)
        .map_err(|e| format!("Failed to delete clip: {}", e))?;

    Ok(())
}

pub fn resize_clip(
    ctx: &DawContext,
    track_id: u64,
    clip_id: u64,
    edge: UiResizeEdge,
    new_time_val: u64,
) -> Result<UiClip, String> {
    crate::api::context::project_ctx!(ctx);
    let track_id = TrackId::from_u64(track_id);
    let clip_id = ClipId::from_u64(clip_id);
    let core_edge: ResizeEdge = edge.into();

    let res = clip_api::resize_clip(ctx, track_id, clip_id, core_edge, new_time_val)
        .map_err(|e| format!("{}", e))?;

    Ok(UiClip::from(&res))
}

pub fn move_clip(
    ctx: &DawContext,
    source_track_id: u64,
    clip_id: u64,
    new_start_time: u64,
    new_track_id: Option<u64>,
) -> Result<UiClip, String> {
    crate::api::context::project_ctx!(ctx);
    let source_track_id = TrackId::from_u64(source_track_id);
    let clip_id = ClipId::from_u64(clip_id);
    let target_track_id = new_track_id
        .map(TrackId::from_u64)
        .unwrap_or(source_track_id);

    let res = clip_api::move_clip(
        ctx,
        source_track_id,
        target_track_id,
        clip_id,
        new_start_time,
    )
    .map_err(|e| format!("{}", e))?;

    Ok(UiClip::from(&res))
}

/// Cut a clip in half.
/// This will retain the original clip at the left cut region,
/// while the right cut region will clone a new clip with the same source,
/// but with the offset at the cut point
///
/// # Parameters
///
/// - source_track_id: Track where clip resides
/// - clip_id: The cut clip id inside the track
/// - cut_point: Absolute timeline tick of the cut location
pub fn slice_clip(
    ctx: &DawContext,
    source_track_id: u64,
    clip_id: u64,
    cut_point: u64,
) -> Result<Vec<UiClip>, String> {
    crate::api::context::project_ctx!(ctx);
    let source_track_id_typed = TrackId::from_u64(source_track_id);
    let clip_id_typed = ClipId::from_u64(clip_id);

    let (c1, c2) = clip_api::slice_clip(ctx, source_track_id_typed, clip_id_typed, cut_point)
        .map_err(|e| format!("{}", e))?;

    Ok(vec![UiClip::from(&c1), UiClip::from(&c2)])
}

/// Add a MIDI track with a generator by its registry ID (preferred method).
pub fn add_midi_track_with_generator_id(
    ctx: &DawContext,
    registry_id: u32,
) -> Result<UiTrack, String> {
    let operation = ctx.begin_project_operation();
    let external = operation
        .read_core()
        .plugin_catalog
        .external(registry_id)
        .is_some();
    if !external {
        let mut core = operation.write_core();
        let track = track_api::add_midi_track_with_generator_id(&mut core, registry_id)
            .map_err(|error| error.to_string())?;
        return Ok(UiTrack::from_track(&track, &core.app_state));
    }

    let pending = {
        let core = operation.read_core();
        karbeat_core::api::external_plugin_api::begin_add_instrument(&core, registry_id)
            .map_err(|error| error.to_string())?
    };
    let completed = karbeat_core::api::external_plugin_api::execute_install(pending)
        .map_err(|error| error.to_string())?;
    let mut core = operation.write_core();
    match karbeat_core::api::external_plugin_api::commit_install(&mut core, completed) {
        karbeat_core::api::external_plugin_api::InstalledPlugin::Instrument(track) => {
            Ok(UiTrack::from_track(&track, &core.app_state))
        }
        karbeat_core::api::external_plugin_api::InstalledPlugin::Effect(_) => {
            Err("External instrument transaction returned an effect".into())
        }
    }
}

pub fn get_clip(ctx: &DawContext, track_id: u64, clip_id: u64) -> Result<UiClip, String> {
    crate::api::context::read_ctx!(ctx);
    clip_api::get_clip(
        ctx,
        TrackId::from_u64(track_id),
        ClipId::from_u64(clip_id),
        |c| UiClip::from(c),
    )
    .map_err(|e| e.to_string())
}

// Alternatively, fetching the whole Track is often useful too and still cheaper than all tracks
pub fn get_track(ctx: &DawContext, track_id: u64) -> Option<UiTrack> {
    crate::api::context::read_ctx!(ctx);
    track_api::get_track(ctx, TrackId::from_u64(track_id), |t| {
        UiTrack::from_track(t, &ctx.app_state)
    })
}

// =====================================
// API for multiple actions at once
// =====================================

/// move clips in batch
pub fn move_clip_batch(
    ctx: &DawContext,
    source_track_id: u64,
    clip_ids: Vec<u64>,
    delta_ticks: i64,
    new_track_id: Option<u64>,
) -> Result<Vec<UiClip>, String> {
    crate::api::context::project_ctx!(ctx);
    let source_track_id = TrackId::from_u64(source_track_id);
    let target_track_id = new_track_id
        .map(TrackId::from_u64)
        .unwrap_or(source_track_id);
    let clip_ids: Vec<ClipId> = clip_ids.into_iter().map(ClipId::from_u64).collect();

    let res =
        clip_api::batch_move_clips(ctx, source_track_id, target_track_id, clip_ids, delta_ticks)
            .map_err(|e| format!("{}", e))?;

    Ok(res.iter().map(UiClip::from).collect())
}

/// Resize clips in batch by a delta amount
pub fn resize_clip_batch(
    ctx: &DawContext,
    track_id: u64,
    clip_ids: Vec<u64>,
    edge: UiResizeEdge,
    delta_ticks: i64,
) -> Result<Vec<UiClip>, String> {
    crate::api::context::project_ctx!(ctx);
    let track_id = TrackId::from_u64(track_id);
    let clip_ids: Vec<ClipId> = clip_ids.into_iter().map(ClipId::from_u64).collect();
    let core_edge: ResizeEdge = edge.into();
    let res = clip_api::batch_resize_clips(ctx, track_id, clip_ids, core_edge, delta_ticks)
        .map_err(|e| format!("{}", e))?;

    Ok(res.iter().map(UiClip::from).collect())
}

/// Atomically duplicate a selected clip group at predetermined start times.
/// Start times use timeline ticks. Unlike copy/paste, this never changes
/// ClipboardContent.
pub fn duplicate_clip_groups(
    ctx: &DawContext,
    track_id: u64,
    clip_ids: Vec<u64>,
    group_start_times: Vec<u64>,
) -> Result<Vec<UiClip>, String> {
    crate::api::context::project_ctx!(ctx);
    let track_id = TrackId::from_u64(track_id);
    let clip_ids = clip_ids.into_iter().map(ClipId::from_u64).collect();
    let duplicated =
        clip_api::batch_duplicate_clip_groups(ctx, track_id, clip_ids, group_start_times)
            .map_err(|error| error.to_string())?;

    Ok(duplicated.iter().map(UiClip::from).collect())
}

/// Delete clips in batch
pub fn delete_clip_batch(
    ctx: &DawContext,
    track_id: u64,
    clip_ids: Vec<u64>,
) -> Result<(), String> {
    crate::api::context::project_ctx!(ctx);
    let track_id = TrackId::from_u64(track_id);
    let clip_ids: Vec<ClipId> = clip_ids.into_iter().map(ClipId::from_u64).collect();
    clip_api::batch_delete_clips(ctx, track_id, clip_ids)
        .map_err(|e| format!("Failed to delete clips: {}", e))?;

    Ok(())
}

pub fn change_track_name(
    ctx: &DawContext,
    track_id: u64,
    new_name: &str,
) -> Result<(), String> {
    crate::api::context::project_ctx!(ctx);
    track_api::change_track_name(ctx, TrackId::from_u64(track_id), new_name)
        .map_err(|e| e.to_string())?;
    Ok(())
}

/// Change the track header's color to a new color specified by a hex string (e.g. "#RRGGBB" or "#RRGGBBAA").
pub fn change_track_color(
    ctx: &DawContext,
    track_id: u64,
    new_color: &str,
) -> Result<(), String> {
    crate::api::context::project_ctx!(ctx);
    track_api::change_track_color(ctx, TrackId::from_u64(track_id), new_color)
        .map_err(|e| e.to_string())?;
    Ok(())
}

/// Delete a track from the timeline. This function returns a string which will be
/// "audio", "midi", or "automation"
pub fn delete_track(ctx: &DawContext, track_id: u64) -> Result<String, String> {
    let operation = ctx.begin_project_operation();
    let track_id = TrackId::from_u64(track_id);
    let external = {
        let core = operation.read_core();
        karbeat_core::api::external_plugin_api::track_targets(&core, track_id)
            .iter()
            .any(|target| {
                karbeat_core::api::external_plugin_api::descriptor(&core, *target).is_some()
            })
    };
    let removed_track_type = if external {
        let pending = {
            let core = operation.read_core();
            karbeat_core::api::external_plugin_api::begin_delete_track(&core, track_id)
                .map_err(|error| error.to_string())?
        };
        let completed = karbeat_core::api::external_plugin_api::execute_removal(pending)
            .map_err(|error| error.to_string())?;
        match karbeat_core::api::external_plugin_api::commit_removal(
            &mut operation.write_core(),
            completed,
        ) {
            karbeat_core::api::external_plugin_api::RemovedProjectItem::Track(removed) => removed,
            _ => return Err("Track removal transaction returned an incompatible result".into()),
        }
    } else {
        track_api::delete_track(&mut operation.write_core(), track_id)
            .map_err(|error| error.to_string())?
    };
    let type_string = match removed_track_type {
        karbeat_core::core::project::TrackType::Audio => "audio",
        karbeat_core::core::project::TrackType::Midi => "midi",
        karbeat_core::core::project::TrackType::Automation => "automation",
    };

    Ok(type_string.into())
}

/// Update track order in the timeline
pub fn update_track_order(
    ctx: &DawContext,
    track_id: u64,
    new_idx: usize,
) -> Result<(), String> {
    crate::api::context::project_ctx!(ctx);
    track_api::update_track_order(ctx, TrackId::from_u64(track_id), new_idx)
        .map_err(|e| e.to_string())
}

/// Rename clip. Could result in error if [new_name]
/// does not meet the required constraint or the clip not found
pub fn rename_clip(ctx: &DawContext, clip_id: u64, new_name: &str) -> Result<(), String> {
    crate::api::context::project_ctx!(ctx);
    clip_api::rename_clip(ctx, ClipId::from_u64(clip_id), new_name).map_err(|e| e.to_string())
}
