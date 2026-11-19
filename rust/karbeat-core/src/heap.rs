//! Returns heap memory freed by large project swaps to the operating system.
//!
//! glibc keeps freed pages in its per-thread arenas instead of unmapping them, so memory
//! released by a project load or a plugin teardown stays resident even though nothing uses it.

use karbeat_host::retire::RetirementService;
#[cfg(all(target_os = "linux", target_env = "gnu"))]
use std::ffi::c_int;
use std::time::Duration;
use std::{
    sync::atomic::{AtomicBool, Ordering},
    thread::Builder,
};

/// Longest wait for retired engine values to be destroyed before releasing anyway.
const RETIREMENT_TIMEOUT: Duration = Duration::from_secs(5);

static RELEASE_PENDING: AtomicBool = AtomicBool::new(false);

/// Schedules one background release of free heap pages after a large deallocation.
///
/// The release first waits on the retirement barrier, so everything the audio thread let go of
/// before the call has been destroyed. Hosted endpoints count once handed back to their native
/// owner, which tears the instance down on its next pump; that memory is released by the next
/// request. Requests made while a release is pending coalesce into it. Never call from the audio
/// thread.
pub fn schedule_release_to_os() {
    schedule_release_after(|| {
        if !RetirementService::global().drain_all(RETIREMENT_TIMEOUT) {
            tracing::warn!("Releasing heap pages before every retired value was destroyed");
        }
    });
}

fn schedule_release_after(wait: impl FnOnce() + Send + 'static) -> bool {
    if !cfg!(all(target_os = "linux", target_env = "gnu")) {
        return false;
    }
    if RELEASE_PENDING.swap(true, Ordering::AcqRel) {
        return false;
    }
    let spawned = Builder::new()
        .name("karbeat-heap-release".to_owned())
        .spawn(move || {
            wait();
            // Cleared first so frees that land during the release can schedule another pass.
            RELEASE_PENDING.store(false, Ordering::Release);
            release_to_os();
        });
    if let Err(error) = spawned {
        RELEASE_PENDING.store(false, Ordering::Release);
        tracing::warn!("Could not schedule heap release: {error}");
        return false;
    }
    true
}

#[cfg(all(target_os = "linux", target_env = "gnu"))]
fn release_to_os() {
    unsafe extern "C" {
        fn malloc_trim(pad: usize) -> c_int;
    }
    // SAFETY: `malloc_trim` only returns unused pages of glibc's own arenas and takes each
    // arena's lock itself, so it is safe to call concurrently with other allocating threads.
    let released = unsafe { malloc_trim(0) };
    tracing::debug!("Heap release returned memory to the OS: {}", released != 0);
}

#[cfg(not(all(target_os = "linux", target_env = "gnu")))]
fn release_to_os() {}

#[cfg(all(test, target_os = "linux", target_env = "gnu"))]
mod tests {
    use super::*;
    #[cfg(test)]
    use std::thread::{sleep, yield_now};

    #[test]
    fn pending_release_coalesces_requests_until_it_runs() {
        assert!(schedule_release_after(|| sleep(Duration::from_millis(50))));
        assert!(!schedule_release_after(|| sleep(Duration::from_millis(50))));
        while RELEASE_PENDING.load(Ordering::Acquire) {
            yield_now();
        }
        assert!(schedule_release_after(|| {}));
    }
}
