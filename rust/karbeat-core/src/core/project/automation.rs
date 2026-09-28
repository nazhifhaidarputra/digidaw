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
// ============================================================================
// CURVE TYPES
// ============================================================================

/// Interpolation curve type between automation points
#[derive(Clone, Copy, Debug, Default, PartialEq, Serialize, Deserialize)]
pub enum AutomationCurveType {
    /// Linear interpolation between points
    #[default]
    Linear,
    /// Exponential curve (good for frequency, volume)
    Exponential,
    /// Instant step (no interpolation)
    Step,
}

// ============================================================================
// AUTOMATION POINT
// ============================================================================

/// A single point on an automation lane.
///
/// Values are stored in normalized form (0.0–1.0). The lane's `min`/`max`
/// fields define the mapping to the actual parameter range.
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
}

impl AutomationPoint {
    /// Creates a linear point at `time_ticks`; normalized values are already range-safe by type.
    pub fn new(time_ticks: u32, value: NormalizedF64) -> Self {
        Self {
            id: AutomationPointId::default(),
            time_ticks,
            value,
            curve_type: AutomationCurveType::Linear,
            tension: BipolarF64::default(),
        }
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
        }
    }
}

// ============================================================================
// AUTOMATION LANE
// ============================================================================

/// An automation lane that controls a single parameter.
///
/// Lives in `ApplicationState::automation_pool` and is serialized with the project.
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
    /// Minimum value of the target parameter (for display/denormalization)
    pub min: f64,
    /// Maximum value of the target parameter (for display/denormalization)
    pub max: f64,
    /// Default value of the target parameter (normalized 0.0–1.0)
    pub default_value: NormalizedF64,
}

impl AutomationLane {
    /// Create a new empty automation lane for the given target on the given track.
    pub fn new(
        id: AutomationId,
        label: impl Into<String>,
        min: f64,
        max: f64,
        default_value: f64,
    ) -> Self {
        let normalized_value = NormalizedF64::from_range(default_value, min, max);
        Self {
            id,
            label: label.into(),
            points: Vec::new(),
            next_point_id: 0,
            enabled: true,
            min,
            max,
            default_value: normalized_value,
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
    /// [`Self::add_point`].
    pub fn update_point(
        &mut self,
        id: u64,
        time_ticks: Option<u32>,
        value: Option<NormalizedF64>,
        tension: Option<BipolarF64>,
        curve_type: Option<AutomationCurveType>,
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

    /// Convert a normalized value (0.0–1.0) to the actual parameter value.
    pub fn denormalize(&self, normalized: NormalizedF64) -> f64 {
        self.min + normalized.get() * (self.max - self.min)
    }

    /// Convert an actual parameter value to normalized (0.0–1.0).
    pub fn normalize(&self, value: f64) -> NormalizedF64 {
        if (self.max - self.min).abs() < f64::EPSILON {
            return NormalizedF64::new(0.0);
        }
        NormalizedF64::new((value - self.min) / (self.max - self.min))
    }

    /// Get the denormalized value at a given time in ticks.
    pub fn denormalized_value_at(&self, time_ticks: u32) -> Option<f64> {
        self.value_at(time_ticks).map(|v| self.denormalize(v))
    }

    /// Clear all points.
    pub fn clear(&mut self) {
        self.points.clear();
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
    let first = points.first()?;
    if time_ticks < first.time_ticks {
        return Some(first.value);
    }

    // `p1` is the last point at or before the time, `p2` the first point after it.
    let idx = insertion_index_after(points, time_ticks);
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

    let elapsed = time_ticks.saturating_sub(p1.time_ticks);
    let t = f64::from(elapsed) / f64::from(duration);
    Some(NormalizedF64::new(interpolate_segment(p1, p2.value, t)))
}

/// Evaluates the segment starting at `from` and ending at `to_value`.
///
/// `t` is the normalized position inside the segment. The curve type and the
/// tension of the segment's FIRST point select the shape:
/// - Linear: tension bends the ramp (positive eases out, negative eases in).
/// - Exponential: geometric ramp; tension is inverted so dragging feels natural.
/// - Step: holds the first value until the next point, tension is ignored.
#[inline]
pub fn interpolate_segment(from: &AutomationPoint, to_value: NormalizedF64, t: f64) -> f64 {
    let t = t.clamp(0.0, 1.0);
    let tension = from.tension.get();
    let v1 = from.value.get();
    let v2 = to_value.get();

    match from.curve_type {
        AutomationCurveType::Linear => lerp(apply_tension_to_t(t, tension), v1, v2),
        AutomationCurveType::Exponential => {
            let v1 = v1.max(EXPONENTIAL_FLOOR);
            let v2 = v2.max(EXPONENTIAL_FLOOR);
            v1 * (v2 / v1).powf(apply_tension_to_t(t, -tension))
        }
        AutomationCurveType::Step => {
            if t < 1.0 {
                v1
            } else {
                v2
            }
        }
    }
}

/// Smallest value used by exponential segments so the ratio stays finite.
const EXPONENTIAL_FLOOR: f64 = 1e-4;

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
        let mut lane = AutomationLane::new(AutomationId::default(), "Gain", 0.0, 1.0, 0.5);
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

        lane.update_point(d.to_u64(), Some(100), None, None, None);

        assert_eq!(ids(&lane), [c, a, b, d]);
        lane.update_point(c.to_u64(), Some(100), None, None, None);
        assert_eq!(ids(&lane), [a, b, d, c]);
    }

    #[test]
    fn audio_lane_matches_project_lane_evaluation() {
        let mut lane = AutomationLane::new(AutomationId::default(), "Cutoff", 0.0, 1.0, 0.5);
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
}
