import 'dart:async';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/features/plugins/services/audio_plugins_service.dart';
import 'package:karbeat/features/setting/services/external_plugin_service.dart';
import 'package:karbeat/features/setting/services/plugin_settings_provider.dart';
import 'package:karbeat/src/rust/api/external_plugins.dart';
import 'package:karbeat/src/rust/api/project.dart';
import 'package:mocktail/mocktail.dart';

class _MockDawContext extends Mock implements DawContext {}

class _ProjectNotifier extends ProjectNotifier {
  final DawContext context = _MockDawContext();

  @override
  DawContext get dawContext => context;

  @override
  Future<ApplicationDataStore> build() =>
      Completer<ApplicationDataStore>().future;
}

class _PluginNotifier extends PluginNotifier {
  int refreshCount = 0;

  @override
  Future<PluginState> build() async => const PluginState();

  @override
  Future<Result<void>> refreshCatalog() async {
    refreshCount++;
    return Result.ok(null);
  }
}

class _ExternalService extends ExternalPluginService {
  final events = StreamController<UiPluginScanEvent>.broadcast();
  List<String> savedDirectories = const [];
  int savedTimeout = 30;
  int? cancelledId;
  Exception? saveError;
  bool? retryQuarantinedReceived;

  @override
  Future<Result<String?>> chooseDirectory() async => Result.ok('/custom/vst3');

  @override
  Future<Result<List<String>>> defaultPaths() async =>
      Result.ok(['/usr/lib/vst3']);

  @override
  Future<Result<UiPluginScanSettings>> loadSettings() async => Result.ok(
    const UiPluginScanSettings(directories: [], timeoutSeconds: 30),
  );

  @override
  Future<Result<UiPluginScanSettings>> saveSettings({
    required List<String> directories,
    required int timeoutSeconds,
  }) async {
    if (saveError case final error?) return Result.error(error);
    savedDirectories = directories;
    savedTimeout = timeoutSeconds;
    return Result.ok(
      UiPluginScanSettings(
        directories: directories,
        timeoutSeconds: timeoutSeconds,
      ),
    );
  }

  @override
  Stream<UiPluginScanEvent> scan({
    required List<String> directories,
    required int timeoutSeconds,
    required bool retryQuarantined,
  }) {
    retryQuarantinedReceived = retryQuarantined;
    return events.stream;
  }

  @override
  Future<Result<bool>> cancel(int scanId) async {
    cancelledId = scanId;
    return Result.ok(true);
  }

  @override
  Future<Result<List<UiExternalPluginEntry>>> refreshCatalog(
    DawContext context,
  ) async => Result.ok([_vitalEntry()]);
}

void main() {
  test(
    'persists paths and handles scan progress, cancellation, and refresh',
    () async {
      final service = _ExternalService();
      late _PluginNotifier plugins;
      final container = ProviderContainer(
        overrides: [
          projectProvider.overrideWith(_ProjectNotifier.new),
          externalPluginServiceProvider.overrideWithValue(service),
          audioPluginProvider.overrideWith(() {
            plugins = _PluginNotifier();
            return plugins;
          }),
        ],
      );
      addTearDown(() async {
        await service.events.close();
        container.dispose();
      });
      final notifier = container.read(pluginSettingsProvider.notifier);

      expect((await notifier.initialize()).isOk(), isTrue);
      expect(
        container.read(pluginSettingsProvider).defaultDirectories,
        IList(['/usr/lib/vst3']),
      );
      expect((await notifier.chooseDirectory()).isOk(), isTrue);
      expect(service.savedDirectories, ['/custom/vst3']);
      expect((await notifier.setTimeoutSeconds(60)).isOk(), isTrue);
      expect(service.savedTimeout, 60);

      expect((await notifier.scan()).isOk(), isTrue);
      service.events.add(const UiPluginScanEvent.started(id: 42));
      service.events.add(
        const UiPluginScanEvent.progress(
          completed: 1,
          total: 2,
          discovered: 1,
          path: '/usr/lib/vst3/Vital.vst3',
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(container.read(pluginSettingsProvider).completed, 1);
      expect(container.read(pluginSettingsProvider).discoveredCount, 1);
      expect((await notifier.cancelScan()).isOk(), isTrue);
      expect(service.cancelledId, 42);
      service.events.add(
        UiPluginScanEvent.finished(
          plugins: [_vitalEntry().descriptor],
          failures: const [],
          cancelled: true,
        ),
      );
      for (
        var i = 0;
        i < 20 && container.read(pluginSettingsProvider).isScanning;
        i++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }

      final state = container.read(pluginSettingsProvider);
      expect(state.isScanning, isFalse);
      expect(state.lastScanCancelled, isTrue);
      expect(state.discoveredCount, 1);
      expect(state.externalPlugins.single.descriptor.name, 'Vital');
      expect(plugins.refreshCount, 1);
    },
  );

  test('rolls back a rejected settings write', () async {
    final service = _ExternalService();
    final container = _container(service);
    addTearDown(() async {
      await service.events.close();
      container.dispose();
    });
    final notifier = container.read(pluginSettingsProvider.notifier);
    expect((await notifier.initialize()).isOk(), isTrue);
    service.saveError = Exception('settings rejected');

    expect((await notifier.chooseDirectory()).isErr(), isTrue);
    expect(container.read(pluginSettingsProvider).directories, isEmpty);
    expect(container.read(pluginSettingsProvider).isSaving, isFalse);
  });

  test('failed scan retains the previous catalog and supports retry', () async {
    final service = _ExternalService();
    final container = _container(service);
    addTearDown(() async {
      await service.events.close();
      container.dispose();
    });
    final notifier = container.read(pluginSettingsProvider.notifier);
    expect((await notifier.initialize()).isOk(), isTrue);

    expect((await notifier.retryFailures()).isOk(), isTrue);
    expect(service.retryQuarantinedReceived, isTrue);
    service.events.add(
      const UiPluginScanEvent.failed(message: 'helper unavailable'),
    );
    await Future<void>.delayed(Duration.zero);

    final state = container.read(pluginSettingsProvider);
    expect(state.isScanning, isFalse);
    expect(state.scanError, contains('helper unavailable'));
    expect(state.externalPlugins.single.descriptor.name, 'Vital');
  });
}

ProviderContainer _container(_ExternalService service) => ProviderContainer(
  overrides: [
    projectProvider.overrideWith(_ProjectNotifier.new),
    externalPluginServiceProvider.overrideWithValue(service),
    audioPluginProvider.overrideWith(_PluginNotifier.new),
  ],
);

UiExternalPluginEntry _vitalEntry() => const UiExternalPluginEntry(
  id: 99,
  available: true,
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
