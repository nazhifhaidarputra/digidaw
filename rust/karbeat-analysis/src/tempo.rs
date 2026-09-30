//! Tempo, beat and downbeat detection over long audio, in overlapping segments analyzed in
//! parallel.

use std::{
    path::{Path, PathBuf},
    sync::{
        Arc,
        atomic::{AtomicBool, AtomicUsize, Ordering},
    },
    time::{Duration, Instant},
};

use beat_this::{BeatAnalysis, BeatThis, Tensor};
use karbeat_utils::audio_utils::resample_interleaved_buffer;
use parking_lot::Mutex;
use rayon::ThreadPool;

use crate::{
    AnalysisError,
    budget::{AnalysisPlan, DeviceResources, OVERLAP_SECONDS},
    model::{CANCELLED, RunControl, ThrottledRtenModel},
};

/// Beats closer than this after merging segments are one beat seen by both segments.
const DUPLICATE_BEAT_SECONDS: f32 = 0.07;
/// Sample rate the Beat This! mel front end expects.
const MODEL_SAMPLE_RATE: u32 = 22_050;

/// ONNX files of the Beat This! mel front end and the small beat model.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ModelPaths {
    pub mel: PathBuf,
    pub beat: PathBuf,
}

/// Interleaved audio to analyze.
#[derive(Clone, Copy, Debug)]
pub struct AudioInput<'a> {
    pub samples: &'a [f32],
    pub channels: usize,
    pub sample_rate: u32,
}

impl AudioInput<'_> {
    fn frames(&self) -> usize {
        self.samples.len() / self.channels.max(1)
    }

    fn duration(&self) -> f32 {
        self.frames() as f32 / self.sample_rate.max(1) as f32
    }

    /// Mono mix of the frames between `start` and `end` seconds.
    fn mono(&self, start: f32, end: f32) -> Vec<f32> {
        let channels = self.channels.max(1);
        let rate = self.sample_rate as f32;
        let first = ((start * rate) as usize).min(self.frames());
        let last = ((end * rate) as usize).clamp(first, self.frames());
        let scale = 1.0 / channels as f32;
        self.samples
            .get(first * channels..last * channels)
            .unwrap_or_default()
            .chunks_exact(channels)
            .map(|frame| frame.iter().sum::<f32>() * scale)
            .collect()
    }
}

/// Detected tempo, beats and downbeats, in seconds from the start of the audio.
#[derive(Clone, Debug, PartialEq)]
pub struct TempoAnalysis {
    pub bpm: f32,
    /// Regularity of the beats, from 0.0 (erratic) to 1.0 (steady).
    pub confidence: f32,
    pub beats: Vec<f32>,
    pub downbeats: Vec<f32>,
}

/// A tracker for one worker: its own inference thread and cancellation, sharing the loaded
/// graphs with the other workers.
struct Tracker {
    tracker: BeatThis<ThrottledRtenModel>,
    control: Arc<RunControl>,
}

struct LoadedModels {
    paths: ModelPaths,
    /// The loaded graphs; worker trackers share them.
    mel: ThrottledRtenModel,
    beat: ThrottledRtenModel,
    trackers: Vec<Tracker>,
    last_used: Instant,
}

impl LoadedModels {
    /// Makes sure there are `workers` trackers, all watching `cancel`.
    fn prepare(&mut self, workers: usize, cancel: &Arc<AtomicBool>) {
        while self.trackers.len() < workers {
            let control = Arc::new(RunControl::new(1));
            let tracker = BeatThis::from_models(
                self.mel.share(Arc::clone(&control)),
                self.beat.share(Arc::clone(&control)),
            );
            self.trackers.push(Tracker { tracker, control });
        }
        for tracker in &self.trackers {
            // Models kept from an earlier job still hold that job's cancellation flag.
            tracker.control.begin(Arc::clone(cancel), 1);
        }
    }
}

static PATHS: Mutex<Option<ModelPaths>> = Mutex::new(None);
static MODELS: Mutex<Option<LoadedModels>> = Mutex::new(None);

/// Sets the model files used by [`analyze_tempo`]. Unloads models loaded from other files.
pub fn configure_models(paths: ModelPaths) -> Result<(), AnalysisError> {
    for path in [&paths.mel, &paths.beat] {
        if !path.is_file() {
            return Err(AnalysisError::ModelsUnavailable(format!(
                "model file not found: {}",
                path.display()
            )));
        }
    }
    let mut models = MODELS.lock();
    if models.as_ref().is_some_and(|loaded| loaded.paths != paths) {
        *models = None;
    }
    *PATHS.lock() = Some(paths);
    Ok(())
}

