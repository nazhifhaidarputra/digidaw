use std::num::NonZeroU64;

use raw_window_handle::{RawDisplayHandle, RawWindowHandle};

/// Largest accepted client width or height for a native plugin editor window.
pub const MAX_NATIVE_WINDOW_DIMENSION: u32 = 16_384;

/// Nonzero process-local identifier assigned to a host-owned native window.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct NativeWindowId(NonZeroU64);

impl NativeWindowId {
    /// Wraps a nonzero identifier allocated by the native window owner.
    pub const fn new(value: NonZeroU64) -> Self {
        Self(value)
    }

    /// Returns the integer identifier used in platform event maps.
    pub const fn get(self) -> u64 {
        self.0.get()
    }
}

/// Monotonic allocator for native window identifiers.
///
/// Identifiers are never reused by one allocator; exhaustion is reported instead of wrapping.
#[derive(Debug)]
pub struct NativeWindowIdAllocator {
    next: NonZeroU64,
}

impl Default for NativeWindowIdAllocator {
    fn default() -> Self {
        Self {
            next: NonZeroU64::MIN,
        }
    }
}

impl NativeWindowIdAllocator {
    /// Allocates the next nonzero identifier.
    ///
    /// Returns [`NativeUiError::IdentifierExhausted`] when incrementing would overflow.
    pub fn allocate(&mut self) -> Result<NativeWindowId, NativeUiError> {
        let id = self.next;
        self.next = NonZeroU64::new(
            id.get()
                .checked_add(1)
                .ok_or(NativeUiError::IdentifierExhausted)?,
        )
        .ok_or(NativeUiError::IdentifierExhausted)?;
        Ok(NativeWindowId::new(id))
    }
}

/// Plugin editor client-area dimensions in physical window units.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct NativeWindowSize {
    /// Client width; valid values are `1..=MAX_NATIVE_WINDOW_DIMENSION`.
    pub width: u32,
    /// Client height; valid values are `1..=MAX_NATIVE_WINDOW_DIMENSION`.
    pub height: u32,
}

impl NativeWindowSize {
    /// Constructs and validates nonzero bounded client dimensions.
    pub fn new(width: u32, height: u32) -> Result<Self, NativeUiError> {
        let size = Self { width, height };
        size.validate()?;
        Ok(size)
    }

    /// Verifies both dimensions are within the native editor limit.
    pub fn validate(self) -> Result<(), NativeUiError> {
        if (1..=MAX_NATIVE_WINDOW_DIMENSION).contains(&self.width)
            && (1..=MAX_NATIVE_WINDOW_DIMENSION).contains(&self.height)
        {
            Ok(())
        } else {
            Err(NativeUiError::InvalidSize(self))
        }
    }
}

/// Current client dimensions and display scale reported by a native window.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct NativeWindowMetrics {
    /// Current client-area dimensions.
    pub client_size: NativeWindowSize,
    /// Positive finite platform scale factor.
    pub scale_factor: f64,
}

impl NativeWindowMetrics {
    /// Validates both client dimensions and the positive finite scale factor.
    pub fn validate(self) -> Result<(), NativeUiError> {
        self.client_size.validate()?;
        if self.scale_factor.is_finite() && self.scale_factor > 0.0 {
            Ok(())
        } else {
            Err(NativeUiError::InvalidScaleFactor(self.scale_factor))
        }
    }
}

/// Optional inclusive resize bounds supplied by a plugin editor.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct NativeWindowConstraints {
    /// Minimum client dimensions, or no lower bound beyond general size validation.
    pub min: Option<NativeWindowSize>,
    /// Maximum client dimensions, or no upper bound beyond the global limit.
    pub max: Option<NativeWindowSize>,
}

impl NativeWindowConstraints {
    /// Creates unconstrained, resizable bounds.
    pub const fn resizable() -> Self {
        Self {
            min: None,
            max: None,
        }
    }

    /// Creates equal minimum and maximum bounds for a fixed-size editor.
    pub const fn fixed(size: NativeWindowSize) -> Self {
        Self {
            min: Some(size),
            max: Some(size),
        }
    }

