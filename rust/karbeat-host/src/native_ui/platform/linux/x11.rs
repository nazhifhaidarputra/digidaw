use std::{
    cell::{Cell, RefCell},
    collections::{HashMap, VecDeque},
    num::NonZeroU32,
    os::fd::AsRawFd,
    rc::{Rc, Weak},
};

use glib::ControlFlow;
use raw_window_handle::{RawDisplayHandle, RawWindowHandle, XcbDisplayHandle, XcbWindowHandle};
use x11rb::{
    CURRENT_TIME,
    connection::Connection,
    properties::WmSizeHints,
    protocol::{
        Event,
        xproto::{
            Atom, AtomEnum, ChangeWindowAttributesAux, ClientMessageEvent, ConfigureNotifyEvent,
            ConfigureWindowAux, ConnectionExt as _, CreateWindowAux, EventMask, InputFocus,
            PropMode, StackMode, Window, WindowClass,
        },
    },
    resource_manager::new_from_resource_manager,
    rust_connection::RustConnection,
    wrapper::ConnectionExt as _,
};

use crate::native_ui::{
    NativeParentHandle, NativeSurfaceKind, NativeUiError, NativeWindow, NativeWindowConstraints,
    NativeWindowEvent, NativeWindowId, NativeWindowMetrics, NativeWindowSize, NativeWindowSpec,
    UiFdSource, install_ui_fd_source,
};

struct X11Atoms {
    wm_protocols: Atom,
    wm_delete_window: Atom,
    utf8_string: Atom,
    net_wm_name: Atom,
    resource_manager: Atom,
}

struct X11Shared {
    connection: RustConnection,
    screen_num: usize,
    root: Window,
    root_depth: u8,
    root_visual: u32,
    atoms: X11Atoms,
    windows: RefCell<HashMap<Window, Weak<X11WindowState>>>,
    pending_events: RefCell<VecDeque<Event>>,
    pending_error: RefCell<Option<String>>,
    scale_factor: Cell<f64>,
}

struct X11WindowState {
    id: NativeWindowId,
    xid: Window,
    metrics: Cell<NativeWindowMetrics>,
    destroyed: Cell<bool>,
}

pub(super) struct X11Backend {
    _fd_source: UiFdSource,
    shared: Rc<X11Shared>,
}

pub struct X11Window {
    shared: Rc<X11Shared>,
    state: Rc<X11WindowState>,
}

impl X11Backend {
    pub(super) fn connect() -> Result<Self, NativeUiError> {
        let (connection, screen_num) = x11rb::connect(None).map_err(native_error)?;
        let screen =
            connection.setup().roots.get(screen_num).ok_or_else(|| {
                NativeUiError::NativeOperationFailed("X11 screen is missing".into())
            })?;
        let root = screen.root;
        let root_depth = screen.root_depth;
        let root_visual = screen.root_visual;
        let atoms = X11Atoms {
            wm_protocols: intern_atom(&connection, b"WM_PROTOCOLS")?,
            wm_delete_window: intern_atom(&connection, b"WM_DELETE_WINDOW")?,
            utf8_string: intern_atom(&connection, b"UTF8_STRING")?,
            net_wm_name: intern_atom(&connection, b"_NET_WM_NAME")?,
            resource_manager: intern_atom(&connection, b"RESOURCE_MANAGER")?,
        };
        let scale_factor = read_xft_scale(&connection);
        connection
            .change_window_attributes(
                root,
                &ChangeWindowAttributesAux::new().event_mask(EventMask::PROPERTY_CHANGE),
            )
            .map_err(native_error)?;
        connection.flush().map_err(native_error)?;
        let shared = Rc::new(X11Shared {
            connection,
            screen_num,
            root,
            root_depth,
            root_visual,
            atoms,
            windows: RefCell::new(HashMap::new()),
            pending_events: RefCell::new(VecDeque::new()),
            pending_error: RefCell::new(None),
            scale_factor: Cell::new(scale_factor),
        });
        let weak = Rc::downgrade(&shared);
        let fd = shared.connection.stream().as_raw_fd();
        let fd_source = install_ui_fd_source(fd, move || {
            let Some(shared) = weak.upgrade() else {
                return ControlFlow::Break;
            };
            match shared.drain_connection() {
                Ok(()) => ControlFlow::Continue,
                Err(error) => {
                    *shared.pending_error.borrow_mut() = Some(error.to_string());
                    ControlFlow::Break
                }
            }
        })?;
        Ok(Self {
            _fd_source: fd_source,
            shared,
        })
    }

