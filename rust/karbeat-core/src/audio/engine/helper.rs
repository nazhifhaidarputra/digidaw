use dasp::slice;
use hashbrown::HashMap;
use itertools::Itertools;
use karbeat_plugin_api::types::{AudioBuffers, AudioBusBuffer, ProcessContext};
use karbeat_utils::math::hermite_interp;
use wide::{f32x8, f32x16};

use crate::{
    audio::engine::runtime::consts::MAX_ENGINE_CHANNELS,
    commands::MixerChannelTarget,
    core::project::{
        AudioTrack, AutomationTarget, MixerChannelParamTarget, MixerChannelParams,
        RoutingConnection, RoutingNode, SidechainRoute, TrackAutomationTarget, equal_power,
    },
    shared::BusId,
};

/// Gain of each frame a waveform render produces.
pub trait FrameGain {
    /// Gain of the `frame`-th frame rendered by this call, read from source frame `read_pos`.
    /// Called once per frame in rising frame order, except for frames a
    /// [`unity_run`](Self::unity_run) covers.
    fn at(&mut self, frame: u32, read_pos: f64) -> f32;

    /// Number of frames, starting at `frame`, whose gain is exactly 1.0. The renderer mixes
    /// those without calling [`at`](Self::at). Zero when the gain has to be evaluated.
    fn unity_run(&self, _frame: u32) -> u32 {
        0
    }
}

impl<F: FnMut(u32, f64) -> f32> FrameGain for F {
    #[inline(always)]
    fn at(&mut self, frame: u32, read_pos: f64) -> f32 {
        self(frame, read_pos)
    }
}

/// Renders an audio waveform slice by reading the source directly at `step` source frames per
/// output frame, with Hermite interpolation. Pitch follows the speed; pitch-preserving stretch
/// runs through a realtime stretcher before this point.
///
/// `gain` gives the gain of each rendered frame. When looping with a `loop_crossfade` of X
/// frames, the last X frames of the loop are equal-power blended into its first X frames and
/// every repeat after the first starts X frames in, so the loop plays with no jump at the wrap.
///
/// Stereo output is rendered in runs: stretches of frames that stay inside the source, cross no
/// loop wrap and touch no loop crossfade are mixed without per-frame bounds or wrap handling,
/// and as a plain copy when the source is read at its own rate. Frames at those edges go
/// through the per-frame sampler.
#[inline(always)]
#[allow(
    clippy::too_many_arguments,
    reason = "the real-time render path passes independent preallocated state explicitly"
)]
pub fn render_audio_waveform(
    source_buffer: &[f32],
    src_channels: usize,
    target_slice: &mut [f32],
    target_channels: usize,
    source_read_index: &mut f64,
    step: f64,
    is_looping: bool,
    loop_len: f64,
    loop_crossfade: f64,
    base_volume: f32,
    mut gain: impl FrameGain,
) {
    let bounds = LoopBounds::new(is_looping, loop_len, loop_crossfade);
    let base = *source_read_index;
    let frames_written = if target_channels == 2 {
        let frames = (target_slice.len() / 2) as u32;
        let mut renderer = StereoRuns {
            source: source_buffer,
            src_channels,
            output: target_slice,
            bounds,
            base,
            step,
            base_volume,
        };
        renderer.render(frames, &mut gain);
        frames
    } else {
        // Non-stereo output is a fallback path and stays per frame.
        let mut frames_written: u32 = 0;
        for sample in target_slice.iter_mut() {
            let rp = bounds.read_pos(base, f64::from(frames_written) * step);
            let s0 = bounds.sample(source_buffer, rp, src_channels);
            let gain0 = gain.at(frames_written, rp) * base_volume;
            *sample += s0[0] * gain0;
            frames_written += 1;
        }
        frames_written
    };

    // Advance the read pointer safely
    *source_read_index = bounds.read_pos(base, f64::from(frames_written) * step);
}

/// Shortest run worth setting up; shorter stretches go through the per-frame sampler.
const MIN_RUN_FRAMES: u32 = 4;
/// Frames whose gains are evaluated together before being applied.
const GAIN_CHUNK: usize = 32;

/// One stereo waveform render, split into runs.
struct StereoRuns<'a> {
    source: &'a [f32],
    src_channels: usize,
    /// Interleaved stereo destination the waveform is mixed into.
    output: &'a mut [f32],
    bounds: LoopBounds,
    base: f64,
    step: f64,
    base_volume: f32,
}

/// Where the frames of one run read the source: `(base + frame * step) - shift`.
#[derive(Clone, Copy)]
struct RunPosition {
    /// Zero before the first loop wrap; afterwards the distance wrapped back so far.
    shift: f64,
    wrapped: bool,
}

