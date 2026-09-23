# Phase 8: Enable ASIO in Windows FFI

Status: Implemented and compile verified

Completed:

- Enabled `karbeat-core/asio` only for Windows builds of `karbeat-flutter-ffi`.
- Kept non-Windows FFI dependency behavior unchanged.
- Added early Windows build checks for Cargo, rustup, MSVC x64 tools, Clang, `libclang.dll`, and the `x86_64-pc-windows-msvc` Rust target.
- Kept ASIO behind CPAL rather than introducing a separate audio backend.

Verification:

- `cargo check -p karbeat_flutter_ffi` passed on Windows.
- Cargo feature inspection confirmed `karbeat_flutter_ffi -> karbeat-core/asio -> cpal/asio`.

Remaining acceptance work:

- Confirm the ASIO host appears in Host & Devices on a system with an installed ASIO driver.
