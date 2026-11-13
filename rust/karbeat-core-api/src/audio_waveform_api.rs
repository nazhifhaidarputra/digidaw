use std::{collections::HashSet, fs::canonicalize, iter::empty, path::PathBuf, sync::Arc};

use anyhow::Context;

use crate::{audio_analysis_api::begin_refresh_render, audio_api::stop_all_previews};
use karbeat_audio::context::DawContext;
use karbeat_core::core::{
    file_manager::audio_loader::{AudioLoader, load_audio_file},
    history::actions::{
        AudioSourceRemoved, ClipEditRecorder, SourceEnvelopeChanged, SourceReplaced,
        SourceTrimChanged,
    },
    project::{
        AudioSourceId, AudioWaveform, ClipId, DawSource, GainEnvelope, TrackId, TrackType,
        track::audio_waveform::{AudioSampleMode, EditedWaveform, WaveformEdits},
    },
};

/// Get audio waveform clips data from Application and map them into U value
pub fn get_audio_waveform_clips_data<C, U, M>(ctx: &DawContext, mapper: M) -> anyhow::Result<C>
where
    M: Fn(&AudioSourceId, &AudioWaveform) -> U,
    C: FromIterator<U>,
{
    let app = &ctx.app_state;
    let map = app
        .get_audio_sources()
        .iter()
        .map(|(id, audio_waveform)| mapper(id, audio_waveform))
        .collect();
    Ok(map)
}

/// Maps waveform data for one audio clip after resolving its source from the project pool.
pub fn get_audio_waveform_for_clip(
    ctx: &DawContext,
    audio_source_id: &AudioSourceId,
) -> anyhow::Result<Arc<AudioWaveform>> {
    let app = &ctx.app_state;
    let audio_waveform = app.get_audio_source(audio_source_id).ok_or_else(|| {
        anyhow::anyhow!("Cannot get the audio source with id {}", audio_source_id)
    })?;

    Ok(audio_waveform.clone())
}

/// Collects mapped waveform data for audio clips belonging to one track.
///
/// Returns an error when the track is missing; non-audio or unresolved clips are omitted.
pub fn get_audio_waveform_for_clip_only_in_specific_track<C, U, M>(
    ctx: &DawContext,
    track_id: &TrackId,
    mapper: M,
) -> Option<C>
where
    M: Fn(&AudioSourceId, &AudioWaveform) -> U,
    C: FromIterator<U>,
{
    let app = &ctx.app_state;
    let track = app.tracks.get(*track_id)?;

    let TrackType::Audio = track.track_type else {
        return Some(empty().collect()); // Return empty since it is not a audio track
    };

    let return_map = track
        .clips()
        .iter()
        .filter_map(|clip_id| {
            let c = app.clips_pool.get(*clip_id)?;
            // Get source Id from clip
            let Some(DawSource::Audio(id)) = c.source else {
                return None;
            };

            let audio_waveform = app.get_audio_source(&id)?;
            Some(mapper(&id, &audio_waveform))
        })
        .collect();

    Some(return_map)
}

/// Collects mapped waveform data for every resolvable audio clip across all tracks.
pub fn get_audio_waveform_for_clip_all_available_in_tracks<C, U, M>(
    ctx: &DawContext,
    mapper: M,
) -> anyhow::Result<C>
where
    M: Fn(u64, &AudioWaveform) -> U,
    C: FromIterator<U>,
{
    let app = &ctx.app_state;
    let mut processed = HashSet::new();

    let return_col = app
        .tracks
        .values()
        .filter(|t| matches!(t.track_type, TrackType::Audio))
        .flat_map(|t| t.clips().iter())
        .filter_map(|clip_id| {
            let clip = app.clips_pool.get(*clip_id)?;
            if let Some(DawSource::Audio(id)) = clip.source {
                let handle = id.to_u64();
                if processed.insert(handle) {
                    // Prevents duplicate IDs natively
                    if let Some(audio_source) = app.get_audio_source(&id) {
                        return Some(mapper(handle, audio_source.as_ref()));
                    }
                }
            }
            None
        })
        .collect::<C>();

    Ok(return_col)
}

/// Maps every imported audio source in the project into a caller-selected collection.
pub fn get_audio_source_list<C, U, M>(ctx: &DawContext, mapper: M) -> anyhow::Result<C>
where
    M: Fn(u64, &AudioWaveform) -> U,
    C: FromIterator<U>,
{
    let app = &ctx.app_state;
    Ok(app
        .asset_library
        .source_map
        .iter()
        .map(|(id, wf)| mapper(id.to_u64(), wf.as_ref()))
        .collect())
}

/// Imports an audio file at the project's sample rate and stores it in the source pool.
///
/// The returned identifier can be referenced by audio clips and preview APIs.
pub fn add_audio_source(ctx: &mut DawContext, file_path: &str) -> anyhow::Result<AudioSourceId> {
    let pending = begin_audio_import(ctx, file_path)?;
    let completed = execute_audio_import(pending)?;
    Ok(commit_audio_import(ctx, completed))
}

