//! Automation regions: clip-like boundaries that group automation points for editing.
//!
//! Points always live in [`AutomationLane::points`], so playback and exports never look at
//! regions. A region only marks the half-open tick span `[start, end)` whose points belong to
//! it: a point dragged into the span joins the region, and one dragged out of it becomes a free
//! point again.
//!
//! Regions that share a `content_id` show one composition. Each of them looks at the composition
//! through a window, and `content_offset` is the composition time at the region's start. A point
//! edit inside a shared region is mirrored into every sibling whose window shows the same
//! composition time, so siblings stay identical wherever their windows overlap.

use std::ops::Range;

use anyhow::anyhow;
use karbeat_utils::types::{BipolarF64, NormalizedF64};
use serde::{Deserialize, Serialize};
use thiserror::Error;

use super::{
    ApplicationState, ResizeEdge,
    automation::{AutomationCurveType, AutomationLane, AutomationPoint, BezierHandles},
};
use crate::shared::id::{AutomationId, AutomationPointId, AutomationRegionId};

/// A named span of an automation lane that groups the points inside it.
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Default)]
#[serde(default)]
pub struct AutomationRegion {
    /// Lane-local stable region identifier.
    pub id: AutomationRegionId,
    /// Name shown on the region.
    pub name: String,
    /// First tick of the region.
    pub start_ticks: u32,
    /// Length in ticks; the region ends just before `start_ticks + length_ticks`.
    pub length_ticks: u32,
    /// Composition shared by every region of the lane with the same identifier.
    pub content_id: u32,
    /// Composition time shown at `start_ticks`.
    pub content_offset: i64,
}

impl AutomationRegion {
    /// First tick after the region.
    #[inline]
    pub fn end_ticks(&self) -> u32 {
        self.start_ticks.saturating_add(self.length_ticks)
    }

    /// Whether `tick` lies inside the region.
    #[inline]
    pub fn contains(&self, tick: u32) -> bool {
        tick >= self.start_ticks && tick < self.end_ticks()
    }

    /// Whether the region shares a tick with the half-open span `[start, end)`.
    #[inline]
    fn overlaps(&self, start: u32, end: u32) -> bool {
        start < self.end_ticks() && self.start_ticks < end
    }

    /// Composition time shown at `tick`.
    #[inline]
    fn content_time(&self, tick: u32) -> i64 {
        i64::from(tick)
            .saturating_sub(i64::from(self.start_ticks))
            .saturating_add(self.content_offset)
    }

    /// Tick that shows `content_time`, or `None` when the region's window doesn't show it.
    #[inline]
    fn tick_for_content(&self, content_time: i64) -> Option<u32> {
        let relative = content_time.checked_sub(self.content_offset)?;
        if relative < 0 || relative >= i64::from(self.length_ticks) {
            return None;
        }
        u32::try_from(i64::from(self.start_ticks).checked_add(relative)?).ok()
    }

    /// Composition times the region shows, as a half-open range.
    #[inline]
    fn content_window(&self) -> Range<i64> {
        self.content_offset
            ..self
                .content_offset
                .saturating_add(i64::from(self.length_ticks))
    }
}

/// Why a region edit was refused.
#[derive(Debug, Error, PartialEq, Eq)]
pub enum AutomationRegionError {
    /// No region of the lane has the identifier.
    #[error("Automation region {0} not found")]
    NotFound(AutomationRegionId),
    /// The edit would make two regions overlap.
    #[error("Automation regions cannot overlap")]
    Overlap,
    /// A region needs at least one tick.
    #[error("An automation region needs a length of at least one tick")]
    Empty,
    /// A slice must cut strictly inside the region.
    #[error("The slice point must be inside the region")]
    SliceOutside,
}

/// A region and its points, detached from a lane for copy and paste.
#[derive(Clone, Debug, PartialEq, Default)]
pub struct AutomationRegionCopy {
    /// Name of the copied region.
    pub name: String,
    /// Start relative to the earliest copied region.
    pub start_ticks: u32,
    /// Length of the copied region.
    pub length_ticks: u32,
    /// Composition of the copied region in its lane.
    pub content_id: u32,
    /// Composition time shown at the region's start.
    pub content_offset: i64,
    /// Points with times relative to the region start.
    pub points: Vec<AutomationPoint>,
}

/// Index after every point before `tick` in a time-ordered slice.
#[inline]
fn first_index_at(points: &[AutomationPoint], tick: u32) -> usize {
    points.partition_point(|p| p.time_ticks < tick)
}

/// Shifts `tick` by `delta`, saturating at the `u32` bounds.
#[inline]
fn shift_tick(tick: u32, delta: i64) -> u32 {
    let shifted = i64::from(tick).saturating_add(delta);
    u32::try_from(shifted.max(0)).unwrap_or(u32::MAX)
}

impl AutomationLane {
    // ------------------------------------------------------------------------
    // Lookup
    // ------------------------------------------------------------------------

