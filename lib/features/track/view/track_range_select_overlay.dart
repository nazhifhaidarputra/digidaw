import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/range_select_state.dart';

/// Renders the range-selection rectangle on one timeline row.
///
/// Lives inside the row's Stack — the same pattern used by [TrackGhostClip].
/// Because it sits in the row's own coordinate space, X is already in
/// absolute timeline pixels and the height is the row's. A range spanning
/// several rows draws one rectangle per covered row.
class TrackRangeSelectOverlay extends ConsumerWidget {
  final TimelineRow row;
  final double trackHeight;
  final double zoomLevel;

  const TrackRangeSelectOverlay({
    super.key,
    required this.row,
    required this.trackHeight,
    required this.zoomLevel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    // Rows outside the range select null and skip rebuilding while it moves.
    final rows = ref.watch(timelineRowsProvider);
    final rangeState = ref.watch(
      rangeSelectProvider.select((s) => s.covers(row, rows) ? s : null),
    );

    final children = <Widget>[];
    if (rangeState != null) {
      final left = rangeState.minTick / zoomLevel;
      final width = (rangeState.maxTick - rangeState.minTick) / zoomLevel;

      children.add(
        Positioned(
          left: left,
          top: 0,
          width: width < 2 ? 2 : width,
          height: trackHeight - 4,
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.2),
                border: Border.all(color: colors.primary, width: 2),
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
