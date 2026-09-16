# Phase 03 — Platform stubs

- Status: complete
- Commit: `feat(host): add native UI platform stubs`

## Completed

- Added target-selected `SystemNativeUi` aliases.
- Added explicit Windows and macOS unavailable platform/window implementations.
- Added the Linux module boundary, ready for runtime and display backends.

## Validation

- `cargo test -p karbeat-host`: 29 unit tests and 3 doc tests passed.
- Only the installed Linux target was compiled; Windows/macOS source is cfg-visible but cannot be
  cross-checked until those Rust targets are installed.

## Next action

Implement the bounded GLib UI-owner dispatcher and request policy.
