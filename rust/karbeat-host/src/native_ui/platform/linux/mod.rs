mod wayland;
mod x11;

use std::thread::{self, ThreadId};

use crate::native_ui::{
    GlibWakeHandle, NativeParentHandle, NativeSurfaceCapabilities, NativeSurfaceKind,
    NativeUiError, NativeUiPlatform, NativeWindow, NativeWindowConstraints, NativeWindowEvent,
    NativeWindowId, NativeWindowMetrics, NativeWindowSize, NativeWindowSpec,
};

use self::{
    wayland::{WaylandBackend, WaylandWindow},
    x11::{X11Backend, X11Window},
};

pub struct LinuxNativeUi {
    owner: ThreadId,
    x11: Option<X11Backend>,
    wayland: Option<WaylandBackend>,
}

pub enum LinuxNativeWindow {
    X11(X11Window),
    Wayland(WaylandWindow),
}

impl NativeWindow for LinuxNativeWindow {
    fn id(&self) -> NativeWindowId {
        match self {
            Self::X11(window) => window.id(),
            Self::Wayland(window) => window.id(),
        }
    }

    fn surface_kind(&self) -> NativeSurfaceKind {
        match self {
            Self::X11(window) => window.surface_kind(),
            Self::Wayland(window) => window.surface_kind(),
        }
    }

    fn parent_handle(&self) -> Result<NativeParentHandle, NativeUiError> {
        match self {
            Self::X11(window) => window.parent_handle(),
            Self::Wayland(window) => window.parent_handle(),
        }
    }

    fn show(&mut self) -> Result<(), NativeUiError> {
        match self {
            Self::X11(window) => window.show(),
            Self::Wayland(window) => window.show(),
        }
    }

    fn hide(&mut self) -> Result<(), NativeUiError> {
        match self {
            Self::X11(window) => window.hide(),
            Self::Wayland(window) => window.hide(),
        }
    }

    fn request_focus(&mut self) -> Result<(), NativeUiError> {
        match self {
            Self::X11(window) => window.request_focus(),
            Self::Wayland(window) => window.request_focus(),
        }
    }

    fn set_title(&mut self, title: &str) -> Result<(), NativeUiError> {
        match self {
            Self::X11(window) => window.set_title(title),
            Self::Wayland(window) => window.set_title(title),
        }
    }

    fn set_constraints(
        &mut self,
        constraints: NativeWindowConstraints,
    ) -> Result<(), NativeUiError> {
        match self {
            Self::X11(window) => window.set_constraints(constraints),
            Self::Wayland(window) => window.set_constraints(constraints),
        }
    }

    fn set_client_size(&mut self, size: NativeWindowSize) -> Result<(), NativeUiError> {
        match self {
            Self::X11(window) => window.set_client_size(size),
            Self::Wayland(window) => window.set_client_size(size),
        }
    }

    fn metrics(&self) -> Result<NativeWindowMetrics, NativeUiError> {
        match self {
            Self::X11(window) => window.metrics(),
            Self::Wayland(window) => window.metrics(),
        }
    }
}

impl NativeUiPlatform for LinuxNativeUi {
    type Window = LinuxNativeWindow;
    type WakeHandle = GlibWakeHandle;

    fn initialize() -> Result<(Self, Self::WakeHandle), NativeUiError> {
        Ok((
            Self {
                owner: thread::current().id(),
                x11: X11Backend::connect().ok(),
                wayland: WaylandBackend::connect().ok(),
            },
            GlibWakeHandle,
        ))
    }

    fn is_owner_thread(&self) -> bool {
        self.owner == thread::current().id()
    }

    fn capabilities(&self) -> NativeSurfaceCapabilities {
        NativeSurfaceCapabilities {
            x11: self.x11.is_some(),
            wayland: self.wayland.is_some(),
            ..NativeSurfaceCapabilities::default()
        }
    }

    fn create_window(
        &mut self,
        id: NativeWindowId,
        spec: &NativeWindowSpec<'_>,
    ) -> Result<Self::Window, NativeUiError> {
        self.ensure_owner()?;
        spec.validate()?;
        match self.capabilities().select(spec.preferred_surface)? {
            NativeSurfaceKind::X11 => self
                .x11
                .as_mut()
                .ok_or(NativeUiError::DisplayUnavailable)?
                .create_window(id, spec)
                .map(LinuxNativeWindow::X11),
            NativeSurfaceKind::Wayland => self
                .wayland
                .as_mut()
                .ok_or(NativeUiError::DisplayUnavailable)?
                .create_window(id, spec)
                .map(LinuxNativeWindow::Wayland),
            kind => Err(NativeUiError::SurfaceUnsupported(
                crate::native_ui::NativeSurfacePreference::Require(kind),
            )),
        }
    }

    fn poll_events(
        &mut self,
        mut emit: impl FnMut(NativeWindowEvent),
    ) -> Result<(), NativeUiError> {
        self.ensure_owner()?;
        if let Some(x11) = self.x11.as_mut() {
            x11.poll_events(&mut emit)?;
        }
        if let Some(wayland) = self.wayland.as_mut() {
            wayland.poll_events(&mut emit)?;
        }
        Ok(())
    }

    fn pump(&mut self) -> Result<(), NativeUiError> {
        self.ensure_owner()?;
        if let Some(x11) = self.x11.as_mut() {
            x11.flush()?;
        }
        if let Some(wayland) = self.wayland.as_mut() {
            wayland.flush()?;
        }
        Ok(())
    }
}

impl LinuxNativeUi {
    fn ensure_owner(&self) -> Result<(), NativeUiError> {
        if self.is_owner_thread() {
            Ok(())
        } else {
            Err(NativeUiError::WrongThread)
        }
    }
}
