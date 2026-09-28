use std::any::Any;

use crate::core::{
    history::{EngineSync, HistoryAction, HistoryError},
    project::{ApplicationState, ProjectMetadata},
};

/// The project tempo changed; holds the tempo on the other side of the edit.
///
/// Dragging the tempo control records a change per step. Changes recorded within the history
/// merge window fold into one entry that restores the tempo from before the drag.
#[derive(Debug)]
pub struct TempoChanged {
    bpm: f32,
}

impl TempoChanged {
    /// Records a change from the previous tempo.
    pub fn new(previous_bpm: f32) -> Self {
        Self { bpm: previous_bpm }
    }

    fn swap(&mut self, app: &mut ApplicationState) -> Result<EngineSync, HistoryError> {
        std::mem::swap(&mut app.transport.bpm, &mut self.bpm);
        Ok(EngineSync::tempo())
    }
}

impl HistoryAction for TempoChanged {
    fn undo(&mut self, app: &mut ApplicationState) -> Result<EngineSync, HistoryError> {
        self.swap(app)
    }

    fn redo(&mut self, app: &mut ApplicationState) -> Result<EngineSync, HistoryError> {
        self.swap(app)
    }

    fn label(&self) -> &'static str {
        "Change Tempo"
    }

    fn merge(&mut self, next: &mut dyn Any) -> bool {
        // Keep this entry's original tempo; the project already holds the newest one.
        next.downcast_mut::<Self>().is_some()
    }
}

/// Project metadata edited; holds the metadata on the other side of the edit.
#[derive(Debug)]
pub struct MetadataChanged {
    metadata: Box<ProjectMetadata>,
}

impl MetadataChanged {
    /// Records an edit from the previous metadata.
    pub fn new(previous: ProjectMetadata) -> Self {
        Self {
            metadata: Box::new(previous),
        }
    }

    fn swap(&mut self, app: &mut ApplicationState) -> Result<EngineSync, HistoryError> {
        std::mem::swap(&mut app.metadata, &mut *self.metadata);
        Ok(EngineSync::none())
    }
}

swap_action!(MetadataChanged, "Edit Project Information");
