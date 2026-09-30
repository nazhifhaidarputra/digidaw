use std::{
    sync::{
        Arc,
        atomic::{AtomicUsize, Ordering},
        mpsc,
    },
    time::Duration,
};

use karbeat_core::shared::id::AudioSourceId;
use parking_lot::Mutex;
use slotmap::KeyData;
use tokio::runtime::Runtime;

use super::{
    JobClass, JobContext, JobError, JobEvent, JobEventSink, JobKind, JobLimits, JobService,
    JobSpec, JobState, JobTarget,
};

const LIMITS: JobLimits = JobLimits {
    heavy: 1,
    inference: 1,
    io: 1,
};

fn runtime() -> Runtime {
    tokio::runtime::Builder::new_multi_thread()
        .worker_threads(2)
        .enable_all()
        .build()
        .unwrap()
}

fn service(runtime: &Runtime) -> JobService {
    JobService::with_handle(runtime.handle().clone(), LIMITS)
}

#[derive(Clone, Default)]
struct Recorder(Arc<Mutex<Vec<JobEvent>>>);

impl JobEventSink for Recorder {
    fn send(&self, event: &JobEvent) -> bool {
        self.0.lock().push(event.clone());
        true
    }
}

impl Recorder {
    fn states(&self, id: u64) -> Vec<JobState> {
        self.0
            .lock()
            .iter()
            .filter(|event| event.id == id)
            .map(|event| event.state.clone())
            .collect()
    }
}

/// Blocks until cancelled, polling like real chunked work does.
fn until_cancelled(job: &JobContext) -> Result<(), &'static str> {
    while !job.is_cancelled() {
        std::thread::sleep(Duration::from_millis(1));
    }
    Err("stopped")
}

fn source(index: u64) -> JobTarget {
    JobTarget::Source(AudioSourceId::from(KeyData::from_ffi(index | (1 << 32))))
}

#[test]
fn completed_job_returns_its_value_and_reports_each_state_in_order() {
    let runtime = runtime();
    let jobs = service(&runtime);
    let recorder = Recorder::default();
    jobs.set_event_sink(Box::new(recorder.clone()));

    let handle = jobs.submit(
        JobSpec::new(JobKind::ProjectExport, JobClass::Heavy),
        |_| Ok::<_, String>(42),
    );
    let id = handle.id();

    assert_eq!(handle.wait_blocking().unwrap(), 42);
    assert_eq!(
        recorder.states(id),
        vec![JobState::Queued, JobState::Running, JobState::Completed]
    );
    assert_eq!(jobs.active_jobs(), 0);
}

#[test]
fn failure_is_reported_with_the_work_error() {
    let runtime = runtime();
    let jobs = service(&runtime);
    let recorder = Recorder::default();
    jobs.set_event_sink(Box::new(recorder.clone()));

    let handle = jobs.submit(
        JobSpec::new(JobKind::ProjectSave, JobClass::Control),
        |_| Err::<(), _>("disk full"),
    );
    let id = handle.id();

    assert!(
        matches!(handle.wait_blocking(), Err(JobError::Failed(message)) if message == "disk full")
    );
    assert_eq!(
        recorder.states(id).last(),
        Some(&JobState::Failed("disk full".into()))
    );
}

#[test]
fn cancel_stops_a_running_cooperative_job() {
    let runtime = runtime();
    let jobs = service(&runtime);
    let (started, running) = mpsc::channel();

    let handle = jobs.submit(
        JobSpec::new(JobKind::TempoDetection, JobClass::Inference),
        move |job| {
            started.send(()).unwrap();
            until_cancelled(job)
        },
    );
    running.recv().unwrap();

    assert!(jobs.cancel(handle.id()));
    assert!(matches!(handle.wait_blocking(), Err(JobError::Cancelled)));
    assert!(!jobs.cancel(0));
}

#[test]
fn superseding_job_cancels_the_older_job_for_the_same_target() {
    let runtime = runtime();
    let jobs = service(&runtime);
    let (started, running) = mpsc::channel();
    let spec = JobSpec::new(JobKind::WaveformRender, JobClass::Control)
        .with_target(source(1))
        .superseding();

    let older = jobs.submit(spec, move |job| {
        started.send(()).unwrap();
        until_cancelled(job)
    });
    running.recv().unwrap();
    let other_target = jobs.submit(spec.with_target(source(2)), |_| Ok::<_, String>(()));
    let newer = jobs.submit(spec, |_| Ok::<_, String>("new"));

    assert!(matches!(older.wait_blocking(), Err(JobError::Cancelled)));
    assert_eq!(newer.wait_blocking().unwrap(), "new");
    assert!(other_target.wait_blocking().is_ok());
}

