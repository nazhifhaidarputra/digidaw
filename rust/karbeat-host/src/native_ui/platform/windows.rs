use crate::native_ui::{
    NativeParentHandle, NativeSurfaceCapabilities, NativeSurfaceKind, NativeUiError,
    NativeUiPlatform, NativeWindow, NativeWindowConstraints, NativeWindowEvent, NativeWindowId,
    NativeWindowMetrics, NativeWindowSize, NativeWindowSpec,
};

use super::UnavailableWakeHandle;

pub struct WindowsNativeUi;
pub struct WindowsNativeWindow {
    id: NativeWindowId,
}

fn unavailable<T>() -> Result<T, NativeUiError> {
    Err(NativeUiError::PlatformBackendUnavailable("Windows"))
}

impl NativeWindow for WindowsNativeWindow {
    fn id(&self) -> NativeWindowId {
        self.id
    }

    fn surface_kind(&self) -> NativeSurfaceKind {
        NativeSurfaceKind::Win32
    }

    fn parent_handle(&self) -> Result<NativeParentHandle, NativeUiError> {
        unavailable()
    }

    fn show(&mut self) -> Result<(), NativeUiError> {
        unavailable()
    }

    fn hide(&mut self) -> Result<(), NativeUiError> {
        unavailable()
    }

    fn request_focus(&mut self) -> Result<(), NativeUiError> {
        unavailable()
    }

    fn set_title(&mut self, _: &str) -> Result<(), NativeUiError> {
        unavailable()
    }

    fn set_constraints(&mut self, _: NativeWindowConstraints) -> Result<(), NativeUiError> {
        unavailable()
    }

    fn set_client_size(&mut self, _: NativeWindowSize) -> Result<(), NativeUiError> {
        unavailable()
    }

    fn metrics(&self) -> Result<NativeWindowMetrics, NativeUiError> {
        unavailable()
    }
}

impl NativeUiPlatform for WindowsNativeUi {
    type Window = WindowsNativeWindow;
    type WakeHandle = UnavailableWakeHandle;

    fn initialize() -> Result<(Self, Self::WakeHandle), NativeUiError> {
        unavailable()
    }

    fn is_owner_thread(&self) -> bool {
        false
    }

    fn capabilities(&self) -> NativeSurfaceCapabilities {
        NativeSurfaceCapabilities::default()
    }

    fn create_window(
        &mut self,
        _: NativeWindowId,
        _: &NativeWindowSpec<'_>,
    ) -> Result<Self::Window, NativeUiError> {
        unavailable()
    }

    fn poll_events(&mut self, _: impl FnMut(NativeWindowEvent)) -> Result<(), NativeUiError> {
        unavailable()
    }

    fn pump(&mut self) -> Result<(), NativeUiError> {
        unavailable()
    }
}
