# DigiDAW Native Plugin UI Architecture — Rust-Owned, Format-Agnostic, OS-Abstracted

## Implementation Plan for Codex

### Repository context

- Repository: `nazhifhaidarputra/digidaw`
- Current development branch baseline: `feat/vst3`
- Primary development/test OS: **Linux, KDE Plasma**
- Current external plug-in implementation: VST3
- Planned plug-in interfaces: VST3, CLAP, LV2, and future native plug-in formats
- Flutter is the application UI, but **Flutter/C++ runner code must no longer participate in plug-in editor correctness or lifecycle management**

---

# 1. Goal

Replace the current Flutter-runner-owned native plug-in window service with a reusable **Rust-native plug-in UI subsystem**.

The new subsystem must live in:

```text
rust/karbeat-host
```

not in:

```text
rust/karbeat-vst3
```

because native editor window management is not a VST3-specific concern.

All plug-in interfaces need the same fundamental host-side capabilities:

```text
dynamic plug-in module
       |
       v
plug-in instance
       |
       v
plug-in editor protocol adapter
       |
       v
host-owned native window
       |
       v
OS window system
```

The format crate is responsible for translating its own GUI protocol into a native parent handle.

The `karbeat-host` crate is responsible for:

- UI-owner thread/main-context dispatch;
- native window creation;
- window destruction;
- window titles;
- window visibility;
- focus requests;
- size and constraints;
- resize events;
- close requests;
- scale/DPI changes;
- native handle exposure;
- native display handle exposure where required;
- event polling/integration;
- stale-event protection;
- lifecycle ordering;
- platform selection;
- common editor-window state.

The Flutter Linux/Windows/macOS runner must not be required to initialize, poll, create, resize, focus, destroy, or otherwise manage plug-in editor windows.

---

# 2. Architectural Principle

Use **static dispatch for operating-system selection**.

Do not use:

```rust
Box<dyn NativeUiPlatform>
```

for the production platform backend.

Instead:

```rust
#[cfg(target_os = "linux")]
pub type SystemNativeUi = linux::LinuxNativeUi;

#[cfg(target_os = "windows")]
pub type SystemNativeUi = windows::WindowsNativeUi;

#[cfg(target_os = "macos")]
pub type SystemNativeUi = macos::MacOsNativeUi;
```

Generic host code should operate on:

```rust
NativeUi<P: NativeUiPlatform>
```

or:

```rust
NativePluginHost<P: NativeUiPlatform>
```

and the production build should monomorphize to exactly one platform.

Important distinction:

> OS selection is compile-time/static dispatch. Linux display-protocol selection may still be runtime because a Linux process may have X11, Wayland, both through XWayland, or neither.

---

# 3. Move the Native UI Abstraction Into `karbeat-host`

The current `karbeat-host::PluginEditorManager` already defines the format-independent plug-in editor contract and uses `RawWindowHandle`.

Extend `karbeat-host` with a separate **host-native window subsystem**.

Recommended layout:

```text
rust/karbeat-host/src/
├── native_ui/
│   ├── mod.rs
│   ├── traits.rs
│   ├── types.rs
│   ├── binding.rs
│   ├── runtime.rs
│   ├── platform/
│   │   ├── mod.rs
│   │   ├── linux/
│   │   │   ├── mod.rs
│   │   │   ├── x11.rs
│   │   │   ├── wayland.rs
│   │   │   └── runtime.rs
│   │   ├── windows.rs
│   │   └── macos.rs
│   └── tests.rs
├── traits.rs
├── types.rs
└── lib.rs
```

`karbeat-vst3` should consume the abstraction.

Future:

```text
karbeat-clap
karbeat-lv2
karbeat-au
```

must consume exactly the same abstraction.

---

# 4. Keep Plug-In GUI Protocols Out of `karbeat-host`

`karbeat-host` must **not** know about:

```text
IPlugView
IPlugFrame
X11EmbedWindowID
CLAP_EXT_GUI
LV2_UI__parent
AudioUnit/AppKit editor APIs
```

Those remain plug-in-format concerns.

The separation must be:

```text
karbeat-host
    |
    +-- creates/owns native window
    +-- emits RawWindowHandle / RawDisplayHandle
    +-- normalizes events
    +-- owns OS event integration
    |
    v
format adapter
    |
    +-- VST3: IPlugView::attached
    +-- CLAP: clap_plugin_gui.set_parent
    +-- LV2: LV2 UI parent feature
    +-- future formats
```

The native UI layer must not contain any `vst3` dependency.

---

# 5. Core Shared Types

Add format-independent types to:

```text
karbeat-host/src/native_ui/types.rs
```

## Native window identity

Do not use `HostInstanceId` as the native-window identity.

Add a generation-safe identifier:

```rust
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct NativeWindowId(u64);
```

The UI manager allocates monotonically increasing IDs.

Reason:

```text
instance A opens editor window #1
window #1 closes
instance A opens editor window #2
late OS event from window #1 arrives
```

The late event must not affect the replacement window.

---

## Size

```rust
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct NativeWindowSize {
    pub width: u32,
    pub height: u32,
}
```

Semantics:

> Size means the native content/client area expected by the plug-in GUI protocol, not the outer decorated frame.

Do not define it as "physical framebuffer pixels".

That would be incorrect across macOS Retina, Windows DPI scaling, and Linux scaling.

---

## Metrics

```rust
#[derive(Debug, Clone, Copy)]
pub struct NativeWindowMetrics {
    pub client_size: NativeWindowSize,
    pub scale_factor: f64,
}
```

The backend must preserve scale independently from logical/content dimensions.

---

## Constraints

```rust
#[derive(Debug, Clone, Copy)]
pub struct NativeWindowConstraints {
    pub min: Option<NativeWindowSize>,
    pub max: Option<NativeWindowSize>,
}
```

Helpers:

```rust
impl NativeWindowConstraints {
    pub fn resizable() -> Self { ... }

    pub fn fixed(size: NativeWindowSize) -> Self { ... }
}
```

Do not make `bool resizable` the primary model.

A plug-in may eventually require real min/max constraints.

---

## Window creation specification

```rust
pub struct NativeWindowSpec<'a> {
    pub title: &'a str,
    pub initial_size: NativeWindowSize,
    pub constraints: NativeWindowConstraints,
    pub initially_visible: bool,
    pub preferred_surface: NativeSurfacePreference,
}
```

---

# 6. Represent Native Surface Technology Explicitly

Linux is not one display protocol.

Add:

```rust
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum NativeSurfaceKind {
    X11,
    Wayland,
    Win32,
    AppKit,
}
```

Do not derive the plug-in API solely by matching `RawWindowHandle`.

The surface kind should be explicit so format adapters can negotiate correctly.

Add:

```rust
#[derive(Debug, Clone, Copy)]
pub struct NativeSurfaceCapabilities {
    pub x11: bool,
    pub wayland: bool,
    pub win32: bool,
    pub appkit: bool,
}
```

or an equivalent bitset.

---

## Surface preference

```rust
pub enum NativeSurfacePreference {
    AnySupported,
    Require(NativeSurfaceKind),
    Prefer {
        primary: NativeSurfaceKind,
        fallback: Option<NativeSurfaceKind>,
    },
}
```

This is important on Linux.

Examples:

### VST3 on Linux

The existing VST3 implementation requires:

```text
X11EmbedWindowID
```

Therefore:

```rust
NativeSurfacePreference::Require(
    NativeSurfaceKind::X11
)
```

If running KDE Plasma Wayland and XWayland is available, the Linux backend may still create an X11 host window through XWayland.

If XWayland is unavailable:

```text
plug-in audio load = allowed
VST3 editor opening = Unsupported
```

Do not fail loading the plug-in merely because its GUI cannot be opened.

### CLAP

A CLAP adapter can inspect which GUI APIs the plug-in supports.

Example:

```text
plugin supports Wayland + X11
host has Wayland + X11
=> prefer Wayland

plugin supports X11 only
host is KDE Wayland with XWayland
=> use X11

plugin supports X11 only
host is Wayland-only with no XWayland
=> editor unavailable
```

### LV2

The LV2 adapter decides which parent/native UI mechanism applies for that LV2 UI type.

`karbeat-host` must not decide LV2 protocol semantics.

---

# 7. Native Parent Handle

Add a format-neutral handle bundle.

```rust
pub struct NativeParentHandle {
    pub kind: NativeSurfaceKind,
    pub window: raw_window_handle::RawWindowHandle,
    pub display: Option<raw_window_handle::RawDisplayHandle>,
}
```

If lifetime safety can use the newer borrowed handle API cleanly, prefer `WindowHandle<'_>` / `DisplayHandle<'_>` internally.

If the current codebase makes that disruptive, use raw handles but document:

> The handles are valid only while the owning `NativeWindow` remains alive.

Formats may need both window and display information.

Do not assume `RawWindowHandle` alone is always enough.

---

# 8. Core `NativeWindow` Trait

Put this in:

```text
karbeat-host/src/native_ui/traits.rs
```

Suggested contract:

```rust
pub trait NativeWindow {
    fn id(&self) -> NativeWindowId;

    fn surface_kind(&self) -> NativeSurfaceKind;

    fn parent_handle(
        &self,
    ) -> Result<NativeParentHandle, NativeUiError>;

    fn show(
        &mut self,
    ) -> Result<(), NativeUiError>;

    fn hide(
        &mut self,
    ) -> Result<(), NativeUiError>;

    fn request_focus(
        &mut self,
    ) -> Result<(), NativeUiError>;

    fn set_title(
        &mut self,
        title: &str,
    ) -> Result<(), NativeUiError>;

    fn set_constraints(
        &mut self,
        constraints: NativeWindowConstraints,
    ) -> Result<(), NativeUiError>;

    fn set_client_size(
        &mut self,
        size: NativeWindowSize,
    ) -> Result<(), NativeUiError>;

    fn metrics(
        &self,
    ) -> Result<NativeWindowMetrics, NativeUiError>;
}
```

Do not add explicit `destroy()` unless platform teardown proves fallible in a way the host must surface.

Prefer native-resource cleanup in `Drop`.

The format-specific editor must detach first.

---

# 9. Core `NativeUiPlatform` Trait

Use static dispatch.

Suggested contract:

```rust
pub trait NativeUiPlatform: Sized + 'static {
    type Window: NativeWindow;

    type WakeHandle:
        NativeUiWakeHandle + Clone + Send + Sync + 'static;

    fn initialize()
        -> Result<(Self, Self::WakeHandle), NativeUiError>;

    fn is_owner_thread(
        &self,
    ) -> bool;

    fn capabilities(
        &self,
    ) -> NativeSurfaceCapabilities;

    fn create_window(
        &mut self,
        id: NativeWindowId,
        spec: &NativeWindowSpec<'_>,
    ) -> Result<Self::Window, NativeUiError>;

    /// Dispatch pending native platform/window events.
    /// Must not block.
    fn poll_events(
        &mut self,
        emit: impl FnMut(NativeWindowEvent),
    ) -> Result<(), NativeUiError>;

    /// Cheap platform housekeeping.
    /// Must not block or sleep.
    fn pump(
        &mut self,
    ) -> Result<(), NativeUiError>;
}
```

No trait object is needed in production.

---

# 10. Cross-Thread Wake Trait

Separate wakeup from window ownership.

```rust
pub trait NativeUiWakeHandle {
    fn wake(&self) -> Result<(), NativeUiError>;
}
```

Requirements:

- callable from FRB/control worker threads;
- `Send + Sync`;
- does not own a native window;
- does not execute plug-in lifecycle work on the calling worker;
- only causes the UI owner to promptly process queued work.

