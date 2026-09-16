# Phase 09 — Runner cleanup

- Status: complete
- Commit: `refactor(runner): remove native plug-in window service`
- Next action: convert production VST3 preparation into a cooperative request that yields between
  bounded MIDI-controller mapping batches in phase 10.

## Checklist

- [x] Remove the Linux runner startup call and native plug-in window service.
- [x] Remove the Linux runner callback test.
- [x] Remove the shared callback ABI header.
- [x] Remove the Linux CMake source entry and direct X11/dlopen linkage.
- [x] Remove the corresponding dormant Windows runner service and startup call.
- [x] Remove the corresponding dormant macOS runner service, project entries, bridge import, and
  startup call.
- [x] Keep Flutter/GTK entirely outside native editor ownership.

## Decisions

- All platform runner callback services were removed together because they consumed the same ABI.
  Leaving the Windows/macOS copies after deleting the shared header would make those runner sources
  uncompilable even though their Rust native UI implementations are intentionally unsupported.
- The normal Flutter window/view startup sequence remains otherwise unchanged.
- X11 remains a Rust host dependency for the Linux native UI backend, but is no longer a direct
  Flutter runner dependency.

## Validation

- Repository search finds no remaining `plugin_windows`, `digidaw_native_host_start`,
  `digidaw_native_host_poll`, callback ABI header, `X11::X11`, or runner `CMAKE_DL_LIBS`
  references outside build artifacts.
- `flutter build linux` — passed and produced `build/linux/x64/release/bundle/karbeat` with the
  cleaned runner.
- Phase 08's live Vital test already passed after removing the exported callback symbol while the
  legacy Linux service was still compiled, establishing that the deleted service was dormant.

## Blockers

- Windows and macOS runner builds were not available on the Linux validation host; their project
  references and startup calls were checked statically.
