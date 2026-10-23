import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/features/track/services/curve_sampler.dart';
import 'package:karbeat/features/track/view/track_header.dart';
import 'package:karbeat/src/rust/api/automation.dart';

/// Compact header for an automation lane in a channel drawer.
class AutomationLaneHeader extends ConsumerWidget {
  final AutomationLaneDto lane;

  /// What owns the automated parameter, such as the plugin or mixer channel.
  final String sourceName;
  final double itemHeight;
  final Color trackColor;

  /// Toggles whether the lane contributes automation during playback.
  final VoidCallback onToggleEnabled;

  /// Whether the lane is shrunk to its title row.
  final bool collapsed;

  /// Shrinks or expands the lane.
  final VoidCallback onToggleCollapsed;

  const AutomationLaneHeader({
    super.key,
    required this.lane,
    required this.sourceName,
    required this.itemHeight,
    required this.trackColor,
    required this.onToggleEnabled,
    required this.collapsed,
    required this.onToggleCollapsed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    // The lane is normalized; the automated parameter names its own range.
    final sampler = ref.watch(curveSamplerProvider);
    final minText = sampler.valueText(lane.id, 0);
    final maxText = sampler.valueText(lane.id, 1);
    return Container(
      height: itemHeight,
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(color: colors.outlineVariant, width: 1),
          right: BorderSide(color: colors.outlineVariant, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Indentation branch line
          Container(
            width: 24,
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: trackColor.withAlpha(100), width: 2),
              ),
            ),
          ),
          const SizedBox(width: 4),
          LaneCollapseToggle(
            collapsed: collapsed,
            color: colors.onSurfaceVariant,
            onPressed: onToggleCollapsed,
          ),
          const SizedBox(width: 4),

          // Icon and Label
          Icon(
            Icons.timeline,
            color: lane.enabled ? trackColor : colors.onSurfaceVariant,
            size: collapsed ? 12 : 16,
          ),
          const SizedBox(width: 8),
          if (collapsed)
            Expanded(
              child: AutomationLaneTitle(
                sourceName: sourceName,
                lane: lane,
                fontSize: 11,
              ),
            )
          else ...[
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AutomationLaneTitle(
                    sourceName: sourceName,
                    lane: lane,
                    fontSize: 12,
                  ),
                  Text(
                    "$minText to $maxText",
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 9,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Toggle active state
            IconButton(
              icon: Icon(
                lane.enabled ? Icons.power_settings_new : Icons.power_off,
                color: lane.enabled ? colors.primary : colors.outline,
                size: 16,
              ),
              onPressed: onToggleEnabled,
            ),
          ],
        ],
      ),
    );
  }
}

/// One-line automation lane title naming what owns the automated parameter
/// and the parameter itself, such as "Vital › Cutoff".
class AutomationLaneTitle extends StatelessWidget {
  final String sourceName;
  final AutomationLaneDto lane;
  final double fontSize;

  const AutomationLaneTitle({
    super.key,
    required this.sourceName,
    required this.lane,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Tooltip(
      message: '$sourceName › ${lane.label}',
      waitDuration: const Duration(milliseconds: 500),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$sourceName › ',
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w400,
              ),
            ),
            TextSpan(text: lane.label),
          ],
        ),
        style: TextStyle(
          color: lane.enabled ? colors.onSurface : colors.onSurfaceVariant,
          fontSize: fontSize,
          fontWeight: FontWeight.w500,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
