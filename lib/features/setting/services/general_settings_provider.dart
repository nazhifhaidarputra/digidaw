import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/notification_provider.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/features/setting/models/general_settings_state.dart';
import 'package:karbeat/features/setting/services/settings_service.dart';
import 'package:karbeat/src/rust/api/mitigation.dart';
import 'package:karbeat/src/rust/api/project.dart';
import 'package:karbeat/src/rust/api/settings.dart';

final settingsServiceProvider = Provider<SettingsService>((ref) {
  return SettingsService();
});

class GeneralSettingsNotifier extends Notifier<GeneralSettingsState> {
  bool _initializationStarted = false;
  DawContext? _dawContext;

  @override
  GeneralSettingsState build() => const GeneralSettingsState();

  Future<Result<void>> initialize(DawContext context) async {
    if (_initializationStarted) return Result.ok(null);
    _initializationStarted = true;
    _dawContext = context;
    state = state.copyWith(isApplyingHistoryLimit: true);

    final service = ref.read(settingsServiceProvider);
    final general = await service.loadGeneralSettings();
    if (general case Ok(value: final general)) {
      await _publishStored(general);
    }
    final loaded = await service.loadHistoryLimit();
    if (loaded case Error<int>(error: final error)) {
      _initializationStarted = false;
      state = state.copyWith(
        isApplyingHistoryLimit: false,
        isInitialized: false,
      );
      return ref.notifyErrorResult(error, title: 'Could not load settings');
    }

    final applied = await service.applyHistoryLimit(context, loaded.ok());
    if (applied case Error<int>(error: final error)) {
      _initializationStarted = false;
      state = state.copyWith(
        isApplyingHistoryLimit: false,
        isInitialized: false,
      );
      return ref.notifyErrorResult(
        error,
        title: 'Could not apply history limit',
      );
    }

    state = state.copyWith(
      maxHistoryEntries: applied.ok(),
      isApplyingHistoryLimit: false,
      isInitialized: true,
    );
    return _initializeAutoSave(context);
  }

  Future<Result<void>> _initializeAutoSave(DawContext context) async {
    state = state.copyWith(isApplyingAutoSave: true);
    final service = ref.read(settingsServiceProvider);
    final loaded = await service.loadAutoSaveSettings();
    if (loaded case Error<UiAutoSaveSettings>(error: final error)) {
      state = state.copyWith(isApplyingAutoSave: false);
      return ref.notifyErrorResult(
        error,
        title: 'Could not load auto save settings',
      );
    }

    final applied = await service.applyAutoSaveSettings(context, loaded.ok());
    if (applied case Error<UiAutoSaveSettings>(error: final error)) {
      state = state.copyWith(isApplyingAutoSave: false);
      return ref.notifyErrorResult(
        error,
        title: 'Could not apply auto save settings',
      );
    }

    _publishAutoSave(applied.ok());
    return Result.ok(null);
  }

  Future<Result<void>> setAutoSaveEnabled(bool enabled) {
    return _updateAutoSave(
      UiAutoSaveSettings(
        isEnabled: enabled,
        intervalSeconds: state.autoSaveIntervalSeconds,
      ),
    );
  }

  Future<Result<void>> setAutoSaveInterval(int seconds) {
    return _updateAutoSave(
      UiAutoSaveSettings(
        isEnabled: state.autoSaveEnabled,
        intervalSeconds: seconds,
      ),
    );
  }

  Future<Result<void>> _updateAutoSave(UiAutoSaveSettings settings) async {
    final context = _dawContext;
    if (context == null) {
      return ref.notifyErrorResult(
        StateError('General settings have not been initialized'),
        title: 'Could not update auto save',
      );
    }
    if (state.isApplyingAutoSave) {
      return Result.error(Exception('Auto save update is already running'));
    }

    state = state.copyWith(isApplyingAutoSave: true);
    final service = ref.read(settingsServiceProvider);
    final applied = await service.applyAutoSaveSettings(context, settings);
    if (applied case Error<UiAutoSaveSettings>(error: final error)) {
      state = state.copyWith(isApplyingAutoSave: false);
      return ref.notifyErrorResult(error, title: 'Could not update auto save');
    }

    _publishAutoSave(applied.ok());
    final saved = await service.saveAutoSaveSettings(applied.ok());
    if (saved case Error<void>(error: final error)) {
      return ref.notifyErrorResult(
        error,
        title: 'Auto save applied but not saved',
      );
    }
    return Result.ok(null);
  }

