import 'package:flutter_riverpod/flutter_riverpod.dart';

final backendOperationGateProvider =
    NotifierProvider<BackendOperationGateNotifier, int>(
      BackendOperationGateNotifier.new,
    );

class BackendOperationGateNotifier extends Notifier<int> {
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

extension BackendOperationCallback<T> on Future<T> Function() {
  /// Wraps this callback so synchronous backend polling stays paused until it
  /// completes, including while other guarded operations are still running.
  Future<T> Function() guardedByBackendOperationGate(
    BackendOperationGateNotifier gate,
  ) {
    final operation = this;
    return () => gate.run(operation);
  }
}
