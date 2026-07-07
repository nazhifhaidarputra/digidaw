# Digidaw Coding Conventions & Style Guide

Welcome to the Digidaw codebase! Building a low-latency Digital Audio Workstation requires strict discipline across both the Flutter frontend and the Rust audio backend. To ensure maximum performance, maintainability, and predictability, all contributors must adhere to the following rules.

---

## I. Error Handling

* **Avoid `try-catch` blocks:** Do not use `try-catch` blocks unless interacting with a third-party library that strictly requires it. Exception throwing interrupts control flow and is notoriously difficult to track across a hybrid FFI architecture.
* **Embrace `Result` Types:** Always prefer returning a strongly typed result.
* For standard synchronous/asynchronous operations, use the custom `Result` wrapper defined in `core/utils/result_type.dart`.
* For state managed by Riverpod, wrap asynchronous calls in `AsyncValue.guard()`.


* **Rust Layer Error Boundaries:**
* Use `thiserror` to define specific, recoverable `enum` error states in the core DSP and internal project layers.
* Use `anyhow::Result` at the FFI boundary and top-level context layers to cleanly pass errors with human-readable context back to Dart.



---

## II. State Management & Data Structures

* **Strict Immutability:** Never mutate standard Dart collections (`List`, `Map`, `Set`) inside application state.
* **Use `fast_immutable_collection`:** All state data classes must use `IList`, `IMap`, or `ISet` to guarantee memory-safe, zero-cost immutability and fast equality comparisons across the UI.
* **Riverpod as the Source of Truth:** Rely on Riverpod `Notifier` and `AsyncNotifier` classes to govern state. Avoid using `StatefulWidget` for global or complex business logic.
* **Passive UI:** The UI should be a passive reflection of the state. Avoid driving high-frequency logic (like audio analysis) with UI timers. Rely on the engine's telemetry clock and reactive state.

---

## III. Architecture & Object-Oriented Design

* **Modular Project Structure:** Karbeat follows a strict feature-driven modular structure. Keep domain logic, UI screens, and FFI bridges neatly separated by feature (e.g., `features/plugins`, `core/project`, `app/providers`). Do not create monolithic "God" folders.
* **Composition over Inheritance:** Avoid deep class hierarchies. Prefer composing small, reusable mixins, traits (in Rust), and helper classes over inheriting from massive base classes.
* **Separation of Delivery Guarantees:** Never mix high-frequency telemetry (e.g., FFT spectrums, 60 FPS playheads) with critical application events (e.g., Saving, Loading) in the same data pipe.

---

## IV. Debugging & Logging

* **No `print()` statements:** Never leave `print()` or `debugPrint()` in production code.
* **Use `AppLogger`:** All diagnostic information must be routed through `AppLogger`. This ensures that logs are appropriately filtered by severity (`info`, `warn`, `error`) and can be safely disabled or written to a crash diagnostic file in release builds.

---

## V. High-Performance FFI & Audio Threading

* **Respect the Audio Thread:** The DSP `process()` loop must **never** allocate heap memory (`Vec::new()`, `Box::new()`), lock a `Mutex`, or block for I/O. All buffers must be pre-allocated and resized via commands from the main thread.
* **Lock-Free Telemetry:** For pushing visual data (like EQ spectrums or mixer meters) from Rust to Dart, use lock-free atomic pointers (e.g., `ArcSwap`). Do not use message queues (`rtrb`) for lossy visual data, as this can choke the audio thread.
* **Zero-Copy Arrays:** When parsing large datasets from the audio engine (like an FFT spectrum), use Dart's `Float32List.sublistView` to parse the flat array efficiently without triggering garbage collection.