/// Unloads the models if no analysis used them for `idle`. Returns whether they were unloaded.
pub fn release_models_if_idle(idle: Duration) -> bool {
    let Some(mut models) = MODELS.try_lock() else {
        return false;
    };
    if models
        .as_ref()
        .is_some_and(|loaded| loaded.last_used.elapsed() >= idle)
    {
        *models = None;
        log::info!("Unloaded idle tempo analysis models");
        return true;
    }
    false
}

fn load(paths: &ModelPaths) -> Result<LoadedModels, AnalysisError> {
    // The prototypes never run; each worker runs a shared copy under its own control.
    let control = Arc::new(RunControl::new(1));
    let load = |path: &Path| {
        ThrottledRtenModel::load(path, Arc::clone(&control))
            .map_err(|error| AnalysisError::ModelsUnavailable(format!("{error:#}")))
    };
    let models = LoadedModels {
        paths: paths.clone(),
        mel: load(&paths.mel)?,
        beat: load(&paths.beat)?,
        trackers: Vec::new(),
        last_used: Instant::now(),
    };
    log::info!("Loaded tempo analysis models from {}", paths.beat.display());
    Ok(models)
}

/// Stretch of audio analyzed in one model call, with the part whose beats are kept.
#[derive(Clone, Copy, Debug, PartialEq)]
struct Segment {
    /// Audio sent to the model, including overlap.
    start: f32,
    end: f32,
    /// Beats in `[keep_start, keep_end)` are kept.
    keep_start: f32,
    keep_end: f32,
}

impl Segment {
    fn at(keep_start: f32, length: f32, duration: f32) -> Self {
        let keep_end = (keep_start + length).min(duration);
        let last = keep_end >= duration;
        Self {
            start: (keep_start - OVERLAP_SECONDS).max(0.0),
            end: (keep_end + OVERLAP_SECONDS).min(duration),
            keep_start,
            // The last segment keeps everything to the end of the audio.
            keep_end: if last { f32::INFINITY } else { keep_end },
        }
    }

    /// Every segment of `duration` seconds of audio, in order.
    fn all(length: f32, duration: f32) -> Vec<Self> {
        let mut segments = Vec::new();
        let mut position = 0.0_f32;
        while position < duration {
            segments.push(Self::at(position, length, duration));
            position += length;
        }
        segments
    }
}

/// Appends segment-relative `times` that fall in the kept part, skipping repeats of the last
/// merged beat.
fn merge(merged: &mut Vec<f32>, times: &[f32], segment: &Segment) {
    for time in times.iter().map(|time| time + segment.start) {
        if time < segment.keep_start || time >= segment.keep_end {
            continue;
        }
        if merged
            .last()
            .is_some_and(|last| time - last < DUPLICATE_BEAT_SECONDS)
        {
            continue;
        }
        merged.push(time);
    }
}

/// Regularity of the beat intervals: 1.0 for a perfectly steady tempo.
fn confidence(beats: &[f32]) -> f32 {
    let intervals: Vec<f32> = beats.windows(2).map(|pair| pair[1] - pair[0]).collect();
    if intervals.is_empty() {
        return 0.0;
    }
    let count = intervals.len() as f32;
    let mean = intervals.iter().sum::<f32>() / count;
    if mean <= 0.0 {
        return 0.0;
    }
    let variance = intervals.iter().map(|x| (x - mean).powi(2)).sum::<f32>() / count;
    (1.0 - 4.0 * variance.sqrt() / mean).clamp(0.0, 1.0)
}

fn bpm(beats: &[f32]) -> Option<f32> {
    beat_this::calculate_bpm(&BeatAnalysis {
        beats: beats.to_vec(),
        downbeats: Vec::new(),
        mel: Tensor {
            shape: Vec::new(),
            data: Vec::new(),
        },
        beat_logits: Vec::new(),
        downbeat_logits: Vec::new(),
    })
}

fn inference_error(error: &anyhow::Error, control: &RunControl) -> AnalysisError {
    if control.is_cancelled() || error.to_string() == CANCELLED {
        AnalysisError::Cancelled
    } else {
        AnalysisError::Inference(format!("{error:#}"))
    }
}

/// Beats and downbeats of one segment, relative to the segment's start.
type SegmentBeats = (Vec<f32>, Vec<f32>);

