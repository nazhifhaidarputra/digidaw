//! Recording device input to audio clips on audio tracks.

use std::collections::HashMap;
use std::time::Duration;

use flutter_rust_bridge::frb;
use karbeat_audio::recording::{TakeFinisher, TakeProgress};
use karbeat_core::shared::id::*;
use karbeat_core_api::{
    audio_waveform_api,
    jobs::{JobClass, JobKind, JobSpec},
    recording_api,
};

use crate::api::context::DawContext;
use crate::api::jobs::run_job;
use crate::api::project::UiTrack;
use crate::frb_generated::StreamSink;

/// How often the recording stream reports progress.
const PROGRESS_INTERVAL: Duration = Duration::from_millis(33);

/// How arming a track went.
#[derive(Clone, Copy, Debug)]
#[frb(dart_metadata=("freezed"))]
pub struct UiStartedTake {
    /// Whether the device input had to be turned on, which restarts the audio stream.
    pub enabled_input: bool,
}

/// What a take recorded since its last report.
#[derive(Clone, Debug)]
#[frb(dart_metadata=("freezed"))]
pub struct UiRecordingProgress {
    pub track_id: u64,
    /// Song playhead, in samples, the take starts at; `None` while it waits for playback.
    pub start_samples: Option<u64>,
    /// Frames recorded so far.
    pub frames: u64,
    pub sample_rate: u32,
    /// Index of the first pair of `peaks` within the take.
    pub peak_offset: usize,
    /// New lowest/highest sample pairs, one pair per 256 frames.
    pub peaks: Vec<f32>,
    /// Whether the engine stopped recording the take, because the song stopped or was
    /// seeked; finish it with [`stop_track_recording`].
    pub ended: bool,
}

impl From<TakeProgress> for UiRecordingProgress {
    fn from(value: TakeProgress) -> Self {
        Self {
            track_id: value.track_id.to_u64(),
            start_samples: value.start_playhead_samples,
            frames: value.frames,
            sample_rate: value.sample_rate,
            peak_offset: value.peak_offset,
            peaks: value.peaks,
            ended: value.ended,
        }
    }
}

/// Arms an audio track: its input records once the song plays.
pub fn start_track_recording(ctx: &DawContext, track_id: u64) -> Result<UiStartedTake, String> {
    crate::api::context::project_ctx!(ctx);
    recording_api::start_track_recording(ctx, TrackId::from_u64(track_id))
        .map(|started| UiStartedTake {
            enabled_input: started.enabled_input,
        })
        .map_err(|error| format!("{error:#}"))
}

/// Tracks with a take waiting for or recording audio.
pub fn get_recording_tracks(ctx: &DawContext) -> Vec<u64> {
    crate::api::context::read_ctx!(ctx);
    recording_api::recording_tracks(ctx)
        .into_iter()
        .map(|track_id| track_id.to_u64())
        .collect()
}

/// Ends a track's take and places what it recorded as a clip. Returns the updated track, or
/// `None` when the take recorded no audio.
pub async fn stop_track_recording(
    ctx: &DawContext,
    track_id: u64,
) -> Result<Option<UiTrack>, String> {
    let ctx = ctx.clone();
    run_job(
        JobSpec::new(JobKind::AudioImport, JobClass::Heavy),
        move |_| -> Result<Option<UiTrack>, String> {
            let finisher = {
                crate::api::context::project_ctx!(ctx);
                recording_api::end_track_recording(ctx, TrackId::from_u64(track_id))
                    .map_err(|error| format!("{error:#}"))?
            };
            finish_take(&ctx, finisher)
        },
    )
    .await
}

/// Ends every take at the same block and places them as clips. Returns the tracks that got a
/// clip.
pub async fn stop_all_recordings(ctx: &DawContext) -> Result<Vec<UiTrack>, String> {
    let ctx = ctx.clone();
    run_job(
        JobSpec::new(JobKind::AudioImport, JobClass::Heavy),
        move |_| -> Result<Vec<UiTrack>, String> {
            let finishers = {
                crate::api::context::project_ctx!(ctx);
                recording_api::recording_tracks(ctx)
                    .into_iter()
                    .map(|track_id| recording_api::end_track_recording(ctx, track_id))
                    .collect::<anyhow::Result<Vec<_>>>()
                    .map_err(|error| format!("{error:#}"))?
            };
            // Every take is finished, even when an earlier one fails.
            let mut tracks = Vec::new();
            let mut failure = None;
            for finisher in finishers {
                match finish_take(&ctx, finisher) {
                    Ok(Some(track)) => tracks.push(track),
                    Ok(None) => {}
                    Err(error) => failure = Some(error),
                }
            }
            match failure {
                Some(error) => Err(error),
                None => Ok(tracks),
            }
        },
    )
    .await
}

/// Waits for a take's file, then imports it and places its clip.
fn finish_take(ctx: &DawContext, finisher: TakeFinisher) -> Result<Option<UiTrack>, String> {
    let Some(take) = finisher.wait().map_err(|error| format!("{error:#}"))? else {
        return Ok(None);
    };
    let pending = recording_api::begin_take_import(&ctx.read(), &take)
        .map_err(|error| format!("{error:#}"))?;
    let completed =
        audio_waveform_api::execute_audio_import(pending).map_err(|error| error.to_string())?;
    let mut core = ctx.project_write();
    let track = recording_api::commit_take(&mut core, &take, completed)
        .map_err(|error| format!("{error:#}"))?;
    Ok(Some(UiTrack::from_track(&track, &core.app_state)))
}

/// Streams what each take records, about 30 times a second while takes are armed.
pub fn create_recording_stream(
    sink: StreamSink<UiRecordingProgress>,
    ctx: &DawContext,
) -> Result<(), String> {
    let registry = std::sync::Arc::clone(&ctx.read().recordings);
    std::thread::Builder::new()
        .name("karbeat-recording-stream".into())
        .spawn(move || {
            // The last frame count and ended flag sent per take; unchanged takes stay quiet.
            let mut sent: HashMap<TrackId, (u64, bool, bool)> = HashMap::new();
            loop {
                let progress = registry.lock().progress();
                sent.retain(|track_id, _| progress.iter().any(|take| take.track_id == *track_id));
                for take in progress {
                    let state = (
                        take.frames,
                        take.ended,
                        take.start_playhead_samples.is_some(),
                    );
                    if sent.get(&take.track_id) == Some(&state) && take.peaks.is_empty() {
                        continue;
                    }
                    sent.insert(take.track_id, state);
                    if sink.add(take.into()).is_err() {
                        log::info!("Recording stream disconnected; stopping its thread.");
                        return;
                    }
                }
                std::thread::sleep(PROGRESS_INTERVAL);
            }
        })
        .map_err(|error| error.to_string())?;
    Ok(())
}
