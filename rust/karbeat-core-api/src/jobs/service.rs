use std::{
    collections::HashMap,
    fmt::Display,
    future::Future,
    sync::{
        Arc, OnceLock,
        atomic::{AtomicBool, AtomicU64, Ordering},
    },
    time::{Duration, Instant},
};

use karbeat_core::shared::id::AudioSourceId;
use parking_lot::Mutex;
use tokio::{
    runtime::{Handle, Runtime},
    sync::{OwnedSemaphorePermit, Semaphore, oneshot, watch},
};

use super::{
    budget::{DeviceBudget, JobLimits},
    events::{JobEvent, JobEventSink, JobState},
};

/// Identifier of one submitted job, unique for the process lifetime.
pub type JobId = u64;

/// Minimum spacing between progress events of one job, unless the fraction moved by 1% or more.
const PROGRESS_INTERVAL: Duration = Duration::from_millis(50);
const PROGRESS_STEP: f32 = 0.01;
/// How often [`JobService::shutdown`] re-checks whether every job has finished.
const SHUTDOWN_POLL: Duration = Duration::from_millis(10);

/// What a job does, reported with its events.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum JobKind {
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

/// Project object a job works on, so the UI knows what to refresh when it finishes.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum JobTarget {
    /// Not tied to project content.
    None,
    /// The whole project.
    Project,
    /// One audio source.
    Source(AudioSourceId),
}

/// Scheduling class, which decides the semaphore a job waits on.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum JobClass {
    /// Plugin and project operations. Never waits behind other classes; these are already
    /// serialized by the project operation lock.
    Control,
    /// Renders, exports and imports, limited to about half the physical cores.
    Heavy,
    /// Model inference, one at a time.
    Inference,
    /// Plugin scans, one at a time.
    Io,
}

/// How a job is scheduled and reported.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct JobSpec {
    pub kind: JobKind,
    pub class: JobClass,
    pub target: JobTarget,
    /// Cancels any unfinished job with the same kind and target when this one is submitted.
    pub supersede: bool,
}

impl JobSpec {
    /// A job without a target that never cancels other jobs.
    pub fn new(kind: JobKind, class: JobClass) -> Self {
        Self {
            kind,
            class,
            target: JobTarget::None,
            supersede: false,
        }
    }

    /// Reports the job against `target`.
    #[must_use]
    pub fn with_target(mut self, target: JobTarget) -> Self {
        self.target = target;
        self
    }

    /// Makes this job replace any unfinished job with the same kind and target.
    #[must_use]
    pub fn superseding(mut self) -> Self {
        self.supersede = true;
        self
    }
}

/// Why a job did not produce its value.
#[derive(Debug, thiserror::Error)]
pub enum JobError {
    #[error("the job was cancelled")]
    Cancelled,
    #[error("background jobs are shutting down")]
    ShuttingDown,
    #[error("the background runtime is unavailable: {0}")]
    RuntimeUnavailable(String),
    #[error("the job panicked")]
    Panicked,
    #[error("{0}")]
    Failed(String),
}

/// Cooperative cancellation shared by a job, the registry and anyone waiting for a slot.
#[derive(Clone)]
struct CancelToken {
    flag: Arc<AtomicBool>,
    signal: Arc<watch::Sender<bool>>,
}

impl CancelToken {
    fn new() -> Self {
        Self {
            flag: Arc::new(AtomicBool::new(false)),
            signal: Arc::new(watch::channel(false).0),
        }
    }

    fn cancel(&self) {
        self.flag.store(true, Ordering::Release);
        self.signal.send_replace(true);
    }

    fn is_cancelled(&self) -> bool {
        self.flag.load(Ordering::Acquire)
    }

    async fn cancelled(&self) {
        let mut receiver = self.signal.subscribe();
        drop(receiver.wait_for(|cancelled| *cancelled).await);
    }
}

/// Handle given to a running job for cancellation checks and progress reports.
pub struct JobContext {
    id: JobId,
    spec: JobSpec,
    generation: u64,
    cancel: CancelToken,
    shared: Arc<Shared>,
    last_progress: Mutex<Option<(Instant, &'static str, f32)>>,
}

impl JobContext {
    pub fn id(&self) -> JobId {
        self.id
    }

    /// Whether the job should stop. Check it between units of work.
    pub fn is_cancelled(&self) -> bool {
        self.cancel.is_cancelled()
    }

