#![allow(
    clippy::as_conversions,
    clippy::arithmetic_side_effects,
    clippy::cast_possible_truncation,
    clippy::cast_precision_loss,
    clippy::cast_sign_loss,
    clippy::indexing_slicing,
    reason = "the prepared layout and parameter bounds keep delay indices, sample arithmetic, and numeric conversions valid"
)]

use karbeat_macros::{EnumParam, karbeat_plugin};
use karbeat_plugin_types::EnumParam;
use karbeat_plugin_types::parameter::SmoothableParam;
use serde::{Deserialize, Serialize};

const MAX_DELAY_SECONDS: usize = 5;
const PARAMETER_SMOOTHING_SECONDS: f64 = 0.01;

// ▱▱▱▱▱ Traits ▱▱▱▱▱

/// Trait defining the routing and delay behavior for a delay algorithm.
///
/// Injecting `DelayDsp` allows each dynamic variant to access delay state
/// variables such as ring buffers, write position, parameters, and interpolation helpers.
pub trait DelayMode: Copy + Default + PartialEq + EnumParam + Send + Sync {
    /// Process a deinterleaved audio block in place using the provided `DelayDsp` state.
    fn process_block<T: DelayMode + 'static>(
        &self,
        delay: &mut DelayDsp<T>,
        buffers: &mut [&mut [f64]],
    );

    /// Whether this mode is bypassed / off.
    fn is_off(&self) -> bool;
}

// ▱▱▱▱▱ Delay type enums ▱▱▱▱

#[derive(Clone, Copy, PartialEq, Debug, Default, EnumParam, Deserialize, Serialize)]
#[repr(usize)]
pub enum SimpleDelayMode {
    #[default]
    Feedback = 0,
    PingPong = 1,
    MultiTap = 2,
    Off = 3,
}

impl From<f32> for SimpleDelayMode {
    fn from(v: f32) -> Self {
        match v as u32 {
            0 => Self::Feedback,
            1 => Self::PingPong,
            2 => Self::MultiTap,
            _ => Self::Off,
        }
    }
}

pub type DelayType = SimpleDelayMode;

// ▱▱▱▱▱ Mode implementation for SimpleDelayMode ▱▱▱▱▱

impl DelayMode for SimpleDelayMode {
    #[inline]
    fn is_off(&self) -> bool {
        *self == Self::Off
    }

    fn process_block<T: DelayMode + 'static>(
        &self,
        delay: &mut DelayDsp<T>,
        buffers: &mut [&mut [f64]],
    ) {
        if self.is_off() {
            return;
        }

        match self {
            Self::Feedback => {
                let frame_count = buffers[0].len();
                for frame in 0..frame_count {
                    let parameters = delay.next_frame_parameters();
                    for (channel, buffer) in buffers.iter_mut().enumerate() {
                        let input = buffer[frame];
                        let delayed = delay.read(channel, parameters.delay_samples);
                        buffer[frame] = input * parameters.dry_mix + delayed * parameters.wet_mix;
                        delay.write(channel, input + delayed * parameters.feedback);
                    }
                    delay.advance();
                }
            }
            Self::PingPong => {
                let frame_count = buffers[0].len();
                for frame in 0..frame_count {
                    let parameters = delay.next_frame_parameters();
                    let paired_channels = buffers.len() - buffers.len() % 2;

                    for left in (0..paired_channels).step_by(2) {
                        let right = left + 1;
                        let left_input = buffers[left][frame];
                        let right_input = buffers[right][frame];
                        let left_delayed = delay.read(left, parameters.delay_samples);
                        let right_delayed = delay.read(right, parameters.delay_samples);

                        buffers[left][frame] =
                            left_input * parameters.dry_mix + left_delayed * parameters.wet_mix;
                        buffers[right][frame] =
                            right_input * parameters.dry_mix + right_delayed * parameters.wet_mix;

                        delay.write(left, left_input + right_delayed * parameters.feedback);
                        delay.write(right, right_input + left_delayed * parameters.feedback);
                    }

                    if paired_channels < buffers.len() {
                        let channel = paired_channels;
                        let input = buffers[channel][frame];
                        let delayed = delay.read(channel, parameters.delay_samples);
                        buffers[channel][frame] =
                            input * parameters.dry_mix + delayed * parameters.wet_mix;
                        delay.write(channel, input + delayed * parameters.feedback);
                    }

                    delay.advance();
                }
            }
            Self::MultiTap => {
                let frame_count = buffers[0].len();
                for frame in 0..frame_count {
                    let parameters = delay.next_frame_parameters();
                    let tap_count = delay.tap_count.get().clamp(2, 8) as usize;
                    let tap_decay = delay.tap_decay.next_smoothed().clamp(0.0, 1.0);

                    for (channel, buffer) in buffers.iter_mut().enumerate() {
                        let input = buffer[frame];
                        let mut wet_sample = 0.0;
                        let mut weight_sum = 0.0;
                        let mut weight = 1.0;

                        for tap in 1..=tap_count {
                            let tap_delay =
                                parameters.delay_samples * tap as f64 / tap_count as f64;
                            wet_sample += delay.read(channel, tap_delay) * weight;
                            weight_sum += weight;
                            weight *= tap_decay;
                        }

                        let final_tap = delay.read(channel, parameters.delay_samples);
                        buffer[frame] =
                            input * parameters.dry_mix + (wet_sample / weight_sum) * parameters.wet_mix;
                        delay.write(channel, input + final_tap * parameters.feedback);
                    }

                    delay.advance();
                }
            }
            Self::Off => {}
        }
    }
}

