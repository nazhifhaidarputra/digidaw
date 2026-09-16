use crate::native_ui::{
    NativeParentHandle, NativeSurfaceCapabilities, NativeSurfaceKind, NativeUiError,
    NativeUiPlatform, NativeWindow, NativeWindowConstraints, NativeWindowEvent, NativeWindowId,
    NativeWindowMetrics, NativeWindowSize, NativeWindowSpec,
};

use super::UnavailableWakeHandle;

pub struct LinuxNativeUi;
pub struct LinuxNativeWindow {
    id: NativeWindowId,
}

impl NativeWindow for LinuxNativeWindow {
    fn id(&self) -> NativeWindowId {
        self.id
    }

    fn surface_kind(&self) -> NativeSurfaceKind {
        NativeSurfaceKind::X11
    }

    fn parent_handle(&self) -> Result<NativeParentHandle, NativeUiError> {
        Err(NativeUiError::PlatformBackendUnavailable("Linux"))
    }

    fn show(&mut self) -> Result<(), NativeUiError> {
        Err(NativeUiError::PlatformBackendUnavailable("Linux"))
    }

    fn hide(&mut self) -> Result<(), NativeUiError> {
        Err(NativeUiError::PlatformBackendUnavailable("Linux"))
    }

    fn request_focus(&mut self) -> Result<(), NativeUiError> {
        Err(NativeUiError::PlatformBackendUnavailable("Linux"))
    }

    fn set_title(&mut self, _: &str) -> Result<(), NativeUiError> {
        Err(NativeUiError::PlatformBackendUnavailable("Linux"))
    }

    fn set_constraints(&mut self, _: NativeWindowConstraints) -> Result<(), NativeUiError> {
        Err(NativeUiError::PlatformBackendUnavailable("Linux"))
    }

    fn set_client_size(&mut self, _: NativeWindowSize) -> Result<(), NativeUiError> {
        Err(NativeUiError::PlatformBackendUnavailable("Linux"))
    }

    fn metrics(&self) -> Result<NativeWindowMetrics, NativeUiError> {
        Err(NativeUiError::PlatformBackendUnavailable("Linux"))
    }
}

impl NativeUiPlatform for LinuxNativeUi {
    type Window = LinuxNativeWindow;
    type WakeHandle = UnavailableWakeHandle;

    fn initialize() -> Result<(Self, Self::WakeHandle), NativeUiError> {
        Err(NativeUiError::PlatformBackendUnavailable("Linux"))
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
        Err(NativeUiError::PlatformBackendUnavailable("Linux"))
    }

    fn poll_events(&mut self, _: impl FnMut(NativeWindowEvent)) -> Result<(), NativeUiError> {
        Err(NativeUiError::PlatformBackendUnavailable("Linux"))
    }

    fn pump(&mut self) -> Result<(), NativeUiError> {
        Err(NativeUiError::PlatformBackendUnavailable("Linux"))
    }
}
