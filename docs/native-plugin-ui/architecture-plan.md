# Rust-owned native plug-in UI architecture

This is the repository-local design reference distilled from
`DIGIDAW_RUST_NATIVE_PLUGIN_UI_ABSTRACTION_PLAN.md`, supplied for this migration.

## Design rule

`karbeat-host` owns the OS-native plug-in window/runtime abstraction. Plug-in format crates own
only protocol-specific editor attachment. Flutter calls the host but never initializes, polls,
creates, resizes, focuses, or destroys native plug-in windows.

## Required architecture

- Select the OS backend statically with `SystemNativeUi`; Linux may probe X11 and Wayland at
  runtime.
- Keep VST3, CLAP, LV2, and platform protocol types out of the common native-window layer.
- Represent surface technology explicitly and expose both raw window and optional display handles.
- Use generation-safe window IDs, logical client sizes, separate scale metrics, min/max constraints,
  normalized events, and typed native UI errors.
- Keep platform/window objects on the UI owner. Cross-thread callers use bounded request/reply
  queues and a wake-only handle.
- Suppress programmatic resize acknowledgements, reject stale events, and detach the format editor
  before destroying its native parent.
- Never unload a module while an editor, callback, native event, processor endpoint, or instance
  still references it.

## Linux implementation

- Reuse Flutter/GTK's GLib default main context without creating a second application loop.
- Use `x11rb` for X11/XWayland and `wayland-client` plus Smithay Client Toolkit for Wayland.
- Probe both connections instead of trusting environment labels alone.
- VST3 requires X11/XWayland and must remain audio-capable when an editor surface is unavailable.
- Integrate display file descriptors with GLib and keep all dispatch nonblocking.

## Platform scope

Linux is implemented and tested. Windows and macOS expose honest, compile-visible unsupported
stubs. CLAP/LV2 hosting, Flutter-embedded native editors, sandboxing, and custom plug-in rendering
are out of scope.

## Acceptance

Vital must load, open in a Rust-owned X11/XWayland window, resize, close, reopen, process a real
parameter change, produce audio, and tear down safely through the Flutter-to-Rust production flow.
Removing the legacy Linux runner service must not change that behavior.
