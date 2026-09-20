use crate::audio::engine::PlaybackMode;
use crate::commands::AudioCommand;
use crate::context::DawContext;
use crate::shared::{GeneratorId, PatternId};

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
pub fn set_bpm(ctx: &mut DawContext, val: f32) {
    ctx.app_state.transport.bpm = val;
    let _ = ctx.send_audio_command(AudioCommand::SetBPM(val));
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

/// Hot-swaps the generator used by active pattern preview playback.
pub fn switch_pattern_generator(ctx: &mut DawContext, generator_id: GeneratorId) {
    let _ = ctx.send_audio_command(AudioCommand::SwitchPatternGenerator(generator_id));
}
