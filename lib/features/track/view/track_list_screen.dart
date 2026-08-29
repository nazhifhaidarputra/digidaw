import 'dart:async';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:karbeat/app/providers/automation_provider.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/app/providers/track_list_state.dart';
import 'package:karbeat/app/providers/transport_state.dart';
import 'package:karbeat/app/providers/workspace_state.dart';
import 'package:karbeat/core/widgets/scroll_physics/unclamped_never_scrollable_physics.dart';
import 'package:karbeat/features/plugins/services/audio_plugins_service.dart';
import 'package:karbeat/features/track/view/automation_lane_header.dart';
import 'package:karbeat/features/track/view/automation_lane_slot.dart';
import 'package:karbeat/features/track/view/grid_painter.dart';
import 'package:karbeat/features/track/view/track_header.dart';
import 'package:karbeat/shared/enums/global.dart';
import 'package:karbeat/shared/models/grid.dart';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:karbeat/core/widgets/context_menu.dart';
import 'package:karbeat/core/widgets/daw_input_detector.dart';
import 'package:karbeat/features/track/view/midi_drawer.dart';
import 'package:karbeat/features/track/view/waveform_painter.dart';

import 'package:karbeat/features/track/view/playhead.dart';
import 'package:karbeat/app/providers/range_select_state.dart';
import 'package:karbeat/features/track/view/track_ghost_clip.dart';
import 'package:karbeat/features/track/view/track_range_select_overlay.dart';
import 'package:karbeat/shared/models/interaction_target.dart';
import 'package:karbeat/src/rust/api/plugin.dart' show UiPluginInfo;
import 'package:karbeat/src/rust/api/project.dart';
import 'package:karbeat/src/rust/api/track.dart';
import 'package:karbeat/src/rust/api/waveform.dart';
import 'package:karbeat/app/providers/clip_placement_state.dart';
import 'package:karbeat/app/providers/notification_provider.dart';
import 'package:karbeat/core/utils/clip_time_utils.dart';
import 'package:karbeat/core/utils/color.dart';
import 'package:karbeat/core/utils/logger.dart';
import 'package:karbeat/core/utils/scroll_behavior.dart';
import 'package:linked_scroll_controller/linked_scroll_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:multi_split_view/multi_split_view.dart';
import 'package:karbeat/features/workspace/models/browser_panel_state.dart';
import 'package:karbeat/src/rust/api/audio.dart' as audio_api;

part 'track_list_split_view.dart';
part 'track_list_sample_browser.dart';
part 'track_list_timeline_ruler.dart';
part 'track_list_audio_slot.dart';
part 'track_list_interactive_clip.dart';
part 'track_list_clip_renderer.dart';
// part 'track_list_grouped_batch_overlay.dart';

class _ClipTickRange {
  final int start;
  final int end;

  const _ClipTickRange(this.start, this.end);

  bool overlaps(_ClipTickRange other) => start < other.end && end > other.start;

  _ClipTickRange shifted(int delta) =>
      _ClipTickRange(start + delta, end + delta);
}

/// Calculates the leading tick of every clip-group copy covered by a draw
/// swipe. The source clips retain their offsets within the group.
///
/// Copy groups never overlap each other. When snapping is active their leading
/// edge is always on a grid line; otherwise each group begins exactly where
/// the preceding group ends. Drawing stops at the first occupied region so a
/// swipe can never paste on top of an existing clip.
List<int> _drawSwipeCopyStarts({
  required List<_ClipTickRange> sourceRanges,
  required List<_ClipTickRange> occupiedRanges,
  required int dragTick,
  int? gridStep,
}) {
  if (sourceRanges.isEmpty) return const [];

  final sourceStart = sourceRanges.map((range) => range.start).reduce(math.min);
  final sourceEnd = sourceRanges.map((range) => range.end).reduce(math.max);
  final groupLength = sourceEnd - sourceStart;
  if (groupLength <= 0 || dragTick < sourceEnd) return const [];

  int alignForward(int tick) {
    if (gridStep == null || gridStep <= 0) return tick;
    return ((tick + gridStep - 1) ~/ gridStep) * gridStep;
  }

  final relativeRanges = sourceRanges
      .map(
        (range) =>
            _ClipTickRange(range.start - sourceStart, range.end - sourceStart),
      )
      .toList(growable: false);

  final starts = <int>[];
  int nextStart = alignForward(sourceEnd);

  // A practical guard against building an unbounded preview if a malformed
  // pointer event reports an extremely large timeline coordinate.
  const maxCopiesPerSwipe = 1000;
  while (nextStart <= dragTick && starts.length < maxCopiesPerSwipe) {
    final copyRanges = relativeRanges
        .map((range) => range.shifted(nextStart))
        .toList(growable: false);
    final collides = copyRanges.any(
      (copy) => occupiedRanges.any(copy.overlaps),
    );
    if (collides) break;

    starts.add(nextStart);
    nextStart = alignForward(nextStart + groupLength);
  }

  return starts;
}

class TrackListScreen extends ConsumerWidget {
  const TrackListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final parentHeight = constraints.maxHeight;
        final parentWidth = constraints.maxWidth;
        if (parentHeight.isInfinite) return const SizedBox();

        final calculatedHeight = parentHeight * 0.15;
        final double itemHeight = calculatedHeight.clamp(60.0, 150.0);
        final double headerWidth = parentWidth > 600
            ? 220.0
            : parentWidth * 0.35;

        final tracksMap = ref.watch(
          projectProvider.select((s) => s.value?.tracks),
        );
        if (tracksMap == null) return const SizedBox();

        final sortedTracks = tracksMap.values.toList()
          ..sort((a, b) => a.orderIdx.compareTo(b.orderIdx));

        final trackIds = sortedTracks.map((t) => t.id).toList();

        return _SplitTrackView(
          trackIds: trackIds,
          itemHeight: itemHeight,
          headerWidth: headerWidth,
        );
      },
    );
  }
}
