//! Project and engine builders shared by the engine regression tests and benchmarks.
#![cfg(any(test, feature = "bench-support"))]
#![allow(
    clippy::expect_used,
    clippy::unwrap_used,
    clippy::panic,
    clippy::arithmetic_side_effects,
    clippy::indexing_slicing,
    reason = "fixtures fail immediately when a deterministic project cannot be built"
)]

use std::sync::{Arc, mpsc};

use karbeat_plugins::registry::PluginRegistry;
use karbeat_utils::hash::hash_str;
use rtrb::RingBuffer;

use crate::{
    audio::{
        engine::{AudioEngine, AudioEngineTelemetry, PlaybackMode},
        event::{PluginTarget, TransportFeedback},
        render_state::AudioGraphState,
    },
    commands::{AudioCommand, AudioFeedback, EffectTarget, MixerChannelTarget},
    core::project::{
        ApplicationState, AudioWaveform, ClipSourceType, ClipTimeUnit, GainEnvelope,
        MixerChannelParams, RoutingConnection, RoutingNode, audio_waveform::AudioSampleMode,
    },
    shared::{AudioSourceId, BusId, ClipId, EffectId, GeneratorId, TrackId},
};

/// Sample rate every fixture engine runs at.
pub const SAMPLE_RATE: u32 = 48_000;
/// Tempo every fixture project plays at; one tick is 25 samples.
pub const BPM: f32 = 120.0;

/// A stereo engine at [`SAMPLE_RATE`] and [`BPM`] whose feedback queues nobody reads.
pub fn engine(block: usize) -> AudioEngine {
    let (_, commands) = RingBuffer::<AudioCommand>::new(64);
    let (position, _) = RingBuffer::<TransportFeedback>::new(1_024);
    let (feedback, _) = RingBuffer::<AudioFeedback>::new(1_024);
    let (telemetry, _) = mpsc::sync_channel(64);
    AudioEngine::new(
        commands,
        position,
        feedback,
        SAMPLE_RATE,
        2,
        BPM,
        block,
        AudioEngineTelemetry::new_for_export(),
        telemetry,
    )
}

/// An empty project at the fixture sample rate and tempo.
pub fn project() -> ApplicationState {
    let mut app = ApplicationState::default();
    app.transport.bpm = BPM;
    app.audio_config.sample_rate = SAMPLE_RATE;
    app
}

/// How a fixture waveform is stored and played.
#[derive(Clone)]
pub struct WaveformSpec {
    pub rate: u32,
    pub frames: usize,
    pub channels: u16,
    pub looping: bool,
    pub mode: AudioSampleMode,
    pub original_bpm: Option<f32>,
    pub envelope: GainEnvelope,
}

impl WaveformSpec {
    /// A plain one-shot at the engine rate.
    pub fn stereo(frames: usize) -> Self {
        Self {
            rate: SAMPLE_RATE,
            frames,
            channels: 2,
            looping: false,
            mode: AudioSampleMode::Default,
            original_bpm: None,
            envelope: GainEnvelope::default(),
        }
    }
}

/// Adds a waveform whose sample at `(frame, channel)` is `sample(frame, channel)`.
pub fn add_waveform(
    app: &mut ApplicationState,
    spec: &WaveformSpec,
    sample: impl Fn(usize, usize) -> f32,
) -> AudioSourceId {
    let channels = usize::from(spec.channels);
    let samples: Vec<f32> = (0..spec.frames)
        .flat_map(|frame| (0..channels).map(move |channel| (frame, channel)))
        .map(|(frame, channel)| sample(frame, channel))
        .collect();
    let bytes: &[u8] = bytemuck::cast_slice(&samples);
    let mut map = memmap2::MmapOptions::new()
        .len(bytes.len())
        .map_anon()
        .expect("anonymous map");
    map.copy_from_slice(bytes);
    let buffer = Arc::new(map.make_read_only().expect("read-only map"));
    app.asset_library.source_map.insert_with_key(|id| {
        Arc::new(AudioWaveform {
            id: Some(id),
            buffer: Some(buffer),
            sample_rate: spec.rate,
            channels: spec.channels,
            duration: spec.frames as f64 / f64::from(spec.rate),
            trim_end: spec.frames as u32,
            is_looping: spec.looping,
            sample_mode: spec.mode,
            original_bpm: spec.original_bpm,
            envelope: spec.envelope.clone(),
            ..AudioWaveform::default()
        })
    })
}

