// src/core/project/track/automation.rs
//
// Automation system for parameter modulation over time.
// Provides both project-level automation lane data (saved with the project)
// and a runtime AutomationManager used by plugin wrappers during audio processing.

use karbeat_dsp::interpolation::lerp;
use karbeat_utils::types::{BipolarF64, NormalizedF64};
use serde::{Deserialize, Serialize};

use crate::{
    audio::event::PluginTarget,
    shared::{
        GeneratorId,
        id::{AutomationId, AutomationPointId, BusId, EffectId, TrackId},
    },
};

// ============================================================================
// AUTOMATION TARGET
// ============================================================================

/// Specifies what parameter an automation lane controls.
///
/// Each lane targets exactly one parameter on one thing (mixer channel,
/// generator, or effect slot).
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq, Hash)]
pub enum AutomationTarget {
    /// Parameter on a generator instance.
    Generator {
        /// Generator owning the parameter.
        generator_id: GeneratorId,
        /// Stable plugin parameter identifier.
        param_id: u32,
    },
    /// Automatable property belonging to a track.
    Track {
        /// Track owning the property.
        track_id: TrackId,
        /// Property selected within the track.
        track_target: TrackAutomationTarget,
    },

    /// Automatable property belonging to a mixer bus.
    Bus {
        /// Bus owning the property.
        bus_id: BusId,
        /// Mixer property selected within the bus.
        mix_target: MixerChannelParamTarget,
    },

    /// Automatable property belonging to the project master path.
    Master(MasterAutomationTarget),
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq, Hash)]
/// Selects an automatable subsystem within a track.
pub enum TrackAutomationTarget {
    /// Track mixer-channel parameter.
    MixerChannel(MixerChannelParamTarget),
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq, Hash)]
/// Selects an automatable property of the project master path.
pub enum MasterAutomationTarget {
    /// Master mixer-channel parameter.
    MixerChannel(MixerChannelParamTarget),
    /// Project tempo in beats per minute.
    TempoBpm,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq, Hash)]
/// Selects an automatable property within a mixer channel.
pub enum MixerChannelParamTarget {
    /// Channel fader gain.
    Volume,
    /// Channel stereo pan.
    Pan,
    /// Property on an effect inserted in the channel.
    Plugin {
        /// Effect slot owning the property.
        effect_id: EffectId,
        /// Property selected within that effect.
        target: EffectAutomationTarget,
    },
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq, Hash)]
/// Selects an automatable control within an effect slot.
pub enum EffectAutomationTarget {
    /// Wet/dry mix control reserved for effect-slot automation.
    Mix,
    /// Plugin-defined parameter.
    PluginParam {
        /// Stable plugin parameter identifier.
        param_id: u32,
    },
}

impl AutomationTarget {
    /// Returns true if this target references the given track ID.
    pub fn references_track(&self, id: TrackId) -> bool {
        match self {
            AutomationTarget::Track { track_id, .. } => *track_id == id,
            _ => false,
        }
    }

    /// Returns true if this target references the given generator ID.
    pub fn references_generator(&self, id: GeneratorId) -> bool {
        match self {
            AutomationTarget::Generator { generator_id, .. } => *generator_id == id,
            _ => false,
        }
    }

    /// Checks if this automation target references a specific Bus.
    pub fn references_bus(&self, target_bus_id: BusId) -> bool {
        match self {
            AutomationTarget::Bus { bus_id, .. } => *bus_id == target_bus_id,
            _ => false,
        }
    }
    /// Checks if two targets belong in the same UI accordion/drawer
    pub fn belongs_to_same_drawer_as(&self, other: &Self) -> bool {
        match (self, other) {
            (
                Self::Generator {
                    generator_id: id1, ..
                },
                Self::Generator {
                    generator_id: id2, ..
                },
            ) => id1 == id2,
            (Self::Track { track_id: id1, .. }, Self::Track { track_id: id2, .. }) => id1 == id2,
            (Self::Bus { bus_id: id1, .. }, Self::Bus { bus_id: id2, .. }) => id1 == id2,
            (Self::Master(_), Self::Master(_)) => true,
            _ => false,
        }
    }

    /// Resolves targets backed by plugin parameters to their owning plugin instance.
    ///
    /// Mixer volume, pan, tempo, and the reserved effect mix target return `None`.
    pub fn as_plugin_target(&self) -> Option<PluginTarget> {
        match self {
            AutomationTarget::Generator { generator_id, .. } => {
                Some(PluginTarget::Generator(*generator_id))
            }
            AutomationTarget::Track {
                track_id,
                track_target:
                    TrackAutomationTarget::MixerChannel(MixerChannelParamTarget::Plugin {
                        effect_id,
                        ..
                    }),
            } => Some(PluginTarget::TrackEffect(*track_id, *effect_id)),
            AutomationTarget::Bus {
                bus_id,
                mix_target: MixerChannelParamTarget::Plugin { effect_id, .. },
            } => Some(PluginTarget::BusEffect(*bus_id, *effect_id)),
            AutomationTarget::Master(master_target) => match master_target {
                MasterAutomationTarget::MixerChannel(mixer_channel_param_target) => {
                    match mixer_channel_param_target {
                        MixerChannelParamTarget::Plugin { effect_id, .. } => {
                            Some(PluginTarget::MasterEffect(*effect_id))
                        }
                        _ => None,
                    }
                }
                MasterAutomationTarget::TempoBpm => None,
            },
            _ => None,
        }
    }
}
/// Lowest tempo reachable by tempo automation, in beats per minute.
pub const TEMPO_AUTOMATION_MIN_BPM: f32 = 10.0;

/// Highest tempo reachable by tempo automation, in beats per minute.
pub const TEMPO_AUTOMATION_MAX_BPM: f32 = 999.0;

// ============================================================================
// CURVE TYPES
// ============================================================================

