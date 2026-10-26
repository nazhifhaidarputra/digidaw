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
              children: group.actions.map((action) {
                final shortcutId = action.shortcutId;
                final chord = shortcutId == null
                    ? null
                    : ref.watch(activeShortcutChordProvider(shortcutId));
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => onAction(action),
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
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
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
