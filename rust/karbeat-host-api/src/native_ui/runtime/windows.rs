use std::{
    cell::{Cell, RefCell},
    collections::BTreeMap,
    ffi::c_void,
    marker::PhantomData,
    ptr,
    rc::Rc,
    sync::atomic::{AtomicBool, AtomicUsize, Ordering},
    thread::ThreadId,
    time::Duration,
};

use windows_sys::Win32::{
    Foundation::{GetLastError, HWND, LPARAM, LRESULT, WPARAM},
    System::{
        Com::{COINIT_APARTMENTTHREADED, CoInitializeEx, CoUninitialize},
        LibraryLoader::GetModuleHandleW,
    },
    UI::WindowsAndMessaging::{
        CreateWindowExW, DefWindowProcW, DestroyWindow, DispatchMessageW, GetMessageW,
        HWND_MESSAGE, KillTimer, MSG, PostMessageW, PostQuitMessage, RegisterClassW, SetTimer,
        TranslateMessage, WM_APP, WM_TIMER, WNDCLASSW,
    },
};

use super::{
    super::{NativeUiError, NativeUiWakeHandle},
    common::{self, NativeUiControlFlow},
};

const WAKE_MESSAGE: u32 = WM_APP + 0x321;
const SHUTDOWN_MESSAGE: u32 = WM_APP + 0x322;
const ERROR_CLASS_ALREADY_EXISTS: u32 = 1_410;
const DISPATCHER_CLASS: &[u16] = &[
    68, 105, 103, 105, 68, 65, 87, 46, 78, 97, 116, 105, 118, 101, 85, 105, 68, 105, 115, 112, 97,
    116, 99, 104, 101, 114, 0,
];

static DISPATCHER_HWND: AtomicUsize = AtomicUsize::new(0);
static WAKE_SCHEDULED: AtomicBool = AtomicBool::new(false);

thread_local! {
    static MAIN_STATE: RefCell<Option<WindowsMainState>> = const { RefCell::new(None) };
    static INTERVALS: RefCell<BTreeMap<usize, Box<dyn FnMut() -> NativeUiControlFlow>>> = RefCell::new(BTreeMap::new());
    static NEXT_TIMER_ID: Cell<usize> = const { Cell::new(1) };
}

struct WindowsMainState {
    dispatcher: HWND,
    _com: WindowsStaGuard,
}

/// RAII ownership of a COM single-threaded apartment on the creating thread.
pub struct WindowsStaGuard {
    owner: ThreadId,
    _not_send: PhantomData<Rc<()>>,
}

impl WindowsStaGuard {
    /// Initializes COM as STA and returns an owner-thread guard.
    pub fn initialize() -> Result<Self, NativeUiError> {
        let apartment = u32::try_from(COINIT_APARTMENTTHREADED).map_err(|_| {
            NativeUiError::RuntimeInitializationFailed("invalid STA initialization flag".into())
        })?;
        // SAFETY: COM initialization is paired with this guard's same-thread Drop.
        let result = unsafe { CoInitializeEx(ptr::null(), apartment) };
        if result < 0 {
            return Err(NativeUiError::RuntimeInitializationFailed(format!(
                "CoInitializeEx(COINIT_APARTMENTTHREADED) failed with HRESULT {result:#010x}"
            )));
        }
        Ok(Self {
            owner: std::thread::current().id(),
            _not_send: PhantomData,
        })
    }
}

impl Drop for WindowsStaGuard {
    fn drop(&mut self) {
        if self.owner == std::thread::current().id() {
            // SAFETY: this balances the successful initialization on the same thread.
            unsafe { CoUninitialize() };
        } else {
            log::error!("Windows STA guard reached Drop on a non-owner thread");
        }
    }
}

/// Non-blocking Win32 wake handle for the process main STA thread.
#[derive(Debug, Clone, Copy, Default)]
pub struct Win32WakeHandle;

