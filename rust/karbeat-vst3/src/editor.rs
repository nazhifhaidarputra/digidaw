//! VST3 editor attachment to windows owned by DigiDAW's native window service.
#![allow(non_snake_case, reason = "VST3 interface method names are ABI-defined")]

use crate::{instance::check, run_loop::RunLoop};
use karbeat_host_api::{HostError, NativeParentHandle, NativeSurfaceKind};
use raw_window_handle::RawWindowHandle;
use std::{
    cell::{Cell, RefCell},
    ffi::c_void,
    ptr,
    rc::Rc,
};
use vst3::{
    Class, ComPtr, ComRef, ComWrapper,
    Steinberg::{
        Vst::{IEditController, IEditControllerTrait},
        *,
    },
};

type ResizeHandler = Rc<dyn Fn(u32, u32) -> bool>;
struct PlugFrame {
    run_loop: Rc<RunLoop>,
    view: Cell<*mut IPlugView>,
    resize: RefCell<Option<ResizeHandler>>,
    requested_size: Cell<Option<(u32, u32)>>,
}
impl Class for PlugFrame {
    type Interfaces = (IPlugFrame, Linux::IRunLoop);
}
impl IPlugFrameTrait for PlugFrame {
    unsafe fn resizeView(&self, view: *mut IPlugView, rect: *mut ViewRect) -> tresult {
        if view.is_null() || rect.is_null() || view != self.view.get() {
            return kInvalidArgument;
        }
        // SAFETY: Plugin supplies one readable rectangle; size is validated before native use.
        let rect_value = unsafe { *rect };
        let Some((width, height)) = dimensions(&rect_value) else {
            return kInvalidArgument;
        };
        let handler = self.resize.borrow().clone();
        if let Some(handler) = handler {
            if !handler(width, height) {
                return kResultFalse;
            }
        }
        self.requested_size.set(Some((width, height)));
        // SAFETY: view matches the retained editor's pointer, alive throughout this callback.
        let Some(view) = (unsafe { ComRef::from_raw(view) }) else {
            return kInvalidArgument;
        };
        // SAFETY: Same validated writable rectangle is synchronously acknowledged to the plugin.
        unsafe { view.onSize(rect) }
    }
}
crate::run_loop::delegate_run_loop!(PlugFrame);