#[derive(Clone, Copy, Debug)]
pub struct DelayFrameParameters {
    pub delay_samples: f64,
    pub feedback: f64,
    pub dry_mix: f64,
    pub wet_mix: f64,
}

// ▱▱▱▱▱ DelayDsp — the top-level delay processor ▱▱▱▱▱

/// Parameters and delay-line storage for delay processors.
#[derive(Clone, Debug)]
#[karbeat_plugin]
pub struct DelayDsp<T: DelayMode + 'static = SimpleDelayMode> {
    /// Time of the final delay tap in milliseconds.
    #[param(
        id = "delay_ms",
        name = "Delay",
        group = "Delay",
        default = 500.0,
        min = 1.0,
        max = 5000.0,
        step = 1.0
    )]
    pub delay_ms: f64,

    /// Amount of delayed signal returned to the delay line.
    #[param(
        id = "feedback",
        name = "Feedback",
        group = "Delay",
        default = 0.35,
        min = 0.0,
        max = 0.95,
        step = 0.001
    )]
    pub feedback: f64,

    /// Linear gain applied to the input signal.
    #[param(
        id = "dry_mix",
        name = "Dry",
        group = "Delay",
        default = 0.5,
        min = 0.0,
        max = 1.0,
        step = 0.001
    )]
    pub dry_mix: f64,

    /// Linear gain applied to the delayed signal.
    #[param(
        id = "wet_mix",
        name = "Wet",
        group = "Delay",
        default = 0.5,
        min = 0.0,
        max = 1.0,
        step = 0.001
    )]
    pub wet_mix: f64,

    /// Mode / routing algorithm of the delay.
    #[param(id = "type", name = "Type", group = "Delay", default = 0.0)]
    pub delay_type: T,

    /// Number of evenly spaced delay taps (for MultiTap mode).
    #[param(
        id = "tap_count",
        name = "Tap Count",
        group = "Multi Tap",
        default = 4,
        min = 2,
        max = 8,
        step = 1
    )]
    pub tap_count: i32,

    /// Level multiplier applied between consecutive taps (for MultiTap mode).
    #[param(
        id = "tap_decay",
        name = "Tap Decay",
        group = "Multi Tap",
        default = 0.7,
        min = 0.0,
        max = 1.0,
        step = 0.001
    )]
    pub tap_decay: f64,

    sample_rate: u32,
    channels: usize,
    ring_buffers: Vec<Vec<f64>>,
    write_position: usize,
}

impl<T: DelayMode + 'static> Default for DelayDsp<T> {
    fn default() -> Self {
        let mut d = Self::base_default();
        d.delay_type.set_base(T::default());
        d
    }
}

