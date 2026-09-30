//! Tempo detection and fit-to-tempo renders, run as background jobs.
//!
//! Starters return the job id at once; progress and completion arrive through
//! `subscribe_job_events`, and the results are stored on the audio source.

use std::{
    path::PathBuf,
    sync::{Arc, atomic::Ordering},
    time::Duration,
};

use flutter_rust_bridge::frb;
use karbeat_core::shared::id::AudioSourceId;
use karbeat_core_api::{
    audio_analysis_api,
    jobs::{self, JobClass, JobContext, JobKind, JobSpec, JobTarget},
};

use crate::api::{context::DawContext, project::UiAudioSampleMode};

/// Delay before a tempo change starts a high-quality re-render. Until it lands, the engine
/// stretches the audio in realtime, so this can wait for the user to stop changing the tempo.
const TEMPO_EDIT_DEBOUNCE: Duration = Duration::from_millis(1500);
/// Tempo models stay loaded this long after the last detection when memory allows.
const MODEL_IDLE_TIMEOUT: Duration = Duration::from_secs(300);

/// Tempo detected in an audio source.
#[derive(Clone, Debug, serde::Serialize)]
#[frb(dart_metadata=("freezed"))]
pub struct UiBeatGrid {
    pub bpm: f32,
    /// Regularity of the beats, from 0.0 (erratic) to 1.0 (steady).
    pub confidence: f32,
    /// Beat times in seconds.
    pub beats: Vec<f32>,
    /// Downbeat times in seconds.
    pub downbeats: Vec<f32>,
}

impl From<&karbeat_core::core::project::track::audio_waveform::BeatGrid> for UiBeatGrid {
    fn from(value: &karbeat_core::core::project::track::audio_waveform::BeatGrid) -> Self {
        Self {
            bpm: value.bpm,
            confidence: value.confidence,
            beats: value.beats.clone(),
            downbeats: value.downbeats.clone(),
        }
    }
}

/// Sets the Beat This! model files, the mel front end and the small beat model; call once
/// at startup with the bundled asset paths.
pub async fn configure_tempo_models(mel_path: String, beat_path: String) -> Result<(), String> {
    audio_analysis_api::configure_tempo_models(PathBuf::from(mel_path), PathBuf::from(beat_path))
        .map_err(|error| error.to_string())
}

fn started(id: u64) -> Result<u64, String> {
    if id == 0 {
        Err("Background jobs are unavailable".into())
    } else {
        Ok(id)
    }
}

fn source_spec(kind: JobKind, class: JobClass, source_id: AudioSourceId) -> JobSpec {
    JobSpec::new(kind, class)
        .with_target(JobTarget::Source(source_id))
        .superseding()
}

/// Detects the tempo, beats and downbeats of an audio source in the background.
///
/// Stores them on the source as one undoable step. Returns the job id.
pub async fn start_tempo_detection(ctx: &DawContext, source_id: u64) -> Result<u64, String> {
    let ctx = ctx.clone();
    let source = AudioSourceId::from_u64(source_id);
    let handle = jobs::global().submit(
        source_spec(JobKind::TempoDetection, JobClass::Inference, source),
        move |job: &JobContext| -> Result<(), String> {
            let pending = audio_analysis_api::begin_detect_tempo(&ctx.read(), source)
                .map_err(|error| error.to_string())?;
            let completed = audio_analysis_api::execute_detect_tempo(
                pending,
                job.cancel_flag(),
                &mut |fraction| job.progress("analyze", fraction),
            )
            .map_err(|error| error.to_string())?;
            log::info!(
                "Detected {:.1} BPM in audio source {source_id}",
                completed.grid().bpm
            );
            if job.is_current() {
                audio_analysis_api::commit_detect_tempo(&mut ctx.project_write(), completed);
            }
            Ok(())
        },
    );
    jobs::global().schedule(MODEL_IDLE_TIMEOUT, || {
        audio_analysis_api::release_idle_tempo_models(MODEL_IDLE_TIMEOUT);
    });
    started(handle.id())
}