impl StereoRuns<'_> {
    fn render(&mut self, frames: u32, gain: &mut impl FrameGain) {
        let source_frames = if self.src_channels == 1 || self.src_channels == 2 {
            // A buffer that is not a whole number of frames plays as silence per frame.
            if self.source.len() % self.src_channels == 0 {
                self.source.len() / self.src_channels
            } else {
                0
            }
        } else {
            0
        };
        let loop_end = self.bounds.loop_end;
        let crossfade = self.bounds.crossfade;
        // Wrapped positions are rebuilt from whole-frame loop points, which keeps them equal
        // to the per-frame remainder.
        let runs_allowed = self.step > 0.0
            && self.step.is_finite()
            && self.base >= 0.0
            && self.base.is_finite()
            && source_frames > 0
            && (!self.bounds.is_looping
                || (loop_end.fract() == 0.0 && crossfade.fract() == 0.0 && loop_end > crossfade));
        // Reading the source at its own rate from a whole frame needs no interpolation.
        let copies = self.step == 1.0 && self.base.fract() == 0.0;
        let (low, mut high) = if copies {
            (0.0, source_frames as f64)
        } else {
            // Hermite reads one frame behind and two ahead.
            (1.0, source_frames as f64 - 2.0)
        };
        if self.bounds.is_looping {
            high = high.min(loop_end - crossfade);
        }

        let mut frame = 0;
        while frame < frames {
            let run = if runs_allowed {
                self.run_at(frame, frames, low, high)
            } else {
                None
            };
            match run {
                Some((position, length)) => {
                    if copies {
                        self.copy_run(frame, length, position, gain);
                    } else {
                        self.interpolated_run(frame, length, position, gain);
                    }
                    frame += length;
                }
                None => {
                    self.single_frame(frame, gain);
                    frame += 1;
                }
            }
        }
    }

    /// Source position of `frame` before any loop wrap.
    #[inline(always)]
    fn raw(&self, frame: u32) -> f64 {
        self.base + f64::from(frame) * self.step
    }

    /// The run position `frame` belongs to and its source position.
    #[inline(always)]
    fn locate(&self, frame: u32) -> (RunPosition, f64) {
        let raw = self.raw(frame);
        if !self.bounds.is_looping || raw < self.bounds.loop_end {
            return (
                RunPosition {
                    shift: 0.0,
                    wrapped: false,
                },
                raw,
            );
        }
        // Matches `get_read_pos`: the remainder is exact, so removing the whole periods
        // from the raw position reproduces it.
        let period = self.bounds.loop_end - self.bounds.crossfade;
        let past = raw - self.bounds.loop_end;
        let remainder = past % period;
        (
            RunPosition {
                shift: past - remainder,
                wrapped: true,
            },
            self.bounds.crossfade + remainder,
        )
    }

    /// Source position of `frame` inside a run located by [`Self::locate`].
    #[inline(always)]
    fn position_in(&self, position: RunPosition, frame: u32) -> f64 {
        let raw = self.raw(frame);
        if position.wrapped {
            self.bounds.crossfade + ((raw - self.bounds.loop_end) - position.shift)
        } else {
            raw
        }
    }

    /// The longest run starting at `frame` whose source positions all lie in `low..high`
    /// without crossing a loop wrap, or `None` when it would be shorter than
    /// [`MIN_RUN_FRAMES`].
    fn run_at(&self, frame: u32, frames: u32, low: f64, high: f64) -> Option<(RunPosition, u32)> {
        let (position, first) = self.locate(frame);
        if !(first >= low && first < high) {
            return None;
        }
        let estimate = ((high - first) / self.step).ceil();
        let mut length = if estimate >= f64::from(frames - frame) {
            frames - frame
        } else {
            estimate as u32
        };
        // Positions rise with the frame, so checking the last frame covers the whole run.
        while length >= MIN_RUN_FRAMES {
            let last = frame + length - 1;
            let (last_position, last_source) = self.locate(last);
            if last_position.wrapped == position.wrapped
                && last_position.shift == position.shift
                && last_source < high
            {
                return Some((position, length));
            }
            length -= 1;
        }
        None
    }

    /// Mixes one frame through the bounds-checked sampler, loop wrap and crossfade included.
    #[inline(always)]
    fn single_frame(&mut self, frame: u32, gain: &mut impl FrameGain) {
        let rp = self
            .bounds
            .read_pos(self.base, f64::from(frame) * self.step);
        let sample = self.bounds.sample(self.source, rp, self.src_channels);
        let frame_gain = gain.at(frame, rp) * self.base_volume;
        let at = frame as usize * 2;
        if let Some([left, right]) = self.output.get_mut(at..at + 2) {
            *left += sample[0] * frame_gain;
            *right += sample[1] * frame_gain;
        }
    }

    /// Mixes `length` frames read at whole source frames: a copy scaled by the gain.
    fn copy_run(
        &mut self,
        first_frame: u32,
        length: u32,
        position: RunPosition,
        gain: &mut impl FrameGain,
    ) {
        let mut frame = first_frame;
        let end = first_frame + length;
        while frame < end {
            let source_frame = self.position_in(position, frame) as usize;
            let unity = gain.unity_run(frame).min(end - frame);
            if unity > 0 {
                let count = unity as usize;
                let out = &mut self.output[frame as usize * 2..(frame as usize + count) * 2];
                if self.src_channels == 2 {
                    let source = &self.source[source_frame * 2..(source_frame + count) * 2];
                    mix_scaled(out, source, self.base_volume);
                } else {
                    let source = &self.source[source_frame..source_frame + count];
                    mix_scaled_mono_to_stereo(out, source, self.base_volume);
                }
                frame += unity;
                continue;
            }

            let count = ((end - frame) as usize).min(GAIN_CHUNK);
            let mut gains = [0.0_f32; GAIN_CHUNK];
            for (offset, slot) in gains[..count].iter_mut().enumerate() {
                let chunk_frame = frame + offset as u32;
                // A unity run may start part-way through a chunk; evaluating it is equivalent.
                *slot = gain.at(chunk_frame, self.position_in(position, chunk_frame))
                    * self.base_volume;
            }
            let out = &mut self.output[frame as usize * 2..(frame as usize + count) * 2];
            if self.src_channels == 2 {
                let source = &self.source[source_frame * 2..(source_frame + count) * 2];
                for ((out, source), gain) in out
                    .chunks_exact_mut(2)
                    .zip(source.chunks_exact(2))
                    .zip(&gains[..count])
                {
                    out[0] += source[0] * gain;
                    out[1] += source[1] * gain;
                }
            } else {
                let source = &self.source[source_frame..source_frame + count];
                for ((out, source), gain) in
                    out.chunks_exact_mut(2).zip(source).zip(&gains[..count])
                {
                    out[0] += source * gain;
                    out[1] += source * gain;
                }
            }
            frame += count as u32;
        }
    }

    /// Mixes `length` frames whose four Hermite taps all lie inside the source.
    fn interpolated_run(
        &mut self,
        first_frame: u32,
        length: u32,
        position: RunPosition,
        gain: &mut impl FrameGain,
    ) {
        let mut frame = first_frame;
        let end = first_frame + length;
        while frame < end {
            let count = ((end - frame) as usize).min(GAIN_CHUNK);
            let unity = gain.unity_run(frame) as usize >= count;
            let mut gains = [self.base_volume; GAIN_CHUNK];
            let mut indices = [0_usize; GAIN_CHUNK];
            let mut alphas = [0.0_f32; GAIN_CHUNK];
            for offset in 0..count {
                let chunk_frame = frame + offset as u32;
                let rp = self.position_in(position, chunk_frame);
                let index = rp as usize;
                indices[offset] = index;
                alphas[offset] = (rp - (index as f64)) as f32;
                if !unity {
                    gains[offset] = gain.at(chunk_frame, rp) * self.base_volume;
                }
            }
            let out = &mut self.output[frame as usize * 2..(frame as usize + count) * 2];
            // Whole groups of eight frames evaluate the interpolation across lanes.
            let wide_frames = count - count % 8;
            for start in (0..wide_frames).step_by(8) {
                let alpha = f32x8::new(lanes(&alphas, start));
                let lane_gains = f32x8::new(lanes(&gains, start));
                let (left, right) = if self.src_channels == 2 {
                    let mut taps = [[0.0_f32; 8]; 8];
                    for lane in 0..8 {
                        let index = indices[start + lane];
                        let window = &self.source[(index - 1) * 2..(index + 3) * 2];
                        for (tap, value) in taps.iter_mut().zip(window) {
                            tap[lane] = *value;
                        }
                    }
                    let tap = |index: usize| f32x8::new(taps[index]);
                    (
                        hermite_x8(alpha, tap(0), tap(2), tap(4), tap(6)) * lane_gains,
                        hermite_x8(alpha, tap(1), tap(3), tap(5), tap(7)) * lane_gains,
                    )
                } else {
                    let mut taps = [[0.0_f32; 8]; 4];
                    for lane in 0..8 {
                        let index = indices[start + lane];
                        let window = &self.source[index - 1..index + 3];
                        for (tap, value) in taps.iter_mut().zip(window) {
                            tap[lane] = *value;
                        }
                    }
                    let tap = |index: usize| f32x8::new(taps[index]);
                    let value = hermite_x8(alpha, tap(0), tap(1), tap(2), tap(3)) * lane_gains;
                    (value, value)
                };
                let (left, right) = (left.to_array(), right.to_array());
                for (lane, out) in out[start * 2..(start + 8) * 2]
                    .chunks_exact_mut(2)
                    .enumerate()
                {
                    out[0] += left[lane];
                    out[1] += right[lane];
                }
            }
            if self.src_channels == 2 {
                for (offset, out) in out.chunks_exact_mut(2).enumerate().skip(wide_frames) {
                    let taps = &self.source[(indices[offset] - 1) * 2..(indices[offset] + 3) * 2];
                    let alpha = alphas[offset];
                    let left = hermite_interp(alpha, taps[0], taps[2], taps[4], taps[6]);
                    let right = hermite_interp(alpha, taps[1], taps[3], taps[5], taps[7]);
                    out[0] += left * gains[offset];
                    out[1] += right * gains[offset];
                }
            } else {
                for (offset, out) in out.chunks_exact_mut(2).enumerate().skip(wide_frames) {
                    let taps = &self.source[indices[offset] - 1..indices[offset] + 3];
                    let value = hermite_interp(alphas[offset], taps[0], taps[1], taps[2], taps[3]);
                    out[0] += value * gains[offset];
                    out[1] += value * gains[offset];
                }
            }
            frame += count as u32;
        }
    }
}

