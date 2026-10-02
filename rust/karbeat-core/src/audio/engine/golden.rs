//! Reference-render regression tests for the block pipeline.
//!
//! Each scenario renders a small project and compares every sample with a stored render in
//! `tests/fixtures/engine_golden`. Regenerate the stored renders, after an intended change in
//! sound, with `UPDATE_ENGINE_GOLDEN=1 cargo test -p karbeat-core --lib engine::golden`.
#![cfg(test)]
#![allow(
    clippy::expect_used,
    clippy::unwrap_used,
    reason = "reference renders fail immediately when a fixture cannot be built or read"
)]

use std::{any::Any, path::PathBuf, sync::Arc};

use karbeat_plugins::registry::PluginRegistry;
use rtrb::RingBuffer;

use super::test_support::{
    SAMPLE_RATE, WaveformSpec, add_audio_clip, add_effect, add_synth_track, add_waveform, engine,
    install_generator, play, project, publish, set_mixer, tone,
};
use crate::{
    audio::{
        engine::{AudioEngine, tests::IdleProbe},
        event::{PluginTarget, TransportFeedback},
        hosted_plugin::HostedPluginInstall,
    },
    commands::{AudioCommand, AudioFeedback, EffectTarget, MixerChannelTarget},
    core::project::{
        ApplicationState, ClipSourceType, EnvelopePoint, Fade, GainEnvelope, MixerChannelParams,
        RoutingConnection, RoutingNode, RoutingTap, SidechainRoute,
        audio_waveform::AudioSampleMode, track::midi::Pattern,
    },
    shared::{BusId, EffectId, PatternId, TrackId},
};

/// Largest per-sample difference from a stored render that still passes (-100 dBFS).
const TOLERANCE: f32 = 1.0e-5;
/// Block sizes every scenario is rendered at: small, odd, and the default device block.
const BLOCKS: [usize; 3] = [64, 441, 512];
const FRAMES: usize = 4_096;

type Event = (usize, Box<dyn FnMut(&mut AudioEngine)>);

struct Scenario {
    engine: AudioEngine,
    /// Commands applied when the render reaches their frame; blocks are split there, so they
    /// land on the same sample at every block size.
    events: Vec<Event>,
    /// Queue ends and retirement handles that must outlive the engine.
    _keep: Vec<Box<dyn Any>>,
}

impl Scenario {
    fn new(engine: AudioEngine) -> Self {
        Self {
            engine,
            events: Vec::new(),
            _keep: Vec::new(),
        }
    }

    fn at(mut self, frame: usize, event: impl FnMut(&mut AudioEngine) + 'static) -> Self {
        self.events.push((frame, Box::new(event)));
        self
    }

    fn render(mut self, block: usize) -> Vec<f32> {
        self.events.sort_by_key(|(frame, _)| *frame);
        let mut output = vec![0.0_f32; FRAMES * 2];
        let mut frame = 0;
        let mut next = 0;
        while frame < FRAMES {
            while next < self.events.len() && self.events[next].0 <= frame {
                (self.events[next].1)(&mut self.engine);
                next += 1;
            }
            let until = self
                .events
                .get(next)
                .map_or(FRAMES, |(at, _)| (*at).min(FRAMES));
            let frames = block.min(until - frame);
            self.engine
                .process(&mut output[frame * 2..(frame + frames) * 2]);
            frame += frames;
        }
        output
    }
}

fn fixture(name: &str, block: usize) -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("tests/fixtures/engine_golden")
        .join(format!("{name}_{block}.f32"))
}