  void _publishAutoSave(UiAutoSaveSettings settings) {
    state = state.copyWith(
      autoSaveEnabled: settings.isEnabled,
      autoSaveIntervalSeconds: settings.intervalSeconds,
      isApplyingAutoSave: false,
    );
  }

  Future<Result<void>> setHistoryLimit(int limit) async {
    final context = _dawContext;
    if (context == null) {
      return ref.notifyErrorResult(
        StateError('General settings have not been initialized'),
        title: 'Could not update history limit',
      );
    }
    if (state.isApplyingHistoryLimit) {
      return Result.error(Exception('History limit update is already running'));
    }

    state = state.copyWith(isApplyingHistoryLimit: true);
    final service = ref.read(settingsServiceProvider);
    final applied = await service.applyHistoryLimit(context, limit);
    if (applied case Error<int>(error: final error)) {
      state = state.copyWith(isApplyingHistoryLimit: false);
      return ref.notifyErrorResult(
        error,
        title: 'Could not update history limit',
      );
    }

    final appliedLimit = applied.ok();
    state = state.copyWith(
      maxHistoryEntries: appliedLimit,
      isApplyingHistoryLimit: false,
    );
    final saved = await service.saveHistoryLimit(appliedLimit);
    if (saved case Error<void>(error: final error)) {
      return ref.notifyErrorResult(
        error,
        title: 'History limit applied but not saved',
      );
    }
    return Result.ok(null);
  }

  /// Asks for [kind]'s folder and saves it; cancelling keeps the current one.
  Future<Result<void>> chooseDefaultFolder(DefaultFolder kind) async {
    final service = ref.read(settingsServiceProvider);
    final picked = await service.pickFolder(
      dialogTitle: switch (kind) {
        DefaultFolder.project => 'Choose default project folder',
        DefaultFolder.export => 'Choose default export folder',
      },
      initialDirectory: state.usableFolder(kind),
    );
    if (picked case Error<String?>(error: final error)) {
      return ref.notifyErrorResult(error, title: 'Could not choose a folder');
    }
    final folder = picked.ok();
    if (folder == null) return Result.ok(null);
    return setDefaultFolder(kind, folder);
  }

  /// Saves [folder] as [kind]'s folder; null clears it.
  Future<Result<void>> setDefaultFolder(
    DefaultFolder kind,
    String? folder,
  ) async {
    if (state.isSavingFolder) {
      return Result.error(Exception('A folder is already being saved'));
    }
    state = state.copyWith(isSavingFolder: true);
    final service = ref.read(settingsServiceProvider);
    final saved = await switch (kind) {
      DefaultFolder.project => service.saveDefaultProjectFolder(folder),
      DefaultFolder.export => service.saveDefaultExportFolder(folder),
    };
    state = state.copyWith(isSavingFolder: false);
    switch (saved) {
      case Ok(value: final settings):
        await _publishStored(settings);
        return Result.ok(null);
      case Error(:final error):
        return ref.notifyErrorResult(error, title: 'Could not save the folder');
    }
  }

  /// Shows or hides the recent projects in the project menu.
  Future<Result<void>> setShowRecentProjects(bool visible) async {
    final previous = state.showRecentProjects;
    state = state.copyWith(showRecentProjects: visible);
    final saved = await ref
        .read(settingsServiceProvider)
        .saveShowRecentProjects(visible);
    if (saved case Error(:final error)) {
      state = state.copyWith(showRecentProjects: previous);
      return ref.notifyErrorResult(
        error,
        title: 'Could not save the recent projects setting',
      );
    }
    return Result.ok(null);
  }

  /// Publishes the stored settings that the engine does not apply: the
  /// default folders, whether they still exist, and the recent projects
  /// option.
  Future<void> _publishStored(UiGeneralSettings settings) async {
    final service = ref.read(settingsServiceProvider);
    final folders = {
      DefaultFolder.project: settings.defaultProjectFolder,
      DefaultFolder.export: settings.defaultExportFolder,
    };
    final missing = <DefaultFolder>{
      for (final MapEntry(key: kind, value: folder) in folders.entries)
        if (folder != null && !await service.folderExists(folder)) kind,
    };
    state = state.copyWith(
      defaultProjectFolder: settings.defaultProjectFolder,
      defaultExportFolder: settings.defaultExportFolder,
      missingFolders: missing.lock,
      showRecentProjects: settings.showRecentProjects,
    );
  }
}

final generalSettingsProvider =
    NotifierProvider<GeneralSettingsNotifier, GeneralSettingsState>(
      GeneralSettingsNotifier.new,
    );