    pub(super) fn create_window(
        &mut self,
        id: NativeWindowId,
        spec: &NativeWindowSpec<'_>,
    ) -> Result<X11Window, NativeUiError> {
        spec.validate()?;
        let xid = self.shared.connection.generate_id().map_err(native_error)?;
        let width = u16::try_from(spec.initial_size.width).map_err(native_error)?;
        let height = u16::try_from(spec.initial_size.height).map_err(native_error)?;
        let attributes = CreateWindowAux::new().event_mask(
            EventMask::STRUCTURE_NOTIFY | EventMask::FOCUS_CHANGE | EventMask::PROPERTY_CHANGE,
        );
        self.shared
            .connection
            .create_window(
                self.shared.root_depth,
                xid,
                self.shared.root,
                0,
                0,
                width,
                height,
                0,
                WindowClass::INPUT_OUTPUT,
                self.shared.root_visual,
                &attributes,
            )
            .map_err(native_error)?
            .check()
            .map_err(native_error)?;

        let state = Rc::new(X11WindowState {
            id,
            xid,
            metrics: Cell::new(NativeWindowMetrics {
                client_size: spec.initial_size,
                scale_factor: self.shared.scale_factor.get(),
            }),
            destroyed: Cell::new(false),
        });
        self.shared
            .windows
            .borrow_mut()
            .insert(xid, Rc::downgrade(&state));
        let mut window = X11Window {
            shared: self.shared.clone(),
            state,
        };
        if let Err(error) = window.configure(spec) {
            drop(window);
            return Err(error);
        }
        self.shared.connection.flush().map_err(native_error)?;
        Ok(window)
    }

    pub(super) fn poll_events(
        &mut self,
        emit: &mut impl FnMut(NativeWindowEvent),
    ) -> Result<(), NativeUiError> {
        self.shared.drain_connection()?;
        if let Some(error) = self.shared.pending_error.borrow_mut().take() {
            return Err(NativeUiError::EventDispatchFailed(error));
        }
        while let Some(event) = self.shared.pending_events.borrow_mut().pop_front() {
            self.handle_event(event, emit);
        }
        Ok(())
    }

    pub(super) fn flush(&mut self) -> Result<(), NativeUiError> {
        self.shared.connection.flush().map_err(native_error)
    }

    fn handle_event(&self, event: Event, emit: &mut impl FnMut(NativeWindowEvent)) {
        match event {
            Event::ClientMessage(event) => self.handle_client_message(event, emit),
            Event::ConfigureNotify(event) => self.handle_configure(event, emit),
            Event::FocusIn(event) => {
                if let Some(state) = self.window_state(event.event) {
                    emit(NativeWindowEvent::FocusChanged {
                        window: state.id,
                        focused: true,
                    });
                }
            }
            Event::FocusOut(event) => {
                if let Some(state) = self.window_state(event.event) {
                    emit(NativeWindowEvent::FocusChanged {
                        window: state.id,
                        focused: false,
                    });
                }
            }
            Event::DestroyNotify(event) => {
                if let Some(state) = self.window_state(event.window) {
                    state.destroyed.set(true);
                    self.shared.windows.borrow_mut().remove(&event.window);
                    emit(NativeWindowEvent::Destroyed { window: state.id });
                }
            }
            Event::PropertyNotify(event)
                if event.window == self.shared.root
                    && event.atom == self.shared.atoms.resource_manager =>
            {
                self.update_scale(emit);
            }
            _ => {}
        }
    }

    fn handle_client_message(
        &self,
        event: ClientMessageEvent,
        emit: &mut impl FnMut(NativeWindowEvent),
    ) {
        if event.type_ == self.shared.atoms.wm_protocols
            && event.data.as_data32()[0] == self.shared.atoms.wm_delete_window
            && let Some(state) = self.window_state(event.window)
        {
            emit(NativeWindowEvent::CloseRequested { window: state.id });
        }
    }

    fn handle_configure(
        &self,
        event: ConfigureNotifyEvent,
        emit: &mut impl FnMut(NativeWindowEvent),
    ) {
        let Some(state) = self.window_state(event.window) else {
            return;
        };
        let Ok(size) = NativeWindowSize::new(u32::from(event.width), u32::from(event.height))
        else {
            return;
        };
        let previous = state.metrics.get();
        if previous.client_size != size {
            state.metrics.set(NativeWindowMetrics {
                client_size: size,
                ..previous
            });
            emit(NativeWindowEvent::Resized {
                window: state.id,
                size,
            });
        }
    }

