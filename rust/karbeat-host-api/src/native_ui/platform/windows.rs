use std::{
    cell::RefCell, collections::VecDeque, ffi::c_void, num::NonZeroIsize, ptr, thread::ThreadId,
};

use raw_window_handle::{RawWindowHandle, Win32WindowHandle};
use windows_sys::Win32::{
    Foundation::{GetLastError, HWND, LPARAM, LRESULT, RECT, WPARAM},
    System::LibraryLoader::GetModuleHandleW,
    UI::{
        HiDpi::{AdjustWindowRectExForDpi, GetDpiForWindow},
        Input::KeyboardAndMouse::SetFocus,
        WindowsAndMessaging::{
            CREATESTRUCTW, CW_USEDEFAULT, CreateWindowExW, DefWindowProcW, DestroyWindow,
            GWL_EXSTYLE, GWL_STYLE, GWLP_USERDATA, GetClientRect, GetWindowLongPtrW, MINMAXINFO,
            RegisterClassW, SW_HIDE, SW_SHOW, SWP_NOACTIVATE, SWP_NOMOVE, SWP_NOZORDER,
            SetForegroundWindow, SetWindowLongPtrW, SetWindowPos, SetWindowTextW, ShowWindow,
            WM_CLOSE, WM_DPICHANGED, WM_GETMINMAXINFO, WM_KILLFOCUS, WM_NCCREATE, WM_NCDESTROY,
            WM_SETFOCUS, WM_SIZE, WNDCLASSW, WS_CAPTION, WS_CLIPCHILDREN, WS_CLIPSIBLINGS,
            WS_MAXIMIZEBOX, WS_OVERLAPPED, WS_SYSMENU, WS_THICKFRAME,
        },
    },
};

use crate::native_ui::{
    NativeParentHandle, NativeSurfaceCapabilities, NativeSurfaceKind, NativeUiDispatcher,
    NativeUiError, NativeUiPlatform, NativeWindow, NativeWindowConstraints, NativeWindowEvent,
    NativeWindowId, NativeWindowMetrics, NativeWindowSize, NativeWindowSpec, Win32WakeHandle,
};

const ERROR_CLASS_ALREADY_EXISTS: u32 = 1_410;
const SWP_FRAMECHANGED: u32 = 0x0020;
const WINDOW_CLASS: &[u16] = &[
    68, 105, 103, 105, 68, 65, 87, 46, 86, 115, 116, 51, 69, 100, 105, 116, 111, 114, 72, 111, 115,
    116, 0,
];
const BASE_STYLE: u32 = WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU | WS_CLIPCHILDREN | WS_CLIPSIBLINGS;

thread_local! {
    static EVENTS: RefCell<VecDeque<NativeWindowEvent>> = const { RefCell::new(VecDeque::new()) };
}

/// Win32 native-window backend bound to the Rust-owned process main STA thread.
pub struct WindowsNativeUi {
    owner: ThreadId,
    instance: *mut c_void,
}

struct WindowContext {
    id: NativeWindowId,
    hwnd: HWND,
    constraints: NativeWindowConstraints,
}

/// Stable boxed context and HWND for a host-owned VST3 editor parent.
pub struct WindowsNativeWindow {
    context: Box<WindowContext>,
    owner: ThreadId,
}

impl WindowsNativeWindow {
    fn check_thread(&self) -> Result<(), NativeUiError> {
        if self.owner == std::thread::current().id() {
            Ok(())
        } else {
            Err(NativeUiError::WrongThread)
        }
    }

    fn hwnd(&self) -> Result<HWND, NativeUiError> {
        self.check_thread()?;
        if self.context.hwnd.is_null() {
            Err(NativeUiError::WindowDestroyed)
        } else {
            Ok(self.context.hwnd)
        }
    }
}

impl NativeWindow for WindowsNativeWindow {
    fn id(&self) -> NativeWindowId {
        self.context.id
    }

    fn surface_kind(&self) -> NativeSurfaceKind {
        NativeSurfaceKind::Win32
    }

    fn parent_handle(&self) -> Result<NativeParentHandle, NativeUiError> {
        let hwnd = self.hwnd()?;
        let raw =
            NonZeroIsize::new(hwnd.addr().cast_signed()).ok_or(NativeUiError::InvalidHandle)?;
        Ok(NativeParentHandle {
            kind: NativeSurfaceKind::Win32,
            window: RawWindowHandle::Win32(Win32WindowHandle::new(raw)),
            display: None,
        })
    }

