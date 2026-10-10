use karbeat_utils::typestate::{InvalidState, TransitionError};

use super::{
    NativeUiError, NativeWindow, NativeWindowEvent, NativeWindowId, NativeWindowMetrics,
    NativeWindowSize,
};

karbeat_utils::typestate! {
    /// Editor window lifecycle; [`NativeEditorLifecycle`] is its public snapshot.
    #[derive(Clone, Copy)]
    machine EditorWindow {
        shared: (),
        erased: #[derive(Clone, Copy)] AnyEditorWindow,
        states {
            #[derive(Clone, Copy)]
            Created as CreatedEditorWindow {}
            #[derive(Clone, Copy)]
            Attached as AttachedEditorWindow {}
            #[derive(Clone, Copy)]
            Visible as VisibleEditorWindow {}
            #[derive(Clone, Copy)]
            Closing as ClosingEditorWindow {}
            #[derive(Clone, Copy)]
            Closed as ClosedEditorWindow {}
        }
        transitions {
            Created => Attached: fn attach(shared, state) { Attached {} }

            // Re-showing a visible editor is allowed. The window is shown as part of the
            // transition so a platform failure leaves the state unchanged.
            Attached | Visible => Result<Visible, NativeUiError>: fn show(
                shared,
                state,
                show_window: &mut dyn FnMut() -> Result<(), NativeUiError>,
            ) {
                match show_window() {
                    Ok(()) => Ok(Visible {}),
                    Err(error) => Err((state, error)),
                }
            }

            Created | Attached | Visible => Closing: fn begin_close(shared, state) { Closing {} }

            // The platform destroyed the window outside normal host teardown.
            Created | Attached | Visible | Closing => Closing: fn destroyed(shared, state) {
                Closing {}
            }

            Closing => Closed: fn finish_close(shared, state) { Closed {} }
        }
    }
}

impl AnyEditorWindow {
    const fn lifecycle(&self) -> NativeEditorLifecycle {
        match self {
            Self::Created(_) => NativeEditorLifecycle::Created,
            Self::Attached(_) => NativeEditorLifecycle::Attached,
            Self::Visible(_) => NativeEditorLifecycle::Visible,
            Self::Closing(_) => NativeEditorLifecycle::Closing,
            Self::Closed(_) => NativeEditorLifecycle::Closed,
        }
    }
}

/// Host-side attachment and visibility state for one plugin editor window.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum NativeEditorLifecycle {
    /// Native window exists but the plugin view is not attached.
    Created,
    /// Plugin view is attached while the window remains hidden.
    Attached,
    /// Attached native window has been shown.
    Visible,
    /// Detachment or platform destruction has started.
    Closing,
    /// Window ownership was released and no further operations are valid.
    Closed,
}

/// Normalized editor event produced after binding-level filtering and validation.
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum NativeEditorEvent {
    /// Event did not belong to this binding or required no host action.
    Ignored,
    /// Platform confirmed the exact client size most recently requested by the host.
    ProgrammaticResizeAcknowledged,
    /// User, window manager, or plugin changed the client size independently.
    ExternalResize(NativeWindowSize),
    /// User or window manager requested editor closure.
    CloseRequested,
    /// Display scale or scaled client metrics changed.
    ScaleFactorChanged(NativeWindowMetrics),
    /// Window focus changed; the payload is `true` when focused.
    FocusChanged(bool),
    /// Platform destroyed the native window outside normal host teardown.
    Destroyed,
}

/// Validates editor lifecycle transitions and owns the corresponding native window.
///
/// The binding distinguishes acknowledgements of host-requested resizes from external changes,
/// and releases the platform window only during a valid `Closing` to `Closed` transition.
pub struct NativeEditorBinding<W: NativeWindow> {
    id: NativeWindowId,
    window: Option<W>,
    lifecycle: AnyEditorWindow,
    last_metrics: NativeWindowMetrics,
    pending_programmatic_resize: Option<NativeWindowSize>,
}

impl<W: NativeWindow> NativeEditorBinding<W> {
    /// Creates a binding in the `Created` state after validating initial window metrics.
    pub fn new(window: W) -> Result<Self, NativeUiError> {
        let id = window.id();
        let last_metrics = window.metrics()?;
        last_metrics.validate()?;
        Ok(Self {
            id,
            window: Some(window),
            lifecycle: AnyEditorWindow::Created(EditorWindow {
                shared: (),
                state: Created {},
            }),
            last_metrics,
            pending_programmatic_resize: None,
        })
    }

    /// Returns the identifier captured from the owned native window.
    pub const fn id(&self) -> NativeWindowId {
        self.id
    }

    /// Returns the current host-side editor lifecycle state.
    pub const fn lifecycle(&self) -> NativeEditorLifecycle {
        self.lifecycle.lifecycle()
    }

    fn invalid_transition(&self, to: NativeEditorLifecycle) -> NativeUiError {
        NativeUiError::InvalidLifecycleTransition {
            from: self.lifecycle(),
            to,
        }
    }

    /// Applies a run-time lifecycle transition, reporting a wrong source state as an invalid
    /// transition towards `to`.
    fn advance(
        &mut self,
        to: NativeEditorLifecycle,
        transition: impl FnOnce(
            AnyEditorWindow,
        ) -> Result<AnyEditorWindow, (AnyEditorWindow, InvalidState)>,
    ) -> Result<(), NativeUiError> {
        match transition(self.lifecycle) {
            Ok(next) => {
                self.lifecycle = next;
                Ok(())
            }
            Err(_) => Err(self.invalid_transition(to)),
        }
    }

