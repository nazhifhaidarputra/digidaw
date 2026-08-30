import 'dart:async';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/app/providers/workspace_state.dart';
import 'package:karbeat/core/constants/toolbar.dart';
import 'package:karbeat/core/input/intents/workspace/action_history_intent.dart';
import 'package:karbeat/core/input/intents/workspace/export_intent.dart';
import 'package:karbeat/core/input/intents/workspace/save_intent.dart';
import 'package:karbeat/features/workspace/view/project_export.dart';
import 'package:karbeat/features/workspace/view/main_content.dart';
import 'package:karbeat/features/workspace/view/side_panel.dart';
import 'package:karbeat/features/workspace/view/sidebar.dart';
import 'package:karbeat/features/piano_roll/view/floating_midi_keyboard.dart';
import 'package:karbeat/features/setting/services/appearance_settings_provider.dart';
import 'package:karbeat/features/workspace/view/workspace_background.dart';
import 'package:karbeat/shared/enums/global.dart';

class MainScreen extends ConsumerWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentContext = ref.watch(
      workspaceStateProvider.select((s) => s.currentToolbarContext),
    );
    final showMidiKeyboard = ref.watch(
      workspaceStateProvider.select((s) => s.floatingMidiKeyboardState.showed),
    );
    final showExportPanel = ref.watch(
      workspaceStateProvider.select((s) => s.showExportPanel),
    );
    final background = ref.watch(
      appearanceSettingsProvider.select(
        (state) => (
          // path: state.backgroundImagePath,
          fit: state.backgroundFit,
          overlay: state.backgroundOverlayOpacity,
        ),
      ),
    );

    return Actions(
      actions: {
        SaveIntent: CallbackAction<SaveIntent>(
          onInvoke: (_) {
            unawaited(_saveProject(ref));
            return null;
          },
        ),
        SaveAsIntent: CallbackAction<SaveAsIntent>(
          onInvoke: (_) {
            unawaited(_saveProject(ref, saveAs: true));
            return null;
          },
        ),
        ExportIntent: CallbackAction<ExportIntent>(
          onInvoke: (_) {
            ref.read(workspaceStateProvider.notifier).openExportPanel();
            return null;
          },
        ),
        UndoIntent: CallbackAction<UndoIntent>(
          onInvoke: (_) {
            unawaited(_runHistoryAction(ref, undo: true));
            return null;
          },
        ),
        RedoIntent: CallbackAction<RedoIntent>(
          onInvoke: (_) {
            unawaited(_runHistoryAction(ref, undo: false));
            return null;
          },
        ),
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: Stack(
          children: [
            Positioned.fill(
              child: WorkspaceBackground(
                fit: background.fit,
                overlayOpacity: background.overlay,
              ),
            ),
            const Row(
              children: [
                Sidebar(),
                Expanded(child: MainContent()),
              ],
            ),
            // Optimized Context Panel Overlay
            if (currentContext != ToolbarMenuContextGroup.none)
              Positioned(
                left: 60,
                top: 0,
                bottom: 0,
                child: _buildContextPanel(context, ref, currentContext),
              ),

            if (showMidiKeyboard) const FloatingMidiKeyboard(),
            if (showExportPanel) ...[
              Positioned.fill(
                child: GestureDetector(
                  onTap: () {
                    // ref.read(karbeatStateProvider).closeExportPanel();
                  },
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                    child: Container(color: Colors.black.withAlpha(100)),
                  ),
                ),
              ),

              // Export panel
              Positioned.fill(
                child: ProjectExportPanel(
                  onClose: () {
                    ref
                        .read(workspaceStateProvider.notifier)
                        .closeExportPanel();
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _saveProject(WidgetRef ref, {bool saveAs = false}) async {
    var path = ref.read(projectProvider).value?.currentFilePath;
    if (saveAs || path == null) {
      path = await FilePicker.saveFile(
        dialogTitle: 'Save Project As...',
        fileName: 'untitled.dgdaw',
        type: FileType.custom,
        allowedExtensions: const ['karbeat', 'dgdaw'],
      );
    }
    if (path != null) {
      await ref.read(projectProvider.notifier).saveProject(path);
    }
  }

  Future<void> _runHistoryAction(WidgetRef ref, {required bool undo}) async {
    final project = ref.read(projectProvider.notifier);
    await (undo ? project.undoLastAction() : project.redoLastAction());
  }

  Widget _buildContextPanel(
    BuildContext context,
    WidgetRef ref,
    ToolbarMenuContextGroup currentContext,
  ) {
    final group = ToolbarConstants.menuGroups.firstWhere(
      (g) => g.id == currentContext,
    );

    return ContextPanel(
      group: group,
      onAction: (action) {
        final state = ref.read(workspaceStateProvider.notifier);
        state.closeContextPanel();
        action.callback?.call(context, ref);
      },
      onClose: () =>
          ref.read(workspaceStateProvider.notifier).closeContextPanel(),
    );
  }
}
