# Phase 3: Linux VST3 Interface Gating

Status: Implemented; Linux regression pending

Completed:

- Limited Steinberg `Linux::IRunLoop` interfaces and delegate implementations to Linux.
- Kept the VST3 host context and plug frame target-specific through compile-time interface tuples.
- Moved the `glib` dependency to the Linux target section.
- Removed GLib types from `native.rs` and used `NativeUiControlFlow` instead.
- Made the VST3 run-loop implementation a Linux implementation with a non-Linux owner-thread no-op adapter.

Verification:

- `cargo check -p karbeat-vst3` passed on Windows without a GLib dependency.
- `cargo test -p karbeat-vst3 --lib` passed: 10 tests.

Remaining acceptance work:

- Compile and run the Linux VST3 tests on Linux.
