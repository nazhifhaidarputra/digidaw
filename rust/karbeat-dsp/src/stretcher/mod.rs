//! Time stretching and pitch shifting.
//!
//! [`backend`] defines the algorithm-neutral traits; the `Default*` aliases below pick the
//! implementation every consumer uses. Swapping the algorithm means implementing those
//! traits and changing the aliases. The current implementation is the Rubber Band Library.
//!
//! [`stretch_offline`] renders a whole input with the default offline stretcher; not real-time
//! safe, so run it on a background worker. [`stretch_offline_parallel`] splits long input into
//! chunks stretched in parallel.

use std::fmt;

pub mod backend;
mod parallel;
pub mod rubberband;

pub use backend::{LivePitchShifter, OfflineTimeStretcher, RealtimeTimeStretcher};
pub use parallel::{PARALLEL_MIN_SECONDS, stretch_offline_parallel};

/// The real-time, fixed-block pitch shifter.
pub type DefaultLivePitchShifter = rubberband::RubberBandLiveShifter;
/// The real-time time stretcher used by the audio engine.
pub type DefaultRealtimeStretcher = rubberband::RubberBandRealtimeStretcher;
/// The offline time stretcher used by background renders.
pub type DefaultOfflineStretcher = rubberband::RubberBandOfflineStretcher;

/// Highest channel count accepted by an offline stretch.
const MAX_CHANNELS: usize = 8;

/// Channels the audio engine's real-time stretchers process: its stereo output.
pub const REALTIME_CHANNELS: usize = 2;

/// One offline stretch of interleaved audio.
#[derive(Clone, Copy, Debug)]
pub struct OfflineStretch<'a> {
    pub sample_rate: u32,
    pub channels: usize,
    /// Interleaved input samples; the length must be a multiple of `channels`.
    pub input: &'a [f32],
    /// Output length divided by input length; `1.0` keeps the duration.
    pub time_ratio: f64,
    /// Frequency multiplier; `1.0` keeps the pitch.
    pub pitch_scale: f64,
    /// Preserve the spectral envelope when shifting pitch, for voices and instruments.
    pub preserve_formants: bool,
    /// Optional `(input_frame, output_frame)` pairs, strictly increasing in both frames,
    /// that pin input frames to exact output frames. Empty for a constant ratio.
    pub key_frames: &'a [(usize, usize)],
}

/// Why a stretch did not complete.
#[derive(Debug, Clone, PartialEq)]
pub enum StretchError {
    /// The cancellation check returned `true`.
    Cancelled,
    /// The request cannot be processed.
    InvalidInput(&'static str),
    /// The stretcher could not be created.
    Unavailable,
}

impl fmt::Display for StretchError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Cancelled => f.write_str("time stretch was cancelled"),
            Self::InvalidInput(reason) => write!(f, "invalid time stretch request: {reason}"),
            Self::Unavailable => f.write_str("the time stretcher could not be created"),
        }
    }
}

impl std::error::Error for StretchError {}
fn validate(request: &OfflineStretch<'_>) -> Result<u32, StretchError> {
    if request.channels == 0 || request.channels > MAX_CHANNELS {
        return Err(StretchError::InvalidInput(
            "channel count must be between 1 and 8",
        ));
    }
    if !request.input.len().is_multiple_of(request.channels) {
        return Err(StretchError::InvalidInput(
            "input length is not a whole number of frames",
        ));
    }
    if !(request.time_ratio.is_finite() && request.time_ratio > 0.0)
        || !(request.pitch_scale.is_finite() && request.pitch_scale > 0.0)
    {
        return Err(StretchError::InvalidInput(
            "time ratio and pitch scale must be positive",
        ));
    }
    let frames = u32::try_from(request.input.len().div_euclid(request.channels))
        .map_err(|_| StretchError::InvalidInput("input is too long"))?;
    let increasing = request
        .key_frames
        .windows(2)
        .all(|pair| matches!(pair, [a, b] if b.0 > a.0 && b.1 > a.1));
    if !increasing {
        return Err(StretchError::InvalidInput(
            "key frames must be strictly increasing",
        ));
    }
    Ok(frames)
}

/// Stretches `request.input` with [`DefaultOfflineStretcher`]; see
/// [`OfflineTimeStretcher::stretch`].
pub fn stretch_offline(
    request: &OfflineStretch<'_>,
    cancelled: &dyn Fn() -> bool,
    progress: &mut dyn FnMut(f32),
    sink: &mut dyn FnMut(&[f32]),
) -> Result<usize, StretchError> {
    DefaultOfflineStretcher::default().stretch(request, cancelled, progress, sink)
}