/// A two-tone signal with different content per channel, so swapped channels show up.
pub fn tone(rate: u32, left_hz: f32, right_hz: f32) -> impl Fn(usize, usize) -> f32 {
    move |frame, channel| {
        let hz = if channel == 0 { left_hz } else { right_hz };
        let level = if channel == 0 { 0.5 } else { 0.35 };
        (frame as f32 * hz * std::f32::consts::TAU / rate as f32).sin() * level
    }
}

/// Places an audio clip of `source` on `track` at `start_tick`, optionally overriding its
/// length and source offset (both in samples).
pub fn add_audio_clip(
    app: &mut ApplicationState,
    source: AudioSourceId,
    track: TrackId,
    start_tick: u32,
    length_and_offset: Option<(u64, u64)>,
) -> ClipId {
    let clip = app
        .create_new_clip(
            Some(source.to_u64()),
            ClipSourceType::Audio,
            track,
            start_tick,
        )
        .expect("audio clip");
    if let Some((loop_length, offset_start)) = length_and_offset {
        app.clips_pool[clip.id].time = ClipTimeUnit::Audio {
            start_tick: u64::from(start_tick),
            loop_length,
            offset_start,
        };
    }
    clip.id
}

/// A MIDI track played by the registered generator `registry_name`.
pub fn add_synth_track(app: &mut ApplicationState, registry_name: &str) -> (TrackId, GeneratorId) {
    let mut registry = PluginRegistry::new_with_defaults();
    let (track, generator, _) = app
        .add_new_midi_track_with_generator_id(&mut registry, hash_str(registry_name))
        .expect("generator track");
    (track.id, generator)
}

/// Publishes `app` to the engine in song mode.
pub fn publish(engine: &mut AudioEngine, app: &ApplicationState) {
    engine.process_command(AudioCommand::ReplaceFullGraph {
        graph: AudioGraphState::from(app),
    });
    engine.process_command(AudioCommand::SetPlaybackMode(PlaybackMode::Song));
}

/// Installs the registered generator `registry_name` for a track made by [`add_synth_track`].
pub fn install_generator(
    engine: &mut AudioEngine,
    track: TrackId,
    generator: GeneratorId,
    registry_name: &str,
) {
    let registry_id = hash_str(registry_name);
    let (plugin_factory, _) = PluginRegistry::new_with_defaults()
        .create_plugin_by_id(registry_id)
        .expect("registered generator");
    engine.process_command(AudioCommand::AddGenerator {
        generator_id: generator,
        track_id: track,
        registry_id,
        plugin_factory,
    });
}

/// Adds the registered effect `registry_name` and sets the parameters named by path.
pub fn add_effect(
    engine: &mut AudioEngine,
    target: EffectTarget,
    effect: u32,
    registry_name: &str,
    parameters: &[(&str, f32)],
) -> EffectId {
    let registry = PluginRegistry::new_with_defaults();
    let registry_id = hash_str(registry_name);
    let (effect_factory, _) = registry
        .create_plugin_by_id(registry_id)
        .expect("registered effect");
    let effect_id = EffectId::from(effect);
    engine.process_command(AudioCommand::AddEffect {
        target,
        effect_id,
        registry_id,
        effect_factory,
    });
    let specs = registry
        .get_plugin_parameter_specs_by_id(registry_id)
        .expect("effect parameters");
    let plugin = match target {
        EffectTarget::Track(track) => PluginTarget::TrackEffect(track, effect_id),
        EffectTarget::Bus(bus) => PluginTarget::BusEffect(bus, effect_id),
        EffectTarget::Master => PluginTarget::MasterEffect(effect_id),
    };
    for (path, value) in parameters {
        let spec = specs
            .iter()
            .find(|spec| spec.path == *path)
            .unwrap_or_else(|| panic!("{registry_name} has no parameter {path}"));
        engine.process_command(AudioCommand::SetParameter {
            target: plugin,
            param_id: spec.id,
            value: *value,
        });
    }
    effect_id
}

/// Sets one mixer channel value.
pub fn set_mixer(engine: &mut AudioEngine, target: MixerChannelTarget, param: MixerChannelParams) {
    engine.process_command(AudioCommand::SetMixerChannelParameter { target, param });
}