    /// Region with the identifier, if any.
    pub fn region(&self, id: AutomationRegionId) -> Option<&AutomationRegion> {
        self.regions.iter().find(|region| region.id == id)
    }

    /// Region containing `tick`, if any.
    pub fn region_at(&self, tick: u32) -> Option<&AutomationRegion> {
        self.region_index_at(tick)
            .and_then(|index| self.regions.get(index))
    }

    fn region_index_at(&self, tick: u32) -> Option<usize> {
        self.regions.iter().position(|region| region.contains(tick))
    }

    fn region_index(&self, id: AutomationRegionId) -> Result<usize, AutomationRegionError> {
        self.regions
            .iter()
            .position(|region| region.id == id)
            .ok_or(AutomationRegionError::NotFound(id))
    }

    fn region_indices(
        &self,
        ids: &[AutomationRegionId],
    ) -> Result<Vec<usize>, AutomationRegionError> {
        ids.iter().map(|id| self.region_index(*id)).collect()
    }

    /// Ticks of other regions showing the same composition time as `tick` in region `index`.
    fn sibling_ticks(&self, index: usize, tick: u32) -> Vec<u32> {
        let Some(source) = self.regions.get(index) else {
            return Vec::new();
        };
        let content_time = source.content_time(tick);
        self.regions
            .iter()
            .enumerate()
            .filter(|(other, region)| *other != index && region.content_id == source.content_id)
            .filter_map(|(_, region)| region.tick_for_content(content_time))
            .collect()
    }

    /// Indices of the points inside the half-open span `[start, end)`.
    fn point_span(&self, start: u32, end: u32) -> Range<usize> {
        let first = first_index_at(&self.points, start);
        let last = first_index_at(&self.points, end).max(first);
        first..last
    }

    /// Whether the half-open span `[start, end)` touches no region outside `ignored`.
    fn span_is_free(&self, start: u32, end: u32, ignored: &[AutomationRegionId]) -> bool {
        !self
            .regions
            .iter()
            .any(|region| !ignored.contains(&region.id) && region.overlaps(start, end))
    }

    fn new_content_id(&mut self) -> u32 {
        let id = self.next_content_id;
        self.next_content_id = self.next_content_id.saturating_add(1);
        id
    }

    /// Removes and returns the points inside the half-open span `[start, end)`.
    fn take_points(&mut self, start: u32, end: u32) -> Vec<AutomationPoint> {
        let span = self.point_span(start, end);
        self.points.drain(span).collect()
    }

    /// Inserts points that keep their identifiers, after any point already on their tick.
    fn insert_points(&mut self, points: Vec<AutomationPoint>) {
        for point in points {
            let index = self
                .points
                .partition_point(|p| p.time_ticks <= point.time_ticks);
            self.points.insert(index, point);
        }
    }

    fn sort_regions(&mut self) {
        self.regions.sort_by_key(|region| region.start_ticks);
    }

    // ------------------------------------------------------------------------
    // Point edits mirrored into shared regions
    // ------------------------------------------------------------------------

    /// Adds a point like [`Self::add_point`]. Inside a shared region, every sibling showing the
    /// same composition time gets a copy.
    pub fn add_point_mirrored(&mut self, point: AutomationPoint) -> AutomationPointId {
        let id = self.add_point(point);
        self.mirror_added(id);
        id
    }

    /// Removes a point like [`Self::remove_point`], and its mirrors in shared regions.
    pub fn remove_point_mirrored(&mut self, id: u64) -> Option<AutomationPoint> {
        let point_id = AutomationPointId::from_u64(id);
        let index = self.points.iter().position(|point| point.id == point_id)?;
        let tick = self.points.get(index)?.time_ticks;
        let rank = index.saturating_sub(first_index_at(&self.points, tick));
        if let Some(region) = self.region_index_at(tick) {
            self.mirror_removed(region, tick, rank);
        }
        self.remove_point(id)
    }

