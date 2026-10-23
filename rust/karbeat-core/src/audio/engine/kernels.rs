//! Sample loops of the block pipeline: eight lanes at a time with scalar remainders.

use karbeat_plugin_types::{Param, SmoothableParam};
use rodio::math::db_to_linear;
use wide::f32x8;

/// Adds `src * gain` to `dst`.
#[inline]
pub fn mix_gain(dst: &mut [f32], src: &[f32], gain: f32) {
    let gain_v = f32x8::splat(gain);
    let (dst_chunks, dst_rest) = dst.as_chunks_mut::<8>();
    let (src_chunks, src_rest) = src.as_chunks::<8>();
    for (dst, src) in dst_chunks.iter_mut().zip(src_chunks) {
        *dst = (f32x8::new(*dst) + f32x8::new(*src) * gain_v).to_array();
    }
    for (dst, src) in dst_rest.iter_mut().zip(src_rest) {
        *dst += *src * gain;
    }
}

/// Largest absolute value among the finite samples of `buffer`.
#[inline]
pub fn finite_peak(buffer: &[f32]) -> f32 {
    let (chunks, rest) = buffer.as_chunks::<8>();
    let mut peak_v = f32x8::ZERO;
    for chunk in chunks {
        peak_v = peak_v.fast_max(finite_abs(f32x8::new(*chunk)));
    }
    rest.iter()
        .fold(reduce_max(peak_v), |peak, sample| fold_peak(peak, *sample))
}

/// Scales interleaved stereo `buffer` by one gain per channel and returns the largest
/// absolute value among the finite results.
#[inline]
pub fn scale_stereo_peak(buffer: &mut [f32], left: f32, right: f32) -> f32 {
    let gains = f32x8::new([left, right, left, right, left, right, left, right]);
    let (chunks, rest) = buffer.as_chunks_mut::<8>();
    let mut peak_v = f32x8::ZERO;
    for chunk in chunks {
        let scaled = f32x8::new(*chunk) * gains;
        peak_v = peak_v.fast_max(finite_abs(scaled));
        *chunk = scaled.to_array();
    }
    let mut peak = reduce_max(peak_v);
    for [left_sample, right_sample] in rest.as_chunks_mut::<2>().0 {
        *left_sample *= left;
        *right_sample *= right;
        peak = fold_peak(fold_peak(peak, *left_sample), *right_sample);
    }
    peak
}

/// Applies a fader and equal-power pan to interleaved `buffer` and returns the largest
/// absolute value among the finite results.
///
/// A settled fader is one multiply per sample. While volume (in decibels) or pan is still
/// smoothing, both advance every frame; stereo converts them to channel gains eight frames
/// at a time. Other channel counts apply volume to the first channel of each frame only.
#[inline]
pub fn apply_fader(
    buffer: &mut [f32],
    channels: usize,
    volume: &mut Param<f32>,
    pan: &mut Param<f32>,
) -> f32 {
    if channels != 2 {
        for frame in buffer.chunks_exact_mut(channels.max(1)) {
            if let Some(sample) = frame.first_mut() {
                *sample *= linear_gain(volume.next_smoothed());
            }
        }
        return finite_peak(buffer);
    }
    if volume.smoother.is_settled() && pan.smoother.is_settled() {
        let (left, right) = stereo_gains(volume.smoother.current(), pan.smoother.current());
        return scale_stereo_peak(buffer, left, right);
    }

    /// Natural logarithm of ten over twenty: decibels to the exponent of `e`.
    const DB_TO_NEPER: f32 = std::f32::consts::LN_10 / 20.0;
    let (chunks, rest) = buffer.as_chunks_mut::<16>();
    let mut peak = 0.0_f32;
    for chunk in chunks {
        let mut decibels = [0.0_f32; 8];
        let mut audible = [1.0_f32; 8];
        let mut position = [0.0_f32; 8];
        for ((decibels, audible), position) in
            decibels.iter_mut().zip(&mut audible).zip(&mut position)
        {
            let level = volume.next_smoothed();
            *decibels = level as f32;
            if level <= -100.0 {
                *audible = 0.0;
            }
            *position = (pan.next_smoothed() as f32 + 1.0) * 0.5;
        }
        let gain = (f32x8::new(decibels) * f32x8::splat(DB_TO_NEPER)).exp() * f32x8::new(audible);
        let position = f32x8::new(position);
        let left = ((f32x8::ONE - position).sqrt() * gain).to_array();
        let right = (position.sqrt() * gain).to_array();
        for ([left_sample, right_sample], (left, right)) in chunk
            .as_chunks_mut::<2>()
            .0
            .iter_mut()
            .zip(left.iter().zip(&right))
        {
            *left_sample *= *left;
            *right_sample *= *right;
            peak = fold_peak(fold_peak(peak, *left_sample), *right_sample);
        }
    }
    for [left_sample, right_sample] in rest.as_chunks_mut::<2>().0 {
        let (left, right) = stereo_gains(volume.next_smoothed(), pan.next_smoothed());
        *left_sample *= left;
        *right_sample *= right;
        peak = fold_peak(fold_peak(peak, *left_sample), *right_sample);
    }
    peak
}

