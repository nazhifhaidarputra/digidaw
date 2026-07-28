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

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:karbeat/core/widgets/context_menu.dart';
import 'package:karbeat/core/widgets/daw_input_detector.dart';
import 'package:karbeat/features/track/view/midi_drawer.dart';
import 'package:karbeat/features/track/view/waveform_painter.dart';
import 'package:karbeat/features/track/view/clip_drag_controller.dart';
import 'package:karbeat/features/track/view/playhead.dart';
import 'package:karbeat/shared/models/interaction_target.dart';
import 'package:karbeat/src/rust/api/plugin.dart' show UiPluginInfo;
import 'package:karbeat/src/rust/api/project.dart';
import 'package:karbeat/src/rust/api/track.dart';
import 'package:karbeat/src/rust/api/waveform.dart';
import 'package:karbeat/app/providers/clip_placement_state.dart';
import 'package:karbeat/core/utils/clip_time_utils.dart';
import 'package:karbeat/core/utils/color.dart';
import 'package:karbeat/core/utils/logger.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/core/utils/scroll_behavior.dart';
import 'package:linked_scroll_controller/linked_scroll_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:multi_split_view/multi_split_view.dart';

part 'track_list_split_view.dart';
part 'track_list_timeline_ruler.dart';
part 'track_list_audio_slot.dart';
part 'track_list_interactive_clip.dart';
part 'track_list_clip_renderer.dart';
part 'track_list_grouped_batch_overlay.dart';

// final trackWaveformProvider =
//     Provider.family<Map<int, WaveformHandle>, ({int trackId})>((ref, arg) {
//       // Re-evaluate whenever the track changes (e.g. clips added/removed)
//       ref.watch(projectProvider.select((s) => s.value?.tracks[arg.trackId]));
//       final ctx = ref.read(projectProvider.notifier).dawContext;
//       return getWaveformHandlesForTrack(ctx: ctx, trackId: arg.trackId);
//     });

// /// Tracks whether a track's automation accordion is expanded
// final trackAccordionExpandedProvider = StateProvider.family<bool, int>(
//   (ref, trackId) => true,
// );

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

class _TrackContainer extends ConsumerStatefulWidget {
  @override
  _TrackContainerState createState() {
    return _TrackContainerState();
  }
}

class _TrackContainerState extends ConsumerState<_TrackContainer> {
  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    throw UnimplementedError();
  }
}
