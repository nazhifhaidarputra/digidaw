import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/features/setting/models/plugin_settings_state.dart';
import 'package:karbeat/features/setting/services/plugin_settings_provider.dart';
import 'package:karbeat/features/setting/view/plugin_settings_page.dart';
import 'package:karbeat/src/rust/api/external_plugins.dart';

class _SettingsNotifier extends PluginSettingsNotifier {
  _SettingsNotifier(this.initialState);

  final PluginSettingsState initialState;
  bool scanCalled = false;
  bool cancelCalled = false;
  bool retryCalled = false;

  @override
  PluginSettingsState build() => initialState;

  @override
  Future<Result<void>> scan({bool retryQuarantined = false}) async {
    scanCalled = true;
    retryCalled = retryQuarantined;
    return Result.ok(null);
  }

  @override
  Future<Result<void>> cancelScan() async {
    cancelCalled = true;
    return Result.ok(null);
  }
}

const _unavailableVital = UiExternalPluginEntry(
  id: 77,
  available: false,
  descriptor: UiExternalPluginDescriptor(
    format: UiExternalPluginFormat.vst3,
    nativeId: 'vital',
    path: '/usr/lib/vst3/Vital.vst3',
    name: 'Vital',
    vendor: 'Vital Audio',
    version: '1.6.4',
    instrument: true,
  ),
);

void main() {
  testWidgets('lays out configured and standard directories responsively', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(640, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final notifier = _SettingsNotifier(
      const PluginSettingsState(
        isInitialized: true,
        directories: IListConst(['/custom/plugins']),
        defaultDirectories: IListConst(['/usr/lib/vst3']),
        timeoutSeconds: 60,
      ),
    );
    await _pumpPage(tester, notifier);

    expect(find.text('/custom/plugins'), findsOneWidget);
    expect(find.text('/usr/lib/vst3'), findsOneWidget);
    expect(find.text('60 seconds'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('scan-plugins')));
    expect(notifier.scanCalled, isTrue);
  });

  testWidgets('shows live scan state and enables cancel', (tester) async {
    final notifier = _SettingsNotifier(
      const PluginSettingsState(
        isInitialized: true,
        isScanning: true,
        scanId: 4,
        completed: 2,
        total: 5,
        discoveredCount: 1,
        currentPath: '/plugins/Vital.vst3',
      ),
    );
    await _pumpPage(tester, notifier);

    expect(find.text('2 of 5 modules · 1 plugin discovered'), findsOneWidget);
    expect(find.text('/plugins/Vital.vst3'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('cancel-plugin-scan')));
    expect(notifier.cancelCalled, isTrue);
  });

  testWidgets('offers retry for unavailable quarantined catalog entries', (
    tester,
  ) async {
    final notifier = _SettingsNotifier(
      const PluginSettingsState(
        isInitialized: true,
        externalPlugins: IListConst([_unavailableVital]),
      ),
    );
    await _pumpPage(tester, notifier);

    await tester.tap(find.byKey(const ValueKey('retry-plugin-scan')));
    expect(notifier.retryCalled, isTrue);
  });
}

Future<void> _pumpPage(WidgetTester tester, _SettingsNotifier notifier) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [pluginSettingsProvider.overrideWith(() => notifier)],
      child: const MaterialApp(home: Scaffold(body: PluginSettingsPage())),
    ),
  );
  await tester.pump();
}