/// Linear gain of a fader level in decibels; -100 dB and below is silence.
#[inline(always)]
fn linear_gain(decibels: f64) -> f32 {
    if decibels <= -100.0 {
        0.0
    } else {
        db_to_linear(decibels as f32)
    }
}

/// Equal-power channel gains for a fader level in decibels and a pan in -1.0..=1.0.
#[inline(always)]
fn stereo_gains(decibels: f64, pan: f64) -> (f32, f32) {
    let gain = linear_gain(decibels);
    let position = (pan as f32 + 1.0) * 0.5;
    ((1.0 - position).sqrt() * gain, position.sqrt() * gain)
}

#[inline(always)]
fn finite_abs(values: f32x8) -> f32x8 {
    values.is_finite().select(values.abs(), f32x8::ZERO)
}

#[inline(always)]
fn reduce_max(values: f32x8) -> f32 {
    values.to_array().into_iter().fold(0.0, f32::max)
}

#[inline(always)]
fn fold_peak(peak: f32, sample: f32) -> f32 {
    if sample.is_finite() {
        peak.max(sample.abs())
    } else {
        peak
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    struct Lcg(u64);

    impl Lcg {
        fn next(&mut self) -> f32 {
            self.0 = self
                .0
                .wrapping_mul(6_364_136_223_846_793_005)
                .wrapping_add(1_442_695_040_888_963_407);
            ((self.0 >> 40) as f32 / (1_u64 << 24) as f32) * 2.0 - 1.0
        }

        fn samples(&mut self, count: usize) -> Vec<f32> {
            (0..count).map(|_| self.next()).collect()
        }
    }

    /// Fader the way a mixer channel builds it, moving from `from` toward `to`.
    fn fader(from: (f32, f32), to: (f32, f32)) -> (Param<f32>, Param<f32>) {
        let mut volume = Param::new_f32(1, "Volume", "", from.0, -100.0, 6.0, 0.1);
        let mut pan = Param::new_f32(2, "Pan", "", from.1, -1.0, 1.0, 0.01);
        volume.set_smoothing_time(0.015, 48_000.0);
        pan.set_smoothing_time(0.015, 48_000.0);
        volume.set_base(to.0);
        pan.set_base(to.1);
        (volume, pan)
    }

    #[test]
    fn mixing_matches_the_scalar_loops_at_every_length() {
        let mut random = Lcg(3);
        for length in 0..=67 {
            let source = random.samples(length);
            let start = random.samples(length);

            let mut mixed = start.clone();
            mix_gain(&mut mixed, &source, 0.37);
            let expected: Vec<f32> = start
                .iter()
                .zip(&source)
                .map(|(a, b)| a + b * 0.37)
                .collect();
            assert_eq!(mixed, expected, "mix_gain, length {length}");
        }
    }

    #[test]
    fn peaks_skip_non_finite_samples_at_every_length() {
        let mut random = Lcg(5);
        for length in 0..=67 {
            let mut buffer = random.samples(length);
            for (index, sample) in buffer.iter_mut().enumerate() {
                match index % 11 {
                    3 => *sample = f32::NAN,
                    7 => *sample = f32::INFINITY,
                    9 => *sample = f32::NEG_INFINITY,
                    _ => {}
                }
            }
            let expected = buffer
                .iter()
                .filter(|sample| sample.is_finite())
                .fold(0.0_f32, |peak, sample| peak.max(sample.abs()));
            assert_eq!(finite_peak(&buffer), expected, "length {length}");
        }
    }

    #[test]
    fn settled_fader_scales_each_channel_and_reports_the_peak() {
        let mut random = Lcg(9);
        for frames in 0..=33 {
            let start = random.samples(frames * 2);
            let (mut volume, mut pan) = fader((-6.0, 0.3), (-6.0, 0.3));
            let (left, right) = stereo_gains(-6.0, f64::from(0.3_f32));
            let mut buffer = start.clone();
            let peak = apply_fader(&mut buffer, 2, &mut volume, &mut pan);
            let expected: Vec<f32> = start
                .chunks_exact(2)
                .flat_map(|frame| [frame[0] * left, frame[1] * right])
                .collect();
            assert_eq!(buffer, expected, "frames {frames}");
            assert_eq!(peak, finite_peak(&expected), "frames {frames}");
        }
    }

    #[test]
    fn moving_fader_follows_the_per_frame_smoothing_curve() {
        let mut random = Lcg(13);
        for (from, to) in [
            ((0.0, 0.0), (-18.0, -0.8)),
            ((-30.0, 0.9), (6.0, 0.9)),
            ((0.0, 0.0), (-100.0, 0.0)),
            ((-100.0, -1.0), (-3.0, 1.0)),
        ] {
            for frames in [1, 7, 8, 9, 64, 1_000] {
                let start = random.samples(frames * 2);
                let (mut volume, mut pan) = fader(from, to);
                let (mut reference_volume, mut reference_pan) = fader(from, to);
                let mut buffer = start.clone();
                let peak = apply_fader(&mut buffer, 2, &mut volume, &mut pan);
                let mut worst = 0.0_f32;
                for (frame, original) in buffer.chunks_exact(2).zip(start.chunks_exact(2)) {
                    let (left, right) = stereo_gains(
                        reference_volume.next_smoothed(),
                        reference_pan.next_smoothed(),
                    );
                    worst = worst
                        .max((frame[0] - original[0] * left).abs())
                        .max((frame[1] - original[1] * right).abs());
                }
                assert!(
                    worst < 2.0e-6,
                    "{from:?} -> {to:?}, {frames} frames: {worst}"
                );
                assert_eq!(peak, finite_peak(&buffer));
                // Both smoothers advanced exactly one step per frame.
                assert_eq!(
                    volume.smoother.current(),
                    reference_volume.smoother.current()
                );
                assert_eq!(pan.smoother.current(), reference_pan.smoother.current());
            }
        }
    }

    #[test]
    fn other_channel_counts_keep_the_volume_only_fallback() {
        let (mut volume, mut pan) = fader((-6.0, 0.5), (-6.0, 0.5));
        let mut buffer = vec![1.0_f32; 9];
        let peak = apply_fader(&mut buffer, 3, &mut volume, &mut pan);
        let gain = linear_gain(-6.0);
        assert_eq!(buffer, [gain, 1.0, 1.0, gain, 1.0, 1.0, gain, 1.0, 1.0]);
        assert_eq!(peak, 1.0);
    }
}
