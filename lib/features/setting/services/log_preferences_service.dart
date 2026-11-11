import 'package:karbeat/core/utils/log_models.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/src/rust/api/settings.dart' as settings_api;

typedef LogPreferences = ({AppLogLevel minimumLevel, int maximumEntries});

/// Stores what the log viewer keeps. Rust brings a stored entry count back
/// into range.
class LogPreferencesService {
  static const defaultMaximumEntries = 250;
  static const minimumEntries = 50;
  static const maximumEntries = 2000;

  Future<Result<LogPreferences>> load() {
    return attemptAsync(() async {
      final settings = await settings_api.loadLogSettings();
      return (
        minimumLevel: AppLogLevel.values.byName(settings.minimumLevel.name),
        maximumEntries: settings.maximumEntries,
      );
    });
  }

  Future<Result<void>> save(LogPreferences preferencesValue) {
    return attemptAsync(
      () => settings_api.saveLogSettings(
        settings: settings_api.UiLogSettings(
          minimumLevel: settings_api.UiLogLevel.values.byName(
            preferencesValue.minimumLevel.name,
          ),
          maximumEntries: preferencesValue.maximumEntries,
        ),
      ),
    );
  }

  static bool isValidMaximum(int? value) {
    return value != null && value >= minimumEntries && value <= maximumEntries;
  }
}
