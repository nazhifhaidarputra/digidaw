use karbeat_host::{HostInstanceId, PluginEditorManager};
use karbeat_vst3::Vst3PluginHost;
use raw_window_handle::{RawWindowHandle, XlibWindowHandle};
use std::{
    ffi::{c_char, c_int, c_uint, c_ulong, c_void},
    ptr,
    time::{Duration, Instant},
};

#[link(name = "X11")]
unsafe extern "C" {
    fn XOpenDisplay(name: *const c_char) -> *mut c_void;
    fn XDefaultRootWindow(display: *mut c_void) -> c_ulong;
    fn XCreateSimpleWindow(
        display: *mut c_void,
        parent: c_ulong,
        x: c_int,
        y: c_int,
        width: c_uint,
        height: c_uint,
        border: c_uint,
        border_color: c_ulong,
        background: c_ulong,
    ) -> c_ulong;
    fn XStoreName(display: *mut c_void, window: c_ulong, name: *const c_char) -> c_int;
    fn XMapRaised(display: *mut c_void, window: c_ulong) -> c_int;
    fn XFlush(display: *mut c_void) -> c_int;
    fn XSync(display: *mut c_void, discard: c_int) -> c_int;
    fn XDestroyWindow(display: *mut c_void, window: c_ulong) -> c_int;
    fn XCloseDisplay(display: *mut c_void) -> c_int;
}

struct Window {
    display: *mut c_void,
    window: c_ulong,
}
impl Drop for Window {
    fn drop(&mut self) {
        // SAFETY: The test retains this X11 connection and parent until after editor detachment.
        unsafe { XDestroyWindow(self.display, self.window) };
        // SAFETY: All windows on the exclusively owned connection have been destroyed.
        unsafe { XCloseDisplay(self.display) };
    }
}

pub fn exercise_editor(host: &mut Vst3PluginHost, instance: HostInstanceId) {
    for _ in 0..2 {
        let (width, height) = host.editor_size(instance).unwrap();
        // SAFETY: A null name selects DISPLAY, without changing the application's backend.
        let display = unsafe { XOpenDisplay(ptr::null()) };
        assert!(
            !display.is_null(),
            "VITAL_TEST_EDITOR requires an X11/XWayland display"
        );
        // SAFETY: display is an open Xlib connection.
        let root = unsafe { XDefaultRootWindow(display) };
        // SAFETY: root belongs to this display; the requested dimensions came from IPlugView.
        let window = unsafe { XCreateSimpleWindow(display, root, 80, 80, width, height, 0, 0, 0) };
        let window = Window { display, window };
        assert_ne!(window.window, 0);
        // SAFETY: Parent and static C title are valid for the call.
        unsafe {
            XStoreName(
                display,
                window.window,
                c"DigiDAW — Vital editor acceptance".as_ptr(),
            )
        };
        // SAFETY: The plugin uses a separate X connection; its parent must exist on the server.
        unsafe { XSync(display, 0) };
        host.open_editor(
            instance,
            RawWindowHandle::Xlib(XlibWindowHandle::new(window.window)),
        )
        .unwrap();
        // SAFETY: Show the live native parent after successful editor attachment.
        unsafe { XMapRaised(display, window.window) };
        // SAFETY: Flush the live connection's map request.
        unsafe { XFlush(display) };
        let until = Instant::now() + Duration::from_secs(3);
        while Instant::now() < until {
            host.pump().unwrap();
            std::thread::sleep(Duration::from_millis(8));
        }
        host.close_editor(instance).unwrap();
        host.close_editor(instance).unwrap();
        drop(window);
        host.pump().unwrap();
    }
}
