use std::{
    cell::{Cell, RefCell},
    collections::{HashMap, VecDeque},
    io::ErrorKind,
    num::NonZeroU32,
    os::fd::AsRawFd,
    ptr::NonNull,
    rc::{Rc, Weak},
};

use raw_window_handle::{
    RawDisplayHandle, RawWindowHandle, WaylandDisplayHandle, WaylandWindowHandle,
};
use smithay_client_toolkit::{
    activation::{ActivationHandler, ActivationState, RequestData},
    compositor::{CompositorHandler, CompositorState},
    delegate_registry,
    output::{OutputHandler, OutputState},
    registry::{ProvidesRegistryState, RegistryState},
    registry_handlers,
    shell::{
        WaylandSurface,
        xdg::{
            XdgShell, XdgSurface,
            window::{Window, WindowConfigure, WindowDecorations, WindowHandler},
        },
    },
};
use wayland_client::{
    Connection, EventQueue, Proxy, QueueHandle,
    backend::{ObjectId, ReadEventsGuard, WaylandError},
    globals::registry_queue_init,
    protocol::{wl_output, wl_surface},
};

use crate::native_ui::{
    NativeParentHandle, NativeSurfaceKind, NativeUiControlFlow, NativeUiError, NativeWindow,
    NativeWindowConstraints, NativeWindowEvent, NativeWindowId, NativeWindowMetrics,
    NativeWindowSize, NativeWindowSpec, UiFdSource, install_ui_fd_source,
};

struct WaylandWindowState {
    id: NativeWindowId,
    metrics: Cell<NativeWindowMetrics>,
    destroyed: Cell<bool>,
}

struct WaylandState {
    registry_state: RegistryState,
    output_state: OutputState,
    activation_state: Option<ActivationState>,
    windows: HashMap<ObjectId, Weak<WaylandWindowState>>,
    pending_events: VecDeque<NativeWindowEvent>,
}

struct WaylandIo {
    event_queue: EventQueue<WaylandState>,
    state: WaylandState,
}

struct WaylandShared {
    connection: Connection,
    queue_handle: QueueHandle<WaylandState>,
    compositor: CompositorState,
    xdg_shell: XdgShell,
    io: RefCell<WaylandIo>,
    prepared_read: RefCell<Option<ReadEventsGuard>>,
    pending_error: RefCell<Option<String>>,
}

pub(super) struct WaylandBackend {
    _fd_source: UiFdSource,
    shared: Rc<WaylandShared>,
}

pub struct WaylandWindow {
    shared: Rc<WaylandShared>,
    window: Window,
    state: Rc<WaylandWindowState>,
}

