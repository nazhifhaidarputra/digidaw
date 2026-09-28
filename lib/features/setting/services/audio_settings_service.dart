import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/src/rust/api/audio_settings.dart' as audio_settings_api;
import 'package:karbeat/src/rust/api/project.dart';

class AudioSettingsService {
  Future<Result<IList<int>>> supportedSampleRates() {
    return attemptAsync(() async {
      return (await audio_settings_api.supportedDspSampleRates()).toList().lock;
    });
  }

  Future<Result<IList<int>>> supportedBlockSizes() {
    return attemptAsync(() async {
      return (await audio_settings_api.supportedDspBlockSizes()).toList().lock;
    });
  }

  Future<Result<audio_settings_api.UiAudioRuntimeSettings>> applyDspConfig(
    DawContext context,
    int sampleRate,
    int blockSize,
  ) {
    return attemptAsync(
      () => audio_settings_api.setDspConfig(
        ctx: context,
        sampleRate: sampleRate,
        blockSize: blockSize,
      ),
    );
  }
}