/// Renders `build()` at every block size and compares it with its stored render.
fn check(name: &str, build: fn() -> Scenario) {
    for block in BLOCKS {
        let rendered = build().render(block);
        assert!(
            rendered.iter().all(|sample| sample.is_finite()),
            "{name} block {block}: non-finite output"
        );
        assert!(
            rendered.iter().any(|sample| sample.abs() > 1.0e-3),
            "{name} block {block}: the scenario renders silence"
        );
        let path = fixture(name, block);
        if std::env::var_os("UPDATE_ENGINE_GOLDEN").is_some() {
            std::fs::create_dir_all(path.parent().unwrap()).unwrap();
            std::fs::write(&path, bytemuck::cast_slice::<f32, u8>(&rendered)).unwrap();
            continue;
        }
        let bytes = std::fs::read(&path)
            .unwrap_or_else(|error| panic!("{}: {error}; see the module docs", path.display()));
        let reference: Vec<f32> = bytes
            .chunks_exact(4)
            .map(|bytes| f32::from_le_bytes([bytes[0], bytes[1], bytes[2], bytes[3]]))
            .collect();
        assert_eq!(reference.len(), rendered.len(), "{name} block {block}");
        let (index, worst) = rendered
            .iter()
            .zip(&reference)
            .map(|(rendered, reference)| (rendered - reference).abs())
            .enumerate()
            .fold((0, 0.0_f32), |worst, (index, difference)| {
                if difference > worst.1 {
                    (index, difference)
                } else {
                    worst
                }
            });
        assert!(
            worst <= TOLERANCE,
            "{name} block {block}: frame {} channel {} is {} but the reference is {}",
            index / 2,
            index % 2,
            rendered[index],
            reference[index]
        );
    }
}

fn track_target(track: TrackId) -> MixerChannelTarget {
    MixerChannelTarget::Track(track)
}

/// One track playing a clip at the engine rate.
fn tone_track(app: &mut ApplicationState, left_hz: f32, right_hz: f32) -> TrackId {
    let source = add_waveform(
        app,
        &WaveformSpec::stereo(8_000),
        tone(SAMPLE_RATE, left_hz, right_hz),
    );
    let track = app.add_new_audio_track().id;
    add_audio_clip(app, source, track, 0, None);
    track
}

fn clip_static() -> Scenario {
    let mut app = project();
    let track = tone_track(&mut app, 220.0, 330.0);
    let mut engine = engine(512);
    publish(&mut engine, &app);
    set_mixer(
        &mut engine,
        track_target(track),
        MixerChannelParams::Volume(-6.0),
    );
    set_mixer(
        &mut engine,
        track_target(track),
        MixerChannelParams::Pan(0.3),
    );
    play(&mut engine, 0);
    Scenario::new(engine)
}

fn clip_resampled_loop() -> Scenario {
    let mut app = project();
    // A mono 44.1 kHz loop with a loop crossfade and a fade-in, repeating about every 1,600
    // engine frames.
    let looped = add_waveform(
        &mut app,
        &WaveformSpec {
            rate: 44_100,
            channels: 1,
            looping: true,
            envelope: GainEnvelope {
                fade_in: Fade {
                    length: 200,
                    ..Fade::default()
                },
                crossfade: 300,
                ..GainEnvelope::default()
            },
            ..WaveformSpec::stereo(1_500)
        },
        |frame, _| ((frame % 97) as f32 / 97.0 - 0.5) * 0.6,
    );
    let tail = add_waveform(
        &mut app,
        &WaveformSpec::stereo(6_000),
        tone(SAMPLE_RATE, 440.0, 660.0),
    );
    let track = app.add_new_audio_track().id;
    let first = add_audio_clip(&mut app, looped, track, 0, Some((3_000, 0)));
    // Starts 400 samples before the first clip ends and enters 250 samples into its source.
    let second = add_audio_clip(&mut app, tail, track, 104, Some((1_400, 250)));
    app.clips_pool[first].envelope = Some(Arc::new(GainEnvelope {
        fade_out: Fade {
            length: 500,
            ..Fade::default()
        },
        crossfade: 400,
        points: vec![
            EnvelopePoint::default(),
            EnvelopePoint {
                position: 2_000,
                gain: 0.4,
                ..EnvelopePoint::default()
            },
        ],
        ..GainEnvelope::default()
    }));
    app.clips_pool[second].envelope = Some(Arc::new(GainEnvelope {
        crossfade: 400,
        ..GainEnvelope::default()
    }));
    let mut engine = engine(512);
    publish(&mut engine, &app);
    play(&mut engine, 0);
    Scenario::new(engine)
}