/// Eight consecutive values of `values` starting at `start`.
#[inline(always)]
fn lanes(values: &[f32; GAIN_CHUNK], start: usize) -> [f32; 8] {
    let mut lanes = [0.0; 8];
    lanes.copy_from_slice(&values[start..start + 8]);
    lanes
}

/// [`hermite_interp`] across eight lanes, with the same operations in the same order.
#[inline(always)]
fn hermite_x8(frac: f32x8, p0: f32x8, p1: f32x8, p2: f32x8, p3: f32x8) -> f32x8 {
    let half = f32x8::splat(0.5);
    let c1 = half * (p2 - p0);
    let c2 = p0 - f32x8::splat(2.5) * p1 + f32x8::splat(2.0) * p2 - half * p3;
    let c3 = half * (p3 - p0) + f32x8::splat(1.5) * (p1 - p2);
    ((c3 * frac + c2) * frac + c1) * frac + p1
}

/// Adds `source * gain` to `out`, sample by sample.
#[inline(always)]
fn mix_scaled(out: &mut [f32], source: &[f32], gain: f32) {
    let gain_v = f32x16::splat(gain);
    let (out_chunks, out_rest) = out.as_chunks_mut::<16>();
    let (source_chunks, source_rest) = source.as_chunks::<16>();
    for (out, source) in out_chunks.iter_mut().zip(source_chunks) {
        *out = (f32x16::new(*out) + f32x16::new(*source) * gain_v).to_array();
    }
    for (out, source) in out_rest.iter_mut().zip(source_rest) {
        *out += source * gain;
    }
}

/// Adds each mono `source` sample, scaled by `gain`, to both channels of interleaved `out`.
#[inline(always)]
fn mix_scaled_mono_to_stereo(out: &mut [f32], source: &[f32], gain: f32) {
    for (out, source) in out.chunks_exact_mut(2).zip(source) {
        let value = source * gain;
        out[0] += value;
        out[1] += value;
    }
}