#[test]
fn queued_job_cancelled_while_waiting_for_a_slot_never_runs() {
    let runtime = runtime();
    let jobs = service(&runtime);
    let (started, running) = mpsc::channel();
    let (release, released) = mpsc::channel::<()>();
    let ran = Arc::new(AtomicUsize::new(0));

    let blocker = jobs.submit(
        JobSpec::new(JobKind::ProjectExport, JobClass::Heavy),
        move |_| {
            started.send(()).unwrap();
            released.recv().map_err(|error| error.to_string())
        },
    );
    running.recv().unwrap();
    let queued_ran = Arc::clone(&ran);
    let queued = jobs.submit(
        JobSpec::new(JobKind::WaveformRender, JobClass::Heavy),
        move |_| {
            queued_ran.fetch_add(1, Ordering::Relaxed);
            Ok::<_, String>(())
        },
    );

    assert!(jobs.cancel(queued.id()));
    assert!(matches!(queued.wait_blocking(), Err(JobError::Cancelled)));
    release.send(()).unwrap();
    assert!(blocker.wait_blocking().is_ok());
    assert_eq!(ran.load(Ordering::Relaxed), 0);
}

#[test]
fn class_semaphore_caps_concurrent_jobs() {
    let runtime = runtime();
    let jobs = JobService::with_handle(runtime.handle().clone(), JobLimits { heavy: 2, ..LIMITS });
    let running = Arc::new(AtomicUsize::new(0));
    let peak = Arc::new(AtomicUsize::new(0));

    let handles: Vec<_> = (0..6)
        .map(|_| {
            let running = Arc::clone(&running);
            let peak = Arc::clone(&peak);
            jobs.submit(
                JobSpec::new(JobKind::WaveformRender, JobClass::Heavy),
                move |_| {
                    let now = running.fetch_add(1, Ordering::SeqCst) + 1;
                    peak.fetch_max(now, Ordering::SeqCst);
                    std::thread::sleep(Duration::from_millis(20));
                    running.fetch_sub(1, Ordering::SeqCst);
                    Ok::<_, String>(())
                },
            )
        })
        .collect();
    for handle in handles {
        handle.wait_blocking().unwrap();
    }

    assert_eq!(peak.load(Ordering::SeqCst), 2);
}

#[test]
fn control_job_does_not_wait_behind_a_heavy_job() {
    let runtime = runtime();
    let jobs = service(&runtime);
    let (started, running) = mpsc::channel();
    let (release, released) = mpsc::channel::<()>();

    let render = jobs.submit(
        JobSpec::new(JobKind::ProjectExport, JobClass::Heavy),
        move |_| {
            started.send(()).unwrap();
            released.recv().map_err(|error| error.to_string())
        },
    );
    running.recv().unwrap();
    let install = jobs.submit(
        JobSpec::new(JobKind::PluginInstall, JobClass::Control),
        |_| Ok::<_, String>("installed"),
    );

    assert_eq!(install.wait_blocking().unwrap(), "installed");
    release.send(()).unwrap();
    assert!(render.wait_blocking().is_ok());
}

#[test]
fn project_replacement_cancels_source_jobs_and_marks_them_stale() {
    let runtime = runtime();
    let jobs = service(&runtime);
    let (started, running) = mpsc::channel();

    let render = jobs.submit(
        JobSpec::new(JobKind::WaveformRender, JobClass::Control).with_target(source(1)),
        move |job| {
            started.send(()).unwrap();
            while !job.is_cancelled() {
                std::thread::sleep(Duration::from_millis(1));
            }
            Ok::<_, String>(job.is_current())
        },
    );
    running.recv().unwrap();
    let generation = jobs.begin_project_replacement();

    assert_eq!(generation, 1);
    assert_eq!(jobs.generation(), 1);
    assert!(!render.wait_blocking().unwrap());
}

#[test]
fn panicking_job_is_reported_without_taking_down_the_runtime() {
    let runtime = runtime();
    let jobs = service(&runtime);

    let crashed = jobs.submit(
        JobSpec::new(JobKind::ProjectExport, JobClass::Heavy),
        |_| -> Result<(), String> { panic!("render bug") },
    );
    assert!(matches!(crashed.wait_blocking(), Err(JobError::Panicked)));

    let next = jobs.submit(
        JobSpec::new(JobKind::ProjectExport, JobClass::Heavy),
        |_| Ok::<_, String>(()),
    );
    assert!(next.wait_blocking().is_ok());
}

