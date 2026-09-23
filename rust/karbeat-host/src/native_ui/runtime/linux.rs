use std::{
    ffi::{c_int, c_uint, c_void},
    sync::{
        Arc,
        atomic::{AtomicBool, Ordering},
    },
    time::Duration,
};

use glib::{ControlFlow, translate::FromGlib};

use super::{
    super::{NativeUiError, NativeUiWakeHandle},
    common::{self, NativeUiControlFlow},
};

static DRAIN_SCHEDULED: AtomicBool = AtomicBool::new(false);

/// GLib wake handle that coalesces scheduling of the bounded UI task drain.
#[derive(Debug, Clone, Copy, Default)]
pub struct GlibWakeHandle;

impl NativeUiWakeHandle for GlibWakeHandle {
    fn wake(&self) -> Result<(), NativeUiError> {
        wake_ui_owner()
    }
}

pub(super) fn initialize_dispatcher() -> Result<(), NativeUiError> {
    schedule_drain();
    Ok(())
}

pub(super) fn wake_ui_owner() -> Result<(), NativeUiError> {
    schedule_drain();
    Ok(())
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
    if common::bind_owner_thread().is_err() {
        return;
    }
    if common::drain_owner_tasks() {
        schedule_drain();
    }
}

/// Opaque registration identifier for a recurring native UI interval.
pub type NativeUiInterval = glib::SourceId;

/// Installs a recurring GLib timeout callback on the native UI owner.
pub fn install_ui_interval(
    interval: Duration,
    mut callback: impl FnMut() -> NativeUiControlFlow + 'static,
) -> Result<NativeUiInterval, NativeUiError> {
    if !super::common::NativeUiDispatcher::is_owner_thread() {
        return Err(NativeUiError::WrongThread);
    }
    Ok(glib::timeout_add_local(interval, move || {
        match callback() {
            NativeUiControlFlow::Continue => ControlFlow::Continue,
            NativeUiControlFlow::Break => ControlFlow::Break,
        }
    }))
}

/// RAII registration for a Unix file descriptor watched by the GLib UI loop.
pub struct UiFdSource {
    source_id: Option<glib::SourceId>,
    active: Arc<AtomicBool>,
}

impl Drop for UiFdSource {
    fn drop(&mut self) {
        if self.active.swap(false, Ordering::AcqRel)
            && let Some(source_id) = self.source_id.take()
        {
            source_id.remove();
        }
    }
}

/// Registers a Unix file descriptor with the GLib native UI loop.
pub fn install_ui_fd_source(
    fd: c_int,
    mut callback: impl FnMut() -> NativeUiControlFlow + 'static,
) -> Result<UiFdSource, NativeUiError> {
    let active = Arc::new(AtomicBool::new(true));
    let callback_active = active.clone();
    let callback: Box<dyn FnMut() -> NativeUiControlFlow> = Box::new(move || {
        let result = callback();
        if result == NativeUiControlFlow::Break {
            callback_active.store(false, Ordering::Release);
        }
        result
    });
    let callback = Box::new(callback);
    let callback_ptr = Box::into_raw(callback);
    // SAFETY: callback_ptr remains owned by the GLib source until its destroy notifier runs.
    let source_id = unsafe {
        g_unix_fd_add_full(
            0,
            fd,
            G_IO_IN | G_IO_ERR | G_IO_HUP,
            Some(run_fd_source),
            callback_ptr.cast(),
            Some(drop_fd_source),
        )
    };
    if source_id == 0 {
        // SAFETY: GLib did not take ownership when source creation failed.
        drop(unsafe { Box::from_raw(callback_ptr) });
        return Err(NativeUiError::RuntimeInitializationFailed(
            "failed to register a GLib Unix FD source".into(),
        ));
    }
    Ok(UiFdSource {
        // SAFETY: zero was rejected above.
        source_id: Some(unsafe { glib::SourceId::from_glib(source_id) }),
        active,
    })
}

const G_IO_IN: c_uint = 1;
const G_IO_ERR: c_uint = 8;
const G_IO_HUP: c_uint = 16;

type GlibUnixFdCallback = unsafe extern "C" fn(c_int, c_uint, *mut c_void) -> c_int;
type GlibDestroyNotify = unsafe extern "C" fn(*mut c_void);

unsafe extern "C" {
    fn g_unix_fd_add_full(
        priority: c_int,
        fd: c_int,
        condition: c_uint,
        function: Option<GlibUnixFdCallback>,
        user_data: *mut c_void,
        notify: Option<GlibDestroyNotify>,
    ) -> c_uint;
}

unsafe extern "C" fn run_fd_source(_: c_int, _: c_uint, user_data: *mut c_void) -> c_int {
    // SAFETY: install_ui_fd_source created this exact double-boxed callback allocation.
    let callback = unsafe { &mut *user_data.cast::<Box<dyn FnMut() -> NativeUiControlFlow>>() };
    i32::from(callback() == NativeUiControlFlow::Continue)
}

unsafe extern "C" fn drop_fd_source(user_data: *mut c_void) {
    // SAFETY: this is the unique allocation transferred to GLib.
    drop(unsafe { Box::from_raw(user_data.cast::<Box<dyn FnMut() -> NativeUiControlFlow>>()) });
}

#[cfg(test)]
#[allow(
    clippy::unwrap_used,
    clippy::panic,
    reason = "runtime test fixtures fail on unexpected results"
)]
mod tests {
    use std::sync::{
        Arc,
        atomic::{AtomicUsize, Ordering},
    };

    use super::super::common::NativeUiDispatcher;

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
        let request = dispatcher.dispatch(move || {
            task_calls.fetch_add(1, Ordering::Relaxed);
            Ok(())
        });
        drop(request);
        iterate_until(NativeUiDispatcher::is_owner_thread);
        assert_eq!(calls.load(Ordering::Relaxed), 0);

        let (ready, queued) = std::sync::mpsc::sync_channel(1);
        let batch_calls = Arc::new(AtomicUsize::new(0));
        let worker_calls = batch_calls.clone();
        let worker = std::thread::spawn(move || {
            let dispatcher = NativeUiDispatcher::initialize().unwrap();
            let mut requests = Vec::new();
            for _ in 0..9 {
                let calls = worker_calls.clone();
                requests.push(Box::pin(dispatcher.dispatch(move || {
                    calls.fetch_add(1, Ordering::Relaxed);
                    Ok(())
                })));
            }
            for request in &mut requests {
                assert!(
                    futures_lite::future::block_on(futures_lite::future::poll_once(request))
                        .is_none()
                );
            }
            ready.send(()).unwrap();
            for request in requests {
                futures_lite::future::block_on(request).unwrap();
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
