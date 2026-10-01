//! Gain envelopes for audio waveforms and audio clips.
//!
//! A waveform envelope is shared by every clip that references the waveform (soft copies), and a
//! clip envelope stacks on top of it: the engine multiplies both. An envelope is a fade-in, a
//! fade-out, a crossfade length, and optional gain breakpoints. Gains are linear, with 1.0 unity.
//!
//! Every evaluation function here is allocation-free and real-time safe.

use std::f32::consts::FRAC_PI_2;

use karbeat_utils::types::BipolarF64;
use serde::{Deserialize, Serialize};

use super::automation::{AutomationCurveType, SegmentShape, shape_segment};

/// Largest envelope point gain (+6 dB).
pub const MAX_ENVELOPE_GAIN: f32 = 2.0;

/// A fade at one edge of a waveform or clip.
#[derive(Clone, Copy, Debug, Default, PartialEq, Serialize, Deserialize)]
#[serde(default)]
pub struct Fade {
    /// Fade length in samples. Zero disables the fade.
    pub length: u32,
    /// Shape of the fade, rising from silence to unity.
    pub curve_type: AutomationCurveType,
    /// Bipolar tension of the fade curve.
    pub tension: BipolarF64,
}

impl Fade {
    /// Gain at normalized position `t` from silence (0.0) to unity (1.0).
    #[inline]
    pub fn gain_at(&self, t: f64) -> f32 {
        shape_segment(
            SegmentShape::new(self.curve_type, self.tension.get()),
            0.0,
            1.0,
            t,
        ) as f32
    }
}

/// One gain breakpoint.
#[derive(Clone, Copy, Debug, PartialEq, Serialize, Deserialize)]
#[serde(default)]
pub struct EnvelopePoint {
    /// Position in samples. Waveform envelopes count source frames from the trim start; clip
    /// envelopes count project-rate samples of the clip content, the unit of `offset_start`.
    pub position: u64,
    /// Linear gain, 0.0 to [`MAX_ENVELOPE_GAIN`].
    pub gain: f32,
    /// Curve toward the next point.
    pub curve_type: AutomationCurveType,
    /// Bipolar tension of the curve toward the next point.
    pub tension: BipolarF64,
}

impl Default for EnvelopePoint {
    fn default() -> Self {
        Self {
            position: 0,
            gain: 1.0,
            curve_type: AutomationCurveType::Linear,
            tension: BipolarF64::default(),
        }
    }
}

/// Fades, crossfade, and gain breakpoints applied to a waveform or a clip.
#[derive(Clone, Debug, Default, PartialEq, Serialize, Deserialize)]
#[serde(default)]
pub struct GainEnvelope {
    /// Fade from the start edge.
    pub fade_in: Fade,
    /// Fade toward the end edge.
    pub fade_out: Fade,
    /// Equal-power crossfade length in samples. On a waveform it blends the loop end into the
    /// loop start; on a clip it crossfades with an overlapping neighbour on the same track.
    pub crossfade: u32,
    /// Gain breakpoints sorted by position.
    pub points: Vec<EnvelopePoint>,
}

/// Cached segment index into [`GainEnvelope::points`] for monotonic playback.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct EnvelopeCursor(usize);

impl EnvelopeCursor {
    /// Positions the cursor for `pos` with one binary search.
    #[inline]
    pub fn seek(envelope: &GainEnvelope, pos: u64) -> Self {
        Self(envelope.points.partition_point(|p| p.position <= pos))
    }
}

impl GainEnvelope {
    /// Whether the envelope leaves audio untouched.
    pub fn is_identity(&self) -> bool {
        self.fade_in.length == 0
            && self.fade_out.length == 0
            && self.crossfade == 0
            && self.points.is_empty()
    }

    /// Whether fades or points change the gain. The crossfade is applied separately.
    #[inline]
    pub fn shapes_gain(&self) -> bool {
        self.fade_in.length > 0 || self.fade_out.length > 0 || !self.points.is_empty()
    }