/// Read-position wrapping and loop-crossfade sampling for one waveform render.
#[derive(Clone, Copy, Debug)]
pub struct LoopBounds {
    is_looping: bool,
    loop_end: f64,
    crossfade: f64,
}

impl LoopBounds {
    /// Bounds for a waveform of `loop_len` frames. The crossfade is capped at half the loop and
    /// ignored when not looping.
    #[inline(always)]
    pub fn new(is_looping: bool, loop_len: f64, crossfade: f64) -> Self {
        let crossfade = if is_looping {
            crossfade.clamp(0.0, loop_len / 2.0)
        } else {
            0.0
        };
        Self {
            is_looping,
            loop_end: loop_len,
            crossfade,
        }
    }

    /// Source frame `offset` frames after `base`, wrapped into the loop.
    #[inline(always)]
    pub fn read_pos(&self, base: f64, offset: f64) -> f64 {
        get_read_pos(
            base,
            offset,
            self.is_looping,
            self.loop_end,
            self.crossfade,
            self.loop_end - self.crossfade,
        )
    }

    /// Samples the frame at `rp`, blending in the loop start inside the loop-crossfade region.
    #[inline(always)]
    pub fn sample(&self, buffer: &[f32], rp: f64, channels: usize) -> [f32; 2] {
        let frame = sample_waveform_dasp(buffer, rp, channels);
        let fade_start = self.loop_end - self.crossfade;
        if self.crossfade <= 0.0 || rp < fade_start {
            return frame;
        }
        let head = sample_waveform_dasp(buffer, rp - fade_start, channels);
        let (fading_out, fading_in) = equal_power(((rp - fade_start) / self.crossfade) as f32);
        [
            frame[0] * fading_out + head[0] * fading_in,
            frame[1] * fading_out + head[1] * fading_in,
        ]
    }
}

/// Sample a waveform at a specific position using dasp interpolation.
/// Handles fallback from 1-channel to 2-channel stereo.
#[inline]
pub fn sample_waveform_dasp(buffer: &[f32], pos: f64, src_channels: usize) -> [f32; 2] {
    let idx = pos as usize;
    let alpha = (pos - (idx as f64)) as f32;

    if src_channels == 2 {
        let frames: &[[f32; 2]] = slice::from_sample_slice(buffer).unwrap_or(&[]);
        let len = frames.len();

        if idx >= len {
            return [0.0, 0.0];
        }

        if alpha == 0.0 {
            return frames[idx];
        }

        let p0 = if idx > 0 {
            frames[idx - 1]
        } else {
            frames[idx]
        };
        let p1 = frames[idx];
        let p2 = if idx + 1 < len { frames[idx + 1] } else { p1 };
        let p3 = if idx + 2 < len { frames[idx + 2] } else { p2 };

        [
            hermite_interp(alpha, p0[0], p1[0], p2[0], p3[0]),
            hermite_interp(alpha, p0[1], p1[1], p2[1], p3[1]),
        ]
    } else {
        let frames: &[[f32; 1]] = slice::from_sample_slice(buffer).unwrap_or(&[]);
        let len = frames.len();

        if idx >= len {
            return [0.0, 0.0];
        }

        if alpha == 0.0 {
            let val = frames[idx][0];
            return [val, val];
        }

        let p0 = if idx > 0 {
            frames[idx - 1]
        } else {
            frames[idx]
        };
        let p1 = frames[idx];
        let p2 = if idx + 1 < len { frames[idx + 1] } else { p1 };
        let p3 = if idx + 2 < len { frames[idx + 2] } else { p2 };

        let val = hermite_interp(alpha, p0[0], p1[0], p2[0], p3[0]);
        [val, val]
    }
}
#[inline(always)]
pub fn calc_fade(current_elapsed: u32, fade_samples: u32, loop_length: u32) -> f32 {
    if fade_samples == 0 {
        return 1.0;
    }
    if current_elapsed < fade_samples {
        (current_elapsed as f32) / (fade_samples as f32)
    } else if current_elapsed + fade_samples > loop_length {
        let remaining = loop_length.saturating_sub(current_elapsed);
        (remaining as f32) / (fade_samples as f32)
    } else {
        1.0
    }
}

#[inline(always)]
pub fn get_read_pos(
    base_idx: f64,
    offset: f64,
    is_looping: bool,
    trim_end: f64,
    start_bound: f64,
    loop_len: f64,
) -> f64 {
    let rp = base_idx + offset;
    if is_looping && rp >= trim_end {
        start_bound + ((rp - trim_end) % loop_len)
    } else {
        rp
    }
}

/// Helper function to decode 16-bit PCM WAV bytes into a flat f32 array
pub fn load_internal_wav(bytes: &[u8]) -> Vec<f32> {
    let cursor = std::io::Cursor::new(bytes);
    let Ok(reader) = hound::WavReader::new(cursor) else {
        return Vec::new();
    };

    // Convert 16-bit integer (-32768 to 32767) to f32 (-1.0 to 1.0)
    reader
        .into_samples::<i16>()
        .map(|s| (s.unwrap_or(0) as f32) / 32768.0)
        .collect()
}

#[inline(always)]
pub fn apply_phase_inversion_simd(buffer: &mut [f32]) {
    let neg_one = f32x16::splat(-1.0);
    let (simd_chunks, remaining_samples) = buffer.as_chunks_mut::<16>();

    for chunk in simd_chunks {
        let mut v = f32x16::new(*chunk);
        v *= neg_one;
        *chunk = v.to_array();
    }

    for sample in remaining_samples {
        *sample = -*sample;
    }
}