/// Interpolation curve type between automation points
///
/// New variants are appended so the existing ones keep their serialized form.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq, Serialize, Deserialize)]
pub enum AutomationCurveType {
    /// Linear interpolation between points
    #[default]
    Linear,
    /// Exponential curve (good for frequency, volume)
    Exponential,
    /// Instant step (no interpolation)
    Step,
    /// Mirror of the exponential curve: fast at the start, slow at the end
    Logarithmic,
    /// Ease-in-out ramp
    SCurve,
    /// Cubic Bezier shaped by the point's [`BezierHandles`]
    Bezier,
    /// Equal hold steps climbing from the first value to the second
    Stairs,
    /// Stairs with smoothed risers
    SmoothStairs,
    /// Square alternation between the two values
    Pulse,
    /// Sine oscillation between the two values
    Wave,
    /// Triangle oscillation between the two values
    Triangle,
    /// One sine arch that leaves the first value, peaks at the second, and returns
    HalfSine,
}

/// How a curve type uses its segment controls. Lets editors stay generic over curve types.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct CurveTraits {
    /// Whether tension changes the shape.
    pub supports_tension: bool,
    /// Whether raising tension lowers a rising segment (exponential ramps).
    pub tension_inverted: bool,
    /// Whether tension selects a step or cycle count instead of a bend.
    pub tension_is_count: bool,
    /// Whether the shape comes from [`BezierHandles`].
    pub uses_handles: bool,
}

impl AutomationCurveType {
    /// Describes which segment controls this curve type responds to.
    pub fn traits(self) -> CurveTraits {
        let tension_is_count = matches!(
            self,
            Self::Stairs | Self::SmoothStairs | Self::Pulse | Self::Wave | Self::Triangle
        );
        let uses_handles = self == Self::Bezier;
        CurveTraits {
            supports_tension: !uses_handles && self != Self::Step,
            tension_inverted: self == Self::Exponential,
            tension_is_count,
            uses_handles,
        }
    }
}

/// Control handles of a cubic Bezier segment.
///
/// `x` is a fraction of the segment's duration (0.0–1.0), which keeps the curve a function of
/// time. `y` is an absolute value in the unit of the segment's endpoints.
#[derive(Clone, Copy, Debug, PartialEq, Serialize, Deserialize)]
pub struct BezierHandles {
    /// Time fraction of the handle leaving the first point.
    pub x1: f64,
    /// Value of the handle leaving the first point.
    pub y1: f64,
    /// Time fraction of the handle arriving at the next point.
    pub x2: f64,
    /// Value of the handle arriving at the next point.
    pub y2: f64,
}

impl BezierHandles {
    /// Handles on the straight line from `v1` to `v2`, which draw a linear segment.
    pub fn straight(v1: f64, v2: f64) -> Self {
        Self {
            x1: 1.0 / 3.0,
            y1: lerp(1.0 / 3.0, v1, v2),
            x2: 2.0 / 3.0,
            y2: lerp(2.0 / 3.0, v1, v2),
        }
    }

    /// Clamps time fractions and automation values into 0.0–1.0; non-finite fields fall back
    /// to the straight-line handles between `v1` and `v2`.
    #[must_use]
    pub fn sanitized(self, v1: f64, v2: f64) -> Self {
        let fallback = Self::straight(v1, v2);
        let pick = |value: f64, default: f64| {
            if value.is_finite() {
                value.clamp(0.0, 1.0)
            } else {
                default
            }
        };
        Self {
            x1: pick(self.x1, fallback.x1),
            y1: pick(self.y1, fallback.y1),
            x2: pick(self.x2, fallback.x2),
            y2: pick(self.y2, fallback.y2),
        }
    }
}

/// Everything that selects the shape of one segment.
#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub struct SegmentShape {
    /// Curve family.
    pub curve: AutomationCurveType,
    /// Bipolar tension, -1.0 to 1.0.
    pub tension: f64,
    /// Bezier handles; `None` draws a Bezier segment as a straight line.
    pub handles: Option<BezierHandles>,
}

impl SegmentShape {
    /// Shape without Bezier handles.
    pub fn new(curve: AutomationCurveType, tension: f64) -> Self {
        Self {
            curve,
            tension,
            handles: None,
        }
    }
}

// ============================================================================
// AUTOMATION POINT
// ============================================================================

/// A single point on an automation lane.
///
/// Values are stored in normalized form (0.0–1.0). The automated parameter maps them to its
/// own range.
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Default)]
#[serde(default)]
pub struct AutomationPoint {
    /// Lane-local stable point identifier.
    pub id: AutomationPointId,
    /// Position in ticks (relative to project start)
    pub time_ticks: u32,
    /// Normalized parameter value (0.0–1.0)
    pub value: NormalizedF64,
    /// Interpolation curve to the NEXT point
    pub curve_type: AutomationCurveType,
    /// Bipolar tension control (-1.0 to 1.0)
    pub tension: BipolarF64,
    /// Bezier handles of the segment to the NEXT point
    pub handles: Option<BezierHandles>,
}

impl AutomationPoint {
    /// Creates a linear point at `time_ticks`; normalized values are already range-safe by type.
    pub fn new(time_ticks: u32, value: NormalizedF64) -> Self {
        Self::with_curve(time_ticks, value, AutomationCurveType::Linear)
    }

    /// Creates a point with a specific curve.
    pub fn with_curve(
        time_ticks: u32,
        value: NormalizedF64,
        curve_type: AutomationCurveType,
    ) -> Self {
        Self {
            id: AutomationPointId::default(),
            time_ticks,
            value,
            curve_type,
            tension: BipolarF64::default(),
            handles: None,
        }
    }

    /// Shape of the segment that starts at this point.
    #[inline]
    pub fn shape(&self) -> SegmentShape {
        SegmentShape {
            curve: self.curve_type,
            tension: self.tension.get(),
            handles: self.handles,
        }
    }
}

// ============================================================================
// AUTOMATION LANE
// ============================================================================