    /// Updates a point like [`Self::update_point`] and mirrors the change into shared regions.
    ///
    /// A point that stays on its tick updates its mirrors in place. A point moved to another
    /// tick leaves its old region's composition and joins the one at its new tick, if any.
    #[allow(
        clippy::too_many_arguments,
        reason = "mirrors the independently editable point fields of `update_point`"
    )]
    pub fn update_point_mirrored(
        &mut self,
        id: u64,
        time_ticks: Option<u32>,
        value: Option<NormalizedF64>,
        tension: Option<BipolarF64>,
        curve_type: Option<AutomationCurveType>,
        handles: Option<BezierHandles>,
    ) -> Option<usize> {
        let point_id = AutomationPointId::from_u64(id);
        let old_index = self.points.iter().position(|point| point.id == point_id)?;
        let old_tick = self.points.get(old_index)?.time_ticks;
        let rank = old_index.saturating_sub(first_index_at(&self.points, old_tick));
        let old_region = self.region_index_at(old_tick);

        let new_index = self.update_point(id, time_ticks, value, tension, curve_type, handles)?;
        let updated = self.points.get(new_index)?.clone();

        if updated.time_ticks == old_tick {
            if let Some(region) = old_region {
                for tick in self.sibling_ticks(region, old_tick) {
                    let index = first_index_at(&self.points, tick).saturating_add(rank);
                    if let Some(mirror) = self.points.get_mut(index)
                        && mirror.time_ticks == tick
                    {
                        mirror.value = updated.value;
                        mirror.curve_type = updated.curve_type;
                        mirror.tension = updated.tension;
                        mirror.handles = updated.handles;
                    }
                }
            }
        } else {
            if let Some(region) = old_region {
                self.mirror_removed(region, old_tick, rank);
            }
            self.mirror_added(point_id);
        }
        self.points.iter().position(|point| point.id == point_id)
    }

    /// Removes every point between `start` and `end` (inclusive) like [`Self::delete_range`],
    /// and the same composition span from the siblings of every shared region it cuts.
    pub fn delete_range_mirrored(&mut self, start: u32, end: u32) -> usize {
        let (start, end) = (start.min(end), start.max(end));
        let mut mirrored = Vec::new();
        for (index, region) in self.regions.iter().enumerate() {
            if !region.overlaps(start, end.saturating_add(1)) {
                continue;
            }
            let from = region.content_time(start.max(region.start_ticks));
            let to = region.content_time(end.min(region.end_ticks().saturating_sub(1)));
            for (other, sibling) in self.regions.iter().enumerate() {
                if other == index || sibling.content_id != region.content_id {
                    continue;
                }
                let window = sibling.content_window();
                let low = from.max(window.start);
                let high = to.min(window.end.saturating_sub(1));
                if let (Some(low), Some(high)) = (
                    sibling.tick_for_content(low),
                    sibling.tick_for_content(high),
                ) && low <= high
                {
                    mirrored.push((low, high));
                }
            }
        }
        let removed: usize = mirrored
            .into_iter()
            .map(|(low, high)| self.delete_range(low, high))
            .sum();
        removed.saturating_add(self.delete_range(start, end))
    }

    /// Copies the point with `id` into every sibling of the region it now sits in.
    fn mirror_added(&mut self, id: AutomationPointId) {
        let Some(point) = self.points.iter().find(|point| point.id == id).cloned() else {
            return;
        };
        let Some(region) = self.region_index_at(point.time_ticks) else {
            return;
        };
        for tick in self.sibling_ticks(region, point.time_ticks) {
            self.add_point(AutomationPoint {
                time_ticks: tick,
                ..point.clone()
            });
        }
    }

    /// Removes the mirrors of the point at `tick` (the `rank`-th point on that tick) in region
    /// `region`.
    fn mirror_removed(&mut self, region: usize, tick: u32, rank: usize) {
        for mirror_tick in self.sibling_ticks(region, tick) {
            let index = first_index_at(&self.points, mirror_tick).saturating_add(rank);
            if self
                .points
                .get(index)
                .is_some_and(|point| point.time_ticks == mirror_tick)
            {
                self.points.remove(index);
            }
        }
    }

    /// Fills `[from, to)` of region `index` with what its siblings show at the same
    /// composition times. The span must already be empty.
    fn fill_from_siblings(&mut self, index: usize, from: u32, to: u32) {
        let Some(region) = self.regions.get(index).cloned() else {
            return;
        };
        let mut remaining = Vec::with_capacity(2);
        remaining.push(region.content_time(from)..region.content_time(to));
        let mut copies = Vec::new();

        for (other, sibling) in self.regions.iter().enumerate() {
            if other == index || sibling.content_id != region.content_id {
                continue;
            }
            let window = sibling.content_window();
            let mut next = Vec::with_capacity(remaining.len());
            for wanted in remaining {
                let low = wanted.start.max(window.start);
                let high = wanted.end.min(window.end);
                if low >= high {
                    next.push(wanted);
                    continue;
                }
                if let (Some(first), Some(last)) = (
                    sibling.tick_for_content(low),
                    sibling.tick_for_content(high.saturating_sub(1)),
                ) {
                    copies.extend(
                        self.points
                            .iter()
                            .filter(|p| p.time_ticks >= first && p.time_ticks <= last)
                            .filter_map(|p| {
                                region
                                    .tick_for_content(sibling.content_time(p.time_ticks))
                                    .map(|tick| AutomationPoint {
                                        time_ticks: tick,
                                        ..p.clone()
                                    })
                            }),
                    );
                }
                if wanted.start < low {
                    next.push(wanted.start..low);
                }
                if high < wanted.end {
                    next.push(high..wanted.end);
                }
            }
            remaining = next;
            if remaining.is_empty() {
                break;
            }
        }

        copies.sort_by_key(|point| point.time_ticks);
        for point in copies {
            self.add_point(point);
        }
    }

    // ------------------------------------------------------------------------
    // Region edits
    // ------------------------------------------------------------------------

    /// Creates a region over `[start, start + length)` with its own composition. Points already
    /// in the span become its members.
    pub fn create_region(
        &mut self,
        start: u32,
        length: u32,
        name: impl Into<String>,
    ) -> Result<AutomationRegionId, AutomationRegionError> {
        if length == 0 {
            return Err(AutomationRegionError::Empty);
        }
        let end = start.saturating_add(length);
        if !self.span_is_free(start, end, &[]) {
            return Err(AutomationRegionError::Overlap);
        }
        let content_id = self.new_content_id();
        let id = AutomationRegionId::next(&mut self.next_region_id);
        self.regions.push(AutomationRegion {
            id,
            name: name.into(),
            start_ticks: start,
            length_ticks: end.saturating_sub(start),
            content_id,
            content_offset: 0,
        });
        self.sort_regions();
        Ok(id)
    }

    /// Creates a region over `[start, start + length)` holding `points`, whose times are
    /// relative to the region start. It overwrites the free points under it. Points at or past
    /// the region's length are placed on its last tick.
    pub fn insert_region(
        &mut self,
        start: u32,
        length: u32,
        name: impl Into<String>,
        points: &[AutomationPoint],
    ) -> Result<AutomationRegionId, AutomationRegionError> {
        let id = self.create_region(start, length, name)?;
        let end = start.saturating_add(length);
        self.take_points(start, end);
        let last = length.saturating_sub(1);
        for point in points {
            self.add_point(AutomationPoint {
                time_ticks: start.saturating_add(point.time_ticks.min(last)),
                ..point.clone()
            });
        }
        Ok(id)
    }

    /// Renames a region.
    pub fn rename_region(
        &mut self,
        id: AutomationRegionId,
        name: impl Into<String>,
    ) -> Result<(), AutomationRegionError> {
        let index = self.region_index(id)?;
        if let Some(region) = self.regions.get_mut(index) {
            region.name = name.into();
        }
        Ok(())
    }

    /// Removes regions together with their points.
    pub fn delete_regions(
        &mut self,
        ids: &[AutomationRegionId],
    ) -> Result<(), AutomationRegionError> {
        self.region_indices(ids)?;
        let spans: Vec<_> = self
            .regions
            .iter()
            .filter(|region| ids.contains(&region.id))
            .map(|region| (region.start_ticks, region.end_ticks()))
            .collect();
        for (start, end) in spans {
            self.take_points(start, end);
        }
        self.regions.retain(|region| !ids.contains(&region.id));
        Ok(())
    }

    /// Removes regions but keeps their points as free points.
    pub fn dissolve_regions(
        &mut self,
        ids: &[AutomationRegionId],
    ) -> Result<(), AutomationRegionError> {
        self.region_indices(ids)?;
        self.regions.retain(|region| !ids.contains(&region.id));
        Ok(())
    }

    /// Closest move to `delta` ticks that keeps the regions at or after tick zero and stops them
    /// at the first region they would run into.
    pub fn clamp_region_move(&self, ids: &[AutomationRegionId], delta: i64) -> i64 {
        let mut clamped = delta;
        for moving in self.regions.iter().filter(|r| ids.contains(&r.id)) {
            let start = i64::from(moving.start_ticks);
            let end = i64::from(moving.end_ticks());
            if clamped < 0 {
                clamped = clamped.max(start.saturating_neg());
            }
            for still in self.regions.iter().filter(|r| !ids.contains(&r.id)) {
                if clamped > 0 && still.start_ticks >= moving.end_ticks() {
                    clamped = clamped.min(i64::from(still.start_ticks).saturating_sub(end));
                } else if clamped < 0 && still.end_ticks() <= moving.start_ticks {
                    clamped = clamped.max(i64::from(still.end_ticks()).saturating_sub(start));
                }
            }
        }
        clamped
    }

    /// Moves regions and their points by `delta` ticks, clamped like
    /// [`Self::clamp_region_move`]. Free points under the new spans are overwritten. Returns
    /// the applied move.
    pub fn move_regions(
        &mut self,
        ids: &[AutomationRegionId],
        delta: i64,
    ) -> Result<i64, AutomationRegionError> {
        let indices = self.region_indices(ids)?;
        let delta = self.clamp_region_move(ids, delta);
        if delta == 0 {
            return Ok(0);
        }

        let mut moved = Vec::new();
        for index in &indices {
            if let Some(region) = self.regions.get(*index) {
                let (start, end) = (region.start_ticks, region.end_ticks());
                moved.extend(self.take_points(start, end));
            }
        }
        for index in &indices {
            if let Some(region) = self.regions.get_mut(*index) {
                region.start_ticks = shift_tick(region.start_ticks, delta);
            }
        }
        for index in &indices {
            if let Some(region) = self.regions.get(*index) {
                let (start, end) = (region.start_ticks, region.end_ticks());
                self.take_points(start, end);
            }
        }
        for point in &mut moved {
            point.time_ticks = shift_tick(point.time_ticks, delta);
        }
        moved.sort_by_key(|point| point.time_ticks);
        self.insert_points(moved);
        self.sort_regions();
        Ok(delta)
    }

    /// Closest resize to `delta` ticks on `edge` that keeps every region at least one tick long,
    /// at or after tick zero, and clear of its neighbours.
    pub fn clamp_region_resize(
        &self,
        ids: &[AutomationRegionId],
        edge: ResizeEdge,
        delta: i64,
    ) -> i64 {
        let mut clamped = delta;
        for region in self.regions.iter().filter(|r| ids.contains(&r.id)) {
            let start = i64::from(region.start_ticks);
            let end = i64::from(region.end_ticks());
            let shortest = i64::from(region.length_ticks).saturating_sub(1);
            match edge {
                ResizeEdge::Right => {
                    clamped = clamped.max(shortest.saturating_neg());
                    if let Some(next) = self
                        .regions
                        .iter()
                        .filter(|r| r.start_ticks >= region.end_ticks())
                        .map(|r| i64::from(r.start_ticks))
                        .min()
                    {
                        clamped = clamped.min(next.saturating_sub(end));
                    }
                }
                ResizeEdge::Left => {
                    clamped = clamped.min(shortest).max(start.saturating_neg());
                    if let Some(previous) = self
                        .regions
                        .iter()
                        .filter(|r| r.end_ticks() <= region.start_ticks)
                        .map(|r| i64::from(r.end_ticks()))
                        .max()
                    {
                        clamped = clamped.max(previous.saturating_sub(start));
                    }
                }
            }
        }
        clamped
    }

    /// Moves one edge of each region by `delta` ticks, clamped like
    /// [`Self::clamp_region_resize`]. Shrinking deletes the points left outside. Growing
    /// overwrites the free points under the new span, then shows what a sibling shows at the
    /// same composition times. The composition stays where it was on both edges. Returns the
    /// applied resize.
    pub fn resize_regions(
        &mut self,
        ids: &[AutomationRegionId],
        edge: ResizeEdge,
        delta: i64,
    ) -> Result<i64, AutomationRegionError> {
        let indices = self.region_indices(ids)?;
        let delta = self.clamp_region_resize(ids, edge, delta);
        if delta == 0 {
            return Ok(0);
        }

        let mut grown = Vec::new();
        for index in indices {
            let Some(region) = self.regions.get(index).cloned() else {
                continue;
            };
            let (old_start, old_end) = (region.start_ticks, region.end_ticks());
            let (start, end) = match edge {
                ResizeEdge::Right => (old_start, shift_tick(old_end, delta)),
                ResizeEdge::Left => (shift_tick(old_start, delta), old_end),
            };
            // Shrinking crops; growing overwrites the free points under the new span.
            match edge {
                ResizeEdge::Right if end < old_end => self.take_points(end, old_end),
                ResizeEdge::Right => self.take_points(old_end, end),
                ResizeEdge::Left if start > old_start => self.take_points(old_start, start),
                ResizeEdge::Left => self.take_points(start, old_start),
            };
            if let Some(region) = self.regions.get_mut(index) {
                region.content_offset = region
                    .content_offset
                    .saturating_add(i64::from(start).saturating_sub(i64::from(old_start)));
                region.start_ticks = start;
                region.length_ticks = end.saturating_sub(start);
            }
            match edge {
                ResizeEdge::Right if end > old_end => grown.push((index, old_end, end)),
                ResizeEdge::Left if start < old_start => grown.push((index, start, old_start)),
                _ => {}
            }
        }
        for (index, from, to) in grown {
            self.fill_from_siblings(index, from, to);
        }
        self.sort_regions();
        Ok(delta)
    }

    /// Cuts a region in two at `at`. Both halves keep showing the same composition.
    pub fn slice_region(
        &mut self,
        id: AutomationRegionId,
        at: u32,
    ) -> Result<AutomationRegionId, AutomationRegionError> {
        let index = self.region_index(id)?;
        let region = self
            .regions
            .get(index)
            .cloned()
            .ok_or(AutomationRegionError::NotFound(id))?;
        if at <= region.start_ticks || at >= region.end_ticks() {
            return Err(AutomationRegionError::SliceOutside);
        }
        let second_id = AutomationRegionId::next(&mut self.next_region_id);
        let second = AutomationRegion {
            id: second_id,
            start_ticks: at,
            length_ticks: region.end_ticks().saturating_sub(at),
            content_offset: region.content_time(at),
            ..region.clone()
        };
        if let Some(first) = self.regions.get_mut(index) {
            first.length_ticks = at.saturating_sub(region.start_ticks);
        }
        self.regions.push(second);
        self.sort_regions();
        Ok(second_id)
    }

    /// Copies regions `delta` ticks later. The copies share their originals' compositions and
    /// overwrite the free points under them.
    pub fn duplicate_regions(
        &mut self,
        ids: &[AutomationRegionId],
        delta: u32,
    ) -> Result<Vec<AutomationRegionId>, AutomationRegionError> {
        let copies = self.copy_regions(ids)?;
        let Some(first) = self
            .regions
            .iter()
            .filter(|region| ids.contains(&region.id))
            .map(|region| region.start_ticks)
            .min()
        else {
            return Ok(Vec::new());
        };
        self.paste_regions(first.saturating_add(delta), &copies, true)
    }

    /// Gives each region a composition of its own, so later edits no longer reach the regions
    /// it shared with.
    pub fn make_regions_unique(
        &mut self,
        ids: &[AutomationRegionId],
    ) -> Result<(), AutomationRegionError> {
        let indices = self.region_indices(ids)?;
        for index in indices {
            let content_id = self.new_content_id();
            if let Some(region) = self.regions.get_mut(index) {
                region.content_id = content_id;
            }
        }
        Ok(())
    }

    /// Detaches regions and their points, with starts relative to the earliest region.
    pub fn copy_regions(
        &self,
        ids: &[AutomationRegionId],
    ) -> Result<Vec<AutomationRegionCopy>, AutomationRegionError> {
        self.region_indices(ids)?;
        let selected: Vec<_> = self
            .regions
            .iter()
            .filter(|region| ids.contains(&region.id))
            .collect();
        let first = selected
            .iter()
            .map(|region| region.start_ticks)
            .min()
            .unwrap_or_default();
        Ok(selected
            .into_iter()
            .map(|region| {
                let span = self.point_span(region.start_ticks, region.end_ticks());
                AutomationRegionCopy {
                    name: region.name.clone(),
                    start_ticks: region.start_ticks.saturating_sub(first),
                    length_ticks: region.length_ticks,
                    content_id: region.content_id,
                    content_offset: region.content_offset,
                    points: self
                        .points
                        .get(span)
                        .unwrap_or_default()
                        .iter()
                        .map(|point| AutomationPoint {
                            id: AutomationPointId::default(),
                            time_ticks: point.time_ticks.saturating_sub(region.start_ticks),
                            ..point.clone()
                        })
                        .collect(),
                }
            })
            .collect())
    }

    /// Places copied regions starting at `at_tick`. With `share_content`, a copy whose
    /// composition still exists in this lane keeps sharing it; other copies get compositions
    /// of their own, shared among copies that came from one composition. The copies overwrite
    /// the free points under them, and refuse to overlap a region.
    pub fn paste_regions(
        &mut self,
        at_tick: u32,
        copies: &[AutomationRegionCopy],
        share_content: bool,
    ) -> Result<Vec<AutomationRegionId>, AutomationRegionError> {
        let spans: Vec<_> = copies
            .iter()
            .map(|copy| {
                let start = at_tick.saturating_add(copy.start_ticks);
                (start, start.saturating_add(copy.length_ticks))
            })
            .collect();
        if spans.iter().any(|(start, end)| start >= end) {
            return Err(AutomationRegionError::Empty);
        }
        let collides_with_lane = spans
            .iter()
            .any(|(start, end)| !self.span_is_free(*start, *end, &[]));
        let collides_with_copies = spans.iter().enumerate().any(|(i, (start, end))| {
            spans
                .iter()
                .skip(i.saturating_add(1))
                .any(|(other_start, other_end)| start < other_end && other_start < end)
        });
        if collides_with_lane || collides_with_copies {
            return Err(AutomationRegionError::Overlap);
        }

        let mut content_map: Vec<(u32, u32)> = Vec::new();
        let mut ids = Vec::with_capacity(copies.len());
        for (copy, (start, end)) in copies.iter().zip(spans) {
            let shared = share_content
                && self
                    .regions
                    .iter()
                    .any(|region| region.content_id == copy.content_id);
            let content_id = if shared {
                copy.content_id
            } else if let Some((_, mapped)) = content_map
                .iter()
                .find(|(from, _)| *from == copy.content_id)
            {
                *mapped
            } else {
                let mapped = self.new_content_id();
                content_map.push((copy.content_id, mapped));
                mapped
            };

            self.take_points(start, end);
            let last = copy.length_ticks.saturating_sub(1);
            for point in &copy.points {
                self.add_point(AutomationPoint {
                    time_ticks: start.saturating_add(point.time_ticks.min(last)),
                    ..point.clone()
                });
            }
            let id = AutomationRegionId::next(&mut self.next_region_id);
            self.regions.push(AutomationRegion {
                id,
                name: copy.name.clone(),
                start_ticks: start,
                length_ticks: end.saturating_sub(start),
                content_id,
                content_offset: copy.content_offset,
            });
            ids.push(id);
        }
        self.sort_regions();
        Ok(ids)
    }
}

