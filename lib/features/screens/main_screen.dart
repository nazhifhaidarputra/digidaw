import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/features/components/project_export.dart';
import 'package:karbeat/features/layout/main_content.dart';
import 'package:karbeat/features/side_panel/side_panel.dart';
import 'package:karbeat/features/side_panel/sidebar.dart';
import 'package:karbeat/state/app_state.dart';

import 'package:karbeat/features/components/floating_midi_keyboard.dart';

class MainScreen extends ConsumerWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentContext = ref.watch(
      karbeatStateProvider.select((s) => s.currentToolbarContext),
    );
    final showMidiKeyboard = ref.watch(
      karbeatStateProvider.select((s) => s.showFloatingMidiKeyboard),
    );

    final showExportPanel = ref.watch(
      karbeatStateProvider.select((s) => s.showExportPanel),
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
                  ref.read(karbeatStateProvider).closeExportPanel();
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
    final group = KarbeatState.menuGroups.firstWhere(
      (g) => g.id == currentContext,
    );

    return ContextPanel(
      group: group,
      onAction: (action) {
        final state = ref.read(karbeatStateProvider);
        state.closeContextPanel();
        action.callback?.call(context, state);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Executed: ${action.title}')));
      },
      onClose: () => ref.read(karbeatStateProvider).closeContextPanel(),
    );
  }
}
