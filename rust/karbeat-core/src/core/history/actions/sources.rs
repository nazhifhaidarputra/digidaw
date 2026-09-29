use std::sync::Arc;

use crate::core::{
    history::{EngineSync, HistoryAction, HistoryError},
    project::{ApplicationState, GainEnvelope},
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