/// Stretches an audio source to the project tempo in the background, keeping its pitch.
///
/// `warp` stretches beat by beat so every detected beat lands on the grid; it needs a
/// finished tempo detection. The source switches to stretch mode and follows later tempo
/// changes. Undoable. Returns the job id.
pub async fn start_fit_to_tempo(
    ctx: &DawContext,
    source_id: u64,
    warp: bool,
) -> Result<u64, String> {
    let ctx = ctx.clone();
    let source = AudioSourceId::from_u64(source_id);
    // Validate before queueing, so the caller learns about a missing tempo at once.
    drop(
        audio_analysis_api::begin_fit_to_tempo(&ctx.read(), source, warp)
            .map_err(|error| error.to_string())?,
    );
    let handle = jobs::global().submit(
        source_spec(JobKind::WaveformRender, JobClass::Heavy, source),
        move |job: &JobContext| -> Result<(), String> {
            let pending = audio_analysis_api::begin_fit_to_tempo(&ctx.read(), source, warp)
                .map_err(|error| error.to_string())?;
            render(&ctx, pending, job)
        },
    );
    started(handle.id())
}

fn render(
    ctx: &DawContext,
    pending: audio_analysis_api::PendingRender,
    job: &JobContext,
) -> Result<(), String> {
    let cancel = job.cancel_flag();
    // A render that turns stale raises the job's own flag, so it ends as cancelled.
    let completed = audio_analysis_api::execute_render(
        pending.with_cancel_flag(Arc::clone(&cancel)),
        &|| cancel.load(Ordering::Acquire),
        &mut |f| job.progress("render", f),
    )
    .map_err(|error| format!("{error:#}"))?;
    if job.is_current() {
        audio_analysis_api::commit_render(&mut ctx.project_write(), completed);
    }
    Ok(())
}

/// Cancels running renders that no longer match the project, then queues renders for sources
/// whose render does not match their recipe: every edited source after a project loads, or
/// the stretched ones after the tempo changes. Call after any edit that can change either,
/// including undo and redo.
///
/// Tempo changes are debounced, and a newer request replaces an older one per source; a
/// stale render stops at once rather than when its replacement starts.
pub(crate) fn schedule_source_renders(ctx: &DawContext, tempo_changed: bool) {
    let sources = {
        let project = ctx.read();
        audio_analysis_api::cancel_stale_renders(&project);
        audio_analysis_api::sources_needing_render(&project)
    };
    let delay = if tempo_changed {
        TEMPO_EDIT_DEBOUNCE
    } else {
        Duration::ZERO
    };
    for source in sources {
        schedule_render(ctx, source, delay);
    }
}

/// Queues a render of one source's current recipe, replacing a pending one.
fn schedule_render(ctx: &DawContext, source: AudioSourceId, delay: Duration) {
    let ctx = ctx.clone();
    drop(jobs::global().submit_debounced(
        source_spec(JobKind::WaveformRender, JobClass::Heavy, source),
        delay,
        move |job: &JobContext| -> Result<(), String> {
            let pending = audio_analysis_api::begin_refresh_render(&ctx.read(), source)
                .map_err(|error| error.to_string())?;
            match pending {
                Some(pending) => render(&ctx, pending, job),
                None => Ok(()),
            }
        },
    ));
}

/// Changes how an audio source follows the project tempo (undoable), then renders it in the
/// background when needed. Stretch keeps the pitch; Resampled bends it like tape.
pub fn set_audio_source_sample_mode(
    ctx: &DawContext,
    source_id: u64,
    mode: UiAudioSampleMode,
) -> Result<(), String> {
    let source = AudioSourceId::from_u64(source_id);
    let needs_render =
        audio_analysis_api::set_sample_mode(&mut ctx.project_write(), source, mode.into())
            .map_err(|error| error.to_string())?;
    audio_analysis_api::cancel_stale_renders(&ctx.read());
    if needs_render {
        schedule_render(ctx, source, Duration::ZERO);
    }
    Ok(())
}

/// Sets an audio source's normalize, invert and reverse edits (undoable), then renders them
/// in the background. The original audio plays until the render is ready.
pub fn set_waveform_edits(
    ctx: &DawContext,
    source_id: u64,
    normalize: bool,
    invert: bool,
    reverse: bool,
) -> Result<(), String> {
    let source = AudioSourceId::from_u64(source_id);
    let needs_render = audio_analysis_api::set_waveform_edits(
        &mut ctx.project_write(),
        source,
        normalize,
        invert,
        reverse,
    )
    .map_err(|error| error.to_string())?;
    audio_analysis_api::cancel_stale_renders(&ctx.read());
    if needs_render {
        schedule_render(ctx, source, Duration::ZERO);
    }
    Ok(())
}
