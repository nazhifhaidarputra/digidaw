use std::{
    cell::{Cell, RefCell},
    sync::{Mutex, OnceLock},
};

use async_executor::LocalExecutor;
use tokio::sync::{mpsc, oneshot};

use super::super::NativeUiError;

pub(super) const REQUEST_QUEUE_CAPACITY: usize = 128;
pub(super) const MAX_UI_TASKS_PER_TICK: usize = 4;

type UiTask = Box<dyn FnOnce(&LocalExecutor<'static>) + Send>;

static TASK_SENDER: OnceLock<mpsc::Sender<UiTask>> = OnceLock::new();
static TASK_RECEIVER: OnceLock<Mutex<Option<mpsc::Receiver<UiTask>>>> = OnceLock::new();

thread_local! {
    static UI_RECEIVER: RefCell<Option<mpsc::Receiver<UiTask>>> = const { RefCell::new(None) };
    static UI_EXECUTOR: LocalExecutor<'static> = LocalExecutor::new();
    static IS_UI_OWNER: Cell<bool> = const { Cell::new(false) };
}

/// Platform-neutral continuation result for native UI interval callbacks.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum NativeUiControlFlow {
    /// Keep the interval registered.
    Continue,
    /// Remove the interval after the current callback.
    Break,
}

/// Cross-thread dispatcher for closures that must execute on the native UI owner.
#[derive(Debug, Clone, Copy, Default)]
pub struct NativeUiDispatcher;

impl NativeUiDispatcher {
    /// Ensures the bounded process queue exists and connects it to the OS event-loop adapter.
    pub fn initialize() -> Result<Self, NativeUiError> {
        ensure_queue()?;
        super::initialize_dispatcher()?;
        Ok(Self)
    }

    /// Returns whether the current thread owns native UI objects.
    pub fn is_owner_thread() -> bool {
        IS_UI_OWNER.with(Cell::get)
    }

    /// Enqueues a closure and asynchronously receives its native-owner result.
    pub async fn dispatch<F, T>(&self, operation: F) -> Result<T, NativeUiError>
    where
        F: FnOnce() -> Result<T, NativeUiError> + Send + 'static,
        T: Send + 'static,
    {
        self.dispatch_async(move || async move { operation() })
            .await
    }

    /// Enqueues one non-`Send` future factory for execution on the native owner.
    pub async fn dispatch_async<F, Fut, T>(&self, operation: F) -> Result<T, NativeUiError>
    where
        F: FnOnce() -> Fut + Send + 'static,
        Fut: Future<Output = Result<T, NativeUiError>> + 'static,
        T: Send + 'static,
    {
        if Self::is_owner_thread() {
            return Err(NativeUiError::WrongThread);
        }
        let sender = ensure_queue()?;
        let (reply, response) = oneshot::channel();
        let task: UiTask = Box::new(move |executor| {
            if reply.is_closed() {
                return;
            }
            executor
                .spawn(async move {
                    let result = operation().await;
                    drop(reply.send(result));
                })
                .detach();
        });
        match sender.try_send(task) {
            Ok(()) => super::wake_ui_owner()?,
            Err(mpsc::error::TrySendError::Full(_)) => return Err(NativeUiError::QueueFull),
            Err(mpsc::error::TrySendError::Closed(_)) => {
                return Err(NativeUiError::RuntimeUnavailable);
            }
        }
        response
            .await
            .map_err(|_| NativeUiError::RequestDisconnected)?
    }
}

pub(super) fn ensure_queue() -> Result<&'static mpsc::Sender<UiTask>, NativeUiError> {
    if let Some(sender) = TASK_SENDER.get() {
        return Ok(sender);
    }
    let (sender, receiver) = mpsc::channel(REQUEST_QUEUE_CAPACITY);
    TASK_RECEIVER
        .set(Mutex::new(Some(receiver)))
        .map_err(|_| NativeUiError::RuntimeInitializationFailed("receiver already set".into()))?;
    TASK_SENDER
        .set(sender)
        .map_err(|_| NativeUiError::RuntimeInitializationFailed("sender already set".into()))?;
    TASK_SENDER.get().ok_or(NativeUiError::RuntimeUnavailable)
}

pub(super) fn bind_owner_thread() -> Result<(), NativeUiError> {
    if IS_UI_OWNER.with(Cell::get) {
        return Ok(());
    }
    let receiver = TASK_RECEIVER
        .get()
        .and_then(|receiver| receiver.lock().ok()?.take())
        .ok_or(NativeUiError::RuntimeUnavailable)?;
    UI_RECEIVER.with(|local| *local.borrow_mut() = Some(receiver));
    IS_UI_OWNER.with(|owner| owner.set(true));
    Ok(())
}

pub(super) fn drain_owner_tasks() -> bool {
    let mut processed = 0_usize;
    let mut queue_has_more = false;
    UI_RECEIVER.with(|local| {
        let mut local = local.borrow_mut();
        let Some(receiver) = local.as_mut() else {
            return;
        };
        while processed < MAX_UI_TASKS_PER_TICK {
            match receiver.try_recv() {
                Ok(task) => {
                    processed = processed.saturating_add(1);
                    UI_EXECUTOR.with(|executor| task(executor));
                }
                Err(mpsc::error::TryRecvError::Empty | mpsc::error::TryRecvError::Disconnected) => {
                    break;
                }
            }
        }
        queue_has_more = !receiver.is_empty();
    });

    let mut ticked = 0_usize;
    UI_EXECUTOR.with(|executor| {
        while ticked < MAX_UI_TASKS_PER_TICK && executor.try_tick() {
            ticked = ticked.saturating_add(1);
        }
    });
    queue_has_more || processed == MAX_UI_TASKS_PER_TICK || ticked == MAX_UI_TASKS_PER_TICK
}

/// Spawns one non-`Send` future on the native owner's local executor.
pub fn spawn_ui_local(future: impl Future<Output = ()> + 'static) -> Result<(), NativeUiError> {
    if !NativeUiDispatcher::is_owner_thread() {
        return Err(NativeUiError::WrongThread);
    }
    UI_EXECUTOR.with(|executor| executor.spawn(future).detach());
    super::wake_ui_owner()
}
