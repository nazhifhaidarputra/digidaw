//! Automation curves and looping of one audio clip.
//!
//! Curve positions count project-rate samples of the clip content, the unit of `offset_start`,
//! like the points of a clip's gain envelope. Volume stays on [`super::GainEnvelope`]; this adds
//! pan, pitch, and a loop whose repeat length can follow a curve.
//!
//! A loop plays the clip's first `time` samples again and again. Each repeat's length is the loop
//! time at the moment the repeat starts, so a falling curve gives faster and faster repeats. The
//! start of every repeat is computed ahead of time by [`ClipModulation::normalized`], so the audio
//! thread finds its place with a binary search wherever playback lands.
//!
//! Every evaluation function here is allocation-free and real-time safe.

use karbeat_utils::types::BipolarF64;
use serde::{Deserialize, Serialize};

use super::automation::{AutomationCurveType, SegmentShape, shape_segment};

/// Largest pitch curve offset in cents, in either direction (two octaves).
pub const MAX_CLIP_PITCH_CENTS: f64 = 2400.0;
/// Shortest loop time in samples, about 1.3 ms at 48 kHz.
pub const MIN_CLIP_LOOP_SAMPLES: u64 = 64;
/// Most repeat starts kept per clip. A curve that needs more plays its last value from there on.
const MAX_LOOP_RESTARTS: usize = 1 << 20;

/// One breakpoint of a clip curve.
#[derive(Clone, Copy, Debug, PartialEq, Serialize, Deserialize)]
#[serde(default)]
pub struct CurvePoint {
    /// Position in project-rate samples of the clip content.
    pub position: u64,
    /// Value in the unit of the curve: pan -1.0 to 1.0, pitch in cents, loop time in samples.
    pub value: f64,
    /// Curve toward the next point.
    pub curve_type: AutomationCurveType,
    /// Bipolar tension of the curve toward the next point.
    pub tension: BipolarF64,
}

impl Default for CurvePoint {
    fn default() -> Self {
        Self {
            position: 0,
            value: 0.0,
            curve_type: AutomationCurveType::Linear,
            tension: BipolarF64::default(),
        }
    }
}

/// Value of `points` at `pos`. Before the first point the first value holds, after the last point
/// the last value holds. `None` without points.
///
/// Segments are shaped in the 0.0 to 1.0 range `to_unit` converts into, like automation lanes:
/// exponential and logarithmic shapes floor their values at a small positive number, so a bipolar
/// value would not reach its endpoints.
#[inline]
fn curve_value(
    points: &[CurvePoint],
    pos: u64,
    to_unit: impl Fn(f64) -> f64,
    from_unit: impl Fn(f64) -> f64,
) -> Option<f64> {
    let first = points.first()?;
    let next = points.partition_point(|point| point.position <= pos);
    let Some(from) = next.checked_sub(1).and_then(|index| points.get(index)) else {
        return Some(first.value);
    };
    let Some(to) = points.get(next) else {
        return Some(from.value);
    };
    let t = (pos - from.position) as f64 / (to.position - from.position) as f64;
    Some(from_unit(shape_segment(
        SegmentShape::new(from.curve_type, from.tension.get()),
        to_unit(from.value),
        to_unit(to.value),
        t,
    )))
}

/// Octaves of the shortest and longest loop times, the range loop curves are shaped in.
const LOOP_OCTAVES: (f64, f64) = (6.0, 32.0);

fn normalize_curve(points: &mut Vec<CurvePoint>, fallback: f64, min: f64, max: f64) {
    for point in points.iter_mut() {
        point.value = if point.value.is_finite() {
            point.value.clamp(min, max)
        } else {
            fallback
        };
        point.tension = BipolarF64::new(point.tension.get());
    }
    points.sort_by_key(|point| point.position);
    // Two points on one sample would make an empty segment.
    points.dedup_by_key(|point| point.position);
}

fn scale_curve(points: &mut [CurvePoint], factor: f64) {
    for point in points {
        point.position = (point.position as f64 * factor).round() as u64;
    }
}

/// Repeating part of a clip.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
#[serde(default)]
pub struct ClipLoop {
    /// Whether the clip repeats instead of playing straight through.
    pub enabled: bool,
    /// Repeat length in project samples when `curve` has no points.
    pub time: u64,
    /// Repeat length in samples over the clip. Shaped in octaves, so halving the loop time takes
    /// equally long at every length.
    pub curve: Vec<CurvePoint>,
}