#[test]
fn async_job_runs_on_the_runtime_and_can_be_cancelled() {
    let runtime = runtime();
    let jobs = service(&runtime);

    let done = jobs.submit_async(JobSpec::new(JobKind::PluginScan, JobClass::Io), |_| async {
        Ok::<_, String>(7)
    });
    assert_eq!(done.wait_blocking().unwrap(), 7);

    let (started, running) = mpsc::channel();
    let waiting = jobs.submit_async(
        JobSpec::new(JobKind::PluginScan, JobClass::Io),
        move |job| async move {
            started.send(()).unwrap();
            while !job.is_cancelled() {
                tokio::time::sleep(Duration::from_millis(1)).await;
            }
            Err::<(), _>("scan cancelled")
        },
    );
    running.recv().unwrap();
    assert!(jobs.cancel(waiting.id()));
    assert!(matches!(waiting.wait_blocking(), Err(JobError::Cancelled)));
}

#[test]
fn shutdown_cancels_running_jobs_and_rejects_new_ones() {
    let runtime = runtime();
    let jobs = service(&runtime);
    let (started, running) = mpsc::channel();

    let render = jobs.submit(
        JobSpec::new(JobKind::ProjectExport, JobClass::Heavy),
        move |job| {
            started.send(()).unwrap();
            until_cancelled(job)
        },
    );
    running.recv().unwrap();

    assert!(jobs.shutdown(Duration::from_secs(5)));
    assert!(matches!(render.wait_blocking(), Err(JobError::Cancelled)));
    assert!(matches!(
        jobs.submit(
            JobSpec::new(JobKind::ProjectSave, JobClass::Control),
            |_| Ok::<_, String>(()),
        )
        .wait_blocking(),
        Err(JobError::ShuttingDown)
    ));
}

#[test]
fn progress_events_are_throttled() {
    let runtime = runtime();
    let jobs = service(&runtime);
    let recorder = Recorder::default();
    jobs.set_event_sink(Box::new(recorder.clone()));

    let handle = jobs.submit(
        JobSpec::new(JobKind::ProjectExport, JobClass::Heavy),
        |job| {
            for step in 0..=10_000_u16 {
                job.progress("render", f32::from(step) / 10_000.0);
            }
            Ok::<_, String>(())
        },
    );
    let id = handle.id();
    handle.wait_blocking().unwrap();

    let progress: Vec<f32> = recorder
        .states(id)
        .into_iter()
        .filter_map(|state| match state {
            JobState::Progress { fraction, .. } => Some(fraction),
            _ => None,
        })
        .collect();
    assert!(progress.len() <= 102, "{} progress events", progress.len());
    assert_eq!(progress.last(), Some(&1.0));
}

#[test]
fn debounced_burst_runs_only_the_last_request() {
    let runtime = runtime();
    let jobs = service(&runtime);
    let ran = Arc::new(AtomicUsize::new(0));
    let spec = JobSpec::new(JobKind::WaveformRender, JobClass::Control)
        .with_target(source(1))
        .superseding();

    let handles: Vec<_> = (0..5)
        .map(|value| {
            let ran = Arc::clone(&ran);
            jobs.submit_debounced(spec, Duration::from_millis(30), move |_| {
                ran.fetch_add(1, Ordering::SeqCst);
                Ok::<_, String>(value)
            })
        })
        .collect();
    let results: Vec<_> = handles
        .into_iter()
        .map(super::JobHandle::wait_blocking)
        .collect();

    assert_eq!(ran.load(Ordering::SeqCst), 1);
    assert_eq!(results.last().unwrap().as_ref().unwrap(), &4);
    assert!(
        results[..4]
            .iter()
            .all(|result| matches!(result, Err(JobError::Cancelled)))
    );
}

#[test]
fn scheduled_task_runs_after_the_delay_unless_shut_down() {
    let runtime = runtime();
    let jobs = service(&runtime);
    let (done, finished) = mpsc::channel();
    jobs.schedule(Duration::from_millis(10), move || done.send(()).unwrap());
    finished.recv_timeout(Duration::from_secs(5)).unwrap();

    let (done, finished) = mpsc::channel::<()>();
    jobs.schedule(Duration::from_millis(50), move || done.send(()).unwrap());
    assert!(jobs.shutdown(Duration::from_secs(1)));
    assert!(finished.recv_timeout(Duration::from_millis(200)).is_err());
}
