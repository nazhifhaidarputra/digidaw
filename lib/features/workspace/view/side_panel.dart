import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/core/input/input.dart';
import 'package:karbeat/core/input/shortcut_models.dart';
import 'package:karbeat/shared/models/menu_group.dart';

class ContextPanel extends ConsumerWidget {
  final DawToolbarMenuGroup group;
  final Function(DawToolbarMenuAction) onAction;
  final VoidCallback onClose;

  const ContextPanel({
    super.key,
    required this.group,
    required this.onAction,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final actions = [
      for (final action in group.actions)
        if (action.isVisible?.call(ref) ?? true) action,
    ];
    return Container(
      width: 240,
      color: colors.surfaceContainerLow,
      child: Column(
        children: [
          // Header
          Container(
            height: 50,
            color: colors.primaryContainer,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  group.title,
                  style: TextStyle(
                    color: colors.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    Icons.close,
                    color: colors.onPrimaryContainer,
                    size: 18,
                  ),
                  onPressed: onClose,
                ),
              ],
            ),
          ),

          // Simple text list
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(8),
              children: actions.map((action) {
                final submenu = action.submenu;
                if (submenu != null) {
                  return _SubmenuEntry(
                    action: action,
                    items: submenu(
                      (callback) => onAction(
                        DawToolbarMenuAction(action.title, callback: callback),
                      ),
                    ),
                  );
                }
                return _ActionEntry(
                  action: action,
                  onTap: () => onAction(action),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

/// One action of the panel: its title, and the key of its shortcut when it
/// has one.
class _ActionEntry extends ConsumerWidget {
  const _ActionEntry({
    required this.action,
    required this.onTap,
    this.trailing,
  });

  final DawToolbarMenuAction action;
  final VoidCallback onTap;

  /// Shown at the end of the row instead of a shortcut.
  final Widget? trailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final shortcutId = action.shortcutId;
    final chord = shortcutId == null
        ? null
        : ref.watch(activeShortcutChordProvider(shortcutId));
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  action.title,
                  style: TextStyle(
                    fontSize: 14,
                    color: action.isDestructive
                        ? colors.error
                        : colors.onSurface,
                  ),
                ),
              ),
              ?trailing,
              if (chord != null)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    shortcutLabel(chord),
                    style: TextStyle(
                      fontSize: 10,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// An action whose [items] open in a submenu beside the panel when it is
/// hovered or tapped, like a submenu of a desktop menu bar.
class _SubmenuEntry extends StatefulWidget {
  const _SubmenuEntry({required this.action, required this.items});

  final DawToolbarMenuAction action;
  final List<Widget> items;

  @override
  State<_SubmenuEntry> createState() => _SubmenuEntryState();
}

class _SubmenuEntryState extends State<_SubmenuEntry> {
  final _controller = MenuController();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return MenuAnchor(
      controller: _controller,
      // The submenu's top-left meets the entry's top-right, past the panel's
      // padding, with its first item level with the entry.
      style: const MenuStyle(alignment: AlignmentDirectional.topEnd),
      alignmentOffset: const Offset(8, -8),
      menuChildren: widget.items,
      child: MouseRegion(
        onEnter: (_) => _controller.open(),
        child: _ActionEntry(
          action: widget.action,
          onTap: () =>
              _controller.isOpen ? _controller.close() : _controller.open(),
          trailing: Icon(
            Icons.chevron_right,
            size: 18,
            color: colors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
