import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/floating_midi_keyboard_state.dart';
import 'package:karbeat/app/providers/notification_provider.dart';
import 'package:karbeat/app/providers/piano_roll_state.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/app/providers/transport_state.dart';
import 'package:karbeat/app/providers/workspace_state.dart';
import 'package:karbeat/core/constants/toolbar.dart';
import 'package:karbeat/core/input/intents/song_timeline/playback_intent.dart';
import 'package:karbeat/core/input/intents/workspace/action_history_intent.dart';
import 'package:karbeat/core/input/intents/workspace/export_intent.dart';
import 'package:karbeat/core/input/intents/workspace/open_midi_keyboard_intent.dart';
import 'package:karbeat/core/input/intents/workspace/save_intent.dart';
import 'package:karbeat/core/utils/logger.dart';
import 'package:karbeat/core/widgets/shortcut_focus_anchor.dart';
import 'package:karbeat/features/workspace/services/project_file_actions.dart';
import 'package:karbeat/features/workspace/view/project_export.dart';
import 'package:karbeat/features/workspace/view/startup_recovery_prompt.dart';
import 'package:karbeat/features/workspace/view/unsaved_changes_guard.dart';
import 'package:karbeat/features/workspace/view/main_content.dart';
import 'package:karbeat/features/workspace/view/side_panel.dart';
import 'package:karbeat/features/workspace/view/sidebar.dart';
import 'package:karbeat/features/piano_roll/view/floating_midi_keyboard.dart';
import 'package:karbeat/features/setting/services/appearance_settings_provider.dart';
import 'package:karbeat/features/workspace/view/workspace_background.dart';
import 'package:karbeat/shared/enums/global.dart';
import 'package:karbeat/src/rust/api/transport.dart';

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
      // The export panel is modal: with no workspace actions to find, every
      // shortcut key passes through unhandled while it is open.
      actions: showExportPanel
          ? const <Type, Action<Intent>>{}
          : {
              SaveIntent: CallbackAction<SaveIntent>(
                onInvoke: (_) {
                  unawaited(saveCurrentProject(ref));
                  return null;
                },
              ),
              SaveAsIntent: CallbackAction<SaveAsIntent>(
                onInvoke: (_) {
                  unawaited(saveCurrentProject(ref, saveAs: true));
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
              TogglePlayIntent: CallbackAction<TogglePlayIntent>(
                onInvoke: (_) {
                  unawaited(_togglePlayback(ref));
                  return null;
                },
              ),
              StopIntent: CallbackAction<StopIntent>(
                onInvoke: (_) {
                  // The piano roll stops its pattern without rewinding the song.
                  if (ref.read(workspaceStateProvider).currentView ==
                      WorkspaceView.pianoRoll) {
                    unawaited(
                      ref
                          .read(pianoRollProvider.notifier)
                          .stopPatternPlayback(),
                    );
                  } else {
                    unawaited(ref.read(transportProvider.notifier).stop());
                  }
                  return null;
                },
              ),
              ToggleLoopIntent: CallbackAction<ToggleLoopIntent>(
                onInvoke: (_) {
                  unawaited(ref.read(transportProvider.notifier).toggleLoop());
                  return null;
                },
              ),
              ToggleMetronomeIntent: CallbackAction<ToggleMetronomeIntent>(
                onInvoke: (_) {
                  ref.read(transportProvider.notifier).toggleMetronomeActive();
                  return null;
                },
              ),
              ToggleVirtualMidiKeyboardIntent:
                  CallbackAction<ToggleVirtualMidiKeyboardIntent>(
                    onInvoke: (_) {
                      ref
                          .read(workspaceStateProvider.notifier)
                          .toggleFloatingMidiKeyboard();
                      return null;
                    },
                  ),
            },
      child: UnsavedChangesGuard(
        child: StartupRecoveryPrompt(
          child: ShortcutFocusAnchor(
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
          ),
        ),
      ),
    );
  }

  Future<void> _runHistoryAction(WidgetRef ref, {required bool undo}) async {
    final project = ref.read(projectProvider.notifier);
    await (undo ? project.undoLastAction() : project.redoLastAction());
  }

  Future<void> _togglePlayback(WidgetRef ref) async {
    try {
      final context = ref.read(projectProvider.notifier).dawContext;
      if (ref.read(workspaceStateProvider).currentView ==
          WorkspaceView.pianoRoll) {
        final pianoRoll = ref.read(pianoRollProvider);
        if (pianoRoll.editingPatternId == null ||
            pianoRoll.previewGeneratorId == null) {
          return;
        }
        await ref.read(pianoRollProvider.notifier).togglePatternPlayback();
        return;
      }

      await togglePlaybackWithMode(
        ctx: context,
        playbackMode: const PlaybackModeDto.song(),
      );
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to toggle playback',
        error: error,
        stackTrace: stackTrace,
      );
      ref
          .read(notificationProvider.notifier)
          .error(error, stackTrace: stackTrace);
    }
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
