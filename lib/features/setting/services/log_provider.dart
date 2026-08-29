import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/notification_provider.dart';
import 'package:karbeat/core/utils/log_models.dart';
import 'package:karbeat/core/utils/logger.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/features/setting/services/log_preferences_service.dart';

final appLogRepositoryProvider = Provider<AppLogRepository>((ref) {
  return AppLogRepository.instance;
});

final logPreferencesServiceProvider = Provider<LogPreferencesService>((ref) {
  return LogPreferencesService();
});

class LogNotifier extends Notifier<AppLogState> {
  StreamSubscription<AppLogEntry>? _subscription;
  bool _initializationStarted = false;

  @override
  AppLogState build() {
    final repository = ref.read(appLogRepositoryProvider);
    _subscription = repository.entriesAdded.listen((entry) {
      state = state.copyWith(entries: repository.snapshot);
    });
    ref.onDispose(() => _subscription?.cancel());
    return AppLogState(entries: repository.snapshot);
  }

  Future<Result<void>> initialize() async {
    if (_initializationStarted) return Result.ok(null);
    _initializationStarted = true;
    final loaded = await ref.read(logPreferencesServiceProvider).load();
    if (loaded case Error<LogPreferences>(error: final error)) {
      _initializationStarted = false;
      return ref.notifyErrorResult(
        error,
        title: 'Could not load logging settings',
      );
    }

    final preferences = loaded.ok();
    final repository = ref.read(appLogRepositoryProvider);
    repository.configureMaximumEntries(preferences.maximumEntries);
    AppLogger.configure(
      minimumLevel: preferences.minimumLevel,
      maximumEntries: preferences.maximumEntries,
    );
    state = state.copyWith(
      entries: repository.snapshot,
      minimumLevel: preferences.minimumLevel,
      maximumEntries: preferences.maximumEntries,
      isInitialized: true,
    );
    return Result.ok(null);
  }

  Future<Result<void>> setMinimumLevel(AppLogLevel level) {
    return _configure(level: level, maximumEntries: state.maximumEntries);
  }

  Future<Result<void>> setMaximumEntries(int maximumEntries) {
    if (!LogPreferencesService.isValidMaximum(maximumEntries)) {
      return Future.value(
        Result.error(Exception('Unsupported log retention limit')),
      );
    }
    return _configure(
      level: state.minimumLevel,
      maximumEntries: maximumEntries,
    );
  }

  void clear() {
    ref.read(appLogRepositoryProvider).clear();
    state = state.copyWith(
      entries: ref.read(appLogRepositoryProvider).snapshot,
    );
  }

  Future<Result<void>> _configure({
    required AppLogLevel level,
    required int maximumEntries,
  }) async {
    final repository = ref.read(appLogRepositoryProvider);
    repository.configureMaximumEntries(maximumEntries);
    AppLogger.configure(minimumLevel: level, maximumEntries: maximumEntries);
    state = state.copyWith(
      entries: repository.snapshot,
      minimumLevel: level,
      maximumEntries: maximumEntries,
    );

    final saved = await ref.read(logPreferencesServiceProvider).save((
      minimumLevel: level,
      maximumEntries: maximumEntries,
    ));
    if (saved case Error<void>(error: final error)) {
      return ref.notifyErrorResult(
        error,
        title: 'Logging setting applied but not saved',
      );
    }
    return Result.ok(null);
  }
}

final logProvider = NotifierProvider<LogNotifier, AppLogState>(LogNotifier.new);