impl<T: DelayMode + 'static> DelayDsp<T> {
    /// Allocate delay storage for the requested stream layout.
    pub fn prepare(&mut self, sample_rate: u32, num_channels: usize) {
        if sample_rate == 0 || num_channels == 0 {
            self.sample_rate = 0;
            self.channels = 0;
            self.ring_buffers.clear();
            self.write_position = 0;
            return;
        }

        let capacity = (sample_rate as usize)
            .saturating_mul(MAX_DELAY_SECONDS)
            .saturating_add(2);
        self.sample_rate = sample_rate;
        self.channels = num_channels;
        self.ring_buffers = vec![vec![0.0; capacity]; num_channels];
        self.write_position = 0;
        self.configure_smoothers();
    }

    /// Clear all delayed audio while retaining allocated storage.
    pub fn reset(&mut self) {
        for buffer in &mut self.ring_buffers {
            buffer.fill(0.0);
        }
        self.write_position = 0;
        self.reset_smoothers();
    }

    /// Process a deinterleaved audio block in place using the active delay mode.
    pub fn process_block(&mut self, buffers: &mut [&mut [f64]]) {
        if !self.layout_is_valid(buffers) {
            return;
        }

        let mode = self.delay_type.get();
        mode.process_block(self, buffers);
    }

    fn configure_smoothers(&mut self) {
        let sample_rate = f64::from(self.sample_rate);
        self.delay_ms
            .set_smoothing_time(PARAMETER_SMOOTHING_SECONDS, sample_rate);
        self.feedback
            .set_smoothing_time(PARAMETER_SMOOTHING_SECONDS, sample_rate);
        self.dry_mix
            .set_smoothing_time(PARAMETER_SMOOTHING_SECONDS, sample_rate);
        self.wet_mix
            .set_smoothing_time(PARAMETER_SMOOTHING_SECONDS, sample_rate);
        self.tap_decay
            .set_smoothing_time(PARAMETER_SMOOTHING_SECONDS, sample_rate);
        self.reset_smoothers();
    }

    fn reset_smoothers(&mut self) {
        self.delay_ms.smoother.reset(self.delay_ms.get());
        self.feedback.smoother.reset(self.feedback.get());
        self.dry_mix.smoother.reset(self.dry_mix.get());
        self.wet_mix.smoother.reset(self.wet_mix.get());
        self.tap_decay.smoother.reset(self.tap_decay.get());
    }

    pub fn layout_is_valid(&self, buffers: &[&mut [f64]]) -> bool {
        if self.sample_rate == 0 || self.ring_buffers.is_empty() || buffers.len() != self.channels {
            return false;
        }

        let Some(first) = buffers.first() else {
            return false;
        };
        buffers.iter().all(|buffer| buffer.len() == first.len())
    }

    #[inline]
    pub fn next_frame_parameters(&mut self) -> DelayFrameParameters {
        let capacity = self.ring_buffers[0].len();
        let maximum_delay = capacity.saturating_sub(2) as f64;
        let delay_samples = (self.delay_ms.next_smoothed() * f64::from(self.sample_rate) * 0.001)
            .clamp(1.0, maximum_delay);

        DelayFrameParameters {
            delay_samples,
            feedback: self.feedback.next_smoothed().clamp(0.0, 0.95),
            dry_mix: self.dry_mix.next_smoothed().clamp(0.0, 1.0),
            wet_mix: self.wet_mix.next_smoothed().clamp(0.0, 1.0),
        }
    }

    #[inline]
    pub fn read(&self, channel: usize, delay_samples: f64) -> f64 {
        let buffer = &self.ring_buffers[channel];
        let capacity = buffer.len();
        let read_position =
            (self.write_position as f64 - delay_samples).rem_euclid(capacity as f64);
        let earlier_index = read_position.floor() as usize;
        let later_index = (earlier_index + 1) % capacity;
        let fraction = read_position - earlier_index as f64;

        buffer[earlier_index] + (buffer[later_index] - buffer[earlier_index]) * fraction
    }

    #[inline]
    pub fn write(&mut self, channel: usize, sample: f64) {
        self.ring_buffers[channel][self.write_position] = sample;
    }

    #[inline]
    pub fn advance(&mut self) {
        self.write_position += 1;
        if self.write_position == self.ring_buffers[0].len() {
            self.write_position = 0;
        }
    }

    #[inline]
    pub fn sample_rate(&self) -> u32 {
        self.sample_rate
    }

    #[inline]
    pub fn channels(&self) -> usize {
        self.channels
    }

    #[inline]
    pub fn write_position(&self) -> usize {
        self.write_position
    }

    #[inline]
    pub fn ring_buffers(&self) -> &[Vec<f64>] {
        &self.ring_buffers
    }

    #[inline]
    pub fn ring_buffers_mut(&mut self) -> &mut [Vec<f64>] {
        &mut self.ring_buffers
    }
}

