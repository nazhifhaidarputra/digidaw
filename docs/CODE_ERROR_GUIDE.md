# Crash Error Code Guide

Every crash report DigiDAW writes carries a stable numeric `code`. This guide explains what each code means and where to start looking. The codes are defined in `rust/karbeat-core/src/core/mitigation/crash.rs`; keep this table in sync when adding one.

Codes are grouped by the side that detected the crash:

| Range | Source |
| --- | --- |
| `1xxx` | Rust engine (`RustCrashSource`) |
| `2xxx` | Flutter UI (`FlutterCrashSource`) |

Never renumber or reuse a code. Retired codes stay listed as retired.

## Where reports live

Reports are JSON files under the platform application-support directory:

```text
<app support>/crashes/crash-<nanoseconds>-<code>.json
```

Only the newest 20 are kept. Each report contains `when` (UTC timestamp), `code`, `source` (the details below), `device` (OS, kernel, CPU, core count, RAM), and `app_version`. Reports never leave the machine. After a crash, the next launch lists them and lets the user export or delete them.

## Rust engine (`1xxx`)

| Code | Name | Meaning | Where to look |
| --- | --- | --- | --- |
| `1001` | `Panic` | A Rust thread panicked. `thread`, `message`, `location` (`file:line:column`), and `backtrace` identify it. The report is written by the panic hook installed in `init_app`. | Start at `location`. The `thread` name tells the audio callback apart from control, auto save (`karbeat-auto-save`), and FFI worker threads. A panic on the audio thread usually means an unchecked index or an assumption about buffer sizes. |
| `1002` | `UncleanShutdown` | The previous session never reached a clean shutdown: its session marker was still present at the next launch. No hook saw the crash. | Usually a native crash inside an external plugin (VST3, CLAP, LV2), a crash in native audio drivers, the process being killed, or a power loss. Check whether the same plugins were loaded, and look at the other reports from the same time. |

## Flutter UI (`2xxx`)

| Code | Name | Meaning | Where to look |
| --- | --- | --- | --- |
| `2001` | `FrameworkError` | `FlutterError.onError` caught an error, such as an exception thrown during build, layout, or paint. `library` names the Flutter library that reported it. Recorded in profile and release builds only. | The `stack` usually points at the widget that threw. |
| `2002` | `UncaughtAsync` | `PlatformDispatcher.onError` caught an asynchronous error that no `Future` handled. | Look for a missing `Result` conversion at an FFI or plugin boundary; see *Error Handling* in `CONTRIBUTING.md`. |

## Adding a code

1. Add a variant to `RustCrashSource` or `FlutterCrashSource`, and give it the next free code in its range in `code()`.
2. Add a row to the matching table above.
3. Extend the `codes_are_stable` test in `crash.rs`.