pub fn process_plugin_wrapper(
    plugin: &mut dyn crate::core::project::plugin::AudioPlugin,
    interleaved_io: &mut [f32],
    aux_interleaved: Option<&[f32]>,
    channels: usize,
    ctx: &ProcessContext,
    channel_buffers_in: &mut [Vec<f32>],
    channel_buffers_out: &mut [Vec<f32>],
    aux_channel_buffers: &mut [Vec<f32>],
) {
    let Some(frames) = prepare_planar_input(
        interleaved_io,
        channels,
        channel_buffers_in,
        channel_buffers_out,
    ) else {
        interleaved_io.fill(0.0);
        return;
    };

    if !process_plugin_planar(
        plugin,
        aux_interleaved,
        channels,
        frames,
        ctx,
        channel_buffers_in,
        channel_buffers_out,
        aux_channel_buffers,
    ) {
        interleaved_io.fill(0.0);
        return;
    }
    finish_planar_output(interleaved_io, channel_buffers_in, channels, frames);
}

pub fn prepare_planar_input(
    interleaved: &[f32],
    channels: usize,
    channel_buffers_in: &mut [Vec<f32>],
    channel_buffers_out: &[Vec<f32>],
) -> Option<usize> {
    if channels == 0
        || channels > MAX_ENGINE_CHANNELS as usize
        || !interleaved.len().is_multiple_of(channels)
        || channel_buffers_in.len() < channels
        || channel_buffers_out.len() < channels
    {
        return None;
    }
    let frames = interleaved.len() / channels;
    if channel_buffers_in[..channels]
        .iter()
        .chain(&channel_buffers_out[..channels])
        .any(|buffer| buffer.len() < frames)
    {
        return None;
    }
    deinterleave_buffer(interleaved, channel_buffers_in, channels, frames);
    Some(frames)
}

#[allow(
    clippy::too_many_arguments,
    reason = "the render path passes preallocated channel storage explicitly"
)]
pub fn process_plugin_planar(
    plugin: &mut dyn crate::core::project::plugin::AudioPlugin,
    aux_interleaved: Option<&[f32]>,
    channels: usize,
    frames: usize,
    ctx: &ProcessContext,
    channel_buffers_in: &mut [Vec<f32>],
    channel_buffers_out: &mut [Vec<f32>],
    aux_channel_buffers: &mut [Vec<f32>],
) -> bool {
    let has_aux = aux_interleaved.is_some();
    if has_aux
        && (aux_channel_buffers.len() < channels
            || aux_channel_buffers[..channels]
                .iter()
                .any(|buffer| buffer.len() < frames))
    {
        return false;
    }
    if let Some(aux) = aux_interleaved {
        if aux.len() < frames * channels {
            for buffer in aux_channel_buffers.iter_mut().take(channels) {
                buffer[..frames].fill(0.0);
            }
        } else {
            deinterleave_buffer(aux, aux_channel_buffers, channels, frames);
        }
    }

    {
        let mut in_ptrs: [&mut [f32]; MAX_ENGINE_CHANNELS as usize] =
            std::array::from_fn(|_| &mut [][..]);
        for (i, buffer) in channel_buffers_in.iter_mut().take(channels).enumerate() {
            in_ptrs[i] = &mut buffer[..frames];
        }

        let mut out_ptrs: [&mut [f32]; MAX_ENGINE_CHANNELS as usize] =
            std::array::from_fn(|_| &mut [][..]);
        for (i, buffer) in channel_buffers_out.iter_mut().take(channels).enumerate() {
            out_ptrs[i] = &mut buffer[..frames];
        }

        let mut aux_ptrs: [&mut [f32]; MAX_ENGINE_CHANNELS as usize] =
            std::array::from_fn(|_| &mut [][..]);
        for (i, buffer) in aux_channel_buffers.iter_mut().take(channels).enumerate() {
            aux_ptrs[i] = &mut buffer[..frames];
        }

        let mut main_in = [AudioBusBuffer {
            channel_data: &mut in_ptrs[..channels],
            is_silent: false,
        }];
        let mut main_out = [AudioBusBuffer {
            channel_data: &mut out_ptrs[..channels],
            is_silent: false,
        }];
        let mut aux_in = [AudioBusBuffer {
            channel_data: &mut aux_ptrs[..channels],
            is_silent: false,
        }];
        let aux_len = has_aux as usize;

        let mut buffers = AudioBuffers {
            main_inputs: &mut main_in,
            main_outputs: &mut main_out,
            aux_inputs: &mut aux_in[..aux_len],
            aux_outputs: &mut [],
        };

        plugin.process(&mut buffers, ctx);
    }

    for (input, output) in channel_buffers_in[..channels]
        .iter_mut()
        .zip(&mut channel_buffers_out[..channels])
    {
        std::mem::swap(input, output);
    }
    true
}

pub fn finish_planar_output(
    interleaved: &mut [f32],
    channel_buffers: &[Vec<f32>],
    channels: usize,
    frames: usize,
) {
    interleave_buffer(interleaved, channel_buffers, channels, frames);
}

#[inline]
fn deinterleave_buffer(
    interleaved: &[f32],
    channel_buffers: &mut [Vec<f32>],
    channels: usize,
    frames: usize,
) {
    if let ([left, right], 2) = (&mut *channel_buffers, channels)
        && let (Some(left), Some(right)) = (left.get_mut(..frames), right.get_mut(..frames))
    {
        // Plain element copies over fixed-size frames, which the compiler vectorizes.
        for ((left, right), [source_left, source_right]) in left
            .iter_mut()
            .zip(right)
            .zip(interleaved.as_chunks::<2>().0)
        {
            *left = *source_left;
            *right = *source_right;
        }
        return;
    }

    for (channel_index, destination) in channel_buffers.iter_mut().take(channels).enumerate() {
        destination[..frames].iter_mut().set_from(
            interleaved
                .iter()
                .skip(channel_index)
                .step_by(channels)
                .copied(),
        );
    }
}

