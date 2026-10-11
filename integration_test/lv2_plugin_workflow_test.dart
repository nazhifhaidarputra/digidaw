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
import 'package:karbeat/shared/models/user_notification.dart';
import 'package:karbeat/src/rust/api/audio.dart' as audio_api;
import 'package:karbeat/src/rust/api/external_plugins.dart'
    as external_plugin_api;
import 'package:karbeat/src/rust/api/mixer.dart' as mixer_api;
import 'package:karbeat/src/rust/api/plugin.dart' as plugin_api;
import 'package:karbeat/src/rust/api/project.dart' as project_api;

/// LV2 instrument without an editor, used for the audible part of the workflow.
const _instrument = 'MDA DX10';

/// LV2 instrument with an X11 editor.
const _withEditor = 'LSP Sampler Mono';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Both bundles have to be on a default LV2 path for the scan to find them.
  final canRun =
      Platform.isLinux &&
      Directory('/usr/lib64/lv2/mda.lv2').existsSync() &&
      Directory('/usr/lib64/lv2/lsp-plugins.lv2').existsSync();

  testWidgets('scans, adds, plays, and edits LV2 plugins through Flutter', (
    tester,
  ) async {
    await _stage(
      'app bootstrap',
      tester.pumpWidget(
        const ProviderScope(
          observers: [NotificationProviderObserver()],
          child: KarbeatApp(),
        ),
      ),
    );
    await _stage(
      'workspace bootstrap',
      _pumpUntil(tester, () => find.text('Tracks').evaluate().isNotEmpty),
    );
    // An earlier run that ended with its test leaves a crash report prompt open.
    final crashPrompt = find.byKey(const ValueKey('crash-recovery-dialog'));
    if (crashPrompt.evaluate().isNotEmpty) {
      await tester.tap(
        find.descendant(of: crashPrompt, matching: find.text('Close')),
      );
      await _stage(
        'dismiss crash prompt',
        _pumpUntil(tester, () => crashPrompt.evaluate().isEmpty),
      );
    }
    final container = ProviderScope.containerOf(
      tester.element(find.byType(KarbeatApp)),
    );
    final context = container.read(projectProvider.notifier).dawContext;
    final notifications = <UserNotificationEvent>[];
    final notificationSubscription = container.listen(notificationProvider, (
      previous,
      next,
    ) {
      final event = next.current;
      if (event != null && previous?.current?.id != event.id) {
        notifications.add(event);
      }
    });
    final createdTrackIds = <int>{};

    Future<void> deleteTrack(int trackId) async {
      await _stage(
        'delete track $trackId',
        container
            .read(trackListStateProvider.notifier)
            .deleteTrack(trackId: trackId),
      );
      createdTrackIds.remove(trackId);
      await _pumpUntil(
        tester,
        () => !container
            .read(projectProvider)
            .requireValue
            .tracks
            .containsKey(trackId),
      );
    }

    try {
      await tester.tap(find.byTooltip('Project'));
      await _stage(
        'open project menu',
        _pumpUntil(tester, () => find.text('Settings').evaluate().isNotEmpty),
      );
      await tester.tap(find.text('Settings'));
      await _stage(
        'open settings',
        _pumpUntil(
          tester,
          () => find
              .byKey(const ValueKey(SettingMenu.plugins))
              .evaluate()
              .isNotEmpty,
        ),
      );
      await tester.tap(find.byKey(const ValueKey(SettingMenu.plugins)));
      await _stage('show plugin settings', tester.pump());
      await _stage(
        'plugin settings initialization',
        _pumpUntil(
          tester,
          () => container.read(pluginSettingsProvider).isInitialized,
        ),
      );
      expect(
        container.read(pluginSettingsProvider).defaultDirectories,
        contains('/usr/lib64/lv2'),
        reason: 'LV2 search paths must be listed with the other defaults',
      );
      // The default directory list can push the scan button below the viewport.
      await tester.ensureVisible(find.byKey(const ValueKey('scan-plugins')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('scan-plugins')));
      await _stage('start plugin scan', tester.pump());
      await _stage(
        'plugin scan',
        _pumpUntil(tester, () {
          final state = container.read(pluginSettingsProvider);
          return !state.isScanning &&
              (state.discoveredCount > 0 || state.scanError != null);
        }, timeout: const Duration(seconds: 150)),
        timeout: const Duration(seconds: 155),
      );
      expect(container.read(pluginSettingsProvider).scanError, isNull);

      await tester.tap(find.byTooltip('Close settings'));
      await _stage(
        'close settings',
        _pumpUntil(
          tester,
          () => find.text('Add New Track').evaluate().isNotEmpty,
        ),
      );

      // --- Instrument without an editor: parameters, text, and audio. ---
      final dx10 = await _addGenerator(
        tester,
        container,
        _instrument,
        createdTrackIds,
      );
      final target = plugin_api.UiPluginTarget.generator(dx10.generatorId!);
      final capabilities = await _stage(
        'capability query',
        external_plugin_api.externalPluginCapabilities(
          ctx: context,
          target: target,
        ),
      );
      expect(capabilities.controller, isTrue);
      expect(capabilities.editor, isFalse);

      final parameters = await _stage(
        'parameter query',
        plugin_api.getPluginParameterSpecs(ctx: context, target: target),
      );
      final parameter = parameters.firstWhere(
        (candidate) =>
            candidate.paramType == plugin_api.UiParameterType.float &&
            candidate.step == 0 &&
            candidate.value.isFinite &&
            candidate.value >= 0 &&
            candidate.value <= 1,
      );
      final changedValue = parameter.value <= 0.5
          ? parameter.value + 0.1
          : parameter.value - 0.1;
      expect(
        await _stage(
          'parameter text',
          external_plugin_api.externalPluginParameterText(
            ctx: context,
            target: target,
            parameter: parameter.id,
            value: changedValue,
          ),
        ),
        isNotEmpty,
      );
      await _stage(
        'subscribe plugin telemetry',
        plugin_api.setPluginTelemetrySubs(
          ctx: context,
          target: target,
          buffers: const [],
          active: true,
        ),
      );
      await _stage(
        'change parameter',
        external_plugin_api.setExternalPluginParameter(
          ctx: context,
          target: target,
          parameter: parameter.id,
          value: changedValue,
        ),
      );
      await _stage(
        'changed parameter telemetry',
        _pumpUntil(tester, () {
          final snapshot = plugin_api.getPluginSnapshotTelemetrySync(
            ctx: context,
            target: target,
          );
          final values = snapshot?.parameters.where(
            (entry) => entry.$1 == parameter.id,
          );
          return values != null &&
              values.isNotEmpty &&
              (values.single.$2 - changedValue).abs() < 0.0001;
        }),
      );
      await _stage(
        'unsubscribe plugin telemetry',
        plugin_api.setPluginTelemetrySubs(
          ctx: context,
          target: target,
          buffers: const [],
          active: false,
        ),
      );

      await _stage(
        'subscribe mixer telemetry',
        mixer_api.setMixerTelemetrySubs(ctx: context, active: true),
      );
      await _stage(
        'start preview note',
        audio_api.playPreviewNote(
          ctx: context,
          trackId: dx10.id,
          noteKey: 60,
          velocity: 100,
          isOn: true,
        ),
      );
      double magnitude = 0;
      await _stage(
        'nonzero instrument audio',
        _pumpUntil(tester, () {
          final snapshot = mixer_api.getMixerTelemetrySync(ctx: context);
          magnitude = snapshot.tracks[dx10.id]?.magnitude ?? 0;
          return magnitude.isFinite && magnitude > 0.000001;
        }, timeout: const Duration(seconds: 10)),
        timeout: const Duration(seconds: 15),
      );
      expect(magnitude, greaterThan(0.000001));
      await _stage(
        'stop preview note',
        audio_api.playPreviewNote(
          ctx: context,
          trackId: dx10.id,
          noteKey: 60,
          velocity: 0,
          isOn: false,
        ),
      );
      await _stage(
        'unsubscribe mixer telemetry',
        mixer_api.setMixerTelemetrySubs(ctx: context, active: false),
      );
      await deleteTrack(dx10.id);

      // --- Instrument with an X11 editor: open, close, reopen, delete. ---
      final sampler = await _addGenerator(
        tester,
        container,
        _withEditor,
        createdTrackIds,
      );
      final editorTarget = plugin_api.UiPluginTarget.generator(
        sampler.generatorId!,
      );
      final editorCapabilities = await _stage(
        'editor capability query',
        external_plugin_api.externalPluginCapabilities(
          ctx: context,
          target: editorTarget,
        ),
      );
      expect(editorCapabilities.editor, isTrue);
      await _stage(
        'open editor',
        external_plugin_api.openExternalPluginEditor(
          ctx: context,
          target: editorTarget,
        ),
      );
      var flutterFrameCompleted = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        flutterFrameCompleted = true;
      });
      await _stage('Flutter frame with editor open', tester.pump());
      expect(flutterFrameCompleted, isTrue);
      expect(find.text('Tracks'), findsWidgets);
      // The editor idles on the native loop while Flutter keeps rendering.
      for (var frame = 0; frame < 20; frame++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
      await _stage(
        'close editor',
        external_plugin_api.closeExternalPluginEditor(
          ctx: context,
          target: editorTarget,
        ),
      );
      await _stage(
        'repeat editor close',
        external_plugin_api.closeExternalPluginEditor(
          ctx: context,
          target: editorTarget,
        ),
      );
      await _stage(
        'reopen editor',
        external_plugin_api.openExternalPluginEditor(
          ctx: context,
          target: editorTarget,
        ),
      );
      await _stage('Flutter frame with reopened editor', tester.pump());
      await deleteTrack(sampler.id);
      expect(
        await _stage(
          'deleted descriptor lookup',
          external_plugin_api.externalPluginDescriptor(
            ctx: context,
            target: editorTarget,
          ),
        ),
        isNull,
      );

      final errors = notifications.where(
        (event) => event.type == UserNotificationType.error,
      );
      expect(errors.map((event) => event.message), isEmpty);
    } finally {
      // Cleanup runs here because the provider container is gone by tear-down.
      for (final trackId in createdTrackIds.toList()) {
        await deleteTrack(trackId);
      }
      notificationSubscription.close();
    }
  }, skip: !canRun);
}

