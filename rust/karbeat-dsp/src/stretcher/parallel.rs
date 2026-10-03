//! Offline stretching of long audio in chunks rendered in parallel.
//!
//! Rubber Band's R3 engine processes one stream on one thread, so long audio is split into
//! chunks, each stretched by its own stretcher on the given thread pool. The time ratio and
//! any warp map are known up front, so an [`OutputMap`] gives every input frame its exact
//! output position: each chunk is pinned to it with key frames, and chunks line up.
//!
//! Chunks render a second of extra audio on each side, keeping Rubber Band's start-up and
//! tail out of the result. At each seam the incoming chunk is shifted by up to a few
//! milliseconds to the lag that best correlates with the outgoing one, so their phases
//! match, and the two are crossfaded. Seams sit just before a beat or in the quietest spot
//! nearby, where a crossfade is least audible.

#![allow(
    clippy::as_conversions,
    clippy::arithmetic_side_effects,
    reason = "frame positions convert between sample counts and f64 time maps; sizes are bounded by the input length"
)]

use std::{
    collections::BTreeMap,
    f64::consts::PI,
    sync::atomic::{AtomicBool, AtomicU64, AtomicUsize, Ordering},
    time::Duration,
};

use crossfire::{RecvTimeoutError, mpsc};
use rayon::ThreadPool;

use super::{OfflineStretch, OfflineTimeStretcher, StretchError, validate};

/// Shortest input, in seconds, that is split into parallel chunks; shorter input renders
/// in one pass.
pub const PARALLEL_MIN_SECONDS: f64 = 60.0;
/// Longest chunk of input, in seconds.
const CHUNK_SECONDS: f64 = 20.0;
/// Shortest chunk of input, in seconds, however many threads there are.
const MIN_CHUNK_SECONDS: f64 = 8.0;
/// Extra input rendered on each side of a chunk and then discarded.
const PAD_SECONDS: f64 = 1.0;
/// Crossfade length at a seam, in output seconds.
const SEAM_SECONDS: f64 = 0.03;
/// Largest shift of an incoming chunk to align its phase with the outgoing one.
const MAX_LAG_SECONDS: f64 = 0.005;
/// A seam moves to a nearby beat within this distance of its even spacing.
const BEAT_SNAP_SECONDS: f64 = 1.0;
/// Without beats, a seam moves to the quietest spot within this distance.
const QUIET_SNAP_SECONDS: f64 = 0.5;
/// Window over which loudness is measured when looking for a quiet spot.
const QUIET_WINDOW_SECONDS: f64 = 0.01;
/// Gap between the end of a crossfade and the beat after it.
const ATTACK_MARGIN_SECONDS: f64 = 0.005;
/// Key frames closer than this to a chunk's anchors are dropped, keeping the map increasing.
const MIN_KEY_GAP_FRAMES: usize = 256;
/// Correlation above which a seam's two sides are treated as coherent.
const COHERENT_CORRELATION: f64 = 0.7;
/// How often progress and cancellation are checked while waiting for chunks.
const POLL: Duration = Duration::from_millis(50);
/// How long a worker waits before checking again for room to render another chunk.
const WINDOW_WAIT: Duration = Duration::from_millis(2);
/// Frames handed to the sink at once.
const EMIT_FRAMES: usize = 4096;

/// Piecewise-linear map from input frames to output frames, through the warp key frames.
#[derive(Clone, Debug, PartialEq)]
pub(crate) struct OutputMap {
    points: Vec<(f64, f64)>,
}

impl OutputMap {
    pub(crate) fn new(input_frames: usize, time_ratio: f64, key_frames: &[(usize, usize)]) -> Self {
        let total_in = input_frames as f64;
        let total_out = (total_in * time_ratio).round();
        let mut points = vec![(0.0, 0.0)];
        for &(input, output) in key_frames {
            let point = (input as f64, output as f64);
            let after_last = points
                .last()
                .is_some_and(|last| point.0 > last.0 && point.1 > last.1);
            if after_last && point.0 < total_in && point.1 < total_out {
                points.push(point);
            }
        }
        points.push((total_in, total_out));
        Self { points }
    }

    /// Output frames in total.
    pub(crate) fn total(&self) -> usize {
        self.points.last().map_or(0, |last| last.1 as usize)
    }

