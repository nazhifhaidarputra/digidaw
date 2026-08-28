import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/shared/models/user_notification.dart';

/// Immutable public state for the notification queue.
///
/// The queue itself deliberately stays private. Exposing only its active item
/// and length lets [ListQueue] perform O(1) push/pop operations without copying
/// the whole buffer every time Riverpod publishes a new state.
@immutable
final class NotificationQueueState {
  const NotificationQueueState({this.current, this.pendingCount = 0});

  final UserNotificationEvent? current;
  final int pendingCount;

  bool get isEmpty => current == null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationQueueState &&
          other.current == current &&
          other.pendingCount == pendingCount;

  @override
  int get hashCode => Object.hash(current, pendingCount);
}

class NotificationNotifier extends Notifier<NotificationQueueState> {
  static const int maxPendingNotifications = 100;

  final ListQueue<UserNotificationEvent> _pending = ListQueue();
  int _nextId = 0;

  @override
  NotificationQueueState build() {
    ref.onDispose(_pending.clear);
    return const NotificationQueueState();
  }

  void info(
    String message, {
    String? title,
    Duration duration = const Duration(seconds: 4),
  }) {
    _push(
      type: UserNotificationType.info,
      message: message,
      title: title,
      duration: duration,
    );
  }

  void warn(
    String message, {
    String? title,
    Duration duration = const Duration(seconds: 5),
  }) {
    _push(
      type: UserNotificationType.warn,
      message: message,
      title: title,
      duration: duration,
    );
  }

  void error(
    Object error, {
    String? title,
    StackTrace? stackTrace,
    Duration duration = const Duration(seconds: 7),
  }) {
    _push(
      type: UserNotificationType.error,
      message: _readableError(error),
      title: title,
      duration: duration,
    );
  }

  void push(UserNotificationEvent event) {
    final eventId = event.id < _nextId ? _nextId : event.id;
    _nextId = eventId + 1;
    final normalizedEvent = UserNotificationEvent(
      id: eventId,
      type: event.type,
      title: event.title,
      message: event.message,
      createdAt: event.createdAt,
      duration: event.duration,
    );
    _enqueue(normalizedEvent);
  }

  /// Removes the visible event and promotes the next FIFO item, if any.
  ///
  /// [eventId] prevents an expired timer from dismissing a newer event.
  void dismissCurrent({int? eventId}) {
    if (eventId != null && state.current?.id != eventId) return;

    final next = _pending.isEmpty ? null : _pending.removeFirst();
    state = NotificationQueueState(
      current: next,
      pendingCount: _pending.length,
    );
  }

  void clear() {
    _pending.clear();
    state = const NotificationQueueState();
  }

  void _push({
    required UserNotificationType type,
    required String message,
    required Duration duration,
    String? title,
  }) {
    _enqueue(
      UserNotificationEvent(
        id: _nextId++,
        type: type,
        title: title,
        message: message,
        createdAt: DateTime.now(),
        duration: duration,
      ),
    );
  }

  void _enqueue(UserNotificationEvent event) {
    if (state.current == null) {
      state = NotificationQueueState(current: event);
      return;
    }

    if (_pending.length == maxPendingNotifications) {
      _pending.removeFirst();
    }
    _pending.addLast(event);
    state = NotificationQueueState(
      current: state.current,
      pendingCount: _pending.length,
    );
  }

  static String _readableError(Object error) {
    final text = error.toString().trim();
    return text.replaceFirst(RegExp(r'^(Exception|Error):\s*'), '');
  }
}

final notificationProvider =
    NotifierProvider<NotificationNotifier, NotificationQueueState>(
      NotificationNotifier.new,
    );

/// Consistent error handling for APIs that expose the local [Result] type.
extension NotificationResultRef on Ref {
  Result<T> notifyErrorResult<T>(
    Object error, {
    String? title,
    StackTrace? stackTrace,
  }) {
    read(
      notificationProvider.notifier,
    ).error(error, title: title, stackTrace: stackTrace);
    return Result.error(
      error is Exception ? error : Exception(error.toString()),
    );
  }

  void notifyError(Object error, {String? title, StackTrace? stackTrace}) {
    read(
      notificationProvider.notifier,
    ).error(error, title: title, stackTrace: stackTrace);
  }

  /// Converts a throwing API into [AsyncValue] while also notifying the user.
  Future<AsyncValue<T>> guardApi<T>(
    Future<T> Function() call, {
    String? title,
  }) async {
    try {
      return AsyncData(await call());
    } catch (error, stackTrace) {
      notifyError(error, title: title, stackTrace: stackTrace);
      return AsyncError(error, stackTrace);
    }
  }
}

/// Observes errors emitted directly by Riverpod providers (for example an
/// [AsyncNotifier] whose build method throws).
final class NotificationProviderObserver extends ProviderObserver {
  const NotificationProviderObserver();

  @override
  void providerDidFail(
    ProviderObserverContext context,
    Object error,
    StackTrace stackTrace,
  ) {
    if (context.provider == notificationProvider) return;

    // Provider observers run during another provider's notification. Deferring
    // avoids mutating notificationProvider inside that same lifecycle callback.
    Future.microtask(() {
      try {
        context.container
            .read(notificationProvider.notifier)
            .error(error, stackTrace: stackTrace);
      } on StateError {
        // The container may be disposed between the observer callback and this
        // microtask (notably during test/app shutdown).
      }
    });
  }
}