/// Adds the LV2 generator called [name] through the track dialog and plugin browser, and
/// returns its new track.
Future<({int id, int? generatorId})> _addGenerator(
  WidgetTester tester,
  ProviderContainer container,
  String name,
  Set<int> createdTrackIds,
) async {
  final entry =
      (await _stage(
        '$name catalog lookup',
        container
            .read(audioPluginProvider.notifier)
            .getBrowserEntries(
              plugin_api.KarbeatPluginType.generator,
              query: name,
            ),
      )).singleWhere(
        (entry) =>
            entry.name == name && entry.binaryType == PluginBinaryType.lv2,
      );
  expect(entry.binaryType.label, 'LV2');

  await tester.tap(find.text('Add New Track'));
  await _stage(
    'open track type dialog',
    _pumpUntil(
      tester,
      () => find.text('Add generator...').evaluate().isNotEmpty,
    ),
  );
  await tester.tap(find.text('Add generator...'));
  await _stage(
    'open generator browser',
    _pumpUntil(
      tester,
      () => find
          .byKey(const ValueKey('plugin-browser-search'))
          .evaluate()
          .isNotEmpty,
    ),
  );
  await tester.enterText(
    find.byKey(const ValueKey('plugin-browser-search')),
    name,
  );
  await _stage('filter generator browser', tester.pump());
  expect(
    find.byKey(ValueKey('plugin-browser-${entry.favoriteKey}')),
    findsOneWidget,
  );
  await tester.tap(find.byKey(ValueKey('plugin-browser-${entry.favoriteKey}')));
  await _stage('select $name', tester.pump());
  final existingTrackIds = container
      .read(projectProvider)
      .requireValue
      .tracks
      .keys
      .toSet();
  bool isNewTrack(project_api.UiTrack track) =>
      track.name == name && !existingTrackIds.contains(track.id);
  await tester.tap(find.byKey(const ValueKey('add-selected-plugin')));
  // Preparation runs off the UI thread; a frame blocked for long fails this wait.
  await _stage(
    'responsive $name track creation',
    _pumpUntilResponsive(
      tester,
      () =>
          container
              .read(projectProvider)
              .value
              ?.tracks
              .values
              .any(isNewTrack) ??
          false,
      timeout: const Duration(seconds: 40),
    ),
    timeout: const Duration(seconds: 45),
  );
  final track = container
      .read(projectProvider)
      .requireValue
      .tracks
      .values
      .singleWhere(isNewTrack);
  createdTrackIds.add(track.id);
  expect(track.generatorId, isNotNull);
  return (id: track.id, generatorId: track.generatorId);
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

Future<T> _stage<T>(
  String name,
  Future<T> operation, {
  Duration timeout = const Duration(seconds: 20),
}) {
  return operation.timeout(
    timeout,
    onTimeout: () => throw TestFailure('Timed out during $name'),
  );
}

Future<void> _pumpUntilResponsive(
  WidgetTester tester,
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 20),
  Duration maximumPumpLatency = const Duration(seconds: 2),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TestFailure('Timed out waiting for integration state');
    }
    await Future<void>.delayed(const Duration(milliseconds: 16));
    final frameTimer = Stopwatch()..start();
    await tester.pump(const Duration(milliseconds: 16));
    frameTimer.stop();
    if (frameTimer.elapsed > maximumPumpLatency) {
      throw TestFailure(
        'Flutter frame was blocked for ${frameTimer.elapsed.inMilliseconds}ms '
        'while preparing a plugin',
      );
    }
  }
}
