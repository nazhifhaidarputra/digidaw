# Phase 5: Win32 Native Windows

Status: Implemented and unit tested

Completed:

- Replaced the Windows native UI stub with a Win32 backend.
- Registered a process-local window class and stored a stable boxed context in `GWLP_USERDATA`.
- Created editor host windows hidden by default and exposed a raw Win32 `HWND` parent handle.
- Implemented show, hide, focus, title, constraints, client resizing, DPI-aware metrics, and teardown.
- Translated close, size, DPI, focus, and destroy messages into native UI events.
- Enforced native-owner thread checks.

Verification:

- The Windows integration unit test covered creation, parent handle, title, resizing, constraints, visibility, and destruction.

Remaining acceptance work:

- Manually validate DPI changes, user-driven resize, focus behavior, and close behavior on Windows 10 and 11.