pub(crate) struct Vst3Editor {
    view: ComPtr<IPlugView>,
    frame: ComWrapper<PlugFrame>,
    attached: bool,
}
impl Vst3Editor {
    pub fn create(
        controller: &ComPtr<IEditController>,
        run_loop: Rc<RunLoop>,
    ) -> Result<Self, HostError> {
        // SAFETY: Controller is initialized on the native UI thread; editor is a static C string.
        let raw = unsafe { controller.createView(c"editor".as_ptr()) };
        // SAFETY: createView returns a newly owned IPlugView reference or null.
        let view =
            unsafe { ComPtr::from_raw(raw) }.ok_or(HostError::Unsupported("native editor"))?;
        Self::from_view(view, run_loop)
    }
    fn from_view(view: ComPtr<IPlugView>, run_loop: Rc<RunLoop>) -> Result<Self, HostError> {
        let frame = ComWrapper::new(PlugFrame {
            run_loop,
            view: Cell::new(view.as_ptr()),
            resize: RefCell::new(None),
            requested_size: Cell::new(None),
        });
        let pointer = frame
            .as_com_ref::<IPlugFrame>()
            .ok_or(HostError::Unsupported("editor frame"))?;
        // SAFETY: Frame remains alive until it is explicitly detached before editor destruction.
        check("editor.setFrame", unsafe {
            view.setFrame(pointer.as_ptr())
        })?;
        Ok(Self {
            view,
            frame,
            attached: false,
        })
    }
    pub fn size(&self) -> Result<(u32, u32), HostError> {
        let mut rect = ViewRect {
            left: 0,
            top: 0,
            right: 0,
            bottom: 0,
        };
        // SAFETY: Live view writes its dimensions into one initialized rectangle.
        check("editor.getSize", unsafe {
            self.view.getSize(&raw mut rect)
        })?;
        dimensions(&rect).ok_or(HostError::InvalidConfiguration)
    }
    pub fn set_resize_handler(&self, handler: ResizeHandler) {
        *self.frame.resize.borrow_mut() = Some(handler);
    }
    pub fn resizable(&self) -> Result<bool, HostError> {
        // SAFETY: The retained view is queried on its owning UI thread.
        let code = unsafe { self.view.canResize() };
        if code == kResultOk {
            Ok(true)
        } else if code == kResultFalse || code == kNotImplemented {
            Ok(false)
        } else {
            Err(HostError::PluginCall {
                operation: "editor.canResize",
                code,
            })
        }
    }
    pub fn open(&mut self, parent_handle: &NativeParentHandle) -> Result<(), HostError> {
        if self.attached {
            return Ok(());
        }
        let (parent, platform): (*mut c_void, &std::ffi::CStr) =
            match (parent_handle.kind, parent_handle.window) {
                (NativeSurfaceKind::X11, RawWindowHandle::Xcb(handle)) => (
                    ptr::without_provenance_mut(
                        usize::try_from(handle.window.get())
                            .map_err(|_| HostError::InvalidConfiguration)?,
                    ),
                    c"X11EmbedWindowID",
                ),
                #[cfg(target_os = "windows")]
                (NativeSurfaceKind::Win32, RawWindowHandle::Win32(handle)) => (
                    ptr::with_exposed_provenance_mut(
                        usize::try_from(handle.hwnd.get())
                            .map_err(|_| HostError::InvalidConfiguration)?,
                    ),
                    c"HWND",
                ),
                #[cfg(target_os = "macos")]
                (NativeSurfaceKind::AppKit, RawWindowHandle::AppKit(handle)) => {
                    (handle.ns_view.as_ptr(), c"NSView")
                }
                _ => {
                    return Err(HostError::Unsupported(
                        "VST3 editor requires an X11/XCB parent on Linux",
                    ));
                }
            };
        // SAFETY: This static platform string is one of the VST3 SDK's native parent types.
        check("editor.isPlatformTypeSupported", unsafe {
            self.view.isPlatformTypeSupported(platform.as_ptr())
        })?;
        // SAFETY: Native service guarantees the parent remains alive until close returns.
        check("editor.attached", unsafe {
            self.view.attached(parent, platform.as_ptr())
        })?;
        self.attached = true;
        Ok(())
    }
    pub fn resize(&self, width: u32, height: u32) -> Result<(), HostError> {
        // SAFETY: View resize capability query occurs on the owning UI thread.
        check("editor.canResize", unsafe { self.view.canResize() })?;
        let mut rect = ViewRect {
            left: 0,
            top: 0,
            right: i32::try_from(width).map_err(|_| HostError::InvalidConfiguration)?,
            bottom: i32::try_from(height).map_err(|_| HostError::InvalidConfiguration)?,
        };
        if dimensions(&rect).is_none() {
            return Err(HostError::InvalidConfiguration);
        }
        // SAFETY: View may adjust this writable size rectangle to its supported constraints.
        let result = unsafe { self.view.checkSizeConstraint(&raw mut rect) };
        if result != kNotImplemented {
            check("editor.checkSizeConstraint", result)?;
        }
        let (constrained_width, constrained_height) =
            dimensions(&rect).ok_or(HostError::InvalidConfiguration)?;
        if (width, height) != (constrained_width, constrained_height) {
            let handler = self.frame.resize.borrow().clone();
            if let Some(handler) = handler {
                if !handler(constrained_width, constrained_height) {
                    return Err(HostError::NativeDispatch(
                        "could not apply editor size constraints".into(),
                    ));
                }
            }
        }
        // SAFETY: Adjusted dimensions are valid and the view remains retained.
        check("editor.onSize", unsafe { self.view.onSize(&raw mut rect) })
    }
    pub fn close(&mut self) -> Result<(), HostError> {
        if self.attached {
            // SAFETY: Exactly one removed call follows each successful attachment.
            let code = unsafe { self.view.removed() };
            self.attached = false;
            check("editor.removed", code)?;
        }
        Ok(())
    }
}
impl Drop for Vst3Editor {
    fn drop(&mut self) {
        if let Err(error) = self.close() {
            log::warn!("VST3 editor teardown: {error}");
        }
        // SAFETY: View is detached before releasing its frame owner.
        unsafe { self.view.setFrame(ptr::null_mut()) };
        self.frame.view.set(ptr::null_mut());
    }
}
fn dimensions(rect: &ViewRect) -> Option<(u32, u32)> {
    let width = u32::try_from(rect.right.checked_sub(rect.left)?).ok()?;
    let height = u32::try_from(rect.bottom.checked_sub(rect.top)?).ok()?;
    ((1..=16384).contains(&width) && (1..=16384).contains(&height)).then_some((width, height))
}

#[cfg(test)]
#[allow(
    clippy::unwrap_used,
    reason = "synthetic editor assertions fail on unexpected results"
)]
mod tests {
    use super::*;
    use raw_window_handle::XcbWindowHandle;
    use std::num::NonZeroU32;

