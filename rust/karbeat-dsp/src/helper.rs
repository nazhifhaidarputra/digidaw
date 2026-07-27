//! DSP Helper Utilities
//!
//! This module provides common, highly-optimized helper functions for audio synthesis,
//! effects processing, and general digital signal processing (DSP) tasks.

use std::f64::consts::FRAC_PI_2;

// ============================================================================
// Amplitude & Power Conversions
// ============================================================================

/// Converts a linear amplitude value to decibels (dB).
/// Clamps the input to `1e-6` to prevent `log10(0)` undefined behavior.
#[inline]
pub fn linear_to_db(linear: f64) -> f64 {
    20.0 * linear.max(1e-6).log10()
}

/// Converts a linear amplitude value to decibels (dB) for `f32`.
#[inline]
pub fn linear_to_db_f32(linear: f32) -> f32 {
    20.0 * linear.max(1e-6).log10()
}

/// Converts a decibel (dB) value to linear amplitude.
#[inline]
pub fn db_to_linear(db: f64) -> f64 {
    10.0_f64.powf(db / 20.0)
}

/// Converts a decibel (dB) value to linear amplitude for `f32`.
#[inline]
pub fn db_to_linear_f32(db: f32) -> f32 {
    10.0_f32.powf(db / 20.0)
}

// ============================================================================
// Frequency & Pitch Conversions
// ============================================================================

/// Converts a MIDI note number to frequency in Hz (A4 = 69 = 440Hz).
#[inline]
pub fn midi_to_freq(midi_note: f64) -> f64 {
    440.0 * 2.0_f64.powf((midi_note - 69.0) / 12.0)
}

/// Converts a MIDI note number to frequency in Hz for `f32`.
#[inline]
pub fn midi_to_freq_f32(midi_note: f32) -> f32 {
    440.0 * 2.0_f32.powf((midi_note - 69.0) / 12.0)
}

/// Converts a frequency in Hz to a MIDI note number.
#[inline]
pub fn freq_to_midi(freq: f64) -> f64 {
    69.0 + 12.0 * (freq / 440.0).log2()
}

/// Converts a frequency in Hz to a MIDI note number for `f32`.
#[inline]
pub fn freq_to_midi_f32(freq: f32) -> f32 {
    69.0 + 12.0 * (freq / 440.0).log2()
}

// ============================================================================
// Signal Shaping & Clipping
// ============================================================================

/// Hard clips a sample to the range `[-threshold, threshold]`.
#[inline]
pub fn hard_clip(sample: f64, threshold: f64) -> f64 {
    sample.clamp(-threshold, threshold)
}

/// Soft clips a sample using a hyperbolic tangent (tanh) function.
/// Provides smooth, musical saturation.
#[inline]
pub fn soft_clip_tanh(sample: f64) -> f64 {
    sample.tanh()
}

/// Soft clips a sample using a cubic polynomial.
/// Faster than `tanh` but with slightly different harmonic characteristics.
/// Input should ideally be in the range `[-1.5, 1.5]` for best results.
#[inline]
pub fn soft_clip_poly(sample: f64) -> f64 {
    if sample < -1.0 {
        -0.6666666666666666 // -2/3
    } else if sample > 1.0 {
        0.6666666666666666 // 2/3
    } else {
        sample - (sample.powi(3) / 3.0)
    }
}

// ============================================================================
// Dynamics & Compression
// ============================================================================

/// Calculates the gain reduction (in dB) for a compressor.
/// Returns a positive dB value representing how much to attenuate the signal.
///
/// - `level_db`: Current input level in dB
/// - `threshold_db`: Compression threshold in dB
/// - `ratio`: Compression ratio (e.g., 4.0 for 4:1)
/// - `knee_db`: Width of the soft knee in dB (use 0.0 for hard knee)
#[inline]
pub fn compressor_gain_reduction(
    level_db: f64,
    threshold_db: f64,
    ratio: f64,
    knee_db: f64,
) -> f64 {
    let half_knee = knee_db / 2.0;
    let knee_start = threshold_db - half_knee;
    let knee_end = threshold_db + half_knee;

    if level_db <= knee_start {
        0.0 // No compression
    } else if level_db >= knee_end {
        // Hard knee compression above the knee
        (level_db - threshold_db) * (1.0 - 1.0 / ratio)
    } else {
        // Soft knee quadratic curve
        let x = level_db - threshold_db + half_knee;
        (x * x) / (2.0 * knee_db) * (1.0 - 1.0 / ratio)
    }
}