// ▱▱▱▱▱ Legacy / Helper Wrappers ▱▱▱▱▱

/// A feedback delay with an independent delay line for each channel.
#[derive(Clone, Debug)]
#[karbeat_plugin]
pub struct FeedbackDelayDsp {
    /// Shared parameters and delay-line state.
    #[nested(prefix = "delay/")]
    pub delay: DelayDsp<SimpleDelayMode>,
}

impl Default for FeedbackDelayDsp {
    fn default() -> Self {
        let mut inst = Self::base_default();
        inst.delay.delay_type.set_base(SimpleDelayMode::Feedback);
        inst
    }
}

impl FeedbackDelayDsp {
    pub fn prepare(&mut self, sample_rate: u32, num_channels: usize) {
        self.delay.prepare(sample_rate, num_channels);
    }

    pub fn reset(&mut self) {
        self.delay.reset();
    }

    pub fn process_block(&mut self, buffers: &mut [&mut [f64]]) {
        self.delay.process_block(buffers);
    }
}

/// A delay that cross-feeds adjacent channel pairs.
#[derive(Clone, Debug)]
#[karbeat_plugin]
pub struct PingPongDelayDsp {
    /// Shared parameters and delay-line state.
    #[nested(prefix = "delay/")]
    pub delay: DelayDsp<SimpleDelayMode>,
}

impl Default for PingPongDelayDsp {
    fn default() -> Self {
        let mut inst = Self::base_default();
        inst.delay.delay_type.set_base(SimpleDelayMode::PingPong);
        inst
    }
}

impl PingPongDelayDsp {
    pub fn prepare(&mut self, sample_rate: u32, num_channels: usize) {
        self.delay.prepare(sample_rate, num_channels);
    }

    pub fn reset(&mut self) {
        self.delay.reset();
    }

    pub fn process_block(&mut self, buffers: &mut [&mut [f64]]) {
        self.delay.process_block(buffers);
    }
}

/// A delay with evenly spaced, progressively decaying taps.
#[derive(Clone, Debug)]
#[karbeat_plugin]
pub struct MultiTapDelayDsp {
    /// Shared parameters and delay-line state.
    #[nested(prefix = "delay/")]
    pub delay: DelayDsp<SimpleDelayMode>,
}

impl Default for MultiTapDelayDsp {
    fn default() -> Self {
        let mut inst = Self::base_default();
        inst.delay.delay_type.set_base(SimpleDelayMode::MultiTap);
        inst
    }
}

impl MultiTapDelayDsp {
    pub fn prepare(&mut self, sample_rate: u32, num_channels: usize) {
        self.delay.prepare(sample_rate, num_channels);
    }

    pub fn reset(&mut self) {
        self.delay.reset();
    }

    pub fn process_block(&mut self, buffers: &mut [&mut [f64]]) {
        self.delay.process_block(buffers);
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use karbeat_plugin_types::parameter::AutoParams;

    const EPSILON: f64 = 1.0e-10;

    fn configure_delay<T: DelayMode + 'static>(delay: &mut DelayDsp<T>, delay_ms: f64, feedback: f64) {
        delay.delay_ms.set_base(delay_ms);
        delay.feedback.set_base(feedback);
        delay.dry_mix.set_base(0.0);
        delay.wet_mix.set_base(1.0);
    }

