import 'dart:async';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/features/setting/services/audio_discovery_service.dart';
import 'package:karbeat/features/setting/services/audio_output_preferences_service.dart';
import 'package:karbeat/features/setting/services/host_devices_settings_provider.dart';
import 'package:karbeat/src/rust/api/audio_settings.dart';
import 'package:karbeat/src/rust/api/project.dart';
import 'package:mocktail/mocktail.dart';

class _MockDawContext extends Mock implements DawContext {}

class _FakeAudioDiscoveryService extends AudioDiscoveryService {
  final hosts = IList([
    const UiAudioHostInfo(
      hostName: null,
      displayName: 'System default (WASAPI)',
    ),
    const UiAudioHostInfo(hostName: 'ASIO', displayName: 'ASIO'),
  ]);
  final deviceRequests =
      <String?, Completer<Result<IList<UiOutputDeviceInfo>>>>{};
  String? appliedHost;
  String? appliedDevice;
  Exception? applyError;

  @override
  Future<Result<IList<UiAudioHostInfo>>> listOutputHosts() async {
    return Result.ok(hosts);
  }

  @override
  Future<Result<IList<UiOutputDeviceInfo>>> listOutputDevices(
    String? hostName,
  ) {
    return deviceRequests
        .putIfAbsent(hostName, Completer<Result<IList<UiOutputDeviceInfo>>>.new)
        .future;
  }

  @override
  Future<Result<UiAudioRuntimeSettings>> applyOutputSelection(
    DawContext context,
    String? hostName,
    String? deviceId,
  ) async {
    final error = applyError;
    if (error != null) return Result.error(error);
    appliedHost = hostName;
    appliedDevice = deviceId;
    return Result.ok(
      UiAudioRuntimeSettings(
        requestedOutput: UiRequestedOutputConfig(
          host: hostName == null
              ? const UiOutputHostSelection.systemDefault()
              : UiOutputHostSelection.named(name: hostName),
          device: deviceId == null
              ? const UiOutputDeviceSelection.systemDefault()
              : UiOutputDeviceSelection.specific(id: deviceId, name: deviceId),
        ),
        requestedDsp: const UiRequestedDspConfig(
          sampleRate: 48000,
          blockSize: 1024,
        ),
        streamStatus: const UiDeviceStreamStatus.starting(),
      ),
    );
  }
}

class _FakeOutputPreferencesService extends AudioOutputPreferencesService {
  AudioOutputPreferences loaded = (hostName: null, deviceId: null);
  AudioOutputPreferences? saved;

  @override
  Future<Result<AudioOutputPreferences>> load() async => Result.ok(loaded);

  @override
  Future<Result<void>> save(AudioOutputPreferences value) async {
    saved = value;
    return Result.ok(null);
  }
}

IList<UiOutputDeviceInfo> _devices(String name) => IList([
  const UiOutputDeviceInfo(
    deviceId: null,
    displayName: 'System default output',
    isCurrentSystemDefault: true,
  ),
  UiOutputDeviceInfo(
    deviceId: name,
    displayName: name,
    isCurrentSystemDefault: false,
  ),
]);

