# Phase 9: FlexASIO Selection Semantics

Status: Implemented; device test pending

Completed:

- Removed the hidden global preference for FlexASIO when using the normal system host.
- Preserved the WASAPI/system default path when no explicit host/device is selected.
- For an explicitly selected ASIO host, use its default output device first; if none exists, prefer enumerated FlexASIO and then the first ASIO output.
- Preserved exact saved device-ID selection and a clear error when an explicitly saved device disappears.

Verification:

- The core audio backend compiles with Windows ASIO enabled.

Remaining acceptance work:

- Verify FlexASIO enumeration, explicit selection, persistence, restart behavior, and missing-device fallback with FlexASIO installed.
