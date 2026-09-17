import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karbeat/app/providers/backend_operation_gate.dart';

void main() {
  test(
    'tracks overlapping backend operations and releases after errors',
    () async {
      final container = ProviderContainer.test();
      final gate = container.read(backendOperationGateProvider.notifier);
      final first = Completer<void>();
      final second = Completer<void>();

      final firstRun = gate.run(() => first.future);
      final secondRun = gate.run(() => second.future);
      expect(container.read(backendOperationGateProvider), 2);

      first.complete();
      await firstRun;
      expect(container.read(backendOperationGateProvider), 1);

      second.completeError(StateError('failed'));
      await expectLater(secondRun, throwsStateError);
      expect(container.read(backendOperationGateProvider), 0);
    },
  );
}
