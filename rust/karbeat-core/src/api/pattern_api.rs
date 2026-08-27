use crate::{
    audio::engine::PlaybackMode,
    commands::AudioCommand,
    context::DawContext,
    core::project::{GeneratorId, Pattern, PatternId},
};

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
    F: Fn(u32, &Pattern) -> Item, // The mapper takes the ID and the Pattern, and returns an Item
    C: FromIterator<Item>,        // The collection must be buildable from an iterator of Items
{
    let patterns = ctx
        .app_state
        .pattern_pool
        .iter()
        .map(|(id, pattern)| {
            // Let the closure handle exactly what the Item shape looks like
            mapper(id.into(), pattern)
        })
        .collect::<C>(); // Collect dynamically resolves to type C

    Ok(patterns)
}

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

pub fn stop_pattern_preview(ctx: &mut DawContext) -> anyhow::Result<()> {
    // Send commands to stop playing and switch back to Song mode
    ctx.try_send_audio_command_chain(vec![
        AudioCommand::SetPlaying(false),
        AudioCommand::SetPlaybackMode(PlaybackMode::Song),
    ])
}
