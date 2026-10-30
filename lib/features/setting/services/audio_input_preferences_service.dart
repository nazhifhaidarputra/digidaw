import 'package:karbeat/core/utils/result_type.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef AudioInputPreferences = ({bool enabled, String? deviceId});

class AudioInputPreferencesService {
  static const enabledKey = 'settings.audio.input_enabled.v1';
  static const deviceKey = 'settings.audio.input_device.v1';

  Future<Result<AudioInputPreferences>> load() {
    return attemptAsync(() async {
      final preferences = SharedPreferencesAsync();
      return (
        enabled: await preferences.getBool(enabledKey) ?? false,
        deviceId: await preferences.getString(deviceKey),
      );
    });
  }

  Future<Result<void>> save(AudioInputPreferences value) {
    return attemptAsync(() async {
      final preferences = SharedPreferencesAsync();
      await preferences.setBool(enabledKey, value.enabled);
      final deviceId = value.deviceId;
      if (deviceId == null) {
        await preferences.remove(deviceKey);
      } else {
        await preferences.setString(deviceKey, deviceId);
      }
    });
  }
}
