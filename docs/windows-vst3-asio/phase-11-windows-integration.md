# Phase 11: Full Windows Integration

Status: Hardware validation pending

Implemented prerequisites:

- Rust-owned main STA message loop for Flutter and VST3 windows.
- Real Win32 VST3 parent windows and editor lifecycle plumbing.
- Windows scanner COM initialization and bundle-path coverage.
- Windows-only CPAL ASIO feature enablement.
- Explicit FlexASIO selection semantics.
- Stereo-to-multichannel output adaptation.

Automated verification completed:

- Host API, VST3, core, and Flutter FFI Windows compilation passed.
- VST3 library tests passed (10 tests).
- Host API tests passed except for the documented pre-existing scanner deduplication failure.
- Focused audio-backend tests passed (10 tests).
- Windows dispatcher/native-window and VST3 bundle-path tests passed.
- `flutter build windows --debug` completed and produced the Windows executable.

Manual acceptance checklist:

- Launch a packaged build on Windows 10 and Windows 11.
- Scan and instantiate Vital VST3.
- Play audio, open the native editor, edit parameters, and save/restore state.
- Resize, change DPI, close/reopen the editor, reconfigure DSP, and remove the plugin.
- Select ASIO and FlexASIO in Host & Devices and verify persistence and streaming.
- Close the application with an editor open and confirm clean host, window, COM, and process teardown.
- Run the complete Linux regression suite before merge.
