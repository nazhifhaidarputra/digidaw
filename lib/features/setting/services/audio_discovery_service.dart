import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/src/rust/api/audio_settings.dart' as audio_settings_api;
import 'package:karbeat/src/rust/api/project.dart';

class AudioDiscoveryService {
  Future<Result<IList<audio_settings_api.UiAudioHostInfo>>> listOutputHosts() {
    return attemptAsync(() async {
      return (await audio_settings_api.listOutputHosts()).lock;
    });
  }

  Future<Result<IList<audio_settings_api.UiOutputDeviceInfo>>>
  listOutputDevices(String? hostName) {
    return attemptAsync(() async {
      return (await audio_settings_api.listOutputDevices(
        hostName: hostName,
      )).lock;
    });
  }

  Future<Result<audio_settings_api.UiAudioRuntimeSettings>>
  applyOutputSelection(DawContext context, String? hostName, String? deviceId) {
    return attemptAsync(
      () => audio_settings_api.setOutputSelection(
        ctx: context,
        hostName: hostName,
        deviceId: deviceId,
      ),
    );
  }
}