    fn assert_close(actual: f64, expected: f64) {
        assert!(
            (actual - expected).abs() < EPSILON,
            "expected {expected}, got {actual}"
        );
    }

    #[test]
    fn feedback_delay_places_and_decays_echoes() {
        let mut delay = FeedbackDelayDsp::default();
        configure_delay(&mut delay.delay, 3.0, 0.5);
        delay.prepare(1000, 1);

        let mut audio = [0.0; 12];
        audio[0] = 1.0;
        delay.process_block(&mut [&mut audio]);

        assert_close(audio[0], 0.0);
        assert_close(audio[3], 1.0);
        assert_close(audio[6], 0.5);
        assert_close(audio[9], 0.25);
    }

    #[test]
    fn delay_dsp_direct_mode_switching() {
        let mut delay = DelayDsp::<SimpleDelayMode>::default();
        assert_eq!(delay.delay_type.get(), SimpleDelayMode::Feedback);

        configure_delay(&mut delay, 3.0, 0.5);
        delay.prepare(1000, 1);

        let mut audio = [0.0; 12];
        audio[0] = 1.0;
        delay.process_block(&mut [&mut audio]);

        assert_close(audio[0], 0.0);
        assert_close(audio[3], 1.0);
        assert_close(audio[6], 0.5);

        // Switch mode to Off dynamically
        delay.reset();
        delay.delay_type.set_base(SimpleDelayMode::Off);
        let mut audio_off = [1.0, 2.0, 3.0];
        delay.process_block(&mut [&mut audio_off]);
        assert_eq!(audio_off, [1.0, 2.0, 3.0]);
    }

    #[test]
    fn dry_and_wet_gains_are_independent() {
        let mut delay = FeedbackDelayDsp::default();
        delay.delay.delay_ms.set_base(2.0);
        delay.delay.feedback.set_base(0.0);
        delay.delay.dry_mix.set_base(0.25);
        delay.delay.wet_mix.set_base(0.75);
        delay.prepare(1000, 1);

        let mut audio = [1.0, 0.0, 0.0, 0.0];
        delay.process_block(&mut [&mut audio]);

        assert_close(audio[0], 0.25);
        assert_close(audio[2], 0.75);
    }

    #[test]
    fn ping_pong_cross_feeds_adjacent_pairs() {
        let mut delay = PingPongDelayDsp::default();
        configure_delay(&mut delay.delay, 2.0, 0.5);
        delay.prepare(1000, 3);

        let mut left = [1.0, 0.0, 0.0, 0.0, 0.0, 0.0];
        let mut right = [0.0; 6];
        let mut unpaired = [1.0, 0.0, 0.0, 0.0, 0.0, 0.0];
        delay.process_block(&mut [&mut left, &mut right, &mut unpaired]);

        assert_close(left[2], 1.0);
        assert_close(right[4], 0.5);
        assert_close(unpaired[2], 1.0);
        assert_close(unpaired[4], 0.5);
    }

    #[test]
    fn ping_pong_uses_feedback_routing_for_mono() {
        let mut delay = PingPongDelayDsp::default();
        configure_delay(&mut delay.delay, 2.0, 0.5);
        delay.prepare(1000, 1);

        let mut audio = [1.0, 0.0, 0.0, 0.0, 0.0];
        delay.process_block(&mut [&mut audio]);

        assert_close(audio[2], 1.0);
        assert_close(audio[4], 0.5);
    }

    #[test]
    fn multi_tap_uses_even_spacing_and_normalized_decay() {
        let mut delay = MultiTapDelayDsp::default();
        configure_delay(&mut delay.delay, 6.0, 0.0);
        delay.delay.tap_count.set_base(3);
        delay.delay.tap_decay.set_base(0.5);
        delay.prepare(1000, 1);

        let mut audio = [0.0; 8];
        audio[0] = 1.0;
        delay.process_block(&mut [&mut audio]);

        assert_close(audio[2], 1.0 / 1.75);
        assert_close(audio[4], 0.5 / 1.75);
        assert_close(audio[6], 0.25 / 1.75);
    }

