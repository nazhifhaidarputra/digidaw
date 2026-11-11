import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/src/rust/api/settings.dart' as settings_api;

typedef AudioOutputPreferences = ({String? hostName, String? deviceId});

/// Stores the chosen audio host and output device.
class AudioOutputPreferencesService {
  Future<Result<AudioOutputPreferences>> load() {
    return attemptAsync(() async {
      final audio = await settings_api.loadAudioPreferences();
      return (hostName: audio.outputHost, deviceId: audio.outputDevice);
    });
  }

  Future<Result<void>> save(AudioOutputPreferences value) {
    return attemptAsync(
      () => settings_api.saveAudioOutput(
        hostName: value.hostName,
        deviceId: value.deviceId,
      ),
    );
  }
}
