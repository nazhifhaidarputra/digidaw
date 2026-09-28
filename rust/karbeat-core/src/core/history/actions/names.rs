use karbeat_utils::color::Color;

use crate::core::{
    history::{EngineSync, HistoryAction, HistoryError},
    project::{ApplicationState, AudioTrack, mixer::BusMixerChannel},
};
use crate::shared::id::{BusId, ClipId, PatternId, TrackId};

fn track_mut(app: &mut ApplicationState, id: TrackId) -> Result<&mut AudioTrack, HistoryError> {
    app.tracks.get_mut(id).ok_or(HistoryError::missing("Track"))
}

fn bus_mut(app: &mut ApplicationState, id: BusId) -> Result<&mut BusMixerChannel, HistoryError> {
    app.mixer
        .buses
        .get_mut(id)
        .ok_or(HistoryError::missing("Bus"))
}

/// A track renamed; holds the name on the other side of the edit.
#[derive(Debug)]
pub struct TrackRenamed {
    track_id: TrackId,
    name: String,
}

impl TrackRenamed {
    /// Records a rename from the track's previous name.
    pub fn new(track_id: TrackId, previous_name: String) -> Self {
        Self {
            track_id,
            name: previous_name,
        }
    }

    fn swap(&mut self, app: &mut ApplicationState) -> Result<EngineSync, HistoryError> {
        std::mem::swap(&mut track_mut(app, self.track_id)?.name, &mut self.name);
        Ok(EngineSync::none())
    }
}

swap_action!(TrackRenamed, "Rename Track");

/// A track recolored; holds the color on the other side of the edit.
#[derive(Debug)]
pub struct TrackRecolored {
    track_id: TrackId,
    color: Color,
}

impl TrackRecolored {
    /// Records a color change from the track's previous color.
    pub fn new(track_id: TrackId, previous_color: Color) -> Self {
        Self {
            track_id,
            color: previous_color,
        }
    }

    fn swap(&mut self, app: &mut ApplicationState) -> Result<EngineSync, HistoryError> {
        std::mem::swap(&mut track_mut(app, self.track_id)?.color, &mut self.color);
        Ok(EngineSync::none())
    }
}

swap_action!(TrackRecolored, "Change Track Color");

/// Tracks reordered. Moving one track renumbers the others, so every track's order is held.
#[derive(Debug)]
pub struct TracksReordered {
    orders: Box<[(TrackId, usize)]>,
}

impl TracksReordered {
    /// Snapshots every track's order before the edit.
    pub fn capture(app: &ApplicationState) -> Self {
        Self {
            orders: app
                .tracks
                .iter()
                .map(|(id, track)| (id, track.order_idx))
                .collect(),
        }
    }

    fn swap(&mut self, app: &mut ApplicationState) -> Result<EngineSync, HistoryError> {
        for (id, order) in &mut self.orders {
            std::mem::swap(&mut track_mut(app, *id)?.order_idx, order);
        }
        Ok(EngineSync::track_graph())
    }
}

swap_action!(TracksReordered, "Reorder Tracks");

/// A pattern renamed, together with the clips whose names followed it.
#[derive(Debug)]
pub struct PatternRenamed {
    pattern_id: PatternId,
    name: String,
    clip_names: Box<[(ClipId, String)]>,
}

impl PatternRenamed {
    /// Records a rename from the pattern's previous name and the previous names of the clips the
    /// rename changed.
    pub fn new(
        pattern_id: PatternId,
        previous_name: String,
        previous_clip_names: Vec<(ClipId, String)>,
    ) -> Self {
        Self {
            pattern_id,
            name: previous_name,
            clip_names: previous_clip_names.into_boxed_slice(),
        }
    }

    fn swap(&mut self, app: &mut ApplicationState) -> Result<EngineSync, HistoryError> {
        let pattern = app
            .pattern_pool
            .get_mut(self.pattern_id)
            .ok_or(HistoryError::missing("Pattern"))?;
        std::mem::swap(&mut pattern.name, &mut self.name);
        for (clip_id, name) in &mut self.clip_names {
            let clip = app
                .clips_pool
                .get_mut(*clip_id)
                .ok_or(HistoryError::missing("Clip"))?;
            std::mem::swap(&mut clip.name, name);
        }
        Ok(EngineSync::track_graph())
    }
}

swap_action!(PatternRenamed, "Rename Pattern");

/// A bus renamed; holds the name on the other side of the edit.
#[derive(Debug)]
pub struct BusRenamed {
    bus_id: BusId,
    name: String,
}

impl BusRenamed {
    /// Records a rename from the bus's previous name.
    pub fn new(bus_id: BusId, previous_name: String) -> Self {
        Self {
            bus_id,
            name: previous_name,
        }
    }

    fn swap(&mut self, app: &mut ApplicationState) -> Result<EngineSync, HistoryError> {
        std::mem::swap(&mut bus_mut(app, self.bus_id)?.name, &mut self.name);
        Ok(EngineSync::none())
    }
}

swap_action!(BusRenamed, "Rename Bus");

/// A bus recolored; holds the color on the other side of the edit.
#[derive(Debug)]
pub struct BusRecolored {
    bus_id: BusId,
    color: Color,
}

impl BusRecolored {
    /// Records a color change from the bus's previous color.
    pub fn new(bus_id: BusId, previous_color: Color) -> Self {
        Self {
            bus_id,
            color: previous_color,
        }
    }

    fn swap(&mut self, app: &mut ApplicationState) -> Result<EngineSync, HistoryError> {
        std::mem::swap(&mut bus_mut(app, self.bus_id)?.color, &mut self.color);
        Ok(EngineSync::none())
    }
}

swap_action!(BusRecolored, "Change Bus Color");
