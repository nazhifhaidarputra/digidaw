//! Fixed pool of DSP worker threads running a static bulk-synchronous schedule.
//!
//! The DSP thread is worker 0 and coordinates: it publishes a block on the [`BlockClock`],
//! runs its own share of every level, and meets the other workers at a [`LevelBarrier`] after
//! each one. Which node a worker runs is fixed by the schedule rather than claimed at runtime,
//! so a plugin keeps being processed by the same thread from block to block, and no message
//! crosses between threads during a block.

use std::{
    cell::UnsafeCell,
    panic::{AssertUnwindSafe, catch_unwind},
    sync::Arc,
    thread::JoinHandle,
    time::{Duration, Instant},
};

use super::sync::{BlockClock, LevelBarrier, SHUTDOWN};

/// Most threads, the DSP thread included, a pool is built with.
pub const MAX_DSP_WORKERS: usize = 8;

/// Threads, the DSP thread included, that render when the user has not chosen a count: every
/// core but one, which is left to the UI.
pub fn auto_worker_count() -> usize {
    std::thread::available_parallelism()
        .map_or(1, std::num::NonZeroUsize::get)
        .saturating_sub(1)
        .clamp(1, MAX_DSP_WORKERS)
}

/// Longest a real-time thread runs before [`RealtimeSlice`] makes it block.
pub const REALTIME_SLICE: Duration = Duration::from_millis(10);

/// Promotes the calling thread to real-time scheduling for audio work. Best effort: the
/// failure is logged, since it only costs headroom. Not real-time safe; call at thread start.
///
/// On Linux the buffer length becomes the process's `RLIMIT_RTTIME`: how long a real-time
/// thread may run without blocking before the kernel kills the process with `SIGXCPU`. The
/// DSP thread renders several blocks back to back to fill the output ring, so a second of
/// frames is requested, which RtKit caps at its own maximum, and every real-time thread blocks
/// at least once per [`REALTIME_SLICE`] through [`RealtimeSlice`].
pub fn promote_current_thread(
    block_frames: usize,
    sample_rate: u32,
) -> Option<audio_thread_priority::RtPriorityHandle> {
    let frames = if cfg!(target_os = "linux") {
        sample_rate
    } else {
        u32::try_from(block_frames).unwrap_or(u32::MAX)
    };
    match audio_thread_priority::promote_current_thread_to_real_time(frames, sample_rate) {
        Ok(handle) => Some(handle),
        Err(error) => {
            log::warn!("DSP thread runs without real-time priority: {error}");
            None
        }
    }
}

/// Keeps a real-time thread from running a whole [`REALTIME_SLICE`] without blocking, which
/// the kernel punishes once it exceeds `RLIMIT_RTTIME`. Spinning and yielding do not count;
/// parking or sleeping does.
pub struct RealtimeSlice {
    slice: Duration,
    since: Instant,
}

impl RealtimeSlice {
    pub fn new(slice: Duration) -> Self {
        Self {
            slice,
            since: Instant::now(),
        }
    }

    /// Records that the thread just blocked.
    pub fn blocked(&mut self) {
        self.since = Instant::now();
    }

    /// Sleeps for a moment once the thread has run a whole slice without blocking. Returns
    /// whether it slept.
    pub fn yield_if_due(&mut self) -> bool {
        if self.since.elapsed() < self.slice {
            return false;
        }
        std::thread::sleep(Duration::from_micros(20));
        self.blocked();
        true
    }
}

/// Work split into levels: every node of a level may run once all earlier levels finished.
pub trait LevelJob: Sync {
    /// Levels in this block.
    fn levels(&self) -> usize;
    /// Runs `worker`'s share of `level`. Must not panic; node work catches its own panics.
    fn run(&self, worker: usize, level: usize);
}

/// Type-erased job published for one block.
#[derive(Clone, Copy)]
struct Dispatch {
    job: *const (),
    run: unsafe fn(*const (), usize, usize),
    levels: usize,
}

/// # Safety
///
/// `job` must point to a live `J` for the whole call.
unsafe fn run_erased<J: LevelJob>(job: *const (), worker: usize, level: usize) {
    // SAFETY: The caller guarantees `job` points to a live `J`.
    let job = unsafe { &*job.cast::<J>() };
    job.run(worker, level);
}

struct Shared {
    clock: BlockClock,
    barrier: LevelBarrier,
    /// Written by the coordinator only before it ticks the clock, read by workers only after
    /// they observe the tick and before they arrive at the block's last barrier.
    dispatch: UnsafeCell<Dispatch>,
}

// SAFETY: `dispatch` is only written while no worker reads it (see the field), and the clock's
// release/acquire orders the write before every read. `Dispatch::job` points to a `LevelJob`,
// which is `Sync`.
unsafe impl Sync for Shared {}
// SAFETY: See `Sync`; the pointer in `dispatch` is only dereferenced under that protocol.
unsafe impl Send for Shared {}

/// Worker threads that run [`LevelJob`]s with the calling thread as worker 0.
pub struct AudioWorkerPool {
    shared: Arc<Shared>,
    threads: Vec<JoinHandle<()>>,
}

