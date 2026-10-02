//! Time per 512-frame engine block for representative projects.
//!
//! `cargo bench -p karbeat-core --bench engine_block --features bench-support`
#![allow(
    clippy::unwrap_used,
    missing_docs,
    reason = "benchmark fixtures are deterministic"
)]

use std::hint::black_box;

use criterion::{Criterion, criterion_group, criterion_main};
use karbeat_core::{
    audio::engine::test_support::{BenchProject, bench_engine, play, set_mixer},
    commands::{AudioCommand, MixerChannelTarget},
    core::project::MixerChannelParams,
};

const BLOCK: usize = 512;

/// Loops the song over `ticks` so a benchmark never runs out of clips.
fn looped(shape: BenchProject, ticks: (u64, u64)) -> karbeat_core::audio::engine::AudioEngine {
    let (mut engine, _) = bench_engine(shape, BLOCK);
    engine.process_command(AudioCommand::SetLooping(true));
    engine.process_command(AudioCommand::SetSongLoopRegion(Some(ticks)));
    // One tick is 25 samples at the fixture tempo and rate.
    play(&mut engine, u32::try_from(ticks.0).unwrap() * 25);
    engine
}

fn engine_blocks(criterion: &mut Criterion) {
    let mut group = criterion.benchmark_group("engine_block_512");
    let mut block = vec![0.0_f32; BLOCK * 2];

    let small = BenchProject {
        tracks: 8,
        clips_per_track: 16,
        clip_frames: 48_000,
        buses: 0,
        effects_per_track: 0,
        resampled: false,
        passthrough_effects: 0,
    };
    let mut engine = looped(small, (1_920, 28_800));
    group.bench_function("tracks_8", |bench| {
        bench.iter(|| engine.process(black_box(block.as_mut_slice())));
    });

    let mut engine = looped(
        BenchProject {
            resampled: true,
            ..small
        },
        (1_920, 28_800),
    );
    group.bench_function("tracks_8_resampled", |bench| {
        bench.iter(|| engine.process(black_box(block.as_mut_slice())));
    });

    let large = BenchProject {
        tracks: 64,
        clips_per_track: 8,
        clip_frames: 48_000,
        buses: 4,
        effects_per_track: 2,
        resampled: false,
        passthrough_effects: 0,
    };
    let mut engine = looped(large, (1_920, 13_440));
    group.bench_function("tracks_64_buses_4_effects", |bench| {
        bench.iter(|| engine.process(black_box(block.as_mut_slice())));
    });

    // The same mix without plugins, which leaves only the engine's own work.
    let mut engine = looped(
        BenchProject {
            effects_per_track: 0,
            buses: 0,
            ..large
        },
        (1_920, 13_440),
    );
    group.bench_function("tracks_64", |bench| {
        bench.iter(|| engine.process(black_box(block.as_mut_slice())));
    });

    // Two copy-only effects per track: the cost of running effect chains, without plugins.
    let mut engine = looped(
        BenchProject {
            effects_per_track: 0,
            passthrough_effects: 2,
            buses: 0,
            ..large
        },
        (1_920, 13_440),
    );
    group.bench_function("tracks_64_passthrough_chains", |bench| {
        bench.iter(|| engine.process(black_box(block.as_mut_slice())));
    });

    // The transport is stopped: only meters, routing bookkeeping and silence handling run.
    let (mut engine, _) = bench_engine(large, BLOCK);
    group.bench_function("tracks_64_idle", |bench| {
        bench.iter(|| engine.process(black_box(block.as_mut_slice())));
    });

    // 5,000 short clips, playing near the end of the song.
    let mut engine = looped(
        BenchProject {
            tracks: 10,
            clips_per_track: 500,
            clip_frames: 2_400,
            buses: 0,
            effects_per_track: 0,
            resampled: false,
            passthrough_effects: 0,
        },
        (96 * 450, 96 * 490),
    );
    group.bench_function("clips_5000_late", |bench| {
        bench.iter(|| engine.process(black_box(block.as_mut_slice())));
    });

    // Every fader moves every block, so the smoothing path never settles.
    let (mut engine, tracks) = bench_engine(
        BenchProject {
            tracks: 16,
            ..small
        },
        BLOCK,
    );
    engine.process_command(AudioCommand::SetLooping(true));
    engine.process_command(AudioCommand::SetSongLoopRegion(Some((1_920, 28_800))));
    play(&mut engine, 48_000);
    let mut loud = false;
    group.bench_function("tracks_16_faders_moving", |bench| {
        bench.iter(|| {
            loud = !loud;
            for track in &tracks {
                set_mixer(
                    &mut engine,
                    MixerChannelTarget::Track(*track),
                    MixerChannelParams::Volume(if loud { 0.0 } else { -12.0 }),
                );
            }
            engine.process(black_box(block.as_mut_slice()));
        });
    });
    group.finish();
}

criterion_group!(benches, engine_blocks);
criterion_main!(benches);
