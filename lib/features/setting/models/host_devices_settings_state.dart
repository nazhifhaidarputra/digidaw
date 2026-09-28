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
    String? selectedHostName,
    String? selectedOutputDeviceId,
    @Default(false) bool isLoadingHosts,
    @Default(false) bool isLoadingOutputDevices,
    @Default(false) bool isApplyingSelection,
    @Default(false) bool isInitialized,
    String? discoveryError,
    String? fallbackReason,
    UiAudioRuntimeSettings? runtimeSettings,
  }) = _HostDevicesSettingsState;
}
