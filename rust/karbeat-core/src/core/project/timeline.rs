//! Song timeline annotations: the loop region and cue markers.

use karbeat_utils::color::Color;
use serde::{Deserialize, Serialize};
use slotmap::SlotMap;
use thiserror::Error;

use crate::shared::id::CueMarkerId;

/// Rejected timeline edit.
#[derive(Debug, Error, PartialEq, Eq)]
pub enum TimelineError {
    /// The loop region would not span any time.
    #[error("Loop region must end after it starts")]
    EmptyLoopRegion,
    /// No cue marker has this ID.
    #[error("Cue marker not found")]
    MarkerNotFound,
    /// The trimmed marker name is empty.
    #[error("Cue marker name cannot be empty")]
    EmptyMarkerName,
}

/// Song range that playback repeats while looping is on. It is also the time selection that
/// region export and bounce render.
#[derive(Serialize, Deserialize, Clone, Copy, Debug, PartialEq, Eq)]
pub struct LoopRegion {
    /// First tick inside the region.
    pub start_tick: u64,
    /// First tick after the region; always greater than `start_tick`.
    pub end_tick: u64,
}

impl LoopRegion {
    /// Creates a region spanning `start_tick..end_tick`.
    pub fn new(start_tick: u64, end_tick: u64) -> Result<Self, TimelineError> {
        if end_tick <= start_tick {
            return Err(TimelineError::EmptyLoopRegion);
        }
        Ok(Self {
            start_tick,
            end_tick,
        })
    }

    /// Region as `(start_tick, end_tick)`, the shape engine commands use.
    pub fn as_ticks(self) -> (u64, u64) {
        (self.start_tick, self.end_tick)
    }

    /// Length of the region in ticks.
    pub fn length_ticks(self) -> u64 {
        self.end_tick.saturating_sub(self.start_tick)
    }
}

/// Named position on the song timeline.
#[derive(Serialize, Deserialize, Clone, Debug, PartialEq)]
#[serde(default)]
pub struct CueMarker {
    /// Label shown on the ruler.
    pub name: String,
    /// Position on the timeline.
    pub tick: u64,
    /// Flag color on the ruler.
    pub color: Color,
}

impl Default for CueMarker {
    fn default() -> Self {
        Self {
            name: "Marker".into(),
            tick: 0,
            color: Color::new_from_rgb(255, 179, 0),
        }
    }
}

/// Persisted song timeline annotations.
#[derive(Serialize, Deserialize, Clone, Debug, Default)]
#[serde(default)]
pub struct TimelineState {
    /// Loop region, or `None` when none has been set.
    pub loop_region: Option<LoopRegion>,
    /// Cue markers keyed by stable IDs, in no particular order.
    pub markers: SlotMap<CueMarkerId, CueMarker>,
}

impl TimelineState {
    /// Adds a marker and returns its ID.
    pub fn add_marker(&mut self, marker: CueMarker) -> Result<CueMarkerId, TimelineError> {
        let marker = validated(marker)?;
        Ok(self.markers.insert(marker))
    }

    /// Replaces a marker's name, position, and color.
    pub fn update_marker(
        &mut self,
        id: CueMarkerId,
        marker: CueMarker,
    ) -> Result<(), TimelineError> {
        let marker = validated(marker)?;
        let slot = self
            .markers
            .get_mut(id)
            .ok_or(TimelineError::MarkerNotFound)?;
        *slot = marker;
        Ok(())
    }

    /// Removes a marker.
    pub fn remove_marker(&mut self, id: CueMarkerId) -> Result<CueMarker, TimelineError> {
        self.markers.remove(id).ok_or(TimelineError::MarkerNotFound)
    }

    /// Markers ordered by position, then by name.
    pub fn markers_by_tick(&self) -> Vec<(CueMarkerId, &CueMarker)> {
        let mut markers: Vec<_> = self.markers.iter().collect();
        markers.sort_by(|(_, a), (_, b)| a.tick.cmp(&b.tick).then_with(|| a.name.cmp(&b.name)));
        markers
    }
}

fn validated(mut marker: CueMarker) -> Result<CueMarker, TimelineError> {
    let trimmed = marker.name.trim();
    if trimmed.is_empty() {
        return Err(TimelineError::EmptyMarkerName);
    }
    if trimmed.len() != marker.name.len() {
        marker.name = trimmed.to_string();
    }
    Ok(marker)
}

#[cfg(test)]
#[allow(
    clippy::unwrap_used,
    clippy::indexing_slicing,
    reason = "fixture edits and keys are valid and should fail the test immediately otherwise"
)]
mod tests {
    use super::*;

    fn marker(name: &str, tick: u64) -> CueMarker {
        CueMarker {
            name: name.into(),
            tick,
            ..CueMarker::default()
        }
    }

    #[test]
    fn loop_region_must_span_time() {
        assert_eq!(LoopRegion::new(10, 10), Err(TimelineError::EmptyLoopRegion));
        assert_eq!(LoopRegion::new(10, 5), Err(TimelineError::EmptyLoopRegion));
        assert_eq!(LoopRegion::new(0, 960).unwrap().length_ticks(), 960);
    }

    #[test]
    fn markers_are_validated_and_sorted() {
        let mut timeline = TimelineState::default();
        assert_eq!(
            timeline.add_marker(marker("   ", 0)),
            Err(TimelineError::EmptyMarkerName)
        );
        let chorus = timeline.add_marker(marker(" Chorus ", 3840)).unwrap();
        let intro = timeline.add_marker(marker("Intro", 0)).unwrap();
        assert_eq!(timeline.markers[chorus].name, "Chorus");

        let order: Vec<_> = timeline
            .markers_by_tick()
            .iter()
            .map(|(id, _)| *id)
            .collect();
        assert_eq!(order, [intro, chorus]);

        timeline
            .update_marker(chorus, marker("Drop", 1920))
            .unwrap();
        assert_eq!(timeline.markers[chorus].tick, 1920);
        timeline.remove_marker(intro).unwrap();
        assert_eq!(
            timeline.remove_marker(intro),
            Err(TimelineError::MarkerNotFound)
        );
    }

    #[test]
    fn timeline_round_trips_through_json_and_defaults_when_missing() {
        let mut timeline = TimelineState {
            loop_region: Some(LoopRegion::new(960, 7680).unwrap()),
            ..TimelineState::default()
        };
        let id = timeline.add_marker(marker("Verse", 960)).unwrap();

        let json = serde_json::to_string(&timeline).unwrap();
        let restored: TimelineState = serde_json::from_str(&json).unwrap();
        assert_eq!(restored.loop_region, timeline.loop_region);
        assert_eq!(restored.markers[id], timeline.markers[id]);

        let empty: TimelineState = serde_json::from_str("{}").unwrap();
        assert!(empty.loop_region.is_none() && empty.markers.is_empty());
    }
}
