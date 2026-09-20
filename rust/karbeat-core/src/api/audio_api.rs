use crate::{
    audio::event::TransportFeedback,
    commands::AudioCommand,
    context::DawContext,
    core::{
        file_manager::audio_loader::{AudioLoader, load_audio_file},
        project::{AudioHardwareConfig, AudioSourceId, AudioWaveform, GeneratorId, TrackId},
    },
};
use karbeat_plugin_api::types::MidiEvent;

const SAMPLE_BROWSER_PREVIEW_SECONDS: u64 = 15;

/// Looks up an imported audio source and maps the borrowed waveform without cloning it.
pub fn get_audio_source<T, F>(ctx: &DawContext, id: AudioSourceId, mapper: F) -> Option<T>
where
    F: FnOnce(&AudioWaveform) -> T,
{
    let app = &ctx.app_state;
    app.get_audio_source(&id).map(|w| mapper(w.as_ref()))
}

/// Clones an imported source into a one-shot audio-thread preview.
///
/// Returns an error when `id` is absent. Command-send failures are intentionally ignored to
/// preserve the existing fire-and-forget preview behavior.
pub fn play_source_preview(ctx: &mut DawContext, id: AudioSourceId) -> anyhow::Result<()> {
    let app = &ctx.app_state;
    if let Some(waveform_arc) = app.get_audio_source(&id) {
        let waveform_to_play = (*waveform_arc).clone();
        let _ = ctx.send_audio_command(AudioCommand::PlayOneShot(waveform_to_play));
        Ok(())
    } else {
        Err(anyhow::anyhow!("Audio source not found"))
    }
}

/// Loads a file at the requested DSP sample rate and previews at most 15 seconds of frames.
pub fn play_file_preview(ctx: &mut DawContext, file_path: &str) -> anyhow::Result<()> {
    let sample_rate = ctx.audio_runtime_settings.read().requested_dsp.sample_rate;
    let waveform = load_audio_file(file_path, None, sample_rate)?;
    let max_frames = u64::from(sample_rate) * SAMPLE_BROWSER_PREVIEW_SECONDS;
    ctx.send_audio_command(AudioCommand::PlayPreview {
        waveform,
        max_frames,
    })
}

/// Requests that the audio thread stop every active preview voice.
pub fn stop_all_previews(ctx: &mut DawContext) {
    let _ = ctx.send_audio_command(AudioCommand::StopAllPreviews);
}

/// Set the metronome to be active or not. The active state is managed by frontend. Backend does not hold
/// The truth state. Since the state lives on audio thread
pub fn set_metronome_active(ctx: &mut DawContext, active: bool) {
    let _ = ctx.send_audio_command(AudioCommand::SetMetronomeActive(active));
}

/// Maps the project's serialized audio hardware configuration without cloning it first.
pub fn get_audio_config<T, F>(ctx: &DawContext, mapper: F) -> T
where
    F: FnOnce(&AudioHardwareConfig) -> T,
{
    let app = &ctx.app_state;
    mapper(&app.audio_config)
}

/// Drains the position feedback ring buffer and maps it to UI types
pub fn drain_position_feedback<T, F>(ctx: &mut DawContext, mut mapper: F) -> Vec<T>
where
    F: FnMut(TransportFeedback) -> T,
{
    let mut results = Vec::new();
    if let Some(consumer) = ctx.position_consumer.lock().as_mut() {
        while let Ok(pos_data) = consumer.pop() {
            results.push(mapper(pos_data));
        }
    }
    results
}

/// Resolves a track's generator and sends it a preview note-on or note-off command.
///
/// Returns an error if the track is missing, has no generator, or the command cannot be queued.
pub fn play_preview_note(
    ctx: &mut DawContext,
    track_id: TrackId,
    note_key: u8,
    velocity: u8,
    is_on: bool,
) -> anyhow::Result<()> {
    let generator_id = {
        let app = &ctx.app_state;
        let track = app
            .tracks
            .get(track_id)
            .ok_or_else(|| anyhow::anyhow!("Can't find requested track"))?;
        track
            .generator
            .as_ref()
            .ok_or_else(|| anyhow::anyhow!("Track has no generator"))?
            .id
    };

    let _ = ctx.send_audio_command(AudioCommand::PlayPreviewNote {
        note_key,
        generator_id,
        velocity,
        is_note_on: is_on,
    })?;

    Ok(())
}

/// Sends a preview note directly to a generator without resolving it through a track.
///
/// `is_on` selects note-on versus note-off. The request is asynchronous; success only guarantees
/// that the command entered the audio command queue, while a full or unavailable queue is returned
/// as an error.
pub fn play_preview_note_generator(
    ctx: &mut DawContext,
    generator_id: GeneratorId,
    note_key: u8,
    velocity: u8,
    is_on: bool,
) -> anyhow::Result<()> {
    ctx.send_audio_command(AudioCommand::PlayPreviewNote {
        note_key,
        generator_id,
        velocity,
        is_note_on: is_on,
    })?;
    Ok(())
}

/// Queues a sample-accurate MIDI event for a generator on the audio thread.
pub fn send_midi_event(
    ctx: &mut DawContext,
    generator_id: GeneratorId,
    event: MidiEvent,
) -> anyhow::Result<()> {
    ctx.send_audio_command(AudioCommand::SendMidiEvent {
        generator_id,
        event,
    })
}
