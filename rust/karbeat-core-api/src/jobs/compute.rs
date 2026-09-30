//! Thread pool shared by the CPU-heavy parts of background jobs.
//!
//! Parallel tempo analysis and chunked offline stretching run their pieces here, so the
//! total number of busy compute threads stays capped however many jobs run at once.

use std::sync::OnceLock;

use rayon::ThreadPool;

use super::DeviceBudget;

/// Physical cores left to the audio/DSP threads and the UI.
const RESERVED_CORES: usize = 2;

static POOL: OnceLock<Option<ThreadPool>> = OnceLock::new();

/// Compute threads for a device: every physical core except [`RESERVED_CORES`], at least one.
pub fn compute_threads(budget: &DeviceBudget) -> usize {
    budget.physical_cores.saturating_sub(RESERVED_CORES).max(1)
}

/// The shared compute pool, created on first use, or `None` if the OS refused its threads;
/// callers then do the work on their own thread.
pub fn compute_pool() -> Option<&'static ThreadPool> {
    POOL.get_or_init(|| {
        let threads = compute_threads(&DeviceBudget::detect());
        let pool = rayon::ThreadPoolBuilder::new()
            .num_threads(threads)
            .thread_name(|index| format!("karbeat-compute-{index}"))
            .build();
        match pool {
            Ok(pool) => {
                log::info!("Background compute pool: {threads} thread(s)");
                Some(pool)
            }
            Err(error) => {
                log::error!("Could not create the background compute pool: {error}");
                None
            }
        }
    })
    .as_ref()
}

#[cfg(test)]
mod tests {
    use super::{DeviceBudget, compute_threads};

    fn budget(physical_cores: usize) -> DeviceBudget {
        DeviceBudget {
            physical_cores,
            logical_cpus: physical_cores * 2,
            total_ram_mb: 8_192,
        }
    }

    #[test]
    fn two_cores_stay_free_for_audio_and_ui() {
        assert_eq!(compute_threads(&budget(1)), 1);
        assert_eq!(compute_threads(&budget(2)), 1);
        assert_eq!(compute_threads(&budget(4)), 2);
        assert_eq!(compute_threads(&budget(16)), 14);
    }
}
