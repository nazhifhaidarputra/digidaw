//! LV2 worker extension: non-realtime jobs a plugin schedules from its audio thread.
//!
//! A plugin hands a request to `schedule_work` inside `run`. In realtime the request crosses a
//! bounded ring to one worker thread per instance, which calls the plugin's `work`; responses
//! come back over a second ring and are delivered after the next block. While rendering
//! offline the job runs inside `schedule_work`, so an export never races a job such as loading
//! a sample.

use std::{
    ffi::c_void,
    sync::{
        Arc, Mutex, MutexGuard, PoisonError,
        atomic::{AtomicBool, Ordering},
    },
    thread::{JoinHandle, Thread},
    time::Duration,
};

use karbeat_host_api::HostError;

use crate::atoms::{AtomReceiver, AtomSender, atom_ring};

/// Capacity of each direction's message ring, which also bounds one message.
const RING_BYTES: usize = 64 * 1024;
/// How long an idle worker sleeps if a wake-up is ever missed.
const IDLE_WAIT: Duration = Duration::from_millis(100);

const SUCCESS: lv2_sys::LV2_Worker_Status = lv2_sys::LV2_Worker_Status_LV2_WORKER_SUCCESS;
const NO_SPACE: lv2_sys::LV2_Worker_Status = lv2_sys::LV2_Worker_Status_LV2_WORKER_ERR_NO_SPACE;
const UNKNOWN: lv2_sys::LV2_Worker_Status = lv2_sys::LV2_Worker_Status_LV2_WORKER_ERR_UNKNOWN;

type WorkFn = unsafe extern "C" fn(
    lv2_sys::LV2_Handle,
    lv2_sys::LV2_Worker_Respond_Function,
    lv2_sys::LV2_Worker_Respond_Handle,
    u32,
    *const c_void,
) -> lv2_sys::LV2_Worker_Status;

/// A plugin's `work` entry point with the instance it belongs to.
#[derive(Clone, Copy)]
struct Work {
    call: WorkFn,
    instance: lv2_sys::LV2_Handle,
}

// SAFETY: LV2 lets a host call `work` from a non-realtime thread while `run` executes; the
// handle is only used for that call, and the worker stops before the instance is freed.
unsafe impl Send for Work {}

impl Work {
    /// Runs one job, with `responses` receiving whatever the plugin sends back.
    ///
    /// # Safety
    /// The instance must be alive, `data` must point to `size` readable bytes, and no other
    /// job of this instance may be running.
    unsafe fn run(
        &self,
        responses: &mut AtomSender,
        size: u32,
        data: *const c_void,
    ) -> lv2_sys::LV2_Worker_Status {
        let handle = std::ptr::from_mut(responses).cast();
        // SAFETY: The caller guarantees the instance and the request; the response queue
        // outlives this synchronous call.
        unsafe { (self.call)(self.instance, Some(respond), handle, size, data) }
    }
}

/// Where `schedule_work` sends a request.
enum Route {
    /// The plugin asked for the feature but offers no worker interface.
    Detached,
    /// Queue the request for the worker thread.
    Threaded {
        requests: AtomSender,
        thread: Thread,
    },
    /// Run the job immediately; used while rendering offline.
    Inline { work: Work, responses: AtomSender },
}

/// The `worker:schedule` feature of one instance.
///
/// It is created before instantiation, because the plugin receives the record then, and is
/// routed once the plugin's worker interface is known.
pub(crate) struct WorkerPort {
    record: Box<lv2_sys::LV2_Worker_Schedule>,
    route: Box<Route>,
}

impl WorkerPort {
    pub fn new() -> Self {
        let mut route = Box::new(Route::Detached);
        Self {
            record: Box::new(lv2_sys::LV2_Worker_Schedule {
                handle: std::ptr::from_mut::<Route>(route.as_mut()).cast(),
                schedule_work: Some(schedule_work),
            }),
            route,
        }
    }

