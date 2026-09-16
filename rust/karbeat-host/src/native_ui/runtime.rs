use std::{
    cell::{Cell, RefCell},
    sync::{
        Arc, Mutex, OnceLock,
        atomic::{AtomicBool, AtomicU8, Ordering},
        mpsc::{self, Receiver, SyncSender, TryRecvError, TrySendError},
    },
    time::Duration,
};

use glib::ControlFlow;

use super::{NativeUiError, NativeUiWakeHandle};

const REQUEST_QUEUE_CAPACITY: usize = 128;
const MAX_UI_TASKS_PER_TICK: usize = 4;
const REQUEST_PENDING: u8 = 0;
const REQUEST_STARTED: u8 = 1;
const REQUEST_CANCELLED: u8 = 2;

type UiTask = Box<dyn FnOnce() + Send>;

static TASK_SENDER: OnceLock<SyncSender<UiTask>> = OnceLock::new();
static TASK_RECEIVER: OnceLock<Mutex<Option<Receiver<UiTask>>>> = OnceLock::new();
static DRAIN_SCHEDULED: AtomicBool = AtomicBool::new(false);

thread_local! {
    static UI_RECEIVER: RefCell<Option<Receiver<UiTask>>> = const { RefCell::new(None) };
    static IS_UI_OWNER: Cell<bool> = const { Cell::new(false) };
}

#[derive(Debug, Clone, Copy, Default)]
pub struct GlibWakeHandle;

impl NativeUiWakeHandle for GlibWakeHandle {
    fn wake(&self) -> Result<(), NativeUiError> {
        schedule_drain();
        Ok(())
    }
}

#[derive(Debug, Clone, Copy, Default)]
pub struct NativeUiDispatcher;

impl NativeUiDispatcher {
    pub fn initialize() -> Result<Self, NativeUiError> {
        ensure_queue()?;
        schedule_drain();
        Ok(Self)
    }

    pub fn is_owner_thread() -> bool {
        IS_UI_OWNER.with(Cell::get)
    }

    pub fn dispatch<F, T>(&self, operation: F) -> Result<NativeUiRequest<T>, NativeUiError>
    where
        F: FnOnce() -> Result<T, NativeUiError> + Send + 'static,
        T: Send + 'static,
    {
        if Self::is_owner_thread() {
            return Err(NativeUiError::WrongThread);
        }
        let sender = ensure_queue()?;
        let status = Arc::new(AtomicU8::new(REQUEST_PENDING));
        let task_status = status.clone();
        let (reply, response) = mpsc::sync_channel(1);
        let task = Box::new(move || {
            if task_status
                .compare_exchange(
                    REQUEST_PENDING,
                    REQUEST_STARTED,
                    Ordering::AcqRel,
                    Ordering::Acquire,
                )
                .is_err()
            {
                return;
            }
            drop(reply.try_send(operation()));
        });
        match sender.try_send(task) {
            Ok(()) => GlibWakeHandle.wake()?,
            Err(TrySendError::Full(_)) => return Err(NativeUiError::QueueFull),
            Err(TrySendError::Disconnected(_)) => {
                return Err(NativeUiError::RuntimeUnavailable);
            }
        }
        Ok(NativeUiRequest { status, response })
    }
}

pub struct NativeUiRequest<T> {
    status: Arc<AtomicU8>,
    response: Receiver<Result<T, NativeUiError>>,
}

impl<T> NativeUiRequest<T> {
    pub fn cancel(&self) -> bool {
        self.status
            .compare_exchange(
                REQUEST_PENDING,
                REQUEST_CANCELLED,
                Ordering::AcqRel,
                Ordering::Acquire,
            )
            .is_ok()
    }

    pub fn wait(self, timeout: Duration) -> Result<T, NativeUiError> {
        if NativeUiDispatcher::is_owner_thread() {
            return Err(NativeUiError::WrongThread);
        }
        match self.response.recv_timeout(timeout) {
            Ok(result) => result,
            Err(mpsc::RecvTimeoutError::Timeout) => {
                if self.cancel() || self.status.load(Ordering::Acquire) == REQUEST_CANCELLED {
                    Err(NativeUiError::RequestCancelled)
                } else {
                    self.response
                        .recv()
                        .map_err(|_| NativeUiError::RequestDisconnected)?
                }
            }
            Err(mpsc::RecvTimeoutError::Disconnected) => Err(NativeUiError::RequestDisconnected),
        }
    }
}

impl<T> Drop for NativeUiRequest<T> {
    fn drop(&mut self) {
        self.cancel();
    }
}

