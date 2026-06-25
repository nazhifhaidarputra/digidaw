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
    return Container(
      height: itemHeight,
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade800, width: 1),
          right: BorderSide(color: Colors.grey.shade400, width: 1),
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
            color: lane.enabled ? trackColor : Colors.grey,
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
                    color: lane.enabled ? Colors.white70 : Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  "Min: ${lane.min} | Max: ${lane.max}",
                  style: const TextStyle(color: Colors.white38, fontSize: 9),
                ),
              ],
            ),
          ),

          // Toggle active state
          IconButton(
            icon: Icon(
              lane.enabled ? Icons.power_settings_new : Icons.power_off,
              color: lane.enabled ? Colors.greenAccent : Colors.white24,
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