    /// Validates each bound and ensures minimum dimensions do not exceed maximum dimensions.
    pub fn validate(self) -> Result<(), NativeUiError> {
        if let Some(min) = self.min {
            min.validate()?;
        }
        if let Some(max) = self.max {
            max.validate()?;
        }
        if let (Some(min), Some(max)) = (self.min, self.max)
            && (min.width > max.width || min.height > max.height)
        {
            return Err(NativeUiError::InvalidConstraints);
        }
        Ok(())
    }
}

/// Platform surface ABI used to parent a native plugin editor.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum NativeSurfaceKind {
    /// X11 window and display handles.
    X11,
    /// Wayland surface and display handles.
    Wayland,
    /// Win32 window handle.
    Win32,
    /// macOS AppKit view or window handle.
    AppKit,
}

/// Surface ABIs available from the initialized native window backend.
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq)]
pub struct NativeSurfaceCapabilities {
    /// Whether X11 parent handles can be created.
    pub x11: bool,
    /// Whether Wayland parent handles can be created.
    pub wayland: bool,
    /// Whether Win32 parent handles can be created.
    pub win32: bool,
    /// Whether AppKit parent handles can be created.
    pub appkit: bool,
}

impl NativeSurfaceCapabilities {
    /// Returns whether `kind` is available from this backend.
    pub const fn supports(self, kind: NativeSurfaceKind) -> bool {
        match kind {
            NativeSurfaceKind::X11 => self.x11,
            NativeSurfaceKind::Wayland => self.wayland,
            NativeSurfaceKind::Win32 => self.win32,
            NativeSurfaceKind::AppKit => self.appkit,
        }
    }

    /// Resolves a required, preferred, or unconstrained surface preference.
    ///
    /// `AnySupported` prefers Wayland, then X11, Win32, and AppKit in that order.
    pub fn select(
        self,
        preference: NativeSurfacePreference,
    ) -> Result<NativeSurfaceKind, NativeUiError> {
        let selected = match preference {
            NativeSurfacePreference::Require(kind) => self.supports(kind).then_some(kind),
            NativeSurfacePreference::Prefer { primary, fallback } => self
                .supports(primary)
                .then_some(primary)
                .or_else(|| fallback.filter(|kind| self.supports(*kind))),
            NativeSurfacePreference::AnySupported => [
                NativeSurfaceKind::Wayland,
                NativeSurfaceKind::X11,
                NativeSurfaceKind::Win32,
                NativeSurfaceKind::AppKit,
            ]
            .into_iter()
            .find(|kind| self.supports(*kind)),
        };
        selected.ok_or(NativeUiError::SurfaceUnsupported(preference))
    }
}

/// Policy used when selecting the native surface that will parent a plugin view.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum NativeSurfacePreference {
    /// Select the first available surface in the host's standard priority order.
    AnySupported,
    /// Require exactly the supplied surface kind.
    Require(NativeSurfaceKind),
    /// Prefer one surface and optionally fall back to another.
    Prefer {
        /// Surface attempted first.
        primary: NativeSurfaceKind,
        /// Optional secondary surface if `primary` is unavailable.
        fallback: Option<NativeSurfaceKind>,
    },
}

/// Raw native handles passed to a plugin while the owning [`NativeWindow`] remains alive.
#[derive(Debug, Clone, Copy)]
pub struct NativeParentHandle {
    /// ABI represented by the raw handle fields.
    pub kind: NativeSurfaceKind,
    /// Platform window or surface handle.
    pub window: RawWindowHandle,
    /// Platform display handle when required by the ABI.
    pub display: Option<RawDisplayHandle>,
}

/// Parameters used to create a host-owned native editor window.
#[derive(Debug, Clone, Copy)]
pub struct NativeWindowSpec<'a> {
    /// Initial platform window title.
    pub title: &'a str,
    /// Initial client-area dimensions.
    pub initial_size: NativeWindowSize,
    /// Plugin-supplied resize bounds.
    pub constraints: NativeWindowConstraints,
    /// Whether the platform should show the window immediately after creation.
    pub initially_visible: bool,
    /// Surface ABI required or preferred by the plugin editor.
    pub preferred_surface: NativeSurfacePreference,
}

impl NativeWindowSpec<'_> {
    /// Validates the initial size and resize constraints before platform creation.
    pub fn validate(&self) -> Result<(), NativeUiError> {
        self.initial_size.validate()?;
        self.constraints.validate()
    }
}