fn clip_tempo_modes() -> Scenario {
    let mut app = project();
    // Recorded at 100 BPM and played at 120: one keeps its pitch, the other is resampled.
    for (mode, hz) in [
        (AudioSampleMode::Stretch, 300.0),
        (AudioSampleMode::Resampled, 450.0),
    ] {
        let source = add_waveform(
            &mut app,
            &WaveformSpec {
                mode,
                original_bpm: Some(100.0),
                ..WaveformSpec::stereo(12_000)
            },
            tone(SAMPLE_RATE, hz, hz * 1.25),
        );
        let track = app.add_new_audio_track().id;
        add_audio_clip(&mut app, source, track, 0, None);
    }
    let mut engine = engine(512);
    publish(&mut engine, &app);
    play(&mut engine, 0);
    Scenario::new(engine)
}

/// A pattern of three overlapping notes, 3,000 samples long.
fn chord_pattern(app: &mut ApplicationState) -> PatternId {
    let pattern = app.pattern_pool.insert_with_key(|id| Pattern {
        id,
        length_ticks: 120,
        ..Pattern::default()
    });
    for (key, start, length) in [(60, 0, 50), (64, 30, 50), (67, 70, 40)] {
        app.pattern_pool[pattern]
            .add_note(key, start, Some(length))
            .expect("note");
    }
    pattern
}

fn synth_chain() -> Scenario {
    let mut app = project();
    let (track, generator) = add_synth_track(&mut app, "synth_my_retro");
    let pattern = chord_pattern(&mut app);
    app.create_new_clip(Some(pattern.to_u64()), ClipSourceType::Midi, track, 4)
        .expect("pattern clip");
    let mut engine = engine(512);
    publish(&mut engine, &app);
    install_generator(&mut engine, track, generator, "synth_my_retro");
    add_effect(
        &mut engine,
        EffectTarget::Track(track),
        1,
        "effect_param_eq",
        &[("band3/gain", 9.0), ("band5/gain", -12.0)],
    );
    add_effect(
        &mut engine,
        EffectTarget::Track(track),
        2,
        "effect_delay",
        &[("delay/delay_ms", 20.0), ("delay/feedback", 0.5)],
    );
    add_effect(
        &mut engine,
        EffectTarget::Master,
        3,
        "effect_param_eq",
        &[("base_gain", -3.0)],
    );
    play(&mut engine, 0);
    Scenario::new(engine)
}

fn routing_pdc() -> Scenario {
    let mut app = project();
    let lead = tone_track(&mut app, 220.0, 275.0);
    let pad = tone_track(&mut app, 330.0, 495.0);
    let mut engine = engine(512);
    publish(&mut engine, &app);
    let bus = BusId::from(1);
    engine.process_command(AudioCommand::AddBus {
        bus_id: bus,
        name: "Send".into(),
    });
    // A latent effect on the lead puts delay compensation on the other paths.
    add_effect(
        &mut engine,
        EffectTarget::Track(lead),
        1,
        "effect_pitch_shifter",
        &[],
    );
    let ducker = add_effect(
        &mut engine,
        EffectTarget::Track(pad),
        1,
        "effect_digidaw_sidechain_comp",
        &[],
    );
    add_effect(
        &mut engine,
        EffectTarget::Bus(bus),
        1,
        "effect_delay",
        &[("delay/delay_ms", 15.0)],
    );
    let mut send =
        RoutingConnection::new_send(RoutingNode::Track(lead), RoutingNode::Bus(bus), 0.5);
    send.tap = RoutingTap::PreFader;
    engine.process_command(AudioCommand::UpdateRouting {
        routing: vec![
            RoutingConnection::new(RoutingNode::Track(lead), RoutingNode::Master),
            send,
            RoutingConnection::new_send(
                RoutingNode::Track(lead),
                RoutingNode::PluginSidechain(SidechainRoute::TrackEffect(pad, ducker)),
                1.0,
            ),
            RoutingConnection::new(RoutingNode::Track(pad), RoutingNode::Bus(bus)),
            RoutingConnection::new(RoutingNode::Bus(bus), RoutingNode::Master),
        ]
        .into_boxed_slice(),
    });
    set_mixer(
        &mut engine,
        track_target(lead),
        MixerChannelParams::Volume(-9.0),
    );
    set_mixer(
        &mut engine,
        MixerChannelTarget::Bus(bus),
        MixerChannelParams::Pan(-0.5),
    );
    play(&mut engine, 0);
    Scenario::new(engine)
}

