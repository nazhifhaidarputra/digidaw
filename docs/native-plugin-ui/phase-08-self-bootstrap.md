# Phase 08 — Self-bootstrap

- Status: complete
- Commit: `feat(vst3): self-bootstrap native UI dispatch`
- Next action: remove the dormant runner callback services, ABI, tests, startup calls, and native
  runner linkage in phase 09.

## Checklist

- [x] Bootstrap the shared GLib dispatcher on the first production VST3 request.
- [x] Construct and retain the VST3 host, platform connection, windows, and periodic work on the
  GLib owner.
- [x] Process VST3 timers, parameter/state work, endpoint retirements, and native events from an
  8 ms format-local owner source.
- [x] Reuse the shared bounded queue and its four-operations-per-callback fairness limit.
- [x] Preserve cancellation-before-start and wait-after-start request semantics.
- [x] Reject synchronous native calls made from the GLib owner.
- [x] Remove the exported `digidaw_native_host_poll` symbol while retaining the legacy runner
  source for the phase validation.
- [x] Convert the Vital host/core integration harnesses to drive the real default GLib context.
- [x] Prove Vital editor, audio, state, and teardown work without the runner callback.

## Decisions

- The global dispatcher owns only opaque `Send` operations. `Vst3PluginHost`, native platform
  objects, editor bindings, and periodic format work remain in owner-thread-local storage.
- First use is scheduled with the shared asynchronous idle source, so initialization cannot execute
  inline on a temporarily unowned `MainContext`.
- The owner pump uses an 8 ms interval. A deliberately cancelled state slot can remain busy until
  the next tick; callers continue to receive explicit bounded backpressure rather than reentrancy.
- `available()` reports successful VST3 owner construction and no longer depends on runner polling.

## Validation

- `cargo test -p karbeat-host -p karbeat-vst3` — passed: 38 unit tests, 5 doc tests, and 2
  live-display tests ignored.
- `VITAL_VST3_PATH=/usr/lib/vst3/Vital.vst3 VITAL_TEST_EDITOR=1 cargo test -p karbeat-vst3
  --test vital -- --ignored --test-threads=1` — passed against the live KDE Wayland/XWayland
  session. The self-bootstrapped owner opened the real Vital editor and completed audio, state,
  duplication, offline processing, and retirement checks.
- `VITAL_VST3_PATH=/usr/lib/vst3/Vital.vst3 cargo test -p karbeat-core --test vst3_core --
  --ignored` — passed through the real core project and audio-engine lifecycle.
- `cargo test -p karbeat_flutter_ffi --no-run` and `cargo build -p karbeat_flutter_ffi --lib` —
  passed.
- `nm -D target/debug/libkarbeat_flutter_ffi.so` confirms the rebuilt shared library exports no
  `digidaw_native_host_poll` symbol while the legacy runner source remains present.

## Blockers

- None.
