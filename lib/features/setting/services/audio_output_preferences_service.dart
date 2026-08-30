import 'package:karbeat/core/utils/result_type.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef AudioOutputPreferences = ({String? hostName, String? deviceId});

class AudioOutputPreferencesService {
  static const hostKey = 'settings.audio.output_host.v1';
  static const deviceKey = 'settings.audio.output_device.v1';

  Future<Result<AudioOutputPreferences>> load() {
    return attemptAsync(() async {
      final preferences = SharedPreferencesAsync();
      return (
        hostName: await preferences.getString(hostKey),
        deviceId: await preferences.getString(deviceKey),
      );
    });
  }

  Future<Result<void>> save(AudioOutputPreferences value) {
    return attemptAsync(() async {
      final preferences = SharedPreferencesAsync();
      await _writeOptional(preferences, hostKey, value.hostName);
      await _writeOptional(preferences, deviceKey, value.deviceId);
    });
  }

  Future<void> _writeOptional(
    SharedPreferencesAsync preferences,
    String key,
    String? value,
  ) async {
    if (value == null) {
      await preferences.remove(key);
    } else {
      await preferences.setString(key, value);
    }
  }
}
