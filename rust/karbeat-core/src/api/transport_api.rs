use crate::audio::engine::PlaybackMode;
use crate::commands::AudioCommand;
use crate::context::utils::{
    broadcast_state_change, send_audio_command, try_send_audio_command_chain,
};
use crate::lock::get_app_write;

/// Set is playing for song mode
pub fn set_playing(val: bool) -> anyhow::Result<()>{
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
        // Audio clips (ClipTimeUnit::Samples) are BPM-independent — no rescaling needed.
        // MIDI clips (ClipTimeUnit::Ticks) are converted at playback time, so max_sample_index
        // must be recalculated when BPM changes.
        app.update_max_sample_index();
    }
    send_audio_command(AudioCommand::SetBPM(val));
    broadcast_state_change();
}

pub fn stop_song_playback() {
    send_audio_command(AudioCommand::StopAndReset);
}
