//! Audio clips added through the API reach the engine and sound.
#![allow(
    clippy::unwrap_used,
    clippy::as_conversions,
    reason = "integration test fixtures fail immediately"
)]

use karbeat_core::{
    audio::engine::{AudioEngine, AudioEngineTelemetry, PlaybackMode},
    commands::AudioCommand,
    context::DawContext,
    core::project::{audio_waveform::AudioSampleMode, clip::ClipSourceType},
    message::TelemetryRegistry,
    shared::id::AudioSourceId,
};
use karbeat_core_api::{
    audio_analysis_api, audio_waveform_api, clip_api, track_api, transport_api,
};

const RATE: u32 = 48_000;

/// A context wired to an engine that the test drives block by block.
fn session() -> (DawContext, AudioEngine) {
    let mut ctx = DawContext::new();
    ctx.audio_runtime_settings.write().requested_dsp.sample_rate = RATE;
    let (sender, commands) = rtrb::RingBuffer::new(256);
    let (feedback, responses) = rtrb::RingBuffer::new(256);
    let (position, _positions) = rtrb::RingBuffer::new(256);
    let (registration, _registrations) = std::sync::mpsc::sync_channel(256);
    let (telemetry, output) = AudioEngineTelemetry::new();
    ctx.telemetry_registry = Some(TelemetryRegistry::new(output));
    *ctx.command_sender.lock() = Some(sender);
    *ctx.feedback_consumer.lock() = Some(responses);
    let engine = AudioEngine::new(
        commands,
        position,
        feedback,
        RATE,
        2,
        120.0,
        512,
        telemetry,
        registration,
    );
    (ctx, engine)
}

/// Imports a two-second stereo tone through the real audio importer.
fn import_tone(ctx: &mut DawContext, name: &str) -> AudioSourceId {
    let path = std::env::temp_dir().join(name);
    let spec = hound::WavSpec {
        channels: 2,
        sample_rate: RATE,
        bits_per_sample: 16,
        sample_format: hound::SampleFormat::Int,
    };
    let mut writer = hound::WavWriter::create(&path, spec).unwrap();
    for frame in 0..RATE * 2 {
        let value =
            ((frame as f32 * 330.0 * std::f32::consts::TAU / RATE as f32).sin() * 16_000.0) as i16;
        writer.write_sample(value).unwrap();
        writer.write_sample(value).unwrap();
    }
    writer.finalize().unwrap();
    audio_waveform_api::add_audio_source(ctx, path.to_str().unwrap()).unwrap()
}

/// Places `source` on a new audio track and returns the RMS of the first played blocks.
fn play_on_new_track(ctx: &mut DawContext, engine: &mut AudioEngine, source: AudioSourceId) -> f32 {
    let track = track_api::add_new_audio_track(ctx);
    clip_api::add_clip(
        ctx,
        Some(source.to_u64()),
        ClipSourceType::Audio,
        track.id,
        0,
    )
    .unwrap();
    // The first block applies the queued commands.
    engine.process(&mut [0.0_f32; 1_024][..]);
    engine.process_command(AudioCommand::SetPlaybackMode(PlaybackMode::Song));
    engine.process_command(AudioCommand::SetPlayhead(0));
    engine.process_command(AudioCommand::SetPlaying(true));
    let mut output = vec![0.0_f32; 16_384];
    for block in output.chunks_mut(1_024) {
        engine.process(block);
    }
    (output.iter().map(|sample| sample * sample).sum::<f32>() / output.len() as f32).sqrt()
}

#[test]
fn clip_on_a_new_track_is_audible() {
    let (mut ctx, mut engine) = session();
    let source = import_tone(&mut ctx, "karbeat_new_track_tone.wav");
    let rms = play_on_new_track(&mut ctx, &mut engine, source);
    assert!(rms > 0.1, "rms {rms}");
}

#[test]
fn stretched_clip_is_audible_after_a_tempo_change() {
    let (mut ctx, mut engine) = session();
    let source = import_tone(&mut ctx, "karbeat_stretched_tone.wav");
    transport_api::set_bpm(&mut ctx, 100.0);
    // Entering Stretch at 100 BPM anchors the source tempo there.
    audio_analysis_api::set_sample_mode(&mut ctx, source, AudioSampleMode::Stretch).unwrap();
    // A new tempo before any re-render: the engine stretches by 110/100 in realtime.
    transport_api::set_bpm(&mut ctx, 110.0);

    let rms = play_on_new_track(&mut ctx, &mut engine, source);
    assert!(rms > 0.1, "rms {rms}");
}
