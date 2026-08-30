import 'package:freezed_annotation/freezed_annotation.dart';

part 'general_settings_state.freezed.dart';

@freezed
abstract class GeneralSettingsState with _$GeneralSettingsState {
  const factory GeneralSettingsState({
    @Default(100) int maxHistoryEntries,
    @Default(false) bool isApplyingHistoryLimit,
    @Default(false) bool isInitialized,
  }) = _GeneralSettingsState;
}