    /// Sorts points by position and clamps gains into range. Non-finite gains become unity.
    #[must_use]
    pub fn normalized(mut self) -> Self {
        for point in &mut self.points {
            point.gain = if point.gain.is_finite() {
                point.gain.clamp(0.0, MAX_ENVELOPE_GAIN)
            } else {
                1.0
            };
            point.tension = BipolarF64::new(point.tension.get());
        }
        self.fade_in.tension = BipolarF64::new(self.fade_in.tension.get());
        self.fade_out.tension = BipolarF64::new(self.fade_out.tension.get());
        self.points.sort_by_key(|point| point.position);
        self
    }

    /// Fade-in and fade-out lengths for content of `len` samples. Fades that would overlap are
    /// scaled down proportionally so they meet instead.
    #[inline]
    pub fn fade_lengths(&self, len: u64) -> (u64, u64) {
        let fade_in = u64::from(self.fade_in.length);
        let fade_out = u64::from(self.fade_out.length);
        let total = fade_in + fade_out;
        if total <= len || total == 0 {
            return (fade_in, fade_out);
        }
        // `fade_in < total`, so the scaled length is below `len` and fits in a u64.
        let scaled_in = (u128::from(fade_in) * u128::from(len)) / u128::from(total);
        let scaled_in = u64::try_from(scaled_in).unwrap_or(len);
        (scaled_in, len - scaled_in)
    }

    /// Fade gain `elapsed` samples into content of `len` samples.
    #[inline]
    pub fn fade_gain(&self, elapsed: u64, len: u64) -> f32 {
        let (fade_in, fade_out) = self.fade_lengths(len);
        let mut gain = 1.0;
        if elapsed < fade_in {
            gain *= self.fade_in.gain_at(elapsed as f64 / fade_in as f64);
        }
        let remaining = len.saturating_sub(elapsed);
        if remaining < fade_out {
            gain *= self.fade_out.gain_at(remaining as f64 / fade_out as f64);
        }
        gain
    }

    /// Breakpoint gain at `pos`. The cursor moves forward with playback and binary-searches again
    /// only when `pos` goes backwards, e.g. after a loop wrap. Before the first point the first
    /// gain holds, after the last point the last gain holds, and no points means unity.
    #[inline]
    pub fn point_gain(&self, pos: u64, cursor: &mut EnvelopeCursor) -> f32 {
        let points = self.points.as_slice();
        let Some(first) = points.first() else {
            return 1.0;
        };

        let mut idx = cursor.0.min(points.len());
        if idx > 0 && points[idx - 1].position > pos {
            idx = points.partition_point(|p| p.position <= pos);
        } else {
            while idx < points.len() && points[idx].position <= pos {
                idx += 1;
            }
        }
        cursor.0 = idx;

        let Some(from) = idx.checked_sub(1).and_then(|i| points.get(i)) else {
            return first.gain;
        };
        let Some(to) = points.get(idx) else {
            return from.gain;
        };
        let t = (pos - from.position) as f64 / (to.position - from.position) as f64;
        shape_segment(
            SegmentShape::new(from.curve_type, from.tension.get()),
            f64::from(from.gain),
            f64::from(to.gain),
            t,
        ) as f32
    }

    /// Crossfade length usable inside a loop of `loop_len` frames: at most half the loop.
    #[inline]
    pub fn loop_crossfade(&self, loop_len: u64) -> u64 {
        u64::from(self.crossfade).min(loop_len / 2)
    }
}

