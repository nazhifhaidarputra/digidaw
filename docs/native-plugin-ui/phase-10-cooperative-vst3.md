# Phase 10 — Cooperative VST3 preparation

- Status: complete
- Commit: `perf(vst3): yield during expensive preparation work`
- Next action: extend and run the Flutter/Vital lifecycle acceptance flow in phase 11.

## Checklist

- [x] Split VST3 preparation into start and resumable advance operations.
- [x] Limit each production owner tick to 64 MIDI-controller mapping queries.
- [x] Cover all 16 channels × 130 controller slots in 33 bounded batches.
- [x] Yield to the GLib loop between mapping batches.
- [x] Return cooperative completion through a request that can only be waited off the UI owner.
- [x] Preserve cancellation-before-start through the shared dispatcher and wait for the real result
  after cooperative preparation has started.
- [x] Bound the queued preparation jobs and process them round-robin, one batch per owner tick.
- [x] Route add, retry, project restore, duplicate, and offline-copy production paths through the
  cooperative request.
- [x] Keep direct `Vst3PluginHost::prepare` and `NativeHost::create_prepared` synchronous for
  focused low-level tests.

## Decisions

- The resumable job retains the partially built DSP and `IMidiMapping` interface exclusively on
  the VST3 UI owner. No COM interface crosses threads.
- A 64-query batch bounds host-owned work while completing Vital's 2,080 possible probes in 33
  turns. Only a single third-party ABI call remains non-preemptible.
- Once the worker has received `NativePrepareRequest`, native mutation has started. Its timeout
  therefore waits for the actual result instead of returning a false timeout and orphaning an
  instance.
- Failed jobs run the same lifecycle cleanup as synchronous preparation; abandoned completed
  endpoints return through the existing retirement queue.

## Validation

- `cargo test -p karbeat-vst3` — passed: 9 unit tests including exact bounded mapping coverage,
  plus doc tests.
- `cargo clippy -p karbeat-vst3 -p karbeat-core --all-targets` — passed with existing workspace
  warnings and no errors.
- `VITAL_VST3_PATH=/usr/lib/vst3/Vital.vst3 VITAL_TEST_EDITOR=1 cargo test -p karbeat-vst3
  --test vital -- --ignored --test-threads=1` — passed. The native gateway's first Vital instance
  used cooperative preparation; the low-level host path remained synchronous.
- `VITAL_VST3_PATH=/usr/lib/vst3/Vital.vst3 cargo test -p karbeat-core --test vst3_core --
  --ignored` — passed through cooperative add, project restore, and retry paths with finite nonzero
  audio and teardown.
- `cargo test -p karbeat-core --lib` — 245 passed and 5 unrelated existing tests failed in mixer
  automation, preview-note, clipboard remapping, and zero-duration note expectations. The same
  failures persist with `--test-threads=1`; none execute the changed external plug-in paths.

## Blockers

- None for cooperative VST3 preparation. The five unrelated core unit failures remain repository
  validation debt and are recorded above for final workspace validation.