    /// Output position of input frame `input`.
    pub(crate) fn at(&self, input: f64) -> f64 {
        Self::interpolate(&self.points, input, |point| point.0, |point| point.1)
    }

    /// Input position that lands on output frame `output`.
    pub(crate) fn input_at(&self, output: f64) -> f64 {
        Self::interpolate(&self.points, output, |point| point.1, |point| point.0)
    }

    fn interpolate(
        points: &[(f64, f64)],
        value: f64,
        from: impl Fn(&(f64, f64)) -> f64,
        to: impl Fn(&(f64, f64)) -> f64,
    ) -> f64 {
        let upper = points
            .partition_point(|point| from(point) <= value)
            .clamp(1, points.len().saturating_sub(1).max(1));
        let (Some(a), Some(b)) = (points.get(upper - 1), points.get(upper)) else {
            return value;
        };
        let span = from(b) - from(a);
        if span <= 0.0 {
            return to(a);
        }
        to(a) + (value - from(a)) / span * (to(b) - to(a))
    }
}

/// One chunk of input: `keep` lands in the output, `render` adds padding on both sides.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) struct Chunk {
    pub(crate) render_start: usize,
    pub(crate) render_end: usize,
    pub(crate) keep_start: usize,
    pub(crate) keep_end: usize,
}

/// Seconds to frames at `sample_rate`.
fn frames(seconds: f64, sample_rate: u32) -> usize {
    (seconds * f64::from(sample_rate)).round() as usize
}

/// Start of the quietest window within [`QUIET_SNAP_SECONDS`] of `ideal`, plus half a window.
fn quietest_point(request: &OfflineStretch<'_>, ideal: usize, input_frames: usize) -> usize {
    let channels = request.channels;
    let window = frames(QUIET_WINDOW_SECONDS, request.sample_rate).max(1);
    let reach = frames(QUIET_SNAP_SECONDS, request.sample_rate);
    let first = ideal.saturating_sub(reach);
    let last = (ideal + reach).min(input_frames.saturating_sub(window));
    let hop = (window / 2).max(1);
    let mut best = (f32::INFINITY, ideal);
    let mut start = first;
    while start <= last {
        let energy: f32 = request
            .input
            .get(start * channels..(start + window) * channels)
            .unwrap_or_default()
            .iter()
            .map(|sample| sample * sample)
            .sum();
        if energy < best.0 {
            best = (energy, start + window / 2);
        }
        start += hop;
    }
    best.1
}

/// Where a seam near `ideal` goes: just before the nearest beat when one is close enough,
/// so the crossfade ends before its attack, else in the quietest spot nearby.
fn seam_point(
    request: &OfflineStretch<'_>,
    map: &OutputMap,
    ideal: usize,
    input_frames: usize,
) -> usize {
    let reach = frames(BEAT_SNAP_SECONDS, request.sample_rate);
    let beat = request
        .key_frames
        .iter()
        .map(|&(input, _)| input)
        .filter(|input| input.abs_diff(ideal) <= reach)
        .min_by_key(|input| input.abs_diff(ideal));
    match beat {
        Some(beat) => {
            let before = frames(
                SEAM_SECONDS / 2.0 + ATTACK_MARGIN_SECONDS,
                request.sample_rate,
            );
            let output = map.at(beat as f64) - before as f64;
            map.input_at(output.max(0.0)).round() as usize
        }
        None => quietest_point(request, ideal, input_frames),
    }
}

/// Splits the input into chunks for `threads` workers: at least two per worker, each
/// between [`MIN_CHUNK_SECONDS`] and [`CHUNK_SECONDS`] long, with seams placed by
/// [`seam_point`].
pub(crate) fn plan_chunks(
    request: &OfflineStretch<'_>,
    map: &OutputMap,
    input_frames: usize,
    threads: usize,
) -> Vec<Chunk> {
    let rate = request.sample_rate;
    let longest = frames(CHUNK_SECONDS, rate).max(1);
    let shortest = frames(MIN_CHUNK_SECONDS, rate).max(1);
    let target = (input_frames / (2 * threads.max(1))).clamp(shortest.min(longest), longest);
    let count = input_frames.div_ceil(target).max(1);
    let min_gap = shortest / 2;

    let mut bounds = vec![0];
    for index in 1..count {
        let ideal = index * input_frames / count;
        let seam = seam_point(request, map, ideal, input_frames);
        let previous = bounds.last().copied().unwrap_or(0);
        if seam >= previous + min_gap && seam + min_gap <= input_frames {
            bounds.push(seam);
        }
    }
    bounds.push(input_frames);

    let pad = frames(PAD_SECONDS, rate);
    bounds
        .windows(2)
        .filter_map(|pair| match *pair {
            [keep_start, keep_end] => Some(Chunk {
                render_start: keep_start.saturating_sub(pad),
                render_end: (keep_end + pad).min(input_frames),
                keep_start,
                keep_end,
            }),
            _ => None,
        })
        .collect()
}

