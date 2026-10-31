use std::sync::Arc;

use crate::core::{
    history::{EngineSync, HistoryAction, HistoryError},
    project::{
        ApplicationState, ClipTiming, GainEnvelope,
        track::audio_waveform::{AudioSampleMode, BeatGrid, EditedWaveform, SourceTrim},
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

/// An audio source's trim points changed; holds the trim on the other side of the edit.
#[derive(Debug)]
pub struct SourceTrimChanged {
    source_id: AudioSourceId,
    trim: SourceTrim,
}

impl SourceTrimChanged {
    /// Records an edit from the source's previous trim.
    pub fn new(source_id: AudioSourceId, previous: SourceTrim) -> Self {
        Self {
            source_id,
            trim: previous,
        }
    }

    fn swap(&mut self, app: &mut ApplicationState) -> Result<EngineSync, HistoryError> {
        let entry = app
            .asset_library
            .source_map
            .get_mut(self.source_id)
            .ok_or(HistoryError::missing("Audio source"))?;
        let waveform = Arc::make_mut(entry);
        std::mem::swap(&mut waveform.trim_start, &mut self.trim.trim_start);
        std::mem::swap(&mut waveform.trim_end, &mut self.trim.trim_end);
        std::mem::swap(&mut waveform.envelope, &mut self.trim.envelope);
        Ok(EngineSync::source(self.source_id))
    }
}

swap_action!(SourceTrimChanged, "Trim Audio");

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
    /// Clips rescaled to follow the source's new playback length.
    clips: Vec<ClipTiming>,
}

impl SourceTempoChanged {
    /// Records an edit from the source's previous tempo state.
    pub fn new(source_id: AudioSourceId, previous: SourceTempo, label: &'static str) -> Self {
        Self {
            source_id,
            tempo: previous,
            label,
            clips: Vec::new(),
        }
    }

    /// Also restores `clips`, rescaled by the edit to follow the source's playback length.
    #[must_use]
    pub fn with_clips(mut self, clips: Vec<ClipTiming>) -> Self {
        self.clips = clips;
        self
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
        let sync = EngineSync::source(self.source_id);
        if self.clips.is_empty() {
            return Ok(sync);
        }
        app.swap_clip_timings(&mut self.clips);
        Ok(sync.and(EngineSync::track_graph()))
    }
}

swap_action!(SourceTempoChanged, field label);