    /// The flag behind [`Self::is_cancelled`], for APIs that poll an `AtomicBool`.
    pub fn cancel_flag(&self) -> Arc<AtomicBool> {
        Arc::clone(&self.cancel.flag)
    }

    /// Project generation captured when the job was submitted.
    pub fn generation(&self) -> u64 {
        self.generation
    }

    /// Whether the project this job was submitted against is still loaded.
    ///
    /// Commit steps must check this so results for a replaced project are discarded.
    pub fn is_current(&self) -> bool {
        self.generation == self.shared.generation.load(Ordering::Acquire)
    }

    /// Reports progress for `stage`. Events are throttled, so call it as often as convenient.
    pub fn progress(&self, stage: &'static str, fraction: f32) {
        let fraction = fraction.clamp(0.0, 1.0);
        let now = Instant::now();
        let mut last = self.last_progress.lock();
        let due = match *last {
            None => true,
            Some((at, last_stage, last_fraction)) => {
                last_stage != stage
                    || fraction >= 1.0
                    || (fraction - last_fraction).abs() >= PROGRESS_STEP
                    || (now.duration_since(at) >= PROGRESS_INTERVAL && fraction > last_fraction)
            }
        };
        if !due {
            return;
        }
        *last = Some((now, stage, fraction));
        drop(last);
        self.shared.emit(JobEvent {
            id: self.id,
            kind: self.spec.kind,
            target: self.spec.target,
            state: JobState::Progress { stage, fraction },
        });
    }
}

/// Resolves to the job's value once it finishes.
pub struct JobHandle<T> {
    id: JobId,
    receiver: oneshot::Receiver<Result<T, JobError>>,
}

impl<T> JobHandle<T> {
    pub fn id(&self) -> JobId {
        self.id
    }

    /// Waits for the job. Dropping the handle instead lets the job finish in the background.
    pub async fn wait(self) -> Result<T, JobError> {
        self.receiver.await.unwrap_or(Err(JobError::ShuttingDown))
    }

    /// Blocks the calling thread until the job finishes.
    ///
    /// Only for synchronous callers outside the job runtime, such as tests.
    pub fn wait_blocking(self) -> Result<T, JobError> {
        futures_lite::future::block_on(self.wait())
    }
}

/// Where a service finds the Tokio runtime its jobs run on.
enum RuntimeSource {
    /// An explicit runtime, used by tests and embedders.
    Handle(Handle),
    /// The process runtime installed with [`set_runtime_provider`], or a private fallback.
    Process,
}

struct Entry {
    spec: JobSpec,
    cancel: CancelToken,
}

struct Shared {
    runtime: RuntimeSource,
    heavy: Arc<Semaphore>,
    inference: Arc<Semaphore>,
    io: Arc<Semaphore>,
    registry: Mutex<HashMap<JobId, Entry>>,
    next_id: AtomicU64,
    generation: AtomicU64,
    accepting: AtomicBool,
    sink: Mutex<Option<Box<dyn JobEventSink>>>,
}

impl Shared {
    fn runtime(&self) -> Result<Handle, JobError> {
        match &self.runtime {
            RuntimeSource::Handle(handle) => Ok(handle.clone()),
            RuntimeSource::Process => process_runtime(),
        }
    }

    fn semaphore(&self, class: JobClass) -> Option<Arc<Semaphore>> {
        match class {
            JobClass::Control => None,
            JobClass::Heavy => Some(Arc::clone(&self.heavy)),
            JobClass::Inference => Some(Arc::clone(&self.inference)),
            JobClass::Io => Some(Arc::clone(&self.io)),
        }
    }

    fn emit(&self, event: JobEvent) {
        let mut sink = self.sink.lock();
        if let Some(active) = sink.as_ref()
            && !active.send(&event)
        {
            *sink = None;
        }
    }

    fn event(&self, id: JobId, spec: JobSpec, state: JobState) {
        self.emit(JobEvent {
            id,
            kind: spec.kind,
            target: spec.target,
            state,
        });
    }

