import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:karbeat/src/rust/api/audio_settings.dart';

part 'host_devices_settings_state.freezed.dart';

@freezed
abstract class HostDevicesSettingsState with _$HostDevicesSettingsState {
  const factory HostDevicesSettingsState({
    @Default(IListConst<UiAudioHostInfo>([]))
    IList<UiAudioHostInfo> availableHosts,
    @Default(IListConst<UiOutputDeviceInfo>([]))
    IList<UiOutputDeviceInfo> availableOutputDevices,
    @Default(IListConst<UiInputDeviceInfo>([]))
    IList<UiInputDeviceInfo> availableInputDevices,
    String? selectedHostName,
    String? selectedOutputDeviceId,

    /// Whether the device input is open, so tracks can record and monitor it.
    @Default(false) bool inputEnabled,

    /// `null` follows the system default input.
    String? selectedInputDeviceId,
    @Default(false) bool isLoadingInputDevices,
    @Default(false) bool isApplyingInput,
    String? inputDiscoveryError,
    @Default(false) bool isLoadingHosts,
    @Default(false) bool isLoadingOutputDevices,
    @Default(false) bool isApplyingSelection,
    @Default(false) bool isInitialized,
    String? discoveryError,
    String? fallbackReason,
    UiAudioRuntimeSettings? runtimeSettings,
  }) = _HostDevicesSettingsState;
}