#[inline]
fn interleave_buffer(
    interleaved: &mut [f32],
    channel_buffers: &[Vec<f32>],
    channels: usize,
    frames: usize,
) {
    if let ([left, right], 2) = (channel_buffers, channels)
        && let (Some(left), Some(right)) = (left.get(..frames), right.get(..frames))
    {
        for ([out_left, out_right], (left, right)) in interleaved
            .as_chunks_mut::<2>()
            .0
            .iter_mut()
            .zip(left.iter().zip(right))
        {
            *out_left = *left;
            *out_right = *right;
        }
        return;
    }

    for (channel_index, source) in channel_buffers.iter().take(channels).enumerate() {
        interleaved
            .iter_mut()
            .skip(channel_index)
            .step_by(channels)
            .set_from(source[..frames].iter().copied());
    }
}

// =============================================================================
// Routing Order Helper
// =============================================================================

/// Compute a topologically sorted routing order over tracks, buses, and master.
///
/// A connection into a plugin sidechain orders its source before the channel that owns the
/// plugin, so the aux buffer is filled before that channel's effects run. Nodes without a
/// dependency between them keep their input order (tracks, then buses, then master), and master
/// is always last. `MixerState` rejects cycles; any node left unscheduled by one is appended in
/// input order so the audio thread still renders it.
///
/// This mirrors `MixerState::get_routing_order` without needing the full `MixerState` on the
/// audio thread.
pub fn compute_routing_order(
    tracks: &[AudioTrack],
    bus_ids: impl Iterator<Item = BusId>,
    routing: &[RoutingConnection],
) -> Vec<RoutingNode> {
    let nodes: Vec<RoutingNode> = tracks
        .iter()
        .map(|track| RoutingNode::Track(track.id))
        .chain(bus_ids.map(RoutingNode::Bus))
        .chain(std::iter::once(RoutingNode::Master))
        .collect();
    let index: HashMap<RoutingNode, usize> = nodes
        .iter()
        .enumerate()
        .map(|(index, &node)| (node, index))
        .collect();

    let mut in_degree = vec![0_usize; nodes.len()];
    let mut adjacency = vec![Vec::new(); nodes.len()];
    for connection in routing {
        let destination = match connection.destination {
            RoutingNode::PluginSidechain(route) => sidechain_owner(tracks, route),
            other => Some(other),
        };
        let (Some(&source), Some(&destination)) = (
            index.get(&connection.source),
            destination.and_then(|node| index.get(&node)),
        ) else {
            continue;
        };
        if source != destination {
            adjacency[source].push(destination);
            in_degree[destination] += 1;
        }
    }

    let mut ready: std::collections::BinaryHeap<std::cmp::Reverse<usize>> = in_degree
        .iter()
        .enumerate()
        .filter(|(_, degree)| **degree == 0)
        .map(|(index, _)| std::cmp::Reverse(index))
        .collect();
    let mut scheduled = vec![false; nodes.len()];
    let mut order = Vec::with_capacity(nodes.len());
    while let Some(std::cmp::Reverse(index)) = ready.pop() {
        scheduled[index] = true;
        order.push(nodes[index]);
        for &next in &adjacency[index] {
            in_degree[next] -= 1;
            if in_degree[next] == 0 {
                ready.push(std::cmp::Reverse(next));
            }
        }
    }
    order.extend(
        nodes
            .iter()
            .zip(&scheduled)
            .filter(|(_, scheduled)| !**scheduled)
            .map(|(node, _)| *node),
    );
    order
}

/// Channel that owns the plugin fed by `route`, resolved from the audio thread's track list.
pub fn sidechain_owner(tracks: &[AudioTrack], route: SidechainRoute) -> Option<RoutingNode> {
    match route {
        SidechainRoute::Generator(generator_id) => tracks
            .iter()
            .find(|track| {
                track
                    .generator
                    .as_ref()
                    .is_some_and(|generator| generator.id == generator_id)
            })
            .map(|track| RoutingNode::Track(track.id)),
        SidechainRoute::TrackEffect(track_id, _) => Some(RoutingNode::Track(track_id)),
        SidechainRoute::BusEffect(bus_id, _) => Some(RoutingNode::Bus(bus_id)),
        SidechainRoute::MasterEffect(_) => Some(RoutingNode::Master),
    }
}

pub fn resolve_target_mixer_param(
    target: &MixerChannelTarget,
    param: &MixerChannelParams,
) -> (Option<AutomationTarget>, f32) {
    // First, extract the generic mixer target and the float value
    let (mix_target, val) = match param {
        MixerChannelParams::Volume(v) => (
            Some(MixerChannelParamTarget::Volume),
            ((*v - (-60.0)) / 66.0).clamp(0.0, 1.0),
        ),
        MixerChannelParams::Pan(v) => (
            Some(MixerChannelParamTarget::Pan),
            ((*v - (-1.0)) / 2.0).clamp(0.0, 1.0),
        ),
        MixerChannelParams::Mute(v) => (None, if *v { 1.0 } else { 0.0 }),
        MixerChannelParams::InvertedPhase(v) => (None, if *v { 1.0 } else { 0.0 }),
        MixerChannelParams::Solo(v) => (None, if *v { 1.0 } else { 0.0 }),
    };

    // If it's an automatable parameter, wrap it in its specific track/bus/master parent
    let automation_target = mix_target.map(|mt| match target {
        MixerChannelTarget::Track(track_id) => AutomationTarget::Track {
            track_id: *track_id,
            track_target: TrackAutomationTarget::MixerChannel(mt),
        },
        MixerChannelTarget::Bus(bus_id) => AutomationTarget::Bus {
            bus_id: *bus_id,
            mix_target: mt,
        },
        MixerChannelTarget::Master => AutomationTarget::Master(
            crate::core::project::MasterAutomationTarget::MixerChannel(mt),
        ),
    });

    (automation_target, val)
}

