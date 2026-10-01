import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/automation_provider.dart';
import 'package:karbeat/core/widgets/context_menu.dart';
import 'package:karbeat/features/track/models/automation_lane_clipboard.dart';
import 'package:karbeat/features/track/services/automation_editor_service.dart';
import 'package:karbeat/features/track/services/automation_template_service.dart';
import 'package:karbeat/features/track/view/automation_range_context_menu.dart';
import 'package:karbeat/features/track/view/automation_template_dialogs.dart';

/// Adds lane lifecycle actions to an automation header or timeline surface.
class AutomationLaneContextMenu extends ConsumerWidget {
  /// Lane, link, and target data used by the lifecycle actions.
  final ChannelAutomationEntry entry;

  /// Header or timeline surface that receives the context menu.
  final Widget child;

  /// Creates a context-menu surface for one automation lane.
  const AutomationLaneContextMenu({
    super.key,
    required this.entry,
    required this.child,
  });

  Future<void> _confirmRemoval(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove automation?'),
        content: Text(
          'Permanently remove “${entry.lane.label}” and all of its automation points?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await ref
        .read(automationProvider.notifier)
        .handleRemoveAutomationForTarget(target: entry.target);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = entry.lane.enabled;
    final collapsed = ref.watch(
      automationLaneLayoutProvider(entry.laneId).select((l) => l.collapsed),
    );
    final laneId = entry.laneId;
    final editor = ref.read(automationEditorProvider.notifier);
    final hasCurveClipboard = ref.watch(
      automationEditorProvider.select(
        (s) => s.clipboard is AutomationLanePointClipboardCurve,
      ),
    );
    // Rebuilds the menu when the template library changes.
    ref.watch(automationTemplatesProvider);

    /// Pastes land on the lane's selected range start, else where the lane
    /// was right-clicked.
    int pasteTick() => ref.read(automationEditorProvider).pasteTickFor(laneId);

    return ContextMenuWrapper(
      title: 'Automation: ${entry.sourceName} › ${entry.lane.label}',
      actions: [
        if (hasCurveClipboard)
          DawContextAction(
            title: 'Paste curve',
            icon: Icons.content_paste,
            onTap: () => editor.pasteCurve(laneId: laneId, atTick: pasteTick()),
          ),
        ...automationTemplateActions(
          ref: ref,
          title: 'Insert template',
          onInsert: (template) => editor.insertTemplate(
            laneId: laneId,
            atTick: pasteTick(),
            template: template,
          ),
        ),
        DawContextAction(
          title: 'Manage curve templates…',
          icon: Icons.bookmarks_outlined,
          onTap: () => showAutomationTemplateManager(context),
        ),
        DawContextAction(
          title: collapsed ? 'Expand lane' : 'Shrink lane',
          icon: collapsed ? Icons.unfold_more : Icons.unfold_less,
          onTap: () => ref
              .read(automationProvider.notifier)
              .toggleAutomationLaneCollapsed(laneId: entry.laneId),
        ),
        DawContextAction(
          title: enabled ? 'Unlink automation' : 'Relink automation',
          icon: enabled ? Icons.link_off : Icons.link,
          onTap: () => ref
              .read(automationProvider.notifier)
              .handleSetAutomationLaneEnabled(
                laneId: entry.laneId,
                enabled: !enabled,
              ),
        ),
        DawContextAction(
          title: 'Remove automation',
          icon: Icons.delete_outline,
          isDestructive: true,
          onTap: () => _confirmRemoval(context, ref),
        ),
      ],
      child: child,
    );
  }
}
