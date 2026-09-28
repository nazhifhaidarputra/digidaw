import 'package:flutter/material.dart';

/// Compact latching button for channel flags such as mute (M) and solo (S).
class ChannelToggleButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final Color activeColor;
  final VoidCallback onTap;

  /// Hover text describing the action.
  final String? tooltip;

  const ChannelToggleButton({
    super.key,
    required this.label,
    required this.isActive,
    required this.activeColor,
    required this.onTap,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final activeForeground =
        ThemeData.estimateBrightnessForColor(activeColor) == Brightness.dark
        ? Colors.white
        : Colors.black;
    final button = GestureDetector(
      onTap: onTap,
      child: Container(
        width: 26,
        height: 22,
        decoration: BoxDecoration(
          color: isActive
              ? activeColor.withValues(alpha: 0.85)
              : colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isActive ? activeColor : colors.outlineVariant,
            width: 1,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? activeForeground : colors.onSurfaceVariant,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );

    return Semantics(
      button: true,
      toggled: isActive,
      label: tooltip ?? label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: tooltip == null
            ? button
            : Tooltip(message: tooltip!, child: button),
      ),
    );
  }
}