// ============================================================================
// Interpolation & Mixing
// ============================================================================

/// Maps a value from one range to another linearly.
#[inline]
pub fn map_range(value: f64, in_min: f64, in_max: f64, out_min: f64, out_max: f64) -> f64 {
    out_min + (value - in_min) * (out_max - out_min) / (in_max - in_min)
}

/// Equal-power crossfade between two signals.
/// Prevents volume dips in the middle of the fade.
/// `mix` should be in the range `0.0` (100% `a`) to `1.0` (100% `b`).
#[inline]
pub fn equal_power_crossfade(a: f64, b: f64, mix: f64) -> f64 {
    let mix_clamped = mix.clamp(0.0, 1.0);
    let theta = mix_clamped * FRAC_PI_2;
    let gain_a = theta.cos();
    let gain_b = theta.sin();
    a * gain_a + b * gain_b
}

/// Linear crossfade between two signals.
/// `mix` should be in the range `0.0` (100% `a`) to `1.0` (100% `b`).
#[inline]
pub fn linear_crossfade(a: f64, b: f64, mix: f64) -> f64 {
    let mix_clamped = mix.clamp(0.0, 1.0);
    a * (1.0 - mix_clamped) + b * mix_clamped
}

// ============================================================================
// Filters & Stateful Helpers
// ============================================================================

/// Simple 1-pole DC blocker (high-pass filter).
/// Removes low-frequency drift / DC offset from a signal.
///
/// - `sample`: Current input sample
/// - `prev_out`: Mutable reference to previous output sample (initialize to 0.0)
/// - `prev_in`: Mutable reference to previous input sample (initialize to 0.0)
/// - `alpha`: Pole position, typically `0.99` to `0.995` (closer to 1.0 = lower cutoff freq)
#[inline]
pub fn dc_blocker(sample: f64, prev_out: &mut f64, prev_in: &mut f64, alpha: f64) -> f64 {
    let out = sample - *prev_in + alpha * *prev_out;
    *prev_in = sample;
    *prev_out = out;
    out
}

/// One-pole lowpass smoothing filter (exponential moving average).
/// Useful for smoothing parameter changes to avoid zipper noise.
///
/// - `current`: Current smoothed value
/// - `target`: Target value to reach
/// - `coefficient`: Smoothing factor (0.0 = no change, 1.0 = instant change).
///   Typical audio rate: `1.0 - exp(-2.0 * PI * cutoff_freq / sample_rate)`
#[inline]
pub fn smooth_step(current: f64, target: f64, coefficient: f64) -> f64 {
    current + coefficient * (target - current)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_db_conversions() {
        assert!((linear_to_db(1.0) - 0.0).abs() < 1e-5);
        assert!((linear_to_db(0.5) - (-6.0205)).abs() < 1e-3);
        assert!((db_to_linear(0.0) - 1.0).abs() < 1e-5);
        assert!((db_to_linear(-6.0205) - 0.5).abs() < 1e-3);
    }

    #[test]
    fn test_midi_conversions() {
        assert!((midi_to_freq(69.0) - 440.0).abs() < 1e-5);
        assert!((freq_to_midi(440.0) - 69.0).abs() < 1e-5);
    }

    #[test]
    fn test_equal_power_crossfade() {
        // At mix = 0.5, gains should be ~0.707, so 1.0 * 0.707 + 1.0 * 0.707 ≈ 1.414
        let result = equal_power_crossfade(1.0, 1.0, 0.5);
        assert!((result - std::f64::consts::SQRT_2).abs() < 1e-5);
    }
}
