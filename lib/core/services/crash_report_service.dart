import 'package:flutter/foundation.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/src/rust/api/mitigation.dart' as mitigation_api;

/// Writes Flutter errors to the local crash report store.
///
/// Reports are recorded only after the engine has configured crash reporting;
/// earlier calls return an error that callers log and otherwise ignore.
abstract final class CrashReportService {
  /// Records an error caught by `FlutterError.onError`.
  ///
  /// Debug builds skip these: layout and build assertions fire constantly
  /// during development and are already visible in the console.
  static Result<void> recordFrameworkError(FlutterErrorDetails details) {
    if (kDebugMode) return Result.ok(null);
    return attempt(
      () => mitigation_api.recordFlutterCrash(
        kind: mitigation_api.UiFlutterCrashKind.frameworkError,
        sourceLibrary: details.library,
        message: details.exceptionAsString(),
        stack: details.stack?.toString(),
      ),
    );
  }

  /// Records an uncaught asynchronous error caught by
  /// `PlatformDispatcher.onError`.
  static Result<void> recordUncaughtError(Object error, StackTrace stackTrace) {
    return attempt(
      () => mitigation_api.recordFlutterCrash(
        kind: mitigation_api.UiFlutterCrashKind.uncaughtAsync,
        message: error.toString(),
        stack: stackTrace.toString(),
      ),
    );
  }
}
