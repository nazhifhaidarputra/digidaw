//! Writes recorded takes to WAV files off the audio thread.
//!
//! Starting a take creates its sample ring and WAV file and spawns a writer thread; the engine
//! gets the [`RecordTake`] that feeds the ring. The writer drops the frames the round trip
//! through the output and input devices delayed, so a take lands on the timeline where it was
//! played, and keeps a peak preview the UI draws while the take grows.

use std::{
    path::PathBuf,
    sync::Arc,
    thread::JoinHandle,
    time::{Duration, Instant},
};

use anyhow::Context;
use hashbrown::HashMap;
use karbeat_core::shared::TrackId;
use parking_lot::Mutex;
use rtrb::{Consumer, RingBuffer};

use crate::{
    engine::{InputSource, RecordTake, TakeShared, TakeStart},
    playback_sync::{InputClock, OutputClock},
    writer::{
        AudioWriter, BitDepth, BitPerSample,
        metadata::AudioMetadata,
        wav::{WavAudioWriter, WavAudioWriterConfig},
    },
};

/// Seconds of audio a take's ring holds while its writer catches up.
const RING_SECONDS: usize = 4;
/// How long the writer sleeps between drains of the ring.
const WRITER_INTERVAL: Duration = Duration::from_millis(20);
/// Frames summarized by one preview peak.
pub const PEAK_FRAMES: usize = 256;
/// Longest round-trip latency a take is corrected for.
const MAX_LATENCY: Duration = Duration::from_secs(1);

/// What a new take records and where it goes.
#[derive(Clone, Debug)]
pub struct TakeRequest {
    pub track_id: TrackId,
    pub source: InputSource,
    /// Engine sample rate; the file is written at it.
    pub sample_rate: u32,
    /// File the take is written to.
    pub path: PathBuf,
    /// Name of the clip and source the take becomes.
    pub name: String,
}

/// A finished take written to its file.
#[derive(Clone, Debug, PartialEq)]
pub struct RecordedTake {
    pub track_id: TrackId,
    pub path: PathBuf,
    pub name: String,
    /// Song playhead, in samples, the take starts at.
    pub start_playhead_samples: u64,
    /// Frames in the file.
    pub frames: u64,
    /// Sample rate of the file.
    pub sample_rate: u32,
}

/// The clocks a take is aligned with.
#[derive(Clone)]
pub struct TakeClocks {
    pub input: Arc<InputClock>,
    pub output: Arc<OutputClock>,
}

/// What the UI shows of a take while it records.
#[derive(Clone, Debug, Default, PartialEq)]
pub struct TakePreview {
    /// Song playhead, in samples, the take starts at; `None` while it waits for playback.
    pub start_playhead_samples: Option<u64>,
    /// Frames written so far.
    pub frames: u64,
    pub sample_rate: u32,
    /// Lowest and highest sample of each [`PEAK_FRAMES`] frames, across channels, in pairs.
    pub peaks: Vec<f32>,
}

/// New preview data of one take since the last read.
#[derive(Clone, Debug, PartialEq)]
pub struct TakeProgress {
    pub track_id: TrackId,
    pub start_playhead_samples: Option<u64>,
    pub frames: u64,
    pub sample_rate: u32,
    /// Index of the first peak pair in `peaks` within the take.
    pub peak_offset: usize,
    /// Peak pairs added since the last read.
    pub peaks: Vec<f32>,
    /// Whether the engine stopped recording the take, because the song stopped or was seeked;
    /// the take is waiting to be finished.
    pub ended: bool,
}

struct ActiveTake {
    shared: Arc<TakeShared>,
    preview: Arc<Mutex<TakePreview>>,
    writer: JoinHandle<anyhow::Result<Option<RecordedTake>>>,
}

/// Waits for a take's writer to finish its file.
pub struct TakeFinisher {
    writer: JoinHandle<anyhow::Result<Option<RecordedTake>>>,
}

impl TakeFinisher {
    /// Blocks until the take's file is complete. Returns `None` when the take recorded no
    /// audio; its file is deleted.
    pub fn wait(self) -> anyhow::Result<Option<RecordedTake>> {
        self.writer
            .join()
            .map_err(|_| anyhow::anyhow!("the recording writer panicked"))?
    }
}

/// Takes being recorded, with their writers.
#[derive(Default)]
pub struct RecordingRegistry {
    takes: HashMap<TrackId, ActiveTake>,
    /// Peak pairs of each take already handed out by [`Self::progress`].
    reported_peaks: HashMap<TrackId, usize>,
}

