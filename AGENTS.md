# AGENTS.md

Guidance for AI agents adding or changing code in this repository. Follow `CONTRIBUTING.md` first; this file turns those rules and the current architecture into concrete working conventions.

## Scope

This repository is DigiDAW, still internally named `karbeat` in packages, crates, and imports. It is a Flutter app with a Rust audio engine connected through Flutter Rust Bridge.

These instructions apply to the whole repository unless a more specific `AGENTS.md` is added in a subdirectory.

## First Principles

- Keep changes narrow. Solve the requested problem without unrelated refactors, formatting churn, dependency bumps, generated-file edits, or architecture rewrites.
- Preserve user work. The worktree may be dirty; never revert, overwrite, or normalize changes you did not make.
- Read the local patterns before editing. Match nearby naming, provider shape, widget composition, and Rust module boundaries.
- Treat audio performance as a correctness requirement. A change that compiles but risks glitches, blocking, allocation, lock contention, or UI-driven real-time work is not acceptable.
- Prefer explicit typed results over exceptions. Throwing is a boundary concern, not a normal control-flow mechanism.
- Do not leave debug artifacts: no `print()`, no `debugPrint()`, no temporary logs, no commented-out experiments.

## Project Map

- `lib/main.dart`: platform bootstrap and root `ProviderScope`.
- `lib/app/`: app shell and global Riverpod state.
- `lib/app/providers/`: Riverpod `Notifier` and `AsyncNotifier` state stores. Immutable state data lives here.
- `lib/core/`: shared services, input handling, widgets, utilities, logging, formatting, constants.
- `lib/features/<feature>/`: feature-owned UI and services. Current feature split includes workspace, track, piano roll, mixer, source, plugins, and misc screens.
- `lib/shared/`: shared models, enums, IDs, intents, and small data structures.
- `lib/src/rust/`: Flutter Rust Bridge generated Dart API. Do not edit by hand.
- `lib/generated/plugins/`: generated Dart plugin spec files. Do not edit by hand.
- `lib/tool/generate_plugin_manifests.dart`: generator for Dart plugin spec files from JSON manifests.
- `assets/manifests/audio-plugins/`: plugin manifest JSON and manifest documentation.
- `rust/`: Rust workspace.
- `rust/karbeat-core/`: project model, commands, high-level APIs, file management, audio engine ownership.
- `rust/karbeat-dsp/`: DSP primitives. Keep this generic and reusable.
- `rust/karbeat-flutter-ffi/`: Flutter-facing DTOs and bridge functions.
- `rust/karbeat-plugins/`: first-party plugin implementations and manifest export.
- `rust/karbeat-plugin-api/`, `rust/karbeat-plugin-types/`, `rust/karbeat-macros/`, `rust/karbeat-host/`, `rust/karbeat-utils/`: plugin ecosystem and shared support crates.

## Generated Code

Never hand-edit generated files. Change their sources, then regenerate.

- Freezed outputs: `**/*.freezed.dart`
- Flutter Rust Bridge Dart outputs: `lib/src/rust/**`
- Flutter Rust Bridge Rust output: `rust/karbeat-flutter-ffi/src/frb_generated.rs`
- Generated plugin specs: `lib/generated/plugins/**`

Generation commands:

```sh
dart run build_runner build
flutter_rust_bridge_codegen generate
dart run lib/tool/generate_plugin_manifests.dart
```

Use the command that matches the source you changed. If generated outputs are already dirty from the user, do not discard them.

## Dart And Flutter

- Use `package:karbeat/...` imports for app code. Keep relative imports only where the existing local file already uses them for nearby generated barrels.
- Use Flutter Material widgets and the existing dark/minimal DAW style. Prefer dense, practical controls over marketing-like layout.
- Keep UI passive. Widgets render Riverpod state and dispatch explicit user actions; they should not own business state, project data, or audio synchronization loops.
- Use `ConsumerWidget`, `ConsumerStatefulWidget`, `Notifier`, and `AsyncNotifier` according to nearby patterns.
- `StatefulWidget` is acceptable for local lifecycle concerns such as focus nodes, controllers, gestures, animations, and platform initialization. Do not put global or feature business logic in `StatefulWidget`.
- Prefer `ref.watch(...select(...))` for focused rebuilds in large UI surfaces.
- Keep high-frequency visual data, such as meters, FFT, and playheads, sourced from engine telemetry or existing provider streams. Do not add UI timers as the source of truth for audio state.
- Use `AppLogger` for diagnostics. Do not use `print()` or `debugPrint()` in production code.
- Route user-visible errors through `notificationProvider`, `ref.notifyError`, `ref.notifyErrorResult`, or `ref.guardApi` where applicable.

## Dart State And Data

- All immutable state data classes must use Freezed.
- Use `copyWith` for state transitions.
- Use `fast_immutable_collections` for state collections: `IList`, `IMap`, and `ISet`.
- Use `IListConst`, `IMapConst`, and `ISetConst` for defaults in Freezed models.
- Do not mutate standard `List`, `Map`, or `Set` inside app state. Convert external collections at the boundary, then publish immutable state.
- Keep `projectProvider` as the central serialized project truth. Feature notifiers should coordinate with it rather than duplicating full project maps.
- For operations that call Rust and then update Dart state, keep the backend mutation and local provider merge visibly paired so the UI cannot drift from the engine.
- Use the local `Result<T>` from `lib/core/utils/result_type.dart` for explicit success/failure APIs.
- For async Riverpod operations, prefer `AsyncValue.guard()` or the existing `ref.guardApi()` helper.
- Avoid broad `try-catch`. If a third-party or FFI boundary can throw, catch there, convert to `Result` or `AsyncValue`, notify once, and preserve the stack trace when available.

