import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/src/rust/api/external_plugins.dart';
import 'package:karbeat/src/rust/api/plugin.dart';
import 'package:karbeat/src/rust/api/project.dart';

class ExternalPluginService {
  Future<Result<String?>> chooseDirectory() {
    return attemptAsync(
      () => FilePicker.getDirectoryPath(dialogTitle: 'Choose plugin folder'),
    );
  }

  Future<Result<List<String>>> defaultPaths() {
    return attemptAsync(defaultPluginScanPaths);
  }

  Future<Result<UiPluginScanSettings>> loadSettings() {
    return attemptAsync(pluginScanSettings);
  }

  Future<Result<UiPluginScanSettings>> saveSettings({
    required List<String> directories,
    required int timeoutSeconds,
  }) {
    return attemptAsync(
      () => savePluginScanSettings(
        directories: directories,
        timeoutSeconds: timeoutSeconds,
      ),
    );
  }

  Stream<UiPluginScanEvent> scan({
    required List<String> directories,
    required int timeoutSeconds,
    required bool retryQuarantined,
  }) {
    return scanExternalPlugins(
      directories: directories,
      timeoutSeconds: timeoutSeconds,
      retryQuarantined: retryQuarantined,
    );
  }

  Future<Result<bool>> cancel(int scanId) {
    return attemptAsync(() => cancelExternalPluginScan(id: scanId));
  }

  Future<Result<List<UiExternalPluginEntry>>> refreshCatalog(
    DawContext context,
  ) {
    return attemptAsync(() => refreshExternalPluginCatalog(ctx: context));
  }

  Future<Result<UiExternalPluginDescriptor?>> descriptor(
    DawContext context,
    UiPluginTarget target,
  ) {
    return attemptAsync(
      () => externalPluginDescriptor(ctx: context, target: target),
    );
  }

  Future<Result<UiExternalPluginCapabilities>> capabilities(
    DawContext context,
    UiPluginTarget target,
  ) {
    return attemptAsync(
      () => externalPluginCapabilities(ctx: context, target: target),
    );
  }

  Future<Result<void>> openEditor(DawContext context, UiPluginTarget target) {
    return attemptAsync(
      () => openExternalPluginEditor(ctx: context, target: target),
    );
  }
}

final externalPluginServiceProvider = Provider<ExternalPluginService>((ref) {
  return ExternalPluginService();
});