impl RecordingRegistry {
    /// Whether `track_id` has a take waiting for or recording audio.
    pub fn is_recording(&self, track_id: TrackId) -> bool {
        self.takes.contains_key(&track_id)
    }

    /// Tracks with a take.
    pub fn recording_tracks(&self) -> Vec<TrackId> {
        self.takes.keys().copied().collect()
    }

    /// Creates the take's file and writer and returns the take for the engine.
    pub fn begin(
        &mut self,
        request: TakeRequest,
        clocks: TakeClocks,
    ) -> anyhow::Result<Box<RecordTake>> {
        anyhow::ensure!(
            !self.takes.contains_key(&request.track_id),
            "The track is already recording"
        );
        let channels = usize::from(request.source.channels.clamp(1, 2));
        let wav = WavAudioWriter::new(
            &request.path,
            WavAudioWriterConfig {
                sample_rate: request.sample_rate,
                channels: channels as u16,
                bit_depth: BitDepth::BitPerSample(BitPerSample::B32),
            },
            &AudioMetadata::default(),
        )
        .with_context(|| format!("Could not create {}", request.path.display()))?;

        let capacity = request.sample_rate as usize * RING_SECONDS * channels;
        let (producer, consumer) = RingBuffer::<f32>::new(capacity);
        let shared = Arc::new(TakeShared::default());
        let preview = Arc::new(Mutex::new(TakePreview {
            sample_rate: request.sample_rate,
            ..TakePreview::default()
        }));
        let take = Box::new(RecordTake::new(
            request.track_id,
            request.source,
            producer,
            Arc::clone(&shared),
        ));
        let writer = TakeWriter {
            request: request.clone(),
            channels,
            consumer,
            wav,
            shared: Arc::clone(&shared),
            preview: Arc::clone(&preview),
            clocks,
            peak: PeakBucket::default(),
            skip: None,
            frames: 0,
        };
        let writer = std::thread::Builder::new()
            .name("karbeat-take-writer".into())
            .spawn(move || writer.run())
            .context("Could not start the recording writer")?;
        self.takes.insert(
            request.track_id,
            ActiveTake {
                shared,
                preview,
                writer,
            },
        );
        self.reported_peaks.insert(request.track_id, 0);
        Ok(take)
    }

    /// Removes the take of `track_id`. The caller must also end it in the engine; the finisher
    /// returns once the engine stopped recording and the file is complete.
    pub fn finish(&mut self, track_id: TrackId) -> Option<TakeFinisher> {
        self.reported_peaks.remove(&track_id);
        self.takes.remove(&track_id).map(|take| TakeFinisher {
            writer: take.writer,
        })
    }

    /// Preview data added to every take since the last call.
    pub fn progress(&mut self) -> Vec<TakeProgress> {
        self.takes
            .iter()
            .map(|(track_id, take)| {
                let reported = self.reported_peaks.entry(*track_id).or_insert(0);
                let preview = take.preview.lock();
                let pairs = preview.peaks.len() / 2;
                let progress = TakeProgress {
                    track_id: *track_id,
                    start_playhead_samples: preview.start_playhead_samples,
                    frames: preview.frames,
                    sample_rate: preview.sample_rate,
                    peak_offset: *reported,
                    peaks: preview.peaks[(*reported * 2).min(preview.peaks.len())..].to_vec(),
                    ended: take.shared.ended(),
                };
                *reported = pairs;
                progress
            })
            .collect()
    }
}

/// Lowest and highest sample of the frames summarized so far.
#[derive(Clone, Copy)]
struct PeakBucket {
    low: f32,
    high: f32,
    frames: usize,
}

impl Default for PeakBucket {
    fn default() -> Self {
        Self {
            low: 0.0,
            high: 0.0,
            frames: 0,
        }
    }
}

struct TakeWriter {
    request: TakeRequest,
    channels: usize,
    consumer: Consumer<f32>,
    wav: WavAudioWriter,
    shared: Arc<TakeShared>,
    preview: Arc<Mutex<TakePreview>>,
    clocks: TakeClocks,
    peak: PeakBucket,
    /// Frames still to drop for latency, once the take's start is known.
    skip: Option<u64>,
    frames: u64,
}

