import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/blocking_task_provider.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/features/workspace/services/project_file_dialogs.dart';
import 'package:karbeat/src/rust/api/serialization.dart' as serialization_api;

/// Saves the current project behind the blocking overlay.
///
/// Asks for a destination when the project is untitled or [saveAs] is set.
/// Returns `true` only when the project was written.
Future<bool> saveCurrentProject(WidgetRef ref, {bool saveAs = false}) async {
  var path = ref.read(projectProvider).value?.currentFilePath;
  if (saveAs || path == null) {
    path = await pickProjectFileToSave();
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
  return saved.isOk();
}

/// Name shown for a project in the window title and prompts: the file name
/// of [filePath], or "Untitled" when the project has never been saved.
String projectDisplayName(String? filePath) {
  return filePath?.split(RegExp(r'[/\\]')).last ?? 'Untitled';
}

/// Whether the current project has no unsaved changes, reported by the engine
/// whenever it changes.
final projectSavedProvider = StreamProvider<bool>((ref) {
  final dawContext = ref.read(projectProvider.notifier).dawContext;
  return serialization_api.subscribeProjectSaved(ctx: dawContext);
});

/// Window title for a project: its name, followed by an asterisk while it has
/// unsaved changes.
String projectWindowTitle(String? filePath, {required bool saved}) {
  return 'DigiDAW — ${projectDisplayName(filePath)}${saved ? '' : '*'}';
}

final projectWindowTitleProvider = Provider<String>((ref) {
  final filePath = ref.watch(
    projectProvider.select((s) => s.value?.currentFilePath),
  );
  final saved = ref.watch(projectSavedProvider).value ?? true;
  return projectWindowTitle(filePath, saved: saved);
});