void main() {
  test('loads typed hosts and system-default output devices', () async {
    final service = _FakeAudioDiscoveryService();
    final container = ProviderContainer(
      overrides: [audioDiscoveryServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);

    final initialization = container
        .read(hostDevicesSettingsProvider.notifier)
        .initialize();
    await Future<void>.delayed(Duration.zero);
    service.deviceRequests[null]!.complete(Result.ok(_devices('Speakers')));
    final result = await initialization;

    expect(result.isOk(), isTrue);
    final state = container.read(hostDevicesSettingsProvider);
    expect(state.availableHosts.first.hostName, isNull);
    expect(state.availableOutputDevices.first.deviceId, isNull);
    expect(state.availableOutputDevices.last.displayName, 'Speakers');
  });

  test('a stale device response cannot overwrite a newer host', () async {
    final service = _FakeAudioDiscoveryService();
    final container = ProviderContainer(
      overrides: [audioDiscoveryServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(hostDevicesSettingsProvider.notifier);

    final initial = notifier.initialize();
    await Future<void>.delayed(Duration.zero);
    final newer = notifier.selectHost('ASIO');
    await Future<void>.delayed(Duration.zero);
    service.deviceRequests['ASIO']!.complete(
      Result.ok(_devices('ASIO Device')),
    );
    expect((await newer).isOk(), isTrue);
    service.deviceRequests[null]!.complete(Result.ok(_devices('Old Device')));
    expect((await initial).isOk(), isTrue);

    final state = container.read(hostDevicesSettingsProvider);
    expect(state.selectedHostName, 'ASIO');
    expect(state.availableOutputDevices.last.displayName, 'ASIO Device');
  });

  test('restores, applies, and persists a specific output selection', () async {
    final service = _FakeAudioDiscoveryService();
    final preferences = _FakeOutputPreferencesService()
      ..loaded = (hostName: 'ASIO', deviceId: 'ASIO Device');
    final container = ProviderContainer(
      overrides: [
        audioDiscoveryServiceProvider.overrideWithValue(service),
        audioOutputPreferencesServiceProvider.overrideWithValue(preferences),
      ],
    );
    addTearDown(container.dispose);

    final initialization = container
        .read(hostDevicesSettingsProvider.notifier)
        .initialize(_MockDawContext());
    await Future<void>.delayed(Duration.zero);
    service.deviceRequests['ASIO']!.complete(
      Result.ok(_devices('ASIO Device')),
    );

    expect((await initialization).isOk(), isTrue);
    expect(service.appliedHost, 'ASIO');
    expect(service.appliedDevice, 'ASIO Device');
    expect(preferences.saved?.hostName, 'ASIO');
    expect(preferences.saved?.deviceId, 'ASIO Device');
  });

  test('missing saved host falls back to explicit system defaults', () async {
    final service = _FakeAudioDiscoveryService();
    final preferences = _FakeOutputPreferencesService()
      ..loaded = (hostName: 'Missing', deviceId: 'Missing Device');
    final container = ProviderContainer(
      overrides: [
        audioDiscoveryServiceProvider.overrideWithValue(service),
        audioOutputPreferencesServiceProvider.overrideWithValue(preferences),
      ],
    );
    addTearDown(container.dispose);

    final initialization = container
        .read(hostDevicesSettingsProvider.notifier)
        .initialize(_MockDawContext());
    await Future<void>.delayed(Duration.zero);
    service.deviceRequests[null]!.complete(Result.ok(_devices('Speakers')));

    expect((await initialization).isOk(), isTrue);
    expect(service.appliedHost, isNull);
    expect(service.appliedDevice, isNull);
    expect(preferences.saved?.hostName, isNull);
    expect(
      container.read(hostDevicesSettingsProvider).fallbackReason,
      isNotNull,
    );
  });

  test('backend rejection restores the previously selected output', () async {
    final service = _FakeAudioDiscoveryService();
    final preferences = _FakeOutputPreferencesService();
    final container = ProviderContainer(
      overrides: [
        audioDiscoveryServiceProvider.overrideWithValue(service),
        audioOutputPreferencesServiceProvider.overrideWithValue(preferences),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(hostDevicesSettingsProvider.notifier);

    final initialization = notifier.initialize(_MockDawContext());
    await Future<void>.delayed(Duration.zero);
    service.deviceRequests[null]!.complete(Result.ok(_devices('Speakers')));
    expect((await initialization).isOk(), isTrue);
    service.applyError = Exception('device failed to open');

    final result = await notifier.selectOutputDevice('Speakers');

    expect(result.isErr(), isTrue);
    expect(
      container.read(hostDevicesSettingsProvider).selectedOutputDeviceId,
      isNull,
    );
  });
}
