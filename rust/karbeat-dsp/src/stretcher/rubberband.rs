//! Rubber Band implementations of the stretch and pitch traits, on top of `karbeat_rb`.
//!
//! - [`RubberBandOfflineStretcher`] runs `RubberBandStretcher` in offline mode: the whole input
//!   is studied first, then processed, which gives the best quality and allows a key-frame map
//!   that pins chosen input frames (such as detected beats) to exact output frames.
//! - [`RubberBandRealtimeStretcher`] runs it in real-time mode for the audio engine.
//! - [`RubberBandLiveShifter`] wraps `RubberBandLiveShifter`, the fixed-block pitch shifter.

#![allow(
    clippy::as_conversions,
    reason = "progress fractions are computed from block counts"
)]

use karbeat_rb::{LiveOptions, LiveShifter, MAX_CHANNELS, RbError, Stretcher, StretcherOptions};

use super::{
    OfflineStretch, StretchError,
    backend::{LivePitchShifter, OfflineTimeStretcher, RealtimeTimeStretcher},
    validate,
};

/// Frames handed to Rubber Band per call when rendering offline.
const BLOCK_FRAMES: usize = 4096;
/// Share of the progress range spent in the study pass; processing takes the rest.
const STUDY_WEIGHT: f32 = 0.2;

impl From<RbError> for StretchError {
    fn from(error: RbError) -> Self {
        match error {
            RbError::CreateFailed => Self::Unavailable,
            RbError::UnsupportedChannels(_) | RbError::ChannelMismatch { .. } => {
                Self::InvalidInput("unsupported channel layout")
            }
            RbError::ShortBuffer { .. } => Self::InvalidInput("channel buffers are too short"),
            RbError::OutOfRange => Self::InvalidInput("a frame count or key frame is out of range"),
        }
    }
}

/// The first `count` entries, or all of them if `count` is out of range.
fn active<T>(items: &[T], count: usize) -> &[T] {
    items.get(..count).unwrap_or(items)
}

/// Pitch-shift-only real-time shifter backed by `RubberBandLiveShifter`.
#[derive(Debug)]
pub struct RubberBandLiveShifter {
    shifter: LiveShifter,
}

impl LivePitchShifter for RubberBandLiveShifter {
    fn new(
        sample_rate: u32,
        channels: usize,
        preserve_formants: bool,
    ) -> Result<Self, StretchError> {
        let options = LiveOptions {
            formant_preserved: preserve_formants,
        };
        Ok(Self {
            shifter: LiveShifter::new(sample_rate, channels, options)?,
        })
    }

    fn block_size(&self) -> usize {
        self.shifter.block_size()
    }

    fn latency(&self) -> usize {
        self.shifter.start_delay()
    }

    fn set_pitch_scale(&mut self, scale: f64) {
        self.shifter.set_pitch_scale(scale);
    }

    fn set_preserve_formants(&mut self, preserve: bool) {
        self.shifter.set_formant_preserved(preserve);
    }

    fn shift<I: AsRef<[f32]>, O: AsMut<[f32]>>(
        &mut self,
        input: &[I],
        output: &mut [O],
    ) -> Result<(), StretchError> {
        Ok(self.shifter.shift(input, output)?)
    }

    fn reset(&mut self) {
        self.shifter.reset();
    }
}

/// Real-time time stretcher and pitch shifter backed by `RubberBandStretcher` (R3 engine).
///
/// A call with the wrong channel count feeds or retrieves nothing.
#[derive(Debug)]
pub struct RubberBandRealtimeStretcher {
    stretcher: Stretcher,
    time_ratio: f64,
    pitch_scale: f64,
    max_process_frames: usize,
}

impl RealtimeTimeStretcher for RubberBandRealtimeStretcher {
    fn new(
        sample_rate: u32,
        channels: usize,
        max_process_frames: usize,
    ) -> Result<Self, StretchError> {
        let options = StretcherOptions {
            realtime: true,
            engine_finer: true,
            channels_together: true,
            ..StretcherOptions::default()
        };
        let mut stretcher = Stretcher::new(sample_rate, channels, options, 1.0, 1.0)?;
        let max_process_frames = max_process_frames.max(1);
        stretcher.set_max_process_size(max_process_frames)?;
        Ok(Self {
            stretcher,
            time_ratio: 1.0,
            pitch_scale: 1.0,
            max_process_frames,
        })
    }

