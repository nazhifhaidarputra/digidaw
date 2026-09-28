import 'dart:async';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/notification_provider.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/core/utils/logger.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/features/plugins/services/audio_plugins_service.dart';
import 'package:karbeat/features/setting/models/plugin_settings_state.dart';
import 'package:karbeat/features/setting/services/external_plugin_service.dart';
import 'package:karbeat/src/rust/api/external_plugins.dart';

class PluginSettingsNotifier extends Notifier<PluginSettingsState> {
  StreamSubscription<UiPluginScanEvent>? _scanSubscription;
  bool _initializationStarted = false;

  @override
  PluginSettingsState build() {
    ref.onDispose(() => _scanSubscription?.cancel());
    return const PluginSettingsState();
  }

  Future<Result<void>> initialize() async {
    if (state.isInitialized || _initializationStarted) return Result.ok(null);
    _initializationStarted = true;
    final service = ref.read(externalPluginServiceProvider);
    final results = await (
      service.defaultPaths(),
      service.loadSettings(),
      service.refreshCatalog(ref.read(projectProvider.notifier).dawContext),
    ).wait;
    if (results.$1 case Error<List<String>>(error: final error)) {
      return _initializationFailed(error);
    }
    if (results.$2 case Error<UiPluginScanSettings>(error: final error)) {
      return _initializationFailed(error);
    }
    if (results.$3 case Error<List<UiExternalPluginEntry>>(
      error: final error,
    )) {
      return _initializationFailed(error);
    }
    final settings = results.$2.ok();
    state = state.copyWith(
      isInitialized: true,
      defaultDirectories: results.$1.ok().toIList(),
      directories: settings.directories.toIList(),
      timeoutSeconds: settings.timeoutSeconds,
      externalPlugins: results.$3.ok().toIList(),
    );
    return Result.ok(null);
  }

  Result<void> _initializationFailed(Exception error) {
    _initializationStarted = false;
    AppLogger.error('Failed to initialize plugin settings: $error');
    return ref.notifyErrorResult(
      error,
      title: 'Could not initialize plugin settings',
    );
  }

  Future<Result<void>> chooseDirectory() async {
    if (state.isSaving || state.isScanning) return Result.ok(null);
    final selected = await ref
        .read(externalPluginServiceProvider)
        .chooseDirectory();
    if (selected case Error<String?>(error: final error)) {
      return ref.notifyErrorResult(
        error,
        title: 'Could not choose plugin folder',
      );
    }
    final directory = selected.ok();
    if (directory == null ||
        state.directories.contains(directory) ||
        state.defaultDirectories.contains(directory)) {
      return Result.ok(null);
    }
    return _persistSettings(
      state.directories.add(directory),
      state.timeoutSeconds,
    );
  }

  Future<Result<void>> removeDirectory(String directory) {
    if (state.isSaving || state.isScanning) {
      return Future.value(Result.ok(null));
    }
    return _persistSettings(
      state.directories.remove(directory),
      state.timeoutSeconds,
    );
  }

  Future<Result<void>> setTimeoutSeconds(int timeoutSeconds) {
    if (state.isSaving ||
        state.isScanning ||
        timeoutSeconds == state.timeoutSeconds) {
      return Future.value(Result.ok(null));
    }
    return _persistSettings(state.directories, timeoutSeconds);
  }

  Future<Result<void>> _persistSettings(
    IList<String> directories,
    int timeoutSeconds,
  ) async {
    state = state.copyWith(isSaving: true);
    final saved = await ref
        .read(externalPluginServiceProvider)
        .saveSettings(
          directories: directories.toList(),
          timeoutSeconds: timeoutSeconds,
        );
    if (saved case Error<UiPluginScanSettings>(error: final error)) {
      state = state.copyWith(isSaving: false);
      AppLogger.error('Failed to save plugin scan settings: $error');
      return ref.notifyErrorResult(
        error,
        title: 'Could not save plugin settings',
      );
    }
    final applied = saved.ok();
    state = state.copyWith(
      directories: applied.directories.toIList(),
      timeoutSeconds: applied.timeoutSeconds,
      isSaving: false,
    );
    return Result.ok(null);
  }