    #[test]
    fn fractional_delay_uses_linear_interpolation() {
        let mut delay = FeedbackDelayDsp::default();
        configure_delay(&mut delay.delay, 1.0, 0.0);
        delay.prepare(1500, 1);

        let mut audio = [1.0, 0.0, 0.0, 0.0];
        delay.process_block(&mut [&mut audio]);

        assert_close(audio[1], 0.5);
        assert_close(audio[2], 0.5);
    }

    #[test]
    fn supports_the_five_second_delay_boundary() {
        let mut delay = FeedbackDelayDsp::default();
        configure_delay(&mut delay.delay, 5000.0, 0.0);
        delay.prepare(1000, 1);

        let mut audio = vec![0.0; 5001];
        audio[0] = 1.0;
        delay.process_block(&mut [&mut audio]);

        assert_close(audio[5000], 1.0);
    }

    #[test]
    fn reset_clears_pending_echoes() {
        let mut delay = FeedbackDelayDsp::default();
        configure_delay(&mut delay.delay, 3.0, 0.5);
        delay.prepare(1000, 1);

        let mut input = [1.0, 0.0];
        delay.process_block(&mut [&mut input]);
        delay.reset();

        let mut silence = [0.0; 8];
        delay.process_block(&mut [&mut silence]);
        assert!(silence.iter().all(|sample| sample.abs() < EPSILON));
    }

    #[test]
    fn output_is_independent_of_callback_size() {
        fn render(callback_size: usize) -> Vec<f64> {
            let mut delay = FeedbackDelayDsp::default();
            configure_delay(&mut delay.delay, 7.5, 0.6);
            delay.prepare(1000, 2);
            let mut left = vec![0.0; 96];
            let mut right = vec![0.0; 96];
            left[0] = 1.0;
            right[5] = -0.5;

            for (left_chunk, right_chunk) in left
                .chunks_mut(callback_size)
                .zip(right.chunks_mut(callback_size))
            {
                delay.process_block(&mut [left_chunk, right_chunk]);
            }
            left.extend(right);
            left
        }

        let expected = render(96);
        for callback_size in [1, 3, 16, 31] {
            let actual = render(callback_size);
            for (actual, expected) in actual.iter().zip(&expected) {
                assert_close(*actual, *expected);
            }
        }
    }

    #[test]
    fn processing_does_not_resize_delay_storage() {
        let mut delay = MultiTapDelayDsp::default();
        delay.prepare(48000, 2);
        let capacities: Vec<_> = delay.delay.ring_buffers.iter().map(Vec::capacity).collect();
        let pointers: Vec<_> = delay.delay.ring_buffers.iter().map(Vec::as_ptr).collect();

        delay.delay.delay_ms.set_base(5000.0);
        delay.delay.tap_count.set_base(8);
        let mut left = [0.0; 128];
        let mut right = [0.0; 128];
        delay.process_block(&mut [&mut left, &mut right]);

        for (index, buffer) in delay.delay.ring_buffers.iter().enumerate() {
            assert_eq!(buffer.capacity(), capacities[index]);
            assert_eq!(buffer.as_ptr(), pointers[index]);
        }
    }

    #[test]
    fn invalid_layouts_are_passed_through() {
        let mut delay = FeedbackDelayDsp::default();
        delay.prepare(1000, 2);
        let mut mono = [1.0, 2.0];
        delay.process_block(&mut [&mut mono]);
        assert_eq!(mono, [1.0, 2.0]);

        let mut left = [1.0, 2.0];
        let mut right = [3.0];
        delay.process_block(&mut [&mut left, &mut right]);
        assert_eq!(left, [1.0, 2.0]);
        assert_eq!(right, [3.0]);
    }

    #[test]
    fn multi_tap_exposes_shared_and_specific_parameters() {
        let delay = DelayDsp::<SimpleDelayMode>::default();
        let paths: Vec<_> = delay
            .auto_get_parameter_specs(karbeat_utils::hash::FNV_OFFSET, "")
            .into_iter()
            .map(|spec| spec.path)
            .collect();

        assert_eq!(
            paths,
            [
                "delay_ms",
                "feedback",
                "dry_mix",
                "wet_mix",
                "type",
                "tap_count",
                "tap_decay",
            ]
        );
    }
}
