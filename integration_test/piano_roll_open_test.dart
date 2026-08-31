import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:karbeat/app/app.dart';
import 'package:karbeat/app/providers/notification_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('opens the piano roll with the live engine', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        observers: [NotificationProviderObserver()],
        child: KarbeatApp(),
      ),
    );

    for (var attempt = 0; attempt < 40; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      await tester.pump();
      if (find.text('Tracks').evaluate().isNotEmpty) break;
    }

    expect(find.text('Tracks'), findsWidgets);
    await tester.tap(find.text('Tracks').first);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Piano Roll').last);
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('No Pattern Selected'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