impl Default for ClipLoop {
    fn default() -> Self {
        Self {
            enabled: false,
            time: 12_000,
            curve: Vec::new(),
        }
    }
}

impl ClipLoop {
    fn time_at(&self, pos: u64) -> u64 {
        let (low, high) = LOOP_OCTAVES;
        curve_value(
            &self.curve,
            pos,
            |samples| (samples.log2() - low) / (high - low),
            |unit| (low + unit * (high - low)).exp2(),
        )
        .map_or(self.time, |samples| samples.round() as u64)
        .max(MIN_CLIP_LOOP_SAMPLES)
    }

    /// Length of every repeat after the curve's last point.
    fn tail_time(&self) -> u64 {
        self.curve
            .last()
            .map_or(self.time, |point| point.value.round() as u64)
            .max(MIN_CLIP_LOOP_SAMPLES)
    }
}

/// Where playback is inside a clip's loop.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct LoopPhase {
    /// Samples since the current repeat started.
    pub into: u64,
    /// Length of the current repeat.
    pub length: u64,
}

/// Pan, pitch, and loop of one audio clip. Build it with [`Self::new`], and call
/// [`Self::normalized`] after changing the public fields, which recomputes the repeat starts.
#[derive(Clone, Debug, Default, PartialEq, Serialize, Deserialize)]
#[serde(from = "StoredClipModulation")]
pub struct ClipModulation {
    /// Stereo balance over the clip, -1.0 (left) to 1.0 (right).
    pub pan: Vec<CurvePoint>,
    /// Pitch offset over the clip in cents.
    pub pitch: Vec<CurvePoint>,
    /// Repeating part of the clip.
    pub looping: ClipLoop,
    /// Content position of each repeat start, from zero through the loop curve's last point.
    /// Empty without a curve.
    #[serde(skip)]
    restarts: Vec<u64>,
}

/// The saved fields; loading goes through [`ClipModulation::new`] to rebuild the repeat starts.
#[derive(Deserialize, Default)]
#[serde(default)]
struct StoredClipModulation {
    pan: Vec<CurvePoint>,
    pitch: Vec<CurvePoint>,
    looping: ClipLoop,
}

impl From<StoredClipModulation> for ClipModulation {
    fn from(stored: StoredClipModulation) -> Self {
        Self::new(stored.pan, stored.pitch, stored.looping)
    }
}

impl ClipModulation {
    /// Builds a normalized modulation from its curves and loop.
    #[must_use]
    pub fn new(pan: Vec<CurvePoint>, pitch: Vec<CurvePoint>, looping: ClipLoop) -> Self {
        Self {
            pan,
            pitch,
            looping,
            restarts: Vec::new(),
        }
        .normalized()
    }

    /// Sorts curves, clamps values into range, and recomputes the repeat starts. Non-finite
    /// values become neutral. Allocates, so it never runs on the audio thread.
    #[must_use]
    pub fn normalized(mut self) -> Self {
        let min_time = MIN_CLIP_LOOP_SAMPLES as f64;
        self.looping.time = self.looping.time.max(MIN_CLIP_LOOP_SAMPLES);
        normalize_curve(&mut self.pan, 0.0, -1.0, 1.0);
        normalize_curve(
            &mut self.pitch,
            0.0,
            -MAX_CLIP_PITCH_CENTS,
            MAX_CLIP_PITCH_CENTS,
        );
        normalize_curve(
            &mut self.looping.curve,
            self.looping.time as f64,
            min_time,
            f64::from(u32::MAX),
        );

        self.restarts.clear();
        if let Some(last) = self.looping.curve.last().map(|point| point.position) {
            self.restarts.push(0);
            let mut pos = 0;
            while pos < last && self.restarts.len() < MAX_LOOP_RESTARTS {
                pos += self.looping.time_at(pos);
                self.restarts.push(pos);
            }
        }
        self
    }

    /// This modulation with every position and loop time scaled by `factor`, for clip content
    /// that now plays `factor` times as long.
    #[must_use]
    pub fn scaled(&self, factor: f64) -> Self {
        let mut scaled = self.clone();
        scale_curve(&mut scaled.pan, factor);
        scale_curve(&mut scaled.pitch, factor);
        scale_curve(&mut scaled.looping.curve, factor);
        for point in &mut scaled.looping.curve {
            point.value *= factor;
        }
        scaled.looping.time = (scaled.looping.time as f64 * factor).round() as u64;
        scaled.normalized()
    }