    /// Returns the latest validated metrics received from the platform.
    pub const fn last_metrics(&self) -> NativeWindowMetrics {
        self.last_metrics
    }

    /// Returns the client size awaiting a matching platform resize event.
    pub const fn pending_programmatic_resize(&self) -> Option<NativeWindowSize> {
        self.pending_programmatic_resize
    }

    /// Borrows the owned native window while it has not been released.
    pub fn window(&self) -> Result<&W, NativeUiError> {
        self.window.as_ref().ok_or(NativeUiError::WindowDestroyed)
    }

    /// Mutably borrows the owned native window while it has not been released.
    pub fn window_mut(&mut self) -> Result<&mut W, NativeUiError> {
        self.window.as_mut().ok_or(NativeUiError::WindowDestroyed)
    }

    /// Records successful plugin-view attachment.
    ///
    /// Only `Created` may transition to `Attached`.
    pub fn mark_attached(&mut self) -> Result<(), NativeUiError> {
        self.advance(NativeEditorLifecycle::Attached, AnyEditorWindow::attach)
    }

    /// Shows an attached editor and records the `Visible` state.
    ///
    /// Re-showing an already visible editor is allowed; other states are rejected.
    pub fn show(&mut self) -> Result<(), NativeUiError> {
        let window = &mut self.window;
        let mut show_window = || {
            window
                .as_mut()
                .ok_or(NativeUiError::WindowDestroyed)?
                .show()
        };
        match self.lifecycle.show(&mut show_window) {
            Ok(next) => {
                self.lifecycle = next;
                Ok(())
            }
            Err((_, TransitionError::Failed(error))) => Err(error),
            Err((_, TransitionError::InvalidState(_))) => {
                Err(self.invalid_transition(NativeEditorLifecycle::Visible))
            }
        }
    }

    /// Requests focus only while the editor is visible.
    pub fn request_focus(&mut self) -> Result<(), NativeUiError> {
        if !matches!(self.lifecycle, AnyEditorWindow::Visible(_)) {
            return Err(self.invalid_transition(NativeEditorLifecycle::Visible));
        }
        self.window_mut()?.request_focus()
    }

    /// Requests a validated client size and marks it for acknowledgement filtering.
    pub fn resize_window(&mut self, size: NativeWindowSize) -> Result<(), NativeUiError> {
        size.validate()?;
        if matches!(
            self.lifecycle,
            AnyEditorWindow::Closing(_) | AnyEditorWindow::Closed(_)
        ) {
            return Err(NativeUiError::WindowDestroyed);
        }
        self.window_mut()?.set_client_size(size)?;
        self.pending_programmatic_resize = Some(size);
        self.last_metrics.client_size = size;
        Ok(())
    }

    /// Enters `Closing` from any live state and reports whether the transition occurred.
    pub fn begin_close(&mut self) -> bool {
        match self.lifecycle.begin_close() {
            Ok(next) => {
                self.lifecycle = next;
                true
            }
            Err(_) => false,
        }
    }

    /// Releases the native window and completes a previously started close.
    ///
    /// Calling this outside `Closing` returns an invalid-transition error.
    pub fn finish_close(&mut self) -> Result<(), NativeUiError> {
        self.advance(NativeEditorLifecycle::Closed, AnyEditorWindow::finish_close)?;
        self.pending_programmatic_resize = None;
        drop(self.window.take());
        Ok(())
    }

    /// Validates and normalizes one platform event for this binding.
    ///
    /// Events for other windows and events received after closure are ignored. Resize and scale
    /// payloads are validated before cached metrics or lifecycle state are changed.
    pub fn handle_event(
        &mut self,
        event: NativeWindowEvent,
    ) -> Result<NativeEditorEvent, NativeUiError> {
        let Some(window) = self.window.as_ref() else {
            return Ok(NativeEditorEvent::Ignored);
        };
        if event.window() != window.id() || matches!(self.lifecycle, AnyEditorWindow::Closed(_)) {
            return Ok(NativeEditorEvent::Ignored);
        }
        match event {
            NativeWindowEvent::CloseRequested { .. } => {
                if self.begin_close() {
                    Ok(NativeEditorEvent::CloseRequested)
                } else {
                    Ok(NativeEditorEvent::Ignored)
                }
            }
            NativeWindowEvent::Resized { size, .. } => {
                size.validate()?;
                self.last_metrics.client_size = size;
                if self.pending_programmatic_resize == Some(size) {
                    self.pending_programmatic_resize = None;
                    Ok(NativeEditorEvent::ProgrammaticResizeAcknowledged)
                } else {
                    Ok(NativeEditorEvent::ExternalResize(size))
                }
            }
            NativeWindowEvent::ScaleFactorChanged { metrics, .. } => {
                metrics.validate()?;
                self.last_metrics = metrics;
                Ok(NativeEditorEvent::ScaleFactorChanged(metrics))
            }
            NativeWindowEvent::FocusChanged { focused, .. } => {
                Ok(NativeEditorEvent::FocusChanged(focused))
            }
            NativeWindowEvent::Destroyed { .. } => {
                // Closed bindings returned above, so every remaining state can be destroyed.
                if let Ok(next) = self.lifecycle.destroyed() {
                    self.lifecycle = next;
                }
                self.pending_programmatic_resize = None;
                Ok(NativeEditorEvent::Destroyed)
            }
        }
    }
}
