//! Bounded native-owner task dispatch with compile-time event-loop adapters.

mod common;
#[cfg(target_os = "linux")]
mod linux;
#[cfg(target_os = "windows")]
mod windows;

use super::NativeUiError;
pub use common::{NativeUiControlFlow, NativeUiDispatcher, spawn_ui_local};
#[cfg(target_os = "linux")]
pub use linux::{
    GlibWakeHandle, NativeUiInterval, UiFdSource, install_ui_fd_source, install_ui_interval,
};
#[cfg(not(any(target_os = "linux", target_os = "windows")))]
use std::env::consts::OS;
#[cfg(target_os = "windows")]
pub use windows::{
    NativeUiInterval, Win32WakeHandle, WindowsStaGuard, initialize_windows_main_thread,
    install_ui_interval, request_windows_main_loop_shutdown, run_windows_main_loop,
    shutdown_windows_main_thread,
};

#[cfg(target_os = "linux")]
pub(super) fn initialize_dispatcher() -> Result<(), NativeUiError> {
    linux::initialize_dispatcher()
}

#[cfg(target_os = "windows")]
pub(super) fn initialize_dispatcher() -> Result<(), NativeUiError> {
    windows::initialize_dispatcher()
}

#[cfg(not(any(target_os = "linux", target_os = "windows")))]
pub(super) fn initialize_dispatcher() -> Result<(), NativeUiError> {
    Err(NativeUiError::PlatformBackendUnavailable(OS))
}

#[cfg(target_os = "linux")]
pub(super) fn wake_ui_owner() -> Result<(), NativeUiError> {
    linux::wake_ui_owner()
}

#[cfg(target_os = "windows")]
pub(super) fn wake_ui_owner() -> Result<(), NativeUiError> {
    windows::wake_ui_owner()
}

#[cfg(not(any(target_os = "linux", target_os = "windows")))]
pub(super) fn wake_ui_owner() -> Result<(), NativeUiError> {
    Err(NativeUiError::RuntimeUnavailable)
}
