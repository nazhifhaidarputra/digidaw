import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/workspace_state.dart';
import 'package:karbeat/core/constants/toolbar.dart';

class Sidebar extends ConsumerWidget {
  const Sidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final currentContext = ref.watch(
      workspaceStateProvider.select((s) => s.currentToolbarContext),
    );

    return Container(
      width: 60,
      color: colors.surfaceContainerLow,
      child: Column(
        children: [
          Expanded(
            child: Container(
              color: colors.surfaceContainerLow,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: ToolbarConstants.menuGroups.map((group) {
                    return SidebarItem(
                      icon: group.icon,
                      title: group.title,
                      isActive: currentContext == group.id,
                      onTap: () => ref
                          .read(workspaceStateProvider.notifier)
                          .toggleToolbarContext(group.id),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SidebarItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isActive;
  final VoidCallback onTap;

  const SidebarItem({
    super.key,
    required this.icon,
    required this.title,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: isActive ? colors.primaryContainer : Colors.transparent,
        border: isActive
            ? Border(left: BorderSide(color: colors.primary, width: 3))
            : null,
      ),
      child: Tooltip(
        message: title,
        child: IconButton(
          icon: Icon(
            icon,
            color: isActive
                ? colors.onPrimaryContainer
                : colors.onSurfaceVariant,
            size: 22,
          ),
          onPressed: onTap,
        ),
      ),
    );
  }
}
