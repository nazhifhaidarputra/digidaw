import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/features/setting/models/info_settings_state.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppInfoService {
  Future<String> loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  }
}

final appInfoServiceProvider = Provider<AppInfoService>((ref) {
  return AppInfoService();
});

final appVersionProvider = FutureProvider<String>((ref) {
  return ref.read(appInfoServiceProvider).loadVersion();
});

final infoSettingsProvider = Provider<InfoSettingsState>((ref) {
  return ref
      .watch(appVersionProvider)
      .when(
        data: (version) => InfoSettingsState(version: version),
        loading: () => const InfoSettingsState(isLoading: true),
        error: (error, _) => InfoSettingsState(errorMessage: error.toString()),
      );
});
