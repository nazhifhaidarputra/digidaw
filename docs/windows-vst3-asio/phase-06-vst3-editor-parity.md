# Phase 6: VST3 Editor Parity

Status: Implemented; live-plugin test pending

Completed:

- Preserved the existing Win32 editor attachment ABI (`HWND`).
- Connected VST3 editor lifecycle work to the Windows native-owner dispatcher.
- Enabled open, show, focus, resize negotiation, event polling, close, reopen, and teardown through the real Win32 parent window.
- Updated the Vital integration harness so its main thread can own and run the Rust Win32 loop.

Verification:

- The VST3 library tests passed on Windows.
- The VST3 and core Vital integration targets compile and safely skip when the configured Vital path is absent.

Remaining acceptance work:

- Run the Vital VST3 editor test with a real Vital installation.
- Validate plugin-driven resize, user resize, DPI transition, close/reopen, and shutdown with the editor open.