  Future<Result<void>> scan({bool retryQuarantined = false}) async {
    if (state.isScanning) {
      return Result.error(Exception('A plugin scan is already running'));
    }
    await _scanSubscription?.cancel();
    state = state.copyWith(
      isScanning: true,
      isCancelling: false,
      scanId: null,
      completed: 0,
      total: 0,
      currentPath: null,
      discoveredCount: 0,
      hasCompletedScan: false,
      lastScanCancelled: false,
      scanError: null,
      failures: const IListConst<UiPluginScanFailure>([]),
    );

    final service = ref.read(externalPluginServiceProvider);
    _scanSubscription = service
        .scan(
          directories: state.directories.toList(),
          timeoutSeconds: state.timeoutSeconds,
          retryQuarantined: retryQuarantined,
        )
        .listen(
          _handleScanEvent,
          onError: (Object error, StackTrace stackTrace) {
            _scanFailed(error, stackTrace);
          },
        );
    return Result.ok(null);
  }

  Future<void> _handleScanEvent(UiPluginScanEvent event) async {
    switch (event) {
      case UiPluginScanEvent_Started(:final id):
        state = state.copyWith(scanId: id);
      case UiPluginScanEvent_Progress(
        :final completed,
        :final total,
        :final discovered,
        :final path,
        :final error,
      ):
        final progressFailures = error == null
            ? state.failures
            : state.failures.add(
                UiPluginScanFailure(path: path, reason: error),
              );
        state = state.copyWith(
          completed: completed,
          total: total,
          discoveredCount: discovered,
          currentPath: path,
          failures: progressFailures,
        );
      case UiPluginScanEvent_Finished(
        :final plugins,
        :final failures,
        :final cancelled,
      ):
        final refreshed = await ref
            .read(externalPluginServiceProvider)
            .refreshCatalog(ref.read(projectProvider.notifier).dawContext);
        if (refreshed case Error<List<UiExternalPluginEntry>>(
          error: final error,
        )) {
          _scanFailed(error, StackTrace.current);
          return;
        }
        final catalogResult = await ref
            .read(audioPluginProvider.notifier)
            .refreshCatalog();
        if (catalogResult case Error<void>(error: final error)) {
          _scanFailed(error, StackTrace.current);
          return;
        }
        state = state.copyWith(
          isScanning: false,
          isCancelling: false,
          scanId: null,
          currentPath: null,
          discoveredCount: plugins.length,
          hasCompletedScan: true,
          lastScanCancelled: cancelled,
          failures: failures.toIList(),
          externalPlugins: refreshed.ok().toIList(),
        );
      case UiPluginScanEvent_Failed(:final message):
        _scanFailed(Exception(message), StackTrace.current);
    }
  }

  void _scanFailed(Object error, StackTrace stackTrace) {
    state = state.copyWith(
      isScanning: false,
      isCancelling: false,
      scanId: null,
      currentPath: null,
      scanError: error.toString(),
    );
    AppLogger.error(
      'External plugin scan failed',
      error: error,
      stackTrace: stackTrace,
    );
    ref
        .read(notificationProvider.notifier)
        .error(error, title: 'Plugin scan failed', stackTrace: stackTrace);
  }

  Future<Result<void>> cancelScan() async {
    final scanId = state.scanId;
    if (!state.isScanning || scanId == null || state.isCancelling) {
      return Result.ok(null);
    }
    state = state.copyWith(isCancelling: true);
    final cancelled = await ref
        .read(externalPluginServiceProvider)
        .cancel(scanId);
    if (cancelled case Error<bool>(error: final error)) {
      state = state.copyWith(isCancelling: false);
      return ref.notifyErrorResult(
        error,
        title: 'Could not cancel plugin scan',
      );
    }
    if (!cancelled.ok()) {
      state = state.copyWith(isCancelling: false);
      return Result.error(Exception('Plugin scan is no longer active'));
    }
    return Result.ok(null);
  }

  Future<Result<void>> retryFailures() => scan(retryQuarantined: true);
}

final pluginSettingsProvider =
    NotifierProvider<PluginSettingsNotifier, PluginSettingsState>(
      PluginSettingsNotifier.new,
    );
