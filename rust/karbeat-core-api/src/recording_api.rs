//! Recording device input to audio clips.
//!
//! A take starts armed: its file and writer exist, and the engine records into it once the
//! song plays. Ending it waits for the writer, then the file is imported like any audio source
//! and placed as a clip where the take started, as one undoable step.

use std::path::{Path, PathBuf};
use std::sync::Arc;

use karbeat_audio::{
    commands::AudioCommand,
    context::DawContext,
    engine::InputSource,
    recording::{RecordedTake, TakeClocks, TakeFinisher, TakeRequest},
};
use karbeat_core::core::{
    history::actions::ClipEditRecorder,
    project::{AudioTrack, ClipSourceType, TickScale, TrackType},
};
use karbeat_core::shared::id::*;

use crate::audio_waveform_api::{self, CompletedAudioImport, PendingAudioImport};

/// Name of a take recorded at `now`: `Recording_` and the local time with its UTC offset, such as
/// `Recording_2026-10-30T14:05:33+07:00`.
pub fn take_name(now: &jiff::Zoned) -> String {
    format!("Recording_{}", now.strftime("%Y-%m-%dT%H:%M:%S%:z"))
}

/// File name of a take called `name`, without the colons some file systems reject.
fn take_file_stem(name: &str) -> String {
    name.replace(':', "-")
}

/// How a take started.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct StartedTake {
    /// Whether the device input was off and had to be turned on, restarting the audio stream.
    pub enabled_input: bool,
}

/// Arms `track_id` to record its input once the song plays.
///
/// The take's WAV file goes in the project's session folder, so saving the project packs it.
/// Turns the device input on when it is off.
pub fn start_track_recording(
    ctx: &mut DawContext,
    track_id: TrackId,
) -> anyhow::Result<StartedTake> {
    let track = ctx
        .app_state
        .tracks
        .get(track_id)
        .ok_or_else(|| anyhow::anyhow!("Track not found"))?;
    anyhow::ensure!(
        track.track_type == TrackType::Audio,
        "Only audio tracks record device input"
    );
    let source = InputSource::from(&track.input);
    anyhow::ensure!(
        !ctx.recordings.lock().is_recording(track_id),
        "The track is already recording"
    );

    let requested_input = ctx.audio_runtime_settings.read().requested_input.clone();
    let enabled_input = !requested_input.enabled;
    if enabled_input {
        crate::audio_settings_api::select_input(ctx, true, requested_input.device_id)?;
    }

    let name = take_name(&jiff::Zoned::now());
    let directory = ctx.app_state.asset_library.ensure_session_dir()?;
    let request = TakeRequest {
        track_id,
        source,
        sample_rate: ctx.audio_runtime_settings.read().requested_dsp.sample_rate,
        path: unique_take_path(&directory, &take_file_stem(&name)),
        name,
    };
    let clocks = TakeClocks {
        input: Arc::clone(&ctx.input_clock),
        output: Arc::clone(&ctx.output_clock),
    };
    let take = ctx.recordings.lock().begin(request, clocks)?;
    if let Err(error) = ctx.send_audio_command(AudioCommand::StartRecordingTake(take)) {
        // The dropped take abandons its ring, which ends the writer.
        if let Some(finisher) = ctx.recordings.lock().finish(track_id) {
            finisher.wait()?;
        }
        return Err(error.context("The audio engine did not take the recording"));
    }
    Ok(StartedTake { enabled_input })
}

/// A free path for a take file called `stem` in `directory`.
fn unique_take_path(directory: &Path, stem: &str) -> PathBuf {
    let mut path = directory.join(format!("{stem}.wav"));
    let mut counter = 2;
    while path.exists() {
        path = directory.join(format!("{stem}_{counter}.wav"));
        counter += 1;
    }
    path
}

/// Tracks with a take waiting for or recording audio.
pub fn recording_tracks(ctx: &DawContext) -> Vec<TrackId> {
    ctx.recordings.lock().recording_tracks()
}

/// Ends the take of `track_id`. Wait on the finisher without holding the project; it returns
/// the finished take, or `None` when it recorded no audio.
pub fn end_track_recording(
    ctx: &mut DawContext,
    track_id: TrackId,
) -> anyhow::Result<TakeFinisher> {
    let finisher = ctx
        .recordings
        .lock()
        .finish(track_id)
        .ok_or_else(|| anyhow::anyhow!("The track is not recording"))?;
    // A take the engine already ended, or never received, ignores this.
    let _ = ctx.send_audio_command(AudioCommand::EndRecordingTake { track_id });
    Ok(finisher)
}

/// Starts importing a finished take's file; decode it with
/// [`audio_waveform_api::execute_audio_import`].
pub fn begin_take_import(
    ctx: &DawContext,
    take: &RecordedTake,
) -> anyhow::Result<PendingAudioImport> {
    audio_waveform_api::begin_audio_import(ctx, &take.path.to_string_lossy())
}

/// Adds a decoded take as an audio source named after it and places it as a clip on its track
/// where it started, as one undoable step. Returns the updated track.
pub fn commit_take(
    ctx: &mut DawContext,
    take: &RecordedTake,
    completed: CompletedAudioImport,
) -> anyhow::Result<AudioTrack> {
    let source_id = audio_waveform_api::commit_audio_import(ctx, completed);
    if let Some(waveform) = ctx.app_state.asset_library.source_map.get_mut(source_id) {
        Arc::make_mut(waveform).name.clone_from(&take.name);
    }
    let start_tick = TickScale::new(ctx.app_state.transport.bpm, take.sample_rate)
        .to_ticks(take.start_playhead_samples);
    let start_tick = u32::try_from(start_tick)
        .map_err(|_| anyhow::anyhow!("The recording starts past the end of the timeline"))?;

    let recorder = ClipEditRecorder::begin(&ctx.app_state, "Record Audio", &[take.track_id], &[]);
    ctx.app_state.create_new_clip(
        Some(source_id.to_u64()),
        ClipSourceType::Audio,
        take.track_id,
        start_tick,
    )?;
    let action = recorder.finish(&mut ctx.app_state);
    ctx.push_history(action);
    ctx.broadcast_track_graph();
    ctx.app_state
        .tracks
        .get(take.track_id)
        .cloned()
        .ok_or_else(|| anyhow::anyhow!("The recorded track was deleted"))
}

#[cfg(test)]
#[allow(
    clippy::expect_used,
    reason = "recording tests fail immediately when a fixture cannot be built"
)]
mod tests {
    use super::*;

    #[test]
    fn take_names_carry_the_local_offset_and_files_drop_colons() {
        let zoned: jiff::Zoned = "2026-10-30T14:05:33+07:00[Asia/Jakarta]"
            .parse()
            .expect("fixture time must parse");
        let name = take_name(&zoned);
        assert_eq!(name, "Recording_2026-10-30T14:05:33+07:00");
        assert_eq!(take_file_stem(&name), "Recording_2026-10-30T14-05-33+07-00");
    }

    #[test]
    fn take_paths_never_overwrite_an_earlier_take() {
        let dir = tempfile::tempdir().expect("temporary dir");
        let first = unique_take_path(dir.path(), "Recording");
        std::fs::write(&first, b"").expect("take file");
        let second = unique_take_path(dir.path(), "Recording");
        assert_ne!(first, second);
        assert!(second.ends_with("Recording_2.wav"));
    }
}
