//! Lock-free synchronization of the worker pool: the block clock and the level barrier.
//!
//! Both sit on 32-bit atomic words padded to their own cache lines, so a worker spinning on one
//! never invalidates the line another worker writes.

use std::sync::atomic::{AtomicU32, Ordering};

use crossbeam_utils::{Backoff, CachePadded};

/// Epoch value that tells workers to exit; the clock never publishes it as a block.
pub(crate) const SHUTDOWN: u32 = u32::MAX;
/// Yields after the backoff gives up, before a waiter parks: roughly tens of microseconds.
/// A real-time thread that never blocks is killed once it exceeds its `RLIMIT_RTTIME`, so
/// waits always end in a park.
const YIELDS_BEFORE_PARKING: u32 = 64;

/// Waits until `word` no longer holds `seen`: spinning, then yielding, then parked. Returns
/// the new value and whether the thread parked.
fn wait_while<W: SyncWord>(word: &W, seen: u32, sleepers: Option<&W>) -> (u32, bool) {
    let backoff = Backoff::new();
    let mut yields = 0;
    let mut parked = false;
    loop {
        let value = word.load(Ordering::Acquire);
        if value != seen {
            return (value, parked);
        }
        if !backoff.is_completed() {
            W::relax(&backoff);
        } else if yields < YIELDS_BEFORE_PARKING {
            yields += 1;
            W::relax(&backoff);
        } else {
            // Announced before the final check, so a waker that changes the word after it
            // sees the sleeper.
            if let Some(sleepers) = sleepers {
                sleepers.fetch_add(1, Ordering::SeqCst);
            }
            if word.load(Ordering::SeqCst) == seen {
                word.park(seen);
                parked = true;
            }
            if let Some(sleepers) = sleepers {
                sleepers.fetch_sub(1, Ordering::SeqCst);
            }
        }
    }
}

/// Atomic word the pool synchronizes on. Abstracted so the model checker can drive the same
/// clock and barrier code it drives in production.
pub(crate) trait SyncWord: Send + Sync {
    fn new(value: u32) -> Self;
    fn load(&self, order: Ordering) -> u32;
    fn store(&self, value: u32, order: Ordering);
    fn fetch_add(&self, value: u32, order: Ordering) -> u32;
    fn fetch_sub(&self, value: u32, order: Ordering) -> u32;
    /// Sleeps while the word still holds `expected`; may return spuriously.
    fn park(&self, expected: u32);
    /// Wakes every thread parked on the word.
    fn wake_all(&self);
    /// One step of a spin wait.
    fn relax(backoff: &Backoff);
}

impl SyncWord for AtomicU32 {
    fn new(value: u32) -> Self {
        AtomicU32::new(value)
    }

    fn load(&self, order: Ordering) -> u32 {
        AtomicU32::load(self, order)
    }

    fn store(&self, value: u32, order: Ordering) {
        AtomicU32::store(self, value, order);
    }

    fn fetch_add(&self, value: u32, order: Ordering) -> u32 {
        AtomicU32::fetch_add(self, value, order)
    }

    fn fetch_sub(&self, value: u32, order: Ordering) -> u32 {
        AtomicU32::fetch_sub(self, value, order)
    }

    fn park(&self, expected: u32) {
        atomic_wait::wait(self, expected);
    }

    fn wake_all(&self) {
        atomic_wait::wake_all(self);
    }

    fn relax(backoff: &Backoff) {
        backoff.snooze();
    }
}

/// Block epoch published by the coordinator. Workers spin briefly for the next epoch and then
/// park on a futex, so idle workers cost nothing between blocks.
pub(crate) struct BlockClock<W: SyncWord = AtomicU32> {
    epoch: CachePadded<W>,
}

impl<W: SyncWord> BlockClock<W> {
    pub fn new() -> Self {
        Self {
            epoch: CachePadded::new(W::new(0)),
        }
    }

    /// Publishes the next block. Everything the coordinator wrote before is visible to a worker
    /// that observes the new epoch. Only the coordinator ticks.
    pub fn tick(&self) -> u32 {
        let mut next = self.epoch.load(Ordering::Relaxed).wrapping_add(1);
        if next == SHUTDOWN {
            next = 0;
        }
        self.epoch.store(next, Ordering::Release);
        self.epoch.wake_all();
        next
    }

    /// Tells every worker to exit.
    pub fn shut_down(&self) {
        self.epoch.store(SHUTDOWN, Ordering::Release);
        self.epoch.wake_all();
    }

    /// Waits for an epoch other than `seen`. Returns it and whether the thread parked.
    pub fn wait_after(&self, seen: u32) -> (u32, bool) {
        wait_while(&*self.epoch, seen, None)
    }
}