This abstraction can later be reused by VST3, CLAP, LV2, etc.

---

# 11. Normalize OS Events

Add:

```rust
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
```

Never expose OS event types above the backend.

Generic code must not see:

```text
ConfigureNotify
WM_SIZE
WM_CLOSE
WM_DPICHANGED
NSWindowDidResizeNotification
wl_surface.configure
xdg_toplevel.configure
```

---

# 12. Shared Editor Binding

Put common host/editor-window state in:

```text
karbeat-host/src/native_ui/binding.rs
```

Suggested:

```rust
pub struct NativeEditorBinding<W: NativeWindow> {
    pub window: W,
    pub lifecycle: NativeEditorLifecycle,
    pub last_size: NativeWindowSize,

    /// Set when the host itself changes the window size.
    /// Used to suppress OS acknowledgement feedback.
    pub pending_programmatic_resize:
        Option<NativeWindowSize>,
}
```

Lifecycle:

```rust
pub enum NativeEditorLifecycle {
    Created,
    Attached,
    Visible,
    Closing,
    Closed,
}
```

Do not let each plug-in-format crate independently reinvent:

- resize-loop suppression;
- stale-event handling;
- close ordering;
- visibility ordering.

---

# 13. Critical Shared Resize Behavior

Handle the classic feedback loop centrally.

Problem:

```text
plug-in asks host to resize
    |
    v
host resizes native window
    |
    v
OS sends resize event
    |
    v
host tells plug-in it was resized
    |
    v
plug-in asks host to resize again
```

Generic binding policy:

```rust
fn mark_programmatic_resize(
    &mut self,
    size: NativeWindowSize,
) {
    self.pending_programmatic_resize = Some(size);
}
```

On `NativeWindowEvent::Resized`:

```text
if event size == pending_programmatic_resize:
    clear pending value
    update cached metrics
    DO NOT treat as a user-originated resize
else:
    treat as external/user resize
    notify plug-in adapter
```

This policy belongs in `karbeat-host`, not VST3.

---

# 14. Shared Close Ordering

A native close button must not immediately destroy the parent window.

Correct generic flow:

```text
OS close request
    |
    v
NativeWindowEvent::CloseRequested
    |
    v
plug-in format adapter detaches GUI
    |
    v
editor protocol resources are released
    |
    v
NativeEditorBinding is dropped
    |
    v
native window is dropped/destroyed
```

Examples of protocol-specific detach:

```text
VST3:
IPlugView::removed()

CLAP:
plugin GUI hide/destroy according to CLAP lifecycle

LV2:
destroy UI instance according to LV2 UI lifecycle
```

The native window must remain alive until the format adapter confirms detachment.

---

# 15. Shared Dynamic-Library Lifetime Rule

All formats load plug-in code from a dynamic module.

Enforce the invariant:

```text
native editor window
and
plug-in GUI object
and
all plug-in callbacks
```

must be completely torn down before:

```text
dlclose / FreeLibrary / bundle/module unload
```

The generic lifecycle documentation in `karbeat-host` must explicitly state:

> A module may not unload while any editor binding, UI callback, native-window event, processor endpoint, or native plug-in instance still references code/data from that module.

This applies equally to VST3, CLAP, LV2, and future formats.

---

# 16. Linux: Real Implementation Required

Linux is the only fully implemented platform in this task.

Target environment:

```text
KDE Plasma
```

Test both:

```text
Plasma (Wayland)
Plasma (X11)
```

where available.

The Linux implementation must be fully Rust-owned.

No Flutter runner C++ calls.

No GTK C/C++ callback table.

---

# 17. Linux UI Owner: GLib Main Context

Flutter Linux uses GTK/GLib.

Use the trusted Rust `glib` crate for UI-owner scheduling.

Important:

> The Linux native plug-in UI subsystem may integrate with GLib, but it must not depend on Flutter's C++ runner or on GTK widget pointers.

Use:

```text
glib::MainContext
glib sources / timeout sources
Unix FD sources where appropriate
```

for scheduling and waking.

The GLib default main context is already driven by Flutter/GTK.

Do not start another application-level event loop.

---

# 18. Do Not Use `winit` as the Primary Runtime

Do not base this migration on `winit::EventLoop`.

Reason:

DigiDAW already has a process/application event loop owned by Flutter/GTK on Linux.

Creating another high-level application event loop introduces conflicting ownership and main-thread semantics.

Use lower-level, composable crates instead.

Recommended Linux stack:

```text
glib
raw-window-handle
x11rb
wayland-client
smithay-client-toolkit
```

Use each only where needed.

---

# 19. Linux X11 / XWayland Backend

Use:

```text
x11rb
```

for X11.

Responsibilities:

- connect using standard environment/display discovery;
- create host toplevel windows;
- create XIDs;
- set event masks;
- set WM protocols;
- handle `WM_DELETE_WINDOW`;
- set UTF-8 title;
- set normal-size hints;
- resize;
- query geometry;
- map/unmap;
- request raise/focus;
- process `ConfigureNotify`;
- detect destroyed windows;
- expose X11 raw window/display handles;
- nonblocking event drain.

Do not call Xlib directly unless an unavoidable compatibility problem is found.

Avoid `XInitThreads` by keeping this connection owned by the UI thread.

---

# 20. Linux Wayland Backend

Use trusted crates:

```text
wayland-client
smithay-client-toolkit
```

for native Wayland support.

Responsibilities:

- connect to the compositor using environment discovery;
- bind required globals;
- create `wl_surface`;
- create an XDG toplevel where a host-owned toplevel is required;
- handle configure events;
- size negotiations;
- close requests;
- output/scale changes;
- expose Wayland raw window/display handles;
- nonblocking event dispatch integrated with GLib.

Do not implement raw Wayland protocol XML handling manually if Smithay Client Toolkit already provides the needed shell abstraction.

---

# 21. Linux Display Discovery

Do not trust only:

```text
XDG_SESSION_TYPE
WAYLAND_DISPLAY
DISPLAY
```