impl NativeUiWakeHandle for Win32WakeHandle {
    fn wake(&self) -> Result<(), NativeUiError> {
        wake_ui_owner()
    }
}

/// Initializes COM, the bounded dispatcher, and its hidden HWND on the current main thread.
pub fn initialize_windows_main_thread() -> Result<(), NativeUiError> {
    if MAIN_STATE.with(|state| state.borrow().is_some()) {
        return Ok(());
    }
    common::ensure_queue()?;
    common::bind_owner_thread()?;
    let com = WindowsStaGuard::initialize()?;
    let dispatcher = create_dispatcher_window()?;
    DISPATCHER_HWND.store(dispatcher.addr(), Ordering::Release);
    MAIN_STATE.with(|state| {
        *state.borrow_mut() = Some(WindowsMainState {
            dispatcher,
            _com: com,
        });
    });
    Ok(())
}

pub(super) fn initialize_dispatcher() -> Result<(), NativeUiError> {
    if DISPATCHER_HWND.load(Ordering::Acquire) == 0 {
        return Err(NativeUiError::RuntimeUnavailable);
    }
    Ok(())
}

pub(super) fn wake_ui_owner() -> Result<(), NativeUiError> {
    let address = DISPATCHER_HWND.load(Ordering::Acquire);
    if address == 0 {
        return Err(NativeUiError::RuntimeUnavailable);
    }
    if WAKE_SCHEDULED
        .compare_exchange(false, true, Ordering::AcqRel, Ordering::Acquire)
        .is_err()
    {
        return Ok(());
    }
    let dispatcher = ptr::with_exposed_provenance_mut::<c_void>(address);
    // SAFETY: dispatcher is the live message-only window published by initialization.
    if unsafe { PostMessageW(dispatcher, WAKE_MESSAGE, 0, 0) } == 0 {
        WAKE_SCHEDULED.store(false, Ordering::Release);
        return Err(NativeUiError::RuntimeUnavailable);
    }
    Ok(())
}

/// Opaque identifier for an installed Win32 `WM_TIMER` callback.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct NativeUiInterval(usize);

/// Installs a recurring `WM_TIMER` callback on the native owner.
pub fn install_ui_interval(
    interval: Duration,
    callback: impl FnMut() -> NativeUiControlFlow + 'static,
) -> Result<NativeUiInterval, NativeUiError> {
    if !common::NativeUiDispatcher::is_owner_thread() {
        return Err(NativeUiError::WrongThread);
    }
    let dispatcher = current_dispatcher()?;
    let milliseconds = u32::try_from(interval.as_millis())
        .unwrap_or(u32::MAX)
        .max(1);
    let id = NEXT_TIMER_ID.with(|next| {
        let id = next.get();
        next.set(id.saturating_add(1).max(1));
        id
    });
    INTERVALS.with(|intervals| {
        intervals.borrow_mut().insert(id, Box::new(callback));
    });
    // SAFETY: dispatcher belongs to this thread; callbacks are routed through its WndProc.
    if unsafe { SetTimer(dispatcher, id, milliseconds, None) } == 0 {
        INTERVALS.with(|intervals| drop(intervals.borrow_mut().remove(&id)));
        return Err(last_error("SetTimer"));
    }
    Ok(NativeUiInterval(id))
}

/// Runs the process-wide Win32 message loop on the initialized main STA thread.
pub fn run_windows_main_loop() -> Result<i32, NativeUiError> {
    if !common::NativeUiDispatcher::is_owner_thread()
        || MAIN_STATE.with(|state| state.borrow().is_none())
    {
        return Err(NativeUiError::WrongThread);
    }
    let mut message = MSG::default();
    let exit_code = loop {
        // SAFETY: message is writable for the duration of the blocking Win32 call.
        let result = unsafe { GetMessageW(&raw mut message, ptr::null_mut(), 0, 0) };
        if result == -1 {
            shutdown_windows_main_thread()?;
            return Err(last_error("GetMessageW"));
        }
        if result == 0 {
            break i32::try_from(message.wParam).unwrap_or(1);
        }
        // SAFETY: GetMessageW produced an initialized message for normal Win32 dispatch.
        unsafe { TranslateMessage(&raw const message) };
        // SAFETY: GetMessageW produced an initialized message for normal Win32 dispatch.
        unsafe { DispatchMessageW(&raw const message) };
    };
    shutdown_windows_main_thread()?;
    Ok(exit_code)
}

