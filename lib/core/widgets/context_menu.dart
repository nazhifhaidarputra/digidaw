import 'package:flutter/material.dart';
import 'package:karbeat/core/l10n/localizer.dart';

/// Context action for an context menu available component
///
/// This is related to [ContextMenuWrapper].
class DawContextAction {
  final String title;
  final IconData? icon;
  final VoidCallback onTap;
  final bool isDestructive;
  final Color? color;

  /// Secondary text, used by submenus to show the current selection.
  final String? subtitle;

  /// Nested choices shown in a collapsible dropdown drawer when not null.
  final List<DawContextAction>? children;

  DawContextAction({
    required this.title,
    required this.onTap,
    this.icon,
    this.isDestructive = false,
    this.color,
  }) : subtitle = null,
       children = null;

  /// A collapsible group whose [children] open in a dropdown drawer.
  DawContextAction.submenu({
    required this.title,
    required List<DawContextAction> this.children,
    this.icon,
    this.subtitle,
    this.color,
  }) : onTap = _noop,
       isDestructive = false;

  static void _noop() {}
}

/// Shows the DAW styled context menu dialog. Resolves when the menu closes.
Future<void> showDawContextMenu({
  required BuildContext context,
  required List<DawContextAction> actions,
  String? title,
  Widget? header,
}) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) {
      final colors = Theme.of(dialogContext).colorScheme;
      return AlertDialog(
        title: title != null
            ? Text(title, style: TextStyle(color: colors.onSurface))
            : null,
        contentPadding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (header != null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 8.0,
                  ),
                  child: header,
                ),
                Divider(color: colors.outlineVariant, height: 16),
              ],

              ...actions.map(
                (action) => _DawContextMenuEntry(
                  action: action,
                  dialogContext: dialogContext,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// One row of [showDawContextMenu]; submenus expand in place as a drawer.
class _DawContextMenuEntry extends StatelessWidget {
  final DawContextAction action;
  final BuildContext dialogContext;
  final double indent;

  const _DawContextMenuEntry({
    required this.action,
    required this.dialogContext,
    this.indent = 0,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color =
        action.color ??
        (action.isDestructive ? colors.error : colors.onSurface);
    final padding = EdgeInsets.only(left: 24.0 + indent, right: 24.0);
    final leading = action.icon != null
        ? Icon(action.icon, color: color, size: 20)
        : null;
    final title = Text(
      action.title,
      style: TextStyle(color: color, fontSize: 14),
    );
    final subtitle = action.subtitle == null
        ? null
        : Text(
            action.subtitle!,
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
          );

    final children = action.children;
    if (children != null) {
      return ExpansionTile(
        tilePadding: padding,
        leading: leading,
        title: title,
        subtitle: subtitle,
        iconColor: colors.onSurfaceVariant,
        collapsedIconColor: colors.onSurfaceVariant,
        shape: const Border(),
        collapsedShape: const Border(),
        backgroundColor: colors.onSurface.withValues(alpha: 0.04),
        children: [
          for (final child in children)
            _DawContextMenuEntry(
              action: child,
              dialogContext: dialogContext,
              indent: indent + 16,
            ),
        ],
      );
    }

    return ListTile(
      contentPadding: padding,
      leading: leading,
      title: title,
      subtitle: subtitle,
      hoverColor: colors.onSurface.withValues(alpha: 0.08),
      onTap: () {
        Navigator.of(dialogContext).pop();
        action.onTap();
      },
    );
  }
}

/// A wrapper for a interactable widget that will display Context Menu
class ContextMenuWrapper extends StatelessWidget {
  final Widget child;
  final String? title;
  final Widget? header;
  final List<DawContextAction> actions;

  const ContextMenuWrapper({
    super.key,
    required this.child,
    required this.actions,
    this.title,
    this.header,
  });

  void _showContextMenu(BuildContext context) {
    showDawContextMenu(
      context: context,
      actions: actions,
      title: title,
      header: header,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: () => _showContextMenu(context),
      onSecondaryTap: () => _showContextMenu(context),
      child: child,
    );
  }
}

/// A floating panel that displays context-specific actions at the bottom of
/// its view, just above the workspace control dock. Uses the shared
/// [DawContextAction] model.
///
/// Actions are shown in order. When they don't all fit the available width,
/// the ones that don't fit move behind a [moreLabel] button that opens them
/// in a context menu, so put the most used actions first.
class FloatingContextPanel extends StatelessWidget {
  final List<DawContextAction> actions;
  final VoidCallback onClose;
  final String title;

  const FloatingContextPanel({
    super.key,
    required this.actions,
    required this.onClose,
    required this.title,
  });

  /// Outer horizontal margin kept free on each side of the panel.
  static const double _margin = 16;

  /// Gap between the panel and the bottom of its view, which borders the
  /// control dock.
  static const double _bottomGap = 6;

  /// Width of one action button: its padding and the wider of the icon and
  /// the label.
  static double _actionWidth(DawContextAction action, TextScaler scaler) {
    final label = TextPainter(
      text: TextSpan(text: action.title, style: const TextStyle(fontSize: 10)),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    return 24 + (label.width > 20 ? label.width : 20);
  }

  /// Width of the title, the close icon and the divider after them, plus the
  /// panel's own padding.
  double _chromeWidth(TextScaler scaler) {
    final label = TextPainter(
      text: TextSpan(
        text: title,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    // Padding 16 + 16, close icon 16 + 4, title, 12 gap, divider 1, gap 8.
    return 32 + 20 + label.width + 12 + 1 + 8;
  }

  /// How many [actions] fit in [width], leaving room for the More button
  /// when some don't.
  int _fittingCount(double width, TextScaler scaler, String moreLabel) {
    final available = width - 2 * _margin - _chromeWidth(scaler);
    final widths = [for (final action in actions) _actionWidth(action, scaler)];
    if (widths.fold(0.0, (sum, w) => sum + w) <= available) {
      return actions.length;
    }
    final more = _actionWidth(
      DawContextAction(title: moreLabel, onTap: () {}),
      scaler,
    );
    var used = more;
    var count = 0;
    for (final w in widths) {
      if (used + w > available) break;
      used += w;
      count++;
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    final scaler = MediaQuery.textScalerOf(context);
    final moreLabel = tr('common-more-actions');

    return Positioned(
      bottom: _bottomGap,
      left: 0,
      right: 0,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final fitting = _fittingCount(
            constraints.maxWidth,
            scaler,
            moreLabel,
          );
          final shown = actions.take(fitting);
          final hidden = actions.skip(fitting).toList();

          return Center(
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              color: colors.surfaceContainerHigh,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title / Close button
                    InkWell(
                      onTap: onClose,
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Row(
                          children: [
                            Icon(
                              Icons.close,
                              color: colors.onSurfaceVariant,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              title,
                              style: TextStyle(
                                color: colors.onSurfaceVariant,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 24,
                      color: colors.outlineVariant,
                    ),
                    const SizedBox(width: 8),

                    // Action Buttons
                    ...shown.map(
                      (action) => _FloatingActionButtonItem(action: action),
                    ),
                    if (hidden.isNotEmpty)
                      _FloatingActionButtonItem(
                        action: DawContextAction(
                          title: moreLabel,
                          icon: Icons.more_horiz,
                          onTap: () => showDawContextMenu(
                            context: context,
                            title: title,
                            actions: hidden,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FloatingActionButtonItem extends StatelessWidget {
  final DawContextAction action;

  const _FloatingActionButtonItem({required this.action});

  @override
  Widget build(BuildContext context) {
    // Resolve the final color based on destructive flag or explicit color
    final colors = Theme.of(context).colorScheme;
    final color =
        action.color ??
        (action.isDestructive ? colors.error : colors.onSurface);

    // A submenu on the bar opens its choices in a context menu.
    final children = action.children;
    final onTap = children == null
        ? action.onTap
        : () => showDawContextMenu(
            context: context,
            title: action.title,
            actions: children,
          );

    return Tooltip(
      message: action.title,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (action.icon != null) ...[
                Icon(action.icon, color: color, size: 20),
                const SizedBox(height: 2),
              ],
              Text(action.title, style: TextStyle(color: color, fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }
}
