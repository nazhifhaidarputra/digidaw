use std::any::Any;

use slotmap::SlotMap;

use crate::{
    core::{
        history::{EngineSync, HistoryAction, HistoryError},
        project::{ApplicationState, CueMarker, LoopRegion, ProjectMetadata},
    },
    shared::id::CueMarkerId,
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

/// The song loop region changed; holds the region on the other side of the edit.
///
/// Dragging a loop edge records a change per step. Changes recorded within the history merge
/// window fold into one entry that restores the region from before the drag.
#[derive(Debug)]
pub struct LoopRegionChanged {
    region: Option<LoopRegion>,
}

impl LoopRegionChanged {
    /// Records a change from the previous region.
    pub fn new(previous: Option<LoopRegion>) -> Self {
        Self { region: previous }
    }

    fn swap(&mut self, app: &mut ApplicationState) -> Result<EngineSync, HistoryError> {
        std::mem::swap(&mut app.timeline.loop_region, &mut self.region);
        Ok(EngineSync::loop_region())
    }
}

impl HistoryAction for LoopRegionChanged {
    fn undo(&mut self, app: &mut ApplicationState) -> Result<EngineSync, HistoryError> {
        self.swap(app)
    }

    fn redo(&mut self, app: &mut ApplicationState) -> Result<EngineSync, HistoryError> {
        self.swap(app)
    }

    fn label(&self) -> &'static str {
        "Change Loop Region"
    }

    fn merge(&mut self, next: &mut dyn Any) -> bool {
        // Keep this entry's original region; the project already holds the newest one.
        next.downcast_mut::<Self>().is_some()
    }
}

/// Cue markers edited; holds every marker on the other side of the edit.
///
/// Consecutive moves of the same marker within the history merge window fold into one entry.
#[derive(Debug)]
pub struct CueMarkersChanged {
    markers: SlotMap<CueMarkerId, CueMarker>,
    label: &'static str,
    moved: Option<CueMarkerId>,
}

impl CueMarkersChanged {
    /// Records an edit from the previous markers.
    pub fn new(previous: SlotMap<CueMarkerId, CueMarker>, label: &'static str) -> Self {
        Self {
            markers: previous,
            label,
            moved: None,
        }
    }

    /// Records a move of one marker, which merges with further moves of the same marker.
    pub fn moved(previous: SlotMap<CueMarkerId, CueMarker>, marker: CueMarkerId) -> Self {
        Self {
            markers: previous,
            label: "Move Cue Marker",
            moved: Some(marker),
        }
    }

    fn swap(&mut self, app: &mut ApplicationState) -> Result<EngineSync, HistoryError> {
        std::mem::swap(&mut app.timeline.markers, &mut self.markers);
        Ok(EngineSync::none())
    }
}

impl HistoryAction for CueMarkersChanged {
    fn undo(&mut self, app: &mut ApplicationState) -> Result<EngineSync, HistoryError> {
        self.swap(app)
    }

    fn redo(&mut self, app: &mut ApplicationState) -> Result<EngineSync, HistoryError> {
        self.swap(app)
    }

    fn label(&self) -> &'static str {
        self.label
    }

    fn merge(&mut self, next: &mut dyn Any) -> bool {
        next.downcast_mut::<Self>()
            .is_some_and(|next| self.moved.is_some() && self.moved == next.moved)
    }
}
