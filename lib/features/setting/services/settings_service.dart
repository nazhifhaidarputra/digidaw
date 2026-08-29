import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/src/rust/api/project.dart';
import 'package:karbeat/src/rust/api/simple.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const historyLimitPreferenceKey = 'settings.history_limit.v1';
  static const defaultHistoryLimit = 100;
  static const maxHistoryLimit = 1000;

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
}