    fn window_state(&self, xid: Window) -> Option<Rc<X11WindowState>> {
        self.shared.windows.borrow().get(&xid)?.upgrade()
    }

    fn update_scale(&self, emit: &mut impl FnMut(NativeWindowEvent)) {
        let scale_factor = read_xft_scale(&self.shared.connection);
        if (scale_factor - self.shared.scale_factor.get()).abs() < f64::EPSILON {
            return;
        }
        self.shared.scale_factor.set(scale_factor);
        let states: Vec<_> = self
            .shared
            .windows
            .borrow()
            .values()
            .filter_map(Weak::upgrade)
            .collect();
        for state in states {
            let metrics = NativeWindowMetrics {
                client_size: state.metrics.get().client_size,
                scale_factor,
            };
            state.metrics.set(metrics);
            emit(NativeWindowEvent::ScaleFactorChanged {
                window: state.id,
                metrics,
            });
        }
    }
}

impl X11Shared {
    fn drain_connection(&self) -> Result<(), NativeUiError> {
        while let Some(event) = self.connection.poll_for_event().map_err(native_error)? {
            self.pending_events.borrow_mut().push_back(event);
        }
        Ok(())
    }
}

impl NativeWindow for X11Window {
    fn id(&self) -> NativeWindowId {
        self.state.id
    }

    fn surface_kind(&self) -> NativeSurfaceKind {
        NativeSurfaceKind::X11
    }

    fn parent_handle(&self) -> Result<NativeParentHandle, NativeUiError> {
        self.ensure_alive()?;
        let xid = NonZeroU32::new(self.state.xid).ok_or(NativeUiError::InvalidHandle)?;
        let screen = i32::try_from(self.shared.screen_num).map_err(native_error)?;
        Ok(NativeParentHandle {
            kind: NativeSurfaceKind::X11,
            window: RawWindowHandle::Xcb(XcbWindowHandle::new(xid)),
            display: Some(RawDisplayHandle::Xcb(XcbDisplayHandle::new(None, screen))),
        })
    }

    fn show(&mut self) -> Result<(), NativeUiError> {
        self.ensure_alive()?;
        self.shared
            .connection
            .map_window(self.state.xid)
            .map_err(native_error)?
            .check()
            .map_err(native_error)?;
        self.shared.connection.flush().map_err(native_error)
    }

    fn hide(&mut self) -> Result<(), NativeUiError> {
        self.ensure_alive()?;
        self.shared
            .connection
            .unmap_window(self.state.xid)
            .map_err(native_error)?
            .check()
            .map_err(native_error)?;
        self.shared.connection.flush().map_err(native_error)
    }

    fn request_focus(&mut self) -> Result<(), NativeUiError> {
        self.ensure_alive()?;
        self.shared
            .connection
            .configure_window(
                self.state.xid,
                &ConfigureWindowAux::new().stack_mode(StackMode::ABOVE),
            )
            .map_err(native_error)?;
        self.shared
            .connection
            .set_input_focus(InputFocus::PARENT, self.state.xid, CURRENT_TIME)
            .map_err(native_error)?;
        self.shared.connection.flush().map_err(native_error)
    }

    fn set_title(&mut self, title: &str) -> Result<(), NativeUiError> {
        self.ensure_alive()?;
        self.shared
            .connection
            .change_property8(
                PropMode::REPLACE,
                self.state.xid,
                self.shared.atoms.net_wm_name,
                self.shared.atoms.utf8_string,
                title.as_bytes(),
            )
            .map_err(native_error)?;
        self.shared
            .connection
            .change_property8(
                PropMode::REPLACE,
                self.state.xid,
                AtomEnum::WM_NAME,
                AtomEnum::STRING,
                title.as_bytes(),
            )
            .map_err(native_error)?;
        Ok(())
    }

    fn set_constraints(
        &mut self,
        constraints: NativeWindowConstraints,
    ) -> Result<(), NativeUiError> {
        self.ensure_alive()?;
        constraints.validate()?;
        let mut hints = WmSizeHints::new();
        hints.min_size = constraints.min.map(size_as_i32_pair).transpose()?;
        hints.max_size = constraints.max.map(size_as_i32_pair).transpose()?;
        hints
            .set_normal_hints(&self.shared.connection, self.state.xid)
            .map_err(native_error)?;
        Ok(())
    }

