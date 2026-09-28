import 'package:freezed_annotation/freezed_annotation.dart';

part 'info_settings_state.freezed.dart';

@freezed
abstract class InfoSettingsState with _$InfoSettingsState {
  const factory InfoSettingsState({
    @Default(false) bool isLoading,
    String? version,
    String? buildNumber,
    String? errorMessage,
  }) = _InfoSettingsState;
}
