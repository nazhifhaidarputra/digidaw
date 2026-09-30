use super::{JobId, JobKind, JobTarget};

/// Lifecycle state carried by a [`JobEvent`].
#[derive(Clone, Debug, PartialEq)]
pub enum JobState {
    /// Accepted and waiting for a worker slot.
    Queued,
    /// Running on a worker.
    Running,
    /// Progress report from a running job; `fraction` is in `0.0..=1.0`.
    Progress { stage: &'static str, fraction: f32 },
    /// Finished successfully.
    Completed,
    /// Finished with an error.
    Failed(String),
    /// Stopped before finishing, by a cancel request, a newer job, or shutdown.
    Cancelled,
}

impl JobState {
    /// Whether no further events follow this one for the same job.
    pub fn is_terminal(&self) -> bool {
        matches!(self, Self::Completed | Self::Failed(_) | Self::Cancelled)
    }
}

/// One lifecycle update of a background job.
#[derive(Clone, Debug, PartialEq)]
pub struct JobEvent {
    pub id: JobId,
    pub kind: JobKind,
    pub target: JobTarget,
    pub state: JobState,
}

/// Destination for job events, such as a Flutter stream.
///
/// Called from worker threads, so it must not block.
pub trait JobEventSink: Send + Sync {
    /// Returns `false` when the destination is closed and must be detached.
    fn send(&self, event: &JobEvent) -> bool;
}
