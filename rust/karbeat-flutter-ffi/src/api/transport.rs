//! api/transport.rs
//! Transport API - all functions push AudioCommands to the audio thread.
//! BPM is also persisted in ApplicationState for project serialization.

use flutter_rust_bridge::frb;
use karbeat_core::{ api::transport_api, audio::engine::PlaybackMode };

pub enum PlaybackModeDto {
    Song,
    Pattern {
        pattern_id: u32,
        generator_id: u32,
    },
}

impl From<&PlaybackMode> for PlaybackModeDto {
    fn from(value: &PlaybackMode) -> Self {
        match value {
            PlaybackMode::Song => PlaybackModeDto::Song,
            PlaybackMode::Pattern { pattern_id, generator_id } =>
                PlaybackModeDto::Pattern {
                    pattern_id: pattern_id.to_u32(),
                    generator_id: generator_id.to_u32(),
                },
        }
    }
}

impl From<PlaybackModeDto> for PlaybackMode {
    fn from(value: PlaybackModeDto) -> Self {
        match value {
            PlaybackModeDto::Song => PlaybackMode::Song,
            PlaybackModeDto::Pattern { pattern_id, generator_id } =>
                PlaybackMode::Pattern {
                    pattern_id: pattern_id.into(),
                    generator_id: generator_id.into(),
                },
        }
    }
}

/// set the play state of the transport
pub fn set_playing(val: bool) -> Result<(), String> {
    transport_api::set_playing(val).map_err(|e| e.to_string())
}

/// set what position the playhead is at (in samples)
pub fn set_playhead(val: u32) -> Result<(), String> {
    transport_api::set_playhead(val);
    Ok(())
}

/// set whether the transport is looping
pub fn set_looping(val: bool) -> Result<(), String> {
    transport_api::set_looping(val);
    Ok(())
}

/// set the BPM of the transport.
/// writes to both ApplicationState (for serialization) and AudioCommand (for audio thread)
pub fn set_bpm(val: f32) -> Result<(), String> {
    transport_api::set_bpm(val);
    Ok(())
}

/// stop the song playback and reset the playhead to 0
pub fn stop_song_playback() -> Result<(), String> {
    transport_api::stop_song_playback();
    Ok(())
}

/// Toggle the pattern playback
pub fn toggle_pattern_playback(pattern_id: u32, generator_id: u32) {
    transport_api::toggle_pattern_playback(pattern_id.into(), generator_id.into());
}

/// Toggle the playback with specific playback
#[frb]
pub fn toggle_playback_with_mode(playback_mode: PlaybackModeDto) {
    transport_api::toggle_playing_with_playback(playback_mode.into());
}

pub fn switch_pattern_generator(generator_id: u32) {
    transport_api::switch_pattern_generator(generator_id.into());
}
