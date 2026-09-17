# Phase 11 — Flutter/Vital acceptance

- Status: complete
- Commit: `test(vst3): cover the Flutter Vital editor lifecycle`
- Next action: no native plug-in UI phase remains; address the recorded unrelated repository
  validation debt separately if desired.

## Checklist

- [x] Scan and add `/usr/lib/vst3/Vital.vst3` through the production Flutter UI.
- [x] Require at least two bounded-latency Flutter frames while Vital preparation is pending.
- [x] Open Vital's real XWayland editor through the Flutter-to-Rust API.
- [x] Change a real continuous Vital parameter deterministically and observe the value in Rust/audio
  telemetry.
- [x] Play a preview note and require finite, nonzero mixer output.
- [x] Close the editor twice, reopen it, and delete the track while the editor is open.
- [x] Verify descriptor and telemetry retirement, no timeout notification, and idempotent cleanup.
- [x] Diagnose and regress the `addMidiTrackGenerator` Flutter freeze.

## Freeze diagnosis and fix

- The cooperative VST3 worker was not sufficient on its own because the Flutter Rust Bridge add
  call retained the exclusive `DawContext` lock while waiting for `NativePrepareRequest`.
- The workspace's 60 FPS mixer telemetry callback used a synchronous FFI call on the GTK thread.
  When that callback attempted to acquire `DawContext` during preparation, GTK stopped servicing
  the GLib owner. The preparation worker then waited for GLib, reproducing the previous Rust
  request timeout as a lock inversion and leaving Flutter unresponsive.
- A reference-counted backend-operation gate now suppresses synchronous mixer and plug-in
  telemetry reads during generator/effect insertion. Dart continues producing frames while the
  Rust worker waits and GLib advances the bounded VST3 job. The gate releases in `finally`,
  including failures and overlapping operations.
- The integration test uses explicit UI-state waits instead of `pumpAndSettle`, because DigiDAW's
  active tickers intentionally prevent a global settled state.

## Validation

- `flutter test test/app/providers/backend_operation_gate_test.dart
  test/features/plugins/plugin_browser_dialog_test.dart` — passed, 7 tests.
- Focused `flutter analyze` for all changed Dart files — passed with no issues.
- `VITAL_VST3_PATH=/usr/lib/vst3/Vital.vst3 flutter test
  integration_test/vst3_plugin_workflow_test.dart -d linux` — passed in the live KDE Wayland/XWayland
  session. It exercised UI insertion responsiveness, the real editor, parameter telemetry, audible
  output, duplicate close, reopen, and deletion with the editor open.
- `VITAL_VST3_PATH=/usr/lib/vst3/Vital.vst3 cargo test -p karbeat-vst3 --test vital -- --ignored
  --test-threads=1` — passed.
- `VITAL_VST3_PATH=/usr/lib/vst3/Vital.vst3 cargo test -p karbeat-core --test vst3_core --
  --ignored --test-threads=1` — passed.
- `cargo clippy --workspace --all-targets` — passed with existing warnings.
- `flutter build linux` — passed and produced `build/linux/x64/release/bundle/karbeat`.
- `flutter analyze` — the changed files are clean; the full command exits with four unrelated
  existing warnings in `track_widgets.dart`, `main_screen.dart`, `export_audio.dart`, and
  `sidechain.dart`.
- `cargo test --workspace` — reached the existing `karbeat-core` baseline of 245 passed and 5
  unrelated failures in mixer automation, preview note, clipboard remapping, and zero-duration
  note expectations.
- `cargo fmt --all -- --check` — blocked by extensive pre-existing formatting drift across
  unrelated Rust files. No bulk formatting was applied, preserving user changes.

## Blockers

- None for the native plug-in UI lifecycle. The unrelated formatting, analyzer, and core-test debt
  above remains outside this implementation.
