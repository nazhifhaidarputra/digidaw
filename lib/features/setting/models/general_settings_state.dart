import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'general_settings_state.freezed.dart';

/// A folder the file dialogs start in.
enum DefaultFolder {
  /// Where projects are saved and opened from.
  project,

  /// Where audio exports go.
  export,
}

@freezed
abstract class GeneralSettingsState with _$GeneralSettingsState {
  const GeneralSettingsState._();

  const factory GeneralSettingsState({
    @Default(100) int maxHistoryEntries,
    @Default(false) bool isApplyingHistoryLimit,
    @Default(true) bool autoSaveEnabled,
    @Default(300) int autoSaveIntervalSeconds,
    @Default(false) bool isApplyingAutoSave,
    @Default(false) bool isInitialized,

    /// Folder project dialogs start in; null lets the dialog choose.
    String? defaultProjectFolder,

    /// Folder exports go to; null asks for one on every export.
    String? defaultExportFolder,

    /// Set folders that no longer exist; the dialogs ignore them.
    @Default(ISetConst<DefaultFolder>({})) ISet<DefaultFolder> missingFolders,
    @Default(false) bool isSavingFolder,

    /// Whether the project menu lists recently opened projects.
    @Default(true) bool showRecentProjects,
  }) = _GeneralSettingsState;

  String? folder(DefaultFolder kind) => switch (kind) {
    DefaultFolder.project => defaultProjectFolder,
    DefaultFolder.export => defaultExportFolder,
  };

  /// [kind]'s folder when it is set and still exists.
  String? usableFolder(DefaultFolder kind) =>
      missingFolders.contains(kind) ? null : folder(kind);
}