    struct View {
        calls: Rc<RefCell<Vec<&'static str>>>,
        resize_result: Cell<tresult>,
        attach_result: Cell<tresult>,
        size: Cell<(u32, u32)>,
    }
    impl Class for View {
        type Interfaces = (IPlugView,);
    }
    impl IPlugViewTrait for View {
        unsafe fn isPlatformTypeSupported(&self, _: FIDString) -> tresult {
            kResultOk
        }
        unsafe fn attached(&self, _: *mut c_void, _: FIDString) -> tresult {
            self.calls.borrow_mut().push("attach");
            self.attach_result.get()
        }
        unsafe fn removed(&self) -> tresult {
            self.calls.borrow_mut().push("remove");
            kResultOk
        }
        unsafe fn onWheel(&self, _: f32) -> tresult {
            kResultFalse
        }
        unsafe fn onKeyDown(&self, _: char16, _: int16, _: int16) -> tresult {
            kResultFalse
        }
        unsafe fn onKeyUp(&self, _: char16, _: int16, _: int16) -> tresult {
            kResultFalse
        }
        unsafe fn getSize(&self, size: *mut ViewRect) -> tresult {
            let (width, height) = self.size.get();
            // SAFETY: The host supplies a writable size record for the duration of this call.
            unsafe {
                *size = ViewRect {
                    left: 0,
                    top: 0,
                    right: i32::try_from(width).unwrap(),
                    bottom: i32::try_from(height).unwrap(),
                };
            }
            kResultOk
        }
        unsafe fn onSize(&self, rect: *mut ViewRect) -> tresult {
            self.calls.borrow_mut().push("plugin_resize");
            // SAFETY: The host supplies the validated rectangle synchronously.
            self.size.set(dimensions(unsafe { &*rect }).unwrap());
            kResultOk
        }
        unsafe fn onFocus(&self, _: TBool) -> tresult {
            kResultOk
        }
        unsafe fn setFrame(&self, frame: *mut IPlugFrame) -> tresult {
            self.calls.borrow_mut().push(if frame.is_null() {
                "detach_frame"
            } else {
                "frame"
            });
            kResultOk
        }
        unsafe fn canResize(&self) -> tresult {
            self.resize_result.get()
        }
        unsafe fn checkSizeConstraint(&self, rect: *mut ViewRect) -> tresult {
            self.calls.borrow_mut().push("constraint");
            // SAFETY: The host supplies a writable rectangle for plugin constraints.
            let rect = unsafe { &mut *rect };
            rect.right = rect.right.min(640);
            rect.bottom = rect.bottom.min(480);
            kResultOk
        }
    }
    fn fixture() -> (Vst3Editor, ComWrapper<View>) {
        let view = ComWrapper::new(View {
            calls: Rc::new(RefCell::new(Vec::new())),
            resize_result: Cell::new(kResultOk),
            attach_result: Cell::new(kResultOk),
            size: Cell::new((640, 480)),
        });
        let editor =
            Vst3Editor::from_view(view.to_com_ptr::<IPlugView>().unwrap(), RunLoop::new()).unwrap();
        (editor, view)
    }

    #[test]
    fn constrained_resize_updates_native_client_before_plugin_content() {
        let (editor, view) = fixture();
        let calls = view.calls.clone();
        editor.set_resize_handler(Rc::new(move |width, height| {
            assert_eq!((width, height), (640, 480));
            calls.borrow_mut().push("native_resize");
            true
        }));
        assert!(editor.resizable().unwrap());
        editor.resize(800, 600).unwrap();
        assert_eq!(
            *view.calls.borrow(),
            ["frame", "constraint", "native_resize", "plugin_resize"]
        );
        assert_eq!(editor.size().unwrap(), (640, 480));
    }

    #[test]
    fn fixed_editors_and_native_resize_failures_do_not_resize_plugin_content() {
        let (editor, view) = fixture();
        for code in [kResultFalse, kNotImplemented] {
            view.resize_result.set(code);
            assert!(!editor.resizable().unwrap());
            assert!(editor.resize(800, 600).is_err());
        }
        assert_eq!(*view.calls.borrow(), ["frame"]);
        view.resize_result.set(kResultOk);
        editor.set_resize_handler(Rc::new(|_, _| false));
        assert!(matches!(
            editor.resize(800, 600),
            Err(HostError::NativeDispatch(_))
        ));
        assert_eq!(*view.calls.borrow(), ["frame", "constraint"]);
    }

    #[test]
    fn close_and_drop_detach_once_and_failed_attach_never_calls_removed() {
        for success in [true, false] {
            let (mut editor, view) = fixture();
            view.attach_result
                .set(if success { kResultOk } else { kResultFalse });
            let parent = NativeParentHandle {
                kind: NativeSurfaceKind::X11,
                window: RawWindowHandle::Xcb(XcbWindowHandle::new(NonZeroU32::MIN)),
                display: None,
            };
            assert_eq!(editor.open(&parent).is_ok(), success);
            if success {
                editor.open(&parent).unwrap();
            }
            editor.close().unwrap();
            editor.close().unwrap();
            drop(editor);
            if success {
                assert_eq!(
                    *view.calls.borrow(),
                    ["frame", "attach", "remove", "detach_frame"]
                );
            } else {
                assert_eq!(*view.calls.borrow(), ["frame", "attach", "detach_frame"]);
            }
        }
    }
}
