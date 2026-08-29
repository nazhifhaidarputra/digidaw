import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

typedef AppPackageMetadata = ({String version, String buildNumber});

class AppInfoService {
  Future<AppPackageMetadata> loadPackageMetadata() async {
    final info = await PackageInfo.fromPlatform();
    return (version: info.version, buildNumber: info.buildNumber);
  }
}

final appInfoServiceProvider = Provider<AppInfoService>((ref) {
  return AppInfoService();
});

final appPackageMetadataProvider = FutureProvider<AppPackageMetadata>((ref) {
  return ref.read(appInfoServiceProvider).loadPackageMetadata();
});