/// Key frames for rendering `chunk` on its own, relative to its start: the warp key frames
/// inside it, and anchors that pin the kept range to its place in the full output.
pub(crate) fn chunk_key_frames(
    chunk: &Chunk,
    map: &OutputMap,
    key_frames: &[(usize, usize)],
) -> Vec<(usize, usize)> {
    let origin = map.at(chunk.render_start as f64);
    let local = |input: usize| {
        (
            input - chunk.render_start,
            (map.at(input as f64) - origin).round().max(0.0) as usize,
        )
    };
    let inside = |input: usize| input > chunk.render_start && input < chunk.render_end;
    let anchors: Vec<usize> = [chunk.keep_start, chunk.keep_end]
        .into_iter()
        .filter(|input| inside(*input))
        .collect();
    let mut pins: Vec<(usize, usize)> = key_frames
        .iter()
        .map(|&(input, _)| input)
        .filter(|input| inside(*input))
        .filter(|input| {
            anchors
                .iter()
                .all(|anchor| anchor.abs_diff(*input) >= MIN_KEY_GAP_FRAMES)
        })
        .chain(anchors.iter().copied())
        .map(local)
        .collect();
    pins.sort_unstable();
    let mut increasing: Vec<(usize, usize)> = Vec::with_capacity(pins.len());
    for pin in pins {
        if increasing
            .last()
            .is_none_or(|last| pin.0 > last.0 && pin.1 > last.1)
        {
            increasing.push(pin);
        }
    }
    increasing
}

/// Stretches one chunk into interleaved samples, adding rendered input frames to `done`.
fn render_chunk(
    stretcher: &impl OfflineTimeStretcher,
    request: &OfflineStretch<'_>,
    chunk: &Chunk,
    map: &OutputMap,
    stop: &AtomicBool,
    cancelled: &(dyn Fn() -> bool + Sync),
    done: &AtomicU64,
) -> Result<Vec<f32>, StretchError> {
    let channels = request.channels;
    let input = request
        .input
        .get(chunk.render_start * channels..chunk.render_end * channels)
        .ok_or(StretchError::InvalidInput("chunk is outside the input"))?;
    let span = chunk.render_end - chunk.render_start;
    let origin = map.at(chunk.render_start as f64);
    let output_span = map.at(chunk.render_end as f64) - origin;
    let key_frames = chunk_key_frames(chunk, map, request.key_frames);
    let local = OfflineStretch {
        input,
        time_ratio: output_span / span.max(1) as f64,
        key_frames: &key_frames,
        ..*request
    };
    let mut output = Vec::with_capacity((output_span.max(0.0) as usize + 1) * channels);
    let mut reported = 0_u64;
    stretcher.stretch(
        &local,
        &|| stop.load(Ordering::Acquire) || cancelled(),
        &mut |fraction| {
            let frames = (f64::from(fraction) * span as f64) as u64;
            done.fetch_add(frames.saturating_sub(reported), Ordering::Relaxed);
            reported = reported.max(frames);
        },
        &mut |block| output.extend_from_slice(block),
    )?;
    Ok(output)
}

/// A rendered chunk placed on the output timeline.
struct Placed {
    data: Vec<f32>,
    /// Output frame of the chunk's first rendered frame.
    origin: i64,
    /// Frames the content is moved earlier to align its phase with the previous chunk.
    shift: i64,
}

impl Placed {
    /// Frame at output position `position`, or `None` outside what was rendered.
    fn frame(&self, position: i64, channels: usize) -> Option<&[f32]> {
        let local = usize::try_from(position + self.shift - self.origin).ok()?;
        self.data.get(local * channels..(local + 1) * channels)
    }

