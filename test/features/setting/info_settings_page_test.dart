import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karbeat/features/setting/services/app_info_service.dart';
import 'package:karbeat/features/setting/view/info_settings_page.dart';

void main() {
  testWidgets('shows injected package metadata and support information', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appPackageMetadataProvider.overrideWith(
            (ref) async => (version: '1.2.3', buildNumber: '45'),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(body: InfoSettingsPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1.2.3'), findsOneWidget);
    expect(find.text('45'), findsOneWidget);
    expect(find.text(InfoSettingsPage.supportUrl), findsOneWidget);
    expect(find.byTooltip('Copy bug report URL'), findsOneWidget);
    expect(find.text('View licenses'), findsOneWidget);
  });

  testWidgets('offers retry when package metadata fails', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appPackageMetadataProvider.overrideWith(
            (ref) => Future.error(Exception('metadata unavailable')),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(body: InfoSettingsPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Version information is unavailable.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}
