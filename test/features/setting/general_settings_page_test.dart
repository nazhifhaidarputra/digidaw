import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/features/setting/models/general_settings_state.dart';
import 'package:karbeat/features/setting/services/general_settings_provider.dart';
import 'package:karbeat/features/setting/services/settings_service.dart';
import 'package:karbeat/features/setting/view/general_settings_page.dart';

class _RecordingGeneralSettingsNotifier extends GeneralSettingsNotifier {
  _RecordingGeneralSettingsNotifier(this.initial);

  final GeneralSettingsState initial;
  final enabledCalls = <bool>[];
  final intervalCalls = <int>[];

  @override
  GeneralSettingsState build() => initial;

  @override
  Future<Result<void>> setAutoSaveEnabled(bool enabled) async {
    enabledCalls.add(enabled);
    state = state.copyWith(autoSaveEnabled: enabled);
    return Result.ok(null);
  }

  @override
  Future<Result<void>> setAutoSaveInterval(int seconds) async {
    intervalCalls.add(seconds);
    state = state.copyWith(autoSaveIntervalSeconds: seconds);
    return Result.ok(null);
  }
}

Future<_RecordingGeneralSettingsNotifier> _pumpPage(
  WidgetTester tester,
  GeneralSettingsState initial,
) async {
  final notifier = _RecordingGeneralSettingsNotifier(initial);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [generalSettingsProvider.overrideWith(() => notifier)],
      child: MaterialApp(
        theme: ThemeData.dark(),
        home: const Scaffold(body: GeneralSettingsPage()),
      ),
    ),
  );
  return notifier;
}

void main() {
  test('auto save interval bounds match the engine', () {
    expect(SettingsService.isValidAutoSaveInterval(60), isTrue);
    expect(SettingsService.isValidAutoSaveInterval(3600), isTrue);
    expect(SettingsService.isValidAutoSaveInterval(59), isFalse);
    expect(SettingsService.isValidAutoSaveInterval(3601), isFalse);
  });

  testWidgets('auto save switch and interval dispatch updates', (tester) async {
    final notifier = await _pumpPage(tester, const GeneralSettingsState());

    expect(find.text('5 minutes'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('auto-save-enabled-switch')));
    await tester.pump();
    expect(notifier.enabledCalls, [false]);

    await tester.tap(find.byKey(const ValueKey('auto-save-enabled-switch')));
    await tester.pump();
    await tester.tap(find.text('5 minutes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('10 minutes').last);
    await tester.pumpAndSettle();

    expect(notifier.enabledCalls, [false, true]);
    expect(notifier.intervalCalls, [600]);
    expect(find.text('10 minutes'), findsOneWidget);
  });

  testWidgets('interval is locked while auto save is disabled', (tester) async {
    final notifier = await _pumpPage(
      tester,
      const GeneralSettingsState(autoSaveEnabled: false),
    );

    await tester.tap(find.text('5 minutes'));
    await tester.pumpAndSettle();

    expect(find.text('10 minutes'), findsNothing);
    expect(notifier.intervalCalls, isEmpty);
  });

  testWidgets('a persisted non-preset interval stays selectable', (
    tester,
  ) async {
    await _pumpPage(
      tester,
      const GeneralSettingsState(autoSaveIntervalSeconds: 90),
    );

    expect(find.text('90 seconds'), findsOneWidget);
  });
}
