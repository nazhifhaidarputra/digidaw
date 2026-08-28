import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/app/providers/notification_provider.dart';
import 'package:karbeat/app/providers/track_list_state.dart';
import 'package:karbeat/app/providers/workspace_state.dart';
import 'package:karbeat/shared/enums/global.dart';
import 'package:karbeat/src/rust/api/project.dart' show DawContext;
import 'package:karbeat/src/rust/api/track.dart';
import 'package:karbeat/core/utils/logger.dart';
import 'package:karbeat/core/utils/result_type.dart';

part 'clip_placement_state.freezed.dart';

enum BatchDragAction { none, move, resizeLeft, resizeRight }

@freezed
abstract class ClipPlacementState with _$ClipPlacementState {
  const factory ClipPlacementState({
    // New clip placement
    int? sourceId,
    UiSourceType? sourceType,
    @Default(-1)
    int trackId, // Used as target track for both new placement and moving
    @Default(0.0) double timeSamples,

    // Existing clip batch drag
    @Default([]) List<int> draggedClipIds,
    @Default(BatchDragAction.none) BatchDragAction dragAction,
    @Default(0) int snappedDeltaTicks,
    @Default(-1) int originalTrackId,
  }) = _ClipPlacementState;
}

extension ClipPlacementHelper on ClipPlacementState {
  bool get isPlacing => sourceId != null;
  bool get isDraggingExisting => dragAction != BatchDragAction.none;
}

class ClipPlacementNotifier extends Notifier<ClipPlacementState> {
  @override
  ClipPlacementState build() {
    return const ClipPlacementState();
  }

  DawContext get _ctx {
    assert(
      ref.read(projectProvider).hasValue,
      "Attempted to access DawContext before ProjectProvider finished loading!",
    );
    return ref.read(projectProvider.notifier).dawContext;
  }

  // --- New Clip Placement Methods ---

  void startPlacement(
    int sourceId, {
    required UiSourceType type,
    int? initialTrackId,
  }) {
    state = state.copyWith(
      sourceId: sourceId,
      sourceType: type,
      trackId: initialTrackId ?? -1, // Spawns on the actual track!
      timeSamples: 0.0, // Spawns exactly at the start of the timeline
    );
    ref
        .read(workspaceStateProvider.notifier)
        .navigateTo(WorkspaceView.trackList);
  }

  void updatePlacementTarget(int trackId, double timeSamples) {
    state = state.copyWith(trackId: trackId, timeSamples: timeSamples);
  }

  void cancelPlacement() {
    state = state.copyWith(sourceId: null, sourceType: null);
  }

  Future<Result<void>> confirmPlacement() async {
    final s = state;
    AppLogger.info("CONFIRM Placement");
    if (s.sourceId != null && s.sourceType != null && s.trackId != -1) {
      try {
        await createClip(
          ctx: _ctx,
          sourceId: s.sourceId!,
          sourceType: s.sourceType!,
          trackId: s.trackId,
          startTime: s.timeSamples.toInt(),
        );
        await ref.read(trackListStateProvider.notifier).syncTrack(s.trackId);
        cancelPlacement();
        return Result.ok(null);
      } catch (e) {
        AppLogger.error("Error creating clip: $e");
        return ref.notifyErrorResult(Exception("$e"));
      }
    }
    return Result.ok(null);
  }

  // --- Existing Clip Drag Methods ---

  void startBatchDrag({
    required List<int> clipIds,
    required BatchDragAction action,
    required int originalTrackId,
  }) {
    state = state.copyWith(
      draggedClipIds: clipIds,
      dragAction: action,
      originalTrackId: originalTrackId,
      trackId: originalTrackId,
      snappedDeltaTicks: 0,
    );
  }

  void updateBatchDrag({
    required int targetTrackId,
    required int snappedDeltaTicks,
  }) {
    state = state.copyWith(
      trackId: targetTrackId,
      snappedDeltaTicks: snappedDeltaTicks,
    );
  }

  void cancelBatchDrag() {
    state = state.copyWith(
      draggedClipIds: [],
      dragAction: BatchDragAction.none,
      originalTrackId: -1,
      trackId: -1,
      snappedDeltaTicks: 0,
    );
  }
}

final clipPlacementProvider =
    NotifierProvider<ClipPlacementNotifier, ClipPlacementState>(
      () => ClipPlacementNotifier(),
    );
