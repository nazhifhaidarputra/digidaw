use karbeat_audio::{commands::AudioCommand, context::DawContext, engine::PlaybackMode};
use karbeat_core::core::{
    history::actions::{ClipEditRecorder, PatternRemoved, PatternRenamed},
    project::{DawSource, GeneratorId, Pattern, PatternId},
};
use karbeat_core::shared::id::{ClipId, TrackId};

/// Returns a cloned MIDI pattern or an error when the identifier is absent.
pub fn get_pattern(ctx: &DawContext, pattern_id: &PatternId) -> anyhow::Result<Pattern> {
    let pattern_ref = ctx
        .app_state
        .pattern_pool
        .get(*pattern_id)
        .ok_or_else(|| anyhow::anyhow!("Pattern {:?} not found", pattern_id))?;

    Ok(pattern_ref.clone())
}

/// Fetches patterns, applies a mapper, and collects into ANY collection type `C`.
pub fn get_patterns<C, Item, F>(ctx: &DawContext, mapper: F) -> anyhow::Result<C>
where
    F: Fn(u64, &Pattern) -> Item, // The mapper takes the ID and the Pattern, and returns an Item
    C: FromIterator<Item>,        // The collection must be buildable from an iterator of Items
{
    let patterns = ctx
        .app_state
        .pattern_pool
        .iter()
        .map(|(id, pattern)| {
            // Let the closure handle exactly what the Item shape looks like
            mapper(id.to_u64(), pattern)
        })
        .collect::<C>(); // Collect dynamically resolves to type C

    Ok(patterns)
}

/// Renames a MIDI pattern, records history, and republishes the track graph.
pub fn rename_pattern(
    ctx: &mut DawContext,
    pattern_id: PatternId,
    new_name: &str,
) -> anyhow::Result<()> {
    anyhow::ensure!(!new_name.trim().is_empty(), "Pattern name cannot be empty");
    anyhow::ensure!(
        new_name.len() <= 50,
        "Pattern name cannot exceed 50 characters"
    );

    let pattern = ctx
        .app_state
        .pattern_pool
        .get_mut(pattern_id)
        .ok_or_else(|| anyhow::anyhow!("Pattern {:?} not found", pattern_id))?;
    let old_name = std::mem::replace(&mut pattern.name, new_name.to_owned());

    let mut previous_clip_names = Vec::new();
    for (clip_id, clip) in ctx.app_state.clips_pool.iter_mut() {
        if clip.name == old_name
            && matches!(clip.source, Some(DawSource::Midi(id)) if id == pattern_id)
        {
            previous_clip_names.push((clip_id, clip.name.clone()));
            clip.rename_clip(new_name);
        }
    }

    ctx.push_history(PatternRenamed::new(
        pattern_id,
        old_name,
        previous_clip_names,
    ));
    Ok(())
}

/// Deletes a MIDI pattern and every clip that plays it as one undoable step.
///
/// Returns how many clips were deleted with it. The engine receives a track graph update,
/// which also stops an isolated preview of the deleted pattern.
pub fn delete_pattern(ctx: &mut DawContext, pattern_id: PatternId) -> anyhow::Result<usize> {
    let clips = ctx.app_state.pattern_clips(pattern_id);
    let tracks: Vec<TrackId> = clips.iter().map(|(track_id, _)| *track_id).collect();
    let clip_ids: Vec<ClipId> = clips.iter().map(|(_, clip_id)| *clip_id).collect();

    let recorder = ClipEditRecorder::begin(&ctx.app_state, "Delete Pattern", &tracks, &clip_ids);
    let pattern = ctx.app_state.remove_pattern(pattern_id)?;
    let clip_changes = recorder.finish(&mut ctx.app_state);
    ctx.push_history(PatternRemoved::new(clip_changes, pattern_id, pattern));

    ctx.broadcast_track_graph();
    tracing::info!(
        "Removed pattern {} with {} clip(s)",
        pattern_id.to_u64(),
        clip_ids.len()
    );
    Ok(clip_ids.len())
}

/// Toggles isolated preview playback of a pattern through a selected generator.
pub fn play_pattern_preview(
    ctx: &mut DawContext,
    pattern_id: PatternId,
    generator_id: GeneratorId,
) -> anyhow::Result<()> {
    if !ctx.app_state.pattern_pool.contains_key(pattern_id) {
        return Err(anyhow::anyhow!("Pattern {:?} not found", pattern_id));
    }

    // Try send command
    // Send commands to switch to Pattern mode and start playing
    ctx.try_send_audio_command_chain(vec![
        AudioCommand::SetPlaying(false),
        AudioCommand::SetPlaybackMode(PlaybackMode::Pattern {
            pattern_id,
            generator_id,
        }),
        AudioCommand::SetPlaying(true),
    ])?;

    Ok(())
}

/// Stop pattern preview without changing the mode
pub fn stop_pattern_preview_local(
    ctx: &mut DawContext,
    pattern_id: PatternId,
    generator_id: GeneratorId,
) -> anyhow::Result<()> {
    ctx.try_send_audio_command_chain(vec![
        AudioCommand::SetPlaybackMode(PlaybackMode::Pattern {
            pattern_id,
            generator_id,
        }),
        AudioCommand::SetPlaying(false),
    ])
}

/// Stops isolated pattern playback and returns transport to its normal mode.
pub fn stop_pattern_preview(ctx: &mut DawContext) -> anyhow::Result<()> {
    // Send commands to stop playing and switch back to Song mode
    ctx.try_send_audio_command_chain(vec![
        AudioCommand::SetPlaying(false),
        AudioCommand::SetPlaybackMode(PlaybackMode::Song),
    ])
}
