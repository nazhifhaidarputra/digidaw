import 'package:flutter_riverpod/flutter_riverpod.dart';

final telemetryPollingSuppressionProvider =
    NotifierProvider<TelemetryPollingSuppressionNotifier, int>(
      TelemetryPollingSuppressionNotifier.new,
    );

class TelemetryPollingSuppressionNotifier extends Notifier<int> {
  @override
  int build() => 0;

  Future<T> run<T>(Future<T> Function() operation) async {
    state += 1;
    try {
      return await operation();
    } finally {
      state -= 1;
    }
  }
}

extension TelemetryPollingSuppressionCallback<T> on Future<T> Function() {
  /// Wraps this callback so synchronous backend polling stays paused until it
  /// completes, including while other suppressing operations are still running.
  Future<T> Function() suppressesTelemetryPolling(
    TelemetryPollingSuppressionNotifier suppression,
  ) {
    final operation = this;
    return () => suppression.run(operation);
  }
}