    /// Removes the job from the registry and publishes its terminal event.
    fn finish<T>(
        &self,
        id: JobId,
        spec: JobSpec,
        result: Result<T, JobError>,
        reply: oneshot::Sender<Result<T, JobError>>,
    ) {
        self.registry.lock().remove(&id);
        let state = match &result {
            Ok(_) => JobState::Completed,
            Err(JobError::Cancelled | JobError::ShuttingDown) => JobState::Cancelled,
            Err(error) => JobState::Failed(error.to_string()),
        };
        if let Err(error) = &result
            && !matches!(error, JobError::Cancelled | JobError::ShuttingDown)
        {
            log::warn!("Background job {id} ({:?}) failed: {error}", spec.kind);
        }
        self.event(id, spec, state);
        drop(reply.send(result));
    }

    /// Waits for a slot of the job's class. `Ok(None)` means the class has no limit.
    async fn acquire(
        &self,
        class: JobClass,
        cancel: &CancelToken,
    ) -> Result<Option<OwnedSemaphorePermit>, JobError> {
        let Some(semaphore) = self.semaphore(class) else {
            return Ok(None);
        };
        let acquired =
            futures_lite::future::or(async { Some(semaphore.acquire_owned().await) }, async {
                cancel.cancelled().await;
                None
            })
            .await;
        match acquired {
            Some(Ok(permit)) => Ok(Some(permit)),
            Some(Err(_)) => Err(JobError::ShuttingDown),
            None => Err(JobError::Cancelled),
        }
    }
}

/// Failure for a job whose work returned an error: cancelled if the job was asked to stop.
fn work_error(error: impl Display, cancel: &CancelToken) -> JobError {
    if cancel.is_cancelled() {
        JobError::Cancelled
    } else {
        JobError::Failed(format!("{error:#}"))
    }
}

/// Background job manager shared by every long-running operation.
///
/// Jobs are orchestrated on a Tokio runtime (Flutter Rust Bridge's async runtime in the app)
/// and their blocking work runs on the runtime's blocking pool, so FRB worker threads and
/// the async workers never wait on long operations. Each [`JobClass`] except `Control` is
/// limited by its own semaphore sized from the device.
pub struct JobService {
    shared: Arc<Shared>,
}

impl JobService {
    /// Creates a service that runs jobs on `handle`.
    pub fn with_handle(handle: Handle, limits: JobLimits) -> Self {
        Self::new(RuntimeSource::Handle(handle), limits)
    }

    fn new(runtime: RuntimeSource, limits: JobLimits) -> Self {
        Self {
            shared: Arc::new(Shared {
                runtime,
                heavy: Arc::new(Semaphore::new(limits.heavy.max(1))),
                inference: Arc::new(Semaphore::new(limits.inference.max(1))),
                io: Arc::new(Semaphore::new(limits.io.max(1))),
                registry: Mutex::new(HashMap::new()),
                next_id: AtomicU64::new(1),
                generation: AtomicU64::new(0),
                accepting: AtomicBool::new(true),
                sink: Mutex::new(None),
            }),
        }
    }

    /// Replaces the event destination. Events published while no sink is attached are dropped.
    pub fn set_event_sink(&self, sink: Box<dyn JobEventSink>) {
        *self.shared.sink.lock() = Some(sink);
    }

    /// Current project generation; see [`Self::begin_project_replacement`].
    pub fn generation(&self) -> u64 {
        self.shared.generation.load(Ordering::Acquire)
    }

    /// Registers a job and cancels the one it supersedes. Returns its id, token and generation.
    fn admit(&self, spec: JobSpec) -> Result<(JobId, CancelToken, u64), JobError> {
        if !self.shared.accepting.load(Ordering::Acquire) {
            return Err(JobError::ShuttingDown);
        }
        let id = self.shared.next_id.fetch_add(1, Ordering::Relaxed);
        let cancel = CancelToken::new();
        let mut registry = self.shared.registry.lock();
        if spec.supersede {
            for entry in registry.values() {
                if entry.spec.kind == spec.kind && entry.spec.target == spec.target {
                    entry.cancel.cancel();
                }
            }
        }
        registry.insert(
            id,
            Entry {
                spec,
                cancel: cancel.clone(),
            },
        );
        drop(registry);
        self.shared.event(id, spec, JobState::Queued);
        Ok((id, cancel, self.generation()))
    }

    fn rejected<T>(error: JobError) -> JobHandle<T> {
        let (reply, receiver) = oneshot::channel();
        drop(reply.send(Err(error)));
        JobHandle { id: 0, receiver }
    }

