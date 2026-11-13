import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/blocking_task_provider.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/app/providers/workspace_state.dart';
import 'package:karbeat/core/input/shortcut_models.dart';
import 'package:karbeat/core/l10n/localizer.dart';
import 'package:karbeat/features/setting/services/general_settings_provider.dart';
import 'package:karbeat/features/setting/view/setting_screen.dart';
import 'package:karbeat/features/source/services/audio_source_import.dart';
import 'package:karbeat/features/workspace/services/project_file_actions.dart';
import 'package:karbeat/features/workspace/services/project_file_dialogs.dart';
import 'package:karbeat/features/workspace/view/recent_projects_menu.dart';
import 'package:karbeat/features/workspace/view/unsaved_changes_guard.dart';
import 'package:karbeat/generated/shortcuts/shortcut_keys.dart';
import 'package:karbeat/shared/enums/global.dart';

/// Toolbar Menu Group
class DawToolbarMenuGroup {
  final ToolbarMenuContextGroup id;

  /// Message id of the menu's name.
  final String titleId;
  final IconData icon;

  /// Define list of actions with type [DawToolbarMenuAction]
  final List<DawToolbarMenuAction> actions;

  DawToolbarMenuGroup({
    required this.id,
    required this.titleId,
    required this.icon,
    required this.actions,
  });

  String get title => tr(titleId);
}

/// Model for toolbar menu action
class DawToolbarMenuAction {
  /// Message id of the action's name.
  final String titleId;

  /// The shortcut whose active chord is shown as a hint. The displayed key
  /// follows the user's remapping in settings.
  final ShortcutKey? shortcut;

  /// Flag the menu if the menu is a dangerous operation
  final bool isDestructive;

  /// Define the callback when this action is executed
  final DawToolbarMenuActionCallback? callback;

  /// Whether the action is listed; listed always when null.
  final bool Function(WidgetRef ref)? isVisible;

  /// Items of a submenu that opens beside the action, as in a desktop menu
  /// bar, instead of running [callback].
  final DawToolbarSubmenuBuilder? submenu;

  DawToolbarMenuAction(
    this.titleId, {
    this.shortcut,
    this.isDestructive = false,
    this.callback,
    this.isVisible,
    this.submenu,
  });

  String get title => tr(titleId);
}

typedef DawToolbarMenuActionCallback = void Function(BuildContext, WidgetRef);

/// Builds the items of a submenu; [run] closes every menu and runs a
/// callback, as choosing a plain action does.
typedef DawToolbarSubmenuBuilder =
    List<Widget> Function(
      void Function(DawToolbarMenuActionCallback callback) run,
    );

/// Factory for toolbar menu group
///
/// **DEVELOPER NOTE**: *Create a new initialization here for a new group menu type*
class DawToolbarMenuGroupFactory {
  static DawToolbarMenuGroup createProjectMenuGroup() => DawToolbarMenuGroup(
    id: ToolbarMenuContextGroup.project,
    icon: Icons.work,
    titleId: 'app-menu-project',
    actions: [
      DawToolbarMenuAction(
        'app-menu-new-project',
        shortcut: WorkspaceShortcutKeys.newProject,
        callback: (context, ref) async {
          await newProject(context, ref);
        },
      ),
      DawToolbarMenuAction(
        'app-menu-open-project',
        shortcut: WorkspaceShortcutKeys.openProject,
        callback: (context, ref) async {
          await openProject(context, ref);
        },
      ),
      DawToolbarMenuAction(
        'app-menu-open-recent',
        isVisible: (ref) => ref.watch(
          generalSettingsProvider.select((state) => state.showRecentProjects),
        ),
        submenu: (run) => [RecentProjectsMenuItems(run: run)],
      ),
      DawToolbarMenuAction(
        'app-menu-save-project',
        shortcut: WorkspaceShortcutKeys.save,
        callback: (context, ref) async {
          // Untitled projects fall back to Save As.
          await saveCurrentProject(ref);
        },
      ),
      DawToolbarMenuAction(
        'app-menu-save-as',
        shortcut: WorkspaceShortcutKeys.saveAs,
        callback: (context, ref) async {
          await saveCurrentProject(ref, saveAs: true);
        },
      ),
      DawToolbarMenuAction(
        'app-menu-import-audio',
        shortcut: WorkspaceShortcutKeys.importAudio,
        callback: (context, ref) => importAudioSource(context, ref),
      ),
      DawToolbarMenuAction(
        'app-menu-export-project',
        shortcut: WorkspaceShortcutKeys.export,
        callback: (context, ref) async {
          ref.read(workspaceStateProvider.notifier).openExportPanel();
        },
      ),
      DawToolbarMenuAction(
        'app-menu-settings',
        shortcut: WorkspaceShortcutKeys.openSettings,
        callback: (context, ref) {
          Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute<void>(
              builder: (context) => const SettingScreen(),
            ),
          );
        },
      ),
      DawToolbarMenuAction(
        'app-menu-quit',
        isDestructive: true,
        callback: (context, ref) => quitApplication(context, ref),
      ),
    ],
  );

  static DawToolbarMenuGroup createEditMenuGroup() => DawToolbarMenuGroup(
    id: ToolbarMenuContextGroup.edit,
    icon: Icons.edit,
    titleId: 'app-menu-edit',
    actions: [
      DawToolbarMenuAction(
        'app-menu-undo',
        shortcut: WorkspaceShortcutKeys.undo,
      ),
      DawToolbarMenuAction(
        'app-menu-redo',
        shortcut: WorkspaceShortcutKeys.redo,
      ),
    ],
  );

  static DawToolbarMenuGroup createViewMenuGroup() => DawToolbarMenuGroup(
    id: ToolbarMenuContextGroup.view,
    titleId: 'app-menu-view',
    icon: Icons.visibility,
    actions: [
      DawToolbarMenuAction('app-menu-zoom-in'),
      DawToolbarMenuAction('app-menu-zoom-out'),
    ],
  );
}
