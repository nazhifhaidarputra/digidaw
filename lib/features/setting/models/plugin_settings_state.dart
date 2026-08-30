import 'package:freezed_annotation/freezed_annotation.dart';

part 'plugin_settings_state.freezed.dart';

@freezed
abstract class PluginSettingsState with _$PluginSettingsState {
  const factory PluginSettingsState({
    @Default(false) bool thirdPartyHostingAvailable,
    @Default(
      'Third-party plugin scanning is unavailable until a plugin host is ready.',
    )
    String unavailableReason,
  }) = _PluginSettingsState;
}
