use crate::native_ui::{NativeUiError, NativeUiWakeHandle};

#[cfg(target_os = "linux")]
/// Linux native-window backend with Wayland and X11 implementations.
pub mod linux;
#[cfg(target_os = "macos")]
pub mod macos;
#[cfg(target_os = "windows")]
pub mod windows;

/// Wake handle used by platform stubs that cannot provide a native event loop.
#[derive(Debug, Clone, Copy, Default)]
pub struct UnavailableWakeHandle;

impl NativeUiWakeHandle for UnavailableWakeHandle {
    fn wake(&self) -> Result<(), NativeUiError> {
        Err(NativeUiError::RuntimeUnavailable)
    }
}

#[cfg(target_os = "linux")]
/// Native UI backend selected for the current compilation target.
pub type SystemNativeUi = linux::LinuxNativeUi;

#[cfg(target_os = "windows")]
pub type SystemNativeUi = windows::WindowsNativeUi;

#[cfg(target_os = "macos")]
pub type SystemNativeUi = macos::MacOsNativeUi;
