//! Returns heap memory freed by large project swaps to the operating system.
//!
//! glibc keeps freed pages in its per-thread arenas instead of unmapping them, so memory
//! released by a project load or a plugin teardown stays resident even though nothing uses it.

use std::sync::atomic::{AtomicBool, Ordering};
use std::time::Duration;

/// Lets asynchronous retirement (engine cleanup queues, native plugin teardown) finish first.
const RELEASE_DELAY: Duration = Duration::from_secs(2);

static RELEASE_PENDING: AtomicBool = AtomicBool::new(false);

/// Schedules one background release of free heap pages after a large deallocation.
///
/// Requests made while a release is pending coalesce into it. Never call from the audio thread.
pub fn schedule_release_to_os() {
    schedule_release_after(RELEASE_DELAY);
}

fn schedule_release_after(delay: Duration) -> bool {
    if !cfg!(all(target_os = "linux", target_env = "gnu")) {
        return false;
    }
    if RELEASE_PENDING.swap(true, Ordering::AcqRel) {
        return false;
    }
    let spawned = std::thread::Builder::new()
        .name("karbeat-heap-release".to_owned())
        .spawn(move || {
            std::thread::sleep(delay);
            // Cleared first so frees that land during the release can schedule another pass.
            RELEASE_PENDING.store(false, Ordering::Release);
            release_to_os();
        });
    if let Err(error) = spawned {
        RELEASE_PENDING.store(false, Ordering::Release);
        log::warn!("Could not schedule heap release: {error}");
        return false;
    }
    true
}

#[cfg(all(target_os = "linux", target_env = "gnu"))]
fn release_to_os() {
    unsafe extern "C" {
        fn malloc_trim(pad: usize) -> std::ffi::c_int;
    }
    // SAFETY: `malloc_trim` only returns unused pages of glibc's own arenas and takes each
    // arena's lock itself, so it is safe to call concurrently with other allocating threads.
    let released = unsafe { malloc_trim(0) };
    log::debug!("Heap release returned memory to the OS: {}", released != 0);
}

#[cfg(not(all(target_os = "linux", target_env = "gnu")))]
fn release_to_os() {}

#[cfg(all(test, target_os = "linux", target_env = "gnu"))]
mod tests {
    use super::*;

    #[test]
    fn pending_release_coalesces_requests_until_it_runs() {
        assert!(schedule_release_after(Duration::from_millis(50)));
        assert!(!schedule_release_after(Duration::from_millis(50)));
        while RELEASE_PENDING.load(Ordering::Acquire) {
            std::thread::yield_now();
        }
        assert!(schedule_release_after(Duration::ZERO));
    }
}
