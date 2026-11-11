import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/src/rust/api/mitigation.dart' as mitigation_api;
import 'package:karbeat/src/rust/api/project.dart';
import 'package:karbeat/src/rust/api/settings.dart' as settings_api;
import 'package:karbeat/src/rust/api/simple.dart';

/// Loads, saves and applies the settings on the General page. Rust stores
/// them and replaces stored values the engine would reject with defaults.
class SettingsService {
  static const maxHistoryLimit = 1000;

  static const minAutoSaveIntervalSeconds = 60;
  static const maxAutoSaveIntervalSeconds = 3600;

  Future<Result<settings_api.UiGeneralSettings>> loadGeneralSettings() {
    return attemptAsync(settings_api.loadGeneralSettings);
  }

  Future<Result<int>> loadHistoryLimit() {
    return attemptAsync(
      () async => (await settings_api.loadGeneralSettings()).historyLimit,
    );
  }

  Future<Result<void>> saveHistoryLimit(int limit) {
    return attemptAsync(() => settings_api.saveHistoryLimit(limit: limit));
  }

  Future<Result<int>> applyHistoryLimit(DawContext context, int limit) {
    if (!isValidHistoryLimit(limit)) {
      return Future.value(
        Result.error(
          Exception('History limit must be between 0 and $maxHistoryLimit'),
        ),
      );
    }

    return attemptAsync(() => setHistoryLimit(ctx: context, limit: limit));
  }

  static bool isValidHistoryLimit(int value) {
    return value >= 0 && value <= maxHistoryLimit;
  }

  Future<Result<mitigation_api.UiAutoSaveSettings>> loadAutoSaveSettings() {
    return attemptAsync(
      () async => (await settings_api.loadGeneralSettings()).autoSave,
    );
  }

  Future<Result<void>> saveAutoSaveSettings(
    mitigation_api.UiAutoSaveSettings settings,
  ) {
    return attemptAsync(
      () => settings_api.saveAutoSavePreferences(settings: settings),
    );
  }

  Future<Result<mitigation_api.UiAutoSaveSettings>> applyAutoSaveSettings(
    DawContext context,
    mitigation_api.UiAutoSaveSettings settings,
  ) {
    if (!isValidAutoSaveInterval(settings.intervalSeconds)) {
      return Future.value(
        Result.error(
          Exception(
            'Auto save interval must be between $minAutoSaveIntervalSeconds '
            'and $maxAutoSaveIntervalSeconds seconds',
          ),
        ),
      );
    }

    return attemptAsync(
      () =>
          mitigation_api.setAutoSaveSettings(ctx: context, settings: settings),
    );
  }

  static bool isValidAutoSaveInterval(int seconds) {
    return seconds >= minAutoSaveIntervalSeconds &&
        seconds <= maxAutoSaveIntervalSeconds;
  }

  /// Sets the folder project dialogs start in; null clears it. Rust rejects
  /// a folder that does not exist.
  Future<Result<settings_api.UiGeneralSettings>> saveDefaultProjectFolder(
    String? folder,
  ) {
    return attemptAsync(
      () => settings_api.saveDefaultProjectFolder(folder: folder),
    );
  }

  /// Sets the folder exports go to; null clears it. Rust rejects a folder
  /// that does not exist.
  Future<Result<settings_api.UiGeneralSettings>> saveDefaultExportFolder(
    String? folder,
  ) {
    return attemptAsync(
      () => settings_api.saveDefaultExportFolder(folder: folder),
    );
  }

  /// Shows or hides the recent projects in the project menu.
  Future<Result<settings_api.UiGeneralSettings>> saveShowRecentProjects(
    bool visible,
  ) {
    return attemptAsync(
      () => settings_api.saveShowRecentProjects(visible: visible),
    );
  }

  /// Asks the user for a folder, starting in [initialDirectory] when given.
  Future<Result<String?>> pickFolder({
    required String dialogTitle,
    String? initialDirectory,
  }) {
    return attemptAsync(
      () => FilePicker.getDirectoryPath(
        dialogTitle: dialogTitle,
        initialDirectory: initialDirectory,
      ),
    );
  }

  /// Whether [path] is a folder that exists.
  Future<bool> folderExists(String path) => Directory(path).exists();
}
