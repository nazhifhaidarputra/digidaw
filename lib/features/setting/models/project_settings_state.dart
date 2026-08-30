import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:karbeat/src/rust/api/project.dart';

part 'project_settings_state.freezed.dart';

@freezed
abstract class ProjectSettingsState with _$ProjectSettingsState {
  const factory ProjectSettingsState({
    UiProjectMetadata? metadata,
    @Default(false) bool hasProject,
  }) = _ProjectSettingsState;
}