// ============================================================================
// Project-level region edits
// ============================================================================

impl ApplicationState {
    fn automation_lane_mut(
        &mut self,
        lane_id: AutomationId,
    ) -> anyhow::Result<&mut AutomationLane> {
        self.automation_pool
            .get_mut(lane_id)
            .ok_or_else(|| anyhow!("Automation lane {:?} not found", lane_id))
    }

    /// Runs a region edit on a lane and returns the lane afterwards.
    pub fn edit_automation_regions<T>(
        &mut self,
        lane_id: AutomationId,
        edit: impl FnOnce(&mut AutomationLane) -> Result<T, AutomationRegionError>,
    ) -> anyhow::Result<(AutomationLane, T)> {
        let lane = self.automation_lane_mut(lane_id)?;
        let result = edit(lane)?;
        Ok((lane.clone(), result))
    }

    /// Copies regions of a lane for a later paste.
    pub fn copy_automation_regions(
        &self,
        lane_id: AutomationId,
        ids: &[AutomationRegionId],
    ) -> anyhow::Result<Vec<AutomationRegionCopy>> {
        let lane = self
            .automation_pool
            .get(lane_id)
            .ok_or_else(|| anyhow!("Automation lane {:?} not found", lane_id))?;
        Ok(lane.copy_regions(ids)?)
    }
}