/// An automation lane that controls a single parameter.
///
/// Lives in `ApplicationState::automation_pool` and is serialized with the project. A lane only
/// holds normalized values (0.0–1.0); the automated parameter owns the mapping to real values.
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Default)]
#[serde(default)]
pub struct AutomationLane {
    /// Project-wide lane identifier.
    pub id: AutomationId,
    /// Human-readable label (e.g. "Volume", "Filter Cutoff")
    pub label: String,
    /// Automation points sorted by time. Points are self-contained in the lane.
    pub points: Vec<AutomationPoint>,
    /// Monotonic lane-local counter used when assigning point identifiers.
    pub next_point_id: u32,
    /// Whether this lane is active
    pub enabled: bool,
    /// Value held while the lane has no points (normalized 0.0–1.0)
    pub default_value: NormalizedF64,
}

impl AutomationLane {
    /// Create a new empty automation lane.
    pub fn new(id: AutomationId, label: impl Into<String>, default_value: NormalizedF64) -> Self {
        Self {
            id,
            label: label.into(),
            points: Vec::new(),
            next_point_id: 0,
            enabled: true,
            default_value,
        }
    }

    /// Add a point to the lane, keeping time order. A point added on an occupied tick goes
    /// after the points already there, so it starts a new segment instead of reshaping the
    /// segment that ends on that tick.
    pub fn add_point(&mut self, mut point: AutomationPoint) -> AutomationPointId {
        point.id = AutomationPointId::next(&mut self.next_point_id);
        let id = point.id;
        let idx = insertion_index_after(&self.points, point.time_ticks);
        self.points.insert(idx, point);
        id
    }

    /// Remove a point at the given index.
    pub fn remove_point(&mut self, id: u64) -> Option<AutomationPoint> {
        let id = AutomationPointId::from_u64(id);
        let index = self.points.iter().position(|point| point.id == id)?;
        Some(self.points.remove(index))
    }

    /// Updates a point and returns its index afterwards.
    ///
    /// A point that stays on its tick keeps its position among points sharing that tick.
    /// A point moved to another tick is placed after the points already there, like
    /// [`Self::add_point`]. A point switched to a Bezier curve without handles gets handles on
    /// the straight line to the next point, so the switch never changes the drawn segment.
    pub fn update_point(
        &mut self,
        id: u64,
        time_ticks: Option<u32>,
        value: Option<NormalizedF64>,
        tension: Option<BipolarF64>,
        curve_type: Option<AutomationCurveType>,
        handles: Option<BezierHandles>,
    ) -> Option<usize> {
        let id = AutomationPointId::from_u64(id);
        let index = self.points.iter().position(|point| point.id == id)?;

        let mut point = self.points.remove(index);
        let previous_time = point.time_ticks;
        if let Some(tt) = time_ticks {
            point.time_ticks = tt;
        }
        if let Some(v) = value {
            point.value = v;
        }
        if let Some(t) = tension {
            point.tension = t;
        }
        if let Some(ct) = curve_type {
            point.curve_type = ct;
        }

        let new_index = if point.time_ticks == previous_time {
            index
        } else {
            insertion_index_after(&self.points, point.time_ticks)
        };

        let from = point.value.get();
        let to = self
            .points
            .get(new_index)
            .map_or(from, |next| next.value.get());
        if let Some(handles) = handles {
            point.handles = Some(handles.sanitized(from, to));
        } else if point.curve_type == AutomationCurveType::Bezier && point.handles.is_none() {
            point.handles = Some(BezierHandles::straight(from, to));
        }

        self.points.insert(new_index, point);

        Some(new_index)
    }

    /// Get the interpolated normalized value (0.0–1.0) at a given time in ticks.
    /// Returns `None` if the lane is disabled or has no points.
    pub fn value_at(&self, time_ticks: u32) -> Option<NormalizedF64> {
        if !self.enabled {
            return None;
        }
        interpolate_points(&self.points, time_ticks)
    }

    /// Clear all points.
    pub fn clear(&mut self) {
        self.points.clear();
    }

    // ------------------------------------------------------------------------
    // Range operations (copy, delete, paste)
    // ------------------------------------------------------------------------

    /// Copies the curve between `start` and `end` (inclusive) with times relative to `start`.
    ///
    /// When no point sits exactly on an edge, one is synthesized there from the interpolated
    /// value, so the copy starts and ends where the lane's curve crosses the range. The
    /// synthesized start point continues with the curve type and tension of the segment it cuts.
    /// Returned points carry default identifiers; pasting assigns new ones.
    pub fn extract_range(&self, start: u32, end: u32) -> Vec<AutomationPoint> {
        let (start, end) = (start.min(end), start.max(end));
        let first = self.points.partition_point(|p| p.time_ticks < start);
        let last = self.points.partition_point(|p| p.time_ticks <= end);
        let inside = self.points.get(first..last).unwrap_or_default();

        let mut out = Vec::with_capacity(inside.len() + 2);
        let starts_on_point = inside.first().is_some_and(|p| p.time_ticks == start);
        if !starts_on_point && let Some(value) = interpolate_points(&self.points, start) {
            let cut = first.checked_sub(1).and_then(|i| self.points.get(i));
            out.push(AutomationPoint {
                value,
                curve_type: cut.map_or(AutomationCurveType::Linear, |p| p.curve_type),
                tension: cut.map_or_else(BipolarF64::default, |p| p.tension),
                // Handles describe the whole cut segment, not the part kept here.
                handles: None,
                ..AutomationPoint::new(0, value)
            });
        }
        out.extend(inside.iter().map(|p| AutomationPoint {
            id: AutomationPointId::default(),
            time_ticks: p.time_ticks - start,
            ..p.clone()
        }));
        let ends_on_point = inside.last().is_some_and(|p| p.time_ticks == end);
        if !ends_on_point
            && end > start
            && let Some(value) = interpolate_points(&self.points, end)
        {
            out.push(AutomationPoint::new(end - start, value));
        }
        out
    }

    /// Removes every point between `start` and `end` (inclusive) and returns how many it removed.
    pub fn delete_range(&mut self, start: u32, end: u32) -> usize {
        let (start, end) = (start.min(end), start.max(end));
        let before = self.points.len();
        self.points
            .retain(|p| p.time_ticks < start || p.time_ticks > end);
        before - self.points.len()
    }

