use karbeat_core::audio::engine::PlaybackMode;
use karbeat_core::commands::AudioCommand;
use karbeat_core::context::DawContext;
use karbeat_core::core::history::actions::TempoChanged;
use karbeat_core::shared::{GeneratorId, PatternId};

/// Set is playing for song mode
pub fn set_playing(ctx: &mut DawContext, val: bool) -> anyhow::Result<()> {
    ctx.try_send_audio_command_chain(vec![
        AudioCommand::SetPlaybackMode(PlaybackMode::Song),
        AudioCommand::SetPlaying(val),
    ])?;

    Ok(())
}

/// Updates the project playhead and queues the same absolute sample position to the audio thread.
pub fn set_playhead(ctx: &mut DawContext, val: u32) {
    let _ = ctx.send_audio_command(AudioCommand::SetPlayhead(val));
}

/// Updates project loop enablement and queues the new state to the audio thread.
pub fn set_looping(ctx: &mut DawContext, val: bool) {
    let _ = ctx.send_audio_command(AudioCommand::SetLooping(val));
}

/// Updates tempo, rebuilds timing-dependent graph state, and queues the tempo change.
///
/// Rejects NaN and infinity, which a project file cannot store.
pub fn set_bpm(ctx: &mut DawContext, val: f32) -> anyhow::Result<()> {
    anyhow::ensure!(val.is_finite(), "Tempo must be a finite number");
    let previous = std::mem::replace(&mut ctx.app_state.transport.bpm, val);
    ctx.push_history(TempoChanged::new(previous));
    let _ = ctx.send_audio_command(AudioCommand::SetBPM(val));
    Ok(())
}

/// Stops transport playback and resets the audio-thread playhead to zero.
pub fn stop_song_playback(ctx: &mut DawContext) {
    let _ = ctx.send_audio_command(AudioCommand::StopAndReset);
}

/// Toggles isolated playback of a pattern through a specific generator.
pub fn toggle_pattern_playback(
    ctx: &mut DawContext,
    pattern_id: PatternId,
    generator_id: GeneratorId,
) {
    let _ = ctx.send_audio_command(AudioCommand::TogglePatternPlayback {
        pattern_id,
        generator_id,
    });
}

/// Toggles playback while selecting the mode to use when transport starts.
pub fn toggle_playing_with_playback(ctx: &mut DawContext, playback_mode: PlaybackMode) {
    let _ = ctx.send_audio_command(AudioCommand::TogglePlayingWithPlaybackMode(playback_mode));
}

/// Stops pattern playback and rewinds the pattern playhead without touching song position.
pub fn stop_pattern_playback(ctx: &mut DawContext) {
    let _ = ctx.send_audio_command(AudioCommand::StopPatternPlayback);
}

/// Moves the pattern playhead to `samples`, whether or not the pattern is playing.
pub fn set_pattern_playhead(ctx: &mut DawContext, samples: u32) {
    let _ = ctx.send_audio_command(AudioCommand::SetPatternPlayhead(samples));
}

/// Loops pattern playback between `start_tick` and `end_tick`, or clears the loop region so
/// the whole pattern loops.
pub fn set_pattern_loop(ctx: &mut DawContext, region: Option<(u64, u64)>) -> anyhow::Result<()> {
    if let Some((start, end)) = region {
        anyhow::ensure!(end > start, "Loop region must end after it starts");
    }
    let _ = ctx.send_audio_command(AudioCommand::SetPatternLoop(region));
    Ok(())
}

/// Hot-swaps the generator used by active pattern preview playback.
pub fn switch_pattern_generator(ctx: &mut DawContext, generator_id: GeneratorId) {
    let _ = ctx.send_audio_command(AudioCommand::SwitchPatternGenerator(generator_id));
}