impl TakeWriter {
    fn run(mut self) -> anyhow::Result<Option<RecordedTake>> {
        let result = self.write_until_ended();
        let finalized = self.wav.finalize().map_err(anyhow::Error::from);
        let start = self.shared.start();
        match (result, finalized, start) {
            (Err(error), _, _) | (Ok(()), Err(error), _) => {
                remove_file(&self.request.path);
                Err(error.context(format!("Could not write {}", self.request.path.display())))
            }
            (Ok(()), Ok(()), Some(start)) if self.frames > 0 => {
                let dropped = self.shared.dropped_frames();
                if dropped > 0 {
                    log::warn!(
                        "Recording {} lost {dropped} frames because the disk fell behind",
                        self.request.name
                    );
                }
                Ok(Some(RecordedTake {
                    track_id: self.request.track_id,
                    path: self.request.path.clone(),
                    name: self.request.name.clone(),
                    start_playhead_samples: start.playhead_samples,
                    frames: self.frames,
                    sample_rate: self.request.sample_rate,
                }))
            }
            (Ok(()), Ok(()), _) => {
                remove_file(&self.request.path);
                Ok(None)
            }
        }
    }

    fn write_until_ended(&mut self) -> anyhow::Result<()> {
        loop {
            // Read before draining: once ended, every frame is already in the ring. A take
            // dropped without ending, because its command never reached the engine, ends too.
            let ended = self.shared.ended() || self.consumer.is_abandoned();
            if let Some(start) = self.shared.start() {
                if self.skip.is_none() {
                    self.skip = Some(latency_frames(
                        &self.clocks,
                        start,
                        self.request.sample_rate,
                    ));
                    self.preview.lock().start_playhead_samples = Some(start.playhead_samples);
                }
                self.drain()?;
            }
            if ended {
                return Ok(());
            }
            std::thread::sleep(WRITER_INTERVAL);
        }
    }

    /// Writes every complete frame waiting on the ring.
    fn drain(&mut self) -> anyhow::Result<()> {
        let available = self.consumer.slots() / self.channels * self.channels;
        if available == 0 {
            return Ok(());
        }
        let chunk = self.consumer.read_chunk(available)?;
        let (first, second) = chunk.as_slices();
        let mut samples = Vec::with_capacity(available);
        samples.extend_from_slice(first);
        samples.extend_from_slice(second);
        chunk.commit_all();

        let mut kept: &[f32] = &samples;
        if let Some(skip) = self.skip.as_mut()
            && *skip > 0
        {
            let frames = (kept.len() / self.channels) as u64;
            let dropped = (*skip).min(frames);
            *skip -= dropped;
            kept = &kept[dropped as usize * self.channels..];
        }
        if kept.is_empty() {
            return Ok(());
        }
        self.wav.write(kept)?;
        self.frames += (kept.len() / self.channels) as u64;

        let mut new_peaks = Vec::new();
        for frame in kept.chunks_exact(self.channels) {
            for &sample in frame {
                self.peak.low = self.peak.low.min(sample);
                self.peak.high = self.peak.high.max(sample);
            }
            self.peak.frames += 1;
            if self.peak.frames == PEAK_FRAMES {
                new_peaks.extend([self.peak.low, self.peak.high]);
                self.peak = PeakBucket::default();
            }
        }
        let mut preview = self.preview.lock();
        preview.frames = self.frames;
        preview.peaks.extend_from_slice(&new_peaks);
        Ok(())
    }
}

/// Engine frames between rendering the take's first block and the input captured with it:
/// the input was played while the listener heard that much earlier.
fn latency_frames(clocks: &TakeClocks, start: TakeStart, sample_rate: u32) -> u64 {
    let maximum = u64::from(sample_rate) * MAX_LATENCY.as_secs();
    let device_rate = clocks.input.device_rate();
    let Some(captured) = clocks.input.captured_at(start.input_frame, device_rate) else {
        return 0;
    };
    let Some(heard) = clocks.output.heard_engine_frame(captured) else {
        return 0;
    };
    let latency = start.render_frame.saturating_sub(heard);
    if latency > maximum {
        log::warn!(
            "Measured recording latency of {latency} frames is implausible; recording uncorrected"
        );
        return 0;
    }
    log::info!(
        "Recording latency is {latency} frames ({:.1} ms)",
        latency as f64 * 1_000.0 / f64::from(sample_rate.max(1))
    );
    latency
}

fn remove_file(path: &std::path::Path) {
    if let Err(error) = std::fs::remove_file(path)
        && error.kind() != std::io::ErrorKind::NotFound
    {
        log::warn!("Could not remove {}: {error}", path.display());
    }
}

#[cfg(test)]
#[allow(
    clippy::unwrap_used,
    reason = "recording tests fail immediately when a fixture cannot be built"
)]
mod tests {
    use super::*;
    use crate::playback_sync::OutputEpoch;

    fn after(origin: Instant, millis: u64) -> Instant {
        origin + Duration::from_millis(millis)
    }

    fn clocks() -> TakeClocks {
        TakeClocks {
            input: Arc::new(InputClock::new()),
            output: Arc::new(OutputClock::new()),
        }
    }