    /// Whether the modulation leaves the clip untouched and holds nothing worth keeping. A loop
    /// that was set up and then turned off keeps its settings.
    pub fn is_identity(&self) -> bool {
        self.pan.is_empty() && self.pitch.is_empty() && self.looping == ClipLoop::default()
    }

    /// Whether the clip repeats.
    #[inline]
    pub fn loops(&self) -> bool {
        self.looping.enabled
    }

    /// Whether a pitch curve moves the clip's pitch.
    #[inline]
    pub fn has_pitch(&self) -> bool {
        !self.pitch.is_empty()
    }

    /// Whether a pan curve moves the clip's balance.
    #[inline]
    pub fn has_pan(&self) -> bool {
        !self.pan.is_empty()
    }

    /// Pan at content position `pos`, -1.0 to 1.0.
    #[inline]
    pub fn pan_at(&self, pos: u64) -> f64 {
        curve_value(
            &self.pan,
            pos,
            |pan| (pan + 1.0) / 2.0,
            |unit| unit * 2.0 - 1.0,
        )
        .unwrap_or(0.0)
    }

    /// Pitch offset at content position `pos` in cents.
    #[inline]
    pub fn pitch_cents_at(&self, pos: u64) -> f64 {
        curve_value(
            &self.pitch,
            pos,
            |cents| (cents + MAX_CLIP_PITCH_CENTS) / (2.0 * MAX_CLIP_PITCH_CENTS),
            |unit| unit * 2.0 * MAX_CLIP_PITCH_CENTS - MAX_CLIP_PITCH_CENTS,
        )
        .unwrap_or(0.0)
    }

    /// Frequency multiplier at content position `pos`.
    #[inline]
    pub fn pitch_scale_at(&self, pos: u64) -> f64 {
        (self.pitch_cents_at(pos) / 1200.0).exp2()
    }

    /// Loop time at content position `pos` in samples.
    #[inline]
    pub fn loop_time_at(&self, pos: u64) -> u64 {
        self.looping.time_at(pos)
    }

    /// Left and right gains of a stereo balance, unity at the center, so a flat pan curve leaves
    /// the level alone.
    #[inline]
    pub fn balance_gains(pan: f64) -> (f32, f32) {
        let pan = pan as f32;
        ((1.0 - pan).min(1.0), (1.0 + pan).min(1.0))
    }

    /// Phase of the loop `elapsed` samples into a clip whose content starts at `offset`.
    ///
    /// The clip's first frame always starts a repeat, so a clip cut or trimmed mid-loop still
    /// repeats from its own start; the repeat lengths then follow the curve from the nearest
    /// repeat at or before `offset`.
    #[inline]
    pub fn loop_phase(&self, offset: u64, elapsed: u64) -> LoopPhase {
        let tail = self.looping.tail_time();
        let starts = self.restarts.as_slice();
        let start_at = |pos: u64| {
            starts
                .partition_point(|start| *start <= pos)
                .saturating_sub(1)
        };
        let Some(anchor) = starts.get(start_at(offset)) else {
            return LoopPhase {
                into: elapsed % tail,
                length: tail,
            };
        };
        let pos = anchor + elapsed;
        let index = start_at(pos);
        let (Some(start), next) = (starts.get(index), starts.get(index + 1)) else {
            return LoopPhase {
                into: elapsed % tail,
                length: tail,
            };
        };
        match next {
            Some(next) => LoopPhase {
                into: pos - start,
                length: next - start,
            },
            None => LoopPhase {
                into: (pos - start) % tail,
                length: tail,
            },
        }
    }

    /// Clip-relative samples where repeats start in a clip of `length` samples whose content
    /// starts at `offset`, at most `limit` of them, for drawing.
    pub fn loop_starts(&self, offset: u64, length: u64, limit: usize) -> Vec<u64> {
        let mut starts = Vec::new();
        let mut elapsed = 0;
        while elapsed < length && starts.len() < limit {
            starts.push(elapsed);
            let phase = self.loop_phase(offset, elapsed);
            elapsed += phase.length - phase.into;
        }
        starts
    }
}

#[cfg(test)]
#[allow(
    clippy::unwrap_used,
    reason = "serialization failures should fail these tests"
)]
mod tests {
    use super::*;