/// Analyzes one segment with `tracker`.
fn analyze_segment(
    tracker: &mut Tracker,
    input: AudioInput<'_>,
    segment: &Segment,
) -> Result<SegmentBeats, AnalysisError> {
    if tracker.control.is_cancelled() {
        return Err(AnalysisError::Cancelled);
    }
    // Resample here rather than in `beat-this`: this FFT resampler compensates its filter
    // delay, so beat times line up with the source audio.
    let audio = resample_interleaved_buffer(
        &input.mono(segment.start, segment.end),
        1,
        input.sample_rate,
        MODEL_SAMPLE_RATE,
    )
    .map_err(|error| AnalysisError::Inference(error.err_source))?;
    let analysis = tracker
        .tracker
        .analyze_audio(&audio, MODEL_SAMPLE_RATE)
        .map_err(|error| inference_error(&error, &tracker.control))?;
    Ok((analysis.beats, analysis.downbeats))
}

/// How often progress and cancellation are checked while workers run.
const POLL: Duration = Duration::from_millis(50);

/// Analyzes `segments` with one worker per tracker, on `pool` when there is more than one.
/// Returns each segment's result in segment order.
fn run_segments(
    trackers: &mut [Tracker],
    pool: Option<&ThreadPool>,
    input: AudioInput<'_>,
    segments: &[Segment],
    cancel: &AtomicBool,
    progress: &mut dyn FnMut(f32),
) -> Vec<Result<SegmentBeats, AnalysisError>> {
    let count = segments.len().max(1) as f32;
    let (Some(pool), [_, _, ..]) = (pool, &*trackers) else {
        // One worker: analyze in order on this thread.
        let Some(tracker) = trackers.first_mut() else {
            return vec![Err(AnalysisError::ModelsUnavailable(
                "no model loaded".into(),
            ))];
        };
        return segments
            .iter()
            .enumerate()
            .map(|(index, segment)| {
                let result = analyze_segment(tracker, input, segment);
                progress(index.saturating_add(1) as f32 / count);
                result
            })
            .collect();
    };

    let next = AtomicUsize::new(0);
    let finished = AtomicUsize::new(0);
    let failed = AtomicBool::new(false);
    let results: Vec<Mutex<Option<Result<SegmentBeats, AnalysisError>>>> =
        segments.iter().map(|_| Mutex::new(None)).collect();
    pool.in_place_scope(|scope| {
        for tracker in trackers.iter_mut() {
            let (next, finished, failed, results) = (&next, &finished, &failed, &results);
            scope.spawn(move |_| {
                while !failed.load(Ordering::Acquire) {
                    let index = next.fetch_add(1, Ordering::AcqRel);
                    let (Some(segment), Some(slot)) = (segments.get(index), results.get(index))
                    else {
                        return;
                    };
                    let result = analyze_segment(tracker, input, segment);
                    if result.is_err() {
                        failed.store(true, Ordering::Release);
                    }
                    *slot.lock() = Some(result);
                    finished.fetch_add(1, Ordering::AcqRel);
                }
            });
        }
        // Report progress on this thread while the workers run.
        loop {
            let done = finished.load(Ordering::Acquire);
            progress(done as f32 / count);
            if done >= segments.len()
                || failed.load(Ordering::Acquire)
                || cancel.load(Ordering::Acquire)
            {
                break;
            }
            std::thread::sleep(POLL);
        }
    });
    results
        .into_iter()
        .map(|slot| {
            slot.into_inner()
                .unwrap_or(Err(if cancel.load(Ordering::Acquire) {
                    AnalysisError::Cancelled
                } else {
                    AnalysisError::Inference("a segment was not analyzed".into())
                }))
        })
        .collect()
}

