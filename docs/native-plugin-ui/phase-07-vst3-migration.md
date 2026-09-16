# Phase 07 — VST3 migration

- Status: complete
- Commit: `feat(vst3): use Rust-owned native editor windows`
- Next action: self-bootstrap the GLib runtime on the first production request and remove the
  exported runner poll dependency in phase 08.

## Checklist

- [x] Return typed editor size and constraints from `PluginEditorManager`.
- [x] Expose a format-declared native surface preference.
- [x] Borrow `NativeParentHandle` for editor attachment instead of accepting a raw handle by value.
- [x] Require X11 on Linux VST3 and translate only XCB XIDs to `X11EmbedWindowID`.
- [x] Replace callback-owned native windows in the production VST3 owner with
  `NativeEditorBinding<SystemNativeUi::Window>`.
- [x] Route plug-frame resize requests into programmatic binding resizes.
- [x] Route external native resize/close/destroy events through binding policy.
- [x] Create hidden → attach → show → request focus.
- [x] Detach → release editor → finish binding close/drop, including instance destruction.
- [x] Update the live Vital test to create its parent through `SystemNativeUi`.

## Decisions

- The legacy runner callback ABI remains compiled only as a temporary bootstrap input. No callback
  from that table creates, resizes, focuses, titles, polls, or destroys production editor windows.
- A close failure retains the binding and its parent instead of risking a window drop while a plug-in
  may still reference it.
- `karbeat-host` now re-exports the native UI API at its crate root as required by the public
  contract.
- Platform initialization records the calling thread as owner. Phase 08 will ensure production
  initialization reaches it only through the asynchronous GLib dispatcher.

## Validation

- `cargo test -p karbeat-host -p karbeat-vst3` — passed: 38 unit tests, 5 doc tests, 2 live-display
  tests ignored.
- `VITAL_VST3_PATH=/usr/lib/vst3/Vital.vst3 VITAL_TEST_EDITOR=1 cargo test -p karbeat-vst3
  --test vital -- --ignored --test-threads=1` — passed. Vital rendered nonzero finite audio and its
  real XWayland editor completed two open/pump/close cycles through `SystemNativeUi`.
- Focused Clippy run reports no errors in changed production modules; existing workspace warnings
  remain.

## Blockers

- None.