#[cfg(test)]
#[allow(
    clippy::unwrap_used,
    clippy::indexing_slicing,
    clippy::as_conversions,
    reason = "test fixtures fail immediately on unexpected results"
)]
mod tests {
    use super::{OfflineStretch, StretchError, stretch_offline};

    const RATE: u32 = 48_000;

    fn sine(frames: usize, channels: usize) -> Vec<f32> {
        (0..frames)
            .flat_map(|frame| {
                let value = (frame as f32 * 440.0 * std::f32::consts::TAU / RATE as f32).sin();
                std::iter::repeat_n(value * 0.5, channels)
            })
            .collect()
    }

    fn request(input: &[f32], channels: usize, time_ratio: f64) -> OfflineStretch<'_> {
        OfflineStretch {
            sample_rate: RATE,
            channels,
            input,
            time_ratio,
            pitch_scale: 1.0,
            preserve_formants: false,
            key_frames: &[],
        }
    }

    fn run(request: &OfflineStretch<'_>) -> Result<Vec<f32>, StretchError> {
        let mut output = Vec::new();
        stretch_offline(request, &|| false, &mut |_| {}, &mut |block| {
            output.extend_from_slice(block)
        })?;
        Ok(output)
    }

    fn assert_close(actual: usize, expected: usize) {
        let tolerance = expected / 100 + 1;
        assert!(
            actual.abs_diff(expected) <= tolerance,
            "{actual} frames, expected about {expected}"
        );
    }

    #[test]
    fn output_length_follows_the_time_ratio() {
        let input = sine(RATE as usize, 2);
        for ratio in [0.75, 1.0, 1.5] {
            let output = run(&request(&input, 2, ratio)).unwrap();
            assert_close(output.len() / 2, (RATE as f64 * ratio) as usize);
        }
    }

    #[test]
    fn progress_reaches_one_and_counts_every_output_frame() {
        let input = sine(RATE as usize / 2, 1);
        let mut last = 0.0;
        let mut streamed = 0;
        let written = stretch_offline(
            &request(&input, 1, 2.0),
            &|| false,
            &mut |fraction| {
                assert!(fraction >= last);
                last = fraction;
            },
            &mut |block| streamed += block.len(),
        )
        .unwrap();
        assert_eq!(last, 1.0);
        assert_eq!(written, streamed);
        assert_close(written, RATE as usize);
    }

    #[test]
    fn cancellation_stops_the_render() {
        let input = sine(RATE as usize, 2);
        let result = stretch_offline(
            &request(&input, 2, 1.25),
            &|| true,
            &mut |_| {},
            &mut |_| {},
        );
        assert_eq!(result, Err(StretchError::Cancelled));
    }

    #[test]
    fn key_frame_pins_an_input_transient_to_its_output_frame() {
        let frames = RATE as usize;
        let mut input = vec![0.0_f32; frames];
        let click = frames / 2;
        for sample in &mut input[click..click + 32] {
            *sample = 0.9;
        }
        let target = click * 3 / 2 + RATE as usize / 10;
        let key_frames = [(click, target)];
        let output = run(&OfflineStretch {
            key_frames: &key_frames,
            ..request(&input, 1, 1.5)
        })
        .unwrap();

        let peak = output
            .iter()
            .enumerate()
            .max_by(|a, b| a.1.abs().total_cmp(&b.1.abs()))
            .map(|(index, _)| index)
            .unwrap();
        assert!(
            peak.abs_diff(target) < 2_048,
            "transient at {peak}, expected near {target}"
        );
    }

    #[test]
    fn invalid_requests_are_rejected() {
        let input = sine(1_000, 2);
        assert!(matches!(
            run(&request(&input[..3], 2, 1.0)),
            Err(StretchError::InvalidInput(_))
        ));
        assert!(matches!(
            run(&request(&input, 2, 0.0)),
            Err(StretchError::InvalidInput(_))
        ));
        let backwards = [(500, 500), (400, 600)];
        assert!(matches!(
            run(&OfflineStretch {
                key_frames: &backwards,
                ..request(&input, 2, 1.0)
            }),
            Err(StretchError::InvalidInput(_))
        ));
    }
}
