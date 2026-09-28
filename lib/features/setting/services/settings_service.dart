import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/src/rust/api/mitigation.dart' as mitigation_api;
import 'package:karbeat/src/rust/api/project.dart';
import 'package:karbeat/src/rust/api/simple.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const historyLimitPreferenceKey = 'settings.history_limit.v1';
  static const defaultHistoryLimit = 100;
  static const maxHistoryLimit = 1000;

  static const autoSaveEnabledPreferenceKey = 'settings.auto_save.enabled.v1';
  static const autoSaveIntervalPreferenceKey =
      'settings.auto_save.interval_seconds.v1';
  static const defaultAutoSaveEnabled = true;
  static const defaultAutoSaveIntervalSeconds = 300;
  static const minAutoSaveIntervalSeconds = 60;
  static const maxAutoSaveIntervalSeconds = 3600;

  Future<Result<int>> loadHistoryLimit() {
    return attemptAsync(() async {
      final preferences = SharedPreferencesAsync();
      final stored = await preferences.getInt(historyLimitPreferenceKey);
      if (stored == null) return defaultHistoryLimit;
      if (!isValidHistoryLimit(stored)) {
        await preferences.setInt(
          historyLimitPreferenceKey,
          defaultHistoryLimit,
        );
        return defaultHistoryLimit;
      }
      return stored;
    });
  }

  Future<Result<void>> saveHistoryLimit(int limit) {
    return attemptAsync(() async {
      final preferences = SharedPreferencesAsync();
      await preferences.setInt(historyLimitPreferenceKey, limit);
    });
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
    return attemptAsync(() async {
      final preferences = SharedPreferencesAsync();
      final enabled = await preferences.getBool(autoSaveEnabledPreferenceKey);
      final interval = await preferences.getInt(autoSaveIntervalPreferenceKey);
      if (interval != null && !isValidAutoSaveInterval(interval)) {
        await preferences.setInt(
          autoSaveIntervalPreferenceKey,
          defaultAutoSaveIntervalSeconds,
        );
      }
      return mitigation_api.UiAutoSaveSettings(
        isEnabled: enabled ?? defaultAutoSaveEnabled,
        intervalSeconds: interval != null && isValidAutoSaveInterval(interval)
            ? interval
            : defaultAutoSaveIntervalSeconds,
      );
    });
  }

  Future<Result<void>> saveAutoSaveSettings(
    mitigation_api.UiAutoSaveSettings settings,
  ) {
    return attemptAsync(() async {
      final preferences = SharedPreferencesAsync();
      await preferences.setBool(
        autoSaveEnabledPreferenceKey,
        settings.isEnabled,
      );
      await preferences.setInt(
        autoSaveIntervalPreferenceKey,
        settings.intervalSeconds,
      );
    });
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
}
