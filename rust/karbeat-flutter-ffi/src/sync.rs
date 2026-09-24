//! Locks, threads, and channels shared by the session context and the log bridge.
//!
//! Unit tests swap in Shuttle equivalents so concurrency tests run under its
//! deterministic scheduler instead of the OS scheduler.

#[cfg(not(test))]
pub(crate) use parking_lot::{Mutex, MutexGuard, RwLock, RwLockReadGuard, RwLockWriteGuard};
#[cfg(not(test))]
pub(crate) use std::{
    sync::{atomic, mpsc},
    thread, thread_local,
};

#[cfg(test)]
pub(crate) use shuttle::{
    sync::{MutexGuard, RwLockReadGuard, RwLockWriteGuard, atomic, mpsc},
    thread, thread_local,
};
#[cfg(test)]
pub(crate) use shuttle_lock::{Mutex, RwLock};

/// `parking_lot`-shaped wrappers so production call sites compile unchanged under Shuttle.
#[cfg(test)]
mod shuttle_lock {
    use std::sync::PoisonError;

    use super::{MutexGuard, RwLockReadGuard, RwLockWriteGuard};

    pub(crate) struct Mutex<T>(shuttle::sync::Mutex<T>);

    impl<T> Mutex<T> {
        pub(crate) fn new(value: T) -> Self {
            Self(shuttle::sync::Mutex::new(value))
        }

        pub(crate) fn lock(&self) -> MutexGuard<'_, T> {
            self.0.lock().unwrap_or_else(PoisonError::into_inner)
        }

        pub(crate) fn try_lock(&self) -> Option<MutexGuard<'_, T>> {
            self.0.try_lock().ok()
        }
    }

    pub(crate) struct RwLock<T>(shuttle::sync::RwLock<T>);

    impl<T> RwLock<T> {
        pub(crate) fn new(value: T) -> Self {
            Self(shuttle::sync::RwLock::new(value))
        }

        pub(crate) fn read(&self) -> RwLockReadGuard<'_, T> {
            self.0.read().unwrap_or_else(PoisonError::into_inner)
        }

        pub(crate) fn write(&self) -> RwLockWriteGuard<'_, T> {
            self.0.write().unwrap_or_else(PoisonError::into_inner)
        }
    }
}

/// Runs `test` under Shuttle's random scheduler with enough stack for a full core context.
#[cfg(test)]
pub(crate) fn check_random(test: impl Fn() + Send + Sync + 'static, iterations: usize) {
    let mut config = shuttle::Config::new();
    config.stack_size = 1 << 21;
    shuttle::Runner::new(shuttle::scheduler::RandomScheduler::new(iterations), config).run(test);
}