    /// The `worker:schedule` feature record.
    pub fn feature(&self) -> lv2_sys::LV2_Feature {
        lv2_sys::LV2_Feature {
            URI: lv2_sys::LV2_WORKER__schedule.as_ptr().cast(),
            data: std::ptr::from_ref::<lv2_sys::LV2_Worker_Schedule>(self.record.as_ref())
                .cast_mut()
                .cast(),
        }
    }

    /// Connects the feature to the plugin's worker interface.
    ///
    /// Returns the audio-side response queue and, in realtime, the worker thread.
    pub fn attach(
        &mut self,
        interface: &lv2_sys::LV2_Worker_Interface,
        instance: lv2_sys::LV2_Handle,
        offline: bool,
    ) -> Result<(WorkerResponses, Option<WorkerThread>), HostError> {
        let Some(call) = interface.work else {
            return Err(HostError::Unsupported("LV2 worker without a work function"));
        };
        let work = Work { call, instance };
        let (to_audio, from_worker) = atom_ring(RING_BYTES);
        let thread = if offline {
            *self.route = Route::Inline {
                work,
                responses: to_audio,
            };
            None
        } else {
            let (to_worker, from_audio) = atom_ring(RING_BYTES);
            let thread = WorkerThread::spawn(work, from_audio, to_audio)?;
            *self.route = Route::Threaded {
                requests: to_worker,
                thread: thread.handle(),
            };
            Some(thread)
        };
        Ok((
            WorkerResponses {
                receiver: from_worker,
                respond: interface.work_response,
                end_run: interface.end_run,
                scratch: Vec::with_capacity(RING_BYTES),
            },
            thread,
        ))
    }
}

/// # Safety
/// `data` must point to `size` readable bytes, or `size` must be zero.
unsafe fn message<'a>(size: u32, data: *const c_void) -> Option<&'a [u8]> {
    let size = usize::try_from(size).ok()?;
    if size == 0 {
        return Some(&[]);
    }
    if data.is_null() {
        return None;
    }
    // SAFETY: The caller guarantees `size` readable bytes at a non-null `data`.
    Some(unsafe { std::slice::from_raw_parts(data.cast::<u8>(), size) })
}

unsafe extern "C" fn schedule_work(
    handle: *mut c_void,
    size: u32,
    data: *const c_void,
) -> lv2_sys::LV2_Worker_Status {
    if handle.is_null() {
        return UNKNOWN;
    }
    // SAFETY: The handle is the boxed route of the instance whose `run` is calling. Only that
    // one thread schedules work, so the route is not aliased.
    let route = unsafe { &mut *handle.cast::<Route>() };
    match route {
        Route::Detached => UNKNOWN,
        Route::Threaded { requests, thread } => {
            // SAFETY: The plugin passes `size` readable bytes for this call.
            let Some(body) = (unsafe { message(size, data) }) else {
                return UNKNOWN;
            };
            if requests.send(0, 0, body) {
                thread.unpark();
                SUCCESS
            } else {
                NO_SPACE
            }
        }
        Route::Inline { work, responses } => {
            // SAFETY: Offline rendering is not realtime, so the job may run here, inside the
            // only `run` of this instance. The data is the plugin's own request.
            unsafe { work.run(responses, size, data) }
        }
    }
}

unsafe extern "C" fn respond(
    handle: *mut c_void,
    size: u32,
    data: *const c_void,
) -> lv2_sys::LV2_Worker_Status {
    if handle.is_null() {
        return UNKNOWN;
    }
    // SAFETY: The handle is the response queue passed to `work`, used only for that call.
    let responses = unsafe { &mut *handle.cast::<AtomSender>() };
    // SAFETY: The plugin passes `size` readable bytes for this call.
    match unsafe { message(size, data) } {
        Some(body) if responses.send(0, 0, body) => SUCCESS,
        Some(_) => NO_SPACE,
        None => UNKNOWN,
    }
}

/// Audio-side queue of worker responses, delivered to the plugin after each block.
pub(crate) struct WorkerResponses {
    receiver: AtomReceiver,
    respond: Option<
        unsafe extern "C" fn(lv2_sys::LV2_Handle, u32, *const c_void) -> lv2_sys::LV2_Worker_Status,
    >,
    end_run: Option<unsafe extern "C" fn(lv2_sys::LV2_Handle) -> lv2_sys::LV2_Worker_Status>,
    /// Preallocated to the ring's capacity so a response never allocates on the audio thread.
    scratch: Vec<u8>,
}

