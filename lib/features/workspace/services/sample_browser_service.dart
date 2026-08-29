import 'dart:io';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/features/workspace/models/browser_panel_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SampleBrowserService {
  static const String sourceDirectoriesPreferenceKey =
      'sample_browser.source_directories.v1';

  static const Set<String> supportedExtensions = {
    'aac',
    'flac',
    'm4a',
    'mp3',
    'mp4',
    'ogg',
    'opus',
    'wav',
    'wave',
  };

  Future<Result<String?>> pickDirectory() {
    return attemptAsync(
      () => FilePicker.getDirectoryPath(
        dialogTitle: 'Add sample source directory',
      ),
    );
  }

  Future<Result<FileTree>> scanDirectory(String path) {
    return attemptAsync(() async {
      final directory = Directory(path);
      final normalizedPath = await directory.resolveSymbolicLinks();
      return _scan(Directory(normalizedPath));
    });
  }

  Future<Result<List<String>>> loadPersistedDirectoryPaths() {
    return attemptAsync(() async {
      final preferences = SharedPreferencesAsync();
      return await preferences.getStringList(sourceDirectoriesPreferenceKey) ??
          const <String>[];
    });
  }

  Future<Result<void>> savePersistedDirectoryPaths(Iterable<String> paths) {
    return attemptAsync(() async {
      final uniquePaths = paths.toSet().toList()..sort();
      final preferences = SharedPreferencesAsync();
      await preferences.setStringList(
        sourceDirectoriesPreferenceKey,
        uniquePaths,
      );
    });
  }

  Future<FileTree> _scan(Directory directory) async {
    final childDirectories = <FileTree>[];
    final samples = <BrowserSample>[];
    final entities = await directory.list(followLinks: false).toList();

    for (final entity in entities) {
      final name = _basename(entity.path);
      if (name.startsWith('.')) continue;

      if (entity is Directory) {
        try {
          childDirectories.add(await _scan(entity));
        } on FileSystemException {
          // An unreadable child should not make the entire source unavailable.
        }
      } else if (entity is File && _isSupportedAudioFile(entity.path)) {
        samples.add(BrowserSample(name: name, path: entity.absolute.path));
      }
    }

    childDirectories.sort(
      (left, right) =>
          left.name.toLowerCase().compareTo(right.name.toLowerCase()),
    );
    samples.sort(
      (left, right) =>
          left.name.toLowerCase().compareTo(right.name.toLowerCase()),
    );

    return FileTree(
      name: _basename(directory.path),
      path: directory.absolute.path,
      directories: childDirectories.toIList(),
      samples: samples.toIList(),
    );
  }

  bool _isSupportedAudioFile(String path) {
    final dot = path.lastIndexOf('.');
    if (dot == -1 || dot == path.length - 1) return false;
    return supportedExtensions.contains(path.substring(dot + 1).toLowerCase());
  }

  String _basename(String path) {
    if (path == Platform.pathSeparator) return path;
    final normalized = path.endsWith(Platform.pathSeparator)
        ? path.substring(0, path.length - 1)
        : path;
    final separator = normalized.lastIndexOf(Platform.pathSeparator);
    return separator == -1 ? normalized : normalized.substring(separator + 1);
  }
}

final sampleBrowserServiceProvider = Provider<SampleBrowserService>((ref) {
  return SampleBrowserService();
});
