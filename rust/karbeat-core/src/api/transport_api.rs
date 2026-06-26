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

pub fn set_playhead(ctx: &mut DawContext, val: u32) {
    let _ = ctx.send_audio_command(AudioCommand::SetPlayhead(val));
}

pub fn set_looping(ctx: &mut DawContext, val: bool) {
    let _ = ctx.send_audio_command(AudioCommand::SetLooping(val));
}

pub fn set_bpm(ctx: &mut DawContext, val: f32) {
    ctx.app_state.transport.bpm = val;
    let _ = ctx.send_audio_command(AudioCommand::SetBPM(val));
}

pub fn stop_song_playback(ctx: &mut DawContext, ) {
    let _ = ctx.send_audio_command(AudioCommand::StopAndReset);
}

pub fn toggle_pattern_playback(ctx: &mut DawContext, pattern_id: PatternId, generator_id: GeneratorId) {
    let _ = ctx.send_audio_command(AudioCommand::TogglePatternPlayback {
        pattern_id,
        generator_id,
    });
}

pub fn toggle_playing_with_playback(ctx: &mut DawContext, playback_mode: PlaybackMode) {
    let _ = ctx.send_audio_command(AudioCommand::TogglePlayingWithPlaybackMode(playback_mode));
}

pub fn switch_pattern_generator(ctx: &mut DawContext, generator_id: GeneratorId) {
    let _ = ctx.send_audio_command(AudioCommand::SwitchPatternGenerator(generator_id));
}
