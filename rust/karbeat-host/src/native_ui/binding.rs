use super::{
    NativeUiError, NativeWindow, NativeWindowEvent, NativeWindowId, NativeWindowMetrics,
    NativeWindowSize,
};

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
    lifecycle: NativeEditorLifecycle,
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
            lifecycle: NativeEditorLifecycle::Created,
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
        self.lifecycle
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
        if self.lifecycle != NativeEditorLifecycle::Created {
            return Err(NativeUiError::InvalidLifecycleTransition {
                from: self.lifecycle,
                to: NativeEditorLifecycle::Attached,
            });
        }
        self.lifecycle = NativeEditorLifecycle::Attached;
        Ok(())
    }

    /// Shows an attached editor and records the `Visible` state.
    ///
    /// Re-showing an already visible editor is allowed; other states are rejected.
    pub fn show(&mut self) -> Result<(), NativeUiError> {
        if !matches!(
            self.lifecycle,
            NativeEditorLifecycle::Attached | NativeEditorLifecycle::Visible
        ) {
            return Err(NativeUiError::InvalidLifecycleTransition {
                from: self.lifecycle,
                to: NativeEditorLifecycle::Visible,
            });
        }
        self.window_mut()?.show()?;
        self.lifecycle = NativeEditorLifecycle::Visible;
        Ok(())
    }

    /// Requests focus only while the editor is visible.
    pub fn request_focus(&mut self) -> Result<(), NativeUiError> {
        if self.lifecycle != NativeEditorLifecycle::Visible {
            return Err(NativeUiError::InvalidLifecycleTransition {
                from: self.lifecycle,
                to: NativeEditorLifecycle::Visible,
            });
        }
        self.window_mut()?.request_focus()
    }

    /// Requests a validated client size and marks it for acknowledgement filtering.
    pub fn resize_window(&mut self, size: NativeWindowSize) -> Result<(), NativeUiError> {
        size.validate()?;
        if matches!(
            self.lifecycle,
            NativeEditorLifecycle::Closing | NativeEditorLifecycle::Closed
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
        match self.lifecycle {
            NativeEditorLifecycle::Created
            | NativeEditorLifecycle::Attached
            | NativeEditorLifecycle::Visible => {
                self.lifecycle = NativeEditorLifecycle::Closing;
                true
            }
            NativeEditorLifecycle::Closing | NativeEditorLifecycle::Closed => false,
        }
    }

    /// Releases the native window and completes a previously started close.
    ///
    /// Calling this outside `Closing` returns an invalid-transition error.
    pub fn finish_close(&mut self) -> Result<(), NativeUiError> {
        if self.lifecycle != NativeEditorLifecycle::Closing {
            return Err(NativeUiError::InvalidLifecycleTransition {
                from: self.lifecycle,
                to: NativeEditorLifecycle::Closed,
            });
        }
        self.pending_programmatic_resize = None;
        drop(self.window.take());
        self.lifecycle = NativeEditorLifecycle::Closed;
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
        if event.window() != window.id() || self.lifecycle == NativeEditorLifecycle::Closed {
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
                self.lifecycle = NativeEditorLifecycle::Closing;
                self.pending_programmatic_resize = None;
                Ok(NativeEditorEvent::Destroyed)
            }
        }
    }
}
