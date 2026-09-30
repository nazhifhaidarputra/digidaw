//! Sizes tempo analysis to the device: how many segments run at once, from the free memory
//! and the compute threads available.

use sysinfo::{MemoryRefreshKind, RefreshKind, System};

use crate::AnalysisError;

/// Seconds of audio shared with each neighboring segment, so beats near a segment edge are
/// taken from where the model saw context on both sides.
pub const OVERLAP_SECONDS: f32 = 2.0;
/// Audio analyzed per segment, excluding the overlap on each side. With the overlap it is
/// one chunk of just under 30 s (1500 frames), the length the model was trained on:
/// `beat-this` trims 6 border frames per side, so a full 1500 frames would need a second
/// chunk.
pub const SEGMENT_SECONDS: f32 = 25.5;
/// Segment length when memory is short: with the overlap, one 15 s (750-frame) chunk. It
/// needs well under half the memory and runs faster, with a little less context per beat.
pub const SHORT_SEGMENT_SECONDS: f32 = 11.0;
/// Shortest audio, in seconds, whose segments are analyzed in parallel.
pub const PARALLEL_MIN_SECONDS: f32 = 60.0;
/// Peak memory of loading the small beat model with the mel front end (measured: 49 MiB).
pub const MODEL_MB: u64 = 60;
/// Working memory of one [`SEGMENT_SECONDS`] segment in flight (measured: about 390 MiB
/// per worker), with a margin.
pub const WORKER_MB: u64 = 420;
/// Working memory of one [`SHORT_SEGMENT_SECONDS`] segment in flight (measured: about
/// 145 MiB per worker), with a margin.
pub const SHORT_WORKER_MB: u64 = 170;
/// Memory kept free for the rest of the app and the OS. "Available" memory already counts
/// reclaimable cache.
pub const HEADROOM_MB: u64 = 128;
/// Free memory above which the models stay loaded between analyses.
const KEEP_LOADED_MB: u64 = 1024;

/// Free memory and CPU the analysis may use.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct DeviceResources {
    pub physical_cores: usize,
    pub available_mb: u64,
}

impl DeviceResources {
    /// Reads the current free memory and core count.
    pub fn probe() -> Self {
        let system = System::new_with_specifics(
            RefreshKind::nothing().with_memory(MemoryRefreshKind::nothing().with_ram()),
        );
        let logical = std::thread::available_parallelism().map_or(1, std::num::NonZeroUsize::get);
        Self {
            physical_cores: System::physical_core_count().unwrap_or(logical).max(1),
            available_mb: system.available_memory() / 1_048_576,
        }
    }
}

/// Segments in flight and model lifetime for one analysis.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct AnalysisPlan {
    /// Segments analyzed at once, each on its own thread.
    pub workers: usize,
    pub segment_seconds: f32,
    /// Whether the models stay in memory after the job for the next one.
    pub keep_models_loaded: bool,
}

impl AnalysisPlan {
    /// Segments needed for `duration` seconds of audio in `segment_seconds` segments.
    pub fn segment_count(duration: f32, segment_seconds: f32) -> usize {
        (duration / segment_seconds).ceil().max(1.0) as usize
    }

