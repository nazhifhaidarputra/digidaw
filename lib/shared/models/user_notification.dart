import 'package:flutter/foundation.dart';

/// The visual importance of a user-facing notification.
enum UserNotificationType { info, warn, error }

/// A single immutable event displayed to the user.
@immutable
final class UserNotificationEvent {
  const UserNotificationEvent({
    required this.id,
    required this.type,
    required this.message,
    required this.createdAt,
    this.title,
    this.duration = const Duration(seconds: 5),
  });

  final int id;
  final UserNotificationType type;
  final String? title;
  final String message;
  final DateTime createdAt;
  final Duration duration;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserNotificationEvent &&
          other.id == id &&
          other.type == type &&
          other.title == title &&
          other.message == message &&
          other.createdAt == createdAt &&
          other.duration == duration;

  @override
  int get hashCode =>
      Object.hash(id, type, title, message, createdAt, duration);
}