    fn set_client_size(&mut self, size: NativeWindowSize) -> Result<(), NativeUiError> {
        self.ensure_alive()?;
        size.validate()?;
        self.shared
            .connection
            .configure_window(
                self.state.xid,
                &ConfigureWindowAux::new()
                    .width(size.width)
                    .height(size.height),
            )
            .map_err(native_error)?;
        self.shared.connection.flush().map_err(native_error)
    }

    fn metrics(&self) -> Result<NativeWindowMetrics, NativeUiError> {
        self.ensure_alive()?;
        Ok(self.state.metrics.get())
    }
}

impl X11Window {
    fn configure(&mut self, spec: &NativeWindowSpec<'_>) -> Result<(), NativeUiError> {
        self.shared
            .connection
            .change_property32(
                PropMode::REPLACE,
                self.state.xid,
                self.shared.atoms.wm_protocols,
                AtomEnum::ATOM,
                &[self.shared.atoms.wm_delete_window],
            )
            .map_err(native_error)?;
        self.shared
            .connection
            .change_property8(
                PropMode::REPLACE,
                self.state.xid,
                AtomEnum::WM_CLASS,
                AtomEnum::STRING,
                b"digidaw\0DigiDAW\0",
            )
            .map_err(native_error)?;
        self.set_title(spec.title)?;
        self.set_constraints(spec.constraints)?;
        if spec.initially_visible {
            self.show()?;
        }
        Ok(())
    }

    fn ensure_alive(&self) -> Result<(), NativeUiError> {
        if self.state.destroyed.get() {
            Err(NativeUiError::WindowDestroyed)
        } else {
            Ok(())
        }
    }
}

impl Drop for X11Window {
    fn drop(&mut self) {
        self.shared.windows.borrow_mut().remove(&self.state.xid);
        if !self.state.destroyed.replace(true) {
            if let Ok(cookie) = self.shared.connection.destroy_window(self.state.xid) {
                drop(cookie.check());
            }
            drop(self.shared.connection.flush());
        }
    }
}

fn intern_atom(connection: &RustConnection, name: &[u8]) -> Result<Atom, NativeUiError> {
    connection
        .intern_atom(false, name)
        .map_err(native_error)?
        .reply()
        .map(|reply| reply.atom)
        .map_err(native_error)
}

fn size_as_i32_pair(size: NativeWindowSize) -> Result<(i32, i32), NativeUiError> {
    Ok((
        i32::try_from(size.width).map_err(native_error)?,
        i32::try_from(size.height).map_err(native_error)?,
    ))
}

fn native_error(error: impl std::fmt::Display) -> NativeUiError {
    NativeUiError::NativeOperationFailed(error.to_string())
}

fn read_xft_scale(connection: &RustConnection) -> f64 {
    let dpi = new_from_resource_manager(connection)
        .ok()
        .flatten()
        .and_then(|database| {
            database
                .get_string("Xft.dpi", "")
                .and_then(|dpi| dpi.parse::<f64>().ok())
        })
        .filter(|dpi| dpi.is_finite() && *dpi > 0.0)
        .unwrap_or(96.0);
    (dpi / 96.0).clamp(0.5, 4.0)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::native_ui::{NativeSurfacePreference, NativeUiDispatcher};
    use std::num::NonZeroU64;

    #[test]
    #[ignore = "requires a live X11 or XWayland display"]
    fn creates_resizes_and_destroys_a_live_window() -> Result<(), NativeUiError> {
        NativeUiDispatcher::initialize()?;
        while !NativeUiDispatcher::is_owner_thread() {
            glib::MainContext::default().iteration(true);
        }
        let mut backend = X11Backend::connect()?;
        let mut window = backend.create_window(
            NativeWindowId::new(NonZeroU64::MIN),
            &NativeWindowSpec {
                title: "DigiDAW native UI integration test",
                initial_size: NativeWindowSize::new(320, 200)?,
                constraints: NativeWindowConstraints::resizable(),
                initially_visible: false,
                preferred_surface: NativeSurfacePreference::Require(NativeSurfaceKind::X11),
            },
        )?;
        assert!(matches!(
            window.parent_handle()?.window,
            RawWindowHandle::Xcb(_)
        ));
        window.show()?;
        window.set_client_size(NativeWindowSize::new(360, 240)?)?;
        backend.flush()?;
        drop(window);
        Ok(())
    }
}