#[cfg(test)]
#[allow(
    clippy::indexing_slicing,
    clippy::unwrap_used,
    reason = "tests fail loudly on a missing region or point"
)]
mod tests {
    use super::*;

    fn lane_with(points: &[(u32, f64)]) -> AutomationLane {
        let mut lane =
            AutomationLane::new(AutomationId::default(), "Test", NormalizedF64::new(0.5));
        for (tick, value) in points {
            lane.add_point(AutomationPoint::new(*tick, NormalizedF64::new(*value)));
        }
        lane
    }

    fn ticks(lane: &AutomationLane) -> Vec<u32> {
        lane.points.iter().map(|p| p.time_ticks).collect()
    }

    fn values_at(lane: &AutomationLane, start: u32, end: u32) -> Vec<(u32, f64)> {
        lane.points
            .iter()
            .filter(|p| p.time_ticks >= start && p.time_ticks < end)
            .map(|p| (p.time_ticks.saturating_sub(start), p.value.get()))
            .collect()
    }

    #[test]
    fn creating_a_region_captures_points_and_refuses_overlap() {
        let mut lane = lane_with(&[(0, 0.1), (100, 0.5), (300, 0.9)]);
        let id = lane.create_region(0, 200, "A").unwrap();
        assert_eq!(lane.region_at(100).map(|r| r.id), Some(id));
        assert!(lane.region_at(300).is_none());
        assert_eq!(
            lane.create_region(150, 100, "B"),
            Err(AutomationRegionError::Overlap)
        );
        assert!(lane.create_region(200, 100, "B").is_ok());
    }