    fn max_process_frames(&self) -> usize {
        self.max_process_frames
    }

    fn set_time_ratio(&mut self, ratio: f64) {
        if ratio.is_finite() && ratio > 0.0 && (ratio - self.time_ratio).abs() > 1e-9 {
            self.time_ratio = ratio;
            self.stretcher.set_time_ratio(ratio);
        }
    }

    fn set_pitch_scale(&mut self, scale: f64) {
        if scale.is_finite() && scale > 0.0 && (scale - self.pitch_scale).abs() > 1e-9 {
            self.pitch_scale = scale;
            self.stretcher.set_pitch_scale(scale);
        }
    }

    fn reset(&mut self) {
        self.stretcher.reset();
    }

    fn start_pad(&self) -> usize {
        self.stretcher.start_pad()
    }

    fn start_delay(&self) -> usize {
        self.stretcher.start_delay()
    }

    fn samples_required(&self) -> usize {
        self.stretcher.samples_required()
    }

    fn process<C: AsRef<[f32]>>(&mut self, input: &[C]) {
        let mut heads: [&[f32]; MAX_CHANNELS] = [&[]; MAX_CHANNELS];
        for (head, channel) in heads.iter_mut().zip(input) {
            let channel = channel.as_ref();
            *head = channel.get(..self.max_process_frames).unwrap_or(channel);
        }
        // Only a wrong channel count fails, and then nothing is fed (see the type docs).
        self.stretcher
            .process(active(&heads, input.len()), false)
            .ok();
    }

    fn available(&self) -> usize {
        self.stretcher.available().unwrap_or(0)
    }

    fn retrieve<C: AsMut<[f32]>>(&mut self, output: &mut [C]) -> usize {
        self.stretcher.retrieve(output).unwrap_or(0)
    }
}

/// Offline, whole-input stretcher backed by `RubberBandStretcher` (R3 engine). Not real-time
/// safe; run it on a background worker.
#[derive(Clone, Copy, Debug, Default)]
pub struct RubberBandOfflineStretcher;

impl RubberBandOfflineStretcher {
    fn create(request: &OfflineStretch<'_>, frames: usize) -> Result<Stretcher, StretchError> {
        let shifts_pitch = (request.pitch_scale - 1.0).abs() > f64::EPSILON;
        let options = StretcherOptions {
            engine_finer: true,
            channels_together: request.channels > 1,
            pitch_high_quality: shifts_pitch,
            formant_preserved: shifts_pitch && request.preserve_formants,
            ..StretcherOptions::default()
        };
        let mut stretcher = Stretcher::new(
            request.sample_rate,
            request.channels,
            options,
            request.time_ratio,
            request.pitch_scale,
        )?;
        stretcher.set_expected_input_duration(frames)?;
        stretcher.set_max_process_size(BLOCK_FRAMES)?;
        Ok(stretcher)
    }
}