/// Equal-power gains `(fading_out, fading_in)` at normalized crossfade position `t`.
#[inline]
pub fn equal_power(t: f32) -> (f32, f32) {
    let angle = t.clamp(0.0, 1.0) * FRAC_PI_2;
    (angle.cos(), angle.sin())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn point(position: u64, gain: f32) -> EnvelopePoint {
        EnvelopePoint {
            position,
            gain,
            ..EnvelopePoint::default()
        }
    }

    fn linear_fade(length: u32) -> Fade {
        Fade {
            length,
            ..Fade::default()
        }
    }

    #[test]
    fn default_envelope_is_identity() {
        let envelope = GainEnvelope::default();
        assert!(envelope.is_identity());
        assert_eq!(envelope.fade_gain(0, 100), 1.0);
        assert_eq!(envelope.point_gain(50, &mut EnvelopeCursor::default()), 1.0);
    }

    #[test]
    fn linear_fades_ramp_at_both_edges() {
        let envelope = GainEnvelope {
            fade_in: linear_fade(10),
            fade_out: linear_fade(20),
            ..GainEnvelope::default()
        };
        assert_eq!(envelope.fade_gain(0, 100), 0.0);
        assert!((envelope.fade_gain(5, 100) - 0.5).abs() < 1e-6);
        assert_eq!(envelope.fade_gain(50, 100), 1.0);
        assert!((envelope.fade_gain(90, 100) - 0.5).abs() < 1e-6);
        assert_eq!(envelope.fade_gain(100, 100), 0.0);
    }

    #[test]
    fn overlapping_fades_scale_to_fit() {
        let envelope = GainEnvelope {
            fade_in: linear_fade(300),
            fade_out: linear_fade(100),
            ..GainEnvelope::default()
        };
        assert_eq!(envelope.fade_lengths(200), (150, 50));
        assert_eq!(envelope.fade_lengths(1000), (300, 100));
    }

    #[test]
    fn points_interpolate_like_shape_segment() {
        let envelope = GainEnvelope {
            points: vec![point(100, 1.0), point(200, 0.0), point(300, 2.0)],
            ..GainEnvelope::default()
        };
        let mut cursor = EnvelopeCursor::default();
        assert_eq!(envelope.point_gain(0, &mut cursor), 1.0);
        assert!((envelope.point_gain(150, &mut cursor) - 0.5).abs() < 1e-6);
        assert!((envelope.point_gain(250, &mut cursor) - 1.0).abs() < 1e-6);
        assert_eq!(envelope.point_gain(400, &mut cursor), 2.0);
    }

    #[test]
    fn cursor_recovers_after_moving_backwards() {
        let envelope = GainEnvelope {
            points: vec![point(0, 0.0), point(100, 1.0)],
            ..GainEnvelope::default()
        };
        let mut cursor = EnvelopeCursor::seek(&envelope, 90);
        assert!((envelope.point_gain(90, &mut cursor) - 0.9).abs() < 1e-6);
        assert_eq!(envelope.point_gain(150, &mut cursor), 1.0);
        assert!((envelope.point_gain(10, &mut cursor) - 0.1).abs() < 1e-6);
    }

    #[test]
    fn normalized_sorts_and_clamps() {
        let envelope = GainEnvelope {
            points: vec![point(50, 5.0), point(10, f32::NAN), point(20, -1.0)],
            ..GainEnvelope::default()
        }
        .normalized();
        let positions: Vec<_> = envelope.points.iter().map(|p| p.position).collect();
        let gains: Vec<_> = envelope.points.iter().map(|p| p.gain).collect();
        assert_eq!(positions, [10, 20, 50]);
        assert_eq!(gains, [1.0, 0.0, MAX_ENVELOPE_GAIN]);
    }

    #[test]
    fn equal_power_keeps_constant_power() {
        for step in 0..=10 {
            let (out, fade_in) = equal_power(step as f32 / 10.0);
            assert!((out * out + fade_in * fade_in - 1.0).abs() < 1e-6);
        }
        let (out, fade_in) = equal_power(0.5);
        assert!((out - fade_in).abs() < 1e-6);
    }

    #[test]
    fn loop_crossfade_is_capped_at_half_the_loop() {
        let envelope = GainEnvelope {
            crossfade: 1000,
            ..GainEnvelope::default()
        };
        assert_eq!(envelope.loop_crossfade(600), 300);
        assert_eq!(envelope.loop_crossfade(5000), 1000);
    }
}
