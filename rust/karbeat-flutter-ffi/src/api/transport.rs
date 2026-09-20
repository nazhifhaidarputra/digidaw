//! api/transport.rs
//! Transport API - all functions push AudioCommands to the audio thread.
//! BPM is also persisted in ApplicationState for project serialization.

use flutter_rust_bridge::frb;
use karbeat_core::{api::transport_api, audio::engine::PlaybackMode};

use crate::api::context::DawContext;

pub enum PlaybackModeDto {
    Song,
    Pattern { pattern_id: u64, generator_id: u64 },
}

impl From<&PlaybackMode> for PlaybackModeDto {
    fn from(value: &PlaybackMode) -> Self {
        match value {
            PlaybackMode::Song => PlaybackModeDto::Song,
            PlaybackMode::Pattern {
                pattern_id,
                generator_id,
            } => PlaybackModeDto::Pattern {
                pattern_id: pattern_id.to_u64(),
                generator_id: generator_id.to_u64(),
            },
        }
    }
}

impl From<PlaybackModeDto> for PlaybackMode {
    fn from(value: PlaybackModeDto) -> Self {
        match value {
            PlaybackModeDto::Song => PlaybackMode::Song,
            PlaybackModeDto::Pattern {
                pattern_id,
                generator_id,
            } => PlaybackMode::Pattern {
                pattern_id: pattern_id.into(),
                generator_id: generator_id.into(),
            },
        }
    }
}

/// set the play state of the transport
pub fn set_playing(ctx: &DawContext, val: bool) -> Result<(), String> {
    transport_api::set_playing(&mut ctx.project_write(), val).map_err(|e| e.to_string())
}

/// set what position the playhead is at (in samples)
pub fn set_playhead(ctx: &DawContext, val: u32) -> Result<(), String> {
    transport_api::set_playhead(&mut ctx.project_write(), val);
    Ok(())
}

/// set whether the transport is looping
pub fn set_looping(ctx: &DawContext, val: bool) -> Result<(), String> {
    transport_api::set_looping(&mut ctx.project_write(), val);
    Ok(())
}

/// set the BPM of the transport.
/// writes to both ApplicationState (for serialization) and AudioCommand (for audio thread)
pub fn set_bpm(ctx: &DawContext, val: f32) -> Result<(), String> {
    transport_api::set_bpm(&mut ctx.project_write(), val);
    Ok(())
}

/// stop the song playback and reset the playhead to 0
pub fn stop_song_playback(ctx: &DawContext) -> Result<(), String> {
    transport_api::stop_song_playback(&mut ctx.project_write());
    Ok(())
}

/// Toggle the pattern playback
pub fn toggle_pattern_playback(ctx: &DawContext, pattern_id: u64, generator_id: u64) {
    transport_api::toggle_pattern_playback(
        &mut ctx.project_write(),
        pattern_id.into(),
        generator_id.into(),
    );
}

/// Toggle the playback with specific playback
#[frb]
pub fn toggle_playback_with_mode(ctx: &DawContext, playback_mode: PlaybackModeDto) {
    transport_api::toggle_playing_with_playback(&mut ctx.project_write(), playback_mode.into());
}

pub fn switch_pattern_generator(ctx: &DawContext, generator_id: u64) {
    transport_api::switch_pattern_generator(&mut ctx.project_write(), generator_id.into());
}
