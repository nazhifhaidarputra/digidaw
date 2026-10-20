//! Signalsmith Stretch implementations of the real-time stretch and pitch traits, on top of
//! `karbeat_signalsmith`.
//!
//! Both run the library's cheaper preset with split computation, so each block's spectral work
//! is spread evenly over the following callbacks instead of landing in one of them.
//!
//! - [`SignalsmithRealtimeStretcher`] stretches and shifts audio for the engine.
//! - [`SignalsmithLiveShifter`] shifts pitch in fixed blocks, for the pitch shifter plugin.

use karbeat_signalsmith::{MAX_CHANNELS, SsError, Stretcher};

use super::{
    StretchError,
    backend::{LivePitchShifter, RealtimeTimeStretcher},
};

/// Frames every [`SignalsmithLiveShifter::shift`] call takes and returns. Signalsmith accepts
/// any block size, so it is kept short: the plugin stages one block on top of the latency.
const LIVE_BLOCK_FRAMES: usize = 256;

impl From<SsError> for StretchError {
    fn from(error: SsError) -> Self {
        match error {
            SsError::CreateFailed => Self::Unavailable,
            SsError::UnsupportedChannels(_) | SsError::ChannelMismatch { .. } => {
                Self::InvalidInput("unsupported channel layout")
            }
            SsError::OutOfRange => Self::InvalidInput("a frame count is out of range"),
        }
    }
}

/// Real-time time stretcher and pitch shifter backed by Signalsmith Stretch.
#[derive(Debug)]
pub struct SignalsmithRealtimeStretcher {
    stretcher: Stretcher,
}

impl RealtimeTimeStretcher for SignalsmithRealtimeStretcher {
    fn new(sample_rate: u32, channels: usize) -> Result<Self, StretchError> {
        Ok(Self {
            stretcher: Stretcher::new(sample_rate, channels)?,
        })
    }

    fn set_pitch_scale(&mut self, scale: f64) {
        if scale.is_finite() && scale > 0.0 {
            self.stretcher.set_transpose_factor(scale);
        }
    }

    fn set_preserve_formants(&mut self, preserve: bool) {
        self.stretcher.set_formant_preserved(preserve);
    }

    fn reset(&mut self) {
        self.stretcher.reset();
    }

    fn input_latency(&self) -> usize {
        self.stretcher.input_latency()
    }

    fn output_latency(&self) -> usize {
        self.stretcher.output_latency()
    }

    fn seek_frames(&self) -> usize {
        self.stretcher.seek_length()
    }

    fn seek<C: AsRef<[f32]>>(&mut self, input: &[C], rate: f64) {
        // Only a wrong channel count fails, and then nothing is fed (see the trait docs).
        self.stretcher.seek(input, rate).ok();
    }

    fn process<I: AsRef<[f32]>, O: AsMut<[f32]>>(&mut self, input: &[I], output: &mut [O]) {
        self.stretcher.process(input, output).ok();
    }
}

/// Pitch-shift-only real-time shifter backed by Signalsmith Stretch, in blocks of
/// [`LIVE_BLOCK_FRAMES`].
#[derive(Debug)]
pub struct SignalsmithLiveShifter {
    stretcher: Stretcher,
}

impl LivePitchShifter for SignalsmithLiveShifter {
    fn new(
        sample_rate: u32,
        channels: usize,
        preserve_formants: bool,
    ) -> Result<Self, StretchError> {
        let mut stretcher = Stretcher::new(sample_rate, channels)?;
        stretcher.set_formant_preserved(preserve_formants);
        Ok(Self { stretcher })
    }

    fn block_size(&self) -> usize {
        LIVE_BLOCK_FRAMES
    }

    fn latency(&self) -> usize {
        self.stretcher
            .input_latency()
            .saturating_add(self.stretcher.output_latency())
    }

    fn set_pitch_scale(&mut self, scale: f64) {
        if scale.is_finite() && scale > 0.0 {
            self.stretcher.set_transpose_factor(scale);
        }
    }

    fn set_preserve_formants(&mut self, preserve: bool) {
        self.stretcher.set_formant_preserved(preserve);
    }

