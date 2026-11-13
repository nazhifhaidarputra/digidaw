import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/core/l10n/localizer.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/features/workspace/models/browser_panel_state.dart';
import 'package:karbeat/src/rust/api/sample_browser.dart' as sample_browser_api;

/// Sample browser folders. Rust saves, scans and watches them; this service
/// only picks folders and converts the trees Rust sends.
class SampleBrowserService {
  Future<Result<String?>> pickDirectory() {
    return attemptAsync(
      () => FilePicker.getDirectoryPath(
        dialogTitle: tr('workspace-sample-folder-dialog'),
      ),
    );
  }

  /// Every saved folder once, then [sample_browser_api.UiSampleFolderEvent_Restored],
  /// then each folder whose files change on disk.
  Stream<sample_browser_api.UiSampleFolderEvent> watchDirectories() {
    return sample_browser_api.watchSampleFolders();
  }

  /// Saves and watches [path]; requires [watchDirectories] to be listened to.
  Future<Result<FileTree>> addDirectory(String path) {
    return attemptAsync(
      () async =>
          fileTreeFrom(await sample_browser_api.addSampleFolder(path: path)),
    );
  }
}

/// Converts a folder tree from Rust into immutable browser state.
FileTree fileTreeFrom(sample_browser_api.UiSampleTree tree) {
  return FileTree(
    name: tree.name,
    path: tree.path,
    directories: tree.directories.map(fileTreeFrom).toIList(),
    samples: tree.samples
        .map((sample) => BrowserSample(name: sample.name, path: sample.path))
        .toIList(),
  );
}

final sampleBrowserServiceProvider = Provider<SampleBrowserService>((ref) {
  return SampleBrowserService();
});
