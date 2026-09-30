//! Background job manager for long-running operations.
//!
//! Every operation that can take noticeable time (renders, exports, imports, tempo
//! detection, plugin install/restore/removal, plugin scans) runs as a job so no Flutter
//! Rust Bridge worker thread waits on it. Jobs report lifecycle events through one sink and
//! can be cancelled cooperatively.

/// Device-derived concurrency limits and memory probes.
pub mod budget;
/// Thread pool shared by the CPU-heavy parts of jobs.
pub mod compute;
/// Job lifecycle events and their destination.
pub mod events;
mod service;
#[cfg(test)]
#[allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    reason = "test fixtures fail immediately on unexpected results"
)]
mod tests;

pub use budget::{DeviceBudget, JobLimits};
pub use compute::compute_pool;
pub use events::{JobEvent, JobEventSink, JobState};
pub use service::{
    JobClass, JobContext, JobError, JobHandle, JobId, JobKind, JobService, JobSpec, JobTarget,
    global, set_runtime_provider,
};
