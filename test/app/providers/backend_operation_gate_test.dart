import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karbeat/app/providers/telemetry_polling_suppression.dart';

void main() {
  test(
    'tracks overlapping telemetry suppression and releases after errors',
    () async {
      final container = ProviderContainer.test();
      final suppression = container.read(
        telemetryPollingSuppressionProvider.notifier,
      );
      final first = Completer<void>();
      final second = Completer<void>();

      final firstRun = suppression.run(() => first.future);
      final secondRun = suppression.run(() => second.future);
      expect(container.read(telemetryPollingSuppressionProvider), 2);

      first.complete();
      await firstRun;
      expect(container.read(telemetryPollingSuppressionProvider), 1);

      second.completeError(StateError('failed'));
      await expectLater(secondRun, throwsStateError);
      expect(container.read(telemetryPollingSuppressionProvider), 0);
    },
  );

  test('callback suppresses polling only while invoked', () async {
    final container = ProviderContainer.test();
    final suppression = container.read(
      telemetryPollingSuppressionProvider.notifier,
    );
    final operation = Completer<void>();
    final guarded = (() => operation.future).suppressesTelemetryPolling(
      suppression,
    );

    expect(container.read(telemetryPollingSuppressionProvider), 0);

    final running = guarded();
    expect(container.read(telemetryPollingSuppressionProvider), 1);

    operation.complete();
    await running;
    expect(container.read(telemetryPollingSuppressionProvider), 0);
  });
}