    fn show(&mut self) -> Result<(), NativeUiError> {
        let hwnd = self.hwnd()?;
        // SAFETY: hwnd is a live owner-thread window.
        unsafe { ShowWindow(hwnd, SW_SHOW) };
        Ok(())
    }

    fn hide(&mut self) -> Result<(), NativeUiError> {
        let hwnd = self.hwnd()?;
        // SAFETY: hwnd is a live owner-thread window.
        unsafe { ShowWindow(hwnd, SW_HIDE) };
        Ok(())
    }

    fn request_focus(&mut self) -> Result<(), NativeUiError> {
        let hwnd = self.hwnd()?;
        // SAFETY: foreground activation can be refused by Windows policy without invalidating hwnd.
        unsafe { SetForegroundWindow(hwnd) };
        // SAFETY: hwnd is a live owner-thread window.
        unsafe { SetFocus(hwnd) };
        Ok(())
    }

    fn set_title(&mut self, title: &str) -> Result<(), NativeUiError> {
        let hwnd = self.hwnd()?;
        let title = wide_string(title)?;
        // SAFETY: title is terminated and lives through the synchronous call.
        if unsafe { SetWindowTextW(hwnd, title.as_ptr()) } == 0 {
            Err(last_error("SetWindowTextW"))
        } else {
            Ok(())
        }
    }

    fn set_constraints(
        &mut self,
        constraints: NativeWindowConstraints,
    ) -> Result<(), NativeUiError> {
        constraints.validate()?;
        let hwnd = self.hwnd()?;
        self.context.constraints = constraints;
        let fixed = constraints.min.is_some() && constraints.min == constraints.max;
        // SAFETY: style is read and written for a live owner-thread HWND.
        let current = unsafe { GetWindowLongPtrW(hwnd, GWL_STYLE) }.cast_unsigned();
        let mut style = u32::try_from(current)
            .map_err(|_| NativeUiError::NativeOperationFailed("invalid Win32 style".into()))?;
        if fixed {
            style &= !(WS_THICKFRAME | WS_MAXIMIZEBOX);
        } else {
            style |= WS_THICKFRAME | WS_MAXIMIZEBOX;
        }
        let style_bits = usize::try_from(style)
            .map_err(|_| NativeUiError::NativeOperationFailed("invalid Win32 style".into()))?
            .cast_signed();
        // SAFETY: updating style does not transfer ownership and FRAMECHANGED applies it.
        unsafe { SetWindowLongPtrW(hwnd, GWL_STYLE, style_bits) };
        // SAFETY: flags preserve the current position, z-order, and client dimensions.
        if unsafe {
            SetWindowPos(
                hwnd,
                ptr::null_mut(),
                0,
                0,
                0,
                0,
                SWP_NOMOVE | SWP_NOZORDER | SWP_NOACTIVATE | SWP_FRAMECHANGED,
            )
        } == 0
        {
            return Err(last_error("SetWindowPos(constraints)"));
        }
        Ok(())
    }

    fn set_client_size(&mut self, size: NativeWindowSize) -> Result<(), NativeUiError> {
        size.validate()?;
        let hwnd = self.hwnd()?;
        let outer = outer_rect(hwnd, size)?;
        let width = outer.right.saturating_sub(outer.left);
        let height = outer.bottom.saturating_sub(outer.top);
        // SAFETY: dimensions were validated and converted for this live owner-thread window.
        if unsafe {
            SetWindowPos(
                hwnd,
                ptr::null_mut(),
                0,
                0,
                width,
                height,
                SWP_NOMOVE | SWP_NOZORDER | SWP_NOACTIVATE,
            )
        } == 0
        {
            Err(last_error("SetWindowPos(client size)"))
        } else {
            Ok(())
        }
    }

    fn metrics(&self) -> Result<NativeWindowMetrics, NativeUiError> {
        metrics_for(self.hwnd()?)
    }
}

impl Drop for WindowsNativeWindow {
    fn drop(&mut self) {
        if self.owner == std::thread::current().id() && !self.context.hwnd.is_null() {
            // SAFETY: normal lifecycle destroys the live window on its owner thread.
            if unsafe { DestroyWindow(self.context.hwnd) } == 0 {
                log::error!("failed to destroy Win32 VST3 editor host window");
            }
        } else if !self.context.hwnd.is_null() {
            log::error!("Win32 VST3 editor window dropped outside its owner thread");
        }
    }
}

