#![allow(
    clippy::unwrap_used,
    clippy::panic,
    reason = "native UI test fixtures fail on unexpected results"
)]

use super::*;
use raw_window_handle::{RawWindowHandle, XcbWindowHandle};
use std::{
    cell::RefCell,
    num::{NonZeroU32, NonZeroU64},
    rc::Rc,
};

struct MockWindow {
    id: NativeWindowId,
    metrics: NativeWindowMetrics,
    actions: Rc<RefCell<Vec<&'static str>>>,
}

impl Drop for MockWindow {
    fn drop(&mut self) {
        self.actions.borrow_mut().push("drop-window");
    }
}

impl NativeWindow for MockWindow {
    fn id(&self) -> NativeWindowId {
        self.id
    }

    fn surface_kind(&self) -> NativeSurfaceKind {
        NativeSurfaceKind::X11
    }

    fn parent_handle(&self) -> Result<NativeParentHandle, NativeUiError> {
        Ok(NativeParentHandle {
            kind: NativeSurfaceKind::X11,
            window: RawWindowHandle::Xcb(XcbWindowHandle::new(NonZeroU32::MIN)),
            display: None,
        })
    }

    fn show(&mut self) -> Result<(), NativeUiError> {
        self.actions.borrow_mut().push("show");
        Ok(())
    }

    fn hide(&mut self) -> Result<(), NativeUiError> {
        self.actions.borrow_mut().push("hide");
        Ok(())
    }

    fn request_focus(&mut self) -> Result<(), NativeUiError> {
        self.actions.borrow_mut().push("focus");
        Ok(())
    }

    fn set_title(&mut self, _: &str) -> Result<(), NativeUiError> {
        Ok(())
    }

    fn set_constraints(&mut self, _: NativeWindowConstraints) -> Result<(), NativeUiError> {
        Ok(())
    }

    fn set_client_size(&mut self, size: NativeWindowSize) -> Result<(), NativeUiError> {
        self.metrics.client_size = size;
        self.actions.borrow_mut().push("resize-window");
        Ok(())
    }

    fn metrics(&self) -> Result<NativeWindowMetrics, NativeUiError> {
        Ok(self.metrics)
    }
}

fn binding() -> (
    NativeEditorBinding<MockWindow>,
    Rc<RefCell<Vec<&'static str>>>,
) {
    let actions = Rc::new(RefCell::new(Vec::new()));
    let window = MockWindow {
        id: NativeWindowId::new(NonZeroU64::MIN),
        metrics: NativeWindowMetrics {
            client_size: NativeWindowSize::new(640, 480).unwrap(),
            scale_factor: 1.0,
        },
        actions: actions.clone(),
    };
    (NativeEditorBinding::new(window).unwrap(), actions)
}

#[test]
fn ids_are_monotonic_and_never_zero() {
    let mut ids = NativeWindowIdAllocator::default();
    let first = ids.allocate().unwrap();
    let second = ids.allocate().unwrap();
    assert_eq!(first.get(), 1);
    assert_eq!(second.get(), 2);
}

#[test]
fn sizes_and_fixed_constraints_are_validated() {
    let size = NativeWindowSize::new(640, 480).unwrap();
    assert_eq!(NativeWindowConstraints::fixed(size).min, Some(size));
    assert!(NativeWindowSize::new(0, 480).is_err());
    assert!(NativeWindowSize::new(MAX_NATIVE_WINDOW_DIMENSION + 1, 480).is_err());
}

#[test]
fn surface_preferences_require_or_fall_back() {
    let capabilities = NativeSurfaceCapabilities {
        x11: true,
        wayland: false,
        win32: false,
        appkit: false,
    };
    assert_eq!(
        capabilities
            .select(NativeSurfacePreference::Require(NativeSurfaceKind::X11))
            .unwrap(),
        NativeSurfaceKind::X11
    );
    assert_eq!(
        capabilities
            .select(NativeSurfacePreference::Prefer {
                primary: NativeSurfaceKind::Wayland,
                fallback: Some(NativeSurfaceKind::X11),
            })
            .unwrap(),
        NativeSurfaceKind::X11
    );
    assert!(
        capabilities
            .select(NativeSurfacePreference::Require(NativeSurfaceKind::Wayland))
            .is_err()
    );
}

#[test]
fn programmatic_resize_acknowledgement_is_suppressed() {
    let (mut binding, _) = binding();
    let size = NativeWindowSize::new(800, 600).unwrap();
    binding.resize_window(size).unwrap();
    assert_eq!(
        binding
            .handle_event(NativeWindowEvent::Resized {
                window: binding.id(),
                size,
            })
            .unwrap(),
        NativeEditorEvent::ProgrammaticResizeAcknowledged
    );
    assert_eq!(binding.pending_programmatic_resize(), None);
}

#[test]
fn user_resize_and_scale_changes_are_forwarded() {
    let (mut binding, _) = binding();
    let size = NativeWindowSize::new(700, 500).unwrap();
    assert_eq!(
        binding
            .handle_event(NativeWindowEvent::Resized {
                window: binding.id(),
                size,
            })
            .unwrap(),
        NativeEditorEvent::ExternalResize(size)
    );
    let metrics = NativeWindowMetrics {
        client_size: size,
        scale_factor: 2.0,
    };
    assert_eq!(
        binding
            .handle_event(NativeWindowEvent::ScaleFactorChanged {
                window: binding.id(),
                metrics,
            })
            .unwrap(),
        NativeEditorEvent::ScaleFactorChanged(metrics)
    );
    assert_eq!(binding.last_metrics(), metrics);
}

#[test]
fn stale_and_duplicate_close_events_are_harmless() {
    let (mut binding, _) = binding();
    let stale = NativeWindowId::new(NonZeroU64::new(2).unwrap());
    assert_eq!(
        binding
            .handle_event(NativeWindowEvent::CloseRequested { window: stale })
            .unwrap(),
        NativeEditorEvent::Ignored
    );
    let id = binding.id();
    assert_eq!(
        binding
            .handle_event(NativeWindowEvent::CloseRequested { window: id })
            .unwrap(),
        NativeEditorEvent::CloseRequested
    );
    assert_eq!(
        binding
            .handle_event(NativeWindowEvent::CloseRequested { window: id })
            .unwrap(),
        NativeEditorEvent::Ignored
    );
}

#[test]
fn window_drops_only_after_close_transition_finishes() {
    let (mut binding, actions) = binding();
    binding.mark_attached().unwrap();
    binding.show().unwrap();
    assert!(binding.begin_close());
    actions.borrow_mut().push("detach-editor");
    binding.finish_close().unwrap();
    assert_eq!(
        actions.borrow().as_slice(),
        ["show", "detach-editor", "drop-window"]
    );
    assert!(binding.window_mut().is_err());
    assert_eq!(binding.lifecycle(), NativeEditorLifecycle::Closed);
}

#[test]
fn externally_destroyed_window_requires_best_effort_close() {
    let (mut binding, _) = binding();
    let id = binding.id();
    assert_eq!(
        binding
            .handle_event(NativeWindowEvent::Destroyed { window: id })
            .unwrap(),
        NativeEditorEvent::Destroyed
    );
    assert_eq!(binding.lifecycle(), NativeEditorLifecycle::Closing);
    binding.finish_close().unwrap();
}

#[test]
fn unavailable_wake_handle_is_explicit() {
    let error = platform::UnavailableWakeHandle.wake().unwrap_err();
    assert!(matches!(error, NativeUiError::RuntimeUnavailable));
}
