# Phase 04 — GLib owner runtime

- Status: complete
- Commit: `feat(host): add bounded GLib native UI runtime`

## Completed

- Added asynchronous default-main-loop bootstrap and a cross-thread wake handle.
- Added a bounded 128-task queue with four operations per GLib callback.
- Preserved cancellation before start and wait-for-result after execution begins.
- Added owner-thread rejection and format-neutral local interval installation.

## Validation

- Runtime cancellation/fairness test passed.
- `cargo test -p karbeat-host`: 30 unit tests and 3 doc tests passed.

## Next action

Replace the temporary Linux platform with the X11/XWayland backend.