    fn point(position: u64, value: f64) -> CurvePoint {
        CurvePoint {
            position,
            value,
            ..CurvePoint::default()
        }
    }

    fn looping(time: u64, curve: Vec<CurvePoint>) -> ClipModulation {
        ClipModulation::new(
            Vec::new(),
            Vec::new(),
            ClipLoop {
                enabled: true,
                time,
                curve,
            },
        )
    }

    #[test]
    fn default_modulation_is_identity() {
        let modulation = ClipModulation::default();
        assert!(modulation.is_identity());
        assert!(!modulation.loops());
        assert_eq!(modulation.pan_at(100), 0.0);
        assert_eq!(modulation.pitch_scale_at(100), 1.0);
    }

    #[test]
    fn curves_hold_their_ends_and_interpolate_between_points() {
        let modulation = ClipModulation::new(
            vec![point(100, -1.0), point(200, 1.0)],
            vec![point(0, 0.0), point(100, 1200.0)],
            ClipLoop::default(),
        );
        assert_eq!(modulation.pan_at(0), -1.0);
        assert!(modulation.pan_at(150).abs() < 1e-9);
        assert_eq!(modulation.pan_at(500), 1.0);
        assert!((modulation.pitch_scale_at(100) - 2.0).abs() < 1e-9);
        assert!((modulation.pitch_cents_at(50) - 600.0).abs() < 1e-9);
    }

    fn bent(
        position: u64,
        value: f64,
        curve_type: AutomationCurveType,
        tension: f64,
    ) -> CurvePoint {
        CurvePoint {
            position,
            value,
            curve_type,
            tension: BipolarF64::new(tension),
        }
    }

    #[test]
    fn tension_bends_every_curve_between_the_same_ends() {
        let pan = |tension| {
            ClipModulation::new(
                vec![
                    bent(0, -1.0, AutomationCurveType::Linear, tension),
                    point(1_000, 1.0),
                ],
                Vec::new(),
                ClipLoop::default(),
            )
        };
        assert!(pan(0.0).pan_at(500).abs() < 1e-9);
        assert!(pan(0.8).pan_at(500) > 0.1);
        assert!(pan(-0.8).pan_at(500) < -0.1);
        for tension in [-0.8, 0.0, 0.8] {
            assert_eq!(pan(tension).pan_at(0), -1.0);
            assert_eq!(pan(tension).pan_at(1_000), 1.0);
        }
    }

    #[test]
    fn tension_moves_the_repeats_of_a_loop_curve() {
        let starts = |tension| {
            looping(
                4_000,
                vec![
                    bent(0, 4_000.0, AutomationCurveType::Linear, tension),
                    point(16_000, 500.0),
                ],
            )
            .loop_starts(0, 16_000, 64)
        };
        assert_ne!(starts(0.8), starts(0.0));
        assert_ne!(starts(-0.8), starts(0.0));
    }

    #[test]
    fn exponential_and_logarithmic_shapes_reach_negative_values() {
        for curve_type in [
            AutomationCurveType::Exponential,
            AutomationCurveType::Logarithmic,
        ] {
            let modulation = ClipModulation::new(
                vec![bent(0, -1.0, curve_type, 0.0), point(1_000, 1.0)],
                vec![bent(0, -1_200.0, curve_type, 0.0), point(1_000, 1_200.0)],
                ClipLoop::default(),
            );
            assert!(modulation.pan_at(1) < -0.9, "{curve_type:?}");
            assert!(modulation.pan_at(999) > 0.9, "{curve_type:?}");
            assert!(modulation.pitch_cents_at(1) < -1_100.0, "{curve_type:?}");
            assert!(modulation.pitch_cents_at(999) > 1_100.0, "{curve_type:?}");
            let mid = modulation.pan_at(500);
            assert!(mid > -1.0 && mid < 1.0, "{curve_type:?} {mid}");
        }
    }

    #[test]
    fn normalized_sorts_clamps_and_drops_duplicate_positions() {
        let modulation = ClipModulation::new(
            vec![point(50, 5.0), point(10, f64::NAN), point(10, 0.5)],
            vec![point(0, 99_999.0)],
            ClipLoop::default(),
        );
        let positions: Vec<_> = modulation.pan.iter().map(|p| p.position).collect();
        assert_eq!(positions, [10, 50]);
        assert_eq!(modulation.pan[0].value, 0.0);
        assert_eq!(modulation.pan[1].value, 1.0);
        assert_eq!(modulation.pitch[0].value, MAX_CLIP_PITCH_CENTS);
    }

