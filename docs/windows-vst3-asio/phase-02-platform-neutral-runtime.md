# Phase 2: Platform-Neutral Runtime

Status: Implemented; Linux regression pending

Completed:

- Split `native_ui/runtime.rs` into `runtime/common.rs`, `runtime/linux.rs`, `runtime/windows.rs`, and `runtime/mod.rs`.
- Preserved the bounded Tokio request queue (`128`) and bounded per-tick drain (`4`).
- Kept the local executor, request cancellation, synchronous dispatch, asynchronous dispatch, and local spawning in common code.
- Added host-owned `NativeUiControlFlow`.
- Moved GLib idle/timer scheduling and Unix FD integration behind Linux compilation.
- Exported the runtime on both Linux and Windows.

Verification:

- `cargo check -p karbeat-host-api` passed on Windows.
- Windows runtime owner/dispatch test passed.

Remaining acceptance work:

- Run the host API regression suite on Linux to confirm unchanged GLib behavior.
