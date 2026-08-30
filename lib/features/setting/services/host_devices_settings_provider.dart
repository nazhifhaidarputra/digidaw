import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/notification_provider.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/features/setting/models/host_devices_settings_state.dart';
import 'package:karbeat/features/setting/services/audio_discovery_service.dart';
import 'package:karbeat/features/setting/services/audio_output_preferences_service.dart';
import 'package:karbeat/src/rust/api/audio_settings.dart';
import 'package:karbeat/src/rust/api/project.dart';

final audioDiscoveryServiceProvider = Provider<AudioDiscoveryService>((ref) {
  return AudioDiscoveryService();
});

final audioOutputPreferencesServiceProvider =
    Provider<AudioOutputPreferencesService>((ref) {
      return AudioOutputPreferencesService();
    });

class HostDevicesSettingsNotifier extends Notifier<HostDevicesSettingsState> {
  bool _initializationStarted = false;
  int _deviceRequestGeneration = 0;
  DawContext? _dawContext;

  @override
  HostDevicesSettingsState build() => const HostDevicesSettingsState();

  Future<Result<void>> initialize([DawContext? context]) async {
    if (_initializationStarted) return Result.ok(null);
    _initializationStarted = true;
    _dawContext = context;
    if (context != null) {
      final preferences = await ref
          .read(audioOutputPreferencesServiceProvider)
          .load();
      if (preferences case Error<AudioOutputPreferences>(error: final error)) {
        _initializationStarted = false;
        return ref.notifyErrorResult(
          error,
          title: 'Could not load output settings',
        );
      }
      state = state.copyWith(
        selectedHostName: preferences.ok().hostName,
        selectedOutputDeviceId: preferences.ok().deviceId,
      );
    }
    state = state.copyWith(isLoadingHosts: true, discoveryError: null);
    final hosts = await ref
        .read(audioDiscoveryServiceProvider)
        .listOutputHosts();
    if (hosts case Error<IList<UiAudioHostInfo>>(error: final error)) {
      _initializationStarted = false;
      state = state.copyWith(
        isLoadingHosts: false,
        discoveryError: error.toString(),
      );
      return ref.notifyErrorResult(
        error,
        title: 'Could not discover audio hosts',
      );
    }
    var fallbackReason = state.fallbackReason;
    if (state.selectedHostName != null &&
        !hosts.ok().any((host) => host.hostName == state.selectedHostName)) {
      fallbackReason = 'The saved audio host is unavailable.';
      state = state.copyWith(
        selectedHostName: null,
        selectedOutputDeviceId: null,
      );
    }
    state = state.copyWith(
      availableHosts: hosts.ok(),
      isLoadingHosts: false,
      isInitialized: true,
      fallbackReason: fallbackReason,
    );
    final loadedDevices = await reloadOutputDevices();
    if (loadedDevices.isErr()) return loadedDevices;
    if (state.selectedOutputDeviceId != null &&
        !state.availableOutputDevices.any(
          (device) => device.deviceId == state.selectedOutputDeviceId,
        )) {
      fallbackReason = 'The saved output device is unavailable.';
      state = state.copyWith(
        selectedOutputDeviceId: null,
        fallbackReason: fallbackReason,
      );
    }
    if (fallbackReason != null) {
      ref
          .read(notificationProvider.notifier)
          .warn(
            '$fallbackReason Using the system default output.',
            title: 'Audio output fallback',
          );
    }
    return context == null ? Result.ok(null) : _applySelection();
  }

  Future<Result<void>> selectHost(String? hostName) async {
    final previousState = state;
    state = state.copyWith(
      selectedHostName: hostName,
      selectedOutputDeviceId: null,
    );
    final loaded = await reloadOutputDevices();
    if (loaded.isErr()) {
      state = previousState;
      return loaded;
    }
    return _applySelection(rollbackState: previousState);
  }

  Future<Result<void>> selectOutputDevice(String? deviceId) async {
    final previousState = state;
    state = state.copyWith(selectedOutputDeviceId: deviceId);
    return _applySelection(rollbackState: previousState);
  }

  Future<Result<void>> reloadOutputDevices() async {
    final generation = ++_deviceRequestGeneration;
    final hostName = state.selectedHostName;
    state = state.copyWith(
      isLoadingOutputDevices: true,
      discoveryError: null,
      availableOutputDevices: const IListConst<UiOutputDeviceInfo>([]),
    );
    final devices = await ref
        .read(audioDiscoveryServiceProvider)
        .listOutputDevices(hostName);
    if (generation != _deviceRequestGeneration) return Result.ok(null);
    if (devices case Error<IList<UiOutputDeviceInfo>>(error: final error)) {
      state = state.copyWith(
        isLoadingOutputDevices: false,
        discoveryError: error.toString(),
      );
      return ref.notifyErrorResult(
        error,
        title: 'Could not discover output devices',
      );
    }
    state = state.copyWith(
      availableOutputDevices: devices.ok(),
      isLoadingOutputDevices: false,
    );
    return Result.ok(null);
  }

  Future<Result<void>> _applySelection({
    HostDevicesSettingsState? rollbackState,
  }) async {
    final context = _dawContext;
    if (context == null) return Result.ok(null);
    state = state.copyWith(isApplyingSelection: true);
    final applied = await ref
        .read(audioDiscoveryServiceProvider)
        .applyOutputSelection(
          context,
          state.selectedHostName,
          state.selectedOutputDeviceId,
        );
    if (applied case Error<UiAudioRuntimeSettings>(error: final error)) {
      state =
          rollbackState?.copyWith(isApplyingSelection: false) ??
          state.copyWith(isApplyingSelection: false);
      return ref.notifyErrorResult(
        error,
        title: 'Could not change audio output',
      );
    }
    state = state.copyWith(
      runtimeSettings: applied.ok(),
      isApplyingSelection: false,
    );
    final saved = await ref.read(audioOutputPreferencesServiceProvider).save((
      hostName: state.selectedHostName,
      deviceId: state.selectedOutputDeviceId,
    ));
    if (saved case Error<void>(error: final error)) {
      return ref.notifyErrorResult(
        error,
        title: 'Audio output changed but not saved',
      );
    }
    return Result.ok(null);
  }
}

final hostDevicesSettingsProvider =
    NotifierProvider<HostDevicesSettingsNotifier, HostDevicesSettingsState>(
      HostDevicesSettingsNotifier.new,
    );
