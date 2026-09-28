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
import 'package:karbeat/src/rust/api/external_plugins.dart'
    as external_plugin_api;
import 'package:karbeat/src/rust/api/mixer.dart' as mixer_api;
import 'package:karbeat/src/rust/api/plugin.dart' as plugin_api;
import 'package:karbeat/shared/models/user_notification.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final vitalPath =
      Platform.environment['VITAL_VST3_PATH'] ?? '/usr/lib/vst3/Vital.vst3';
  final canRun = Platform.isLinux && Directory(vitalPath).existsSync();

  testWidgets('scans, favorites, adds, and renders Vital through Flutter', (
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
    int? createdTrackId;
    plugin_api.UiPluginTarget? createdTarget;
    String? favoriteKey;
    var addedFavorite = false;

    addTearDown(() async {
      notificationSubscription.close();
      if (createdTarget != null) {
        await _stage(
          'teardown Vital telemetry',
          plugin_api.setPluginTelemetrySubs(
            ctx: context,
            target: createdTarget,
            buffers: const [],
            active: false,
          ),
        );
      }
      if (createdTrackId != null) {
        await _stage(
          'teardown Vital track',
          container
              .read(trackListStateProvider.notifier)
              .deleteTrack(trackId: createdTrackId),
        );
      }
      if (addedFavorite && favoriteKey != null) {
        await _stage(
          'teardown Vital favorite',
          container
              .read(audioPluginProvider.notifier)
              .toggleFavorite(favoriteKey),
        );
      }
      await _stage(
        'teardown mixer telemetry',
        mixer_api.setMixerTelemetrySubs(ctx: context, active: false),
      );
    });

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
    await tester.tap(find.byKey(const ValueKey('scan-plugins')));
    await _stage('start plugin scan', tester.pump());
    await _stage(
      'Vital scan',
      _pumpUntil(tester, () {
        final state = container.read(pluginSettingsProvider);
        return !state.isScanning &&
            (state.discoveredCount > 0 || state.scanError != null);
      }, timeout: const Duration(seconds: 90)),
      timeout: const Duration(seconds: 95),
    );
    expect(container.read(pluginSettingsProvider).scanError, isNull);

    final vital = (await _stage(
      'Vital catalog lookup',
      container
          .read(audioPluginProvider.notifier)
          .getBrowserEntries(
            plugin_api.KarbeatPluginType.generator,
            query: 'Vital',
          ),
    )).singleWhere((entry) => entry.name == 'Vital');
    expect(vital.binaryType.label, 'VST3');
    favoriteKey = vital.favoriteKey;

    await tester.tap(find.byTooltip('Close settings'));
    await _stage(
      'close settings',
      _pumpUntil(
        tester,
        () => find.text('Add New Track').evaluate().isNotEmpty,
      ),
    );
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
      'Vital',
    );
    await _stage('filter generator browser', tester.pump());
    expect(find.text('VST3'), findsOneWidget);
    if (!container
        .read(audioPluginProvider)
        .requireValue
        .favoriteKeys
        .contains(vital.favoriteKey)) {
      await tester.tap(
        find.byKey(ValueKey('plugin-favorite-${vital.favoriteKey}')),
      );
      await _stage(
        'favorite Vital',
        _pumpUntil(
          tester,
          () => container
              .read(audioPluginProvider)
              .requireValue
              .favoriteKeys
              .contains(vital.favoriteKey),
        ),
      );
      addedFavorite = true;
    }
    await tester.tap(
      find.byKey(ValueKey('plugin-browser-${vital.favoriteKey}')),
    );
    await _stage('select Vital', tester.pump());
    final existingTrackIds = container
        .read(projectProvider)
        .requireValue
        .tracks
        .keys
        .toSet();
    await tester.tap(find.byKey(const ValueKey('add-selected-plugin')));
    final responsiveFrames = await _stage(
      'responsive Vital track creation',
      _pumpUntilResponsive(
        tester,
        () =>
            container
                .read(projectProvider)
                .value
                ?.tracks
                .values
                .any(
                  (track) =>
                      track.name == 'Vital' &&
                      !existingTrackIds.contains(track.id),
                ) ??
            false,
        timeout: const Duration(seconds: 30),
      ),
      timeout: const Duration(seconds: 35),
    );
    expect(
      responsiveFrames,
      greaterThanOrEqualTo(2),
      reason: 'Flutter must keep rendering while Vital is prepared',
    );

    final track = container
        .read(projectProvider)
        .requireValue
        .tracks
        .values
        .singleWhere(
          (track) =>
              track.name == 'Vital' && !existingTrackIds.contains(track.id),
        );
    createdTrackId = track.id;
    expect(track.generatorId, isNotNull);
    final target = plugin_api.UiPluginTarget.generator(track.generatorId!);
    createdTarget = target;

    final capabilities = await _stage(
      'Vital capability query',
      external_plugin_api.externalPluginCapabilities(
        ctx: context,
        target: target,
      ),
    );
    expect(capabilities.editor, isTrue);
    await _stage(
      'open Vital editor',
      external_plugin_api.openExternalPluginEditor(
        ctx: context,
        target: target,
      ),
    );

    var flutterFrameCompleted = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      flutterFrameCompleted = true;
    });
    await _stage('Flutter frame with Vital editor open', tester.pump());
    expect(flutterFrameCompleted, isTrue);
    expect(find.text('Tracks'), findsWidgets);

    final parameters = await _stage(
      'Vital parameter query',
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
        ? parameter.value + 0.01
        : parameter.value - 0.01;
    expect(changedValue, inInclusiveRange(0.0, 1.0));
    expect(changedValue, isNot(closeTo(parameter.value, 0.000001)));

    await _stage(
      'subscribe Vital telemetry',
      plugin_api.setPluginTelemetrySubs(
        ctx: context,
        target: target,
        buffers: const [],
        active: true,
      ),
    );
    await _stage(
      'initial Vital telemetry',
      _pumpUntil(tester, () {
        final snapshot = plugin_api.getPluginSnapshotTelemetrySync(
          ctx: context,
          target: target,
        );
        return snapshot?.parameters.any((entry) => entry.$1 == parameter.id) ??
            false;
      }),
    );
    await _stage(
      'change Vital parameter',
      external_plugin_api.setExternalPluginParameter(
        ctx: context,
        target: target,
        parameter: parameter.id,
        value: changedValue,
      ),
    );
    await _stage(
      'changed Vital telemetry',
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
      'subscribe mixer telemetry',
      mixer_api.setMixerTelemetrySubs(ctx: context, active: true),
    );
    await _stage(
      'start Vital preview note',
      audio_api.playPreviewNote(
        ctx: context,
        trackId: track.id,
        noteKey: 60,
        velocity: 100,
        isOn: true,
      ),
    );
    double magnitude = 0;
    await _stage(
      'nonzero Vital audio',
      _pumpUntil(tester, () {
        final snapshot = mixer_api.getMixerTelemetrySync(ctx: context);
        magnitude = snapshot.tracks[track.id]?.magnitude ?? 0;
        return magnitude.isFinite && magnitude > 0.000001;
      }, timeout: const Duration(seconds: 10)),
      timeout: const Duration(seconds: 15),
    );
    expect(magnitude, greaterThan(0.000001));
    await _stage(
      'stop Vital preview note',
      audio_api.playPreviewNote(
        ctx: context,
        trackId: track.id,
        noteKey: 60,
        velocity: 0,
        isOn: false,
      ),
    );

    await _stage(
      'close Vital editor',
      external_plugin_api.closeExternalPluginEditor(
        ctx: context,
        target: target,
      ),
    );
    await _stage(
      'repeat Vital editor close',
      external_plugin_api.closeExternalPluginEditor(
        ctx: context,
        target: target,
      ),
    );
    await _stage(
      'reopen Vital editor',
      external_plugin_api.openExternalPluginEditor(
        ctx: context,
        target: target,
      ),
    );
    await _stage('Flutter frame with reopened Vital editor', tester.pump());

    await _stage(
      'delete track with open Vital editor',
      container
          .read(trackListStateProvider.notifier)
          .deleteTrack(trackId: track.id),
    );
    createdTrackId = null;
    await _pumpUntil(
      tester,
      () => !container
          .read(projectProvider)
          .requireValue
          .tracks
          .containsKey(track.id),
    );
    expect(
      await _stage(
        'deleted Vital descriptor lookup',
        external_plugin_api.externalPluginDescriptor(
          ctx: context,
          target: target,
        ),
      ),
      isNull,
    );
    await _pumpUntil(
      tester,
      () =>
          plugin_api.getPluginSnapshotTelemetrySync(
            ctx: context,
            target: target,
          ) ==
          null,
    );
    createdTarget = null;

    final errors = notifications.where(
      (event) => event.type == UserNotificationType.error,
    );
    expect(errors, isEmpty);
    expect(
      notifications.where(
        (event) => event.message.toLowerCase().contains('timeout'),
      ),
      isEmpty,
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

Future<int> _pumpUntilResponsive(
  WidgetTester tester,
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 20),
  Duration maximumPumpLatency = const Duration(seconds: 2),
}) async {
  final deadline = DateTime.now().add(timeout);
  var frames = 0;
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
        'while preparing Vital',
      );
    }
    frames += 1;
  }
  return frames;
}
