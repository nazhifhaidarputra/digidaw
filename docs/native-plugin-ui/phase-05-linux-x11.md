# Phase 05 — Linux X11/XWayland backend

- Status: complete
- Commit: `feat(host): implement X11 native editor windows`
- Next action: implement the independent Wayland probe and SCTK XDG toplevel backend in phase 06.

## Checklist

- [x] Probe X11 independently through `x11rb::connect`.
- [x] Retain one X11 connection on the UI owner.
- [x] Create hidden input/output windows with titles, class, constraints, and WM close protocol.
- [x] Support show, hide, focus, client resize, and deterministic destruction.
- [x] Expose XCB parent/display handles.
- [x] Normalize configure, focus, close, and destroy events.
- [x] Register the nonblocking X11 connection FD with the default GLib loop.
- [x] Track `Xft.dpi` changes as scale-factor changes without changing logical client size.
- [x] Add an ignored live-display integration test.

## Decisions

- The pure-Rust `x11rb` connection cannot expose an `xcb_connection_t`, so the raw XCB display
  handle intentionally has a null connection pointer and carries the correct screen number. VST3
  consumes the XID from the window handle.
- `RESOURCE_MANAGER` changes refresh `Xft.dpi`; the factor is bounded to 0.5–4.0 and defaults to
  1.0 when the resource is absent or malformed.
- GLib's Rust wrapper does not expose `g_unix_fd_add_full`, so the runtime contains a small scoped
  adapter whose destroy callback owns the Rust closure.

## Validation

- `cargo test -p karbeat-host` — passed: 30 tests, 1 live-display test ignored, 3 doc tests.
- `cargo test -p karbeat-host creates_resizes_and_destroys_a_live_window -- --ignored --nocapture`
  — passed against `DISPLAY=:0` (XWayland). The sandboxed attempt was denied access to the display
  socket; the approved live-display run passed.
- `cargo clippy -p karbeat-host --all-targets` — passed with existing workspace warnings. A stricter
  `-D warnings` run remains blocked by pre-existing warnings in dependency crates within the
  workspace.

## Blockers

- None.