impl NativeUiPlatform for WindowsNativeUi {
    type Window = WindowsNativeWindow;
    type WakeHandle = Win32WakeHandle;

    fn initialize() -> Result<(Self, Self::WakeHandle), NativeUiError> {
        if !NativeUiDispatcher::is_owner_thread() {
            return Err(NativeUiError::WrongThread);
        }
        // SAFETY: null requests the current executable module.
        let instance = unsafe { GetModuleHandleW(ptr::null()) };
        if instance.is_null() {
            return Err(last_error("GetModuleHandleW"));
        }
        register_window_class(instance)?;
        Ok((
            Self {
                owner: std::thread::current().id(),
                instance,
            },
            Win32WakeHandle,
        ))
    }

    fn is_owner_thread(&self) -> bool {
        self.owner == std::thread::current().id()
    }

    fn capabilities(&self) -> NativeSurfaceCapabilities {
        NativeSurfaceCapabilities {
            win32: true,
            ..NativeSurfaceCapabilities::default()
        }
    }

    fn create_window(
        &mut self,
        id: NativeWindowId,
        spec: &NativeWindowSpec<'_>,
    ) -> Result<Self::Window, NativeUiError> {
        if !self.is_owner_thread() {
            return Err(NativeUiError::WrongThread);
        }
        spec.validate()?;
        if !matches!(
            self.capabilities().select(spec.preferred_surface)?,
            NativeSurfaceKind::Win32
        ) {
            return Err(NativeUiError::SurfaceUnsupported(spec.preferred_surface));
        }
        let fixed = spec.constraints.min.is_some() && spec.constraints.min == spec.constraints.max;
        let style = if fixed {
            BASE_STYLE
        } else {
            BASE_STYLE | WS_THICKFRAME | WS_MAXIMIZEBOX
        };
        let title = wide_string(spec.title)?;
        let mut context = Box::new(WindowContext {
            id,
            hwnd: ptr::null_mut(),
            constraints: spec.constraints,
        });
        let context_pointer = ptr::from_mut(context.as_mut()).cast::<c_void>();
        let outer = outer_rect_for_style(spec.initial_size, style, 0, 96)?;
        // SAFETY: class is registered; context is boxed and remains stable until after destruction.
        let hwnd = unsafe {
            CreateWindowExW(
                0,
                WINDOW_CLASS.as_ptr(),
                title.as_ptr(),
                style,
                CW_USEDEFAULT,
                CW_USEDEFAULT,
                outer.right.saturating_sub(outer.left),
                outer.bottom.saturating_sub(outer.top),
                ptr::null_mut(),
                ptr::null_mut(),
                self.instance,
                context_pointer,
            )
        };
        if hwnd.is_null() {
            return Err(last_error("CreateWindowExW(editor)"));
        }
        context.hwnd = hwnd;
        let mut window = WindowsNativeWindow {
            context,
            owner: self.owner,
        };
        if spec.initially_visible {
            window.show()?;
        }
        Ok(window)
    }

    fn poll_events(
        &mut self,
        mut emit: impl FnMut(NativeWindowEvent),
    ) -> Result<(), NativeUiError> {
        if !self.is_owner_thread() {
            return Err(NativeUiError::WrongThread);
        }
        EVENTS.with(|events| {
            let mut events = events.borrow_mut();
            while let Some(event) = events.pop_front() {
                emit(event);
            }
        });
        Ok(())
    }

    fn pump(&mut self) -> Result<(), NativeUiError> {
        if self.is_owner_thread() {
            Ok(())
        } else {
            Err(NativeUiError::WrongThread)
        }
    }
}

fn register_window_class(instance: *mut c_void) -> Result<(), NativeUiError> {
    let class = WNDCLASSW {
        lpfnWndProc: Some(editor_window_proc),
        hInstance: instance,
        lpszClassName: WINDOW_CLASS.as_ptr(),
        ..WNDCLASSW::default()
    };
    // SAFETY: all class fields remain live through the synchronous registration.
    let atom = unsafe { RegisterClassW(&raw const class) };
    // SAFETY: immediately reads the registration error for this thread.
    if atom == 0 && unsafe { GetLastError() } != ERROR_CLASS_ALREADY_EXISTS {
        Err(last_error("RegisterClassW(editor)"))
    } else {
        Ok(())
    }
}