impl AudioWorkerPool {
    /// Spawns `workers - 1` threads, promoted to real-time priority for blocks of
    /// `block_frames` at `sample_rate`. Returns `None` when `workers` is 1 or a thread cannot
    /// be spawned. Not real-time safe.
    pub fn new(workers: usize, block_frames: usize, sample_rate: u32) -> Option<Self> {
        let workers = workers.clamp(1, MAX_DSP_WORKERS);
        if workers == 1 {
            return None;
        }
        fn idle(_: *const (), _: usize, _: usize) {}
        let shared = Arc::new(Shared {
            clock: BlockClock::new(),
            barrier: LevelBarrier::new(u32::try_from(workers).unwrap_or(1)),
            dispatch: UnsafeCell::new(Dispatch {
                job: std::ptr::null(),
                run: idle,
                levels: 0,
            }),
        });
        let mut pool = Self {
            shared,
            threads: Vec::with_capacity(workers - 1),
        };
        for index in 1..workers {
            let shared = Arc::clone(&pool.shared);
            let spawned = std::thread::Builder::new()
                .name(format!("karbeat-dsp-{index}"))
                .spawn(move || worker_loop(&shared, index, block_frames, sample_rate));
            match spawned {
                Ok(thread) => pool.threads.push(thread),
                Err(error) => {
                    log::warn!("DSP worker {index} could not start, rendering serially: {error}");
                    // Dropping the pool stops and joins the threads already started.
                    return None;
                }
            }
        }
        Some(pool)
    }

    /// Threads that render, the calling thread included.
    pub fn workers(&self) -> usize {
        self.threads.len() + 1
    }

    /// Runs every level of `job` across the pool and returns when all of them finished.
    /// Real-time safe.
    pub fn run<J: LevelJob>(&mut self, job: &J) {
        let levels = job.levels();
        if levels == 0 {
            return;
        }
        // SAFETY: Every worker finished reading the previous dispatch before arriving at that
        // block's last barrier, which this thread has passed; none reads again until the tick.
        unsafe {
            *self.shared.dispatch.get() = Dispatch {
                job: std::ptr::from_ref(job).cast(),
                run: run_erased::<J>,
                levels,
            };
        }
        self.shared.clock.tick();
        for level in 0..levels {
            job.run(0, level);
            self.shared.barrier.wait();
        }
    }
}

impl Drop for AudioWorkerPool {
    fn drop(&mut self) {
        self.shared.clock.shut_down();
        for thread in self.threads.drain(..) {
            let _ = thread.join();
        }
    }
}

fn worker_loop(shared: &Shared, index: usize, block_frames: usize, sample_rate: u32) {
    let _priority = promote_current_thread(block_frames, sample_rate);
    let mut slice = RealtimeSlice::new(REALTIME_SLICE);
    let mut seen = 0;
    loop {
        let (epoch, parked) = shared.clock.wait_after(seen);
        seen = epoch;
        if seen == SHUTDOWN {
            return;
        }
        if parked {
            slice.blocked();
        } else {
            slice.yield_if_due();
        }
        // SAFETY: The tick published this dispatch; it is not rewritten before this worker
        // arrives at the block's last barrier below.
        let dispatch = unsafe { *shared.dispatch.get() };
        for level in 0..dispatch.levels {
            // A panic here would leave the others waiting at the barrier forever.
            let _ = catch_unwind(AssertUnwindSafe(|| {
                // SAFETY: The coordinator keeps the job alive until every worker has arrived
                // at the block's last barrier.
                unsafe { (dispatch.run)(dispatch.job, index, level) }
            }));
            if shared.barrier.wait() {
                slice.blocked();
            }
        }
    }
}

#[cfg(test)]
#[allow(
    clippy::expect_used,
    reason = "pool tests fail immediately when the pool cannot start"
)]
mod tests {
    use super::{AudioWorkerPool, LevelJob};
    use std::sync::atomic::{AtomicU32, Ordering};

    /// Records, per level, which workers ran and what every earlier level had finished.
    struct Probe {
        workers: usize,
        levels: usize,
        done: Vec<AtomicU32>,
        violations: AtomicU32,
    }

    impl LevelJob for Probe {
        fn levels(&self) -> usize {
            self.levels
        }

        fn run(&self, worker: usize, level: usize) {
            // Every worker of every earlier level must have finished.
            for earlier in 0..level {
                if self.done[earlier].load(Ordering::Relaxed) != self.workers as u32 {
                    self.violations.fetch_add(1, Ordering::Relaxed);
                }
            }
            assert!(worker < self.workers);
            self.done[level].fetch_add(1, Ordering::Relaxed);
        }
    }

    #[test]
    fn every_worker_runs_every_level_in_order_across_blocks() {
        let mut pool = AudioWorkerPool::new(4, 64, 48_000).expect("the pool should start");
        assert_eq!(pool.workers(), 4);
        for _ in 0..200 {
            let probe = Probe {
                workers: 4,
                levels: 5,
                done: (0..5).map(|_| AtomicU32::new(0)).collect(),
                violations: AtomicU32::new(0),
            };
            pool.run(&probe);
            assert_eq!(probe.violations.load(Ordering::Relaxed), 0);
            assert!(
                probe
                    .done
                    .iter()
                    .all(|count| count.load(Ordering::Relaxed) == 4)
            );
        }
    }

    #[test]
    fn a_thread_running_a_whole_slice_sleeps_once() {
        let mut slice = super::RealtimeSlice::new(std::time::Duration::from_millis(2));
        assert!(!slice.yield_if_due());
        std::thread::sleep(std::time::Duration::from_millis(3));
        assert!(slice.yield_if_due());
        assert!(!slice.yield_if_due());
    }

    #[test]
    fn a_single_worker_needs_no_pool() {
        assert!(AudioWorkerPool::new(1, 64, 48_000).is_none());
    }
}
