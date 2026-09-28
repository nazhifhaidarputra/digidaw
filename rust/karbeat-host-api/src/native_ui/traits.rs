use crate::native_ui::{
    NativeParentHandle, NativeSurfaceCapabilities, NativeUiError, NativeWindowEvent,
    NativeWindowId, NativeWindowMetrics, NativeWindowSpec,
};

use super::{NativeWindowConstraints, NativeWindowSize};

/// Operations provided by a host-owned platform window used to parent a plugin editor.
pub trait NativeWindow {
    /// Returns the process-local identifier used to route platform events.
    fn id(&self) -> NativeWindowId;
    /// Returns the raw-handle ABI exposed by this window.
    fn surface_kind(&self) -> super::NativeSurfaceKind;
    /// Returns borrowed raw parent handles valid only while this window remains alive.
    fn parent_handle(&self) -> Result<NativeParentHandle, NativeUiError>;
    /// Makes the native window visible.
    fn show(&mut self) -> Result<(), NativeUiError>;
    /// Hides the native window without destroying it.
    fn hide(&mut self) -> Result<(), NativeUiError>;
    /// Requests keyboard focus from the platform window manager.
    fn request_focus(&mut self) -> Result<(), NativeUiError>;
    /// Replaces the platform window title.
    fn set_title(&mut self, title: &str) -> Result<(), NativeUiError>;
    /// Applies plugin-supplied minimum and maximum client dimensions.
    fn set_constraints(
        &mut self,
        constraints: NativeWindowConstraints,
    ) -> Result<(), NativeUiError>;
    /// Requests exact client-area dimensions.
    fn set_client_size(&mut self, size: NativeWindowSize) -> Result<(), NativeUiError>;
    /// Reads current client dimensions and display scaling.
    fn metrics(&self) -> Result<NativeWindowMetrics, NativeUiError>;
}

/// Thread-safe handle that schedules native-UI work on the platform owner.
pub trait NativeUiWakeHandle {
    /// Wakes or schedules the native UI event loop.
    fn wake(&self) -> Result<(), NativeUiError>;
}

/// Platform backend that owns native windows and dispatches their events on one thread.
pub trait NativeUiPlatform: Sized + 'static {
    /// Concrete window implementation created by this backend.
    type Window: NativeWindow;
    /// Cross-thread wake handle associated with the backend event loop.
    type WakeHandle: NativeUiWakeHandle + Clone + Send + Sync + 'static;

    /// Initializes the backend on its owner thread and returns its wake handle.
    fn initialize() -> Result<(Self, Self::WakeHandle), NativeUiError>;
    /// Returns whether the caller is the backend's owner thread.
    fn is_owner_thread(&self) -> bool;
    /// Reports raw-handle surface kinds the initialized backend can create.
    fn capabilities(&self) -> NativeSurfaceCapabilities;
    /// Creates a host-owned native window from a validated specification.
    fn create_window(
        &mut self,
        id: NativeWindowId,
        spec: &NativeWindowSpec<'_>,
    ) -> Result<Self::Window, NativeUiError>;
    /// Drains currently pending platform events into `emit` without blocking.
    fn poll_events(&mut self, emit: impl FnMut(NativeWindowEvent)) -> Result<(), NativeUiError>;
    /// Flushes pending platform requests and performs required event-loop maintenance.
    fn pump(&mut self) -> Result<(), NativeUiError>;
}
