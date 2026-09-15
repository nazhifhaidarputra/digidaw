import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:karbeat/app/app.dart';
import 'package:karbeat/app/providers/notification_provider.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/app/providers/track_list_state.dart';
import 'package:karbeat/features/plugins/models/plugin_browser_entry.dart';
import 'package:karbeat/features/plugins/services/audio_plugins_service.dart';
import 'package:karbeat/features/setting/models/setting_state.dart';
import 'package:karbeat/features/setting/services/plugin_settings_provider.dart';
import 'package:karbeat/src/rust/api/audio.dart' as audio_api;
import 'package:karbeat/src/rust/api/mixer.dart' as mixer_api;
import 'package:karbeat/src/rust/api/plugin.dart' show KarbeatPluginType;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final vitalPath =
      Platform.environment['VITAL_VST3_PATH'] ?? '/usr/lib/vst3/Vital.vst3';
  final canRun = Platform.isLinux && Directory(vitalPath).existsSync();

  testWidgets('scans, favorites, adds, and renders Vital through Flutter', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        observers: [NotificationProviderObserver()],
        child: KarbeatApp(),
      ),
    );
    await _pumpUntil(tester, () => find.text('Tracks').evaluate().isNotEmpty);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(KarbeatApp)),
    );
    final context = container.read(projectProvider.notifier).dawContext;
    int? createdTrackId;
    String? favoriteKey;
    var addedFavorite = false;

    addTearDown(() async {
      if (createdTrackId != null) {
        await container
            .read(trackListStateProvider.notifier)
            .deleteTrack(trackId: createdTrackId!);
      }
      if (addedFavorite && favoriteKey != null) {
        await container
            .read(audioPluginProvider.notifier)
            .toggleFavorite(favoriteKey!);
      }
      await mixer_api.setMixerTelemetrySubs(ctx: context, active: false);
    });

    await tester.tap(find.byTooltip('Project'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey(SettingMenu.plugins)));
    await tester.pump();
    await _pumpUntil(
      tester,
      () => container.read(pluginSettingsProvider).isInitialized,
    );
    await tester.tap(find.byKey(const ValueKey('scan-plugins')));
    await tester.pump();
    await _pumpUntil(tester, () {
      final state = container.read(pluginSettingsProvider);
      return !state.isScanning &&
          (state.discoveredCount > 0 || state.scanError != null);
    }, timeout: const Duration(seconds: 90));
    expect(container.read(pluginSettingsProvider).scanError, isNull);

    final vital =
        (await container
                .read(audioPluginProvider.notifier)
                .getBrowserEntries(KarbeatPluginType.generator, query: 'Vital'))
            .singleWhere((entry) => entry.name == 'Vital');
    expect(vital.binaryType.label, 'VST3');
    favoriteKey = vital.favoriteKey;

    await tester.tap(find.byTooltip('Close settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add New Track'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add generator...'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('plugin-browser-search')),
      'Vital',
    );
    await tester.pump();
    expect(find.text('VST3'), findsOneWidget);
    if (!container
        .read(audioPluginProvider)
        .requireValue
        .favoriteKeys
        .contains(vital.favoriteKey)) {
      await tester.tap(
        find.byKey(ValueKey('plugin-favorite-${vital.favoriteKey}')),
      );
      await tester.pumpAndSettle();
      addedFavorite = true;
    }
    await tester.tap(find.text('Vital'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('add-selected-plugin')));
    await _pumpUntil(
      tester,
      () =>
          container
              .read(projectProvider)
              .value
              ?.tracks
              .values
              .any((track) => track.name == 'Vital') ??
          false,
      timeout: const Duration(seconds: 30),
    );

    final track = container
        .read(projectProvider)
        .requireValue
        .tracks
        .values
        .singleWhere((track) => track.name == 'Vital');
    createdTrackId = track.id;
    expect(track.generatorId, isNotNull);

    await mixer_api.setMixerTelemetrySubs(ctx: context, active: true);
    await audio_api.playPreviewNote(
      ctx: context,
      trackId: track.id,
      noteKey: 60,
      velocity: 100,
      isOn: true,
    );
    double magnitude = 0;
    await _pumpUntil(tester, () {
      final snapshot = mixer_api.getMixerTelemetrySync(ctx: context);
      magnitude = snapshot.tracks[track.id]?.magnitude ?? 0;
      return magnitude.isFinite && magnitude > 0.000001;
    }, timeout: const Duration(seconds: 10));
    expect(magnitude, greaterThan(0.000001));
    await audio_api.playPreviewNote(
      ctx: context,
      trackId: track.id,
      noteKey: 60,
      velocity: 0,
      isOn: false,
    );
  }, skip: !canRun);
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TestFailure('Timed out waiting for integration state');
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await tester.pump();
  }
}
