use karbeat_core::commands::AudioCommand;
use karbeat_core::commands::MixerChannelTarget;
use karbeat_core::context::DawContext;
use karbeat_core::core::history::actions::{
    StructureRecorder, TrackRecolored, TrackRenamed, TracksReordered,
};
use karbeat_core::core::project::AudioTrack;
use karbeat_core::core::project::track::RemovedTrackType;
use karbeat_core::shared::id::*;
use karbeat_utils::color::Color;

/// Looks up a track and maps it while borrowed from project state.
pub fn get_track<T, F>(ctx: &DawContext, track_id: TrackId, mapper: F) -> Option<T>
where
    F: Fn(&AudioTrack) -> T,
{
    let track = ctx.app_state.tracks.get(track_id)?;
    Some(mapper(track))
}

/// Creates a MIDI track with an assigned generator identifier and updates the graph.
pub fn add_midi_track_with_generator_id(
    ctx: &mut DawContext,
    registry_id: u32,
) -> anyhow::Result<AudioTrack> {
    if ctx.plugin_catalog.external(registry_id).is_some() {
        return super::external_plugin_api::add_instrument(ctx, registry_id);
    }
    let structure_before = StructureRecorder::begin(&ctx.app_state, &[], &[]);
    let (audio_track, gen_id, generator_plugin_factory) = ctx
        .app_state
        .add_new_midi_track_with_generator_id(&mut ctx.plugin_registry, registry_id)?;

    let (plugin, telemetry) = ctx.prepare_plugin_install(generator_plugin_factory);
    let _ = ctx.send_audio_command(AudioCommand::InstallGenerator {
        generator_id: gen_id,
        track_id: audio_track.id,
        registry_id,
        plugin,
        telemetry: Some(telemetry),
    });

    let action = structure_before.finish(&ctx.app_state, "Add Instrument Track");
    ctx.push_history(action);
    ctx.broadcast_track_graph();
    ctx.broadcast_routing();
    Ok(audio_track)
}

/// Renames a track and records the previous name for undo.
pub fn change_track_name(
    ctx: &mut DawContext,
    track_id: TrackId,
    new_name: &str,
) -> anyhow::Result<()> {
    if new_name.len() > 20 {
        return Err(anyhow::anyhow!("Track name cannot exceed 20 characters"));
    }
    let track = ctx
        .app_state
        .tracks
        .get_mut(track_id)
        .ok_or_else(|| anyhow::anyhow!("Track not found"))?;
    let previous = std::mem::replace(&mut track.name, new_name.to_string());
    ctx.push_history(TrackRenamed::new(track_id, previous));
    Ok(())
}

/// Changes a track color and records the previous color for undo.
pub fn change_track_color(
    ctx: &mut DawContext,
    track_id: TrackId,
    new_color: &str,
) -> anyhow::Result<()> {
    let track = ctx
        .app_state
        .tracks
        .get_mut(track_id)
        .ok_or_else(|| anyhow::anyhow!("Track not found"))?;
    let color = Color::new_from_string(new_color).ok_or_else(|| {
        anyhow::anyhow!("Invalid color format. Use hex string like #RRGGBB or #RRGGBBAA")
    })?;
    let previous = std::mem::replace(&mut track.color, color);
    ctx.push_history(TrackRecolored::new(track_id, previous));
    Ok(())
}

/// Creates an audio track, records its insertion, and publishes the updated track graph.
pub fn add_new_audio_track(ctx: &mut DawContext) -> AudioTrack {
    let structure_before = StructureRecorder::begin(&ctx.app_state, &[], &[]);
    let track = ctx.app_state.add_new_audio_track();
    let action = structure_before.finish(&ctx.app_state, "Add Audio Track");
    ctx.push_history(action);
    ctx.broadcast_track_graph();
    ctx.broadcast_routing();
    track
}

/// Maps all tracks in project storage order into a caller-selected collection.
pub fn get_tracks<C, U, M>(ctx: &DawContext, mapper: M) -> C
where
    M: Fn(u64, &AudioTrack) -> U,
    C: FromIterator<U>,
{
    ctx.app_state
        .tracks
        .iter()
        .map(|(id, track)| mapper(id.to_u64(), track))
        .collect()
}

/// Get tracks ordered by index (For UI)
pub fn get_tracks_ordered<C, U, M>(ctx: &DawContext, mapper: M) -> anyhow::Result<C>
where
    M: Fn(u64, &AudioTrack) -> U,
    C: FromIterator<U>,
{
    Ok(ctx
        .app_state
        .get_track_ordered_by_index()
        .iter()
        .map(|t| mapper(t.id.to_u64(), t))
        .collect())
}

/// Removes a track and its dependent project/audio state, returning its track type.
pub fn delete_track(ctx: &mut DawContext, track_id: TrackId) -> anyhow::Result<RemovedTrackType> {
    if super::external_plugin_api::track_targets(ctx, track_id)
        .iter()
        .any(|target| super::external_plugin_api::descriptor(ctx, *target).is_some())
    {
        return super::external_plugin_api::delete_track(ctx, track_id);
    }

    let plugins = super::external_plugin_api::track_targets(ctx, track_id);
    if let Err(error) = super::project_api::capture_live_state(
        ctx,
        &plugins,
        &[MixerChannelTarget::Track(track_id)],
    ) {
        log::warn!("Deleting track without its live plugin state: {error:#}");
    }
    let structure_before = StructureRecorder::begin(&ctx.app_state, &[track_id], &[]);
    let effect_ids: Vec<_> = ctx
        .app_state
        .mixer
        .channels
        .get(track_id)
        .map(|channel| {
            channel
                .channel
                .effects
                .iter()
                .map(|effect| effect.id)
                .collect()
        })
        .unwrap_or_default();

    let generator_id = ctx
        .app_state
        .tracks
        .get(track_id)
        .and_then(|t| t.generator.as_ref().map(|g| g.id));

    let deleted_track_type = ctx.app_state.remove_track(track_id)?;

    if let Some(gen_id) = generator_id {
        let _ = ctx.send_audio_command(AudioCommand::RemoveGenerator {
            generator_id: gen_id,
        });
    }
    for effect_id in effect_ids {
        let _ = ctx.send_audio_command(AudioCommand::RemoveEffect {
            target: karbeat_core::commands::EffectTarget::Track(track_id),
            effect_id,
        });
    }
    let action = structure_before.finish(&ctx.app_state, "Delete Track");
    ctx.push_history(action);
    ctx.broadcast_track_graph();
    ctx.broadcast_routing();
    Ok(deleted_track_type)
}

/// Update track order
pub fn update_track_order(
    ctx: &mut DawContext,
    track_id: TrackId,
    new_idx: usize,
) -> anyhow::Result<()> {
    let previous = TracksReordered::capture(&ctx.app_state);
    ctx.app_state.update_track_order(track_id, new_idx)?;
    ctx.push_history(previous);
    Ok(())
}