## Rust

- The workspace uses Rust edition 2024 and shared dependencies from `rust/Cargo.toml`.
- Respect the crate boundaries. Put user/project API behavior in `karbeat-core/src/api`, project domain state in `karbeat-core/src/core/project`, audio callback logic in `karbeat-core/src/audio`, generic DSP in `karbeat-dsp`, bridge DTOs/functions in `karbeat-flutter-ffi`, and plugin implementations in `karbeat-plugins`.
- Use `thiserror` for specific recoverable domain errors.
- Use `anyhow::Result` at top-level FFI and context boundaries where human-readable context must cross into Dart.
- Do not use `unwrap()` or `expect()` in production Rust. The workspace denies these through Clippy. Tests and build scripts may use them when they are clearer and scoped.
- Use `log::{debug, info, warn, error}` style logging in Rust. Do not print directly from library code.
- Keep serialization changes compatible with project load/save behavior. Add round-trip tests when changing persisted project structs or file manager code.

## Audio Thread Rules

The real-time audio path has stricter rules than ordinary Rust.

- Do not allocate in `process()` or callback-time DSP paths: no new `Vec`, `Box`, `String`, hash map growth, JSON work, file I/O, or unbounded collection cloning.
- Do not block in the audio thread: no locks, sleeps, channels that can wait, filesystem access, network access, or expensive logging.
- Pre-allocate and resize buffers from setup, graph replacement, or command handling paths outside the real-time callback.
- Communicate graph and state changes through the existing command/feedback channels.
- Keep telemetry lock-free. Use the existing triple-buffer pattern for visual data such as meters and plugin snapshots.
- Separate high-frequency telemetry from critical events such as save/load, graph replacement, and project mutations.
- For plugin DSP, implement `prepare`, `reset`, `process`, latency reporting, and IO layout changes in the style of existing plugins.
- If adding latency or routing behavior, update plugin delay compensation and tests where behavior can affect rendered timing.

## Flutter Rust Bridge

- Expose Dart-facing DTOs in `rust/karbeat-flutter-ffi/src/api/**`.
- Mark bridge structs that should become immutable Dart data with `#[frb(dart_metadata=("freezed"))]`.
- Keep conversions explicit with `From` implementations near the bridge type.
- Convert domain IDs to plain UI IDs at the FFI boundary with existing `to_u32()` patterns.
- Keep generated Dart files out of manual edits. Regenerate after changing bridge API signatures.
- Avoid leaking Rust internals into Flutter. Flutter should receive UI-shaped DTOs and call focused API functions.

## Plugins

- First-party plugin DSP belongs in `rust/karbeat-plugins/src/effect` or `rust/karbeat-plugins/src/generator`.
- Use `#[karbeat_plugin]`, `#[karbeat_macros::auto_param]`, `AudioPlugin`, `AudioPluginBuilder`, and `Manifestable` in the existing style.
- Build parameter specs with stable IDs and paths. Changing IDs or manifest `id_string` can break automation and saved projects.
- Add the plugin to the Rust plugin registry and the Flutter `PluginRegistryFlutter` UI mapping when it needs a custom screen.
- Keep JSON manifests in `assets/manifests/audio-plugins/**` aligned with Rust plugin parameters, then regenerate `lib/generated/plugins/**`.
- Plugin UIs should extend/use existing plugin widgets and parameter controls instead of inventing parallel controls.

## Testing And Verification

Run the smallest meaningful validation for the change, then broaden when touching shared behavior.

Useful commands:

```sh
flutter analyze
flutter test
dart run build_runner build
cd rust && cargo fmt --check
cd rust && cargo clippy --all-targets
cd rust && cargo test
cd rust && flutter_rust_bridge_codegen generate
```

Choose based on touched files:

- Dart provider/model changes: `dart run build_runner build`, `flutter analyze`, and targeted `flutter test`.
- Flutter widget changes: targeted widget tests if present, then `flutter analyze`.
- Rust API/domain changes: `cd rust && cargo test`; include crate-specific tests when faster.
- Rust DSP/audio engine changes: `cd rust && cargo test` plus focused engine/plugin tests.
- FFI shape changes: regenerate Flutter Rust Bridge output and run both Dart analysis and Rust tests relevant to the API.
- Plugin manifest changes: regenerate plugin manifests and verify the Flutter registry still maps all custom plugin screens.

If a validation command cannot run because local tools, platform libraries, or network are unavailable, report that clearly with the command and failure reason.

## Adding New Code

Before adding a new file or abstraction:

- Locate the nearest existing feature/module that owns the behavior.
- Prefer extending an existing provider, service, widget, API module, or Rust crate before creating a new top-level concept.
- Keep names domain-specific: track, clip, pattern, mixer, bus, generator, effect, automation, source, transport, project.
- Keep APIs small and explicit. Avoid generic helper layers unless they remove real duplication already present in the codebase.
- Add tests near the changed layer when behavior is non-trivial, stateful, persisted, or audio-affecting.
- Update docs only when the behavior or workflow changes for future contributors.

## Common Pitfalls

- Do not edit `lib/src/rust/**` to fix an FFI issue; edit `rust/karbeat-flutter-ffi/src/api/**` and regenerate.
- Do not edit `*.freezed.dart`; edit the source Freezed class and regenerate.
- Do not store mutable `List`, `Map`, or `Set` in app state for convenience.
- Do not make UI code poll backend state with timers when an event, provider, stream, or telemetry buffer should own the update.
- Do not mix project save/load events into high-frequency audio telemetry channels.
- Do not block or allocate in Rust `process()` functions.
- Do not silently swallow errors. Convert them to typed results, notify users when appropriate, and log diagnostic context through the approved logger.