    /// Pastes `points` (times relative to the copied range) at `at_tick`.
    ///
    /// `length_ticks` is the length of the copied range. `target_length` stretches or squeezes
    /// the pasted curve to another length; `None` keeps the original length. Existing points
    /// under the pasted span are replaced. Returns the identifiers of the new points.
    pub fn paste_points(
        &mut self,
        at_tick: u32,
        points: &[AutomationPoint],
        length_ticks: u32,
        target_length: Option<u32>,
    ) -> Vec<AutomationPointId> {
        if points.is_empty() {
            return Vec::new();
        }
        let span = target_length.unwrap_or(length_ticks);
        self.delete_range(at_tick, at_tick.saturating_add(span));

        let scale = if length_ticks == 0 {
            0.0
        } else {
            f64::from(span) / f64::from(length_ticks)
        };
        points
            .iter()
            .map(|point| {
                let offset =
                    floor_to_u32((f64::from(point.time_ticks.min(length_ticks)) * scale).round());
                self.add_point(AutomationPoint {
                    time_ticks: at_tick.saturating_add(offset),
                    ..point.clone()
                })
            })
            .collect()
    }
}

/// Index after every point at or before `time_ticks` in a time-ordered slice.
#[inline]
fn insertion_index_after(points: &[AutomationPoint], time_ticks: u32) -> usize {
    points.partition_point(|p| p.time_ticks <= time_ticks)
}

/// Evaluates time-ordered automation points at `time_ticks`.
///
/// This is the single interpolation contract shared by the project model, the
/// audio thread, and the Flutter curve painter. Values before the first point
/// hold the first value, values after the last point hold the last value.
/// Points sharing a tick form a vertical jump: the segment arriving at that
/// tick ends on the first of them, and from that tick on the last one applies.
/// Returns `None` when `points` is empty. Allocation-free and real-time safe.
#[inline]
pub fn interpolate_points(points: &[AutomationPoint], time_ticks: u32) -> Option<NormalizedF64> {
    interpolate_points_at(points, f64::from(time_ticks))
}

/// [`interpolate_points`] at a fractional tick, for drawing between ticks.
#[inline]
pub fn interpolate_points_at(points: &[AutomationPoint], time_ticks: f64) -> Option<NormalizedF64> {
    let first = points.first()?;
    if time_ticks < f64::from(first.time_ticks) {
        return Some(first.value);
    }

    // `p1` is the last point at or before the time, `p2` the first point after it.
    let idx = points.partition_point(|p| f64::from(p.time_ticks) <= time_ticks);
    let p1 = idx
        .checked_sub(1)
        .and_then(|previous| points.get(previous))?;
    let Some(p2) = points.get(idx) else {
        return Some(p1.value);
    };
    let duration = p2.time_ticks.saturating_sub(p1.time_ticks);
    if duration == 0 {
        return Some(p1.value);
    }

    let elapsed = time_ticks - f64::from(p1.time_ticks);
    let t = elapsed / f64::from(duration);
    Some(NormalizedF64::new(interpolate_segment(p1, p2.value, t)))
}

/// Evaluates the segment starting at `from` and ending at `to_value`.
///
/// `t` is the normalized position inside the segment. The curve type, tension, and Bezier
/// handles of the segment's FIRST point select the shape; see [`shape_segment`].
#[inline]
pub fn interpolate_segment(from: &AutomationPoint, to_value: NormalizedF64, t: f64) -> f64 {
    shape_segment(from.shape(), from.value.get(), to_value.get(), t)
}

/// Shapes a segment from `v1` to `v2` at normalized position `t`.
///
/// - Linear: tension bends the ramp (positive eases out, negative eases in).
/// - Exponential: geometric ramp; tension is inverted so dragging feels natural.
/// - Logarithmic: the exponential ramp mirrored, fast first and slow last.
/// - SCurve: ease-in-out; tension moves the steep part earlier or later.
/// - Step: holds the first value until the next point, tension is ignored.
/// - Bezier: cubic through the shape's handles, tension is ignored.
/// - Stairs, SmoothStairs, Pulse, Wave, Triangle: tension picks the step or cycle count, see
///   [`tension_count`].
/// - HalfSine: one arch toward `v2` and back; tension moves the peak.
///
/// Every curve returns `v2` at `t = 1`. Shared by automation lanes and gain envelopes so both
/// draw and play the same curves. Values may exceed 1.0 (envelope gain boosts); exponential and
/// logarithmic segments floor them at a small positive value to keep the ratio finite.
/// Allocation-free and real-time safe.
#[inline]
pub fn shape_segment(shape: SegmentShape, v1: f64, v2: f64, t: f64) -> f64 {
    let t = t.clamp(0.0, 1.0);
    if t >= 1.0 {
        return match shape.curve {
            AutomationCurveType::Exponential => v2.max(EXPONENTIAL_FLOOR),
            _ => v2,
        };
    }
    let tension = shape.tension;

    match shape.curve {
        AutomationCurveType::Linear => lerp(apply_tension_to_t(t, tension), v1, v2),
        AutomationCurveType::Exponential => {
            let v1 = v1.max(EXPONENTIAL_FLOOR);
            let v2 = v2.max(EXPONENTIAL_FLOOR);
            v1 * (v2 / v1).powf(apply_tension_to_t(t, -tension))
        }
        AutomationCurveType::Logarithmic => {
            // The exponential ramp from `v2` back to `v1`, reflected through the segment centre.
            let from = v2.max(EXPONENTIAL_FLOOR);
            let to = v1.max(EXPONENTIAL_FLOOR);
            v1 + v2 - from * (to / from).powf(apply_tension_to_t(t, tension))
        }
        AutomationCurveType::SCurve => lerp(smoothstep(apply_tension_to_t(t, tension)), v1, v2),
        AutomationCurveType::Step => v1,
        AutomationCurveType::Bezier => {
            let handles = shape
                .handles
                .unwrap_or_else(|| BezierHandles::straight(v1, v2));
            bezier_value(handles, v1, v2, t)
        }
        AutomationCurveType::Stairs => {
            let count = f64::from(tension_count(tension));
            lerp((t * count).floor() / count, v1, v2)
        }
        AutomationCurveType::SmoothStairs => {
            let count = f64::from(tension_count(tension));
            let position = t * count;
            let step = position.floor();
            lerp((step + smoothstep(position - step)) / count, v1, v2)
        }
        AutomationCurveType::Pulse => {
            if half_cycle(t, tension).0.is_multiple_of(2) {
                v1
            } else {
                v2
            }
        }
        AutomationCurveType::Wave => {
            let (half, phase) = half_cycle(t, tension);
            let rising = 0.5 - 0.5 * (phase * std::f64::consts::PI).cos();
            lerp(
                if half.is_multiple_of(2) {
                    rising
                } else {
                    1.0 - rising
                },
                v1,
                v2,
            )
        }
        AutomationCurveType::Triangle => {
            let (half, phase) = half_cycle(t, tension);
            lerp(
                if half.is_multiple_of(2) {
                    phase
                } else {
                    1.0 - phase
                },
                v1,
                v2,
            )
        }
        AutomationCurveType::HalfSine => {
            let arch = (apply_tension_to_t(t, tension) * std::f64::consts::PI).sin();
            lerp(arch, v1, v2)
        }
    }
}