/// Starts song playback at `playhead` samples.
pub fn play(engine: &mut AudioEngine, playhead: u32) {
    engine.process_command(AudioCommand::SetPlayhead(playhead));
    engine.process_command(AudioCommand::SetPlaying(true));
}

/// Renders `frames` stereo frames in blocks of at most `block` frames.
pub fn render(engine: &mut AudioEngine, frames: usize, block: usize) -> Vec<f32> {
    let mut output = vec![0.0_f32; frames * 2];
    for chunk in output.chunks_mut(block * 2) {
        engine.process(chunk);
    }
    output
}

/// Shape of a synthetic project for benchmarks.
#[derive(Clone, Copy, Debug)]
pub struct BenchProject {
    /// Audio tracks, each playing clips back to back.
    pub tracks: usize,
    /// Clips on every track.
    pub clips_per_track: usize,
    /// Length of each clip in samples.
    pub clip_frames: u32,
    /// Buses the tracks are spread over; zero routes every track straight to the master.
    pub buses: usize,
    /// Effects on each track: the first is a Parametric EQ, the second a Delay.
    pub effects_per_track: usize,
    /// Whether the clips play a 44.1 kHz source, which takes the resampling path.
    pub resampled: bool,
}

/// Builds an engine for `shape` and returns it with its tracks. Call [`play`] to start it.
pub fn bench_engine(shape: BenchProject, block: usize) -> (AudioEngine, Vec<TrackId>) {
    let mut app = project();
    let rate = if shape.resampled { 44_100 } else { SAMPLE_RATE };
    let sources: Vec<AudioSourceId> = (0..4)
        .map(|index| {
            let base = 110.0 * (index + 1) as f32;
            add_waveform(
                &mut app,
                &WaveformSpec {
                    rate,
                    ..WaveformSpec::stereo(rate as usize)
                },
                tone(rate, base, base * 1.5),
            )
        })
        .collect();
    // One tick is 25 samples at the fixture tempo and rate.
    let clip_ticks = (shape.clip_frames / 25).max(1);
    let mut tracks = Vec::with_capacity(shape.tracks);
    for track_index in 0..shape.tracks {
        let track = app.add_new_audio_track().id;
        for clip_index in 0..shape.clips_per_track {
            add_audio_clip(
                &mut app,
                sources[(track_index + clip_index) % sources.len()],
                track,
                clip_index as u32 * clip_ticks,
                Some((u64::from(clip_ticks * 25), 0)),
            );
        }
        tracks.push(track);
    }

    let mut engine = engine(block);
    publish(&mut engine, &app);
    let buses: Vec<BusId> = (0..shape.buses)
        .map(|index| BusId::from(index as u32 + 1))
        .collect();
    for (index, bus) in buses.iter().enumerate() {
        engine.process_command(AudioCommand::AddBus {
            bus_id: *bus,
            name: format!("Bus {index}"),
        });
        add_effect(
            &mut engine,
            EffectTarget::Bus(*bus),
            1,
            "effect_param_eq",
            &[("band2/gain", 3.0)],
        );
    }
    if !buses.is_empty() {
        let routing: Vec<RoutingConnection> = tracks
            .iter()
            .enumerate()
            .map(|(index, track)| {
                RoutingConnection::new(
                    RoutingNode::Track(*track),
                    RoutingNode::Bus(buses[index % buses.len()]),
                )
            })
            .chain(
                buses
                    .iter()
                    .map(|bus| RoutingConnection::new(RoutingNode::Bus(*bus), RoutingNode::Master)),
            )
            .collect();
        engine.process_command(AudioCommand::UpdateRouting {
            routing: routing.into_boxed_slice(),
        });
    }
    for track in &tracks {
        if shape.effects_per_track >= 1 {
            add_effect(
                &mut engine,
                EffectTarget::Track(*track),
                1,
                "effect_param_eq",
                &[("band3/gain", -4.0)],
            );
        }
        if shape.effects_per_track >= 2 {
            add_effect(
                &mut engine,
                EffectTarget::Track(*track),
                2,
                "effect_delay",
                &[("delay/delay_ms", 120.0)],
            );
        }
    }
    (engine, tracks)
}