    #[test]
    fn moving_a_region_carries_its_points_and_overwrites_free_ones() {
        let mut lane = lane_with(&[(10, 0.1), (50, 0.5), (250, 0.9)]);
        let id = lane.create_region(0, 100, "A").unwrap();
        assert_eq!(lane.move_regions(&[id], 200), Ok(200));
        // The free point at 250 lay under the moved region.
        assert_eq!(ticks(&lane), vec![210, 250]);
        assert_eq!(lane.region(id).map(|r| r.start_ticks), Some(200));
    }

    #[test]
    fn moves_and_resizes_stop_at_the_neighbouring_region() {
        let mut lane = lane_with(&[]);
        let a = lane.create_region(0, 100, "A").unwrap();
        let b = lane.create_region(300, 100, "B").unwrap();
        assert_eq!(lane.move_regions(&[a], 500), Ok(200));
        assert_eq!(lane.clamp_region_move(&[b], -1000), 0);
        assert_eq!(lane.clamp_region_resize(&[a], ResizeEdge::Right, 50), 0);
        assert_eq!(lane.clamp_region_resize(&[a], ResizeEdge::Right, -500), -99);
        assert_eq!(lane.clamp_region_resize(&[a], ResizeEdge::Left, -500), -200);
    }

    #[test]
    fn shrinking_deletes_the_points_outside_and_left_resize_keeps_the_composition() {
        let mut lane = lane_with(&[(10, 0.1), (60, 0.6), (90, 0.9)]);
        let id = lane.create_region(0, 100, "A").unwrap();
        assert_eq!(lane.resize_regions(&[id], ResizeEdge::Left, 50), Ok(50));
        assert_eq!(ticks(&lane), vec![60, 90]);
        let region = lane.region(id).unwrap();
        assert_eq!((region.start_ticks, region.length_ticks), (50, 50));
        assert_eq!(region.content_offset, 50);
        assert_eq!(lane.resize_regions(&[id], ResizeEdge::Right, -20), Ok(-20));
        assert_eq!(ticks(&lane), vec![60]);
    }

