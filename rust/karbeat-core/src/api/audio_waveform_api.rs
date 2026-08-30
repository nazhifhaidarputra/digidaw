use std::{collections::HashSet, sync::Arc};

use anyhow::Context;

use crate::{
    context::DawContext,
    core::{
        file_manager::audio_loader::AudioLoader,
        project::{AudioSourceId, AudioWaveform, DawSource, TrackId, TrackType},
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

pub fn get_audio_waveform_for_clip_all_available_in_tracks<C, U, M>(
    ctx: &DawContext,
    mapper: M,
) -> anyhow::Result<C>
where
    M: Fn(u32, &AudioWaveform) -> U,
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
                let id_u32 = id.to_u32();
                if processed.insert(id_u32) {
                    // Prevents duplicate IDs natively
                    if let Some(audio_source) = app.get_audio_source(&id) {
                        return Some(mapper(id_u32, audio_source.as_ref()));
                    }
                }
            }
            None
        })
        .collect::<C>();

    Ok(return_col)
}

pub fn get_audio_source_list<C, U, M>(ctx: &DawContext, mapper: M) -> anyhow::Result<C>
where
    M: Fn(u32, &AudioWaveform) -> U,
    C: FromIterator<U>,
{
    let app = &ctx.app_state;
    Ok(app
        .asset_library
        .source_map
        .iter()
        .map(|(id, wf)| mapper(id.to_u32(), wf.as_ref()))
        .collect())
}

pub fn add_audio_source(ctx: &mut DawContext, file_path: &str) -> anyhow::Result<AudioSourceId> {
    let normalized_path = std::fs::canonicalize(file_path)
        .with_context(|| format!("Failed to resolve audio file path: {file_path}"))?;
    if let Some(source_id) =
        ctx.app_state
            .asset_library
            .source_map
            .iter()
            .find_map(|(source_id, waveform)| {
                std::fs::canonicalize(&waveform.file_path)
                    .ok()
                    .filter(|existing_path| existing_path == &normalized_path)
                    .map(|_| source_id)
            })
    {
        return Ok(source_id);
    }

    let sample_rate = ctx.audio_runtime_settings.read().requested_dsp.sample_rate;

    let result = ctx.app_state.load_audio(file_path, None, sample_rate);
    let id = match result {
        Ok(source_id) => {
            log::info!("Successfully added audio source {}", source_id.to_u32());
            source_id
        }
        Err(e) => {
            log::error!("[error] failed to load the audio: {}", e);
            return Err(anyhow::anyhow!("Failed to load the audio source"));
        }
    };
    ctx.broadcast_full_graph();
    Ok(id)
}

pub fn get_audio_waveform<T, F>(ctx: &DawContext, source_id: u32, mapper: F) -> anyhow::Result<T>
where
    F: Fn(&AudioWaveform) -> T,
{
    let app = &ctx.app_state;
    let waveform = app
        .get_audio_source(&AudioSourceId::from(source_id))
        .ok_or_else(|| anyhow::anyhow!("Cannot find audio source"))?;
    Ok(mapper(waveform.as_ref()))
}