fn fader_moves() -> Scenario {
    let mut app = project();
    let track = tone_track(&mut app, 220.0, 330.0);
    let mut engine = engine(512);
    publish(&mut engine, &app);
    play(&mut engine, 0);
    let moves: [(usize, MixerChannelTarget, MixerChannelParams); 6] = [
        (300, track_target(track), MixerChannelParams::Volume(-18.0)),
        (900, track_target(track), MixerChannelParams::Pan(-0.8)),
        (1_500, track_target(track), MixerChannelParams::Volume(4.0)),
        (
            2_100,
            MixerChannelTarget::Master,
            MixerChannelParams::Volume(-12.0),
        ),
        (2_700, track_target(track), MixerChannelParams::Pan(0.9)),
        (
            3_300,
            MixerChannelTarget::Master,
            MixerChannelParams::Volume(0.0),
        ),
    ];
    moves
        .into_iter()
        .fold(Scenario::new(engine), |scenario, (frame, target, param)| {
            scenario.at(frame, move |engine| {
                set_mixer(engine, target.clone(), param.clone());
            })
        })
}

fn channel_switches() -> Scenario {
    let mut app = project();
    let first = tone_track(&mut app, 220.0, 330.0);
    let second = tone_track(&mut app, 550.0, 770.0);
    let routing = app.mixer.routing.clone();
    let mut engine = engine(512);
    publish(&mut engine, &app);
    let effect = add_effect(
        &mut engine,
        EffectTarget::Track(second),
        1,
        "effect_param_eq",
        &[("base_gain", -9.0)],
    );
    play(&mut engine, 0);
    let unlinked: Vec<RoutingConnection> = routing
        .iter()
        .filter(|route| route.source != RoutingNode::Track(second))
        .cloned()
        .collect();
    let switch = |target: MixerChannelTarget, param: MixerChannelParams| {
        move |engine: &mut AudioEngine| set_mixer(engine, target.clone(), param.clone())
    };
    Scenario::new(engine)
        .at(
            400,
            switch(track_target(first), MixerChannelParams::Mute(true)),
        )
        .at(
            800,
            switch(track_target(first), MixerChannelParams::Mute(false)),
        )
        .at(
            1_200,
            switch(track_target(second), MixerChannelParams::Solo(true)),
        )
        .at(
            1_600,
            switch(track_target(second), MixerChannelParams::Solo(false)),
        )
        .at(
            2_000,
            switch(track_target(first), MixerChannelParams::InvertedPhase(true)),
        )
        .at(2_400, move |engine| {
            engine.process_command(AudioCommand::SetEffectBypass {
                target: EffectTarget::Track(second),
                effect_id: effect,
                bypass: true,
            });
        })
        .at(2_800, move |engine| {
            engine.process_command(AudioCommand::SetEffectBypass {
                target: EffectTarget::Track(second),
                effect_id: effect,
                bypass: false,
            });
        })
        .at(3_200, move |engine| {
            engine.process_command(AudioCommand::UpdateRouting {
                routing: unlinked.clone().into_boxed_slice(),
            });
        })
        .at(3_600, move |engine| {
            engine.process_command(AudioCommand::UpdateRouting {
                routing: routing.clone().into_boxed_slice(),
            });
        })
}

fn transport_edges() -> Scenario {
    let mut app = project();
    let track = tone_track(&mut app, 220.0, 330.0);
    let mut engine = engine(512);
    publish(&mut engine, &app);
    add_effect(
        &mut engine,
        EffectTarget::Track(track),
        1,
        "effect_delay",
        &[("delay/delay_ms", 12.0), ("delay/feedback", 0.6)],
    );
    // Ticks 8..68 are samples 200..1,700: the loop end falls inside a block at every size.
    engine.process_command(AudioCommand::SetLooping(true));
    engine.process_command(AudioCommand::SetSongLoopRegion(Some((8, 68))));
    play(&mut engine, 0);
    Scenario::new(engine)
        .at(2_600, |engine| {
            engine.process_command(AudioCommand::SetPlaying(false));
        })
        .at(3_400, |engine| {
            engine.process_command(AudioCommand::SetLooping(false));
            play(engine, 500);
        })
}

