use std::num::NonZeroU64;

use raw_window_handle::{RawDisplayHandle, RawWindowHandle};

pub const MAX_NATIVE_WINDOW_DIMENSION: u32 = 16_384;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct NativeWindowId(NonZeroU64);

impl NativeWindowId {
    pub const fn new(value: NonZeroU64) -> Self {
        Self(value)
    }

    pub const fn get(self) -> u64 {
        self.0.get()
    }
}

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

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct NativeWindowSize {
    pub width: u32,
    pub height: u32,
}

impl NativeWindowSize {
    pub fn new(width: u32, height: u32) -> Result<Self, NativeUiError> {
        let size = Self { width, height };
        size.validate()?;
        Ok(size)
    }

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

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct NativeWindowMetrics {
    pub client_size: NativeWindowSize,
    pub scale_factor: f64,
}

impl NativeWindowMetrics {
    pub fn validate(self) -> Result<(), NativeUiError> {
        self.client_size.validate()?;
        if self.scale_factor.is_finite() && self.scale_factor > 0.0 {
            Ok(())
        } else {
            Err(NativeUiError::InvalidScaleFactor(self.scale_factor))
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct NativeWindowConstraints {
    pub min: Option<NativeWindowSize>,
    pub max: Option<NativeWindowSize>,
}

impl NativeWindowConstraints {
    pub const fn resizable() -> Self {
        Self {
            min: None,
            max: None,
        }
    }

    pub const fn fixed(size: NativeWindowSize) -> Self {
        Self {
            min: Some(size),
            max: Some(size),
        }
    }

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

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum NativeSurfaceKind {
    X11,
    Wayland,
    Win32,
    AppKit,
}

#[derive(Debug, Clone, Copy, Default, PartialEq, Eq)]
pub struct NativeSurfaceCapabilities {
    pub x11: bool,
    pub wayland: bool,
    pub win32: bool,
    pub appkit: bool,
}

impl NativeSurfaceCapabilities {
    pub const fn supports(self, kind: NativeSurfaceKind) -> bool {
        match kind {
            NativeSurfaceKind::X11 => self.x11,
            NativeSurfaceKind::Wayland => self.wayland,
            NativeSurfaceKind::Win32 => self.win32,
            NativeSurfaceKind::AppKit => self.appkit,
        }
    }

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

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum NativeSurfacePreference {
    AnySupported,
    Require(NativeSurfaceKind),
    Prefer {
        primary: NativeSurfaceKind,
        fallback: Option<NativeSurfaceKind>,
    },
}

#[derive(Debug, Clone, Copy)]
pub struct NativeParentHandle {
    pub kind: NativeSurfaceKind,
    pub window: RawWindowHandle,
    pub display: Option<RawDisplayHandle>,
}

#[derive(Debug, Clone, Copy)]
pub struct NativeWindowSpec<'a> {
    pub title: &'a str,
    pub initial_size: NativeWindowSize,
    pub constraints: NativeWindowConstraints,
    pub initially_visible: bool,
    pub preferred_surface: NativeSurfacePreference,
}

impl NativeWindowSpec<'_> {
    pub fn validate(&self) -> Result<(), NativeUiError> {
        self.initial_size.validate()?;
        self.constraints.validate()
    }
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum NativeWindowEvent {
    CloseRequested {
        window: NativeWindowId,
    },
    Resized {
        window: NativeWindowId,
        size: NativeWindowSize,
    },
    ScaleFactorChanged {
        window: NativeWindowId,
        metrics: NativeWindowMetrics,
    },
    FocusChanged {
        window: NativeWindowId,
        focused: bool,
    },
    Destroyed {
        window: NativeWindowId,
    },
}

impl NativeWindowEvent {
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

#[derive(Debug, thiserror::Error)]
pub enum NativeUiError {
    #[error("native UI operation must run on its owner thread")]
    WrongThread,
    #[error("native UI runtime is unavailable")]
    RuntimeUnavailable,
    #[error("native UI runtime initialization failed: {0}")]
    RuntimeInitializationFailed(String),
    #[error("native plug-in editor backend for {0} is not implemented")]
    PlatformBackendUnavailable(&'static str),
    #[error("no native display is available")]
    DisplayUnavailable,
    #[error("native surface preference is unsupported: {0:?}")]
    SurfaceUnsupported(NativeSurfacePreference),
    #[error("native window creation failed: {0}")]
    WindowCreationFailed(String),
    #[error("native window has already been destroyed")]
    WindowDestroyed,
    #[error("invalid native client size: {0:?}")]
    InvalidSize(NativeWindowSize),
    #[error("invalid native window constraints")]
    InvalidConstraints,
    #[error("invalid native scale factor: {0}")]
    InvalidScaleFactor(f64),
    #[error("native window handle is invalid")]
    InvalidHandle,
    #[error("native event dispatch failed: {0}")]
    EventDispatchFailed(String),
    #[error("native UI request queue is full")]
    QueueFull,
    #[error("native UI request was cancelled before execution")]
    RequestCancelled,
    #[error("native UI request channel disconnected")]
    RequestDisconnected,
    #[error("native operation failed: {0}")]
    NativeOperationFailed(String),
    #[error("native window identifier space is exhausted")]
    IdentifierExhausted,
    #[error("invalid native editor lifecycle transition from {from:?} to {to:?}")]
    InvalidLifecycleTransition {
        from: super::NativeEditorLifecycle,
        to: super::NativeEditorLifecycle,
    },
}
