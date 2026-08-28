import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/notification_provider.dart';
import 'package:karbeat/shared/models/user_notification.dart';

/// Places user-facing notifications above [child] at the bottom-right edge.
class NotificationOverlay extends ConsumerStatefulWidget {
  const NotificationOverlay({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<NotificationOverlay> createState() =>
      _NotificationOverlayState();
}

class _NotificationOverlayState extends ConsumerState<NotificationOverlay> {
  Timer? _dismissTimer;
  late final ProviderSubscription<UserNotificationEvent?>
  _notificationSubscription;

  @override
  void initState() {
    super.initState();
    _notificationSubscription = ref.listenManual(
      notificationProvider.select((state) => state.current),
      (_, event) => _scheduleDismiss(event),
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _notificationSubscription.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final queueState = ref.watch(notificationProvider);

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        Positioned(
          right: 20,
          bottom: 20,
          child: SafeArea(
            minimum: const EdgeInsets.all(8),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.08, 0.08),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: queueState.current == null
                  ? const SizedBox.shrink(key: ValueKey('notification-empty'))
                  : _NotificationBox(
                      key: ValueKey(queueState.current!.id),
                      event: queueState.current!,
                      pendingCount: queueState.pendingCount,
                      onDismiss: () => ref
                          .read(notificationProvider.notifier)
                          .dismissCurrent(eventId: queueState.current!.id),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  void _scheduleDismiss(UserNotificationEvent? event) {
    _dismissTimer?.cancel();
    if (event == null || event.duration == Duration.zero) return;

    _dismissTimer = Timer(event.duration, () {
      if (!mounted) return;
      ref.read(notificationProvider.notifier).dismissCurrent(eventId: event.id);
    });
  }
}

class _NotificationBox extends StatelessWidget {
  const _NotificationBox({
    super.key,
    required this.event,
    required this.pendingCount,
    required this.onDismiss,
  });

  final UserNotificationEvent event;
  final int pendingCount;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final (accent, icon, defaultTitle) = switch (event.type) {
      UserNotificationType.info => (
        Colors.lightBlueAccent,
        Icons.info_outline,
        'Info',
      ),
      UserNotificationType.warn => (
        Colors.amberAccent,
        Icons.warning_amber_rounded,
        'Warning',
      ),
      UserNotificationType.error => (
        Colors.redAccent,
        Icons.error_outline,
        'Error',
      ),
    };

    return Semantics(
      liveRegion: true,
      label: '${event.title ?? defaultTitle}: ${event.message}',
      child: Material(
        color: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(minWidth: 280, maxWidth: 380),
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          decoration: BoxDecoration(
            color: const Color(0xFF24262B),
            borderRadius: BorderRadius.circular(8),
            border: Border(left: BorderSide(color: accent, width: 4)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 18,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: accent, size: 21),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title ?? defaultTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      event.message,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFD7D8DC),
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                    if (pendingCount > 0) ...[
                      const SizedBox(height: 5),
                      Text(
                        '$pendingCount more',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Semantics(
                button: true,
                label: 'Dismiss notification',
                child: IconButton(
                  key: const ValueKey('dismiss-notification'),
                  onPressed: onDismiss,
                  visualDensity: VisualDensity.compact,
                  iconSize: 17,
                  color: Colors.white54,
                  icon: const Icon(Icons.close),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
