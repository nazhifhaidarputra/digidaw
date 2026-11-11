import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/src/rust/api/settings.dart' as settings_api;

typedef AudioInputPreferences = ({bool enabled, String? deviceId});

/// Stores whether device input is on and which device it uses.
class AudioInputPreferencesService {
  Future<Result<AudioInputPreferences>> load() {
    return attemptAsync(() async {
      final audio = await settings_api.loadAudioPreferences();
      return (enabled: audio.inputEnabled, deviceId: audio.inputDevice);
    });
  }

  Future<Result<void>> save(AudioInputPreferences value) {
    return attemptAsync(
      () => settings_api.saveAudioInput(
        enabled: value.enabled,
        deviceId: value.deviceId,
      ),
    );
  }
}
