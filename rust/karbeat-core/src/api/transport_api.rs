use crate::audio::engine::PlaybackMode;
use crate::commands::AudioCommand;
use crate::context::utils::{
    broadcast_track_graph, send_audio_command, try_send_audio_command_chain,
};
use crate::lock::get_app_write;
use crate::shared::{GeneratorId, PatternId};

/// Set is playing for song mode
pub fn set_playing(val: bool) -> anyhow::Result<()> {
    try_send_audio_command_chain(vec![
        AudioCommand::SetPlaybackMode(PlaybackMode::Song),
        AudioCommand::SetPlaying(val),
    ])?;

    Ok(())
}

pub fn set_playhead(val: u32) {
    send_audio_command(AudioCommand::SetPlayhead(val));
}

pub fn set_looping(val: bool) {
    send_audio_command(AudioCommand::SetLooping(val));
}

pub fn set_bpm(val: f32) {
    {
        let mut app = get_app_write();
        app.transport.bpm = val;
    }
    send_audio_command(AudioCommand::SetBPM(val));
}

pub fn stop_song_playback() {
    send_audio_command(AudioCommand::StopAndReset);
}

pub fn toggle_pattern_playback(pattern_id: PatternId, generator_id: GeneratorId) {
    send_audio_command(AudioCommand::TogglePatternPlayback {
        pattern_id,
        generator_id,
    });
}

pub fn toggle_playing_with_playback(playback_mode: PlaybackMode) {
    send_audio_command(AudioCommand::TogglePlayingWithPlaybackMode(playback_mode));
}

pub fn switch_pattern_generator(generator_id: GeneratorId) {
    send_audio_command(AudioCommand::SwitchPatternGenerator(generator_id));
}
