import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/clip_placement_state.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/app/providers/transport_state.dart';
import 'package:karbeat/core/utils/clip_time_utils.dart';

class TrackGhostClip extends ConsumerWidget {
  final int trackId;
  final double trackHeight;
  final double zoomLevel;

  const TrackGhostClip({
    super.key,
    required this.trackId,
    required this.trackHeight,
    required this.zoomLevel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final placementState = ref.watch(clipPlacementProvider);

    List<Widget> ghostWidgets = [];

    if (placementState.trackId == trackId) {
      // ==========================================
      // TYPE 1: NEW CLIP FROM AUDIO/MIDI SOURCE
      // ==========================================
      if (placementState.isPlacing) {
      final left = placementState.timeSamples / zoomLevel;

      ghostWidgets.add(
        Positioned(
          left: left,
          top: 0,
          width: 150,
          height: trackHeight - 4,
          child: IgnorePointer(
            child: _buildNewGhostBox(opacity: 0.7),
          ),
        ),
      );
    }
      // ==========================================
      // TYPE 2: EXISTING CLIP FROM TIMELINE
      // ==========================================
      else if (placementState.isDraggingExisting) {
        final originalTrackId = placementState.originalTrackId;
        final projectState = ref.read(projectProvider).value;

        if (projectState != null && originalTrackId != -1) {
          final originalTrack = projectState.tracks[originalTrackId];

          if (originalTrack != null) {
            final bpm =
                ref.watch(
                  transportProvider.select((s) => s.value?.state?.bpm),
                ) ??
                120.0;
            final sr =
                ref.watch(
                  transportProvider.select((s) => s.value?.sampleRate),
                ) ??
                48000;
            final snappedDelta = placementState.snappedDeltaTicks;

            for (final clipId in placementState.draggedClipIds) {
              final clip = originalTrack.clips
                  .where((c) => c.id == clipId)
                  .firstOrNull;
              if (clip != null) {
                final screenLeft = clip.startTimeInTicks(bpm, sr) / zoomLevel;
                final clipWidth = clip.loopLengthInTicks(bpm, sr) / zoomLevel;

                double activeWidth = clipWidth;
                double activeLeft = screenLeft;

                if (placementState.dragAction == BatchDragAction.resizeRight) {
                  activeWidth += (snappedDelta / zoomLevel);
                } else if (placementState.dragAction ==
                    BatchDragAction.resizeLeft) {
                  activeLeft += (snappedDelta / zoomLevel);
                  activeWidth -= (snappedDelta / zoomLevel);
                } else if (placementState.dragAction == BatchDragAction.move) {
                  activeLeft += (snappedDelta / zoomLevel);
                }

                final safeWidth = activeWidth < 1 ? 1.0 : activeWidth;

                ghostWidgets.add(
                  Positioned(
                    left: activeLeft,
                    top: 0,
                    width: safeWidth,
                    height: trackHeight - 4,
                    child: Draggable<List<int>>(
                      data: placementState.draggedClipIds,
                      feedback: _buildExistingGhostBox(
                        clip.name,
                        safeWidth,
                        0.7,
                      ),
                      childWhenDragging: const SizedBox.shrink(),
                      child: _buildExistingGhostBox(clip.name, safeWidth, 0.7),
                    ),
                  ),
                );
              }
            }
          }
        }
      }
    }

    return Positioned.fill(
      child: Stack(clipBehavior: Clip.none, children: ghostWidgets),
    );
  }

  Widget _buildNewGhostBox({required double opacity}) {
    return Opacity(
      opacity: opacity,
      child: Container(
        width: 150,
        height: trackHeight - 4,
        decoration: BoxDecoration(
          color: Colors.cyanAccent.withAlpha(100),
          border: Border.all(color: Colors.cyanAccent, width: 2),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Center(
          child: Text(
            "Place Here",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              shadows: [Shadow(color: Colors.black, blurRadius: 2)],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExistingGhostBox(String name, double width, double opacity) {
    return Opacity(
      opacity: opacity,
      child: Container(
        width: width,
        height: trackHeight - 4,
        decoration: BoxDecoration(
          color: Colors.cyanAccent.withAlpha(150),
          border: Border.all(color: Colors.cyanAccent, width: 2),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(
          child: Text(
            name,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}