    fn mono(&self, position: i64, channels: usize) -> f64 {
        self.frame(position, channels).map_or(0.0, |frame| {
            frame.iter().map(|sample| f64::from(*sample)).sum()
        })
    }
}

/// The shift of `incoming`, within `max_lag`, whose content best matches `outgoing` over the
/// crossfade starting at `start`, with that normalized correlation.
fn best_lag(
    outgoing: &Placed,
    incoming: &Placed,
    start: i64,
    length: usize,
    max_lag: i64,
    channels: usize,
) -> (i64, f64) {
    let reference: Vec<f64> = (0..length as i64)
        .map(|offset| outgoing.mono(start + offset, channels))
        .collect();
    let reference_energy: f64 = reference.iter().map(|sample| sample * sample).sum();
    if reference_energy <= f64::EPSILON {
        return (0, 1.0);
    }
    let mut best: (i64, f64) = (0, f64::NEG_INFINITY);
    for lag in -max_lag..=max_lag {
        let mut dot = 0.0;
        let mut energy = 0.0;
        for (offset, reference) in reference.iter().enumerate() {
            let sample = incoming.mono(start + offset as i64 + lag, channels);
            dot += reference * sample;
            energy += sample * sample;
        }
        let correlation = if energy <= f64::EPSILON {
            0.0
        } else {
            dot / (reference_energy * energy).sqrt()
        };
        // Prefer the smallest shift among equally good ones.
        if correlation > best.1 + 1e-9 || (correlation > best.1 - 1e-9 && lag.abs() < best.0.abs())
        {
            best = (lag, correlation);
        }
    }
    best
}

/// Joins placed chunks, in order, into one output stream.
struct Splicer<'a> {
    channels: usize,
    /// Output frame of the seam before each chunk after the first.
    seams: Vec<i64>,
    seam_frames: usize,
    max_lag: i64,
    total: i64,
    /// Next output frame to emit.
    cursor: i64,
    previous: Option<Placed>,
    block: Vec<f32>,
    written: usize,
    sink: &'a mut dyn FnMut(&[f32]),
}

impl Splicer<'_> {
    fn emit(&mut self, frame: Option<&[f32]>) {
        match frame {
            Some(frame) => self.block.extend_from_slice(frame),
            None => self.block.extend(std::iter::repeat_n(0.0, self.channels)),
        }
        self.cursor += 1;
        self.written += 1;
        if self.block.len() >= EMIT_FRAMES * self.channels {
            self.flush();
        }
    }

    fn flush(&mut self) {
        if !self.block.is_empty() {
            (self.sink)(&self.block);
            self.block.clear();
        }
    }

    /// Emits `chunk` from the cursor up to output frame `end`.
    fn emit_until(&mut self, chunk: &Placed, end: i64) {
        let channels = self.channels;
        while self.cursor < end.min(self.total) {
            self.emit(chunk.frame(self.cursor, channels));
        }
    }

    /// Adds chunk `index`, the one after the last added.
    fn push(&mut self, index: usize, mut chunk: Placed) {
        let Some(previous) = self.previous.take() else {
            self.previous = Some(chunk);
            return;
        };
        let channels = self.channels;
        let seam = self
            .seams
            .get(index.wrapping_sub(1))
            .copied()
            .unwrap_or(self.cursor);
        let start = (seam - self.seam_frames as i64 / 2).max(self.cursor);
        self.emit_until(&previous, start);
        let (lag, correlation) = best_lag(
            &previous,
            &chunk,
            start,
            self.seam_frames,
            self.max_lag,
            channels,
        );
        chunk.shift = lag;
        let coherent = correlation >= COHERENT_CORRELATION;
        let mut mixed = vec![0.0_f32; channels];
        for offset in 0..self.seam_frames {
            if self.cursor >= self.total {
                break;
            }
            let t = (offset as f64 + 0.5) / self.seam_frames as f64;
            let (fade_out, fade_in) = if coherent {
                let fade_out = 0.5 * (1.0 + (PI * t).cos());
                (fade_out, 1.0 - fade_out)
            } else {
                ((PI / 2.0 * t).cos(), (PI / 2.0 * t).sin())
            };
            let out = previous.frame(self.cursor, channels);
            let into = chunk.frame(self.cursor, channels);
            for (channel, sample) in mixed.iter_mut().enumerate() {
                let a = out
                    .and_then(|frame| frame.get(channel))
                    .copied()
                    .unwrap_or(0.0);
                let b = into
                    .and_then(|frame| frame.get(channel))
                    .copied()
                    .unwrap_or(0.0);
                *sample = (f64::from(a) * fade_out + f64::from(b) * fade_in) as f32;
            }
            let frame = std::mem::take(&mut mixed);
            self.emit(Some(&frame));
            mixed = frame;
        }
        self.previous = Some(chunk);
    }

    /// Emits the rest of the last chunk, padded or trimmed to the exact output length.
    fn finish(mut self) -> usize {
        if let Some(last) = self.previous.take() {
            self.emit_until(&last, self.total);
        }
        while self.cursor < self.total {
            self.emit(None);
        }
        self.flush();
        self.written
    }
}