    /// Plans an analysis of `duration` seconds of audio with up to `max_workers` threads.
    ///
    /// Audio shorter than [`PARALLEL_MIN_SECONDS`] runs one segment at a time. Longer audio
    /// runs as many segments at once as threads and segments allow. Segments are
    /// [`SEGMENT_SECONDS`] long when free memory fits that many; otherwise they shrink to
    /// [`SHORT_SEGMENT_SECONDS`], with as many at once as fit. `loaded` says whether the
    /// models are already in memory. Refuses with [`AnalysisError::InsufficientMemory`]
    /// when not even one short segment fits.
    pub fn select(
        resources: DeviceResources,
        loaded: bool,
        max_workers: usize,
        duration: f32,
    ) -> Result<Self, AnalysisError> {
        let model_mb = if loaded { 0 } else { MODEL_MB };
        let free = resources
            .available_mb
            .saturating_sub(model_mb.saturating_add(HEADROOM_MB));
        let wanted = |segment_seconds: f32| {
            if duration < PARALLEL_MIN_SECONDS {
                1
            } else {
                max_workers
                    .min(Self::segment_count(duration, segment_seconds))
                    .max(1)
            }
        };
        let fitting = |worker_mb: u64| usize::try_from(free / worker_mb).unwrap_or(usize::MAX);
        let keep_models_loaded = resources.available_mb >= KEEP_LOADED_MB;

        let long = wanted(SEGMENT_SECONDS);
        let (workers, segment_seconds) = if fitting(WORKER_MB) >= long {
            (long, SEGMENT_SECONDS)
        } else {
            let short = wanted(SHORT_SEGMENT_SECONDS).min(fitting(SHORT_WORKER_MB));
            if short == 0 {
                return Err(AnalysisError::InsufficientMemory {
                    required_mb: model_mb.saturating_add(SHORT_WORKER_MB + HEADROOM_MB),
                    available_mb: resources.available_mb,
                });
            }
            (short, SHORT_SEGMENT_SECONDS)
        };
        Ok(Self {
            workers,
            segment_seconds,
            keep_models_loaded,
        })
    }
}

#[cfg(test)]
#[allow(clippy::unwrap_used, reason = "test fixtures fail immediately")]
mod tests {
    use super::{
        AnalysisError, AnalysisPlan, DeviceResources, SEGMENT_SECONDS, SHORT_SEGMENT_SECONDS,
    };

    fn resources(available_mb: u64) -> DeviceResources {
        DeviceResources {
            physical_cores: 8,
            available_mb,
        }
    }

    fn plan(available_mb: u64, max_workers: usize, duration: f32) -> AnalysisPlan {
        AnalysisPlan::select(resources(available_mb), false, max_workers, duration).unwrap()
    }

    #[test]
    fn long_audio_uses_every_thread_that_has_a_segment() {
        let plan_300 = plan(16_000, 6, 300.0);
        assert_eq!(plan_300.workers, 6);
        assert_eq!(plan_300.segment_seconds, SEGMENT_SECONDS);
        assert!(plan_300.keep_models_loaded);
        // 90 s is four segments.
        assert_eq!(plan(16_000, 6, 90.0).workers, 4);
    }

    #[test]
    fn short_audio_runs_one_segment_at_a_time() {
        assert_eq!(plan(16_000, 6, 59.0).workers, 1);
    }

    #[test]
    fn tight_memory_shrinks_segments_before_giving_up_parallelism() {
        // 60 MB model + 128 MB headroom leave 700 MB: one long segment, or four short ones.
        let tight = plan(888, 4, 600.0);
        assert_eq!(tight.segment_seconds, SHORT_SEGMENT_SECONDS);
        assert_eq!(tight.workers, 4);
        assert!(!tight.keep_models_loaded);
        // Short audio analyzed one segment at a time keeps long segments when one fits.
        assert_eq!(plan(888, 4, 30.0).segment_seconds, SEGMENT_SECONDS);
        // Only one short segment fits.
        let scarce = plan(400, 4, 600.0);
        assert_eq!(
            (scarce.workers, scarce.segment_seconds),
            (1, SHORT_SEGMENT_SECONDS)
        );
    }

    #[test]
    fn too_little_memory_is_refused() {
        let error = AnalysisPlan::select(resources(300), false, 8, 600.0).unwrap_err();
        assert!(matches!(
            error,
            AnalysisError::InsufficientMemory {
                required_mb: 358,
                available_mb: 300,
            }
        ));
        // Loaded models free their share.
        assert!(AnalysisPlan::select(resources(300), true, 8, 600.0).is_ok());
    }
}
