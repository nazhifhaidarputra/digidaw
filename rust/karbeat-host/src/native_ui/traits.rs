use crate::native_ui::{
    NativeParentHandle, NativeSurfaceCapabilities, NativeUiError, NativeWindowEvent,
    NativeWindowId, NativeWindowMetrics, NativeWindowSpec,
};

use super::{NativeWindowConstraints, NativeWindowSize};

pub trait NativeWindow {
    fn id(&self) -> NativeWindowId;
    fn surface_kind(&self) -> super::NativeSurfaceKind;
    fn parent_handle(&self) -> Result<NativeParentHandle, NativeUiError>;
    fn show(&mut self) -> Result<(), NativeUiError>;
    fn hide(&mut self) -> Result<(), NativeUiError>;
    fn request_focus(&mut self) -> Result<(), NativeUiError>;
    fn set_title(&mut self, title: &str) -> Result<(), NativeUiError>;
    fn set_constraints(
        &mut self,
        constraints: NativeWindowConstraints,
    ) -> Result<(), NativeUiError>;
    fn set_client_size(&mut self, size: NativeWindowSize) -> Result<(), NativeUiError>;
    fn metrics(&self) -> Result<NativeWindowMetrics, NativeUiError>;
}

pub trait NativeUiWakeHandle {
    fn wake(&self) -> Result<(), NativeUiError>;
}

pub trait NativeUiPlatform: Sized + 'static {
    type Window: NativeWindow;
    type WakeHandle: NativeUiWakeHandle + Clone + Send + Sync + 'static;

    fn initialize() -> Result<(Self, Self::WakeHandle), NativeUiError>;
    fn is_owner_thread(&self) -> bool;
    fn capabilities(&self) -> NativeSurfaceCapabilities;
    fn create_window(
        &mut self,
        id: NativeWindowId,
        spec: &NativeWindowSpec<'_>,
    ) -> Result<Self::Window, NativeUiError>;
    fn poll_events(&mut self, emit: impl FnMut(NativeWindowEvent)) -> Result<(), NativeUiError>;
    fn pump(&mut self) -> Result<(), NativeUiError>;
}
