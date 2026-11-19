import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/clip_placement_state.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/app/providers/track_list_state.dart';
import 'package:karbeat/app/providers/transport_state.dart';
import 'package:karbeat/app/providers/workspace_state.dart';
import 'package:karbeat/core/l10n/localizer.dart';
import 'package:karbeat/core/utils/clip_time_utils.dart';
import 'package:karbeat/src/rust/api/project.dart';
import 'package:karbeat/src/rust/api/track.dart' show UiResizeEdge;

/// [clip] as the batch drag [action] would leave it after [deltaTicks], so a
/// ghost shows the result of the edit before it is committed.
UiClip previewDraggedClip(
  UiClip clip, {
  required BatchDragAction action,
  required int deltaTicks,
  required bool stretch,
  required double bpm,
  required int sampleRate,
}) {
  final UiResizeEdge edge;
  switch (action) {
    case BatchDragAction.none:
      return clip;
    case BatchDragAction.move:
      return clip.copyWith(startTime: clip.startTime + deltaTicks);
    case BatchDragAction.resizeLeft:
      edge = UiResizeEdge.left;
    case BatchDragAction.resizeRight:
      edge = UiResizeEdge.right;
  }
  // Only audio stretches; other clips are trimmed or extended.
  return stretch && clip.source is UiClipSource_Audio
      ? stretchResizedClip(clip, edge, deltaTicks, bpm, sampleRate)
      : resizedClip(clip, edge, deltaTicks, bpm, sampleRate);
}

class TrackGhostClip extends ConsumerWidget {
  final int trackId;
  final double trackHeight;
  final double zoomLevel;

  /// Builds the content of a dragged clip's ghost. [clip] is the clip as the
  /// drag would leave it, [left] its x position on the track, and
  /// [contentStretch] the length scale of its audio under a stretching resize.
  final Widget Function(UiClip clip, double left, double contentStretch)
  clipBuilder;

  const TrackGhostClip({
    super.key,
    required this.trackId,
    required this.trackHeight,
    required this.zoomLevel,
    required this.clipBuilder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    // Rows that aren't the placement target select null and stay put while
    // the pointer moves over other rows. A selection drag shows on every row
    // holding part of the selection.
    final placementState = ref.watch(
      clipPlacementProvider.select(
        (s) => s.trackId == trackId || s.isSelectionDrag ? s : null,
      ),
    );
    if (placementState == null) {
      return const Positioned.fill(child: Stack(clipBehavior: Clip.none));
    }

    List<Widget> ghostWidgets = [];

    if (placementState.isSelectionDrag) {
      final selectedIds = ref.watch(
        trackListStateProvider.select((s) => s.clipsSelectedOn(trackId)),
      );
      final track = ref.read(projectProvider).value?.tracks[trackId];
      if (track != null && selectedIds.isNotEmpty) {
        ghostWidgets.addAll(
          _draggedClipGhosts(
            ref,
            clips: track.clips.where((c) => selectedIds.contains(c.id)),
            placementState: placementState,
          ),
        );
      }
    } else if (placementState.trackId == trackId) {
      // ==========================================
      // TYPE 1: NEW CLIP FROM AUDIO/MIDI SOURCE
      // ==========================================
      if (placementState.isPlacing) {
        final left = placementState.startTick / zoomLevel;

        ghostWidgets.add(
          Positioned(
            left: left,
            top: 0,
            width: 150,
            height: trackHeight - 4,
            child: IgnorePointer(
              child: _buildNewGhostBox(colors, opacity: 0.7),
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
            final dragged = placementState.draggedClipIds.toSet();
            ghostWidgets.addAll(
              _draggedClipGhosts(
                ref,
                clips: originalTrack.clips.where((c) => dragged.contains(c.id)),
                placementState: placementState,
              ),
            );
          }
        }
      }
    }

    return Positioned.fill(
      child: Stack(clipBehavior: Clip.none, children: ghostWidgets),
    );
  }

  /// Ghosts of [clips] as the batch drag would leave them.
  Iterable<Widget> _draggedClipGhosts(
    WidgetRef ref, {
    required Iterable<UiClip> clips,
    required ClipPlacementState placementState,
  }) sync* {
    final bpm =
        ref.watch(transportProvider.select((s) => s.value?.state?.bpm)) ??
        120.0;
    final sr =
        ref.watch(transportProvider.select((s) => s.value?.sampleRate)) ??
        48000;
    final stretch = ref.watch(
      workspaceStateProvider.select((s) => s.resizeStretches),
    );

    for (final clip in clips) {
      final preview = previewDraggedClip(
        clip,
        action: placementState.dragAction,
        deltaTicks: placementState.snappedDeltaTicks,
        stretch: stretch,
        bpm: bpm,
        sampleRate: sr,
      );
      final left = preview.startTimeInTicks / zoomLevel;
      final width = preview.loopLengthInTicks(bpm, sr) / zoomLevel;
      final contentStretch =
          stretch && clip.source is UiClipSource_Audio && clip.loopLength > 0
          ? preview.loopLength / clip.loopLength
          : 1.0;

      yield Positioned(
        left: left,
        top: 2,
        width: width < 1 ? 1.0 : width,
        height: trackHeight - 4,
        child: IgnorePointer(
          child: Opacity(
            opacity: 0.7,
            child: clipBuilder(preview, left, contentStretch),
          ),
        ),
      );
    }
  }

  Widget _buildNewGhostBox(ColorScheme colors, {required double opacity}) {
    return Opacity(
      opacity: opacity,
      child: Container(
        width: 150,
        height: trackHeight - 4,
        decoration: BoxDecoration(
          color: colors.primaryContainer,
          border: Border.all(color: colors.primary, width: 2),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(
          child: Text(
            tr('track-place-here'),
            style: TextStyle(
              color: colors.onPrimaryContainer,
              fontWeight: FontWeight.bold,
              shadows: [Shadow(color: colors.shadow, blurRadius: 2)],
            ),
          ),
        ),
      ),
    );
  }
}
