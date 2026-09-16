use super::{
    NativeUiError, NativeWindow, NativeWindowEvent, NativeWindowId, NativeWindowMetrics,
    NativeWindowSize,
};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum NativeEditorLifecycle {
    Created,
    Attached,
    Visible,
    Closing,
    Closed,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum NativeEditorEvent {
    Ignored,
    ProgrammaticResizeAcknowledged,
    ExternalResize(NativeWindowSize),
    CloseRequested,
    ScaleFactorChanged(NativeWindowMetrics),
    FocusChanged(bool),
    Destroyed,
}

pub struct NativeEditorBinding<W: NativeWindow> {
    id: NativeWindowId,
    window: Option<W>,
    lifecycle: NativeEditorLifecycle,
    last_metrics: NativeWindowMetrics,
    pending_programmatic_resize: Option<NativeWindowSize>,
}

impl<W: NativeWindow> NativeEditorBinding<W> {
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

    pub const fn id(&self) -> NativeWindowId {
        self.id
    }

    pub const fn lifecycle(&self) -> NativeEditorLifecycle {
        self.lifecycle
    }

    pub const fn last_metrics(&self) -> NativeWindowMetrics {
        self.last_metrics
    }

    pub const fn pending_programmatic_resize(&self) -> Option<NativeWindowSize> {
        self.pending_programmatic_resize
    }

    pub fn window(&self) -> Result<&W, NativeUiError> {
        self.window.as_ref().ok_or(NativeUiError::WindowDestroyed)
    }

    pub fn window_mut(&mut self) -> Result<&mut W, NativeUiError> {
        self.window.as_mut().ok_or(NativeUiError::WindowDestroyed)
    }

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

    pub fn request_focus(&mut self) -> Result<(), NativeUiError> {
        if self.lifecycle != NativeEditorLifecycle::Visible {
            return Err(NativeUiError::InvalidLifecycleTransition {
                from: self.lifecycle,
                to: NativeEditorLifecycle::Visible,
            });
        }
        self.window_mut()?.request_focus()
    }

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