as truth.

Use them as hints.

Probe actual capabilities.

At Linux UI initialization:

```text
try Wayland connection
try X11 connection
record successful capabilities
```

Possible results:

```text
Wayland + X11
    => Plasma Wayland with XWayland

Wayland only
    => pure Wayland

X11 only
    => X11 session

neither
    => headless/no native editor capability
```

Do not fail plug-in audio hosting when no native display exists.

Only editor creation should fail.

---

# 22. KDE Plasma Wayland + VST3

This is an explicit acceptance scenario.

VST3 currently attaches through:

```text
X11EmbedWindowID
```

Therefore when KDE runs Wayland:

```text
KDE Wayland
    |
    +-- Wayland available
    |
    +-- XWayland DISPLAY available
            |
            v
       LinuxNativeUi has X11 capability
            |
            v
       VST3 requests X11
            |
            v
       create X11/XWayland host window
```

The main Flutter window may remain Wayland/GTK.

The plug-in editor may independently be an XWayland/X11 window.

No Flutter parent window is required.

This is acceptable.

---

# 23. Native Wayland Plug-Ins

For formats capable of Wayland GUI parenting, such as future CLAP support:

```text
format adapter checks plug-in supported GUI APIs
    |
    v
requests NativeSurfaceKind::Wayland
    |
    v
karbeat-host creates Wayland surface
    |
    v
format adapter passes native Wayland parent
```

Do not force all Linux plug-ins through X11.

Likewise do not force VST3 through Wayland when its current API path only supports X11.

Surface negotiation is the correct abstraction.

---

# 24. GTK/Qt/OpenGL/Vulkan Compatibility

`karbeat-host` must not care what rendering toolkit the plug-in uses internally.

A plug-in might render using:

```text
GTK
Qt
JUCE
OpenGL
Vulkan
Skia
Cairo
custom software rendering
```

The host's responsibilities end at:

- native window/surface creation;
- correct parent handle;
- event-loop availability;
- size/focus/close lifecycle;
- scale metrics;
- correct lifetime.

Do not inject Flutter OpenGL contexts into the plug-in.

Do not share Flutter renderer state with plug-in editors.

Do not create native editor windows as Flutter child widgets.

Independent native toplevel windows are the initial supported model.

---

# 25. Linux GLib Integration for X11/Wayland FDs

Prefer event-driven integration instead of aggressive periodic polling.

If practical:

```text
X11 connection FD
Wayland connection FD
```

should be registered with GLib Unix FD sources.

On readiness:

```text
dispatch nonblocking native events
normalize them
return to GLib
```

A low-frequency periodic safety pump is acceptable for housekeeping, but avoid constant busy polling.

If integration complexity is high for the first pass, use a bounded periodic GLib source, document it, and migrate to FD sources in a follow-up.

Never block GLib waiting for X11/Wayland input.

---

# 26. Generic UI Task Executor

Move the common "execute something on the native UI owner" infrastructure into `karbeat-host`.

Suggested module:

```text
native_ui/runtime.rs
```

The executor itself is format-neutral.

Conceptual interface:

```rust
pub struct NativeUiHandle<P: NativeUiPlatform> {
    ...
}
```

It must support:

```rust
pub fn dispatch<F, T>(
    &self,
    operation: F,
) -> Result<NativeUiRequest<T>, NativeUiError>
where
    F: FnOnce(&mut P) -> Result<T, NativeUiError>
        + Send
        + 'static,
    T: Send + 'static;
```

However, do not force plug-in-format state into `karbeat-host`.

A format crate may dispatch a closure that, once on the UI thread:

1. accesses its own thread-local format runtime;
2. accesses/uses the shared native UI manager;
3. performs the format lifecycle operation.

If a simpler integration is needed, expose a wake/dispatch primitive rather than making `karbeat-host` aware of VST3 host state.

---

# 27. Generic UI Runtime Must Not Own Plug-In Format State

Do not put:

```text
Vst3PluginHost
ClapPluginHost
Lv2PluginHost
```

inside `karbeat-host::NativeUiRuntime`.

Instead:

```text
karbeat-host:
    owns OS/UI facilities

karbeat-vst3:
    owns VST3 component/controller/editor state

karbeat-clap:
    owns CLAP plug-in state

karbeat-lv2:
    owns LV2 instance/UI state
```

All of those must execute their non-audio operations on the same native UI owner semantics.

---

# 28. Recommended Production Type Aliases

In `karbeat-host`:

```rust
#[cfg(target_os = "linux")]
pub type SystemNativeUi =
    platform::linux::LinuxNativeUi;

#[cfg(target_os = "windows")]
pub type SystemNativeUi =
    platform::windows::WindowsNativeUi;

#[cfg(target_os = "macos")]
pub type SystemNativeUi =
    platform::macos::MacOsNativeUi;
```

Then format crates may define:

```rust
pub type NativeHost =
    FormatNativeHost<karbeat_host::SystemNativeUi>;
```

This preserves static dispatch.

---

# 29. Windows Implementation: Stub Only

Do **not** implement or claim Windows native editor support in this task.

The developer cannot currently test it.

Create a compile-visible stub in:

```text
karbeat-host/src/native_ui/platform/windows.rs
```

It should:

- define `WindowsNativeUi`;
- define `WindowsNativeWindow`;
- implement the required traits;
- return a precise `NativeUiError::PlatformBackendUnavailable` or equivalent;
- contain architecture comments/TODOs;
- compile when possible under Windows cfg;
- not contain speculative unsafe Win32 implementation.

Document the intended future trusted dependency:

```text
windows
```

from Microsoft's `windows-rs` project.

Future implementation will likely use:

```text
Win32_UI_WindowsAndMessaging
Win32_Graphics_Gdi
Win32_System_Com
```

as required.

Do not add a large Windows dependency set merely for the stub unless needed to satisfy build structure.

---