/// Stretches `request.input` with `stretcher`, rendering chunks of long input on
/// `pool` in parallel and streaming the joined result to `sink` in order.
///
/// Input shorter than [`PARALLEL_MIN_SECONDS`], or a single-thread pool, renders in one
/// pass. The output length is exactly the input length times the time ratio (or the warp
/// map's end), rounded. At most two chunks per thread are held in memory at once.
///
/// `cancelled` is polled by every worker between blocks. `progress` receives values from
/// `0.0` to `1.0`. Returns the number of output frames written.
pub fn stretch_offline_parallel<S: OfflineTimeStretcher>(
    stretcher: &S,
    request: &OfflineStretch<'_>,
    pool: &ThreadPool,
    cancelled: &(dyn Fn() -> bool + Sync),
    progress: &mut dyn FnMut(f32),
    sink: &mut dyn FnMut(&[f32]),
) -> Result<usize, StretchError> {
    let input_frames = validate(request)? as usize;
    let threads = pool.current_num_threads();
    let long = input_frames as f64 >= PARALLEL_MIN_SECONDS * f64::from(request.sample_rate);
    if !long || threads < 2 {
        return stretcher.stretch(request, &|| cancelled(), progress, sink);
    }
    let map = OutputMap::new(input_frames, request.time_ratio, request.key_frames);
    let chunks = plan_chunks(request, &map, input_frames, threads);
    if chunks.len() < 2 {
        return stretcher.stretch(request, &|| cancelled(), progress, sink);
    }

    let channels = request.channels;
    let rendered_frames: u64 = chunks
        .iter()
        .map(|chunk| (chunk.render_end - chunk.render_start) as u64)
        .sum();
    let window = 2 * threads;
    let stop = AtomicBool::new(false);
    let next = AtomicUsize::new(0);
    let emitted = AtomicUsize::new(0);
    let done = AtomicU64::new(0);
    let (sender, receiver) =
        mpsc::bounded_blocking::<(usize, Result<Vec<f32>, StretchError>)>(window);

    let mut splicer = Splicer {
        channels,
        seams: chunks
            .iter()
            .skip(1)
            .map(|chunk| map.at(chunk.keep_start as f64).round() as i64)
            .collect(),
        seam_frames: frames(SEAM_SECONDS, request.sample_rate).max(1),
        max_lag: frames(MAX_LAG_SECONDS, request.sample_rate) as i64,
        total: map.total() as i64,
        cursor: 0,
        previous: None,
        block: Vec::with_capacity(EMIT_FRAMES * channels),
        written: 0,
        sink,
    };

    let outcome = pool.in_place_scope(|scope| {
        for _ in 0..threads.min(chunks.len()) {
            let sender = sender.clone();
            let (chunks, map, stop, next, emitted, done) =
                (&chunks, &map, &stop, &next, &emitted, &done);
            scope.spawn(move |_| {
                loop {
                    if stop.load(Ordering::Acquire) {
                        return;
                    }
                    let index = next.fetch_add(1, Ordering::AcqRel);
                    let Some(chunk) = chunks.get(index) else {
                        return;
                    };
                    // Keep at most `window` chunks ahead of the one being emitted.
                    while index >= emitted.load(Ordering::Acquire) + window {
                        if stop.load(Ordering::Acquire) {
                            return;
                        }
                        std::thread::sleep(WINDOW_WAIT);
                    }
                    let rendered =
                        render_chunk(stretcher, request, chunk, map, stop, cancelled, done);
                    let failed = rendered.is_err();
                    if sender.send((index, rendered)).is_err() || failed {
                        return;
                    }
                }
            });
        }
        drop(sender);

        let mut ready: BTreeMap<usize, Vec<f32>> = BTreeMap::new();
        let mut outcome = Ok(());
        while emitted.load(Ordering::Acquire) < chunks.len() {
            match receiver.recv_timeout(POLL) {
                Ok((index, Ok(data))) => {
                    ready.insert(index, data);
                    loop {
                        let index = emitted.load(Ordering::Acquire);
                        let Some(data) = ready.remove(&index) else {
                            break;
                        };
                        let origin = chunks
                            .get(index)
                            .map_or(0, |chunk| map.at(chunk.render_start as f64).round() as i64);
                        splicer.push(
                            index,
                            Placed {
                                data,
                                origin,
                                shift: 0,
                            },
                        );
                        emitted.fetch_add(1, Ordering::AcqRel);
                    }
                }
                Ok((_, Err(error))) => {
                    outcome = Err(error);
                    break;
                }
                Err(RecvTimeoutError::Timeout) => {
                    if cancelled() {
                        outcome = Err(StretchError::Cancelled);
                        break;
                    }
                }
                Err(RecvTimeoutError::Disconnected) => {
                    outcome = Err(if cancelled() {
                        StretchError::Cancelled
                    } else {
                        StretchError::InvalidInput("a chunk was not rendered")
                    });
                    break;
                }
            }
            let fraction = done.load(Ordering::Relaxed) as f64 / rendered_frames.max(1) as f64;
            progress((fraction.min(1.0) * 0.99) as f32);
        }
        if outcome.is_err() {
            stop.store(true, Ordering::Release);
        }
        // Workers blocked on a full channel see it close and stop.
        drop(receiver);
        outcome
    });
    outcome?;
    let written = splicer.finish();
    progress(1.0);
    Ok(written)
}