    fn shift<I: AsRef<[f32]>, O: AsMut<[f32]>>(
        &mut self,
        input: &[I],
        output: &mut [O],
    ) -> Result<(), StretchError> {
        let (input_channels, output_channels) = (input.len(), output.len());
        let mut inputs: [&[f32]; MAX_CHANNELS] = [&[]; MAX_CHANNELS];
        for (head, channel) in inputs.iter_mut().zip(input) {
            *head = channel
                .as_ref()
                .get(..LIVE_BLOCK_FRAMES)
                .unwrap_or_default();
        }
        let mut outputs: [&mut [f32]; MAX_CHANNELS] = Default::default();
        for (head, channel) in outputs.iter_mut().zip(output.iter_mut()) {
            *head = channel
                .as_mut()
                .get_mut(..LIVE_BLOCK_FRAMES)
                .unwrap_or_default();
        }
        let inputs = inputs.get(..input_channels).unwrap_or_default();
        let outputs = outputs.get_mut(..output_channels).unwrap_or_default();
        if inputs
            .iter()
            .any(|channel| channel.len() < LIVE_BLOCK_FRAMES)
            || outputs
                .iter()
                .any(|channel| channel.len() < LIVE_BLOCK_FRAMES)
        {
            return Err(StretchError::InvalidInput("channel buffers are too short"));
        }
        Ok(self.stretcher.process(inputs, outputs)?)
    }

    fn reset(&mut self) {
        self.stretcher.reset();
    }
}

#[cfg(test)]
#[allow(
    clippy::unwrap_used,
    clippy::as_conversions,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects,
    reason = "test fixtures fail immediately on unexpected results"
)]
mod tests {
    use std::time::{Duration, Instant};

    use super::*;

    const RATE: u32 = 48_000;
    /// Engine callback size the load is measured at.
    const CALLBACK: usize = 256;

    /// Stereo harmonics with a little noise, so the stretcher never takes its silence path.
    fn music(frames: usize) -> [Vec<f32>; 2] {
        let mut noise = fastrand::Rng::with_seed(7);
        let channel = |detune: f32, noise: &mut fastrand::Rng| -> Vec<f32> {
            (0..frames)
                .map(|i| {
                    let t = i as f32 / RATE as f32;
                    (1..6)
                        .map(|h| (t * 220.0 * detune * h as f32 * std::f32::consts::TAU).sin())
                        .sum::<f32>()
                        * 0.1
                        + (noise.f32() - 0.5) * 0.05
                })
                .collect()
        };
        [channel(1.0, &mut noise), channel(1.003, &mut noise)]
    }

    /// Plays `seconds` of stereo through one stretcher in [`CALLBACK`]-frame callbacks at
    /// `ratio` input frames per output frame. Returns the average, 99th percentile and worst
    /// callback time as fractions of the callback's duration.
    fn load(seconds: usize, ratio: f64, pitch: f64, formants: bool) -> (f64, f64, f64) {
        let input = music(RATE as usize * seconds * 2);
        let mut stretcher = SignalsmithRealtimeStretcher::new(RATE, 2).unwrap();
        stretcher.set_pitch_scale(pitch);
        stretcher.set_preserve_formants(formants);
        let mut output = [vec![0.0; CALLBACK], vec![0.0; CALLBACK]];
        let callbacks = RATE as usize * seconds / CALLBACK;
        let mut position = 0.0_f64;
        let mut times = Vec::with_capacity(callbacks);
        for _ in 0..callbacks {
            let start = position as usize;
            position += CALLBACK as f64 * ratio;
            let end = position as usize;
            let [left, right] = &mut output;
            let started = Instant::now();
            stretcher.process(
                &[&input[0][start..end], &input[1][start..end]],
                &mut [&mut left[..], &mut right[..]],
            );
            times.push(started.elapsed());
        }
        let callback = CALLBACK as f64 / f64::from(RATE);
        let total: Duration = times.iter().sum();
        times.sort_unstable();
        (
            total.as_secs_f64() / (callbacks as f64 * callback),
            times[callbacks * 99 / 100].as_secs_f64() / callback,
            times[callbacks - 1].as_secs_f64() / callback,
        )
    }

    #[test]
    #[ignore = "benchmark: DSP load of one realtime stretcher"]
    fn bench_realtime_load() {
        for (name, ratio, pitch, formants) in [
            ("pitch +5 st", 1.0, 2_f64.powf(5.0 / 12.0), false),
            ("pitch +5 st, formants", 1.0, 2_f64.powf(5.0 / 12.0), true),
            ("tempo 1.25x", 1.25, 1.0, false),
            ("tempo 0.8x", 0.8, 1.0, false),
            (
                "tempo 1.25x, pitch -3 st",
                1.25,
                2_f64.powf(-3.0 / 12.0),
                false,
            ),
        ] {
            let (average, p99, worst) = load(20, ratio, pitch, formants);
            eprintln!(
                "48 kHz stereo, {name}: {:.2}% average, {:.1}% p99, {:.1}% worst \
                 {CALLBACK}-frame callback",
                average * 100.0,
                p99 * 100.0,
                worst * 100.0
            );
        }
    }
}