impl WorkerResponses {
    /// Hands every finished job's response to the plugin and closes the block.
    pub fn deliver(&mut self, instance: lv2_sys::LV2_Handle) {
        let (respond, scratch) = (self.respond, &mut self.scratch);
        self.receiver.drain(|_, _, parts| {
            scratch.clear();
            if parts[0].len() + parts[1].len() > scratch.capacity() {
                return;
            }
            scratch.extend_from_slice(parts[0]);
            scratch.extend_from_slice(parts[1]);
            if let (Some(respond), Ok(size)) = (respond, u32::try_from(scratch.len())) {
                // SAFETY: Called in the audio context right after `run`, as the worker
                // extension requires, with a contiguous copy of the response.
                unsafe { respond(instance, size, scratch.as_ptr().cast()) };
            }
        });
        if let Some(end_run) = self.end_run {
            // SAFETY: As above; this tells the plugin all responses of this block are in.
            unsafe { end_run(instance) };
        }
    }
}

struct Shared {
    stop: AtomicBool,
    /// Held while a job runs, so state operations can keep jobs out.
    busy: Mutex<()>,
}

/// The thread that runs one realtime instance's jobs. Dropping it finishes the job in flight
/// and joins the thread, which must happen before the plugin instance is freed.
pub(crate) struct WorkerThread {
    shared: Arc<Shared>,
    thread: Option<JoinHandle<()>>,
}

impl WorkerThread {
    fn spawn(
        work: Work,
        mut requests: AtomReceiver,
        mut responses: AtomSender,
    ) -> Result<Self, HostError> {
        let shared = Arc::new(Shared {
            stop: AtomicBool::new(false),
            busy: Mutex::new(()),
        });
        let worker = shared.clone();
        let thread = std::thread::Builder::new()
            .name("lv2-worker".into())
            .spawn(move || {
                let mut scratch = Vec::new();
                loop {
                    requests.drain(|_, _, parts| {
                        scratch.clear();
                        scratch.extend_from_slice(parts[0]);
                        scratch.extend_from_slice(parts[1]);
                        let Ok(size) = u32::try_from(scratch.len()) else {
                            return;
                        };
                        let _busy = worker.busy.lock().unwrap_or_else(PoisonError::into_inner);
                        // SAFETY: The instance outlives this thread, `work` may run beside
                        // `run`, and this thread runs one job at a time from its own copy.
                        unsafe { work.run(&mut responses, size, scratch.as_ptr().cast()) };
                    });
                    if worker.stop.load(Ordering::Acquire) {
                        break;
                    }
                    std::thread::park_timeout(IDLE_WAIT);
                }
            })?;
        Ok(Self {
            shared,
            thread: Some(thread),
        })
    }

    fn handle(&self) -> Thread {
        self.thread
            .as_ref()
            .map_or_else(std::thread::current, |thread| thread.thread().clone())
    }

    /// Keeps the worker from starting a job until the guard is dropped, waiting for one that
    /// is already running. State save and restore must not overlap `work`.
    pub fn exclude(&self) -> MutexGuard<'_, ()> {
        self.shared
            .busy
            .lock()
            .unwrap_or_else(PoisonError::into_inner)
    }
}

impl Drop for WorkerThread {
    fn drop(&mut self) {
        self.shared.stop.store(true, Ordering::Release);
        if let Some(thread) = self.thread.take() {
            thread.thread().unpark();
            if thread.join().is_err() {
                log::error!("LV2 worker thread panicked");
            }
        }
    }
}

#[cfg(test)]
#[allow(clippy::unwrap_used, reason = "test fixtures must be creatable")]
mod tests {
    use super::*;
    use std::sync::atomic::AtomicU32;

    static JOBS: AtomicU32 = AtomicU32::new(0);
    static RESPONSES: AtomicU32 = AtomicU32::new(0);
    static BLOCKS: AtomicU32 = AtomicU32::new(0);