# 30. macOS Implementation: Stub Only

Do **not** implement or claim macOS native editor support in this task.

Create:

```text
karbeat-host/src/native_ui/platform/macos.rs
```

with:

- `MacOsNativeUi`;
- `MacOsNativeWindow`;
- trait implementations returning explicit unavailable errors;
- comments describing required main-thread/AppKit ownership;
- no speculative Objective-C unsafe implementation.

Document future trusted crates:

```text
objc2
objc2-app-kit
```

Future implementation must use AppKit from Rust and expose an `NSView*` parent.

Do not write custom Objective-C FFI if `objc2` bindings cover the required APIs.

---

# 31. Platform Stub Behavior

On Windows/macOS until implemented:

```text
plug-in scanning
plug-in loading without editor, if existing format backend supports it
audio processing
state management
```

may continue independently.

Attempting to open an editor should return a clear message such as:

```text
Native plug-in editor backend for Windows is not implemented
```

or:

```text
Native plug-in editor backend for macOS is not implemented
```

Never silently fall back to Flutter runner C++ callbacks.

The point of the stubs is to keep architecture honest.

---

# 32. Remove `NativeWindowApi` From VST3 Linux Architecture

Current VST3 code defines a callback ABI:

```rust
pub struct NativeWindowApi {
    ...
}
```

implemented by the Flutter runner.

That must stop being used by Linux.

Refactor the VST3 native host from:

```text
NativeHost
    |
    +-- NativeWindowApi callback table
```

to:

```text
Vst3NativeHost<P: NativeUiPlatform>
    |
    +-- P / NativeUi manager from karbeat-host
```

VST3 still owns:

- `IPlugView`;
- `IPlugFrame`;
- VST3 `IRunLoop`;
- editor protocol calls;
- component/controller lifecycle.

`karbeat-host` owns the native parent window.

---

# 33. Adapt `PluginEditorManager`

Keep `PluginEditorManager` format-specific.

Consider evolving the editor trait to separate GUI capability negotiation from attachment.

Conceptual additions:

```rust
pub trait PluginEditorManager {
    fn editor_size(...);

    fn editor_resizable(...);

    fn editor_surface_preferences(
        &mut self,
        instance: HostInstanceId,
    ) -> Result<Vec<NativeSurfaceKind>, HostError>;

    fn open_editor(
        &mut self,
        instance: HostInstanceId,
        parent: &NativeParentHandle,
    ) -> Result<(), HostError>;

    ...
}
```

Avoid returning heap-allocated format-independent vectors in a hot path if a small fixed representation is cleaner.

Alternative:

```rust
fn supports_editor_surface(
    &mut self,
    instance: HostInstanceId,
    kind: NativeSurfaceKind,
) -> Result<bool, HostError>;
```

For VST3 Linux, return true for X11 only.

---

# 34. Keep `raw-window-handle` as the Interop Boundary

`karbeat-host` already depends on:

```text
raw-window-handle
```

Retain it as the shared native-handle representation.

Do not invent a new union of:

```text
HWND
XID
wl_surface*
NSView*
```

unless a specific plug-in API cannot be expressed through `raw-window-handle`.

Use explicit `NativeSurfaceKind` alongside it for protocol negotiation.

---

# 35. Format-Specific Lifecycle Example: VST3

Target VST3 editor flow:

```text
request open editor
    |
    v
Vst3PluginHost queries IPlugView size/support
    |
    v
VST3 adapter declares X11 on Linux
    |
    v
karbeat-host::NativeUi creates X11/XWayland host window
    |
    v
returns NativeParentHandle
    |
    v
Vst3Editor maps handle to:
    X11EmbedWindowID
    |
    v
IPlugView::attached
    |
    v
NativeEditorBinding marked Attached
    |
    v
native window shown/focused
```

Close:

```text
CloseRequested
    |
    v
Vst3Editor::close
    |
    v
IPlugView::removed
    |
    v
drop VST3 editor
    |
    v
drop NativeEditorBinding
    |
    v
drop native window
```

---

# 36. Future CLAP Flow

Do not implement CLAP as part of this migration unless already required.

But design for:

```text
CLAP plug-in reports supported GUI APIs
    |
    v
CLAP host adapter intersects:
    plugin supported APIs
    ∩
    NativeUi capabilities
    |
    v
select Wayland/X11/Win32/Cocoa
    |
    v
create host native window
    |
    v
clap_plugin_gui.set_parent(...)
```

This is why `NativeSurfaceKind` belongs in `karbeat-host`.

---

# 37. Future LV2 Flow

Do not encode LV2 toolkit semantics into the native window layer.

An LV2 adapter may have UI implementations requiring:

- X11 parent;
- toolkit-specific host support;
- external UI;
- other LV2 features.

The LV2 adapter chooses what can use the generic native window subsystem.

Unsupported LV2 UI styles should return format-specific unsupported errors rather than contaminating the generic abstraction.

---

# 38. Native Window Visibility Ordering

Shared invariant:

```text
create native window hidden
    |
    v
obtain native parent handle
    |
    v
format attaches plug-in GUI
    |
    v
show host window
    |
    v
request focus
```

Do not show an empty host window before plug-in attachment succeeds.

If attachment fails:

```text
drop hidden native window
return original plug-in error
```

---

# 39. Native Window Existence Before Attachment

The host object must exist at the OS/compositor level before giving the parent handle to a plug-in.

Examples:

### X11

```text
create XID
flush request to X server
then attach plug-in
```

### Wayland

Ensure the required surface object exists and the protocol state is valid before passing the `wl_surface` pointer.

### Future Windows

`CreateWindowEx` must have succeeded before exposing HWND.

### Future macOS

NSWindow/content NSView must exist before exposing NSView.

Created does not imply visible.

---

# 40. Focus Semantics

Call the API:

```rust
request_focus()
```

not:

```rust
focus()
```

Focus is not guaranteed.

The compositor/window manager may reject or defer it.