impl WaylandBackend {
    pub(super) fn connect() -> Result<Self, NativeUiError> {
        let connection = Connection::connect_to_env().map_err(native_error)?;
        let (globals, mut event_queue) = registry_queue_init(&connection).map_err(native_error)?;
        let queue_handle = event_queue.handle();
        let compositor = CompositorState::bind(&globals, &queue_handle).map_err(native_error)?;
        let xdg_shell = XdgShell::bind(&globals, &queue_handle).map_err(native_error)?;
        let mut state = WaylandState {
            registry_state: RegistryState::new(&globals),
            output_state: OutputState::new(&globals, &queue_handle),
            activation_state: ActivationState::bind(&globals, &queue_handle).ok(),
            windows: HashMap::new(),
            pending_events: VecDeque::new(),
        };
        event_queue.roundtrip(&mut state).map_err(native_error)?;
        let shared = Rc::new(WaylandShared {
            connection,
            queue_handle,
            compositor,
            xdg_shell,
            io: RefCell::new(WaylandIo { event_queue, state }),
            prepared_read: RefCell::new(None),
            pending_error: RefCell::new(None),
        });
        shared.prepare_next_read()?;
        let weak = Rc::downgrade(&shared);
        let fd = shared.connection.backend().poll_fd().as_raw_fd();
        let fd_source = install_ui_fd_source(fd, move || {
            let Some(shared) = weak.upgrade() else {
                return NativeUiControlFlow::Break;
            };
            match shared.read_and_dispatch() {
                Ok(()) => NativeUiControlFlow::Continue,
                Err(error) => {
                    *shared.pending_error.borrow_mut() = Some(error.to_string());
                    NativeUiControlFlow::Break
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
    ) -> Result<WaylandWindow, NativeUiError> {
        spec.validate()?;
        let surface = self
            .shared
            .compositor
            .create_surface(&self.shared.queue_handle);
        let window = self.shared.xdg_shell.create_window(
            surface,
            WindowDecorations::RequestServer,
            &self.shared.queue_handle,
        );
        window.set_app_id("com.digidaw.DigiDAW");
        window.set_title(spec.title);
        apply_constraints(&window, spec.constraints);
        window.xdg_surface().set_window_geometry(
            0,
            0,
            size_as_i32(spec.initial_size.width)?,
            size_as_i32(spec.initial_size.height)?,
        );
        let state = Rc::new(WaylandWindowState {
            id,
            metrics: Cell::new(NativeWindowMetrics {
                client_size: spec.initial_size,
                scale_factor: 1.0,
            }),
            destroyed: Cell::new(false),
        });
        self.shared
            .io
            .borrow_mut()
            .state
            .windows
            .insert(window.wl_surface().id(), Rc::downgrade(&state));
        if spec.initially_visible {
            window.commit();
        }
        self.shared.flush()?;
        Ok(WaylandWindow {
            shared: self.shared.clone(),
            window,
            state,
        })
    }

    pub(super) fn poll_events(
        &mut self,
        emit: &mut impl FnMut(NativeWindowEvent),
    ) -> Result<(), NativeUiError> {
        self.shared.dispatch_pending()?;
        if let Some(error) = self.shared.pending_error.borrow_mut().take() {
            return Err(NativeUiError::EventDispatchFailed(error));
        }
        let mut io = self.shared.io.borrow_mut();
        while let Some(event) = io.state.pending_events.pop_front() {
            emit(event);
        }
        Ok(())
    }

    pub(super) fn flush(&mut self) -> Result<(), NativeUiError> {
        self.shared.flush()
    }
}

impl WaylandShared {
    fn read_and_dispatch(&self) -> Result<(), NativeUiError> {
        if let Some(guard) = self.prepared_read.borrow_mut().take() {
            match guard.read() {
                Ok(_) => {}
                Err(WaylandError::Io(error)) if error.kind() == ErrorKind::WouldBlock => {}
                Err(error) => return Err(native_error(error)),
            }
        }
        self.dispatch_pending()?;
        self.flush()?;
        self.prepare_next_read()
    }

    fn dispatch_pending(&self) -> Result<(), NativeUiError> {
        let mut io = self.io.borrow_mut();
        let WaylandIo { event_queue, state } = &mut *io;
        event_queue.dispatch_pending(state).map_err(native_error)?;
        Ok(())
    }

    fn flush(&self) -> Result<(), NativeUiError> {
        match self.connection.flush() {
            Ok(()) => Ok(()),
            Err(WaylandError::Io(error)) if error.kind() == ErrorKind::WouldBlock => Ok(()),
            Err(error) => Err(native_error(error)),
        }
    }

    fn prepare_next_read(&self) -> Result<(), NativeUiError> {
        if self.prepared_read.borrow().is_some() {
            return Ok(());
        }
        if let Some(guard) = self.connection.prepare_read() {
            *self.prepared_read.borrow_mut() = Some(guard);
            return Ok(());
        }
        self.connection
            .backend()
            .dispatch_inner_queue()
            .map_err(native_error)?;
        self.dispatch_pending()?;
        let guard = self.connection.prepare_read().ok_or_else(|| {
            NativeUiError::EventDispatchFailed(
                "Wayland connection could not prepare a nonblocking read".into(),
            )
        })?;
        *self.prepared_read.borrow_mut() = Some(guard);
        Ok(())
    }
}

impl NativeWindow for WaylandWindow {
    fn id(&self) -> NativeWindowId {
        self.state.id
    }

    fn surface_kind(&self) -> NativeSurfaceKind {
        NativeSurfaceKind::Wayland
    }

    fn parent_handle(&self) -> Result<NativeParentHandle, NativeUiError> {
        self.ensure_alive()?;
        let surface = NonNull::new(self.window.wl_surface().id().as_ptr().cast())
            .ok_or(NativeUiError::InvalidHandle)?;
        let display = NonNull::new(self.shared.connection.backend().display_ptr().cast())
            .ok_or(NativeUiError::InvalidHandle)?;
        Ok(NativeParentHandle {
            kind: NativeSurfaceKind::Wayland,
            window: RawWindowHandle::Wayland(WaylandWindowHandle::new(surface)),
            display: Some(RawDisplayHandle::Wayland(WaylandDisplayHandle::new(
                display,
            ))),
        })
    }

    fn show(&mut self) -> Result<(), NativeUiError> {
        self.ensure_alive()?;
        self.window.commit();
        self.shared.flush()
    }

    fn hide(&mut self) -> Result<(), NativeUiError> {
        self.ensure_alive()?;
        self.window.wl_surface().attach(None, 0, 0);
        self.window.commit();
        self.shared.flush()
    }

    fn request_focus(&mut self) -> Result<(), NativeUiError> {
        self.ensure_alive()?;
        let io = self.shared.io.borrow();
        let activation = io.state.activation_state.as_ref().ok_or_else(|| {
            NativeUiError::NativeOperationFailed("Wayland compositor has no xdg-activation".into())
        })?;
        activation.request_token(
            &self.shared.queue_handle,
            RequestData {
                seat_and_serial: None,
                surface: Some(self.window.wl_surface().clone()),
                app_id: Some("com.digidaw.DigiDAW".into()),
                udata: self.state.id,
            },
        );
        drop(io);
        self.shared.flush()
    }

    fn set_title(&mut self, title: &str) -> Result<(), NativeUiError> {
        self.ensure_alive()?;
        self.window.set_title(title);
        self.shared.flush()
    }

    fn set_constraints(
        &mut self,
        constraints: NativeWindowConstraints,
    ) -> Result<(), NativeUiError> {
        self.ensure_alive()?;
        constraints.validate()?;
        apply_constraints(&self.window, constraints);
        self.window.commit();
        self.shared.flush()
    }

    fn set_client_size(&mut self, size: NativeWindowSize) -> Result<(), NativeUiError> {
        self.ensure_alive()?;
        size.validate()?;
        self.window.xdg_surface().set_window_geometry(
            0,
            0,
            size_as_i32(size.width)?,
            size_as_i32(size.height)?,
        );
        let previous = self.state.metrics.get();
        self.state.metrics.set(NativeWindowMetrics {
            client_size: size,
            ..previous
        });
        self.window.commit();
        self.shared.flush()
    }

    fn metrics(&self) -> Result<NativeWindowMetrics, NativeUiError> {
        self.ensure_alive()?;
        Ok(self.state.metrics.get())
    }
}

impl WaylandWindow {
    fn ensure_alive(&self) -> Result<(), NativeUiError> {
        if self.state.destroyed.get() {
            Err(NativeUiError::WindowDestroyed)
        } else {
            Ok(())
        }
    }
}

impl Drop for WaylandWindow {
    fn drop(&mut self) {
        self.state.destroyed.set(true);
        self.shared
            .io
            .borrow_mut()
            .state
            .windows
            .remove(&self.window.wl_surface().id());
    }
}

impl CompositorHandler for WaylandState {
    fn scale_factor_changed(
        &mut self,
        _: &Connection,
        _: &QueueHandle<Self>,
        surface: &wl_surface::WlSurface,
        new_factor: i32,
    ) {
        let Some(state) = self.window_state(surface) else {
            return;
        };
        let scale_factor = f64::from(new_factor.max(1));
        let metrics = NativeWindowMetrics {
            client_size: state.metrics.get().client_size,
            scale_factor,
        };
        if metrics != state.metrics.get() {
            state.metrics.set(metrics);
            self.pending_events
                .push_back(NativeWindowEvent::ScaleFactorChanged {
                    window: state.id,
                    metrics,
                });
        }
    }

    fn transform_changed(
        &mut self,
        _: &Connection,
        _: &QueueHandle<Self>,
        _: &wl_surface::WlSurface,
        _: wl_output::Transform,
    ) {
    }

    fn frame(&mut self, _: &Connection, _: &QueueHandle<Self>, _: &wl_surface::WlSurface, _: u32) {}

    fn surface_enter(
        &mut self,
        _: &Connection,
        _: &QueueHandle<Self>,
        _: &wl_surface::WlSurface,
        _: &wl_output::WlOutput,
    ) {
    }

    fn surface_leave(
        &mut self,
        _: &Connection,
        _: &QueueHandle<Self>,
        _: &wl_surface::WlSurface,
        _: &wl_output::WlOutput,
    ) {
    }
}

impl WindowHandler for WaylandState {
    fn request_close(&mut self, _: &Connection, _: &QueueHandle<Self>, window: &Window) {
        if let Some(state) = self.window_state(window.wl_surface()) {
            self.pending_events
                .push_back(NativeWindowEvent::CloseRequested { window: state.id });
        }
    }

    fn configure(
        &mut self,
        _: &Connection,
        _: &QueueHandle<Self>,
        window: &Window,
        configure: WindowConfigure,
        _: u32,
    ) {
        let Some(state) = self.window_state(window.wl_surface()) else {
            return;
        };
        let previous = state.metrics.get();
        let width = configure
            .new_size
            .0
            .map_or(previous.client_size.width, NonZeroU32::get);
        let height = configure
            .new_size
            .1
            .map_or(previous.client_size.height, NonZeroU32::get);
        let Ok(size) = NativeWindowSize::new(width, height) else {
            return;
        };
        if size != previous.client_size {
            state.metrics.set(NativeWindowMetrics {
                client_size: size,
                ..previous
            });
            self.pending_events.push_back(NativeWindowEvent::Resized {
                window: state.id,
                size,
            });
        }
    }
}

impl OutputHandler for WaylandState {
    fn output_state(&mut self) -> &mut OutputState {
        &mut self.output_state
    }

    fn new_output(&mut self, _: &Connection, _: &QueueHandle<Self>, _: wl_output::WlOutput) {}

    fn update_output(&mut self, _: &Connection, _: &QueueHandle<Self>, _: wl_output::WlOutput) {}

    fn output_destroyed(&mut self, _: &Connection, _: &QueueHandle<Self>, _: wl_output::WlOutput) {}
}

impl ActivationHandler for WaylandState {
    type RequestUdata = NativeWindowId;

    fn new_token(&mut self, token: String, data: &RequestData<Self::RequestUdata>) {
        if let (Some(activation), Some(surface)) = (&self.activation_state, &data.surface) {
            activation.activate::<Self>(surface, token);
        }
    }
}

impl WaylandState {
    fn window_state(&self, surface: &wl_surface::WlSurface) -> Option<Rc<WaylandWindowState>> {
        self.windows.get(&surface.id())?.upgrade()
    }
}

delegate_registry!(WaylandState);

impl ProvidesRegistryState for WaylandState {
    fn registry(&mut self) -> &mut RegistryState {
        &mut self.registry_state
    }

    registry_handlers![OutputState];
}

smithay_client_toolkit::delegate_dispatch2!(WaylandState);

fn apply_constraints(window: &Window, constraints: NativeWindowConstraints) {
    window.set_min_size(constraints.min.map(|size| (size.width, size.height)));
    window.set_max_size(constraints.max.map(|size| (size.width, size.height)));
}

fn size_as_i32(value: u32) -> Result<i32, NativeUiError> {
    i32::try_from(value).map_err(native_error)
}

fn native_error(error: impl std::fmt::Display) -> NativeUiError {
    NativeUiError::NativeOperationFailed(error.to_string())
}

#[cfg(test)]
mod tests {
    use std::num::NonZeroU64;

    use super::*;
    use crate::native_ui::{NativeSurfacePreference, NativeUiDispatcher};

    #[test]
    #[ignore = "requires a live Wayland display"]
    fn creates_and_destroys_a_live_toplevel() -> Result<(), NativeUiError> {
        NativeUiDispatcher::initialize()?;
        while !NativeUiDispatcher::is_owner_thread() {
            glib::MainContext::default().iteration(true);
        }
        let mut backend = WaylandBackend::connect()?;
        let mut window = backend.create_window(
            NativeWindowId::new(NonZeroU64::MIN),
            &NativeWindowSpec {
                title: "DigiDAW Wayland integration test",
                initial_size: NativeWindowSize::new(320, 200)?,
                constraints: NativeWindowConstraints::resizable(),
                initially_visible: false,
                preferred_surface: NativeSurfacePreference::Require(NativeSurfaceKind::Wayland),
            },
        )?;
        assert!(matches!(
            window.parent_handle()?.window,
            RawWindowHandle::Wayland(_)
        ));
        window.show()?;
        window.set_client_size(NativeWindowSize::new(360, 240)?)?;
        backend.flush()?;
        drop(window);
        Ok(())
    }
}
