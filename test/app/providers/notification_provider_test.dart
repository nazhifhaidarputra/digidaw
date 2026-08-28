import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karbeat/app/providers/notification_provider.dart';
import 'package:karbeat/shared/models/user_notification.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  test('delivers notifications in FIFO order without exposing the buffer', () {
    final notifier = container.read(notificationProvider.notifier);

    notifier.info('first');
    final first = container.read(notificationProvider).current!;
    notifier.warn('second');
    notifier.error(Exception('third'));

    expect(first.message, 'first');
    expect(first.type, UserNotificationType.info);
    expect(container.read(notificationProvider).pendingCount, 2);

    notifier.dismissCurrent(eventId: first.id);
    final second = container.read(notificationProvider).current!;
    expect(second.message, 'second');
    expect(second.type, UserNotificationType.warn);
    expect(container.read(notificationProvider).pendingCount, 1);

    // A timer belonging to the first event must not dismiss the second one.
    notifier.dismissCurrent(eventId: first.id);
    expect(container.read(notificationProvider).current, second);

    notifier.dismissCurrent(eventId: second.id);
    expect(container.read(notificationProvider).current!.message, 'third');
    expect(container.read(notificationProvider).pendingCount, 0);
  });

  test('normalizes exception text and can clear the queue', () {
    final notifier = container.read(notificationProvider.notifier);

    notifier.error(Exception('Could not save project'));
    notifier.info('queued');

    expect(
      container.read(notificationProvider).current!.message,
      'Could not save project',
    );

    notifier.clear();
    expect(
      container.read(notificationProvider),
      const NotificationQueueState(),
    );
  });
}
