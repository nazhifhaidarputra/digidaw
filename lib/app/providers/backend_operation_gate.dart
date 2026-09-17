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