    #[test]
    fn shared_regions_mirror_point_edits() {
        let mut lane = lane_with(&[(10, 0.1), (50, 0.5)]);
        let a = lane.create_region(0, 100, "A").unwrap();
        let b = lane.duplicate_regions(&[a], 200).unwrap()[0];
        assert_eq!(
            lane.region(b).map(|r| r.content_id),
            lane.region(a).map(|r| r.content_id)
        );
        assert_eq!(values_at(&lane, 200, 300), values_at(&lane, 0, 100));

        // Adding, editing, and removing a point in one region reaches the other.
        let added = lane.add_point_mirrored(AutomationPoint::new(70, NormalizedF64::new(0.7)));
        assert_eq!(values_at(&lane, 200, 300), values_at(&lane, 0, 100));
        lane.update_point_mirrored(
            added.to_u64(),
            None,
            Some(NormalizedF64::new(0.2)),
            None,
            None,
            None,
        );
        assert_eq!(values_at(&lane, 200, 300), values_at(&lane, 0, 100));
        lane.update_point_mirrored(added.to_u64(), Some(80), None, None, None, None);
        assert_eq!(values_at(&lane, 200, 300), values_at(&lane, 0, 100));
        lane.remove_point_mirrored(added.to_u64());
        assert_eq!(values_at(&lane, 200, 300), vec![(10, 0.1), (50, 0.5)]);

        // A free point dropped into a shared region joins every copy of it.
        let free = lane.add_point(AutomationPoint::new(150, NormalizedF64::new(0.3)));
        lane.update_point_mirrored(free.to_u64(), Some(230), None, None, None, None);
        assert_eq!(
            values_at(&lane, 0, 100),
            vec![(10, 0.1), (30, 0.3), (50, 0.5)]
        );

        // A unique region no longer mirrors.
        lane.make_regions_unique(&[b]).unwrap();
        lane.add_point_mirrored(AutomationPoint::new(90, NormalizedF64::new(0.9)));
        assert_eq!(
            values_at(&lane, 200, 300),
            vec![(10, 0.1), (30, 0.3), (50, 0.5)]
        );
    }