    /// Runs blocking `work` on the runtime's blocking pool once a slot of its class is free.
    ///
    /// `work` must check [`JobContext::is_cancelled`] between units of work. An error it
    /// returns after cancellation is reported as [`JobError::Cancelled`].
    pub fn submit<T, E, F>(&self, spec: JobSpec, work: F) -> JobHandle<T>
    where
        T: Send + 'static,
        E: Display + Send + 'static,
        F: FnOnce(&JobContext) -> Result<T, E> + Send + 'static,
    {
        let runtime = match self.shared.runtime() {
            Ok(runtime) => runtime,
            Err(error) => return Self::rejected(error),
        };
        let (id, cancel, generation) = match self.admit(spec) {
            Ok(admitted) => admitted,
            Err(error) => return Self::rejected(error),
        };
        let (reply, receiver) = oneshot::channel();
        let shared = Arc::clone(&self.shared);
        runtime.spawn(async move {
            let permit = match shared.acquire(spec.class, &cancel).await {
                Ok(permit) => permit,
                Err(error) => return shared.finish(id, spec, Err(error), reply),
            };
            if cancel.is_cancelled() {
                return shared.finish(id, spec, Err(JobError::Cancelled), reply);
            }
            shared.event(id, spec, JobState::Running);
            let context = JobContext {
                id,
                spec,
                generation,
                cancel: cancel.clone(),
                shared: Arc::clone(&shared),
                last_progress: Mutex::new(None),
            };
            let joined = tokio::task::spawn_blocking(move || work(&context)).await;
            drop(permit);
            let result = match joined {
                Ok(Ok(value)) => Ok(value),
                Ok(Err(error)) => Err(work_error(error, &cancel)),
                Err(_) => Err(JobError::Panicked),
            };
            shared.finish(id, spec, result, reply);
        });
        JobHandle { id, receiver }
    }

    /// Runs async `work` on the runtime once a slot of its class is free.
    ///
    /// For jobs that only await other services, such as the plugin host. Blocking work must
    /// use [`Self::submit`] instead.
    pub fn submit_async<T, E, F, Fut>(&self, spec: JobSpec, work: F) -> JobHandle<T>
    where
        T: Send + 'static,
        E: Display + Send + 'static,
        F: FnOnce(JobContext) -> Fut + Send + 'static,
        Fut: Future<Output = Result<T, E>> + Send + 'static,
    {
        let runtime = match self.shared.runtime() {
            Ok(runtime) => runtime,
            Err(error) => return Self::rejected(error),
        };
        let (id, cancel, generation) = match self.admit(spec) {
            Ok(admitted) => admitted,
            Err(error) => return Self::rejected(error),
        };
        let (reply, receiver) = oneshot::channel();
        let shared = Arc::clone(&self.shared);
        let orchestration = async move {
            let permit = match shared.acquire(spec.class, &cancel).await {
                Ok(permit) => permit,
                Err(error) => return shared.finish(id, spec, Err(error), reply),
            };
            if cancel.is_cancelled() {
                return shared.finish(id, spec, Err(JobError::Cancelled), reply);
            }
            shared.event(id, spec, JobState::Running);
            let context = JobContext {
                id,
                spec,
                generation,
                cancel: cancel.clone(),
                shared: Arc::clone(&shared),
                last_progress: Mutex::new(None),
            };
            let joined = runtime_spawn_result(work(context)).await;
            drop(permit);
            let result = match joined {
                Ok(Ok(value)) => Ok(value),
                Ok(Err(error)) => Err(work_error(error, &cancel)),
                Err(_) => Err(JobError::Panicked),
            };
            shared.finish(id, spec, result, reply);
        };
        runtime.spawn(orchestration);
        JobHandle { id, receiver }
    }

    /// Runs blocking `work` after `delay`, like [`Self::submit`].
    ///
    /// With [`JobSpec::superseding`], a burst of requests renders once: each new request
    /// cancels the one still waiting.
    pub fn submit_debounced<T, E, F>(&self, spec: JobSpec, delay: Duration, work: F) -> JobHandle<T>
    where
        T: Send + 'static,
        E: Display + Send + 'static,
        F: FnOnce(&JobContext) -> Result<T, E> + Send + 'static,
    {
        self.submit_async(spec, move |job| async move {
            tokio::time::sleep(delay).await;
            if job.is_cancelled() {
                return Err(String::from("superseded"));
            }
            tokio::task::spawn_blocking(move || work(&job).map_err(|error| format!("{error:#}")))
                .await
                .unwrap_or_else(|_| Err(String::from("the job panicked")))
        })
    }