impl OfflineTimeStretcher for RubberBandOfflineStretcher {
    fn stretch(
        &self,
        request: &OfflineStretch<'_>,
        cancelled: &dyn Fn() -> bool,
        progress: &mut dyn FnMut(f32),
        sink: &mut dyn FnMut(&[f32]),
    ) -> Result<usize, StretchError> {
        let frames = validate(request)? as usize;
        let channels = request.channels;
        let mut stretcher = Self::create(request, frames)?;
        let mut planar = Planar::new(channels);
        let block_samples = BLOCK_FRAMES.saturating_mul(channels);
        let blocks = request.input.chunks(block_samples);
        let block_count = blocks.len().max(1) as f32;

        for (index, block) in blocks.clone().enumerate() {
            if cancelled() {
                return Err(StretchError::Cancelled);
            }
            let frames = planar.load(block);
            stretcher.study(
                active(&planar.heads(frames), channels),
                index.saturating_add(1) == blocks.len(),
            )?;
            progress(STUDY_WEIGHT * index.saturating_add(1) as f32 / block_count);
        }

        if !request.key_frames.is_empty() {
            stretcher.set_key_frame_map(request.key_frames)?;
        }

        let mut output = Planar::new(channels);
        let mut interleaved = Vec::with_capacity(block_samples);
        let mut written = 0_usize;
        for (index, block) in blocks.clone().enumerate() {
            if cancelled() {
                return Err(StretchError::Cancelled);
            }
            let frames = planar.load(block);
            stretcher.process(
                active(&planar.heads(frames), channels),
                index.saturating_add(1) == blocks.len(),
            )?;
            written =
                written.saturating_add(drain(&mut stretcher, &mut output, &mut interleaved, sink)?);
            progress(
                STUDY_WEIGHT + (1.0 - STUDY_WEIGHT) * index.saturating_add(1) as f32 / block_count,
            );
        }
        if blocks.len() == 0 {
            stretcher.process(active(&planar.heads(0), channels), true)?;
        }
        // After the final block, `available` reports `None` once every frame is out.
        while stretcher.available().is_some() {
            if cancelled() {
                return Err(StretchError::Cancelled);
            }
            written =
                written.saturating_add(drain(&mut stretcher, &mut output, &mut interleaved, sink)?);
            if stretcher.available() == Some(0) {
                std::thread::yield_now();
            }
        }
        progress(1.0);
        Ok(written)
    }
}

/// Streams every ready frame to `sink`; returns how many.
fn drain(
    stretcher: &mut Stretcher,
    output: &mut Planar,
    interleaved: &mut Vec<f32>,
    sink: &mut dyn FnMut(&[f32]),
) -> Result<usize, StretchError> {
    let channels = stretcher.channels();
    let mut written = 0_usize;
    while let Some(available) = stretcher.available() {
        if available == 0 {
            break;
        }
        let mut heads = output.heads_mut(available.min(BLOCK_FRAMES));
        let retrieved = stretcher.retrieve(heads.get_mut(..channels).unwrap_or_default())?;
        if retrieved == 0 {
            break;
        }
        output.interleave(retrieved, interleaved);
        sink(interleaved);
        written = written.saturating_add(retrieved);
    }
    Ok(written)
}

/// Per-channel scratch of [`BLOCK_FRAMES`] frames, reused for every block.
struct Planar {
    channels: Vec<Vec<f32>>,
}

impl Planar {
    fn new(channels: usize) -> Self {
        Self {
            channels: vec![vec![0.0; BLOCK_FRAMES]; channels],
        }
    }

    /// Splits interleaved `input` frames into the channel buffers; returns the frame count.
    fn load(&mut self, input: &[f32]) -> usize {
        let count = self.channels.len().max(1);
        let mut frames = 0;
        for (frame_index, frame) in input.chunks_exact(count).enumerate() {
            for (channel, sample) in self.channels.iter_mut().zip(frame) {
                if let Some(slot) = channel.get_mut(frame_index) {
                    *slot = *sample;
                }
            }
            frames = frame_index.saturating_add(1);
        }
        frames.min(BLOCK_FRAMES)
    }

    /// The first `frames` frames of every channel.
    fn heads(&self, frames: usize) -> [&[f32]; MAX_CHANNELS] {
        let mut heads: [&[f32]; MAX_CHANNELS] = [&[]; MAX_CHANNELS];
        for (head, channel) in heads.iter_mut().zip(&self.channels) {
            *head = channel.get(..frames).unwrap_or(channel);
        }
        heads
    }

    /// The first `frames` frames of every channel, writable.
    fn heads_mut(&mut self, frames: usize) -> [&mut [f32]; MAX_CHANNELS] {
        let mut heads: [&mut [f32]; MAX_CHANNELS] = Default::default();
        for (head, channel) in heads.iter_mut().zip(&mut self.channels) {
            let len = channel.len();
            *head = channel.get_mut(..frames.min(len)).unwrap_or_default();
        }
        heads
    }

    /// Interleaves the first `frames` frames into `output`, replacing its contents.
    fn interleave(&self, frames: usize, output: &mut Vec<f32>) {
        output.clear();
        for frame in 0..frames {
            for channel in &self.channels {
                output.push(channel.get(frame).copied().unwrap_or(0.0));
            }
        }
    }
}
