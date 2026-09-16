# Phase 06 — Linux Wayland backend

- Status: complete
- Commit: `feat(host): implement Wayland native editor windows`
- Next action: migrate the VST3 editor manager and native lifecycle onto `NativeEditorBinding` in
  phase 07.

## Checklist

- [x] Probe Wayland independently of X11 and session-type hints.
- [x] Bind `wl_compositor`, XDG shell, outputs, and optional XDG activation through SCTK.
- [x] Create XDG toplevel surfaces with titles, app ID, logical size, and constraints.
- [x] Normalize configure, close, and output scale changes.
- [x] Implement show/unmap, focus activation, resize geometry, and deterministic destruction.
- [x] Expose non-null raw `wl_display` and `wl_surface` handles through the `system` backend.
- [x] Keep a prepared read guard across GLib polling, then read, dispatch pending events, flush, and
  prepare the next nonblocking read.
- [x] Add an ignored live-compositor integration test.

## Decisions

- Wayland client size is retained in logical surface coordinates. `set_client_size` updates XDG
  window geometry; compositor configure events remain authoritative when a concrete size is sent.
- XDG activation is optional at probe time. A focus request returns a precise operation error when
  the compositor does not expose it.
- Temporary output absence does not invalidate a surface. SCTK's compositor scale callback updates
  scale independently while retaining the current logical client size.

## Validation

- `cargo test -p karbeat-host` — passed: 30 tests, 2 live-display tests ignored, 3 doc tests.
- `cargo test -p karbeat-host creates_and_destroys_a_live_toplevel -- --ignored --nocapture` —
  passed against the current KDE compositor at `WAYLAND_DISPLAY=wayland-0`.
- `cargo clippy -p karbeat-host --lib` — no native UI errors; existing workspace warnings remain.

## Blockers

- None.
