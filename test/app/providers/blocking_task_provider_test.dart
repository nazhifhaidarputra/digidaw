import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karbeat/app/providers/blocking_task_provider.dart';
import 'package:karbeat/app/providers/notification_provider.dart';
import 'package:karbeat/core/utils/result_type.dart';

void main() {
  test('runs queued tasks in FIFO order without dropping any', () async {
    final container = ProviderContainer.test();
    final mailbox = container.read(blockingTaskProvider.notifier);
    final first = Completer<Result<int>>();
    final order = <String>[];

    final firstRun = mailbox.run(
      label: 'first',
      task: () {
        order.add('first');
        return first.future;
      },
    );
    final secondRun = mailbox.run(
      label: 'second',
      task: () async {
        order.add('second');
        return Result.ok(2);
      },
    );

    expect(container.read(blockingTaskProvider).active?.label, 'first');
    expect(container.read(blockingTaskProvider).pendingCount, 1);
    await pumpEventQueue();
    expect(order, ['first']);

    first.complete(Result.ok(1));
    expect((await firstRun).ok(), 1);
    expect((await secondRun).ok(), 2);
    expect(order, ['first', 'second']);

    await pumpEventQueue();
    expect(container.read(blockingTaskProvider).isBlocking, isFalse);
  });

  test('passes returned errors through and converts thrown errors', () async {
    final container = ProviderContainer.test();
    final mailbox = container.read(blockingTaskProvider.notifier);

    final returned = await mailbox.run<void>(
      label: 'returned',
      task: () async => Result.error(Exception('handled by caller')),
    );
    final thrown = await mailbox.run<void>(
      label: 'Thrown',
      task: () async => throw StateError('boom'),
    );

    expect(returned.err().toString(), contains('handled by caller'));
    expect(thrown.err().toString(), contains('boom'));
    expect(
      container.read(notificationProvider).current?.title,
      'Operation failed',
    );
    await pumpEventQueue();
    expect(container.read(blockingTaskProvider).isBlocking, isFalse);
  });

  test('nested submissions run inline instead of deadlocking', () async {
    final container = ProviderContainer.test();
    final mailbox = container.read(blockingTaskProvider.notifier);

    final outer = await mailbox.run(
      label: 'outer',
      timeoutSeconds: BlockingTaskTimeout.unbounded,
      task: () async {
        final inner = await mailbox.run(
          label: 'inner',
          task: () async => Result.ok('inner'),
        );
        return Result.ok('outer+${inner.ok()}');
      },
    );

    expect(outer.ok(), 'outer+inner');
  });

  testWidgets('timeout releases the UI and the next task still runs', (
    tester,
  ) async {
    final container = ProviderContainer.test();
    final mailbox = container.read(blockingTaskProvider.notifier);
    final hung = Completer<Result<void>>();
    Result<void>? timedOut;
    Result<int>? next;

    unawaited(
      mailbox
          .run(label: 'hung', timeoutSeconds: 2, task: () => hung.future)
          .then((result) => timedOut = result),
    );
    unawaited(
      mailbox
          .run(label: 'next', task: () async => Result.ok(7))
          .then((result) => next = result),
    );

    await tester.pump(const Duration(milliseconds: 1999));
    expect(timedOut, isNull);
    expect(container.read(blockingTaskProvider).active?.label, 'hung');

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(timedOut?.err(), isA<BlockingTaskTimeoutException>());
    expect(next?.ok(), 7);
    expect(container.read(blockingTaskProvider).isBlocking, isFalse);

    // The late outcome is observed and logged, not surfaced as unhandled.
    hung.complete(Result.ok(null));
    await tester.pump();
  });

  testWidgets('unbounded timeout keeps blocking until the task settles', (
    tester,
  ) async {
    final container = ProviderContainer.test();
    final mailbox = container.read(blockingTaskProvider.notifier);
    final slow = Completer<Result<void>>();
    Result<void>? result;

    unawaited(
      mailbox
          .run(
            label: 'slow',
            timeoutSeconds: double.infinity,
            task: () => slow.future,
          )
          .then((value) => result = value),
    );

    await tester.pump(const Duration(hours: 2));
    expect(result, isNull);
    expect(container.read(blockingTaskProvider).active?.timeout, isNull);

    slow.complete(Result.ok(null));
    await tester.pump();
    expect(result?.isOk(), isTrue);
  });

  test('rejects non-positive timeouts', () async {
    final container = ProviderContainer.test();
    final mailbox = container.read(blockingTaskProvider.notifier);

    final result = await mailbox.run(
      label: 'invalid',
      timeoutSeconds: 0,
      task: () async => Result.ok(1),
    );

    expect(result.isErr(), isTrue);
    expect(container.read(blockingTaskProvider).isBlocking, isFalse);
  });

  test('disposal cancels queued tasks instead of dropping them', () async {
    final container = ProviderContainer.test();
    final mailbox = container.read(blockingTaskProvider.notifier);
    final active = Completer<Result<void>>();

    final activeRun = mailbox.run(label: 'active', task: () => active.future);
    final queuedRun = mailbox.run<void>(
      label: 'queued',
      task: () async => Result.ok(null),
    );
    container.dispose();

    expect((await queuedRun).err(), isA<BlockingTaskCancelledException>());
    active.complete(Result.ok(null));
    expect((await activeRun).isOk(), isTrue);
  });
}