    /// Doubles the request's first byte and sends it back.
    unsafe extern "C" fn work(
        _instance: lv2_sys::LV2_Handle,
        respond: lv2_sys::LV2_Worker_Respond_Function,
        handle: lv2_sys::LV2_Worker_Respond_Handle,
        size: u32,
        data: *const c_void,
    ) -> lv2_sys::LV2_Worker_Status {
        assert_eq!(size, 1);
        JOBS.fetch_add(1, Ordering::SeqCst);
        // SAFETY: The host passes the one request byte queued by the test.
        let reply = [unsafe { data.cast::<u8>().read() } * 2];
        // SAFETY: The host's respond function accepts one readable byte.
        unsafe { respond.unwrap()(handle, 1, reply.as_ptr().cast()) }
    }

    unsafe extern "C" fn work_response(
        _instance: lv2_sys::LV2_Handle,
        size: u32,
        body: *const c_void,
    ) -> lv2_sys::LV2_Worker_Status {
        assert_eq!(size, 1);
        // SAFETY: The host passes the one response byte the job produced.
        RESPONSES.fetch_add(
            u32::from(unsafe { body.cast::<u8>().read() }),
            Ordering::SeqCst,
        );
        SUCCESS
    }

    unsafe extern "C" fn end_run(_instance: lv2_sys::LV2_Handle) -> lv2_sys::LV2_Worker_Status {
        BLOCKS.fetch_add(1, Ordering::SeqCst);
        SUCCESS
    }

    fn schedule(port: &WorkerPort, byte: u8) -> lv2_sys::LV2_Worker_Status {
        let schedule = port.record.schedule_work.unwrap();
        // SAFETY: The record's handle is the port's own route, and one byte is readable.
        unsafe { schedule(port.record.handle, 1, std::ptr::from_ref(&byte).cast()) }
    }

    #[test]
    fn jobs_run_on_the_worker_in_realtime_and_inline_offline() {
        let interface = lv2_sys::LV2_Worker_Interface {
            work: Some(work),
            work_response: Some(work_response),
            end_run: Some(end_run),
        };
        let mut detached = WorkerPort::new();
        assert_eq!(schedule(&detached, 1), UNKNOWN);

        // Offline: the job has already run when `schedule_work` returns.
        let (mut responses, thread) = detached
            .attach(&interface, std::ptr::null_mut(), true)
            .unwrap();
        assert!(thread.is_none());
        let jobs = JOBS.load(Ordering::SeqCst);
        assert_eq!(schedule(&detached, 3), SUCCESS);
        assert_eq!(JOBS.load(Ordering::SeqCst), jobs + 1);
        responses.deliver(std::ptr::null_mut());
        assert_eq!(RESPONSES.swap(0, Ordering::SeqCst), 6);
        assert_eq!(BLOCKS.swap(0, Ordering::SeqCst), 1);

        // Realtime: the job runs on the worker thread and its response arrives with a later
        // block.
        let mut port = WorkerPort::new();
        let (mut responses, thread) = port
            .attach(&interface, std::ptr::null_mut(), false)
            .unwrap();
        let thread = thread.unwrap();
        assert_eq!(schedule(&port, 5), SUCCESS);
        let deadline = std::time::Instant::now() + Duration::from_secs(5);
        while RESPONSES.load(Ordering::SeqCst) == 0 {
            assert!(
                std::time::Instant::now() < deadline,
                "worker never responded"
            );
            responses.deliver(std::ptr::null_mut());
            std::thread::sleep(Duration::from_millis(1));
        }
        assert_eq!(RESPONSES.swap(0, Ordering::SeqCst), 10);
        // A held exclusion keeps the next job from starting.
        let excluded = thread.exclude();
        let jobs = JOBS.load(Ordering::SeqCst);
        assert_eq!(schedule(&port, 7), SUCCESS);
        std::thread::sleep(Duration::from_millis(50));
        assert_eq!(JOBS.load(Ordering::SeqCst), jobs);
        drop(excluded);
        // Dropping the thread finishes the queued job first.
        drop(thread);
        assert_eq!(JOBS.load(Ordering::SeqCst), jobs + 1);
    }
}
