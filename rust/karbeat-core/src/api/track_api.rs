use crate::context::DawContext;
use crate::core::project::track::RemovedTrackType;
use crate::core::project::AudioTrack;
use crate::shared::id::*;
use karbeat_utils::color::Color;

pub fn get_track<T, F>(ctx: &DawContext, track_id: TrackId, mapper: F) -> Option<T>
where
    F: Fn(&AudioTrack) -> T,
{
    let track = ctx.app_state
        .tracks
        .get(&track_id)?;
    Some(mapper(track))
}

pub fn add_midi_track_with_generator_id(ctx: &mut DawContext, registry_id: u32) -> anyhow::Result<AudioTrack> {
    let (audio_track, _ ,_) = ctx.app_state.add_new_midi_track_with_generator_id(&mut ctx.plugin_registry, registry_id)?;
    ctx.broadcast_track_graph();
    Ok(audio_track)
}

pub fn change_track_name(ctx: &mut DawContext, track_id: TrackId, new_name: &str) -> anyhow::Result<()> {
    if new_name.len() > 20 {
        return Err(anyhow::anyhow!("Track name cannot exceed 20 characters"));
    }
    let track = ctx.app_state
        .tracks
        .get_mut(&track_id)
        .ok_or_else(|| anyhow::anyhow!("Track not found"))?;
    track.name = new_name.to_string();
    Ok(())
}

pub fn change_track_color(ctx: &mut DawContext, track_id: TrackId, new_color: &str) -> anyhow::Result<()> {
    let track = ctx.app_state
        .tracks
        .get_mut(&track_id)
        .ok_or_else(|| anyhow::anyhow!("Track not found"))?;
    track.color = Color::new_from_string(new_color).ok_or_else(|| {
        anyhow::anyhow!("Invalid color format. Use hex string like #RRGGBB or #RRGGBBAA")
    })?;
    Ok(())
}

pub fn add_new_audio_track(ctx: &mut DawContext) -> AudioTrack {
    let track = ctx.app_state.add_new_audio_track();
    ctx.broadcast_track_graph();
    track
}

pub fn get_tracks<C, U, M>(ctx: &DawContext, mapper: M) -> C
where
    M: Fn(u32, &AudioTrack) -> U,
    C: FromIterator<U>,
{
    ctx.app_state
        .tracks
        .iter()
        .map(|(id, track)| mapper(id.to_u32(), track))
        .collect()
}

/// Get tracks ordered by index (For UI)
pub fn get_tracks_ordered<C, U, M>(ctx: &DawContext, mapper: M) -> anyhow::Result<C>
where
    M: Fn(u32, &AudioTrack) -> U,
    C: FromIterator<U>,
{
    Ok(ctx.app_state
        .get_track_ordered_by_index()
        .iter()
        .map(|t| mapper(t.id.into(), t))
        .collect())
}

pub fn delete_track(ctx: &mut DawContext, track_id: TrackId) -> anyhow::Result<RemovedTrackType> {
    let deleted_track_type = ctx.app_state.remove_track(track_id)?;
    ctx.broadcast_track_graph();
    Ok(deleted_track_type)
}

/// Update track order
pub fn update_track_order(ctx: &mut DawContext, track_id: TrackId, new_idx: usize) -> anyhow::Result<()> {
    ctx.app_state.update_track_order(track_id, new_idx)
}
