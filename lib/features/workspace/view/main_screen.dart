import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/workspace_state.dart';
import 'package:karbeat/app/providers/notification_provider.dart';
import 'package:karbeat/core/constants/toolbar.dart';
import 'package:karbeat/features/workspace/view/project_export.dart';
import 'package:karbeat/features/workspace/view/main_content.dart';
import 'package:karbeat/features/workspace/view/side_panel.dart';
import 'package:karbeat/features/workspace/view/sidebar.dart';
import 'package:karbeat/features/piano_roll/view/floating_midi_keyboard.dart';
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

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
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
                  ref.read(workspaceStateProvider.notifier).closeExportPanel();
                },
              ),
            ),
          ],
        ],
      ),
    );
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
        ref
            .read(notificationProvider.notifier)
            .info('Executed: ${action.title}');
      },
      onClose: () =>
          ref.read(workspaceStateProvider.notifier).closeContextPanel(),
    );
  }
}