/// Audio import captured from the project; decode it with [`execute_audio_import`].
pub struct PendingAudioImport {
    file_path: String,
    normalized_path: PathBuf,
    /// Sources present when the import began, with their stored paths.
    existing: Vec<(AudioSourceId, PathBuf)>,
}

/// Decoded audio import; add it with [`commit_audio_import`].
pub enum CompletedAudioImport {
    /// The file is already a project source.
    Existing(AudioSourceId),
    /// Newly decoded audio.
    Decoded {
        waveform: AudioWaveform,
        normalized_path: PathBuf,
        known: HashSet<AudioSourceId>,
    },
}

/// Resolves the file and snapshots the existing sources. Only needs a short read of the project.
pub fn begin_audio_import(ctx: &DawContext, file_path: &str) -> anyhow::Result<PendingAudioImport> {
    let normalized_path = canonicalize(file_path)
        .with_context(|| format!("Failed to resolve audio file path: {file_path}"))?;
    Ok(PendingAudioImport {
        file_path: file_path.to_owned(),
        normalized_path,
        existing: ctx
            .app_state
            .asset_library
            .source_map
            .iter()
            .map(|(id, waveform)| (id, waveform.file_path.clone()))
            .collect(),
    })
}

/// Decodes the file unless it is already a source. Holds no project lock.
pub fn execute_audio_import(pending: PendingAudioImport) -> anyhow::Result<CompletedAudioImport> {
    let duplicate = pending.existing.iter().find_map(|(source_id, path)| {
        canonicalize(path)
            .ok()
            .filter(|existing_path| existing_path == &pending.normalized_path)
            .map(|_| *source_id)
    });
    if let Some(source_id) = duplicate {
        return Ok(CompletedAudioImport::Existing(source_id));
    }

    let waveform = load_audio_file(&pending.file_path, None).map_err(|e| {
        tracing::error!("[error] failed to load the audio: {}", e);
        anyhow::anyhow!("Failed to load the audio source")
    })?;
    Ok(CompletedAudioImport::Decoded {
        waveform,
        normalized_path: pending.normalized_path,
        known: pending.existing.into_iter().map(|(id, _)| id).collect(),
    })
}

/// Adds decoded audio to the project, or returns the source that imported the same file while
/// it was decoding.
pub fn commit_audio_import(ctx: &mut DawContext, completed: CompletedAudioImport) -> AudioSourceId {
    let (mut waveform, normalized_path, known) = match completed {
        CompletedAudioImport::Existing(source_id) => return source_id,
        CompletedAudioImport::Decoded {
            waveform,
            normalized_path,
            known,
        } => (waveform, normalized_path, known),
    };
    let raced = ctx
        .app_state
        .asset_library
        .source_map
        .iter()
        .filter(|(source_id, _)| !known.contains(source_id))
        .find_map(|(source_id, existing)| {
            canonicalize(&existing.file_path)
                .ok()
                .filter(|existing_path| existing_path == &normalized_path)
                .map(|_| source_id)
        });
    if let Some(source_id) = raced {
        return source_id;
    }

    let source_id = ctx
        .app_state
        .asset_library
        .source_map
        .insert_with_key(|id| {
            waveform.id = Some(id);
            Arc::new(waveform)
        });
    tracing::info!("Successfully added audio source {}", source_id.to_u64());
    ctx.mark_project_modified();
    ctx.broadcast_full_graph();
    source_id
}

/// Decodes an audio file to replace a source with [`replace_audio_source`]. Holds no project
/// lock.
pub fn decode_replacement_audio(file_path: &str) -> anyhow::Result<AudioWaveform> {
    load_audio_file(file_path, None).map_err(|error| {
        tracing::error!("Failed to load the replacement audio: {error}");
        anyhow::anyhow!("Failed to load the audio source")
    })
}

/// Swaps a source's audio for `decoded`, as one undoable step. Returns whether it needs a
/// render.
///
/// The clips that play the source keep their place, and the source keeps its playback
/// settings and edits; envelope times stay the same. Trim points and detected beats describe
/// the old audio, so the new audio plays whole, and a tempo-following source anchors to the
/// project tempo as when entering its mode.
pub fn replace_audio_source(
    ctx: &mut DawContext,
    source_id: AudioSourceId,
    decoded: AudioWaveform,
) -> anyhow::Result<bool> {
    let project_bpm = ctx.app_state.transport.bpm;
    let entry = ctx
        .app_state
        .asset_library
        .source_map
        .get_mut(source_id)
        .context("Cannot find audio source")?;
    let previous = Arc::clone(entry);
    let mut envelope_source = AudioWaveform {
        envelope: previous.envelope.clone(),
        ..AudioWaveform::default()
    };
    envelope_source.rescale_frames(previous.sample_rate, decoded.sample_rate);
    let edits = previous
        .edited
        .as_ref()
        .map(|edited| WaveformEdits {
            time_ratio: 1.0,
            warp: false,
            ..edited.edits.clone()
        })
        .filter(|edits| *edits != WaveformEdits::default());
    *entry = Arc::new(AudioWaveform {
        id: Some(source_id),
        root_note: previous.root_note,
        fine_tune: previous.fine_tune,
        is_looping: previous.is_looping,
        muted: previous.muted,
        sample_mode: previous.sample_mode,
        original_bpm: match previous.sample_mode {
            AudioSampleMode::Default => None,
            AudioSampleMode::Stretch | AudioSampleMode::Resampled => {
                Some(project_bpm).filter(|bpm| *bpm > 0.0)
            }
        },
        envelope: envelope_source.envelope,
        edited: edits.map(|edits| EditedWaveform {
            edits,
            ..EditedWaveform::default()
        }),
        beat_grid: None,
        ..decoded
    });
    ctx.push_history(SourceReplaced::new(source_id, previous));
    ctx.broadcast_audio_source(source_id);
    tracing::info!("Replaced the audio of source {}", source_id.to_u64());
    Ok(begin_refresh_render(ctx, source_id)?.is_some())
}

