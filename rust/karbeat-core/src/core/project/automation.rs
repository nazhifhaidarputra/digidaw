// src/core/project/track/automation.rs
//
// Automation system for parameter modulation over time.
// Provides both project-level automation lane data (saved with the project)
// and a runtime AutomationManager used by plugin wrappers during audio processing.

use std::sync::atomic::AtomicU64;

use karbeat_dsp::interpolation::lerp;
use karbeat_utils::types::{BipolarF64, NormalizedF64};
use serde::{Deserialize, Serialize};

use crate::{
    audio::event::PluginTarget,
    shared::{
        id::{AutomationId, BusId, EffectId, TrackId},
        GeneratorId,
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
    Generator {
        generator_id: GeneratorId,
        param_id: u32,
    },
    Track {
        track_id: TrackId,
        track_target: TrackAutomationTarget,
    },

    Bus {
        bus_id: BusId,
        mix_target: MixerChannelParamTarget,
    },

    Master(MasterAutomationTarget),
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq, Hash)]
pub enum TrackAutomationTarget {
    MixerChannel(MixerChannelParamTarget),
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq, Hash)]
pub enum MasterAutomationTarget {
    MixerChannel(MixerChannelParamTarget),
    TempoBpm,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq, Hash)]
pub enum MixerChannelParamTarget {
    Volume,
    Pan,
    Plugin {
        effect_id: EffectId,
        target: EffectAutomationTarget,
    },
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq, Hash)]
pub enum EffectAutomationTarget {
    Mix, // NOTE: This is unused for a moment. might use it later
    PluginParam { param_id: u32 },
}

impl AutomationTarget {
    /// Returns true if this target references the given track ID.
    pub fn references_track(&self, id: TrackId) -> bool {
        match self {
            AutomationTarget::Track { track_id, .. } => *track_id == id,
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
    pub id: u64,
    /// Position in ticks (relative to project start)
    pub time_ticks: u32,
    /// Normalized parameter value (0.0–1.0)
    pub value: NormalizedF64,
    /// Interpolation curve to the NEXT point
    pub curve_type: AutomationCurveType,
    /// Bipolar tension control (-1.0 to 1.0)
    pub tension: BipolarF64,
}

static POINT_ID_COUNTER: AtomicU64 = AtomicU64::new(1);

impl AutomationPoint {
    fn next_id() -> u64 {
        POINT_ID_COUNTER.fetch_add(1, std::sync::atomic::Ordering::Relaxed)
    }

    pub fn new(time_ticks: u32, value: NormalizedF64) -> Self {
        Self {
            id: Self::next_id(),
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
            id: Self::next_id(),
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
    pub id: AutomationId,
    /// Human-readable label (e.g. "Volume", "Filter Cutoff")
    pub label: String,
    /// Automation points sorted by time
    pub points: Vec<AutomationPoint>,
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
            enabled: true,
            min,
            max,
            default_value: normalized_value,
        }
    }

    /// Add a point to the lane (maintains sorted order by time).
    pub fn add_point(&mut self, point: AutomationPoint) {
        let idx = self
            .points
            .binary_search_by(|p| p.time_ticks.cmp(&point.time_ticks))
            .unwrap_or_else(|i| i);
        self.points.insert(idx, point);
    }

    /// Remove a point at the given index.
    pub fn remove_point(&mut self, id: u64) -> Option<AutomationPoint> {
        let index = self.points.iter().position(|p| p.id == id)?;
        Some(self.points.remove(index))
    }

    /// Update a point at the given index.
    pub fn update_point(
        &mut self,
        id: u64,
        time_ticks: Option<u32>,
        value: Option<NormalizedF64>,
        tension: Option<BipolarF64>,
        curve_type: Option<AutomationCurveType>,
    ) -> Option<usize> {
        let index = self.points.iter().position(|p| p.id == id)?;

        let mut point = self.points.remove(index);
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

        let new_index = match self
            .points
            .binary_search_by(|p| p.time_ticks.cmp(&point.time_ticks))
        {
            Ok(pos) => pos,
            Err(pos) => pos,
        };

        self.points.insert(new_index, point);

        Some(new_index)
    }

    /// Get the interpolated normalized value (0.0–1.0) at a given time in ticks.
    /// Returns `None` if the lane is disabled or has no points.
    pub fn value_at(&self, time_ticks: u32) -> Option<NormalizedF64> {
        if !self.enabled || self.points.is_empty() {
            return None;
        }

        // Before first point: return first point's value
        if time_ticks <= self.points[0].time_ticks {
            return Some(self.points[0].value);
        }

        // After last point: return last point's value
        let last = self.points.last()?;
        if time_ticks >= last.time_ticks {
            return Some(last.value);
        }

        // Find surrounding points using binary search
        let idx = self
            .points
            .binary_search_by(|p| p.time_ticks.cmp(&time_ticks))
            .unwrap_or_else(|i| i);

        // idx is where we'd insert, so points[idx-1] <= time < points[idx]
        if idx == 0 {
            return Some(self.points[0].value);
        }

        let p1 = &self.points[idx - 1];
        let p2 = &self.points[idx];

        // Calculate interpolation factor (0.0 to 1.0)
        let duration = p2.time_ticks.saturating_sub(p1.time_ticks);
        if duration == 0 {
            return Some(p1.value);
        }

        let t = ((time_ticks - p1.time_ticks) as f64) / (duration as f64);
        let tension = p1.tension.get();

        // Interpolate based on curve type of the FIRST point
        let value = match p1.curve_type {
            AutomationCurveType::Linear => {
                let t_shaped = apply_tension_to_t(t, tension);
                lerp(t_shaped, p1.value.get(), p2.value.get())
            }
            AutomationCurveType::Exponential => {
                let v1 = p1.value.get().max(1e-4);
                let v2 = p2.value.get().max(1e-4);
                let t_biased = apply_tension_to_t(t, -tension); // inverted: feels natural
                v1 * (v2 / v1).powf(t_biased)
            }
            AutomationCurveType::Step => {
                let jump_at = 0.5 + tension * 0.5; // maps [-1,1] → [0,1]
                if t < jump_at {
                    p1.value.get()
                } else {
                    p2.value.get()
                }
            }
        };

        Some(NormalizedF64::new(value))
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

// Maps a linear t ∈ [0,1] through a tension-controlled cubic ease.
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
