# Contributing to DigiDAW

Welcome to the DigiDAW codebase! Building a low-latency Digital Audio Workstation takes discipline across both the Flutter frontend and the Rust audio engine. This guide describes how the project is organized, the conventions we follow, and what we expect from every change, so that the app stays fast, predictable, and maintainable.

DigiDAW is a Flutter app with a Rust audio engine, connected through [Flutter Rust Bridge](https://cjycode.com/flutter_rust_bridge/). Internally the project is still named `karbeat`, so you will see that name in packages, crates, and imports.

---

## Ground Rules

* **Keep changes focused.** Solve the problem at hand. Avoid unrelated refactors, formatting churn, dependency bumps, edits to generated files, or architecture rewrites in the same change.
* **Read before you write.** Look at the code around the area you are changing and match its naming, provider shape, widget composition, and Rust module boundaries.
* **Audio performance is a correctness requirement.** A change that compiles but risks glitches, blocking, allocation, lock contention, or UI-driven real-time work is not acceptable.
* **Prefer explicit, typed results over exceptions.** Throwing belongs at boundaries, not in normal control flow.
* **Leave no debug artifacts.** No `print()`, no `debugPrint()`, no temporary logs, and no commented-out experiments.

---

## Project Structure

DigiDAW follows a feature-driven modular structure. Keep domain logic, UI screens, and FFI bridges separated by feature, and do not create monolithic "God" folders.

### Flutter (`lib/`)

| Path | Purpose |
| --- | --- |
| `lib/main.dart` | Platform bootstrap and the root `ProviderScope`. |
| `lib/app/` | App shell and global Riverpod state. |
| `lib/app/providers/` | Riverpod `Notifier` and `AsyncNotifier` state stores. Immutable state data lives here. |
| `lib/core/` | Shared services, input handling, widgets, utilities, logging, formatting, and constants. |
| `lib/features/<feature>/` | Feature-owned UI and services: workspace, track, piano roll, mixer, source, plugins, and miscellaneous screens. |
| `lib/shared/` | Shared models, enums, IDs, intents, and small data structures. |
| `lib/src/rust/` | Generated Flutter Rust Bridge Dart API. **Do not edit by hand.** |
| `lib/generated/plugins/` | Generated Dart plugin spec files. **Do not edit by hand.** |
| `lib/tool/generate_plugin_manifests.dart` | Generates the Dart plugin spec files from JSON manifests. |
| `assets/manifests/audio-plugins/` | Plugin manifest JSON and its documentation. |

### Rust (`rust/`)

| Crate | Purpose |
| --- | --- |
| `karbeat-core` | Project model, commands, high-level APIs, file management, and audio engine ownership. |
| `karbeat-dsp` | DSP primitives. Keep this crate generic and reusable. |
| `karbeat-flutter-ffi` | Flutter-facing DTOs and bridge functions. |
| `karbeat-plugins` | First-party plugin implementations and manifest export. |
| `karbeat-host-api` | Low-level contracts for hosting external plugins. |
| `karbeat-host` | Format-independent async host client, service, and static executor router. |
| `karbeat-vst3`, `karbeat-clap`, `karbeat-lv2` | Plugin format executors. Unfinished formats keep concrete "unsupported" stubs. |
| `karbeat-plugin-api`, `karbeat-plugin-types`, `karbeat-macros`, `karbeat-utils` | Plugin ecosystem and shared support crates. |

Within the Rust workspace, respect crate boundaries:

* User and project API behavior goes in `karbeat-core/src/api`.
* Project domain state goes in `karbeat-core/src/core/project`.
* Audio callback logic goes in `karbeat-core/src/audio`.
* Generic DSP goes in `karbeat-dsp`.
* Bridge DTOs and functions go in `karbeat-flutter-ffi`.
* Plugin implementations go in `karbeat-plugins`.

---

## Generated Code

Never edit generated files by hand. Change their sources, then regenerate.

| Generated output | Regenerate with |
| --- | --- |
| Freezed classes (`**/*.freezed.dart`) | `dart run build_runner build` |
| Flutter Rust Bridge Dart API (`lib/src/rust/**`) and Rust glue (`rust/karbeat-flutter-ffi/src/frb_generated.rs`) | `flutter_rust_bridge_codegen generate` |
| Plugin specs (`lib/generated/plugins/**`) | `dart run lib/tool/generate_plugin_manifests.dart` |

Run only the command that matches the source you changed.

---

## Error Handling

* **Avoid `try-catch` blocks.** Only catch where a third-party library or FFI boundary can throw. Exceptions interrupt control flow and are hard to track across a hybrid FFI architecture.
* **Return typed results.**
  * For ordinary synchronous and asynchronous operations, use the `Result<T>` type in `lib/core/utils/result_type.dart`.
  * For asynchronous Riverpod operations, use `AsyncValue.guard()` or the existing `ref.guardApi()` helper.
* **Convert at the boundary.** When a boundary can throw, catch it there, convert it to a `Result` or `AsyncValue`, notify the user once, and keep the stack trace when available.
* **Route user-visible errors** through `notificationProvider`, `ref.notifyError`, `ref.notifyErrorResult`, or `ref.guardApi`.
* **Rust error boundaries:**
  * Use `thiserror` for specific, recoverable domain errors in the core, DSP, and project layers.
  * Use `anyhow::Result` at the FFI boundary and other top-level layers where human-readable context has to travel back to Dart.
* **Never swallow errors silently.** Convert them to typed results, notify the user when appropriate, and log diagnostic context through the approved logger.

---

## Flutter & Dart

### Imports and widgets

* Use `package:karbeat/...` imports for app code. Keep relative imports only where a file already uses them for nearby generated barrels.
* Use Flutter Material widgets in the existing dark, minimal DAW style. Prefer dense, practical controls over marketing-style layouts.
* **Composition over inheritance.** Avoid deep class hierarchies. Prefer small, reusable widgets, mixins, and helpers over large base classes.

### A passive UI

* The UI is a passive reflection of state. Widgets render Riverpod state and dispatch explicit user actions. They should not own business state, project data, or audio synchronization loops.
* Use `ConsumerWidget`, `ConsumerStatefulWidget`, `Notifier`, and `AsyncNotifier` following nearby patterns.
* `StatefulWidget` is fine for local lifecycle concerns such as focus nodes, controllers, gestures, animations, and platform initialization. Do not put global or feature business logic in it.
* In large UI surfaces, prefer `ref.watch(provider.select(...))` so widgets rebuild only for what they use.
* Drive high-frequency visuals (meters, FFT displays, playheads) from engine telemetry or existing provider streams. Never use UI timers as the source of truth for audio state.

### State and data

* **Freezed is a must.** Every immutable state data class uses Freezed. Don't hand-write equality, `copyWith`, or `toString`; let Freezed do the heavy lifting.
* Use `copyWith` for state transitions.
* **Strict immutability.** Never mutate standard `List`, `Map`, or `Set` inside application state. Use `fast_immutable_collections` (`IList`, `IMap`, `ISet`), and `IListConst`, `IMapConst`, `ISetConst` for defaults in Freezed models. Convert external collections at the boundary, then publish immutable state.
* **`projectProvider` is the central, serialized project truth.** Feature notifiers coordinate with it rather than keeping their own copies of the full project.
* When an operation calls Rust and then updates Dart state, keep the backend mutation and the local provider update visibly paired, so the UI cannot drift from the engine.
* Rust handles that pin native memory, such as waveform handles, must be released deterministically. Tie them to an `autoDispose` provider that disposes them in `ref.onDispose`, rather than relying on the garbage collector.

---

## Rust

* The workspace uses Rust edition 2024, with shared dependencies declared in `rust/Cargo.toml`.
* **No `unwrap()` or `expect()` in production code.** The workspace denies them through Clippy. Tests and build scripts may use them where that is clearer and scoped.
* Log with `log::{debug, info, warn, error}`. Library code never prints directly.
* Keep serialization changes compatible with project load and save. Add round-trip tests when you change persisted project structs or file manager code.
* Prefer composing small traits and helper types over deep abstraction layers.

---

## Audio Thread Rules

The real-time audio path has stricter rules than ordinary Rust.

* **Never allocate in `process()` or callback-time DSP paths.** That means no new `Vec`, `Box`, or `String`, no hash map growth, no JSON work, no file I/O, and no unbounded collection cloning.
* **Never block the audio thread.** That means no locks, sleeps, channels that can wait, filesystem access, network access, or expensive logging.
* Pre-allocate buffers and resize them from setup, graph replacement, or command handling paths, outside the real-time callback.
* Communicate graph and state changes through the existing command and feedback channels.
* **Keep telemetry lock-free.** Use the existing triple-buffer pattern, one per plugin instance, for visual data such as meters and plugin snapshots.
* Tokio channels, one-shots, and watches belong only on plugin control and native-owner paths. Audio-command acknowledgements and endpoint retirement use bounded `rtrb` transfers.
* **Separate delivery guarantees.** Never mix high-frequency telemetry (FFT spectrums, 60 FPS playheads) with critical events (save, load, graph replacement, project mutations) in the same pipe.
* For plugin DSP, implement `prepare`, `reset`, `process`, latency reporting, and IO layout changes in the style of the existing plugins.
* If you add latency or routing behavior, update plugin delay compensation, and add tests wherever rendered timing can change.
* **Zero-copy arrays.** When reading large datasets from the engine on the Dart side (an FFT spectrum, for example), use `Float32List.sublistView` over the flat array instead of copying it.

---

## Flutter Rust Bridge

* Expose Dart-facing DTOs in `rust/karbeat-flutter-ffi/src/api/**`.
* Mark bridge structs that should become immutable Dart data with `#[frb(dart_metadata=("freezed"))]`.
* Keep conversions explicit, with `From` implementations next to the bridge type.
* Convert domain IDs to plain UI IDs at the FFI boundary, using the existing `to_u32()` patterns.
* Regenerate the bridge after changing API signatures; never patch the generated Dart files.
* Don't leak Rust internals into Flutter. Flutter should receive UI-shaped DTOs and call focused API functions.

---

## Plugins

* First-party plugin DSP belongs in `rust/karbeat-plugins/src/effect` or `rust/karbeat-plugins/src/generator`.
* Use `#[karbeat_plugin]`, `#[karbeat_macros::auto_param]`, `AudioPlugin`, `AudioPluginBuilder`, and `Manifestable` in the existing style.
* Build parameter specs with stable IDs and paths. Changing IDs or a manifest's `id_string` can break automation and saved projects.
* Register the plugin in the Rust plugin registry, and in the Flutter `PluginRegistryFlutter` UI mapping when it needs a custom screen.
* Keep the JSON manifests in `assets/manifests/audio-plugins/**` aligned with the Rust plugin parameters, then regenerate `lib/generated/plugins/**`.
* Plugin UIs should build on the existing plugin widgets and parameter controls instead of inventing parallel ones.

---

## Logging & Debugging

* **No `print()` statements.** Never leave `print()` or `debugPrint()` in production code.
* **Use `AppLogger`** for all diagnostics on the Dart side. It filters logs by severity (`info`, `warn`, `error`), and logging can be safely disabled or written to a crash diagnostic file in release builds.
* On the Rust side, use the `log` macros. Rust records are forwarded to the in-app log viewer automatically.

---

## Testing & Verification

Run the smallest meaningful validation for your change, then broaden it when you touch shared behavior.

```sh
flutter analyze
flutter test
dart run build_runner build
cd rust && cargo fmt --check
cd rust && cargo clippy --all-targets
cd rust && cargo test
cd rust && flutter_rust_bridge_codegen generate
```

What to run depends on what you touched:

| Change | Validate with |
| --- | --- |
| Dart provider or model | `dart run build_runner build`, `flutter analyze`, and targeted `flutter test` |
| Flutter widget | Targeted widget tests if present, then `flutter analyze` |
| Rust API or domain | `cd rust && cargo test`, or crate-specific tests when faster |
| Rust DSP or audio engine | `cd rust && cargo test` plus focused engine and plugin tests |
| FFI shape | Regenerate the bridge, then run Dart analysis and the relevant Rust tests |
| Plugin manifest | Regenerate plugin manifests and check that the Flutter registry still maps every custom plugin screen |

If a command can't run because a tool, platform library, or network access is unavailable, say so in your pull request, including the command and the reason.

---

## Adding New Code

Before adding a new file or abstraction:

* Find the existing feature or module that owns the behavior.
* Prefer extending an existing provider, service, widget, API module, or Rust crate before creating a new top-level concept.
* Use domain-specific names: track, clip, pattern, mixer, bus, generator, effect, automation, source, transport, project.
* Keep APIs small and explicit. Avoid generic helper layers unless they remove real duplication that already exists.
* Add tests near the changed layer when the behavior is non-trivial, stateful, persisted, or audio-affecting.
* Update documentation only when behavior or workflow changes for future contributors.

---

## Do's and Don'ts at a Glance

| Do | Don't |
| --- | --- |
| Fix FFI issues in `rust/karbeat-flutter-ffi/src/api/**` and regenerate | Edit `lib/src/rust/**` by hand |
| Change the source Freezed class and regenerate | Edit `*.freezed.dart` by hand |
| Store `IList`, `IMap`, `ISet` in app state | Store mutable `List`, `Map`, or `Set` in app state for convenience |
| Drive updates from events, providers, streams, or telemetry buffers | Poll backend state from the UI with timers |
| Keep save/load events on their own channels | Mix save/load events into high-frequency telemetry channels |
| Pre-allocate outside the real-time callback | Block or allocate in Rust `process()` functions |
| Return typed results and notify the user | Silently swallow errors |

---

## Regarding LLM Contributions

I accept LLM contributions, since I also use LLMs to help me write some of the code. Keep in mind, though, that you should know what the LLM writes and not fully "vibe-code" the entire thing without reading, checking, testing, and debugging it. I prefer a well-crafted solution over low-quality generated code. Any code produced entirely by an AI agent without human guidance, supervision, and review will be rejected.
