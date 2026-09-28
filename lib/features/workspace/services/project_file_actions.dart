import 'dart:io' show Platform;

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/blocking_task_provider.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/core/utils/logger.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:window_manager/window_manager.dart';

const projectFileExtensions = ['karbeat', 'dgdaw'];

/// Saves the current project behind the blocking overlay.
///
/// Asks for a destination when the project is untitled or [saveAs] is set.
/// Returns `true` only when the project was written.
Future<bool> saveCurrentProject(WidgetRef ref, {bool saveAs = false}) async {
  var path = ref.read(projectProvider).value?.currentFilePath;
  if (saveAs || path == null) {
    path = await FilePicker.saveFile(
      dialogTitle: 'Save Project As...',
      fileName: 'untitled.dgdaw',
      type: FileType.custom,
      allowedExtensions: projectFileExtensions,
    );
  }
  if (path == null) return false;

  final savePath = path;
  final project = ref.read(projectProvider.notifier);
  final saved = await ref
      .read(blockingTaskProvider.notifier)
      .run(
        label: 'Saving project...',
        task: () => project.saveProject(savePath),
      );
  if (saved.isErr()) return false;
  await updateProjectWindowTitle(savePath);
  return true;
}

/// Name shown for a project in the window title and prompts: the file name
/// of [filePath], or "Untitled" when the project has never been saved.
String projectDisplayName(String? filePath) {
  return filePath?.split(RegExp(r'[/\\]')).last ?? 'Untitled';
}

/// Shows the project file name in the window title on desktop platforms.
/// A `null` path shows the untitled project.
Future<void> updateProjectWindowTitle(String? filePath) async {
  if (!(Platform.isWindows || Platform.isMacOS || Platform.isLinux)) return;

  final updated = await attemptAsync(
    () => windowManager.setTitle('DigiDAW — ${projectDisplayName(filePath)}'),
  );
  if (updated case Error<void>(error: final error)) {
    AppLogger.warn('Failed to set window title: $error');
  }
}