/// Posts a private shutdown request to the Rust-owned process loop.
pub fn request_windows_main_loop_shutdown() -> Result<(), NativeUiError> {
    let dispatcher = current_dispatcher()?;
    // SAFETY: dispatcher is a live process-local HWND.
    if unsafe { PostMessageW(dispatcher, SHUTDOWN_MESSAGE, 0, 0) } == 0 {
        Err(last_error("PostMessageW(shutdown)"))
    } else {
        Ok(())
    }
}

/// Releases the hidden dispatcher and main-thread COM apartment before loop startup failures.
pub fn shutdown_windows_main_thread() -> Result<(), NativeUiError> {
    if !common::NativeUiDispatcher::is_owner_thread() {
        return Err(NativeUiError::WrongThread);
    }
    let state = MAIN_STATE.with(|state| state.borrow_mut().take());
    let Some(state) = state else {
        return Ok(());
    };
    DISPATCHER_HWND.store(0, Ordering::Release);
    WAKE_SCHEDULED.store(false, Ordering::Release);
    INTERVALS.with(|intervals| {
        for id in intervals.borrow().keys().copied().collect::<Vec<_>>() {
            // SAFETY: timers belong to the dispatcher and current owner thread.
            unsafe { KillTimer(state.dispatcher, id) };
        }
        intervals.borrow_mut().clear();
    });
    // SAFETY: the message-only dispatcher is destroyed on its creating thread.
    if unsafe { DestroyWindow(state.dispatcher) } == 0 {
        return Err(last_error("DestroyWindow(dispatcher)"));
    }
    drop(state);
    Ok(())
}

fn create_dispatcher_window() -> Result<HWND, NativeUiError> {
    // SAFETY: null requests the current executable module.
    let instance = unsafe { GetModuleHandleW(ptr::null()) };
    if instance.is_null() {
        return Err(last_error("GetModuleHandleW"));
    }
    let class = WNDCLASSW {
        lpfnWndProc: Some(dispatcher_window_proc),
        hInstance: instance,
        lpszClassName: DISPATCHER_CLASS.as_ptr(),
        ..WNDCLASSW::default()
    };
    // SAFETY: class fields remain valid for the registration call.
    let atom = unsafe { RegisterClassW(&raw const class) };
    // SAFETY: immediately reads this thread's last-error value after RegisterClassW.
    if atom == 0 && unsafe { GetLastError() } != ERROR_CLASS_ALREADY_EXISTS {
        return Err(last_error("RegisterClassW(dispatcher)"));
    }
    // SAFETY: the registered class and module are valid; no create parameter is required.
    let window = unsafe {
        CreateWindowExW(
            0,
            DISPATCHER_CLASS.as_ptr(),
            DISPATCHER_CLASS.as_ptr(),
            0,
            0,
            0,
            0,
            0,
            HWND_MESSAGE,
            ptr::null_mut(),
            instance,
            ptr::null(),
        )
    };
    if window.is_null() {
        Err(last_error("CreateWindowExW(dispatcher)"))
    } else {
        Ok(window)
    }
}

fn current_dispatcher() -> Result<HWND, NativeUiError> {
    let address = DISPATCHER_HWND.load(Ordering::Acquire);
    if address == 0 {
        Err(NativeUiError::RuntimeUnavailable)
    } else {
        Ok(ptr::with_exposed_provenance_mut::<c_void>(address))
    }
}