    #[test]
    fn balance_is_unity_at_the_center() {
        assert_eq!(ClipModulation::balance_gains(0.0), (1.0, 1.0));
        assert_eq!(ClipModulation::balance_gains(-1.0), (1.0, 0.0));
        assert_eq!(ClipModulation::balance_gains(1.0), (0.0, 1.0));
        assert_eq!(ClipModulation::balance_gains(0.5), (0.5, 1.0));
    }

    #[test]
    fn constant_loop_repeats_from_the_clip_start() {
        let modulation = looping(1_000, Vec::new());
        assert_eq!(
            modulation.loop_phase(0, 2_500),
            LoopPhase {
                into: 500,
                length: 1_000
            }
        );
        // An offset does not shift the repeats: the clip's first frame starts one.
        assert_eq!(
            modulation.loop_phase(777, 2_500),
            LoopPhase {
                into: 500,
                length: 1_000
            }
        );
    }

    #[test]
    fn loop_time_is_clamped_to_the_minimum() {
        let modulation = looping(1, Vec::new());
        assert_eq!(modulation.looping.time, MIN_CLIP_LOOP_SAMPLES);
        assert_eq!(modulation.loop_phase(0, 0).length, MIN_CLIP_LOOP_SAMPLES);
    }

    #[test]
    fn falling_curve_makes_repeats_shorter() {
        let modulation = looping(4_000, vec![point(0, 4_000.0), point(16_000, 500.0)]);
        let starts = modulation.loop_starts(0, 16_000, 64);
        let lengths: Vec<_> = starts.windows(2).map(|pair| pair[1] - pair[0]).collect();
        assert_eq!(starts[0], 0);
        assert_eq!(lengths[0], 4_000);
        assert!(
            lengths.windows(2).all(|pair| pair[1] < pair[0]),
            "{lengths:?}"
        );
        assert!(*lengths.last().unwrap() < 1_000);
    }

    #[test]
    fn loop_time_is_shaped_in_octaves() {
        let modulation = looping(1_000, vec![point(0, 4_000.0), point(1_000, 1_000.0)]);
        assert_eq!(modulation.loop_time_at(500), 2_000);
    }

    #[test]
    fn loop_phase_matches_a_walk_through_the_repeats() {
        let modulation = looping(4_000, vec![point(0, 4_000.0), point(16_000, 500.0)]);
        let starts = modulation.loop_starts(0, 40_000, 1_000);
        for pair in starts.windows(2) {
            let phase = modulation.loop_phase(0, pair[0]);
            assert_eq!(phase.into, 0);
            assert_eq!(phase.length, pair[1] - pair[0]);
            assert_eq!(modulation.loop_phase(0, pair[1] - 1).into, phase.length - 1);
        }
        // Past the curve the last value repeats forever.
        assert_eq!(modulation.loop_phase(0, 39_000).length, 500);
    }

    #[test]
    fn a_clip_cut_mid_repeat_starts_a_repeat_at_its_own_first_frame() {
        let modulation = looping(4_000, vec![point(0, 4_000.0), point(16_000, 500.0)]);
        let phase = modulation.loop_phase(1_000, 0);
        assert_eq!(phase.into, 0);
        assert_eq!(phase.length, 4_000);
    }

    #[test]
    fn scaling_scales_times_and_positions() {
        let modulation = looping(1_000, vec![point(100, 2_000.0)]).scaled(2.0);
        assert_eq!(modulation.looping.time, 2_000);
        assert_eq!(modulation.looping.curve[0].position, 200);
        assert_eq!(modulation.looping.curve[0].value, 4_000.0);
    }

    #[test]
    fn loading_rebuilds_the_repeat_starts() {
        let modulation = looping(4_000, vec![point(0, 4_000.0), point(16_000, 500.0)]);
        let json = serde_json::to_string(&modulation).unwrap();
        assert!(!json.contains("restarts"));
        let restored: ClipModulation = serde_json::from_str(&json).unwrap();
        assert_eq!(restored, modulation);
        assert_eq!(
            restored.loop_phase(0, 5_000),
            modulation.loop_phase(0, 5_000)
        );
    }

    #[test]
    fn missing_fields_load_as_defaults() {
        let restored: ClipModulation = serde_json::from_str("{}").unwrap();
        assert!(restored.is_identity());
    }
}
