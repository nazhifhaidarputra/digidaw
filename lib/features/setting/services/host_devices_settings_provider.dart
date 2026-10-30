import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/notification_provider.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/features/setting/models/host_devices_settings_state.dart';
import 'package:karbeat/features/setting/services/audio_discovery_service.dart';
import 'package:karbeat/features/setting/services/audio_input_preferences_service.dart';
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

final audioInputPreferencesServiceProvider =
    Provider<AudioInputPreferencesService>((ref) {
      return AudioInputPreferencesService();
    });

class HostDevicesSettingsNotifier extends Notifier<HostDevicesSettingsState> {
  bool _initializationStarted = false;
  int _deviceRequestGeneration = 0;
  int _inputRequestGeneration = 0;
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
      final input = await ref.read(audioInputPreferencesServiceProvider).load();
      if (input case Ok(value: final input)) {
        state = state.copyWith(
          inputEnabled: input.enabled,
          selectedInputDeviceId: input.deviceId,
        );
      } else {
        ref.notifyError(input.err(), title: 'Could not load input settings');
      }
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
    await reloadInputDevices();
    _dropMissingInputDevice();
    if (context == null) return Result.ok(null);
    final applied = await _applySelection();
    if (applied.isErr()) return applied;
    return _applyInputSelection();
  }

  /// Turns the device input on or off.
  Future<Result<void>> setInputEnabled(bool enabled) async {
    final previousState = state;
    state = state.copyWith(inputEnabled: enabled);
    return _applyInputSelection(rollbackState: previousState);
  }

  /// Selects the input device; `null` follows the system default.
  Future<Result<void>> selectInputDevice(String? deviceId) async {
    final previousState = state;
    state = state.copyWith(selectedInputDeviceId: deviceId);
    return _applyInputSelection(rollbackState: previousState);
  }

  /// Records that arming a track turned the input on, so it stays on next
  /// time.
  Future<void> inputEnabledForRecording() async {
    state = state.copyWith(inputEnabled: true);
    final saved = await ref.read(audioInputPreferencesServiceProvider).save((
      enabled: true,
      deviceId: state.selectedInputDeviceId,
    ));
    if (saved case Error<void>(error: final error)) {
      ref.notifyError(error, title: 'Audio input turned on but not saved');
    }
  }

  /// Lists the input devices of the selected host. A failure leaves output
  /// settings usable, so it is shown on the page rather than returned.
  Future<void> reloadInputDevices() async {
    final generation = ++_inputRequestGeneration;
    state = state.copyWith(
      isLoadingInputDevices: true,
      inputDiscoveryError: null,
      availableInputDevices: const IListConst<UiInputDeviceInfo>([]),
    );
    final devices = await ref
        .read(audioDiscoveryServiceProvider)
        .listInputDevices(state.selectedHostName);
    if (generation != _inputRequestGeneration) return;
    switch (devices) {
      case Ok(:final value):
        state = state.copyWith(
          availableInputDevices: value,
          isLoadingInputDevices: false,
        );
      case Error(:final error):
        state = state.copyWith(
          isLoadingInputDevices: false,
          inputDiscoveryError: error.toString(),
        );
    }
  }

  /// Falls back to the system default input when the selected one is gone.
  void _dropMissingInputDevice() {
    final selected = state.selectedInputDeviceId;
    if (selected == null || state.availableInputDevices.isEmpty) return;
    if (state.availableInputDevices.any((d) => d.deviceId == selected)) return;
    state = state.copyWith(selectedInputDeviceId: null);
    ref
        .read(notificationProvider.notifier)
        .warn(
          'The saved input device is unavailable. Using the system default input.',
          title: 'Audio input fallback',
        );
  }

  Future<Result<void>> _applyInputSelection({
    HostDevicesSettingsState? rollbackState,
  }) async {
    final context = _dawContext;
    if (context == null) return Result.ok(null);
    state = state.copyWith(isApplyingInput: true);
    final applied = await ref
        .read(audioDiscoveryServiceProvider)
        .applyInputSelection(
          context,
          state.inputEnabled,
          state.selectedInputDeviceId,
        );
    if (applied case Error<UiAudioRuntimeSettings>(error: final error)) {
      state =
          rollbackState?.copyWith(isApplyingInput: false) ??
          state.copyWith(isApplyingInput: false);
      return ref.notifyErrorResult(
        error,
        title: 'Could not change audio input',
      );
    }
    state = state.copyWith(
      runtimeSettings: applied.ok(),
      isApplyingInput: false,
    );
    final saved = await ref.read(audioInputPreferencesServiceProvider).save((
      enabled: state.inputEnabled,
      deviceId: state.selectedInputDeviceId,
    ));
    if (saved case Error<void>(error: final error)) {
      return ref.notifyErrorResult(
        error,
        title: 'Audio input changed but not saved',
      );
    }
    return Result.ok(null);
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
    final applied = await _applySelection(rollbackState: previousState);
    if (applied.isErr()) return applied;
    // The input opens on the output's host, so its devices change with it.
    await reloadInputDevices();
    if (state.selectedInputDeviceId != null &&
        !state.availableInputDevices.any(
          (device) => device.deviceId == state.selectedInputDeviceId,
        )) {
      state = state.copyWith(selectedInputDeviceId: null);
      return _applyInputSelection();
    }
    return Result.ok(null);
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
