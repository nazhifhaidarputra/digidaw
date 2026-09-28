import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/automation_provider.dart';
import 'package:karbeat/core/widgets/context_menu.dart';

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
    return ContextMenuWrapper(
      title: 'Automation: ${entry.lane.label}',
      actions: [
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