fn ensure_queue() -> Result<&'static SyncSender<UiTask>, NativeUiError> {
    if let Some(sender) = TASK_SENDER.get() {
        return Ok(sender);
    }
    let (sender, receiver) = mpsc::sync_channel(REQUEST_QUEUE_CAPACITY);
    TASK_RECEIVER
        .set(Mutex::new(Some(receiver)))
        .map_err(|_| NativeUiError::RuntimeInitializationFailed("receiver already set".into()))?;
    TASK_SENDER
        .set(sender)
        .map_err(|_| NativeUiError::RuntimeInitializationFailed("sender already set".into()))?;
    TASK_SENDER.get().ok_or(NativeUiError::RuntimeUnavailable)
}

fn schedule_drain() {
    if DRAIN_SCHEDULED
        .compare_exchange(false, true, Ordering::AcqRel, Ordering::Acquire)
        .is_err()
    {
        return;
    }
    glib::idle_add_once(drain_on_ui_owner);
}

fn drain_on_ui_owner() {
    DRAIN_SCHEDULED.store(false, Ordering::Release);
    IS_UI_OWNER.with(|owner| owner.set(true));
    UI_RECEIVER.with(|local| {
        if local.borrow().is_none()
            && let Some(receiver) = TASK_RECEIVER
                .get()
                .and_then(|receiver| receiver.lock().ok()?.take())
        {
            *local.borrow_mut() = Some(receiver);
        }
    });
    let mut processed = 0;
    UI_RECEIVER.with(|local| {
        let mut local = local.borrow_mut();
        let Some(receiver) = local.as_mut() else {
            return;
        };
        while processed < MAX_UI_TASKS_PER_TICK {
            match receiver.try_recv() {
                Ok(task) => {
                    processed += 1;
                    task();
                }
                Err(TryRecvError::Empty | TryRecvError::Disconnected) => break,
            }
        }
    });
    if processed == MAX_UI_TASKS_PER_TICK {
        schedule_drain();
    }
}

pub fn install_ui_interval(
    interval: Duration,
    callback: impl FnMut() -> ControlFlow + 'static,
) -> Result<glib::SourceId, NativeUiError> {
    if !NativeUiDispatcher::is_owner_thread() {
        return Err(NativeUiError::WrongThread);
    }
    Ok(glib::timeout_add_local(interval, callback))
}

#[cfg(test)]
mod tests {
    use std::sync::{
        Arc,
        atomic::{AtomicUsize, Ordering},
    };

    use super::*;

    fn iterate_until(condition: impl Fn() -> bool) {
        let context = glib::MainContext::default();
        for _ in 0..64 {
            if condition() {
                return;
            }
            context.iteration(false);
        }
        assert!(condition());
    }

    #[test]
    fn cancellation_and_bounded_fairness_are_enforced() {
        let dispatcher = NativeUiDispatcher::initialize().unwrap();
        let calls = Arc::new(AtomicUsize::new(0));
        let task_calls = calls.clone();
        let request = dispatcher
            .dispatch(move || {
                task_calls.fetch_add(1, Ordering::Relaxed);
                Ok(())
            })
            .unwrap();
        assert!(matches!(
            request.wait(Duration::ZERO),
            Err(NativeUiError::RequestCancelled)
        ));
        iterate_until(NativeUiDispatcher::is_owner_thread);
        assert_eq!(calls.load(Ordering::Relaxed), 0);

        let (ready, queued) = mpsc::sync_channel(1);
        let batch_calls = Arc::new(AtomicUsize::new(0));
        let worker_calls = batch_calls.clone();
        let worker = std::thread::spawn(move || {
            let dispatcher = NativeUiDispatcher::initialize().unwrap();
            let mut requests = Vec::new();
            for _ in 0..9 {
                let calls = worker_calls.clone();
                requests.push(
                    dispatcher
                        .dispatch(move || {
                            calls.fetch_add(1, Ordering::Relaxed);
                            Ok(())
                        })
                        .unwrap(),
                );
            }
            ready.send(()).unwrap();
            for request in requests {
                request.wait(Duration::from_secs(2)).unwrap();
            }
        });
        queued.recv().unwrap();
        let context = glib::MainContext::default();
        context.iteration(false);
        assert_eq!(batch_calls.load(Ordering::Relaxed), 4);
        context.iteration(false);
        assert_eq!(batch_calls.load(Ordering::Relaxed), 8);
        context.iteration(false);
        assert_eq!(batch_calls.load(Ordering::Relaxed), 9);
        worker.join().unwrap();
    }
}
