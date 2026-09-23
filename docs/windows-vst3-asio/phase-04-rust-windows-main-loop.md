# Phase 4: Rust-Owned Windows Main Loop

Status: Implemented and unit tested

Completed:

- Added Rust Windows main-thread initialization, STA COM ownership, process message loop, and shutdown entry points.
- Bound `NativeUiDispatcher` to the Windows main STA thread rather than creating a second UI thread.
- Added a message-only dispatcher window with private wake and shutdown messages.
- Coalesced cross-thread wakes and bounded queue/executor work per dispatch.
- Added periodic native-host pumping through `WM_TIMER`.
- Moved `GetMessageW`, `TranslateMessage`, and `DispatchMessageW` into Rust.
- Removed COM and message-loop ownership from `windows/runner/main.cpp`.
- Linked the Flutter runner to the existing Cargokit import library for the stable C ABI handoff.

Verification:

- The Windows owner-thread dispatch/window integration test passed.
- Static inspection confirms the C++ runner contains no Win32 message-pump or COM initialization calls.
- `flutter build windows --debug` linked the C++ runner to the Rust exports and produced `karbeat.exe`.

Remaining acceptance work:

- Exercise normal Flutter close, plugin-host teardown, and process exit in the packaged application.
