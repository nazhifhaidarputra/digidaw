import 'package:karbeat/core/utils/result_type.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef AudioDspPreferences = ({int sampleRate, int blockSize});

class AudioDspPreferencesService {
  static const sampleRateKey = 'settings.audio.dsp_sample_rate.v1';
  static const blockSizeKey = 'settings.audio.dsp_block_size.v1';
  static const defaultSampleRate = 48000;
  static const defaultBlockSize = 1024;

  Future<Result<AudioDspPreferences>> load() {
    return attemptAsync(() async {
      final preferences = SharedPreferencesAsync();
      return (
        sampleRate:
            await preferences.getInt(sampleRateKey) ?? defaultSampleRate,
        blockSize: await preferences.getInt(blockSizeKey) ?? defaultBlockSize,
      );
    });
  }

  Future<Result<void>> save(AudioDspPreferences value) {
    return attemptAsync(() async {
      final preferences = SharedPreferencesAsync();
      await preferences.setInt(sampleRateKey, value.sampleRate);
      await preferences.setInt(blockSizeKey, value.blockSize);
    });
  }
}