#[cfg(test)]
mod buffer_iteration_tests {
    use super::{
        apply_phase_inversion_simd, deinterleave_buffer, finish_planar_output, interleave_buffer,
        prepare_planar_input, process_plugin_planar,
    };
    use crate::audio::missing_plugin::MissingPlugin;
    use karbeat_plugin_api::types::{ProcessContext, ProcessingMode};

    fn process_context() -> ProcessContext<'static> {
        ProcessContext {
            bpm: 120.0,
            time_sig_numerator: 4,
            time_sig_denominator: 4,
            is_playing: true,
            is_recording: false,
            mode: ProcessingMode::Realtime,
            project_time_seconds: 0.0,
            project_time_samples: 0,
            beat_position: 1.0,
            bar_position: 1.0,
            loop_start_beat: None,
            loop_end_beat: None,
            midi_events: &[],
            param_changes: &[],
        }
    }

    #[test]
    fn stereo_deinterleave_round_trip_leaves_incomplete_frame_untouched() {
        let input = [1.0, 2.0, 3.0, 4.0, 99.0];
        let mut channels = vec![vec![0.0; 2], vec![0.0; 2]];

        deinterleave_buffer(&input, &mut channels, 2, 2);

        assert_eq!(channels, [[1.0, 3.0], [2.0, 4.0]]);

        let mut output = [0.0, 0.0, 0.0, 0.0, 99.0];
        interleave_buffer(&mut output, &channels, 2, 2);

        assert_eq!(output, input);
    }

    #[test]
    fn multichannel_deinterleave_round_trip() {
        let input = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0];
        let mut channels = vec![vec![0.0; 2], vec![0.0; 2], vec![0.0; 2]];

        deinterleave_buffer(&input, &mut channels, 3, 2);

        assert_eq!(channels, [[1.0, 4.0], [2.0, 5.0], [3.0, 6.0]]);

        let mut output = [0.0; 6];
        interleave_buffer(&mut output, &channels, 3, 2);

        assert_eq!(output, input);
    }

    #[test]
    fn phase_inversion_processes_simd_remainder() {
        let mut buffer: Vec<f32> = (1..=19).map(|sample| sample as f32).collect();

        apply_phase_inversion_simd(&mut buffer);

        assert_eq!(
            buffer,
            (1..=19).map(|sample| -(sample as f32)).collect::<Vec<_>>()
        );
    }

    #[test]
    fn planar_effect_chain_converts_only_at_chain_boundaries() {
        let input = [1.0, -1.0, 0.5, -0.5];
        let mut output = input;
        let mut channel_inputs = vec![vec![0.0; 2], vec![0.0; 2]];
        let mut channel_outputs = vec![vec![0.0; 2], vec![0.0; 2]];
        let mut aux = vec![vec![0.0; 2], vec![0.0; 2]];
        let frames = prepare_planar_input(&output, 2, &mut channel_inputs, &channel_outputs)
            .expect("valid stereo buffers");
        let mut first = MissingPlugin::effect();
        let mut second = MissingPlugin::effect();
        for plugin in [&mut first, &mut second] {
            assert!(process_plugin_planar(
                plugin.as_mut(),
                None,
                2,
                frames,
                &process_context(),
                &mut channel_inputs,
                &mut channel_outputs,
                &mut aux,
            ));
        }
        finish_planar_output(&mut output, &channel_inputs, 2, frames);
        assert_eq!(output, input);
    }
}

#[cfg(test)]
mod loop_crossfade_tests {
    use super::LoopBounds;

    /// Mono buffer whose sample value is its frame index.
    fn ramp(frames: usize) -> Vec<f32> {
        (0..frames).map(|frame| frame as f32).collect()
    }

    #[test]
    fn repeats_start_after_the_crossfade() {
        let bounds = LoopBounds::new(true, 100.0, 20.0);
        assert_eq!(bounds.read_pos(0.0, 50.0), 50.0);
        assert_eq!(bounds.read_pos(0.0, 100.0), 20.0);
        assert_eq!(bounds.read_pos(0.0, 180.0), 20.0);
    }

    #[test]
    fn loop_end_blends_into_the_loop_start_without_a_jump() {
        let buffer = ramp(100);
        let bounds = LoopBounds::new(true, 100.0, 20.0);
        // Before the crossfade region the loop plays untouched.
        assert_eq!(bounds.sample(&buffer, 70.0, 1)[0], 70.0);
        // At the region start only the tail sounds.
        assert_eq!(bounds.sample(&buffer, 80.0, 1)[0], 80.0);
        // Approaching the loop end the head takes over, meeting the wrap target.
        let near_end = bounds.sample(&buffer, 99.999, 1)[0];
        let after_wrap = bounds.sample(&buffer, bounds.read_pos(0.0, 100.0), 1)[0];
        assert!(
            (near_end - after_wrap).abs() < 0.05,
            "{near_end} vs {after_wrap}"
        );
    }

    #[test]
    fn crossfade_is_ignored_without_looping_and_capped_at_half_the_loop() {
        let buffer = ramp(100);
        let one_shot = LoopBounds::new(false, 100.0, 20.0);
        assert_eq!(one_shot.sample(&buffer, 90.0, 1)[0], 90.0);
        assert_eq!(one_shot.read_pos(0.0, 150.0), 150.0);

        let capped = LoopBounds::new(true, 100.0, 80.0);
        assert_eq!(capped.read_pos(0.0, 100.0), 50.0);
    }
}

#[cfg(test)]
mod waveform_run_tests {
    use super::{FrameGain, LoopBounds, render_audio_waveform};