#[cfg(test)]
#[allow(
    clippy::unwrap_used,
    clippy::indexing_slicing,
    reason = "test fixtures fail immediately on unexpected results"
)]
mod tests {
    use super::{
        Chunk, OutputMap, PAD_SECONDS, Placed, best_lag, chunk_key_frames, frames, plan_chunks,
        stretch_offline_parallel,
    };
    use crate::stretcher::{
        DefaultOfflineStretcher, OfflineStretch, StretchError, stretch_offline,
    };

    const RATE: u32 = 48_000;

    fn pool(threads: usize) -> rayon::ThreadPool {
        rayon::ThreadPoolBuilder::new()
            .num_threads(threads)
            .build()
            .unwrap()
    }

    fn sine(seconds: f64, frequency: f32, channels: usize) -> Vec<f32> {
        let frames = frames(seconds, RATE);
        (0..frames)
            .flat_map(|frame| {
                let value =
                    (frame as f32 * frequency * std::f32::consts::TAU / RATE as f32).sin() * 0.5;
                std::iter::repeat_n(value, channels)
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

    fn run(request: &OfflineStretch<'_>, threads: usize) -> Result<Vec<f32>, StretchError> {
        let mut output = Vec::new();
        stretch_offline_parallel(
            &DefaultOfflineStretcher::default(),
            request,
            &pool(threads),
            &|| false,
            &mut |_| {},
            &mut |block| {
                output.extend_from_slice(block);
            },
        )?;
        Ok(output)
    }

    fn rms(samples: &[f32]) -> f64 {
        (samples.iter().map(|s| f64::from(*s).powi(2)).sum::<f64>() / samples.len() as f64).sqrt()
    }

    #[test]
    fn output_map_interpolates_through_key_frames_and_inverts() {
        let map = OutputMap::new(1_000, 2.0, &[(500, 600)]);
        assert_eq!(map.total(), 2_000);
        assert!((map.at(250.0) - 300.0).abs() < 1e-9);
        assert!((map.at(750.0) - 1_300.0).abs() < 1e-9);
        assert!((map.input_at(1_300.0) - 750.0).abs() < 1e-9);
        let plain = OutputMap::new(1_000, 1.5, &[]);
        assert!((plain.at(400.0) - 600.0).abs() < 1e-9);
    }

    #[test]
    fn chunks_cover_the_input_with_padding_and_follow_the_thread_count() {
        let input = sine(90.0, 440.0, 1);
        let request = request(&input, 1, 1.25);
        let frames_in = input.len();
        let map = OutputMap::new(frames_in, 1.25, &[]);
        let chunks = plan_chunks(&request, &map, frames_in, 4);
        assert!(chunks.len() >= 8, "{} chunks", chunks.len());
        assert_eq!(chunks.first().unwrap().keep_start, 0);
        assert_eq!(chunks.last().unwrap().keep_end, frames_in);
        let pad = frames(PAD_SECONDS, RATE);
        for pair in chunks.windows(2) {
            assert_eq!(pair[0].keep_end, pair[1].keep_start);
            assert_eq!(pair[1].render_start, pair[1].keep_start - pad);
            assert_eq!(pair[0].render_end, pair[0].keep_end + pad);
        }
    }

    #[test]
    fn seams_sit_just_before_a_nearby_beat() {
        let input = vec![0.0_f32; frames(90.0, RATE)];
        // A beat every half second.
        let key_frames: Vec<(usize, usize)> = (1..180)
            .map(|beat| (beat * RATE as usize / 2, beat * RATE as usize / 2))
            .collect();
        let request = OfflineStretch {
            key_frames: &key_frames,
            ..request(&input, 1, 1.0)
        };
        let map = OutputMap::new(input.len(), 1.0, &key_frames);
        let chunks = plan_chunks(&request, &map, input.len(), 2);
        let before = frames(0.02, RATE);
        for chunk in chunks.iter().skip(1) {
            let to_next_beat = (RATE as usize / 2) - chunk.keep_start % (RATE as usize / 2);
            assert_eq!(to_next_beat, before, "seam at {}", chunk.keep_start);
        }
    }

    #[test]
    fn chunk_key_frames_pin_the_kept_range_and_stay_increasing() {
        let map = OutputMap::new(100_000, 2.0, &[(50_000, 90_000)]);
        let chunk = Chunk {
            render_start: 40_000,
            render_end: 70_000,
            keep_start: 45_000,
            keep_end: 60_000,
        };
        let pins = chunk_key_frames(&chunk, &map, &[(50_000, 90_000), (60_100, 0)]);
        let origin = map.at(40_000.0);
        assert_eq!(
            pins,
            vec![
                (5_000, (map.at(45_000.0) - origin).round() as usize),
                (10_000, (90_000.0 - origin).round() as usize),
                (20_000, (map.at(60_000.0) - origin).round() as usize),
            ]
        );
    }

    #[test]
    fn best_lag_finds_a_known_shift() {
        let channels = 1;
        let wave: Vec<f32> = (0..4_000)
            .map(|frame| (frame as f32 * 0.05).sin() + (frame as f32 * 0.013).sin())
            .collect();
        let outgoing = Placed {
            data: wave.clone(),
            origin: 0,
            shift: 0,
        };
        // The incoming content lags by 37 frames.
        let incoming = Placed {
            data: wave,
            origin: 37,
            shift: 0,
        };
        let (lag, correlation) = best_lag(&outgoing, &incoming, 1_000, 1_440, 240, channels);
        assert_eq!(lag, 37);
        assert!(correlation > 0.999);
    }

    #[test]
    fn long_input_keeps_length_pitch_and_level_across_seams() {
        let input = sine(90.0, 440.0, 2);
        let ratio = 1.3;
        let output = run(&request(&input, 2, ratio), 4).unwrap();
        let frames_in = input.len() / 2;
        assert_eq!(
            output.len() / 2,
            (frames_in as f64 * ratio).round() as usize
        );

        let left: Vec<f32> = output.iter().step_by(2).copied().collect();
        // Pitch: zero crossings over the middle 60 s.
        let middle = &left[frames(10.0, RATE)..frames(70.0, RATE)];
        let crossings = middle
            .windows(2)
            .filter(|pair| (pair[0] < 0.0) != (pair[1] < 0.0))
            .count() as f64;
        let frequency = crossings / 2.0 / 60.0;
        assert!((frequency - 440.0).abs() < 440.0 * 0.01, "{frequency} Hz");

        // Level: no dips or bumps at seams. 20 ms windows stay within 1 dB of the mean.
        let steady = &left[frames(1.0, RATE)..left.len() - frames(1.0, RATE)];
        let overall = rms(steady);
        for window in steady.chunks(frames(0.02, RATE)) {
            let level = 20.0 * (rms(window) / overall).log10();
            assert!(level.abs() < 1.0, "level {level:.2} dB");
        }

        // Continuity: steps across each seam are no larger than the worst step of a single
        // pass, which Rubber Band's own processing sets.
        let mut serial = Vec::new();
        stretch_offline(
            &request(&input, 2, ratio),
            &|| false,
            &mut |_| {},
            &mut |block| {
                serial.extend_from_slice(block);
            },
        )
        .unwrap();
        let worst_step = |samples: &[f32]| {
            samples
                .windows(2)
                .map(|pair| (pair[1] - pair[0]).abs())
                .fold(0.0_f32, f32::max)
        };
        let serial_left: Vec<f32> = serial.iter().step_by(2).copied().collect();
        let serial_worst = worst_step(&serial_left[frames(1.0, RATE)..]);
        let map = OutputMap::new(frames_in, ratio, &[]);
        let chunks = plan_chunks(&request(&input, 2, ratio), &map, frames_in, 4);
        let reach = frames(0.05, RATE);
        for chunk in chunks.iter().skip(1) {
            let seam = map.at(chunk.keep_start as f64) as usize;
            let around = worst_step(&left[seam - reach..seam + reach]);
            assert!(
                around <= serial_worst * 1.1,
                "step {around} at the seam near {seam}, single pass at most {serial_worst}"
            );
        }
    }

    #[test]
    fn parallel_level_matches_a_single_pass() {
        let input = sine(64.0, 220.0, 1);
        let request = request(&input, 1, 0.8);
        let parallel = run(&request, 3).unwrap();
        let mut serial = Vec::new();
        stretch_offline(&request, &|| false, &mut |_| {}, &mut |block| {
            serial.extend_from_slice(block);
        })
        .unwrap();
        let skip = frames(1.0, RATE);
        let difference = 20.0
            * (rms(&parallel[skip..parallel.len() - skip])
                / rms(&serial[skip..serial.len() - skip]))
            .log10();
        assert!(difference.abs() < 0.5, "{difference:.2} dB");
    }

    #[test]
    fn a_pinned_click_lands_on_its_output_frame() {
        let frames_in = frames(80.0, RATE);
        let mut input = vec![0.0_f32; frames_in];
        let click = frames(47.3, RATE);
        for sample in &mut input[click..click + 32] {
            *sample = 0.9;
        }
        let target = (click as f64 * 1.5) as usize + frames(0.1, RATE);
        let key_frames = [(click, target)];
        let output = run(
            &OfflineStretch {
                key_frames: &key_frames,
                ..request(&input, 1, 1.5)
            },
            4,
        )
        .unwrap();
        let peak = output
            .iter()
            .enumerate()
            .max_by(|a, b| a.1.abs().total_cmp(&b.1.abs()))
            .map(|(index, _)| index)
            .unwrap();
        assert!(
            peak.abs_diff(target) < 2_048,
            "click at {peak}, expected near {target}"
        );
    }

    #[test]
    fn cancellation_stops_every_chunk() {
        let input = sine(70.0, 440.0, 2);
        let result = stretch_offline_parallel(
            &DefaultOfflineStretcher::default(),
            &request(&input, 2, 1.1),
            &pool(4),
            &|| true,
            &mut |_| {},
            &mut |_| {},
        );
        assert_eq!(result, Err(StretchError::Cancelled));
    }

    #[test]
    fn short_input_renders_in_one_pass() {
        let input = sine(5.0, 440.0, 1);
        let output = run(&request(&input, 1, 2.0), 4).unwrap();
        let expected = input.len() * 2;
        assert!(output.len().abs_diff(expected) <= expected / 100 + 1);
    }

    #[test]
    #[ignore = "benchmark: compare serial and parallel render times"]
    fn bench_three_minutes() {
        let input = sine(180.0, 440.0, 2);
        let request = request(&input, 2, 1.2);
        let started = std::time::Instant::now();
        stretch_offline(&request, &|| false, &mut |_| {}, &mut |_| {}).unwrap();
        let serial = started.elapsed();
        eprintln!("3 min stereo: single pass {:.1} s", serial.as_secs_f32());
        for threads in [2, 3, 4] {
            let started = std::time::Instant::now();
            run(&request, threads).unwrap();
            eprintln!(
                "3 min stereo: {threads} threads {:.1} s",
                started.elapsed().as_secs_f32()
            );
        }
    }
}
