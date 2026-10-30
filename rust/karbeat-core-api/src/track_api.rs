use karbeat_audio::commands::AudioCommand;
use karbeat_audio::commands::MixerChannelTarget;
use karbeat_audio::context::DawContext;
use karbeat_audio::event::PluginTarget;
use karbeat_core::core::history::actions::{
    StructureRecorder, TrackRecolored, TrackRenamed, TracksReordered,
};
use karbeat_core::core::project::track::RemovedTrackType;
use karbeat_core::core::project::{AudioTrack, TrackInputSettings, TrackType};
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

/// Swaps the generator of a MIDI track for a built-in generator, keeping the track's clips,
/// mixer channel, and routing, and records the swap for undo.
///
/// A hosted (external) generator on the track must be removed first with
/// [`super::external_plugin_api::begin_remove_generator`], because its native instance cannot be
/// retired here. An external replacement goes through
/// [`super::external_plugin_api::begin_replace_instrument`].
pub fn replace_track_generator(
    ctx: &mut DawContext,
    track_id: TrackId,
    registry_id: u32,
) -> anyhow::Result<AudioTrack> {
    anyhow::ensure!(
        ctx.plugin_catalog.external(registry_id).is_none(),
        "External generators are installed through the hosted plugin transaction"
    );
    let previous = ctx
        .app_state
        .tracks
        .get(track_id)
        .and_then(|track| track.generator.as_ref())
        .map(|generator| PluginTarget::Generator(generator.id));
    if let Some(previous) = previous {
        anyhow::ensure!(
            super::external_plugin_api::descriptor(ctx, previous).is_none(),
            "Remove the external generator before replacing it"
        );
        // Undo reinstalls the previous generator from project state, so keep its live settings.
        if let Err(error) = super::project_api::capture_live_state(ctx, &[previous], &[]) {
            log::warn!("Replacing generator without its live plugin state: {error:#}");
        }
    }

    let structure_before = StructureRecorder::begin(&ctx.app_state, &[], &[]);
    let (track, previous_id, gen_id, generator_plugin_factory) = ctx
        .app_state
        .replace_track_generator_with_id(&mut ctx.plugin_registry, track_id, registry_id)?;

    if let Some(generator_id) = previous_id {
        let _ = ctx.send_audio_command(AudioCommand::RemoveGenerator { generator_id });
    }
    let (plugin, telemetry) = ctx.prepare_plugin_install(generator_plugin_factory);
    let _ = ctx.send_audio_command(AudioCommand::InstallGenerator {
        generator_id: gen_id,
        track_id,
        registry_id,
        plugin,
        telemetry: Some(telemetry),
    });

    let action = structure_before.finish(&ctx.app_state, "Change Instrument");
    ctx.push_history(action);
    ctx.broadcast_track_graph();
    Ok(track)
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

/// Sets the device input an audio track records and monitors, and publishes the track graph so
/// the engine monitors the new channels.
///
/// Input routing is a setup choice like the audio device, so it is saved with the project but
/// not recorded in undo history.
pub fn set_track_input(
    ctx: &mut DawContext,
    track_id: TrackId,
    input: TrackInputSettings,
) -> anyhow::Result<AudioTrack> {
    anyhow::ensure!(
        matches!(input.channels, 1 | 2),
        "A track records one or two input channels"
    );
    let track = ctx
        .app_state
        .tracks
        .get_mut(track_id)
        .ok_or_else(|| anyhow::anyhow!("Track not found"))?;
    anyhow::ensure!(
        track.track_type == TrackType::Audio,
        "Only audio tracks take device input"
    );
    track.input = input;
    let track = track.clone();
    ctx.mark_project_modified();
    ctx.broadcast_track_graph();
    Ok(track)
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
            target: karbeat_audio::commands::EffectTarget::Track(track_id),
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