Generic semantics:

> Successfully issue the platform-appropriate focus/activation request.

Do not promise that the window becomes focused.

---

# 41. DPI and Scale Handling

Treat DPI/scale changes as first-class events.

Shared event:

```rust
NativeWindowEvent::ScaleFactorChanged
```

Backend-specific sources:

```text
X11:
desktop/output scale mechanisms available to backend

Wayland:
output/surface scale / fractional scale where supported

future Windows:
WM_DPICHANGED

future macOS:
backing scale changes
```

Do not conflate:

```text
client logical size
framebuffer/render pixel size
```

The native parent is for third-party UI code; incorrect scale semantics can break OpenGL/Vulkan/HiDPI plug-ins.

---

# 42. External Native Destruction

Different systems can destroy a window outside the ideal close sequence.

Emit:

```rust
NativeWindowEvent::Destroyed
```

distinct from:

```rust
CloseRequested
```

`Destroyed` means:

> The native parent is already gone. Format cleanup must be best-effort.

Do not try to resize/focus a destroyed window.

---

# 43. Error Model

Add a `NativeUiError` in `karbeat-host`.

Recommended variants/concepts:

```text
WrongThread
RuntimeUnavailable
RuntimeInitializationFailed
PlatformBackendUnavailable
DisplayUnavailable
SurfaceUnsupported
WindowCreationFailed
WindowDestroyed
InvalidSize
InvalidHandle
EventDispatchFailed
QueueFull
RequestCancelled
NativeOperationFailed
```

Avoid making every error:

```text
String
```

Include source errors where reasonable.

Do not put VST3/CLAP/LV2 error types into this enum.

---

# 44. UI Thread/Main-Context Invariants

Document in `karbeat-host::native_ui`.

All of these are UI-owner-only:

```text
NativeUiPlatform object
NativeWindow objects
X11 connection
Wayland connection/event queue
native window event dispatch
native window mutation
plug-in editor attach/detach
non-audio plug-in GUI lifecycle
```

Cross-thread safe object:

```text
NativeUiWakeHandle
```

and request/reply channels only.

Do not mark native window/platform objects `Send` or `Sync` unless the underlying API genuinely permits it and the architecture needs it.

Prefer keeping them `!Send` by construction.

---

# 45. Flutter Runner Independence

Definition:

> Removing `linux/runner/plugin_windows.cc` must not break plug-in editor behavior after the Rust migration.

The primary migration should first make that statement true while allowing the old file to remain compiled temporarily.

Then remove or disconnect the C++ service in a separate cleanup.

No new API should require:

```text
GtkWindow*
GdkWindow*
HWND from Flutter
NSWindow from Flutter
Flutter engine event callback
Flutter timer
```

---

# 46. Linux Runtime Bootstrap

The first native UI request must self-bootstrap the Rust service.

Conceptual flow:

```text
FRB worker / control worker
    |
    v
ensure native UI dispatcher exists
    |
    v
schedule initialization on GLib default MainContext
    |
    v
LinuxNativeUi::initialize()
    |
    +-- record owner thread
    +-- connect Wayland if available
    +-- connect X11 if available
    +-- install event integration
    +-- publish WakeHandle
    |
    v
request is executed on UI owner
```

Do not require C++ to call a Rust `poll` function first.

---

# 47. UI Request Timeout Semantics

Preserve the existing useful distinction:

```text
request has not started
```

versus:

```text
request is already executing inside third-party plug-in code
```

Before start:

- timeout may cancel the queued request;
- no native mutation occurs.

After start:

- do not return a fake timeout;
- wait for actual plug-in operation completion;
- otherwise native state could become orphaned.

Do not solve dispatch bugs by merely increasing timeout durations.

---

# 48. UI Fairness

Generic runtime policy should limit host-owned work per main-loop callback.

For example:

```rust
const MAX_UI_TASKS_PER_TICK: usize = 4;
```

or use a small time budget.

Do not drain 64 arbitrary plug-in lifecycle operations in one GLib callback.

Yield back to GTK/Flutter regularly.

This policy belongs in shared Rust runtime code.

---

# 49. Cooperative Long Operations

Some plug-in host operations involve hundreds or thousands of calls.

Example from current VST3 preparation:

```text
16 MIDI channels × 130 controller slots
```

can produce 2,080 mapping queries.

The OS abstraction does not itself solve long plug-in lifecycle work.

After the native UI migration, introduce cooperative format-level state machines where necessary.

Rule:

> Yield between host-owned groups of plug-in API calls. Do not attempt to preempt a single third-party ABI call.

Shared native UI executor should make rescheduling these jobs easy.

---

# 50. Trusted Crates

Use established external crates for low-level platform work where possible.

## Already used

```text
raw-window-handle
```

Keep it as the native handle boundary.

## Linux runtime

```text
glib
```

Use Rust GLib bindings for main-context scheduling and sources.

## Linux X11

```text
x11rb
```

Use instead of handwritten Xlib FFI.

## Linux Wayland

```text
wayland-client
smithay-client-toolkit
```

Use Smithay Client Toolkit for XDG shell/window mechanics where it provides the required behavior.

## Future Windows

```text
windows
```

Official Microsoft Rust bindings.

Stub only in this task.

## Future macOS

```text
objc2
objc2-app-kit
```

Use Rust AppKit bindings.

Stub only in this task.

---

# 51. Cargo Dependency Placement

Dependencies for native window management belong to:

```text
rust/karbeat-host/Cargo.toml
```

not VST3.

Use target-specific dependencies:

```toml
[target.'cfg(target_os = "linux")'.dependencies]
glib = "..."
x11rb = "..."
wayland-client = "..."
smithay-client-toolkit = "..."
```

Retain:

```toml
raw-window-handle.workspace = true
```

Do not add Windows/macOS heavy dependencies during this task unless required for stub compilation.

Record intended future crates in comments/design docs.

Pin versions according to workspace policy after checking compatible current versions.

