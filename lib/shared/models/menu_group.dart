import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/blocking_task_provider.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/app/providers/workspace_state.dart';
import 'package:karbeat/features/setting/view/setting_screen.dart';
import 'package:karbeat/features/source/services/audio_source_import.dart';
import 'package:karbeat/features/workspace/services/project_file_actions.dart';
import 'package:karbeat/features/workspace/services/project_file_dialogs.dart';
import 'package:karbeat/features/workspace/view/unsaved_changes_guard.dart';
import 'package:karbeat/shared/enums/global.dart';

/// Toolbar Menu Group
class DawToolbarMenuGroup {
  final ToolbarMenuContextGroup id;
  final String title;
  final IconData icon;

  /// Define list of actions with type [DawToolbarMenuAction]
  final List<DawToolbarMenuAction> actions;

  DawToolbarMenuGroup({
    required this.id,
    required this.title,
    required this.icon,
    required this.actions,
  });
}

/// Model for toolbar menu action
class DawToolbarMenuAction {
  final String title;

  /// ID of the shortcut in the shortcut catalog whose active chord is shown as
  /// a hint. The displayed key follows the user's remapping in settings.
  final String? shortcutId;

  /// Flag the menu if the menu is a dangerous operation
  final bool isDestructive;

  /// Define the callback when this action is executed
  final DawToolbarMenuActionCallback? callback;

  DawToolbarMenuAction(
    this.title, {
    this.shortcutId,
    this.isDestructive = false,
    this.callback,
  });
}

typedef DawToolbarMenuActionCallback = void Function(BuildContext, WidgetRef);

/// Factory for toolbar menu group
///
/// **DEVELOPER NOTE**: *Create a new initialization here for a new group menu type*
class DawToolbarMenuGroupFactory {
  static DawToolbarMenuGroup createProjectMenuGroup() => DawToolbarMenuGroup(
    id: ToolbarMenuContextGroup.project,
    icon: Icons.work,
    title: "Project",
    actions: [
      DawToolbarMenuAction(
        'New project',
        shortcutId: 'workspace.newProject',
        callback: (context, ref) async {
          await newProject(context, ref);
        },
      ),
      DawToolbarMenuAction(
        'Open project',
        shortcutId: 'workspace.openProject',
        callback: (context, ref) async {
          await openProject(context, ref);
        },
      ),
      DawToolbarMenuAction(
        'Save Project',
        shortcutId: 'workspace.save',
        callback: (context, ref) async {
          // Untitled projects fall back to Save As.
          await saveCurrentProject(ref);
        },
      ),
      DawToolbarMenuAction(
        'Save As...',
        shortcutId: 'workspace.saveAs',
        callback: (context, ref) async {
          await saveCurrentProject(ref, saveAs: true);
        },
      ),
      DawToolbarMenuAction(
        'Import Audio',
        shortcutId: 'workspace.importAudio',
        callback: (context, ref) => importAudioSource(context, ref),
      ),
      DawToolbarMenuAction(
        'Export Project',
        shortcutId: 'workspace.export',
        callback: (context, ref) async {
          ref.read(workspaceStateProvider.notifier).openExportPanel();
        },
      ),
      DawToolbarMenuAction(
        'Settings',
        shortcutId: 'workspace.openSettings',
        callback: (context, ref) {
          Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute<void>(
              builder: (context) => const SettingScreen(),
            ),
          );
        },
      ),
      DawToolbarMenuAction(
        'Quit DigiDAW',
        isDestructive: true,
        callback: (context, ref) => quitApplication(context, ref),
      ),
    ],
  );

  static DawToolbarMenuGroup createEditMenuGroup() => DawToolbarMenuGroup(
    id: ToolbarMenuContextGroup.edit,
    icon: Icons.edit,
    title: 'Edit',
    actions: [
      DawToolbarMenuAction('Undo', shortcutId: 'workspace.undo'),
      DawToolbarMenuAction('Redo', shortcutId: 'workspace.redo'),
    ],
  );

  static DawToolbarMenuGroup createViewMenuGroup() => DawToolbarMenuGroup(
    id: ToolbarMenuContextGroup.view,
    title: 'View',
    icon: Icons.visibility,
    actions: [
      DawToolbarMenuAction('Zoom in'),
      DawToolbarMenuAction('Zoom out'),
    ],
  );
}
