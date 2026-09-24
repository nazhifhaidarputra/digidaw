import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/core/utils/log_models.dart';
import 'package:karbeat/core/utils/logger.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/src/rust/api/logging.dart';

/// Receives batches from the Rust log queue and captures them as
/// [AppLogSource.rust] entries in the application log viewer.
///
/// Rust never waits on this listener: records are queued non-blockingly on the
/// Rust side and delivered as batches, so a slow or absent Dart listener can
/// only cause bounded, reported drops, never a stalled Rust thread.
class RustLogBridge {
  RustLogBridge({
    Stream<List<RustLogEntryDto>> Function()? subscribe,
    void Function(Iterable<ExternalLogRecord> records)? capture,
  }) : _subscribe = subscribe ?? subscribeRustLogs,
       _capture = capture ?? AppLogger.captureExternal;

  final Stream<List<RustLogEntryDto>> Function() _subscribe;
  final void Function(Iterable<ExternalLogRecord> records) _capture;
  StreamSubscription<List<RustLogEntryDto>>? _subscription;

  bool get isAttached => _subscription != null;

  /// Starts forwarding Rust records. Calling it again while attached is a no-op.
  Result<void> start() {
    if (_subscription != null) return Result.ok(null);
    final stream = attempt(_subscribe);
    if (stream case Error<Stream<List<RustLogEntryDto>>>(error: final error)) {
      return Result.error(error);
    }
    _subscription = stream.ok().listen(
      (batch) => _capture(batch.map(toRecord)),
      onError: (Object error, StackTrace stackTrace) {
        AppLogger.error(
          'Rust log stream failed',
          error: error,
          stackTrace: stackTrace,
        );
      },
      onDone: () => _subscription = null,
    );
    return Result.ok(null);
  }

  Future<void> stop() async {
    final subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
  }

  static ExternalLogRecord toRecord(RustLogEntryDto entry) => (
    source: AppLogSource.rust,
    level: switch (entry.level) {
      RustLogLevel.trace => AppLogLevel.trace,
      RustLogLevel.debug => AppLogLevel.debug,
      RustLogLevel.info => AppLogLevel.info,
      RustLogLevel.warn => AppLogLevel.warning,
      RustLogLevel.error => AppLogLevel.error,
    },
    message: entry.message,
    timestamp: DateTime.fromMillisecondsSinceEpoch(entry.timestampMillis),
    target: entry.target,
  );
}

final rustLogBridgeProvider = Provider<RustLogBridge>((ref) {
  final bridge = RustLogBridge();
  ref.onDispose(() => unawaited(bridge.stop()));
  return bridge;
});