---

# 52. Testing Strategy — Linux First

Developer environment:

```text
Linux
KDE Plasma
```

Linux is the only platform that must pass real functional acceptance tests now.

---

## Plasma X11 session

Test:

1. start DigiDAW;
2. load Vital;
3. confirm Flutter remains responsive;
4. resize Flutter;
5. open Vital editor;
6. resize Vital editor;
7. close Vital editor;
8. reopen;
9. play audio/MIDI;
10. remove Vital;
11. load again;
12. confirm no leaked windows;
13. confirm no lifecycle timeouts.

---

## Plasma Wayland session with XWayland

Test:

1. confirm Flutter runs under Wayland;
2. confirm Wayland capability detected;
3. confirm X11/XWayland capability detected;
4. add Vital;
5. VST3 requests X11 explicitly;
6. Rust creates XWayland host window;
7. open Vital editor;
8. resize Flutter while editor is open;
9. resize editor;
10. close/reopen;
11. verify Flutter OpenGL rendering remains responsive.

---

## Plasma Wayland without XWayland

If reproducible:

1. audio plug-in load must still succeed;
2. opening a VST3 editor must return a clear X11-required error;
3. application must remain responsive;
4. no fallback into C++ runner window creation.

---

# 53. GTK Coexistence Test

The Rust subsystem must coexist with GTK without owning GTK widgets.

Verify:

- GLib main context continues processing Flutter/GTK;
- no nested GTK event loop is started;
- no GTK object crosses into plug-in host code;
- no `GtkWindow*` is stored in `karbeat-host`;
- main Flutter window can resize continuously;
- plug-in editor event activity does not freeze Flutter;
- closing the Flutter app terminates without native editor callbacks accessing destroyed application state.

---

# 54. Rendering Toolkit Compatibility Test

Where available, test plug-ins using different GUI stacks.

Target categories:

```text
OpenGL-heavy plug-in
JUCE plug-in
GTK plug-in if available
Qt plug-in if available
software-rendered plug-in
```

The purpose is not to special-case them.

The purpose is to verify that the host provides a valid native parent/window/event environment without interfering with the plug-in renderer.

---

# 55. Unit Tests in `karbeat-host`

Test generic policy independently of a real display where possible.

Required unit tests:

- NativeWindowId monotonic uniqueness;
- stale event rejection;
- programmatic resize acknowledgement suppression;
- user resize forwarding;
- close ordering;
- cannot use binding after Closed;
- duplicate CloseRequested is harmless;
- `Destroyed` transition is handled;
- fixed constraints generation;
- scale-factor event state update;
- surface capability negotiation;
- unsupported required surface returns error;
- preferred surface falls back correctly.

---

# 56. X11 Integration Tests

Use Xvfb when practical.

Test:

- connect;
- create hidden window;
- raw X11 handle valid;
- set title;
- map/show;
- resize;
- constraints;
- ConfigureNotify;
- WM_DELETE_WINDOW translation;
- destruction;
- multiple windows;
- stale event after window replacement.

Document a developer command for Xvfb tests.

---

# 57. Wayland Integration Tests

Wayland CI may be harder.

At minimum:

- unit test capability/selection logic;
- compile the Wayland implementation;
- test connection failure cleanly;
- test no-Wayland environment behavior.

If a headless Wayland compositor is available in CI later, add full integration tests.

Do not block the Linux X11 migration on perfect Wayland CI automation.

However, KDE Plasma Wayland manual acceptance is required.

---

# 58. Windows/macOS Stub Tests

Stubs should have simple tests where cfg allows:

```text
initialize/open editor returns PlatformBackendUnavailable
error string is explicit
no panic
```

Do not report these platforms as supported.

---

# 59. Changes to `karbeat-vst3`

After shared `karbeat-host::native_ui` exists:

Refactor VST3 to:

- remove Linux native-window callback ownership;
- use `SystemNativeUi`;
- request X11 on Linux;
- obtain `NativeParentHandle`;
- convert parent into VST3 `X11EmbedWindowID`;
- route native resize/close events through shared editor binding policy;
- preserve VST3 `IRunLoop`;
- preserve VST3 component/controller thread affinity;
- preserve audio processor isolation.

The VST3 editor protocol remains in:

```text
karbeat-vst3/src/editor.rs
```

The native window implementation does not.

---

# 60. Legacy Flutter Runner Migration

Primary goal:

Make runner VST3 window code unused.

Do not immediately delete it before proving the Rust implementation.

Phase:

```text
Rust implementation active
    |
    v
verify old C++ callbacks are never invoked
    |
    v
remove legacy native-host poll/window startup
    |
    v
remove plugin_windows.cc/.h from Linux build
```

This cleanup should be a separate commit.

Do not mix functional migration and runner deletion if it makes regression debugging harder.

---

# 61. Windows/macOS Runner Independence

Even though the real native backends are stubs now, architecture must ensure their future implementation will not require:

```text
windows/runner/plugin_windows.cpp
macos/Runner custom plug-in window callbacks
```

Future platform support must be implemented in:

```text
karbeat-host/src/native_ui/platform/windows.rs
karbeat-host/src/native_ui/platform/macos.rs
```

using trusted Rust bindings.

---

# 62. Suggested Implementation Sequence

## Commit 1 — Shared native UI types/traits

Add to `karbeat-host`:

```text
NativeWindowId
NativeWindowSize
NativeWindowMetrics
NativeWindowConstraints
NativeSurfaceKind
NativeSurfacePreference
NativeSurfaceCapabilities
NativeParentHandle
NativeWindowEvent
NativeUiError
NativeWindow
NativeUiPlatform
NativeUiWakeHandle
```

Add unit tests.

No platform behavior yet.

---

## Commit 2 — Generic editor binding policy

Add:

```text
NativeEditorBinding
NativeEditorLifecycle
resize feedback suppression
stale-window event protection
close/destroy transitions
surface selection helpers
```

