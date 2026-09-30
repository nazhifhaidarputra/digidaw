use std::{collections::HashSet, path::PathBuf, sync::Arc};

use anyhow::Context;

use karbeat_core::{
    context::DawContext,
    core::{
        file_manager::audio_loader::{AudioLoader, load_audio_file},
        history::actions::SourceEnvelopeChanged,
        project::{AudioSourceId, AudioWaveform, DawSource, GainEnvelope, TrackId, TrackType},
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
        return Some(std::iter::empty().collect()); // Return empty since it is not a audio track
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
    sample_rate: u32,
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
    let normalized_path = std::fs::canonicalize(file_path)
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
        sample_rate: ctx.audio_runtime_settings.read().requested_dsp.sample_rate,
    })
}

/// Decodes the file unless it is already a source. Holds no project lock.
pub fn execute_audio_import(pending: PendingAudioImport) -> anyhow::Result<CompletedAudioImport> {
    let duplicate = pending.existing.iter().find_map(|(source_id, path)| {
        std::fs::canonicalize(path)
            .ok()
            .filter(|existing_path| existing_path == &pending.normalized_path)
            .map(|_| *source_id)
    });
    if let Some(source_id) = duplicate {
        return Ok(CompletedAudioImport::Existing(source_id));
    }

    let waveform = load_audio_file(&pending.file_path, None, pending.sample_rate).map_err(|e| {
        log::error!("[error] failed to load the audio: {}", e);
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
            std::fs::canonicalize(&existing.file_path)
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
    log::info!("Successfully added audio source {}", source_id.to_u64());
    ctx.mark_project_modified();
    ctx.broadcast_full_graph();
    source_id
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