/// Deletes an audio source and every clip that plays it as one undoable step.
///
/// Returns how many clips were deleted with it. Previews are stopped so the deleted audio does
/// not keep sounding, and the engine receives a full graph because that is the only update that
/// drops a source.
pub fn remove_audio_source(
    ctx: &mut DawContext,
    source_id: AudioSourceId,
) -> anyhow::Result<usize> {
    let clips = ctx.app_state.audio_source_clips(source_id);
    let tracks: Vec<TrackId> = clips.iter().map(|(track_id, _)| *track_id).collect();
    let clip_ids: Vec<ClipId> = clips.iter().map(|(_, clip_id)| *clip_id).collect();

    let recorder =
        ClipEditRecorder::begin(&ctx.app_state, "Delete Audio Source", &tracks, &clip_ids);
    let waveform = ctx.app_state.remove_audio_source(source_id)?;
    let clip_changes = recorder.finish(&mut ctx.app_state);
    ctx.push_history(AudioSourceRemoved::new(clip_changes, source_id, waveform));

    stop_all_previews(ctx);
    ctx.broadcast_full_graph();
    tracing::info!(
        "Removed audio source {} with {} clip(s)",
        source_id.to_u64(),
        clip_ids.len()
    );
    Ok(clip_ids.len())
}

/// Resolves an opaque source handle, validates it, and maps the corresponding waveform.
pub fn get_audio_waveform<T, F>(ctx: &DawContext, source_id: u64, mapper: F) -> anyhow::Result<T>
where
    F: Fn(&AudioWaveform) -> T,
{
    let app = &ctx.app_state;
    let waveform = app
        .get_audio_source(&AudioSourceId::from_u64(source_id))
        .ok_or_else(|| anyhow::anyhow!("Cannot find audio source"))?;
    Ok(mapper(waveform.as_ref()))
}

/// Maps every audio source's waveform envelope into a caller-selected collection.
pub fn get_audio_source_envelopes<C, U, M>(ctx: &DawContext, mapper: M) -> C
where
    M: Fn(u64, &GainEnvelope) -> U,
    C: FromIterator<U>,
{
    ctx.app_state
        .asset_library
        .source_map
        .iter()
        .map(|(id, waveform)| mapper(id.to_u64(), &waveform.envelope))
        .collect()
}

/// Replaces an audio source's waveform envelope as one reversible operation and republishes only
/// that source to the audio engine. Returns the stored (normalized) envelope.
pub fn set_audio_source_envelope(
    ctx: &mut DawContext,
    source_id: AudioSourceId,
    envelope: GainEnvelope,
) -> anyhow::Result<GainEnvelope> {
    let previous = ctx
        .app_state
        .set_audio_source_envelope(source_id, envelope)?;
    ctx.push_history(SourceEnvelopeChanged::new(source_id, previous));
    ctx.broadcast_audio_source(source_id);

    let stored = ctx
        .app_state
        .get_audio_source(&source_id)
        .map(|waveform| waveform.envelope.clone())
        .unwrap_or_default();
    Ok(stored)
}

/// Sets the part of an audio source that plays, in frames of the original audio, as one
/// reversible operation and republishes only that source to the audio engine. A `trim_end` of
/// zero plays to the end.
pub fn set_audio_source_trim(
    ctx: &mut DawContext,
    source_id: AudioSourceId,
    trim_start: u32,
    trim_end: u32,
) -> anyhow::Result<()> {
    let unchanged = ctx
        .app_state
        .get_audio_source(&source_id)
        .is_some_and(|waveform| waveform.trim_start == trim_start && waveform.trim_end == trim_end);
    if unchanged {
        return Ok(());
    }
    let previous = ctx
        .app_state
        .set_audio_source_trim(source_id, trim_start, trim_end)?;
    ctx.push_history(SourceTrimChanged::new(source_id, previous));
    ctx.broadcast_audio_source(source_id);
    Ok(())
}