fn pattern_mode() -> Scenario {
    let mut app = project();
    let (track, generator) = add_synth_track(&mut app, "synth_my_retro");
    let pattern = chord_pattern(&mut app);
    let mut engine = engine(512);
    publish(&mut engine, &app);
    install_generator(&mut engine, track, generator, "synth_my_retro");
    engine.process_command(AudioCommand::TogglePatternPlayback {
        pattern_id: pattern,
        generator_id: generator,
    });
    Scenario::new(engine)
}

fn hosted_idle() -> Scenario {
    use karbeat_host::{HostInstanceId, HostedProcessor, ProcessingConfig};

    let mut app = project();
    let track = tone_track(&mut app, 220.0, 330.0);
    let mut engine = engine(512);
    publish(&mut engine, &app);
    let mut keep: Vec<Box<dyn Any>> = Vec::new();
    for (index, target) in [
        PluginTarget::TrackEffect(track, EffectId::from(1)),
        PluginTarget::MasterEffect(EffectId::from(2)),
    ]
    .into_iter()
    .enumerate()
    {
        let (processor, retirement) = Box::new(HostedProcessor::new(
            Box::new(IdleProbe {
                calls: Arc::default(),
                ringing: 24,
                continuous: false,
            }),
            HostInstanceId(index as u64 + 1),
        ))
        .prepare_transfer()
        .expect("transfer");
        let (install, _) = HostedPluginInstall::new(
            target,
            None,
            123,
            ProcessingConfig {
                sample_rate: f64::from(SAMPLE_RATE),
                max_block_size: 4_096,
                main_input_channels: 2,
                main_output_channels: 2,
                sidechain_channels: 0,
                offline: false,
            },
            processor,
        );
        let (command, mut control) = karbeat_host::ControlTransfer::new(install);
        engine.process_command(AudioCommand::InstallHostedPlugin(command));
        assert!(control.collect());
        keep.push(Box::new(retirement));
    }
    // The transport never starts: hosted effects run on the silent channels all the same.
    Scenario {
        engine,
        events: Vec::new(),
        _keep: keep,
    }
}

fn bounce() -> Scenario {
    let mut app = project();
    let track = tone_track(&mut app, 220.0, 330.0);
    let mut live = engine(512);
    publish(&mut live, &app);
    add_effect(
        &mut live,
        EffectTarget::Track(track),
        1,
        "effect_param_eq",
        &[("band3/gain", 6.0)],
    );
    add_effect(
        &mut live,
        EffectTarget::Master,
        2,
        "effect_param_eq",
        &[("base_gain", -20.0)],
    );
    let (mut commands, consumer) = RingBuffer::<AudioCommand>::new(16);
    let (position, _) = RingBuffer::<TransportFeedback>::new(1_024);
    let (feedback, _) = RingBuffer::<AudioFeedback>::new(1_024);
    let mut offline = AudioEngine::from_export_snapshot(
        live.export_snapshot().without_master(),
        &PluginRegistry::new_with_defaults(),
        2,
        consumer,
        position,
        feedback,
    )
    .expect("snapshot");
    for command in [
        AudioCommand::UpdateAudioConfig {
            sample_rate: Some(SAMPLE_RATE),
            buffer_size: Some(512),
        },
        AudioCommand::SetPlaybackMode(crate::audio::engine::PlaybackMode::Song),
        AudioCommand::SetPlayhead(0),
        AudioCommand::SetPlaying(true),
    ] {
        assert!(commands.push(command).is_ok());
    }
    offline.process(&mut []);
    Scenario {
        engine: offline,
        events: Vec::new(),
        _keep: vec![Box::new(commands)],
    }
}

macro_rules! golden {
    ($($name:ident),+ $(,)?) => {
        $(
            mod $name {
                #[test]
                fn matches_the_reference_render() {
                    super::check(stringify!($name), super::$name);
                }
            }
        )+
    };
}

golden!(
    clip_static,
    clip_resampled_loop,
    clip_tempo_modes,
    synth_chain,
    routing_pdc,
    fader_moves,
    channel_switches,
    transport_edges,
    pattern_mode,
    hosted_idle,
    bounce,
);