    /// Runs `task` on the blocking pool after `delay`, outside the job registry.
    ///
    /// For housekeeping such as unloading idle models. Skipped once shutdown has begun.
    pub fn schedule(&self, delay: Duration, task: impl FnOnce() + Send + 'static) {
        if !self.shared.accepting.load(Ordering::Acquire) {
            return;
        }
        let Ok(runtime) = self.shared.runtime() else {
            return;
        };
        let shared = Arc::clone(&self.shared);
        runtime.spawn(async move {
            tokio::time::sleep(delay).await;
            if shared.accepting.load(Ordering::Acquire) {
                drop(tokio::task::spawn_blocking(task).await);
            }
        });
    }

    /// Asks a job to stop. Returns `false` when no unfinished job has that id.
    pub fn cancel(&self, id: JobId) -> bool {
        let registry = self.shared.registry.lock();
        let Some(entry) = registry.get(&id) else {
            return false;
        };
        entry.cancel.cancel();
        true
    }

    /// Starts a new project generation and cancels jobs working on the old project's sources.
    ///
    /// Call before replacing the loaded project. Returns the new generation.
    pub fn begin_project_replacement(&self) -> u64 {
        let generation = self
            .shared
            .generation
            .fetch_add(1, Ordering::AcqRel)
            .wrapping_add(1);
        for entry in self.shared.registry.lock().values() {
            if matches!(entry.spec.target, JobTarget::Source(_)) {
                entry.cancel.cancel();
            }
        }
        generation
    }

    /// Number of unfinished jobs.
    pub fn active_jobs(&self) -> usize {
        self.shared.registry.lock().len()
    }

    /// Stops accepting jobs, cancels every unfinished one and waits up to `timeout` for them
    /// to finish. Returns whether every job finished in time.
    ///
    /// Blocks the calling thread, so never call it from a runtime worker.
    pub fn shutdown(&self, timeout: Duration) -> bool {
        self.shared.accepting.store(false, Ordering::Release);
        for entry in self.shared.registry.lock().values() {
            entry.cancel.cancel();
        }
        self.shared.heavy.close();
        self.shared.inference.close();
        self.shared.io.close();
        let deadline = Instant::now() + timeout;
        while self.active_jobs() > 0 {
            if Instant::now() >= deadline {
                log::warn!(
                    "{} background job(s) still running at shutdown",
                    self.active_jobs()
                );
                return false;
            }
            std::thread::sleep(SHUTDOWN_POLL);
        }
        true
    }
}

/// Runs `future` as its own task so a panic inside it is caught instead of unwinding the
/// orchestration task.
fn runtime_spawn_result<Fut>(future: Fut) -> tokio::task::JoinHandle<Fut::Output>
where
    Fut: Future + Send + 'static,
    Fut::Output: Send + 'static,
{
    tokio::spawn(future)
}

static RUNTIME_PROVIDER: OnceLock<fn() -> Handle> = OnceLock::new();
static FALLBACK_RUNTIME: OnceLock<Result<Runtime, String>> = OnceLock::new();
static SERVICE: OnceLock<JobService> = OnceLock::new();

/// Installs the process runtime used by [`global`]. Only the first call takes effect.
///
/// The Flutter bridge installs its own async runtime here, so jobs share it.
pub fn set_runtime_provider(provider: fn() -> Handle) -> bool {
    RUNTIME_PROVIDER.set(provider).is_ok()
}

fn process_runtime() -> Result<Handle, JobError> {
    if let Some(provider) = RUNTIME_PROVIDER.get() {
        return Ok(provider());
    }
    let fallback = FALLBACK_RUNTIME.get_or_init(|| {
        tokio::runtime::Builder::new_multi_thread()
            .worker_threads(2)
            .thread_name("karbeat-jobs")
            .enable_all()
            .build()
            .map_err(|error| error.to_string())
    });
    match fallback {
        Ok(runtime) => Ok(runtime.handle().clone()),
        Err(error) => Err(JobError::RuntimeUnavailable(error.clone())),
    }
}

/// The process-wide job service, sized for the current device.
pub fn global() -> &'static JobService {
    SERVICE.get_or_init(|| {
        JobService::new(
            RuntimeSource::Process,
            JobLimits::for_device(&DeviceBudget::detect()),
        )
    })
}
