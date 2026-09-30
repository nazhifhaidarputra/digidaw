//! Runs tempo analysis with the real Beat This! models in `assets/models`.
//!
//! Fetch the models with `scripts/fetch_beat_models.sh`; the tests skip when they are absent.
//! Measure peak memory and time with
//! `KARBEAT_WORKERS=4 cargo test --release -p karbeat-analysis --test beat_this_models -- --ignored --nocapture`.
#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::as_conversions,
    clippy::indexing_slicing,
    reason = "integration test fixtures"
)]

use std::{
    path::PathBuf,
    sync::{
        Arc,
        atomic::{AtomicBool, Ordering},
    },
};

use karbeat_analysis::{AnalysisError, AudioInput, ModelPaths, analyze_tempo, configure_models};

const RATE: u32 = 44_100;
const BPM: f32 = 120.0;

fn models() -> Option<ModelPaths> {
    let root = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../assets/models");
    let paths = ModelPaths {
        mel: root.join("mel_spectrogram.onnx"),
        beat: root.join("beat_this_small.onnx"),
    };
    if paths.mel.is_file() && paths.beat.is_file() {
        Some(paths)
    } else {
        eprintln!("Skipping: run scripts/fetch_beat_models.sh to fetch the models");
        None
    }
}

/// Stereo drum loop at 120 BPM: kick on beats 1 and 3, snare on 2 and 4, noisy hats on
/// eighths. Plain sine clicks are a poor fixture: the model can miss them entirely at some
/// sub-frame phases, while this loop is detected at any phase.
fn drum_loop(seconds: f32) -> Vec<f32> {
    let frames = (seconds * RATE as f32) as usize;
    let eighth = 30.0 / BPM * RATE as f32;
    let mut seed = 0x2545_f491_u32;
    let mut noise = move || {
        seed ^= seed << 13;
        seed ^= seed >> 17;
        seed ^= seed << 5;
        (seed as f32 / u32::MAX as f32) * 2.0 - 1.0
    };
    let mut mono = vec![0.0_f32; frames];
    for step in 0.. {
        let start = (step as f32 * eighth) as usize;
        if start >= frames {
            break;
        }
        for offset in 0..(RATE as usize / 4).min(frames - start) {
            let t = offset as f32 / RATE as f32;
            let mut value = 0.15 * (-t * 120.0).exp() * noise();
            if step % 4 == 0 {
                let pitch = 50.0 + 90.0 * (-t * 30.0).exp();
                value += 0.9 * (-t * 25.0).exp() * (std::f32::consts::TAU * pitch * t).sin();
            }
            if step % 4 == 2 {
                value += 0.5 * (-t * 30.0).exp() * noise()
                    + 0.3 * (-t * 20.0).exp() * (std::f32::consts::TAU * 190.0 * t).sin();
            }
            mono[start + offset] += value;
        }
    }
    mono.iter().flat_map(|sample| [*sample, *sample]).collect()
}

fn pool(threads: usize) -> rayon::ThreadPool {
    rayon::ThreadPoolBuilder::new()
        .num_threads(threads)
        .build()
        .unwrap()
}

fn analyze(samples: &[f32], pool: Option<&rayon::ThreadPool>) -> karbeat_analysis::TempoAnalysis {
    let mut last = 0.0;
    let analysis = analyze_tempo(
        AudioInput {
            samples,
            channels: 2,
            sample_rate: RATE,
        },
        pool,
        Arc::new(AtomicBool::new(false)),
        &mut |fraction| {
            assert!(fraction >= last);
            last = fraction;
        },
    )
    .unwrap();
    assert_eq!(last, 1.0);
    analysis
}

#[test]
fn parallel_segments_find_the_beats_of_a_single_pass() {
    let Some(paths) = models() else { return };
    configure_models(paths).unwrap();
    let samples = drum_loop(90.0);

    let serial = analyze(&samples, None);
    assert!((serial.bpm - BPM).abs() < 1.0, "{} BPM", serial.bpm);
    assert!(serial.confidence > 0.8, "confidence {}", serial.confidence);
    assert!(!serial.downbeats.is_empty());

    // With enough free memory the segments match and so do the beats; when memory is short
    // the parallel run uses shorter segments, which moves beats by a few milliseconds.
    let parallel = analyze(&samples, Some(&pool(4)));
    assert!(
        (parallel.bpm - serial.bpm).abs() < 1.0,
        "{} BPM",
        parallel.bpm
    );
    let matched = serial
        .beats
        .iter()
        .filter(|beat| {
            parallel
                .beats
                .iter()
                .any(|other| (*beat - other).abs() < 0.07)
        })
        .count();
    assert!(
        matched as f32 >= serial.beats.len() as f32 * 0.97,
        "{matched} of {} beats match",
        serial.beats.len()
    );
}

#[test]
fn short_audio_is_detected_too() {
    let Some(paths) = models() else { return };
    configure_models(paths).unwrap();
    let analysis = analyze(&drum_loop(20.0), Some(&pool(4)));
    assert!((analysis.bpm - BPM).abs() < 1.0, "{} BPM", analysis.bpm);
}

#[test]
fn cancellation_stops_before_the_next_model_call() {
    let Some(paths) = models() else { return };
    configure_models(paths).unwrap();
    let samples = drum_loop(90.0);
    let cancel = Arc::new(AtomicBool::new(true));
    let result = analyze_tempo(
        AudioInput {
            samples: &samples,
            channels: 2,
            sample_rate: RATE,
        },
        Some(&pool(4)),
        Arc::clone(&cancel),
        &mut |_| {},
    );
    assert_eq!(result, Err(AnalysisError::Cancelled));
    assert!(cancel.load(Ordering::Relaxed));
}

/// Peak resident memory of this process in MiB, from `/proc/self/status` on Linux.
fn peak_rss_mb() -> Option<u64> {
    let status = std::fs::read_to_string("/proc/self/status").ok()?;
    let line = status.lines().find(|line| line.starts_with("VmHWM:"))?;
    let kb: u64 = line.split_whitespace().nth(1)?.parse().ok()?;
    Some(kb / 1024)
}

#[test]
#[ignore = "measures peak memory and time; run alone"]
fn measure_peak_memory_and_time() {
    let Some(paths) = models() else { return };
    let workers: usize = std::env::var("KARBEAT_WORKERS")
        .ok()
        .and_then(|value| value.parse().ok())
        .unwrap_or(1);
    let seconds: f32 = std::env::var("KARBEAT_SECONDS")
        .ok()
        .and_then(|value| value.parse().ok())
        .unwrap_or(300.0);
    let samples = drum_loop(seconds);
    let before = peak_rss_mb().unwrap_or(0);
    configure_models(paths).unwrap();
    let pool = pool(workers);
    let started = std::time::Instant::now();
    let analysis = analyze(&samples, (workers > 1).then_some(&pool));
    let after = peak_rss_mb().unwrap_or(0);
    eprintln!(
        "{workers} worker(s): peak {after} MiB ({} MiB above the {before} MiB baseline), {:.1} s, {} BPM",
        after.saturating_sub(before),
        started.elapsed().as_secs_f32(),
        analysis.bpm
    );
}