unsafe extern "system" fn dispatcher_window_proc(
    window: HWND,
    message: u32,
    wparam: WPARAM,
    lparam: LPARAM,
) -> LRESULT {
    match message {
        WAKE_MESSAGE => {
            WAKE_SCHEDULED.store(false, Ordering::Release);
            if common::drain_owner_tasks() {
                drop(wake_ui_owner());
            }
            0
        }
        WM_TIMER => {
            let mut remove = false;
            INTERVALS.with(|intervals| {
                if let Some(callback) = intervals.borrow_mut().get_mut(&wparam) {
                    remove = callback() == NativeUiControlFlow::Break;
                }
            });
            if remove {
                // SAFETY: this timer belongs to the dispatcher receiving the message.
                unsafe { KillTimer(window, wparam) };
                INTERVALS.with(|intervals| drop(intervals.borrow_mut().remove(&wparam)));
            }
            0
        }
        SHUTDOWN_MESSAGE => {
            // SAFETY: the Rust-owned loop observes this thread-local quit transition.
            unsafe { PostQuitMessage(0) };
            0
        }
        _ => {
            // SAFETY: unhandled messages retain the default Win32 behavior.
            unsafe { DefWindowProcW(window, message, wparam, lparam) }
        }
    }
}

fn last_error(operation: &'static str) -> NativeUiError {
    // SAFETY: obtains this thread's Win32 last-error code.
    let code = unsafe { GetLastError() };
    NativeUiError::NativeOperationFailed(format!("{operation} failed with Win32 error {code}"))
}

#[cfg(test)]
#[allow(
    clippy::unwrap_used,
    reason = "Win32 runtime tests fail immediately when a platform invariant is broken"
)]
mod tests {
    use std::num::NonZeroU64;

    use crate::native_ui::{
        NativeSurfaceKind, NativeSurfacePreference, NativeUiDispatcher, NativeUiPlatform,
        NativeWindow, NativeWindowConstraints, NativeWindowId, NativeWindowSize, NativeWindowSpec,
        SystemNativeUi,
    };

    use super::{
        initialize_windows_main_thread, request_windows_main_loop_shutdown, run_windows_main_loop,
    };

    #[test]
    fn main_loop_dispatches_on_owner_and_hosts_a_win32_window() {
        initialize_windows_main_thread().unwrap();
        let (mut native_ui, _) = SystemNativeUi::initialize().unwrap();
        let initial_size = NativeWindowSize::new(320, 200).unwrap();
        let mut window = native_ui
            .create_window(
                NativeWindowId::new(NonZeroU64::MIN),
                &NativeWindowSpec {
                    title: "DigiDAW — Win32 test",
                    initial_size,
                    constraints: NativeWindowConstraints::resizable(),
                    initially_visible: false,
                    preferred_surface: NativeSurfacePreference::Require(NativeSurfaceKind::Win32),
                },
            )
            .unwrap();
        assert_eq!(window.surface_kind(), NativeSurfaceKind::Win32);
        assert_eq!(
            window.parent_handle().unwrap().kind,
            NativeSurfaceKind::Win32
        );
        window.set_title("DigiDAW — ✓").unwrap();
        let resized = NativeWindowSize::new(400, 240).unwrap();
        window.set_client_size(resized).unwrap();
        assert_eq!(window.metrics().unwrap().client_size, resized);
        window
            .set_constraints(NativeWindowConstraints::fixed(resized))
            .unwrap();
        window.show().unwrap();
        window.hide().unwrap();
        drop(window);

        let owner = std::thread::current().id();
        let worker = std::thread::spawn(move || {
            let dispatcher = NativeUiDispatcher::initialize().unwrap();
            futures_lite::future::block_on(dispatcher.dispatch(move || {
                let ran_on_owner = std::thread::current().id() == owner;
                request_windows_main_loop_shutdown()?;
                Ok(ran_on_owner)
            }))
            .unwrap()
        });

        assert_eq!(run_windows_main_loop().unwrap(), 0);
        assert!(worker.join().unwrap());
    }
}