/// Reusable barrier that ends each level of a block. The last thread to arrive resets the
/// count and advances the generation; the others spin on the generation, since a level
/// usually lasts microseconds, and park when one runs long. Every write made before arriving
/// is visible to every thread after leaving.
pub(crate) struct LevelBarrier<W: SyncWord = AtomicU32> {
    arrived: CachePadded<W>,
    generation: CachePadded<W>,
    /// Threads parked on the generation; the last arrival only wakes when there are any.
    sleepers: CachePadded<W>,
    parties: u32,
}

impl<W: SyncWord> LevelBarrier<W> {
    pub fn new(parties: u32) -> Self {
        Self {
            arrived: CachePadded::new(W::new(0)),
            generation: CachePadded::new(W::new(0)),
            sleepers: CachePadded::new(W::new(0)),
            parties: parties.max(1),
        }
    }

    /// Returns whether the thread parked.
    pub fn wait(&self) -> bool {
        // Read before arriving: the generation cannot advance until this thread has arrived.
        let generation = self.generation.load(Ordering::Acquire);
        if self.arrived.fetch_add(1, Ordering::AcqRel).wrapping_add(1) == self.parties {
            self.arrived.store(0, Ordering::Relaxed);
            self.generation
                .store(generation.wrapping_add(1), Ordering::SeqCst);
            if self.sleepers.load(Ordering::SeqCst) > 0 {
                self.generation.wake_all();
            }
            return false;
        }
        wait_while(&*self.generation, generation, Some(&*self.sleepers)).1
    }
}

#[cfg(test)]
#[allow(
    clippy::unwrap_used,
    reason = "model-checked threads fail the run immediately when one panics"
)]
mod model {
    use super::{Backoff, BlockClock, LevelBarrier, SHUTDOWN, SyncWord};
    use shuttle::sync::{Arc, atomic::AtomicU32};
    use std::sync::atomic::Ordering;

    impl SyncWord for AtomicU32 {
        fn new(value: u32) -> Self {
            AtomicU32::new(value)
        }

        fn load(&self, order: Ordering) -> u32 {
            AtomicU32::load(self, order)
        }

        fn store(&self, value: u32, order: Ordering) {
            AtomicU32::store(self, value, order);
        }

        fn fetch_add(&self, value: u32, order: Ordering) -> u32 {
            AtomicU32::fetch_add(self, value, order)
        }

        fn fetch_sub(&self, value: u32, order: Ordering) -> u32 {
            AtomicU32::fetch_sub(self, value, order)
        }

        fn park(&self, _expected: u32) {
            shuttle::thread::yield_now();
        }

        fn wake_all(&self) {}

        fn relax(_backoff: &Backoff) {
            shuttle::thread::yield_now();
        }
    }

    const WORKERS: usize = 3;
    const BLOCKS: u32 = 3;
    const LEVELS: u32 = 3;

    /// Each block, every party writes its slot of every level, then checks after the barrier
    /// that every slot of that level holds this block's value: nobody passed a level early.
    #[test]
    fn no_party_leaves_a_level_before_all_arrive() {
        shuttle::check_random(
            || {
                let clock = Arc::new(BlockClock::<AtomicU32>::new());
                let barrier = Arc::new(LevelBarrier::<AtomicU32>::new(WORKERS as u32 + 1));
                let slots: Arc<Vec<AtomicU32>> =
                    Arc::new((0..=WORKERS).map(|_| AtomicU32::new(0)).collect());

                let run_levels = |party: usize,
                                  block: u32,
                                  barrier: &LevelBarrier<AtomicU32>,
                                  slots: &[AtomicU32]| {
                    for level in 0..LEVELS {
                        let stamp = block * LEVELS + level + 1;
                        slots[party].store(stamp, Ordering::Relaxed);
                        barrier.wait();
                        for slot in slots {
                            assert!(slot.load(Ordering::Relaxed) >= stamp);
                        }
                        barrier.wait();
                    }
                };

                let workers: Vec<_> = (1..=WORKERS)
                    .map(|party| {
                        let (clock, barrier, slots) =
                            (Arc::clone(&clock), Arc::clone(&barrier), Arc::clone(&slots));
                        shuttle::thread::spawn(move || {
                            let mut seen = 0;
                            let mut block = 0;
                            loop {
                                seen = clock.wait_after(seen).0;
                                if seen == SHUTDOWN {
                                    break;
                                }
                                run_levels(party, block, &barrier, &slots);
                                block += 1;
                            }
                            assert_eq!(block, BLOCKS);
                        })
                    })
                    .collect();

                for block in 0..BLOCKS {
                    clock.tick();
                    run_levels(0, block, &barrier, &slots);
                }
                clock.shut_down();
                for worker in workers {
                    worker.join().unwrap();
                }
            },
            200,
        );
    }
}
