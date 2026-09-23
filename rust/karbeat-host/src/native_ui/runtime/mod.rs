//! Bounded native-owner task dispatch with compile-time event-loop adapters.

mod common;
#[cfg(target_os = "linux")]
mod linux;
#[cfg(target_os = "windows")]
mod windows;

pub use common::{NativeUiControlFlow, NativeUiDispatcher, spawn_ui_local};
#[cfg(target_os = "linux")]
pub use linux::{
    GlibWakeHandle, NativeUiInterval, UiFdSource, install_ui_fd_source, install_ui_interval,
};
#[cfg(target_os = "windows")]
pub use windows::{
    NativeUiInterval, Win32WakeHandle, WindowsStaGuard, initialize_windows_main_thread,
    install_ui_interval, request_windows_main_loop_shutdown, run_windows_main_loop,
    shutdown_windows_main_thread,
};

#[cfg(target_os = "linux")]
pub(super) fn initialize_dispatcher() -> Result<(), super::NativeUiError> {
    linux::initialize_dispatcher()
}

#[cfg(target_os = "windows")]
pub(super) fn initialize_dispatcher() -> Result<(), super::NativeUiError> {
    windows::initialize_dispatcher()
}

#[cfg(not(any(target_os = "linux", target_os = "windows")))]
pub(super) fn initialize_dispatcher() -> Result<(), super::NativeUiError> {
    Err(super::NativeUiError::PlatformBackendUnavailable(
        std::env::consts::OS,
    ))
}

#[cfg(target_os = "linux")]
pub(super) fn wake_ui_owner() -> Result<(), super::NativeUiError> {
    linux::wake_ui_owner()
}

#[cfg(target_os = "windows")]
pub(super) fn wake_ui_owner() -> Result<(), super::NativeUiError> {
    windows::wake_ui_owner()
}

#[cfg(not(any(target_os = "linux", target_os = "windows")))]
pub(super) fn wake_ui_owner() -> Result<(), super::NativeUiError> {
    Err(super::NativeUiError::RuntimeUnavailable)
}
