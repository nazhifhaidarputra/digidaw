use std::sync::Arc;

use crate::core::{
    history::{EngineSync, HistoryAction, HistoryError},
    project::{
        ApplicationState, GainEnvelope,
        track::audio_waveform::{AudioSampleMode, BeatGrid, EditedWaveform},
    },
};
use crate::shared::id::AudioSourceId;

/// An audio source's waveform envelope replaced; holds the envelope on the other side of the edit.
#[derive(Debug)]
pub struct SourceEnvelopeChanged {
    source_id: AudioSourceId,
    envelope: GainEnvelope,
}

impl SourceEnvelopeChanged {
    /// Records an edit from the source's previous envelope.
    pub fn new(source_id: AudioSourceId, previous: GainEnvelope) -> Self {
        Self {
            source_id,
            envelope: previous,
        }
    }

    fn swap(&mut self, app: &mut ApplicationState) -> Result<EngineSync, HistoryError> {
        let entry = app
            .asset_library
            .source_map
            .get_mut(self.source_id)
            .ok_or(HistoryError::missing("Audio source"))?;
        std::mem::swap(&mut Arc::make_mut(entry).envelope, &mut self.envelope);
        Ok(EngineSync::source(self.source_id))
    }
}

swap_action!(SourceEnvelopeChanged, "Edit Waveform Envelope");

/// Tempo-related state of an audio source: detected beats, tempo, sample mode and render.
#[derive(Debug, Clone)]
pub struct SourceTempo {
    pub original_bpm: Option<f32>,
    pub sample_mode: AudioSampleMode,
    pub beat_grid: Option<BeatGrid>,
    /// Includes the rendered buffer, so undo restores it without rendering again.
    pub edited: Option<EditedWaveform>,
}

/// An audio source's tempo analysis or tempo fit changed; holds the state on the other side
/// of the edit.
#[derive(Debug)]
pub struct SourceTempoChanged {
    source_id: AudioSourceId,
    tempo: SourceTempo,
    label: &'static str,
}

impl SourceTempoChanged {
    /// Records an edit from the source's previous tempo state.
    pub fn new(source_id: AudioSourceId, previous: SourceTempo, label: &'static str) -> Self {
        Self {
            source_id,
            tempo: previous,
            label,
        }
    }

    fn swap(&mut self, app: &mut ApplicationState) -> Result<EngineSync, HistoryError> {
        let entry = app
            .asset_library
            .source_map
            .get_mut(self.source_id)
            .ok_or(HistoryError::missing("Audio source"))?;
        let waveform = Arc::make_mut(entry);
        std::mem::swap(&mut waveform.original_bpm, &mut self.tempo.original_bpm);
        std::mem::swap(&mut waveform.sample_mode, &mut self.tempo.sample_mode);
        std::mem::swap(&mut waveform.beat_grid, &mut self.tempo.beat_grid);
        std::mem::swap(&mut waveform.edited, &mut self.tempo.edited);
        Ok(EngineSync::source(self.source_id))
    }
}

swap_action!(SourceTempoChanged, field label);