/// Smallest value used by exponential segments so the ratio stays finite.
const EXPONENTIAL_FLOOR: f64 = 1e-4;

/// Step and cycle counts selectable by tension, from -1.0 to 1.0. Tension 0 selects 4.
const TENSION_COUNTS: [u32; 10] = [1, 2, 3, 4, 6, 8, 12, 16, 24, 32];

/// Index of the count selected by zero tension in [`TENSION_COUNTS`].
const NEUTRAL_COUNT_INDEX: f64 = 3.0;

/// Number of table entries above the neutral one.
const COUNTS_ABOVE_NEUTRAL: f64 = 6.0;

/// Count selected by zero tension.
const NEUTRAL_COUNT: u32 = 4;

/// Floors a non-negative finite value to `u32`, saturating at the type's bounds.
#[inline]
#[allow(
    clippy::as_conversions,
    reason = "float-to-int `as` saturates, which is the wanted behaviour here"
)]
fn floor_to_u32(value: f64) -> u32 {
    value as u32
}

/// Step or cycle count that `tension` selects for count-driven curves.
#[inline]
pub fn tension_count(tension: f64) -> u32 {
    let tension = if tension.is_finite() {
        tension.clamp(-1.0, 1.0)
    } else {
        0.0
    };
    let index = if tension < 0.0 {
        NEUTRAL_COUNT_INDEX + tension * NEUTRAL_COUNT_INDEX
    } else {
        NEUTRAL_COUNT_INDEX + tension * COUNTS_ABOVE_NEUTRAL
    };
    usize::try_from(floor_to_u32(index.round()))
        .ok()
        .and_then(|index| TENSION_COUNTS.get(index).copied())
        .unwrap_or(NEUTRAL_COUNT)
}

/// Splits `t` into the half cycle it falls in and the position inside that half cycle.
///
/// Oscillating curves run an odd number of half cycles so they leave `v1` and arrive at `v2`.
#[inline]
fn half_cycle(t: f64, tension: f64) -> (u32, f64) {
    let half_cycles = f64::from(tension_count(tension) * 2 - 1);
    let position = t * half_cycles;
    let half = position.floor();
    (floor_to_u32(half), position - half)
}

#[inline]
fn smoothstep(t: f64) -> f64 {
    t * t * (3.0 - 2.0 * t)
}

/// Value of the cubic Bezier from `(0, v1)` to `(1, v2)` at time fraction `t`.
///
/// The handles' time fractions stay inside 0.0–1.0, so time never runs backwards along the curve
/// and a fixed-length bisection finds the curve parameter without allocating.
#[inline]
fn bezier_value(handles: BezierHandles, v1: f64, v2: f64, t: f64) -> f64 {
    let x1 = handles.x1.clamp(0.0, 1.0);
    let x2 = handles.x2.clamp(0.0, 1.0);
    let cubic = |s: f64, p1: f64, p2: f64, p0: f64, p3: f64| {
        let r = 1.0 - s;
        r * r * r * p0 + 3.0 * r * r * s * p1 + 3.0 * r * s * s * p2 + s * s * s * p3
    };

    let (mut low, mut high) = (0.0_f64, 1.0_f64);
    for _ in 0..BEZIER_BISECTION_STEPS {
        let mid = 0.5 * (low + high);
        if cubic(mid, x1, x2, 0.0, 1.0) < t {
            low = mid;
        } else {
            high = mid;
        }
    }
    cubic(0.5 * (low + high), handles.y1, handles.y2, v1, v2)
}

/// Bisection steps used to invert a Bezier's time axis; 2^-32 of the segment is exact enough.
const BEZIER_BISECTION_STEPS: u32 = 32;