/// Detects the tempo, beats and downbeats of `input` with the small Beat This! model.
///
/// The audio is split into overlapping segments. Audio of
/// [`PARALLEL_MIN_SECONDS`](crate::budget::PARALLEL_MIN_SECONDS) or longer has several
/// segments analyzed at once on `pool`, as many as its threads and the free memory allow;
/// when not even one segment fits in memory, the analysis stops with
/// [`AnalysisError::InsufficientMemory`] instead of exhausting it. The result is the same
/// however many segments run at once. `cancel` is checked before every model call.
pub fn analyze_tempo(
    input: AudioInput<'_>,
    pool: Option<&ThreadPool>,
    cancel: Arc<AtomicBool>,
    progress: &mut dyn FnMut(f32),
) -> Result<TempoAnalysis, AnalysisError> {
    if input.channels == 0 || input.sample_rate == 0 || input.frames() == 0 {
        return Err(AnalysisError::InvalidInput("the audio is empty"));
    }
    let paths = PATHS.lock().clone().ok_or_else(|| {
        AnalysisError::ModelsUnavailable("tempo analysis models are not configured".into())
    })?;

    // Held for the whole analysis: one analysis runs at a time.
    let mut slot = MODELS.lock();
    if slot.as_ref().is_some_and(|loaded| loaded.paths != paths) {
        *slot = None;
    }
    let duration = input.duration();
    let plan = AnalysisPlan::select(
        DeviceResources::probe(),
        slot.is_some(),
        pool.map_or(1, ThreadPool::current_num_threads),
        duration,
    )?;
    let models = match &mut *slot {
        Some(models) => models,
        empty @ None => empty.insert(load(&paths)?),
    };
    models.prepare(plan.workers, &cancel);
    log::info!(
        "Analyzing tempo of {duration:.1} s of audio, {} segment(s) at a time",
        plan.workers
    );

    let segments = Segment::all(plan.segment_seconds, duration);
    let trackers = models.trackers.get_mut(..plan.workers).unwrap_or_default();
    let results = run_segments(trackers, pool, input, &segments, &cancel, progress);
    models.last_used = Instant::now();
    if !plan.keep_models_loaded {
        *slot = None;
    }
    drop(slot);

    let mut beats = Vec::new();
    let mut downbeats = Vec::new();
    for (segment, result) in segments.iter().zip(results) {
        let (segment_beats, segment_downbeats) = result?;
        merge(&mut beats, &segment_beats, segment);
        merge(&mut downbeats, &segment_downbeats, segment);
    }
    progress(1.0);

    let bpm = bpm(&beats).ok_or(AnalysisError::NoBeats)?;
    Ok(TempoAnalysis {
        bpm,
        confidence: confidence(&beats),
        beats,
        downbeats,
    })
}

#[cfg(test)]
#[allow(
    clippy::unwrap_used,
    clippy::indexing_slicing,
    reason = "test fixtures fail immediately on unexpected results"
)]
mod tests {
    use super::{AudioInput, Segment, confidence, merge};

    #[test]
    fn segments_overlap_and_keep_disjoint_ranges() {
        let first = Segment::at(0.0, 26.0, 100.0);
        assert_eq!((first.start, first.end), (0.0, 28.0));
        assert_eq!((first.keep_start, first.keep_end), (0.0, 26.0));

        let middle = Segment::at(26.0, 26.0, 100.0);
        assert_eq!((middle.start, middle.end), (24.0, 54.0));

        let last = Segment::at(78.0, 26.0, 100.0);
        assert_eq!((last.start, last.end), (76.0, 100.0));
        assert!(last.keep_end.is_infinite());
    }

    #[test]
    fn merge_keeps_each_segments_own_range_and_drops_repeats() {
        let mut beats = Vec::new();
        let first = Segment::at(0.0, 10.0, 30.0);
        merge(&mut beats, &[1.0, 5.0, 9.99, 11.0], &first);
        let second = Segment::at(10.0, 10.0, 30.0);
        // Segment starts at 8 s: 2.0 → 10.0 s repeats 9.99, 3.0 → 11.0 s is kept.
        merge(&mut beats, &[1.0, 2.0, 3.0], &second);
        assert_eq!(beats, vec![1.0, 5.0, 9.99, 11.0]);
    }

    #[test]
    fn steady_beats_are_confident_and_erratic_ones_are_not() {
        let steady: Vec<f32> = (0..16).map(|beat| beat as f32 * 0.5).collect();
        assert!(confidence(&steady) > 0.99);
        let erratic = [0.0, 0.3, 1.1, 1.3, 2.4, 2.5];
        assert!(confidence(&erratic) < 0.2);
        assert_eq!(confidence(&[1.0]), 0.0);
    }

    #[test]
    fn mono_mix_averages_channels_within_the_range() {
        let samples = [1.0, 0.0, 0.5, 0.5, 0.0, 1.0, 1.0, 1.0];
        let input = AudioInput {
            samples: &samples,
            channels: 2,
            sample_rate: 2,
        };
        assert_eq!(input.mono(0.5, 1.5), vec![0.5, 0.5]);
        assert!(input.mono(3.0, 4.0).is_empty());
    }
}