/// Platform event emitted for one host-owned native window.
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum NativeWindowEvent {
    /// The window manager or user requested closure.
    CloseRequested {
        /// Window receiving the request.
        window: NativeWindowId,
    },
    /// The client area changed dimensions.
    Resized {
        /// Window that was resized.
        window: NativeWindowId,
        /// New client-area dimensions.
        size: NativeWindowSize,
    },
    /// Display scaling or the scaled client metrics changed.
    ScaleFactorChanged {
        /// Window whose metrics changed.
        window: NativeWindowId,
        /// Updated size and scale factor.
        metrics: NativeWindowMetrics,
    },
    /// Keyboard focus entered or left the window.
    FocusChanged {
        /// Window whose focus changed.
        window: NativeWindowId,
        /// `true` when the window gained focus.
        focused: bool,
    },
    /// The platform window was destroyed independently of the requested lifecycle.
    Destroyed {
        /// Destroyed window.
        window: NativeWindowId,
    },
}

impl NativeWindowEvent {
    /// Returns the window identifier carried by any event variant.
    pub const fn window(self) -> NativeWindowId {
        match self {
            Self::CloseRequested { window }
            | Self::Resized { window, .. }
            | Self::ScaleFactorChanged { window, .. }
            | Self::FocusChanged { window, .. }
            | Self::Destroyed { window } => window,
        }
    }
}

/// Validation, platform, lifecycle, and cross-thread dispatch errors for native editors.
#[derive(Debug, thiserror::Error)]
pub enum NativeUiError {
    /// Operation was invoked outside the native UI owner thread.
    #[error("native UI operation must run on its owner thread")]
    WrongThread,
    /// No initialized native UI runtime or request receiver is available.
    #[error("native UI runtime is unavailable")]
    RuntimeUnavailable,
    /// Global queue or platform runtime initialization failed.
    #[error("native UI runtime initialization failed: {0}")]
    RuntimeInitializationFailed(String),
    /// Current target has no implementation for the requested native editor backend.
    #[error("native plug-in editor backend for {0} is not implemented")]
    PlatformBackendUnavailable(&'static str),
    /// Platform display connection could not be established.
    #[error("no native display is available")]
    DisplayUnavailable,
    /// Required or preferred surface selection could not be satisfied.
    #[error("native surface preference is unsupported: {0:?}")]
    SurfaceUnsupported(NativeSurfacePreference),
    /// Platform rejected creation of a native window.
    #[error("native window creation failed: {0}")]
    WindowCreationFailed(String),
    /// Operation requires a native window that has already been released.
    #[error("native window has already been destroyed")]
    WindowDestroyed,
    /// Client dimensions are zero or exceed the global native-window limit.
    #[error("invalid native client size: {0:?}")]
    InvalidSize(NativeWindowSize),
    /// Minimum and maximum client bounds are inconsistent.
    #[error("invalid native window constraints")]
    InvalidConstraints,
    /// Platform scale factor is non-finite or non-positive.
    #[error("invalid native scale factor: {0}")]
    InvalidScaleFactor(f64),
    /// Platform returned a null, zero, or otherwise unusable raw parent handle.
    #[error("native window handle is invalid")]
    InvalidHandle,
    /// Polling or translating a platform event failed.
    #[error("native event dispatch failed: {0}")]
    EventDispatchFailed(String),
    /// Bounded cross-thread native UI request queue has no free slot.
    #[error("native UI request queue is full")]
    QueueFull,
    /// Native UI request or result channel disconnected.
    #[error("native UI request channel disconnected")]
    RequestDisconnected,
    /// Platform-native operation returned an error message.
    #[error("native operation failed: {0}")]
    NativeOperationFailed(String),
    /// Monotonic native window identifier reached `u64::MAX`.
    #[error("native window identifier space is exhausted")]
    IdentifierExhausted,
    /// Editor binding was asked to perform a disallowed lifecycle transition.
    #[error("invalid native editor lifecycle transition from {from:?} to {to:?}")]
    InvalidLifecycleTransition {
        /// Lifecycle state before the rejected operation.
        from: super::NativeEditorLifecycle,
        /// Lifecycle state required by the rejected operation.
        to: super::NativeEditorLifecycle,
    },
}
