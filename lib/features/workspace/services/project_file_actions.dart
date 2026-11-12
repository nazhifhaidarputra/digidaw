import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/blocking_task_provider.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/core/l10n/localizer.dart';
import 'package:karbeat/features/setting/models/general_settings_state.dart';
import 'package:karbeat/features/setting/services/general_settings_provider.dart';
import 'package:karbeat/features/workspace/services/project_file_dialogs.dart';
import 'package:karbeat/features/workspace/view/unsaved_changes_guard.dart';
import 'package:karbeat/src/rust/api/serialization.dart' as serialization_api;

/// Saves the current project behind the blocking overlay.
///
/// Asks for a destination when the project is untitled or [saveAs] is set.
/// The dialog starts in the project's own folder, or the default project
/// folder for an untitled project. Returns `true` only when the project was
/// written.
Future<bool> saveCurrentProject(WidgetRef ref, {bool saveAs = false}) async {
  var path = ref.read(projectProvider).value?.currentFilePath;
  if (saveAs || path == null) {
    path = await pickProjectFileToSave(
      initialDirectory: path == null
          ? _defaultProjectFolder(ref)
          : File(path).parent.path,
    );
  }
  if (path == null) return false;

  final savePath = path;
  final project = ref.read(projectProvider.notifier);
  final saved = await ref
      .read(blockingTaskProvider.notifier)
      .run(
        label: tr('workspace-saving-project'),
        task: () => project.saveProject(savePath),
      );
  return saved.isOk();
}

/// Name shown for a project in the window title and prompts: the file name
/// of [filePath], or "Untitled" when the project has never been saved.
String projectDisplayName(String? filePath) {
  return filePath?.split(RegExp(r'[/\\]')).last ?? tr('workspace-untitled');
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

Future<Null> openProject(BuildContext context, WidgetRef ref) async {
  if (!await confirmDiscardUnsavedChanges(context, ref)) return;
  final path = await pickProjectFileToOpen(
    initialDirectory: _defaultProjectFolder(ref),
  );
  if (path == null) return;
  final project = ref.read(projectProvider.notifier);

  // Await the Rust Shadow Load & Swap behind the global blocking overlay.
  await ref
      .read(blockingTaskProvider.notifier)
      .run(
        label: tr('workspace-loading-project'),
        task: () => project.loadProject(path),
      );
}

/// Opens the recent project at [path], after the unsaved changes prompt.
Future<void> openRecentProject(
  BuildContext context,
  WidgetRef ref,
  String path,
) async {
  if (!await confirmDiscardUnsavedChanges(context, ref)) return;
  final project = ref.read(projectProvider.notifier);
  await ref
      .read(blockingTaskProvider.notifier)
      .run(
        label: tr('workspace-loading-project'),
        task: () => project.loadProject(path),
      );
}

/// The default project folder, when it is set and still exists.
String? _defaultProjectFolder(WidgetRef ref) =>
    ref.read(generalSettingsProvider).usableFolder(DefaultFolder.project);

Future<Null> newProject(BuildContext context, WidgetRef ref) async {
  if (!await confirmDiscardUnsavedChanges(context, ref)) return;
  await ref.read(projectProvider.notifier).newBlankProject();
}