Unit test heavily.

---

## Commit 3 — Windows/macOS stubs

Add compile-visible static-dispatch platform modules.

They must return explicit unsupported errors.

Do not implement real APIs.

---

## Commit 4 — Linux runtime/bootstrap

Add:

```text
glib main-context integration
owner thread tracking
cross-thread wake handle
bounded task scheduling
nonblocking periodic housekeeping
```

No Flutter runner changes.

---

## Commit 5 — Linux X11 backend

Implement using `x11rb`.

Test under X11/Xvfb.

---

## Commit 6 — Linux Wayland backend

Implement using:

```text
wayland-client
smithay-client-toolkit
```

Add capability probing and runtime X11/Wayland selection.

---

## Commit 7 — VST3 migration

Move VST3 editor host windows from `NativeWindowApi` to `karbeat-host::native_ui`.

Linux VST3 explicitly requests X11.

Do not remove C++ runner code yet.

---

## Commit 8 — VST3 dispatch self-bootstrap

Ensure VST3 lifecycle calls no longer need C++ `digidaw_native_host_poll`.

Use the Rust UI runtime/wake mechanism.

Test Vital.

---

## Commit 9 — Remove Linux runner dependency

After acceptance:

- remove startup call;
- remove timer/poll service;
- remove native window callback table;
- remove Linux `plugin_windows.cc/.h` build integration.

This is the only stage that should edit Flutter runner configuration.

If the stated requirement is to avoid runner changes entirely during the functional work, make this cleanup optional and perform it later.

---

## Commit 10 — Cooperative expensive VST3 lifecycle work

Profile and chunk host-owned long loops.

Do not change OS abstraction for this.

---

# 63. Validation Commands

Baseline:

```bash
git status
cargo check --workspace
cargo test -p karbeat-host
cargo test -p karbeat-vst3
```

During implementation:

```bash
cargo fmt --all -- --check
cargo check -p karbeat-host
cargo check -p karbeat-vst3
cargo test -p karbeat-host
cargo test -p karbeat-vst3
```

Final:

```bash
cargo clippy --workspace --all-targets
cargo test --workspace
flutter build linux
```

Then manual KDE tests.

---

# 64. Acceptance Criteria

The work is accepted only when all applicable statements are true.

## Architecture

- Native plug-in UI traits live in `karbeat-host`.
- No VST3-specific type is required by native window management.
- OS selection uses static dispatch.
- Linux may dynamically select X11 vs Wayland as a display protocol.
- Windows backend exists only as explicit stub.
- macOS backend exists only as explicit stub.
- Flutter C++ runner is not part of plug-in editor correctness.

## Linux

- Rust owns native plug-in host windows.
- X11 works in Plasma X11.
- X11 via XWayland works in Plasma Wayland for VST3.
- Native Wayland window support exists for formats that can use it.
- GTK/Flutter main loop remains responsive.
- No second application event loop is created.
- No Flutter GtkWindow pointer is required.

## VST3

- plug-in load works;
- Vital load works;
- editor opens;
- editor resizes;
- editor closes;
- editor reopens;
- Flutter resizes while editor is open;
- no repeated OpenGL frame timeout caused by lifecycle deadlock;
- no `UI request timed out before execution`;
- editor unsupported error is clean when X11/XWayland is absent.

## Resource lifetime

- plug-in GUI detached before native parent destruction;
- native window destroyed before plug-in module unload;
- stale OS events cannot target replacement windows;
- audio endpoint remains independent from native UI;
- no UI/display APIs execute on the audio thread.

---

# 65. Explicit Non-Goals

Do not implement in this task:

- real Windows editor backend;
- real macOS editor backend;
- Windows Flutter runner integration;
- macOS Flutter runner integration;
- embedded Flutter widgets for plug-in UIs;
- process sandboxing/crash isolation;
- full CLAP hosting;
- full LV2 hosting;
- arbitrary Wayland support inside VST3 if VST3 itself only exposes X11 embedding;
- custom rendering of plug-in UI contents.

The abstraction must support those future formats without requiring redesign.

---

# 66. Architectural End State

```text
                         DigiDAW
                            |
                            v
                 +---------------------+
                 |    karbeat-host     |
                 |                     |
                 | NativeUiPlatform<P> |
                 | NativeWindow        |
                 | NativeEditorBinding |
                 | event normalization |
                 | UI dispatch/wakeup  |
                 +----------+----------+
                            |
                 static OS dispatch
                            |
       +--------------------+--------------------+
       |                    |                    |
       v                    v                    v
+---------------+    +---------------+    +---------------+
| LinuxNativeUi |    | Windows stub  |    | macOS stub    |
|               |    |               |    |               |
| GLib          |    | future:       |    | future:       |
| X11/x11rb     |    | windows-rs    |    | objc2/AppKit  |
| Wayland       |    |               |    |               |
| Smithay       |    +---------------+    +---------------+
+-------+-------+
        |
        | NativeParentHandle
        v
+-------------------------------------------------------+
| plug-in format adapters                               |
|                                                       |
| karbeat-vst3      future karbeat-clap    karbeat-lv2 |
|                                                       |
| VST3 GUI protocol  CLAP GUI protocol     LV2 UI      |
+--------------------------+----------------------------+
                           |
                           v
                    third-party plug-in
                           |
                           v
                 its own renderer/toolkit
            GTK / Qt / JUCE / OpenGL / Vulkan / etc.
```

Flutter is intentionally absent from the native plug-in editor ownership chain.

---

# 67. Core Design Rule

The implementation should preserve this statement:

> `karbeat-host` owns the OS-native plug-in window/runtime abstraction; each plug-in format owns only its protocol-specific editor attachment; Flutter is merely a caller and never a native plug-in window service.

And on Linux:

> GTK/Flutter supplies the already-running GLib main context, but Rust owns all plug-in UI scheduling and all X11/Wayland native plug-in windows independently of the Flutter C++ runner.
