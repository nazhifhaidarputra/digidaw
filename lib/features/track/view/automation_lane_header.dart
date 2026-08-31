import 'package:flutter/material.dart';
import 'package:karbeat/src/rust/api/automation.dart';

class AutomationLaneHeader extends StatelessWidget {
  final AutomationLaneDto lane;
  final double itemHeight;
  final Color trackColor;

  const AutomationLaneHeader({
    super.key,
    required this.lane,
    required this.itemHeight,
    required this.trackColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
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
          const SizedBox(width: 8),

          // Icon and Label
          Icon(
            Icons.timeline,
            color: lane.enabled ? trackColor : colors.onSurfaceVariant,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lane.label,
                  style: TextStyle(
                    color: lane.enabled
                        ? colors.onSurface
                        : colors.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  "Min: ${lane.min} | Max: ${lane.max}",
                  style: TextStyle(color: colors.onSurfaceVariant, fontSize: 9),
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
            onPressed: () {
              // TODO: Dispatch toggle enabled to backend
            },
          ),
        ],
      ),
    );
  }
}