    fn request(dir: &tempfile::TempDir, channels: u16) -> TakeRequest {
        TakeRequest {
            track_id: TrackId::from(3),
            source: InputSource {
                first_channel: 0,
                channels,
            },
            sample_rate: 48_000,
            path: dir.path().join("take.wav"),
            name: "Recording_test".into(),
        }
    }

    /// Feeds `frames` stereo frames of a ramp through the engine side of `take`.
    fn record_frames(take: &mut RecordTake, frames: usize, channels: usize) -> Vec<f32> {
        let device: Vec<f32> = (0..frames * 2)
            .map(|sample| (sample / 2) as f32 / frames as f32)
            .collect();
        take.push_for_test(&device, frames);
        device
            .chunks_exact(2)
            .flat_map(|frame| frame[..channels].to_vec())
            .collect()
    }

    #[test]
    fn a_take_is_written_to_a_wav_file_with_a_peak_preview() {
        let dir = tempfile::tempdir().unwrap();
        let mut registry = RecordingRegistry::default();
        let mut take = registry.begin(request(&dir, 2), clocks()).unwrap();
        assert!(registry.is_recording(TrackId::from(3)));

        let written = record_frames(&mut take, 1_024, 2);
        take.start_for_test(TakeStart {
            playhead_samples: 4_800,
            render_frame: 0,
            input_frame: 0,
        });
        take.end();

        let finisher = registry.finish(TrackId::from(3)).unwrap();
        let recorded = finisher.wait().unwrap().unwrap();
        assert_eq!(recorded.start_playhead_samples, 4_800);
        assert_eq!(recorded.frames, 1_024);

        let mut reader = hound::WavReader::open(&recorded.path).unwrap();
        assert_eq!(reader.spec().channels, 2);
        assert_eq!(reader.spec().sample_rate, 48_000);
        let samples: Vec<f32> = reader.samples::<f32>().map(Result::unwrap).collect();
        assert_eq!(samples, written);
    }

    #[test]
    fn the_preview_reports_new_peaks_once() {
        let dir = tempfile::tempdir().unwrap();
        let mut registry = RecordingRegistry::default();
        let mut take = registry.begin(request(&dir, 1), clocks()).unwrap();
        record_frames(&mut take, PEAK_FRAMES * 4, 1);
        take.start_for_test(TakeStart {
            playhead_samples: 0,
            render_frame: 0,
            input_frame: 0,
        });
        let deadline = Instant::now() + Duration::from_secs(5);
        let mut progress = registry.progress();
        while progress[0].frames < (PEAK_FRAMES * 4) as u64 && Instant::now() < deadline {
            std::thread::sleep(Duration::from_millis(5));
            progress = registry.progress();
        }
        let total: usize = progress.iter().map(|p| p.peaks.len()).sum();
        assert!(total <= 8);
        let again = registry.progress();
        assert!(again[0].peaks.is_empty());
        assert_eq!(again[0].peak_offset, 4);
        take.end();
        registry.finish(TrackId::from(3)).unwrap().wait().unwrap();
    }

    #[test]
    fn an_empty_take_leaves_no_file() {
        let dir = tempfile::tempdir().unwrap();
        let mut registry = RecordingRegistry::default();
        let mut take = registry.begin(request(&dir, 2), clocks()).unwrap();
        take.end();
        let path = dir.path().join("take.wav");
        assert_eq!(
            registry.finish(TrackId::from(3)).unwrap().wait().unwrap(),
            None
        );
        assert!(!path.exists());
    }

    #[test]
    fn latency_is_the_gap_between_rendering_and_hearing_the_captured_moment() {
        let clocks = clocks();
        let origin = Instant::now();
        // Output: engine frame 0 is heard 50 ms after the first callback at `origin`.
        clocks.output.attach(OutputEpoch {
            engine_frame: 0,
            dsp_rate: 48_000,
            device_rate: 48_000,
            bridge_delay_frames: 0,
        });
        clocks
            .output
            .record_callback(origin, 480, Duration::from_millis(50));
        // Input: device frame 0 was captured 10 ms after `origin`.
        clocks.input.reset(48_000);
        clocks
            .input
            .record_callback(after(origin, 20), 480, Duration::from_millis(10));

        // The block holding device frame 0 renders engine frame 9_600, 200 ms of output
        // ahead; at capture time the listener heard nothing yet, frame 0.
        let latency = latency_frames(
            &clocks,
            TakeStart {
                playhead_samples: 0,
                render_frame: 9_600,
                input_frame: 0,
            },
            48_000,
        );
        assert_eq!(latency, 9_600);
    }
}