unsafe extern "system" fn editor_window_proc(
    hwnd: HWND,
    message: u32,
    wparam: WPARAM,
    lparam: LPARAM,
) -> LRESULT {
    if message == WM_NCCREATE {
        let create = ptr::with_exposed_provenance::<CREATESTRUCTW>(lparam.cast_unsigned());
        if create.is_null() {
            return 0;
        }
        // SAFETY: WM_NCCREATE supplies a readable CREATESTRUCTW for this call.
        let context = unsafe { (*create).lpCreateParams.cast::<WindowContext>() };
        if context.is_null() {
            return 0;
        }
        // SAFETY: stores the stable boxed context pointer for later owner-thread messages.
        unsafe { SetWindowLongPtrW(hwnd, GWLP_USERDATA, context.addr().cast_signed()) };
        // SAFETY: context is the boxed create parameter and hwnd has just been created for it.
        unsafe { (*context).hwnd = hwnd };
    }

    // SAFETY: reads the pointer installed at WM_NCCREATE without dereferencing it yet.
    let context_address = unsafe { GetWindowLongPtrW(hwnd, GWLP_USERDATA) }.cast_unsigned();
    let context = ptr::with_exposed_provenance_mut::<WindowContext>(context_address);
    if context.is_null() {
        // SAFETY: no application context exists, so default handling is required.
        return unsafe { DefWindowProcW(hwnd, message, wparam, lparam) };
    }

    // SAFETY: GWLP_USERDATA points to the stable boxed context until WM_NCDESTROY clears it.
    let context = unsafe { &mut *context };
    match message {
        WM_CLOSE => {
            push_event(NativeWindowEvent::CloseRequested { window: context.id });
            0
        }
        WM_SIZE => {
            let packed = lparam.cast_unsigned();
            let width = u32::try_from(packed & 0xffff).unwrap_or(0);
            let height = u32::try_from((packed >> 16) & 0xffff).unwrap_or(0);
            if let Ok(size) = NativeWindowSize::new(width, height) {
                push_event(NativeWindowEvent::Resized {
                    window: context.id,
                    size,
                });
            }
            0
        }
        WM_DPICHANGED => {
            let suggested = ptr::with_exposed_provenance::<RECT>(lparam.cast_unsigned());
            if !suggested.is_null() {
                // SAFETY: WM_DPICHANGED supplies a readable suggested RECT for this call.
                let rect = unsafe { *suggested };
                // SAFETY: applying the suggested top-level rectangle preserves Win32 DPI semantics.
                unsafe {
                    SetWindowPos(
                        hwnd,
                        ptr::null_mut(),
                        rect.left,
                        rect.top,
                        rect.right.saturating_sub(rect.left),
                        rect.bottom.saturating_sub(rect.top),
                        SWP_NOZORDER | SWP_NOACTIVATE,
                    )
                };
            }
            if let Ok(metrics) = metrics_for(hwnd) {
                push_event(NativeWindowEvent::ScaleFactorChanged {
                    window: context.id,
                    metrics,
                });
            }
            0
        }
        WM_GETMINMAXINFO => {
            apply_min_max(hwnd, context.constraints, lparam);
            0
        }
        WM_SETFOCUS => {
            push_event(NativeWindowEvent::FocusChanged {
                window: context.id,
                focused: true,
            });
            0
        }
        WM_KILLFOCUS => {
            push_event(NativeWindowEvent::FocusChanged {
                window: context.id,
                focused: false,
            });
            0
        }
        WM_NCDESTROY => {
            push_event(NativeWindowEvent::Destroyed { window: context.id });
            context.hwnd = ptr::null_mut();
            // SAFETY: clears the borrowed context pointer before the Box can be dropped.
            unsafe { SetWindowLongPtrW(hwnd, GWLP_USERDATA, 0) };
            // SAFETY: preserves default non-client teardown behavior.
            unsafe { DefWindowProcW(hwnd, message, wparam, lparam) }
        }
        _ => {
            // SAFETY: unhandled messages retain default Win32 behavior.
            unsafe { DefWindowProcW(hwnd, message, wparam, lparam) }
        }
    }
}

