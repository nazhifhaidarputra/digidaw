import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/src/rust/api/settings.dart' as settings_api;

typedef AudioDspPreferences = ({int sampleRate, int blockSize});

/// Stores the engine's sample rate and block size. Rust replaces stored
/// values the engine does not support with the defaults below.
class AudioDspPreferencesService {
  static const defaultSampleRate = 48000;
  static const defaultBlockSize = 1024;

  Future<Result<AudioDspPreferences>> load() {
    return attemptAsync(() async {
      final audio = await settings_api.loadAudioPreferences();
      return (sampleRate: audio.sampleRate, blockSize: audio.blockSize);
    });
  }

  Future<Result<void>> save(AudioDspPreferences value) {
    return attemptAsync(
      () => settings_api.saveAudioDsp(
        sampleRate: value.sampleRate,
        blockSize: value.blockSize,
      ),
    );
  }
}
