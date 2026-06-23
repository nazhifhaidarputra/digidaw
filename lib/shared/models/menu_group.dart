import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/app/providers/workspace_state.dart';
import 'package:karbeat/shared/enums/global.dart';
import 'package:window_manager/window_manager.dart';

/// Toolbar Menu Group
class DawToolbarMenuGroup {
  final ToolbarMenuContextGroup id;
  final String title;
  final IconData icon;

  /// Define list of actions with type [DawToolbarMenuAction]
  final List<DawToolbarMenuAction> actions;

  DawToolbarMenuGroup({required this.id, required this.title, required this.icon, required this.actions});
}

/// Model for toolbar menu action
class DawToolbarMenuAction {
  final String title;

  /// Shortcut for this action to give a context to the user. **Note that this shortcut only works on desktop app**
  final String? shortcut;

  /// Flag the menu if the menu is a dangerous operation
  final bool isDestructive;

  /// Define the callback when this action is executed
  final DawToolbarMenuActionCallback? callback;

  DawToolbarMenuAction(this.title, {this.shortcut, this.isDestructive = false, this.callback});
}

typedef DawToolbarMenuActionCallback = void Function(BuildContext, WidgetRef);

/// Factory for toolbar menu group
///
/// **DEVELOPER NOTE**: *Create a new initialization here for a new group menu type*
class DawToolbarMenuGroupFactory {
  /// Helper to safely update the window title on Desktop platforms
  static Future<void> _updateWindowTitle(String filePath) async {
    // Only attempt to change the window title on desktop OS
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      final fileName = filePath.split(RegExp(r'[/\\]')).last;

      try {
        await windowManager.setTitle('DigiDAW — $fileName');
      } catch (e) {
        debugPrint("Failed to set window title: $e");
      }
    }
  }

  /// Helper to handle "Save As" logic used by both Save and Save As buttons
  static Future<void> _performSaveAs(BuildContext context, WidgetRef ref) async {
    final path = await FilePicker.saveFile(
      dialogTitle: 'Save Project As...',
      fileName: 'untitled.dgdaw',
      type: FileType.custom,
      allowedExtensions: ['karbeat', 'dgdaw'],
    );

    if (path != null) {
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(child: CircularProgressIndicator()),
        );
      }

      await ref.read(projectProvider.notifier).saveProject(path);

      await _updateWindowTitle(path);

      if (context.mounted) Navigator.of(context).pop();
    }
  }

  static DawToolbarMenuGroup createProjectMenuGroup() => DawToolbarMenuGroup(
    id: ToolbarMenuContextGroup.project,
    icon: Icons.work,
    title: "Project",
    actions: [
      DawToolbarMenuAction(
        'New project',
        shortcut: 'Ctrl + N',
        callback: (context, ref) async {
          ref.invalidate(projectProvider);

          // Safely update window title back to default
          if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
            try {
              await windowManager.setTitle('DigiDAW — Untitled');
            } catch (e) {
              debugPrint("Failed to set window title: $e");
            }
          }
        },
      ),
      DawToolbarMenuAction(
        'Open project',
        shortcut: 'Ctrl+O',
        callback: (context, ref) async {
          final result = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['karbeat', 'dgdaw']);
          if (result != null && result.files.single.path != null) {
            final path = result.files.single.path!;

            // Put up the "Glass Pane" blocking all touch events
            if (context.mounted) {
              showDialog(
                context: context,
                barrierDismissible: false, // User cannot tap outside to dismiss
                useRootNavigator: true, // Ensures it covers the entire app
                builder: (context) => PopScope(
                  canPop: false, // Prevents Android back-button from dismissing it
                  child: const Center(
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [CircularProgressIndicator(), SizedBox(height: 16), Text("Loading Project...")],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }

            try {
              // Await the Rust Shadow Load & Swap
              await ref.read(projectProvider.notifier).loadProject(path);

              await _updateWindowTitle(path);
            } catch (e) {
              debugPrint("Failed to load project: $e");
              // Optional: Show error snackbar here
            } finally {
              // Tear down the "Glass Pane" SAFELY
              if (context.mounted) {
                Navigator.of(context, rootNavigator: true).pop();
              }
            }
          }
        },
      ),
      DawToolbarMenuAction(
        'Save Project',
        shortcut: 'Ctrl+S',
        callback: (context, ref) async {
          final currentFilePath = ref.read(projectProvider).value?.currentFilePath;
          if (currentFilePath == null) {
            // If the project has never been saved, trigger Save As
            await _performSaveAs(context, ref);
          } else {
            // Otherwise, save silently to the existing path
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => const Center(child: CircularProgressIndicator()),
            );

            await ref.read(projectProvider.notifier).saveProject(currentFilePath);

            if (context.mounted) Navigator.of(context).pop();
          }
        },
      ),
      DawToolbarMenuAction(
        'Save As...',
        shortcut: 'Ctrl+Shift+S',
        callback: (context, ref) async {
          await _performSaveAs(context, ref);
        },
      ),
      DawToolbarMenuAction('Import Audio'),
      DawToolbarMenuAction(
        'Export Project',
        callback: (context, ref) async {
          ref.read(workspaceStateProvider.notifier).openExportPanel();
        },
      ),
      DawToolbarMenuAction('Settings'),
    ],
  );

  static DawToolbarMenuGroup createEditMenuGroup() => DawToolbarMenuGroup(
    id: ToolbarMenuContextGroup.edit,
    icon: Icons.edit,
    title: 'Edit',
    actions: [
      DawToolbarMenuAction('Undo', shortcut: 'Ctrl+Z'),
      DawToolbarMenuAction('Redo', shortcut: 'CTRL+Y'),
    ],
  );

  static DawToolbarMenuGroup createViewMenuGroup() => DawToolbarMenuGroup(
    id: ToolbarMenuContextGroup.view,
    title: 'View',
    icon: Icons.visibility,
    actions: [
      DawToolbarMenuAction('Zoom in', shortcut: 'Ctrl+Plus'),
      DawToolbarMenuAction('Zoom out', shortcut: 'CTRL+Minus'),
    ],
  );
}