    /// The per-frame renderer the run-based one replaced, kept as the reference.
    #[allow(clippy::too_many_arguments, reason = "mirrors the renderer under test")]
    fn reference(
        source: &[f32],
        src_channels: usize,
        target: &mut [f32],
        read_index: &mut f64,
        step: f64,
        is_looping: bool,
        loop_len: f64,
        loop_crossfade: f64,
        base_volume: f32,
        mut gain: impl FnMut(u32, f64) -> f32,
    ) {
        let bounds = LoopBounds::new(is_looping, loop_len, loop_crossfade);
        let mut frames = 0_u32;
        for frame in target.chunks_exact_mut(2) {
            let rp = bounds.read_pos(*read_index, f64::from(frames) * step);
            let sample = bounds.sample(source, rp, src_channels);
            let frame_gain = gain(frames, rp) * base_volume;
            frame[0] += sample[0] * frame_gain;
            frame[1] += sample[1] * frame_gain;
            frames += 1;
        }
        *read_index = bounds.read_pos(*read_index, f64::from(frames) * step);
    }

    /// Gain that ramps over its first and last `edge` frames and is unity in between, the
    /// shape of a clip without envelopes.
    struct EdgeRamp {
        frames: u32,
        edge: u32,
    }

    impl EdgeRamp {
        fn value(&self, frame: u32) -> f32 {
            if frame < self.edge {
                frame as f32 / self.edge as f32
            } else if frame + self.edge > self.frames {
                (self.frames - frame) as f32 / self.edge as f32
            } else {
                1.0
            }
        }
    }

    impl FrameGain for EdgeRamp {
        fn at(&mut self, frame: u32, _: f64) -> f32 {
            self.value(frame)
        }

        fn unity_run(&self, frame: u32) -> u32 {
            if frame < self.edge || frame + self.edge > self.frames {
                0
            } else {
                self.frames - self.edge - frame + 1
            }
        }
    }

    struct Lcg(u64);

    impl Lcg {
        fn next(&mut self) -> f32 {
            self.0 = self
                .0
                .wrapping_mul(6_364_136_223_846_793_005)
                .wrapping_add(1_442_695_040_888_963_407);
            ((self.0 >> 40) as f32 / (1_u64 << 24) as f32) * 2.0 - 1.0
        }
    }

    #[test]
    fn runs_render_exactly_what_the_per_frame_sampler_renders() {
        let mut random = Lcg(7);
        let mut cases = 0;
        for src_channels in [1_usize, 2] {
            for source_frames in [37_usize, 160, 401] {
                let source: Vec<f32> = (0..source_frames * src_channels)
                    .map(|_| random.next())
                    .collect();
                for step in [1.0, 0.5, 0.918_75, 1.37, 2.0] {
                    for base in [0.0, 3.0, 2.5, source_frames as f64 - 20.0] {
                        for (is_looping, crossfade) in
                            [(false, 0.0), (true, 0.0), (true, 9.0), (true, 400.0)]
                        {
                            for frames in [1_usize, 7, 64, 333] {
                                for edge in [0_u32, 5] {
                                    let mut expected: Vec<f32> =
                                        (0..frames * 2).map(|_| random.next()).collect();
                                    let mut rendered = expected.clone();
                                    let ramp = EdgeRamp {
                                        frames: frames as u32,
                                        edge,
                                    };
                                    let (mut expected_index, mut rendered_index) = (base, base);
                                    reference(
                                        &source,
                                        src_channels,
                                        &mut expected,
                                        &mut expected_index,
                                        step,
                                        is_looping,
                                        source_frames as f64,
                                        crossfade,
                                        0.8,
                                        |frame, _| ramp.value(frame),
                                    );
                                    render_audio_waveform(
                                        &source,
                                        src_channels,
                                        &mut rendered,
                                        2,
                                        &mut rendered_index,
                                        step,
                                        is_looping,
                                        source_frames as f64,
                                        crossfade,
                                        0.8,
                                        EdgeRamp {
                                            frames: frames as u32,
                                            edge,
                                        },
                                    );
                                    assert_eq!(
                                        rendered, expected,
                                        "channels {src_channels}, source {source_frames}, step \
                                         {step}, base {base}, looping {is_looping}, crossfade \
                                         {crossfade}, frames {frames}, edge {edge}"
                                    );
                                    assert_eq!(rendered_index, expected_index);
                                    cases += 1;
                                }
                            }
                        }
                    }
                }
            }
        }
        assert_eq!(cases, 2 * 3 * 5 * 4 * 4 * 4 * 2);
    }

    #[test]
    fn position_dependent_gains_see_the_same_read_positions() {
        let mut random = Lcg(11);
        let source: Vec<f32> = (0..300 * 2).map(|_| random.next()).collect();
        for (step, is_looping, crossfade) in
            [(1.0, true, 30.0), (0.75, true, 0.0), (1.5, false, 0.0)]
        {
            let mut expected = vec![0.0_f32; 500 * 2];
            let mut rendered = expected.clone();
            let (mut expected_index, mut rendered_index) = (4.0, 4.0);
            let gain =
                |frame: u32, read_pos: f64| (read_pos as f32).sin() * 0.5 + frame as f32 * 1e-3;
            reference(
                &source,
                2,
                &mut expected,
                &mut expected_index,
                step,
                is_looping,
                300.0,
                crossfade,
                1.0,
                gain,
            );
            render_audio_waveform(
                &source,
                2,
                &mut rendered,
                2,
                &mut rendered_index,
                step,
                is_looping,
                300.0,
                crossfade,
                1.0,
                gain,
            );
            assert_eq!(rendered, expected, "step {step}, looping {is_looping}");
            assert_eq!(rendered_index, expected_index);
        }
    }
}
