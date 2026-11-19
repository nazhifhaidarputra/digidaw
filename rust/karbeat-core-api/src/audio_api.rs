use std::{fs::create_dir_all, io::BufWriter, path::Path};

use anyhow::Context;
use hound::{SampleFormat, WavReader, WavSpec, WavWriter};
use karbeat_audio::{
    commands::AudioCommand, context::DawContext, engine::MetronomeClick, event::TransportFeedback,
};
use karbeat_core::core::{
    file_manager::audio_loader::{AudioLoader, load_audio_file},
    project::{AudioHardwareConfig, AudioSourceId, AudioWaveform, GeneratorId, TrackId},
};
use karbeat_dsp::stretcher::{OfflineStretch, stretch_offline};
use karbeat_plugin_api::types::MidiEvent;
use tempfile::NamedTempFile;

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
    let waveform = load_audio_file(file_path, None)?;
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

/// Longest custom metronome click that is kept, in seconds.
const METRONOME_CLICK_MAX_SECONDS: u64 = 10;
/// File in the metronome folder holding the click played on the first beat of each bar.
const METRONOME_DOWNBEAT_FILE: &str = "downbeat.wav";
/// File in the metronome folder holding the click played on every other beat.
const METRONOME_OFFBEAT_FILE: &str = "offbeat.wav";
/// Frequency multiplier of the downbeat click: one octave above the chosen sound.
const METRONOME_DOWNBEAT_PITCH: f64 = 2.0;

/// Renders the audio file at `source` into the two metronome clicks and writes them to `folder`
/// as `downbeat.wav` and `offbeat.wav`, replacing earlier ones.
///
/// The offbeat click is the sound as recorded and the downbeat click is the same sound
/// pitch-shifted an octave up, with the same length. Runs an offline pitch shift, so call it
/// off the audio thread. Nothing in `folder` changes when the sound cannot be decoded or shifted.
pub fn render_metronome_sound(source: &str, folder: &Path) -> anyhow::Result<()> {
    let (offbeat, sample_rate) = decode_metronome_sound(source)?;
    let downbeat = shift_octave_up(&offbeat, sample_rate)?;
    create_dir_all(folder)?;
    write_metronome_click(folder, METRONOME_DOWNBEAT_FILE, &downbeat, sample_rate)?;
    write_metronome_click(folder, METRONOME_OFFBEAT_FILE, &offbeat, sample_rate)
}

/// Reads the clicks [`render_metronome_sound`] wrote to `folder`.
pub fn read_metronome_sound(folder: &Path) -> anyhow::Result<MetronomeClick> {
    let (downbeat, downbeat_rate) = read_metronome_click(&folder.join(METRONOME_DOWNBEAT_FILE))?;
    let (offbeat, offbeat_rate) = read_metronome_click(&folder.join(METRONOME_OFFBEAT_FILE))?;
    if downbeat_rate != offbeat_rate {
        anyhow::bail!("The metronome clicks have different sample rates");
    }
    Ok(MetronomeClick {
        downbeat,
        offbeat,
        sample_rate: offbeat_rate,
    })
}

/// Replaces the metronome's sound with `click`, or restores the built-in click with `None`.
pub fn set_metronome_click(
    ctx: &mut DawContext,
    click: Option<MetronomeClick>,
) -> anyhow::Result<()> {
    ctx.send_audio_command(AudioCommand::SetMetronomeClick(click))
}

/// Decodes an audio file into mono samples of bounded length and their sample rate.
fn decode_metronome_sound(file_path: &str) -> anyhow::Result<(Vec<f32>, u32)> {
    let waveform = load_audio_file(file_path, None)?;
    let channels = usize::from(waveform.channels);
    let interleaved = waveform
        .get_playable_buffer()
        .filter(|_| channels > 0)
        .ok_or_else(|| anyhow::anyhow!("The metronome sound has no audio"))?;
    let max_frames = usize::try_from(u64::from(waveform.sample_rate) * METRONOME_CLICK_MAX_SECONDS)
        .unwrap_or(usize::MAX);
    let channel_count = f32::from(waveform.channels);
    let samples: Vec<f32> = interleaved
        .chunks_exact(channels)
        .take(max_frames)
        .map(|frame| frame.iter().sum::<f32>() / channel_count)
        .collect();
    if samples.is_empty() {
        anyhow::bail!("The metronome sound has no audio");
    }
    Ok((samples, waveform.sample_rate))
}

/// Pitch-shifts mono `samples` an octave up, keeping their length.
fn shift_octave_up(samples: &[f32], sample_rate: u32) -> anyhow::Result<Vec<f32>> {
    let request = OfflineStretch {
        sample_rate,
        channels: 1,
        input: samples,
        time_ratio: 1.0,
        pitch_scale: METRONOME_DOWNBEAT_PITCH,
        preserve_formants: false,
        key_frames: &[],
    };
    let mut shifted = Vec::with_capacity(samples.len());
    stretch_offline(&request, &|| false, &mut |_| {}, &mut |block| {
        shifted.extend_from_slice(block)
    })?;
    // The stretcher can round the length by a frame; the click must match the original.
    shifted.resize(samples.len(), 0.0);
    Ok(shifted)
}

/// Writes mono `samples` as a 32-bit float WAV named `name` in `folder`.
///
/// The file is written beside its destination first, so a failed write keeps the old click.
fn write_metronome_click(
    folder: &Path,
    name: &str,
    samples: &[f32],
    sample_rate: u32,
) -> anyhow::Result<()> {
    let spec = WavSpec {
        channels: 1,
        sample_rate,
        bits_per_sample: 32,
        sample_format: SampleFormat::Float,
    };
    let mut file = NamedTempFile::new_in(folder)?;
    let mut writer = WavWriter::new(BufWriter::new(file.as_file_mut()), spec)?;
    for &sample in samples {
        writer.write_sample(sample)?;
    }
    writer.finalize()?;
    file.persist(folder.join(name))?;
    Ok(())
}

/// Reads a mono click written by [`write_metronome_click`] and its sample rate.
fn read_metronome_click(path: &Path) -> anyhow::Result<(Vec<f32>, u32)> {
    let reader = WavReader::open(path)
        .with_context(|| format!("Could not open the metronome click {}", path.display()))?;
    let spec = reader.spec();
    if spec.channels != 1 || spec.sample_format != SampleFormat::Float {
        anyhow::bail!(
            "The metronome click {} is not a mono float WAV",
            path.display()
        );
    }
    let samples = reader
        .into_samples::<f32>()
        .collect::<Result<Vec<_>, _>>()?;
    if samples.is_empty() {
        anyhow::bail!("The metronome click {} has no audio", path.display());
    }
    Ok((samples, spec.sample_rate))
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