/// Maps a linear t ∈ [0,1] through a tension-controlled ease.
///
/// Uses a smoothstep-family blend:
///   tension = 0  → identity (t)
///   tension < 0  → ease-in  (t² weighted)
///   tension > 0  → ease-out (√t weighted)
///
/// The blend is continuous and always passes through (0,0) and (1,1).
fn apply_tension_to_t(t: f64, tension: f64) -> f64 {
    if tension == 0.0 {
        return t;
    }
    // smoothstep gives ease-in-out; t^2 gives ease-in; sqrt(t) gives ease-out.
    // Blend from identity toward the appropriate end based on sign.
    if tension < 0.0 {
        // ease-in: blend toward t²
        let alpha = -tension; // 0..1
        lerp(alpha, t, t * t)
    } else {
        // ease-out: blend toward √t
        let alpha = tension; // 0..1
        lerp(alpha, t, t.sqrt())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn point(
        time_ticks: u32,
        value: f64,
        curve_type: AutomationCurveType,
        tension: f64,
    ) -> AutomationPoint {
        AutomationPoint {
            id: AutomationPointId::default(),
            time_ticks,
            value: NormalizedF64::new(value),
            curve_type,
            tension: BipolarF64::new(tension),
            handles: None,
        }
    }

    fn value_at(points: &[AutomationPoint], time_ticks: u32) -> f64 {
        interpolate_points(points, time_ticks).map_or(f64::NAN, NormalizedF64::get)
    }

    #[test]
    fn holds_first_and_last_values_outside_the_points() {
        let points = [
            point(100, 0.2, AutomationCurveType::Linear, 0.0),
            point(200, 0.8, AutomationCurveType::Linear, 0.0),
        ];
        assert_eq!(value_at(&points, 0), 0.2);
        assert_eq!(value_at(&points, 5_000), 0.8);
        assert!(interpolate_points(&[], 10).is_none());
    }

    #[test]
    fn linear_tension_bends_the_segment_midpoint() {
        let flat = [
            point(0, 0.0, AutomationCurveType::Linear, 0.0),
            point(100, 1.0, AutomationCurveType::Linear, 0.0),
        ];
        let eased_out = [
            point(0, 0.0, AutomationCurveType::Linear, 1.0),
            point(100, 1.0, AutomationCurveType::Linear, 0.0),
        ];
        let eased_in = [
            point(0, 0.0, AutomationCurveType::Linear, -1.0),
            point(100, 1.0, AutomationCurveType::Linear, 0.0),
        ];
        assert!((value_at(&flat, 50) - 0.5).abs() < 1e-9);
        assert!((value_at(&eased_out, 25) - 0.5).abs() < 1e-9);
        assert!((value_at(&eased_in, 50) - 0.25).abs() < 1e-9);
    }

    #[test]
    fn step_holds_until_the_next_point_regardless_of_tension() {
        let points = [
            point(0, 0.1, AutomationCurveType::Step, 0.9),
            point(100, 0.9, AutomationCurveType::Linear, 0.0),
        ];
        assert_eq!(value_at(&points, 99), 0.1);
        assert_eq!(value_at(&points, 100), 0.9);
    }

    /// C at tick 0 (100%), A at tick 100 (50%), D at tick 200 (100%), then B added at A's tick.
    fn lane_with_point_added_on_occupied_tick() -> (AutomationLane, [AutomationPointId; 4]) {
        let mut lane =
            AutomationLane::new(AutomationId::default(), "Gain", NormalizedF64::new(0.5));
        let c = lane.add_point(AutomationPoint::new(0, NormalizedF64::new(1.0)));
        let a = lane.add_point(AutomationPoint::new(100, NormalizedF64::new(0.5)));
        let d = lane.add_point(AutomationPoint::new(200, NormalizedF64::new(1.0)));
        let b = lane.add_point(AutomationPoint::new(100, NormalizedF64::new(0.0)));
        (lane, [c, a, b, d])
    }

    fn ids(lane: &AutomationLane) -> Vec<AutomationPointId> {
        lane.points.iter().map(|p| p.id).collect()
    }

    #[test]
    fn point_added_on_an_occupied_tick_starts_the_next_segment() {
        let (lane, order) = lane_with_point_added_on_occupied_tick();
        assert_eq!(ids(&lane), order);

        // C -> A keeps ending on A, then the lane jumps to B and ramps B -> D.
        assert!((value_at(&lane.points, 50) - 0.75).abs() < 1e-9);
        assert_eq!(value_at(&lane.points, 100), 0.0);
        assert!((value_at(&lane.points, 150) - 0.5).abs() < 1e-9);
    }

    #[test]
    fn editing_a_point_on_a_shared_tick_keeps_the_order() {
        let (mut lane, order) = lane_with_point_added_on_occupied_tick();
        let [_, a, b, _] = order;

        for (point, value) in [(a, 0.9), (b, 0.3), (a, 0.1), (b, 0.8)] {
            let index = lane.update_point(
                point.to_u64(),
                Some(100),
                Some(NormalizedF64::new(value)),
                Some(BipolarF64::new(0.4)),
                None,
                None,
            );
            assert_eq!(
                lane.points.get(index.unwrap_or(usize::MAX)).map(|p| p.id),
                Some(point)
            );
            assert_eq!(ids(&lane), order);
        }
    }

    #[test]
    fn point_moved_onto_an_occupied_tick_goes_after_the_points_there() {
        let (mut lane, [c, a, b, d]) = lane_with_point_added_on_occupied_tick();

        lane.update_point(d.to_u64(), Some(100), None, None, None, None);

        assert_eq!(ids(&lane), [c, a, b, d]);
        lane.update_point(c.to_u64(), Some(100), None, None, None, None);
        assert_eq!(ids(&lane), [a, b, d, c]);
    }

    #[test]
    fn audio_lane_matches_project_lane_evaluation() {
        let mut lane =
            AutomationLane::new(AutomationId::default(), "Cutoff", NormalizedF64::new(0.5));
        lane.add_point(AutomationPoint::with_curve(
            0,
            NormalizedF64::new(0.1),
            AutomationCurveType::Exponential,
        ));
        lane.add_point(AutomationPoint::new(480, NormalizedF64::new(0.9)));
        lane.points[0].tension = BipolarF64::new(0.4);
        let audio_lane = crate::audio::render_state::AudioAutomationLane::from(lane.clone());

        for tick in [0, 120, 240, 360, 480, 960] {
            let expected = lane.value_at(tick).map_or(f64::NAN, NormalizedF64::get);
            assert_eq!(audio_lane.value_at_ticks(tick), expected);
        }
    }

    const ALL_CURVES: [AutomationCurveType; 12] = [
        AutomationCurveType::Linear,
        AutomationCurveType::Exponential,
        AutomationCurveType::Step,
        AutomationCurveType::Logarithmic,
        AutomationCurveType::SCurve,
        AutomationCurveType::Bezier,
        AutomationCurveType::Stairs,
        AutomationCurveType::SmoothStairs,
        AutomationCurveType::Pulse,
        AutomationCurveType::Wave,
        AutomationCurveType::Triangle,
        AutomationCurveType::HalfSine,
    ];

    fn shape(curve: AutomationCurveType, tension: f64) -> SegmentShape {
        SegmentShape::new(curve, tension)
    }

    #[test]
    fn every_curve_starts_on_the_first_value_and_ends_on_the_second() {
        for curve in ALL_CURVES {
            for tension in [-1.0, -0.4, 0.0, 0.4, 1.0] {
                let start = shape_segment(shape(curve, tension), 0.2, 0.8, 0.0);
                let end = shape_segment(shape(curve, tension), 0.2, 0.8, 1.0);
                assert!((start - 0.2).abs() < 1e-9, "{curve:?} starts at {start}");
                assert!((end - 0.8).abs() < 1e-9, "{curve:?} ends at {end}");
            }
        }
    }

    #[test]
    fn every_curve_stays_between_its_two_values() {
        for curve in ALL_CURVES {
            for tension in [-1.0, 0.0, 1.0] {
                for step in 0..=200 {
                    let value =
                        shape_segment(shape(curve, tension), 0.8, 0.2, f64::from(step) / 200.0);
                    assert!(
                        (0.2 - 1e-9..=0.8 + 1e-9).contains(&value),
                        "{curve:?} at step {step} gave {value}"
                    );
                }
            }
        }
    }

    #[test]
    fn exponential_follows_a_geometric_ramp() {
        let midpoint = shape_segment(shape(AutomationCurveType::Exponential, 0.0), 0.1, 0.9, 0.5);
        assert!((midpoint - 0.3).abs() < 1e-9);
    }

    #[test]
    fn tension_moves_bendable_curves_in_the_direction_their_traits_report() {
        for curve in ALL_CURVES {
            let traits = curve.traits();
            if !traits.supports_tension || traits.tension_is_count {
                continue;
            }
            let direction = if traits.tension_inverted { -1.0 } else { 1.0 };
            for (v1, v2) in [(0.2, 0.8), (0.8, 0.2)] {
                let rising = if v2 > v1 { 1.0 } else { -1.0 };
                let base = shape_segment(shape(curve, 0.0), v1, v2, 0.25);
                let bent = shape_segment(shape(curve, 0.5 * direction * rising), v1, v2, 0.25);
                assert!(bent > base, "{curve:?} from {v1} to {v2}");
            }
        }
    }

    #[test]
    fn logarithmic_mirrors_exponential() {
        for step in 0..=20 {
            let t = f64::from(step) / 20.0;
            let exponential =
                shape_segment(shape(AutomationCurveType::Exponential, 0.0), 0.1, 0.9, t);
            let logarithmic = shape_segment(
                shape(AutomationCurveType::Logarithmic, 0.0),
                0.1,
                0.9,
                1.0 - t,
            );
            assert!((exponential + logarithmic - 1.0).abs() < 1e-9);
        }
        // Logarithmic rises fast first, exponential rises slowly first.
        let log_mid = shape_segment(shape(AutomationCurveType::Logarithmic, 0.0), 0.1, 0.9, 0.5);
        let exp_mid = shape_segment(shape(AutomationCurveType::Exponential, 0.0), 0.1, 0.9, 0.5);
        assert!(log_mid > 0.5 && exp_mid < 0.5);
    }

    #[test]
    fn bezier_with_straight_handles_is_linear() {
        for handles in [None, Some(BezierHandles::straight(0.2, 0.8))] {
            let bezier = SegmentShape {
                curve: AutomationCurveType::Bezier,
                tension: 0.7,
                handles,
            };
            for step in 0..=10 {
                let t = f64::from(step) / 10.0;
                let value = shape_segment(bezier, 0.2, 0.8, t);
                assert!((value - (0.2 + 0.6 * t)).abs() < 1e-6);
            }
        }
    }

    #[test]
    fn bezier_handles_bend_the_segment() {
        let eased = SegmentShape {
            curve: AutomationCurveType::Bezier,
            tension: 0.0,
            handles: Some(BezierHandles {
                x1: 0.0,
                y1: 1.0,
                x2: 0.0,
                y2: 1.0,
            }),
        };
        let mut previous = 0.0;
        for step in 1..=20 {
            let value = shape_segment(eased, 0.0, 1.0, f64::from(step) / 20.0);
            assert!(value >= previous);
            previous = value;
        }
        assert!(shape_segment(eased, 0.0, 1.0, 0.25) > 0.6);
    }

    #[test]
    fn tension_selects_step_and_cycle_counts() {
        assert_eq!(tension_count(-1.0), 1);
        assert_eq!(tension_count(0.0), 4);
        assert_eq!(tension_count(1.0), 32);
        assert_eq!(tension_count(f64::NAN), 4);

        let stairs = shape(AutomationCurveType::Stairs, 0.0);
        assert_eq!(shape_segment(stairs, 0.0, 1.0, 0.24), 0.0);
        assert_eq!(shape_segment(stairs, 0.0, 1.0, 0.26), 0.25);
        assert_eq!(shape_segment(stairs, 0.0, 1.0, 0.99), 0.75);

        // One cycle count gives a single half cycle: low for the whole segment.
        let pulse = shape(AutomationCurveType::Pulse, -1.0);
        assert_eq!(shape_segment(pulse, 0.3, 0.9, 0.9), 0.3);
        // Two cycles give three half cycles: low, high, low.
        let pulse = shape(AutomationCurveType::Pulse, -0.67);
        assert_eq!(tension_count(-0.67), 2);
        assert_eq!(shape_segment(pulse, 0.3, 0.9, 0.5), 0.9);
        assert_eq!(shape_segment(pulse, 0.3, 0.9, 0.9), 0.3);
    }

    #[test]
    fn half_sine_peaks_on_the_second_value_mid_segment() {
        let arch = shape(AutomationCurveType::HalfSine, 0.0);
        assert!((shape_segment(arch, 0.2, 0.8, 0.5) - 0.8).abs() < 1e-9);
        assert!(shape_segment(arch, 0.2, 0.8, 0.95) < 0.35);
    }

    #[test]
    fn fractional_ticks_interpolate_between_whole_ticks() {
        let points = [
            point(0, 0.0, AutomationCurveType::Linear, 0.0),
            point(4, 1.0, AutomationCurveType::Linear, 0.0),
        ];
        let value = interpolate_points_at(&points, 0.5).map_or(f64::NAN, NormalizedF64::get);
        assert!((value - 0.125).abs() < 1e-12);
        assert_eq!(
            interpolate_points_at(&points, 2.0),
            interpolate_points(&points, 2)
        );
    }

    #[test]
    fn switching_to_bezier_adds_straight_handles() {
        let mut lane =
            AutomationLane::new(AutomationId::default(), "Gain", NormalizedF64::new(0.5));
        let first = lane.add_point(AutomationPoint::new(0, NormalizedF64::new(0.0)));
        lane.add_point(AutomationPoint::new(100, NormalizedF64::new(0.9)));

        lane.update_point(
            first.to_u64(),
            None,
            None,
            None,
            Some(AutomationCurveType::Bezier),
            None,
        );
        assert_eq!(
            lane.points[0].handles,
            Some(BezierHandles::straight(0.0, 0.9))
        );
        assert!((value_at(&lane.points, 50) - 0.45).abs() < 1e-6);

        let bent = BezierHandles {
            x1: 0.5,
            y1: 4.0,
            x2: -3.0,
            y2: 0.9,
        };
        lane.update_point(first.to_u64(), None, None, None, None, Some(bent));
        assert_eq!(
            lane.points[0].handles,
            Some(BezierHandles {
                x1: 0.5,
                y1: 1.0,
                x2: 0.0,
                y2: 0.9
            })
        );
    }

    fn ramp_lane() -> AutomationLane {
        let mut lane =
            AutomationLane::new(AutomationId::default(), "Gain", NormalizedF64::new(0.5));
        lane.add_point(AutomationPoint::new(0, NormalizedF64::new(0.0)));
        lane.add_point(AutomationPoint::with_curve(
            100,
            NormalizedF64::new(1.0),
            AutomationCurveType::Step,
        ));
        lane.add_point(AutomationPoint::new(200, NormalizedF64::new(0.5)));
        lane.add_point(AutomationPoint::new(400, NormalizedF64::new(0.5)));
        lane
    }

    fn times_and_values(points: &[AutomationPoint]) -> Vec<(u32, f64)> {
        points
            .iter()
            .map(|p| (p.time_ticks, p.value.get()))
            .collect()
    }

    #[test]
    fn extracting_a_range_cuts_the_curve_at_both_edges() {
        let lane = ramp_lane();

        let copied = lane.extract_range(50, 150);
        assert_eq!(times_and_values(&copied), [(0, 0.5), (50, 1.0), (100, 1.0)]);
        assert_eq!(copied[1].curve_type, AutomationCurveType::Step);

        // A range that starts and ends on points adds nothing.
        let exact = lane.extract_range(100, 200);
        assert_eq!(times_and_values(&exact), [(0, 1.0), (100, 0.5)]);
        assert!(
            AutomationLane::default().extract_range(0, 10).is_empty(),
            "an empty lane has no curve to copy"
        );
    }

    #[test]
    fn pasting_replaces_the_span_and_keeps_the_copied_shape() {
        let mut lane = ramp_lane();
        let copied = lane.extract_range(0, 100);

        let pasted = lane.paste_points(200, &copied, 100, None);
        assert_eq!(pasted.len(), 2);
        assert_eq!(
            times_and_values(&lane.points),
            [(0, 0.0), (100, 1.0), (200, 0.0), (300, 1.0), (400, 0.5)]
        );
        let mut ids: Vec<_> = lane.points.iter().map(|p| p.id.to_u64()).collect();
        ids.sort_unstable();
        ids.dedup();
        assert_eq!(ids.len(), lane.points.len(), "pasted points get new ids");
    }

    #[test]
    fn pasting_can_stretch_to_a_target_length() {
        let mut lane = ramp_lane();
        let copied = lane.extract_range(0, 100);

        lane.paste_points(1000, &copied, 100, Some(400));
        assert_eq!(
            times_and_values(&lane.points)[4..],
            [(1000, 0.0), (1400, 1.0)]
        );
    }

    #[test]
    fn deleting_a_range_removes_only_the_points_inside() {
        let mut lane = ramp_lane();
        assert_eq!(lane.delete_range(200, 100), 2);
        assert_eq!(times_and_values(&lane.points), [(0, 0.0), (400, 0.5)]);
    }

    #[test]
    fn points_round_trip_and_old_project_data_still_loads() {
        let bezier = AutomationPoint {
            handles: Some(BezierHandles::straight(0.1, 0.7)),
            ..point(10, 0.1, AutomationCurveType::Bezier, 0.0)
        };
        let mut json = serde_json::to_value(&bezier).unwrap_or_default();
        assert_eq!(
            serde_json::from_value::<AutomationPoint>(json.clone()).ok(),
            Some(bezier.clone())
        );

        // Points saved before Bezier handles existed have no `handles` field.
        if let Some(fields) = json.as_object_mut() {
            assert!(fields.remove("handles").is_some());
        }
        assert_eq!(
            serde_json::from_value::<AutomationPoint>(json).ok(),
            Some(AutomationPoint {
                handles: None,
                ..bezier
            })
        );

        // Lanes saved before they became purely normalized carry `min` and `max`.
        let lane = ramp_lane();
        let mut json = serde_json::to_value(&lane).unwrap_or_default();
        if let Some(fields) = json.as_object_mut() {
            fields.insert("min".to_owned(), serde_json::json!(-60.0));
            fields.insert("max".to_owned(), serde_json::json!(6.0));
        }
        assert_eq!(
            serde_json::from_value::<AutomationLane>(json).ok(),
            Some(lane)
        );
    }
}
