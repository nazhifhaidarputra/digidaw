import 'package:karbeat/core/utils/log_models.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef LogPreferences = ({AppLogLevel minimumLevel, int maximumEntries});

class LogPreferencesService {
  static const minimumLevelKey = 'settings.logs.minimum_level.v1';
  static const maximumEntriesKey = 'settings.logs.maximum_entries.v1';
  static const defaultMaximumEntries = 250;
  static const minimumEntries = 50;
  static const maximumEntries = 2000;

  Future<Result<LogPreferences>> load() {
    return attemptAsync(() async {
      final preferences = SharedPreferencesAsync();
      final levelName = await preferences.getString(minimumLevelKey);
      final storedMaximum = await preferences.getInt(maximumEntriesKey);
      final level = AppLogLevel.values
          .where((value) => value.name == levelName)
          .firstOrNull;
      final retained = isValidMaximum(storedMaximum)
          ? storedMaximum!
          : defaultMaximumEntries;

      if (levelName != null && level == null) {
        await preferences.remove(minimumLevelKey);
      }
      if (storedMaximum != null && !isValidMaximum(storedMaximum)) {
        await preferences.setInt(maximumEntriesKey, defaultMaximumEntries);
      }

      return (
        minimumLevel: level ?? AppLogLevel.info,
        maximumEntries: retained,
      );
    });
  }

  Future<Result<void>> save(LogPreferences preferencesValue) {
    return attemptAsync(() async {
      final preferences = SharedPreferencesAsync();
      await preferences.setString(
        minimumLevelKey,
        preferencesValue.minimumLevel.name,
      );
      await preferences.setInt(
        maximumEntriesKey,
        preferencesValue.maximumEntries,
      );
    });
  }

  static bool isValidMaximum(int? value) {
    return value != null && value >= minimumEntries && value <= maximumEntries;
  }
}
