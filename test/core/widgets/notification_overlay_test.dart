import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karbeat/app/providers/notification_provider.dart';
import 'package:karbeat/core/widgets/notification_overlay.dart';

void main() {
  testWidgets('shows and dismisses a notification at the bottom right', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          builder: (context, child) => NotificationOverlay(child: child!),
          home: Consumer(
            builder: (context, ref, child) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => ref
                      .read(notificationProvider.notifier)
                      .info('Project exported', duration: Duration.zero),
                  child: const Text('Notify'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Notify'));
    await tester.pumpAndSettle();

    expect(find.text('Info'), findsOneWidget);
    expect(find.text('Project exported'), findsOneWidget);

    final overlaySize = tester.getSize(find.byType(NotificationOverlay));
    final boxBottomRight = tester.getBottomRight(find.text('Project exported'));
    expect(boxBottomRight.dx, greaterThan(overlaySize.width / 2));
    expect(boxBottomRight.dy, greaterThan(overlaySize.height / 2));

    await tester.tap(find.byKey(const ValueKey('dismiss-notification')));
    await tester.pumpAndSettle();

    expect(find.text('Project exported'), findsNothing);
  });
}