    #[test]
    fn slicing_keeps_the_composition_and_growing_refills_from_siblings() {
        let mut lane = lane_with(&[(10, 0.1), (60, 0.6)]);
        let a = lane.create_region(0, 100, "A").unwrap();
        let b = lane.duplicate_regions(&[a], 200).unwrap()[0];
        let second = lane.slice_region(b, 250).unwrap();
        assert_eq!(lane.region(second).map(|r| r.content_offset), Some(50));

        // Cropping B's first half, then growing it back, restores the curve from A.
        lane.resize_regions(&[b], ResizeEdge::Right, -30).unwrap();
        assert_eq!(values_at(&lane, 200, 250), vec![(10, 0.1)]);
        lane.delete_regions(&[second]).unwrap();
        lane.resize_regions(&[b], ResizeEdge::Right, 90).unwrap();
        assert_eq!(values_at(&lane, 200, 300), values_at(&lane, 0, 100));
    }

    #[test]
    fn pasting_regions_into_another_lane_gets_new_compositions() {
        let mut source = lane_with(&[(10, 0.1)]);
        let a = source.create_region(0, 100, "A").unwrap();
        let copies = source.copy_regions(&[a]).unwrap();
        let mut target = lane_with(&[(20, 0.4)]);
        target.create_region(500, 10, "X").unwrap();
        let pasted = target.paste_regions(0, &copies, false).unwrap();
        assert_eq!(ticks(&target), vec![10]);
        let region = target.region(pasted[0]).unwrap();
        assert_ne!(
            Some(region.content_id),
            target.region_at(500).map(|r| r.content_id)
        );
        assert_eq!(
            target.paste_regions(450, &copies, true),
            Err(AutomationRegionError::Overlap)
        );
    }

    #[test]
    fn lanes_saved_before_regions_existed_still_load() {
        let mut lane = lane_with(&[(10, 0.1)]);
        lane.create_region(0, 100, "A").unwrap();
        let mut json = serde_json::to_value(&lane).unwrap();
        assert_eq!(
            serde_json::from_value::<AutomationLane>(json.clone()).ok(),
            Some(lane.clone())
        );
        if let Some(fields) = json.as_object_mut() {
            fields.remove("regions");
            fields.remove("next_region_id");
            fields.remove("next_content_id");
        }
        let old = serde_json::from_value::<AutomationLane>(json).unwrap();
        assert!(old.regions.is_empty());
        assert_eq!(old.points, lane.points);
    }
}
