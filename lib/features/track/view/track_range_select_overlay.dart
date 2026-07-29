import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/range_select_state.dart';

/// Renders the blue range-selection rectangle for a single track row.
///
/// Lives inside [AudioTrackSlot]'s Stack — the same pattern used by
/// [TrackGhostClip]. Because it sits in the track's own coordinate space:
///  • X is already in absolute timeline pixels (no scroll offset to subtract).
///  • Y is always 0, height is always [trackHeight] — no brittle calculations.
///  • Automation lanes are naturally handled because each slot has its own
///    independent coordinate system.
class TrackRangeSelectOverlay extends ConsumerWidget {
  final int trackId;
  final double trackHeight;
  final double zoomLevel;

  const TrackRangeSelectOverlay({
    super.key,
    required this.trackId,
    required this.trackHeight,
    required this.zoomLevel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rangeState = ref.watch(rangeSelectProvider);

    List<Widget> children = [];

    if (rangeState.isSelecting && rangeState.trackId == trackId) {
      final minTick = math.min(rangeState.startTick, rangeState.endTick);
      final maxTick = math.max(rangeState.startTick, rangeState.endTick);

      final left = minTick / zoomLevel;
      final width = (maxTick - minTick) / zoomLevel;

      children.add(
        Positioned(
          left: left,
          top: 0,
          width: width < 2 ? 2 : width,
          height: trackHeight - 4,
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.blueAccent.withAlpha(50),
                border: Border.all(color: Colors.blueAccent, width: 2),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      );
    }

    return Positioned.fill(
      child: Stack(clipBehavior: Clip.none, children: children),
    );
  }
}
