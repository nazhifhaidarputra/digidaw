use crate::native_ui::{NativeUiError, NativeUiWakeHandle};

#[cfg(target_os = "linux")]
pub mod linux;
#[cfg(target_os = "macos")]
pub mod macos;
#[cfg(target_os = "windows")]
pub mod windows;

#[derive(Debug, Clone, Copy, Default)]
pub struct UnavailableWakeHandle;

impl NativeUiWakeHandle for UnavailableWakeHandle {
    fn wake(&self) -> Result<(), NativeUiError> {
        Err(NativeUiError::RuntimeUnavailable)
    }
}

#[cfg(target_os = "linux")]
pub type SystemNativeUi = linux::LinuxNativeUi;

#[cfg(target_os = "windows")]
pub type SystemNativeUi = windows::WindowsNativeUi;

#[cfg(target_os = "macos")]
pub type SystemNativeUi = macos::MacOsNativeUi;