fn apply_min_max(hwnd: HWND, constraints: NativeWindowConstraints, lparam: LPARAM) {
    let info = ptr::with_exposed_provenance_mut::<MINMAXINFO>(lparam.cast_unsigned());
    if info.is_null() {
        return;
    }
    if let Some(minimum) = constraints.min
        && let Ok(rect) = outer_rect(hwnd, minimum)
    {
        // SAFETY: WM_GETMINMAXINFO supplies a writable MINMAXINFO for this call.
        unsafe { (*info).ptMinTrackSize.x = rect.right.saturating_sub(rect.left) };
        // SAFETY: WM_GETMINMAXINFO supplies a writable MINMAXINFO for this call.
        unsafe { (*info).ptMinTrackSize.y = rect.bottom.saturating_sub(rect.top) };
    }
    if let Some(maximum) = constraints.max
        && let Ok(rect) = outer_rect(hwnd, maximum)
    {
        // SAFETY: WM_GETMINMAXINFO supplies a writable MINMAXINFO for this call.
        unsafe { (*info).ptMaxTrackSize.x = rect.right.saturating_sub(rect.left) };
        // SAFETY: WM_GETMINMAXINFO supplies a writable MINMAXINFO for this call.
        unsafe { (*info).ptMaxTrackSize.y = rect.bottom.saturating_sub(rect.top) };
    }
}

fn outer_rect(hwnd: HWND, size: NativeWindowSize) -> Result<RECT, NativeUiError> {
    // SAFETY: style query is valid for a live HWND.
    let style = unsafe { GetWindowLongPtrW(hwnd, GWL_STYLE) }.cast_unsigned();
    // SAFETY: extended style query is valid for a live HWND.
    let extended = unsafe { GetWindowLongPtrW(hwnd, GWL_EXSTYLE) }.cast_unsigned();
    // SAFETY: returns zero only when no DPI can be resolved; use the Win32 baseline then.
    let dpi = unsafe { GetDpiForWindow(hwnd) }.max(96);
    outer_rect_for_style(
        size,
        u32::try_from(style)
            .map_err(|_| NativeUiError::NativeOperationFailed("invalid Win32 style".into()))?,
        u32::try_from(extended).map_err(|_| {
            NativeUiError::NativeOperationFailed("invalid Win32 extended style".into())
        })?,
        dpi,
    )
}

fn outer_rect_for_style(
    size: NativeWindowSize,
    style: u32,
    extended: u32,
    dpi: u32,
) -> Result<RECT, NativeUiError> {
    let mut rect = RECT {
        left: 0,
        top: 0,
        right: i32::try_from(size.width).map_err(|_| NativeUiError::InvalidSize(size))?,
        bottom: i32::try_from(size.height).map_err(|_| NativeUiError::InvalidSize(size))?,
    };
    // SAFETY: rect is writable and style values come from Win32 or validated constants.
    if unsafe { AdjustWindowRectExForDpi(&raw mut rect, style, 0, extended, dpi) } == 0 {
        Err(last_error("AdjustWindowRectExForDpi"))
    } else {
        Ok(rect)
    }
}

fn metrics_for(hwnd: HWND) -> Result<NativeWindowMetrics, NativeUiError> {
    let mut rect = RECT::default();
    // SAFETY: rect is writable and hwnd is live on the owner thread.
    if unsafe { GetClientRect(hwnd, &raw mut rect) } == 0 {
        return Err(last_error("GetClientRect"));
    }
    let width = u32::try_from(rect.right.saturating_sub(rect.left))
        .map_err(|_| NativeUiError::EventDispatchFailed("negative client width".into()))?;
    let height = u32::try_from(rect.bottom.saturating_sub(rect.top))
        .map_err(|_| NativeUiError::EventDispatchFailed("negative client height".into()))?;
    // SAFETY: DPI is queried for a live window.
    let dpi = unsafe { GetDpiForWindow(hwnd) }.max(96);
    let metrics = NativeWindowMetrics {
        client_size: NativeWindowSize::new(width, height)?,
        scale_factor: f64::from(dpi) / 96.0,
    };
    metrics.validate()?;
    Ok(metrics)
}

fn wide_string(value: &str) -> Result<Vec<u16>, NativeUiError> {
    if value.contains('\0') {
        return Err(NativeUiError::NativeOperationFailed(
            "Win32 text contains an interior NUL".into(),
        ));
    }
    Ok(value.encode_utf16().chain(std::iter::once(0)).collect())
}

fn push_event(event: NativeWindowEvent) {
    EVENTS.with(|events| events.borrow_mut().push_back(event));
}

fn last_error(operation: &'static str) -> NativeUiError {
    // SAFETY: reads the calling thread's Win32 last-error value.
    let code = unsafe { GetLastError() };
    NativeUiError::NativeOperationFailed(format!("{operation} failed with Win32 error {code}"))
}
