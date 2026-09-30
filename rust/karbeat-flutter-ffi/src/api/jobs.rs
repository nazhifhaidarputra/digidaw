//! Background job events and cancellation for Flutter.

use flutter_rust_bridge::frb;
use karbeat_core_api::jobs::{
    self, JobContext, JobEvent, JobEventSink, JobKind, JobSpec, JobState, JobTarget,
};

use crate::frb_generated::StreamSink;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum UiJobKind {
    ProjectExport,
    Bounce,
    ProjectLoad,
    ProjectSave,
    ProjectRestore,
    AudioImport,
    WaveformRender,
    TempoDetection,
    PluginInstall,
    PluginRemoval,
    PluginRetry,
    PluginReconfigure,
    PluginScan,
}

impl From<JobKind> for UiJobKind {
    fn from(value: JobKind) -> Self {
        match value {
            JobKind::ProjectExport => Self::ProjectExport,
            JobKind::Bounce => Self::Bounce,
            JobKind::ProjectLoad => Self::ProjectLoad,
            JobKind::ProjectSave => Self::ProjectSave,
            JobKind::ProjectRestore => Self::ProjectRestore,
            JobKind::AudioImport => Self::AudioImport,
            JobKind::WaveformRender => Self::WaveformRender,
            JobKind::TempoDetection => Self::TempoDetection,
            JobKind::PluginInstall => Self::PluginInstall,
            JobKind::PluginRemoval => Self::PluginRemoval,
            JobKind::PluginRetry => Self::PluginRetry,
            JobKind::PluginReconfigure => Self::PluginReconfigure,
            JobKind::PluginScan => Self::PluginScan,
        }
    }
}

/// Project object a job works on; refresh it when the job completes.
#[derive(Clone, Debug)]
#[frb(dart_metadata=("freezed"))]
pub enum UiJobTarget {
    None,
    Project,
    Source { source_id: u64 },
}

impl From<JobTarget> for UiJobTarget {
    fn from(value: JobTarget) -> Self {
        match value {
            JobTarget::None => Self::None,
            JobTarget::Project => Self::Project,
            JobTarget::Source(source) => Self::Source {
                source_id: source.to_u64(),
            },
        }
    }
}

#[derive(Clone, Debug)]
#[frb(dart_metadata=("freezed"))]
pub enum UiJobState {
    Queued,
    Running,
    Progress { stage: String, fraction: f32 },
    Completed,
    Failed { message: String },
    Cancelled,
}

impl From<JobState> for UiJobState {
    fn from(value: JobState) -> Self {
        match value {
            JobState::Queued => Self::Queued,
            JobState::Running => Self::Running,
            JobState::Progress { stage, fraction } => Self::Progress {
                stage: stage.to_owned(),
                fraction,
            },
            JobState::Completed => Self::Completed,
            JobState::Failed(message) => Self::Failed { message },
            JobState::Cancelled => Self::Cancelled,
        }
    }
}

#[derive(Clone, Debug)]
#[frb(dart_metadata=("freezed"))]
pub struct UiJobEvent {
    pub id: u64,
    pub kind: UiJobKind,
    pub target: UiJobTarget,
    pub state: UiJobState,
}

impl From<JobEvent> for UiJobEvent {
    fn from(value: JobEvent) -> Self {
        Self {
            id: value.id,
            kind: value.kind.into(),
            target: value.target.into(),
            state: value.state.into(),
        }
    }
}

struct StreamJobSink(StreamSink<UiJobEvent>);

impl JobEventSink for StreamJobSink {
    fn send(&self, event: &JobEvent) -> bool {
        self.0.add(event.clone().into()).is_ok()
    }
}

/// Streams lifecycle events of every background job. A new subscription replaces the old one.
pub fn subscribe_job_events(sink: StreamSink<UiJobEvent>) {
    jobs::global().set_event_sink(Box::new(StreamJobSink(sink)));
}

/// Asks a background job to stop. Returns `false` when no unfinished job has that id.
pub async fn cancel_job(id: u64) -> bool {
    jobs::global().cancel(id)
}

/// Runs blocking `work` as a background job and waits for it.
///
/// Awaiting frees the FRB worker: the work runs on the job runtime's blocking pool.
pub(crate) async fn run_job<T, E, F>(spec: JobSpec, work: F) -> Result<T, String>
where
    T: Send + 'static,
    E: std::fmt::Display + Send + 'static,
    F: FnOnce(&JobContext) -> Result<T, E> + Send + 'static,
{
    jobs::global()
        .submit(spec, work)
        .wait()
        .await
        .map_err(|error| error.to_string())
}

/// Runtime handle of Flutter Rust Bridge's async executor, which background jobs share.
pub(crate) fn frb_runtime_handle() -> tokio::runtime::Handle {
    crate::frb_generated::FLUTTER_RUST_BRIDGE_HANDLER
        .async_runtime()
        .0
        .handle()
        .clone()
}
