# Phase 12 — Hosted Plug-in Audio Correctness

## Status

Complete.

## Scope

Follow-up defects found during live Vital testing after the native editor migration:

- preserve instrument release envelopes after NoteOff;
- remove plug-in-output clicks caused by buffer-boundary resets;
- reconfigure live hosted plug-ins when the DSP sample rate changes;
- keep long native preparation work from blocking synchronous Flutter telemetry.

## Checklist

- [x] Trace MIDI event lifetime and rule out repeated NoteOn delivery.
- [x] Identify zero-tail generator reset as the ADSR/click source.
- [x] Add a regression test proving an instrument remains processable after NoteOff.
- [x] Replace live hosted endpoints at a new sample rate on the control/UI owners.
- [x] Add atomic replacement and rollback-focused Rust tests.
- [x] Gate Flutter telemetry while DSP configuration performs native work.
- [x] Limit debug level-3 optimization to Rodio to keep development builds practical.
- [x] Run focused Rust and Flutter tests.
- [x] Run workspace validation and live Vital acceptance where available.
- [x] Commit the completed follow-up without pushing.

## Decisions

- Generator instances remain active while installed. `tail_samples()` is useful for export length,
  but zero is not a safe signal that a synthesizer's release envelope has become silent.
- VST3 setup and teardown stay off the audio thread. A sample-rate change prepares replacement
  endpoints first, swaps them atomically in the engine, and retires the old instances afterward.
- Debug builds use Cargo's default optimization level except for `rodio`, which remains at
  `opt-level = 3` so long audio files retain acceptable load performance. Release builds remain
  fully optimized.

## Validation

- `cargo test -p karbeat-core hosted_reconfiguration --no-fail-fast`: passed both atomic swap and
  stale-replacement rollback tests.
- `cargo test -p karbeat-core generator_remains_active_after_note_off_for_release_envelope
  --no-fail-fast`: passed.
- `VITAL_VST3_PATH=/usr/lib/vst3/Vital.vst3 cargo test -p karbeat-core --test vst3_core --
  --ignored --test-threads=1`: passed, including audible output after changing the live DSP rate
  from 48 kHz to 96 kHz.
- `flutter test test/features/setting/audio_settings_provider_test.dart
  test/app/providers/backend_operation_gate_test.dart`: all 7 tests passed.
- `cargo check -p karbeat-core --tests`: passed under the Rodio-only debug optimization profile;
  the clean rebuild completed in 2 minutes 47 seconds on the development machine.
- `cargo clippy -p karbeat-core --lib` and `cargo clippy -p karbeat-vst3 --lib`: passed against the
  clean Phase 12 snapshot. The current worktree's later uncommitted `context.rs` work has two
  unrelated `as_conversions` errors.
- `VITAL_VST3_PATH=/usr/lib/vst3/Vital.vst3 flutter test
  integration_test/vst3_plugin_workflow_test.dart -d linux`: passed in 19 seconds after build. It
  covered Flutter-driven Vital scan/add, responsive preparation, real XWayland editor open,
  deterministic parameter change, nonzero finite preview audio, close/reopen, deletion while the
  editor was open, and idempotent teardown.
- Full `cargo test -p karbeat-core --no-fail-fast`: 249 passed. Five pre-existing deterministic
  failures remain in mixer automation, preview-note setup, clipboard paste, zero-duration note
  creation, and zero-duration note resize tests.
- `cargo fmt --all -- --check` remains blocked by broad formatting drift in files outside this
  phase. Targeted Dart formatting and `git diff --check` passed.
- Targeted Flutter analysis found only four existing warnings in unrelated app files. Full
  `flutter analyze` additionally enters vendored Cargokit sources whose independent package
  dependencies are not resolved by the root package.

## Blockers

None.

## Exact next action

None. Phase 12 is complete; retain the live Vital workflow as the regression acceptance test.
