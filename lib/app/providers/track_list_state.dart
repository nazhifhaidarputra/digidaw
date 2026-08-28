import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:karbeat/app/providers/mixer_state.dart';
import 'package:karbeat/app/providers/notification_provider.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/core/utils/color.dart';
import 'package:karbeat/core/utils/logger.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/src/rust/api/pattern.dart';
import 'package:karbeat/src/rust/api/project.dart';
import 'package:karbeat/src/rust/api/session.dart' as session_api;
import 'package:karbeat/src/rust/api/track.dart';
import 'package:karbeat/src/rust/api/track.dart' as track_api;
import 'package:karbeat/src/rust/api/plugin.dart' as plugin_api;
import 'package:karbeat/src/rust/api/waveform.dart';

part 'track_list_state.freezed.dart';

// ============================================================
// State data class
// ============================================================

/// Immutable state for the track list / arranger view.
///
/// Owns the clip selection state, and
/// view-specific metadata (track heights, open file path, max sample index).
///
/// All clip mutation actions call the Rust backend and then sync state back
/// via the matching `sync*` helpers, applying optimistic local updates first
/// wherever possible.
@freezed
abstract class TrackListState with _$TrackListState {
  const factory TrackListState({
    /// The track that currently "owns" the clip selection.
    int? selectedTrackId,

    /// IDs of clips that are currently selected (always from [selectedTrackId]).
    @Default(IListConst<int>([])) IList<int> selectedClipIds,

    /// The clip that should receive keyboard focus (last clicked).
    int? focusClipId,

    /// Per-track pixel heights for the arranger rows, keyed by track ID.
    @Default(IMapConst<int, int>({})) IMap<int, int> trackIdHeightMap,
  }) = _TrackListState;
}

// ============================================================
// Notifier
// ============================================================

/// Riverpod 3 [Notifier] that owns [TrackListState].
///
/// All actions here mirror the track-list / clip methods of [GlobalAppState]
/// and are intended as a drop-in replacement during the slow migration.
class TrackListNotifier extends Notifier<TrackListState> {
  @override
  TrackListState build() {
    return const TrackListState();
  }

  ProjectNotifier get _projectNotifierRead =>
      ref.read(projectProvider.notifier);
  DawContext get _ctx {
    // Optional: Add a debug assert to catch architectural mistakes early
    assert(
      ref.read(projectProvider).hasValue,
      "Attempted to access DawContext before ProjectProvider finished loading!",
    );
    return ref.read(projectProvider.notifier).dawContext;
  }
  // ------------------------------------------------------------------
  // Synchronisation
  // ------------------------------------------------------------------

  /// Sync a single track by its backend [trackId].
  Future<void> syncTracks() async {
    final result = await ref.guardApi(() async {
      final (newTracksMap, newPatternMap) = await (
        getTracks(ctx: _ctx),
        getPatterns(ctx: _ctx), // Requires the pattern FFI endpoint
      ).wait;
      _projectNotifierRead.upsertTracksBulk(newTracksMap);
      _projectNotifierRead.upsertPatternBulk(newPatternMap);
    });

    return result.value;
  }

  /// Sync a single track (creates a new map reference to trigger selectors).
  Future<void> syncTrack(int trackId) async {
    final res = await ref.guardApi(() async {
      final updatedTrack = await getTrack(ctx: _ctx, trackId: trackId);
      if (updatedTrack == null) {
        AppLogger.warn(
          "Track list state: track not found (id: $trackId), attempting to delete!",
        );
        _projectNotifierRead.removeTrack(trackId);
        return;
      }
      _projectNotifierRead.upsertTrack(trackId, updatedTrack);

      final newPatternMap = await getPatterns(ctx: _ctx);
      _projectNotifierRead.upsertPatternBulk(newPatternMap);
    });

    return res.value;
  }

  IMap<int, UiTrack> getTracksFromProjectProvider() {
    return ref.read(projectProvider).value?.tracks ?? IMap();
  }

  // ------------------------------------------------------------------
  // Clip selection
  // ------------------------------------------------------------------

  /// Select a single clip (clears any existing multi-selection).
  void selectClip({required int trackId, required int clipId}) {
    state = state.copyWith(
      selectedTrackId: trackId,
      selectedClipIds: IList([clipId]),
      focusClipId: clipId,
    );
  }

  /// Add a clip to the selection (Ctrl+Click behaviour).
  void addClipToSelection({required int trackId, required int clipId}) {
    IList<int> current = state.selectedClipIds;

    // Switching to a different track resets the selection.
    if (state.selectedTrackId != null && state.selectedTrackId != trackId) {
      current = IList();
    }

    // O(1) addition if it doesn't exist
    final updated = current.contains(clipId) ? current : current.add(clipId);

    state = state.copyWith(
      selectedTrackId: trackId,
      selectedClipIds: updated,
      focusClipId: clipId,
    );
  }

  /// Remove a clip from the selection.
  void removeClipFromSelection({required int clipId}) {
    final updated = state.selectedClipIds.remove(clipId);

    int? newFocus = state.focusClipId;
    if (newFocus == clipId) {
      newFocus = updated.isNotEmpty ? updated.last : null;
    }

    state = state.copyWith(
      selectedClipIds: updated,
      focusClipId: newFocus,
      selectedTrackId: updated.isEmpty ? null : state.selectedTrackId,
    );
  }

  /// Select a specific set of clips on a given track.
  void selectClips({required int trackId, required List<int> clipIds}) {
    final updated = clipIds.lock;
    state = state.copyWith(
      selectedTrackId: trackId,
      selectedClipIds: updated,
      focusClipId: updated.isNotEmpty ? updated.last : null,
    );
  }

  /// Clear all clip selection.
  void deselectAllClips() {
    state = state.copyWith(
      selectedTrackId: null,
      selectedClipIds: IList(),
      focusClipId: null,
    );
  }

  // ------------------------------------------------------------------
  // Track metadata mutations
  // ------------------------------------------------------------------

  /// Rename a track with optimistic update and backend rollback on failure.
  Future<Result<void>> changeTrackName(int trackId, String newName) async {
    final original = ref.read(projectProvider).value?.tracks[trackId];

    if (original == null) {
      return ref.notifyErrorResult(Exception('Track not found'));
    }

    // Optimistic update
    _patchTrack(trackId, name: newName, color: original.color);

    final result = await AsyncValue.guard(
      () => track_api.changeTrackName(
        ctx: _ctx,
        trackId: trackId,
        newName: newName,
      ),
    );

    if (result.hasError) {
      AppLogger.error(
        'TrackListNotifier: failed to rename track: ${result.error}',
      );
      _patchTrack(
        trackId,
        name: original.name,
        color: original.color,
      ); // Rollback
      return ref.notifyErrorResult(Exception(result.error.toString()));
    }
    return Result.ok(null);
  }

  // ================================================
  // Track CRUD
  // ================================================

  /// Change a track's color with optimistic update and backend rollback.
  Future<Result<void>> changeTrackColor(int trackId, Color newColor) async {
    final original = ref.read(projectProvider).value?.tracks[trackId];
    if (original == null) {
      return ref.notifyErrorResult(Exception('Track not found'));
    }

    final colorStr = newColor.toRGBA();
    _patchTrack(trackId, color: colorStr, name: original.name);

    final result = await AsyncValue.guard(
      () => track_api.changeTrackColor(
        ctx: _ctx,
        trackId: trackId,
        newColor: colorStr,
      ),
    );

    if (result.hasError) {
      AppLogger.error(
        'TrackListNotifier: failed to change track color: ${result.error}',
      );
      _patchTrack(
        trackId,
        color: original.color,
        name: original.name,
      ); // Rollback
      return ref.notifyErrorResult(Exception(result.error.toString()));
    }
    return Result.ok(null);
  }

  Future<AsyncValue<Null>> addAudioTrack() async {
    final createRes = await ref.guardApi(() async {
      final newTrack = await addNewAudioTrack(ctx: _ctx);
      _projectNotifierRead.upsertTrack(newTrack.id, newTrack);
      await ref.read(mixerStateProvider.notifier).syncMixerChannel(newTrack.id);
      await ref.read(mixerStateProvider.notifier).syncRoutingConnection();
    });

    if (createRes.hasError) {
      AppLogger.error(
        'TrackListNotifier: failed to add audio track: ${createRes.error}',
      );
      return AsyncValue.error(
        Exception(createRes.error.toString()),
        createRes.stackTrace!,
      );
    }
    return createRes;
  }

  Future<void> addMidiTrackWithGeneratorId(int id) async {
    final result = await ref.guardApi(() async {
      final newTrack = await track_api.addMidiTrackWithGeneratorId(
        ctx: _ctx,
        registryId: id,
      );
      _projectNotifierRead.upsertTrack(newTrack.id, newTrack);
      if (newTrack.generatorId != null) {
        final generator = await plugin_api.getGenerator(
          ctx: _ctx,
          generatorId: newTrack.generatorId!,
        );
        _projectNotifierRead.upsertGenerator(newTrack.generatorId!, generator);
      }

      await ref.read(mixerStateProvider.notifier).syncMixerChannel(newTrack.id);
      await ref.read(mixerStateProvider.notifier).syncRoutingConnection();
    });

    if (result.hasError) {
      AppLogger.error("Error adding MIDI track: ${result.error}");
    }
  }

  Future<void> deleteTrack({required int trackId}) async {
    final result = await ref.guardApi(() async {
      await track_api.deleteTrack(ctx: _ctx, trackId: trackId);
      _projectNotifierRead.removeTrack(trackId);

      await ref.read(mixerStateProvider.notifier).syncMixerState();
    });

    if (result.hasError) {
      AppLogger.error(
        'TrackListNotifier: failed to delete track: ${result.error}',
      );
    }
  }
  // ------------------------------------------------------------------
  // Clip CRUD
  // ------------------------------------------------------------------

  /// Create an empty MIDI pattern clip on [trackId] at [startTime].
  Future<Result<void>> createEmptyPatternClip({
    required int trackId,
    required int startTime,
  }) async {
    final result = await AsyncValue.guard(() async {
      final newClip = await createClip(
        ctx: _ctx,
        sourceType: UiSourceType.midi,
        trackId: trackId,
        startTime: startTime,
      );
      // await syncTrack(trackId);
      // insert the new clip into the track
      final track = ref.read(projectProvider).value?.tracks[trackId];
      if (track == null) {
        throw Exception("Track not found");
      }

      final updated = track.copyWith(clips: [...track.clips, newClip]);
      _projectNotifierRead.upsertTrack(trackId, updated);

      switch (newClip.source) {
        case UiClipSource_Midi(:final patternId):
          final newPattern = await getPattern(ctx: _ctx, patternId: patternId);
          _projectNotifierRead.upsertPattern(patternId, newPattern);
        default:
      }
    });

    if (result.hasError) {
      AppLogger.error(
        'TrackListNotifier: error creating pattern clip: ${result.error}',
      );
      return ref.notifyErrorResult(Exception(result.error.toString()));
    }
    return Result.ok(null);
  }

  /// Delete a single clip, with an optimistic local removal.
  Future<Result<void>> deleteClip(int trackId, int clipId) async {
    _optimisticDeleteClips(trackId, {clipId});
    final result = await AsyncValue.guard(() async {
      await track_api.deleteClip(ctx: _ctx, trackId: trackId, clipId: clipId);
      syncTrack(trackId);
    });

    if (result.hasError) {
      AppLogger.error(
        'TrackListNotifier: error deleting clip: ${result.error}',
      );
      return ref.notifyErrorResult(Exception(result.error.toString()));
    }
    return Result.ok(null);
  }

  /// Slice a clip at [cutPoint] (sample position).
  Future<Result<void>> sliceClip(int trackId, int clipId, int cutPoint) async {
    final result = await AsyncValue.guard(() async {
      await track_api.sliceClip(
        ctx: _ctx,
        sourceTrackId: trackId,
        clipId: clipId,
        cutPoint: cutPoint,
      );
      await syncTrack(trackId);
    });

    if (result.hasError) {
      AppLogger.error('TrackListNotifier: error slicing clip: ${result.error}');
      return ref.notifyErrorResult(Exception(result.error.toString()));
    }
    return Result.ok(null);
  }

  /// Resize a clip edge, with an optimistic local update.
  Future<Result<void>> resizeClip(
    int trackId,
    int clipId,
    UiResizeEdge edge,
    int newTime,
  ) async {
    _applyOptimisticResize(trackId, clipId, edge, newTime);
    final result = await AsyncValue.guard(
      () => track_api.resizeClip(
        ctx: _ctx,
        trackId: trackId,
        clipId: clipId,
        edge: edge,
        newTimeVal: newTime,
      ),
    );

    if (result.hasError) {
      AppLogger.error(
        'TrackListNotifier: error resizing clip: ${result.error}',
      );
      return ref.notifyErrorResult(Exception(result.error.toString()));
    }
    return Result.ok(null);
  }

  /// Move a clip, optionally to a different track, with an optimistic update.
  Future<Result<void>> moveClip(
    int trackId,
    int clipId,
    int newStartTime, {
    int? newTrackId,
  }) async {
    final validationError = _validateClipMove(
      trackId,
      newTrackId,
      plural: false,
    );
    if (validationError != null) return validationError;

    final tracks = ref.read(projectProvider).value?.tracks;
    final originalSourceTrack = tracks?[trackId];
    final originalTargetTrack = newTrackId == null || newTrackId == trackId
        ? null
        : tracks?[newTrackId];

    _applyOptimisticMove(trackId, clipId, newStartTime, newTrackId);
    final result = await AsyncValue.guard(
      () => track_api.moveClip(
        ctx: _ctx,
        sourceTrackId: trackId,
        clipId: clipId,
        newStartTime: newStartTime,
        newTrackId: newTrackId,
      ),
    );

    if (result.hasError) {
      AppLogger.error('TrackListNotifier: error moving clip: ${result.error}');
      _restoreMovedTracks(
        trackId: trackId,
        sourceTrack: originalSourceTrack,
        targetTrackId: newTrackId,
        targetTrack: originalTargetTrack,
      );
      return ref.notifyErrorResult(Exception(result.error.toString()));
    }
    return Result.ok(null);
  }

  // ------------------------------------------------------------------
  // Batch clip operations
  // ------------------------------------------------------------------

  /// Move multiple clips by [deltaTicks], with an optimistic update.
  Future<Result<void>> moveClipBatch(
    int trackId,
    List<int> clipIds,
    int deltaTicks, {
    int? newTrackId,
  }) async {
    final validationError = _validateClipMove(
      trackId,
      newTrackId,
      plural: true,
    );
    if (validationError != null) return validationError;

    final tracks = ref.read(projectProvider).value?.tracks;
    final originalSourceTrack = tracks?[trackId];
    final originalTargetTrack = newTrackId == null || newTrackId == trackId
        ? null
        : tracks?[newTrackId];

    _applyOptimisticMoveBatch(trackId, clipIds, deltaTicks, newTrackId);
    final result = await AsyncValue.guard(
      () => track_api.moveClipBatch(
        ctx: _ctx,
        sourceTrackId: trackId,
        clipIds: clipIds,
        deltaTicks: deltaTicks,
        newTrackId: newTrackId,
      ),
    );

    if (result.hasError) {
      AppLogger.error(
        'TrackListNotifier: error batch-moving clips: ${result.error}',
      );
      _restoreMovedTracks(
        trackId: trackId,
        sourceTrack: originalSourceTrack,
        targetTrackId: newTrackId,
        targetTrack: originalTargetTrack,
      );
      return ref.notifyErrorResult(Exception(result.error.toString()));
    }
    return Result.ok(null);
  }

  /// Resize multiple clips by [deltaTicks], with an optimistic update.
  Future<Result<void>> resizeClipBatch(
    int trackId,
    List<int> clipIds,
    UiResizeEdge edge,
    int deltaTicks,
  ) async {
    _applyOptimisticResizeBatch(trackId, clipIds, edge, deltaTicks);
    final result = await AsyncValue.guard(
      () => track_api.resizeClipBatch(
        ctx: _ctx,
        trackId: trackId,
        clipIds: clipIds,
        edge: edge,
        deltaTicks: deltaTicks,
      ),
    );

    if (result.hasError) {
      AppLogger.error(
        'TrackListNotifier: error batch-resizing clips: ${result.error}',
      );
      return ref.notifyErrorResult(Exception(result.error.toString()));
    }
    return Result.ok(null);
  }

  /// Atomically duplicate a selected clip group at predetermined start times.
  /// Start times are in the clips' native unit (samples or ticks). Unlike the
  /// clipboard APIs below, this operation never changes ClipboardContent.
  Future<Result<List<UiClip>>> duplicateClipGroups({
    required int trackId,
    required List<int> clipIds,
    required List<int> groupStartTimes,
  }) async {
    if (clipIds.isEmpty || groupStartTimes.isEmpty) {
      return Result.ok(const []);
    }

    try {
      final duplicated = await track_api.duplicateClipGroups(
        ctx: _ctx,
        trackId: trackId,
        clipIds: clipIds,
        groupStartTimes: groupStartTimes,
      );
      if (duplicated.isEmpty) return Result.ok(const []);

      final track = ref.read(projectProvider).value?.tracks[trackId];
      if (track == null) {
        await syncTrack(trackId);
      } else {
        _projectNotifierRead.upsertTrack(
          trackId,
          track.copyWith(clips: [...track.clips, ...duplicated]),
        );
      }

      return Result.ok(duplicated);
    } catch (error) {
      AppLogger.error(
        'TrackListNotifier: error atomically duplicating clip groups: $error',
      );
      return ref.notifyErrorResult(Exception(error.toString()));
    }
  }

  /// Delete multiple clips at once, with an optimistic local removal.
  Future<Result<void>> deleteClipBatch(int trackId, List<int> clipIds) async {
    _optimisticDeleteClips(trackId, clipIds.toSet());

    final result = await AsyncValue.guard(() async {
      await track_api.deleteClipBatch(
        ctx: _ctx,
        trackId: trackId,
        clipIds: clipIds,
      );
      await syncTrack(trackId);
    });

    if (result.hasError) {
      AppLogger.error(
        'TrackListNotifier: error batch-deleting clips: ${result.error}',
      );
      return ref.notifyErrorResult(Exception(result.error.toString()));
    }
    return Result.ok(null);
  }

  /// Delete all currently selected clips and clear the selection.
  Future<Result<void>> deleteSelectedClips() async {
    final trackId = state.selectedTrackId;
    final clipIds = state.selectedClipIds;
    if (trackId == null || clipIds.isEmpty) return Result.ok(null);
    final result = await deleteClipBatch(trackId, clipIds.toList());
    deselectAllClips();
    return result;
  }

  // ------------------------------------------------------------------
  // Clipboard (clips)
  // ------------------------------------------------------------------

  /// Copy the given clips to the session clipboard.
  Future<Result<void>> copySelectedClips({
    required int trackId,
    required List<int> clipIds,
  }) async {
    try {
      await session_api.copyClips(
        ctx: _ctx,
        trackId: trackId,
        clipIds: clipIds,
      );
      return Result.ok(null);
    } catch (e) {
      AppLogger.error('TrackListNotifier: error copying clips: $e');
      return ref.notifyErrorResult(Exception('$e'));
    }
  }

  /// Cut the given clips to the session clipboard, with optimistic removal.
  Future<Result<void>> cutSelectedClips({
    required int trackId,
    required List<int> clipIds,
  }) async {
    try {
      await session_api.cutClips(ctx: _ctx, trackId: trackId, clipIds: clipIds);
      _optimisticDeleteClips(trackId, clipIds.toSet());
      // Clear selection
      if (state.selectedTrackId == trackId) {
        state = state.copyWith(
          selectedClipIds: IList(),
          selectedTrackId: null,
          focusClipId: null,
        );
      }
      return Result.ok(null);
    } catch (e) {
      AppLogger.error('TrackListNotifier: error cutting clips: $e');
      return ref.notifyErrorResult(Exception('$e'));
    }
  }

  /// Paste clips from the session clipboard onto [targetTrackId].
  Future<Result<void>> pasteClips({
    required int targetTrackId,
    required int pasteStartTime,
    required UiTrackType trackType,
  }) async {
    try {
      final clips = await session_api.pasteClips(
        ctx: _ctx,
        targetTrackId: targetTrackId,
        pasteStartTime: pasteStartTime,
        trackType: trackType,
      );

      if (clips.isEmpty) return Result.ok(null);

      // Optimistic: append pasted clips directly into central state
      final currentTracks = ref.read(projectProvider).value?.tracks;
      if (currentTracks != null && currentTracks.containsKey(targetTrackId)) {
        final track = currentTracks[targetTrackId]!;
        final updatedClips = List<UiClip>.from(track.clips)..addAll(clips);

        ref
            .read(projectProvider.notifier)
            .upsertTrack(targetTrackId, track.copyWith(clips: updatedClips));

        state = state.copyWith(
          selectedTrackId: targetTrackId,
          selectedClipIds: clips.map((c) => c.id).toIList(),
          focusClipId: clips.last.id,
        );
      }

      // Background sync for authoritative state
      await syncTrack(targetTrackId);
      return Result.ok(null);
    } catch (e) {
      AppLogger.error('TrackListNotifier: error pasting clips: $e');
      return ref.notifyErrorResult(Exception('$e'));
    }
  }

  Future<void> handleUpdateTrackOrder({
    required WidgetRef ref,
    required int trackId,
    required int newIdx,
  }) async {}

  // ------------------------------------------------------------------
  // View metadata (non-backend)
  // ------------------------------------------------------------------

  /// Update the pixel height for a specific track row.
  void setTrackHeight(int trackId, int height) {
    state = state.copyWith(
      trackIdHeightMap: state.trackIdHeightMap.add(trackId, height),
    );
  }

  // ------------------------------------------------------------------
  // Optimistic helpers
  // ------------------------------------------------------------------

  void _patchTrack(int trackId, {required String name, required String color}) {
    final original = ref.read(projectProvider).value?.tracks[trackId];
    if (original == null) return;

    ref
        .read(projectProvider.notifier)
        .upsertTrack(trackId, original.copyWith(name: name, color: color));
  }

  void _optimisticDeleteClips(int trackId, Set<int> clipIdSet) {
    final track = ref.read(projectProvider).value?.tracks[trackId];
    if (track == null) return;
    final updatedClips = track.clips
        .where((c) => !clipIdSet.contains(c.id))
        .toList();
    ref
        .read(projectProvider.notifier)
        .upsertTrack(trackId, track.copyWith(clips: updatedClips));
  }

  void _applyOptimisticResize(
    int trackId,
    int clipId,
    UiResizeEdge edge,
    int newTime,
  ) {
    final track = ref.read(projectProvider).value?.tracks[trackId];
    if (track == null) return;
    final clipIndex = track.clips.indexWhere((c) => c.id == clipId);
    if (clipIndex == -1) return;
    final clip = track.clips[clipIndex];

    int newStart = clip.startTime.toInt();
    int newLength = clip.loopLength.toInt();
    int newOffset = clip.offsetStart.toInt();

    if (edge == UiResizeEdge.right) {
      if (newTime > clip.startTime) newLength = newTime - clip.startTime;
    } else {
      final oldEnd = clip.startTime + clip.loopLength;
      if (newTime < oldEnd) {
        final delta = newTime - clip.startTime;
        final potentialOffset = clip.offsetStart + delta;
        if (potentialOffset >= 0) {
          newStart = newTime;
          newLength = oldEnd - newTime;
          newOffset = potentialOffset.toInt();
        }
      }
    }

    final updatedClips = List<UiClip>.from(track.clips);
    updatedClips[clipIndex] = clip.copyWith(
      startTime: newStart,
      loopLength: newLength,
      offsetStart: newOffset,
    );
    ref
        .read(projectProvider.notifier)
        .upsertTrack(trackId, track.copyWith(clips: updatedClips));
  }

  Result<void>? _validateClipMove(
    int sourceTrackId,
    int? targetTrackId, {
    required bool plural,
  }) {
    if (targetTrackId == null || targetTrackId == sourceTrackId) return null;

    final tracks = ref.read(projectProvider).value?.tracks;
    final sourceTrack = tracks?[sourceTrackId];
    final targetTrack = tracks?[targetTrackId];

    if (sourceTrack == null) {
      return ref.notifyErrorResult<void>(Exception('Source track not found'));
    }
    if (targetTrack == null) {
      return ref.notifyErrorResult<void>(Exception('Target track not found'));
    }
    if (sourceTrack.trackType == targetTrack.trackType) return null;

    final clipLabel = plural ? 'clips' : 'clip';
    final sourceLabel = _trackTypeLabel(sourceTrack.trackType);
    final targetLabel = _trackTypeLabel(targetTrack.trackType);
    return ref.notifyErrorResult<void>(
      Exception('Cannot move $sourceLabel $clipLabel to $targetLabel track'),
    );
  }

  String _trackTypeLabel(UiTrackType type) => switch (type) {
    UiTrackType.audio => 'audio',
    UiTrackType.midi => 'MIDI',
    UiTrackType.automation => 'automation',
  };

  void _restoreMovedTracks({
    required int trackId,
    required UiTrack? sourceTrack,
    required int? targetTrackId,
    required UiTrack? targetTrack,
  }) {
    final restoredTracks = <int, UiTrack>{};
    if (sourceTrack != null) restoredTracks[trackId] = sourceTrack;
    if (targetTrackId != null &&
        targetTrackId != trackId &&
        targetTrack != null) {
      restoredTracks[targetTrackId] = targetTrack;
    }
    if (restoredTracks.isNotEmpty) {
      ref.read(projectProvider.notifier).upsertTracksBulk(restoredTracks);
    }
  }

  void _applyOptimisticMove(
    int trackId,
    int clipId,
    int newStartTime,
    int? newTrackId,
  ) {
    final tracks = ref.read(projectProvider).value?.tracks;
    if (tracks == null) return;

    final track = tracks[trackId];
    if (track == null) return;

    final clipIndex = track.clips.indexWhere((c) => c.id == clipId);
    if (clipIndex == -1) return;

    final clip = track.clips[clipIndex];
    final updatedClip = clip.copyWith(startTime: newStartTime);

    if (newTrackId != null && newTrackId != trackId) {
      final targetTrack = tracks[newTrackId];
      if (targetTrack == null) return;

      final sourceClips = List<UiClip>.from(track.clips)..removeAt(clipIndex);
      final targetClips = List<UiClip>.from(targetTrack.clips)
        ..add(updatedClip);

      ref.read(projectProvider.notifier).upsertTracksBulk({
        trackId: track.copyWith(clips: sourceClips),
        newTrackId: targetTrack.copyWith(clips: targetClips),
      });
    } else {
      final updatedClips = List<UiClip>.from(track.clips);
      updatedClips[clipIndex] = updatedClip;
      ref
          .read(projectProvider.notifier)
          .upsertTrack(trackId, track.copyWith(clips: updatedClips));
    }
  }

  void _applyOptimisticMoveBatch(
    int trackId,
    List<int> clipIds,
    int deltaSamples,
    int? newTrackId,
  ) {
    final tracks = ref.read(projectProvider).value?.tracks;
    if (tracks == null) return;

    final track = tracks[trackId];
    final targetId = newTrackId ?? trackId;
    final targetTrack = tracks[targetId];
    if (track == null || targetTrack == null) return;

    final clipIdSet = clipIds.toSet();
    final clipsToMove = track.clips
        .where((c) => clipIdSet.contains(c.id))
        .toList();

    if (trackId != targetId) {
      final sourceClips = track.clips
          .where((c) => !clipIdSet.contains(c.id))
          .toList();
      final targetClips = List<UiClip>.from(targetTrack.clips);
      for (final clip in clipsToMove) {
        final newStart = (clip.startTime + deltaSamples).clamp(0, 1 << 62);
        targetClips.add(clip.copyWith(startTime: newStart.toInt()));
      }
      ref.read(projectProvider.notifier).upsertTracksBulk({
        trackId: track.copyWith(clips: sourceClips),
        targetId: targetTrack.copyWith(clips: targetClips),
      });
    } else {
      final updatedClips = track.clips.map((clip) {
        if (clipIdSet.contains(clip.id)) {
          final newStart = (clip.startTime + deltaSamples).clamp(0, 1 << 62);
          return clip.copyWith(startTime: newStart.toInt());
        }
        return clip;
      }).toList();
      ref
          .read(projectProvider.notifier)
          .upsertTrack(trackId, track.copyWith(clips: updatedClips));
    }
  }

  void _applyOptimisticResizeBatch(
    int trackId,
    List<int> clipIds,
    UiResizeEdge edge,
    int deltaSamples,
  ) {
    final track = ref.read(projectProvider).value?.tracks[trackId];
    if (track == null) return;

    final clipIdSet = clipIds.toSet();

    final updatedClips = track.clips.map((clip) {
      if (!clipIdSet.contains(clip.id)) return clip;
      int newStart = clip.startTime.toInt();
      int newLength = clip.loopLength.toInt();
      int newOffset = clip.offsetStart.toInt();

      if (edge == UiResizeEdge.right) {
        final newEnd = (clip.startTime + clip.loopLength + deltaSamples).clamp(
          clip.startTime + 100,
          1 << 62,
        );
        newLength = newEnd.toInt() - clip.startTime.toInt();
      } else {
        final oldEnd = clip.startTime + clip.loopLength;
        int newStartProposed = (clip.startTime + deltaSamples)
            .clamp(0, oldEnd - 100)
            .toInt();
        final delta = newStartProposed - clip.startTime;
        final newOffsetProposed = (clip.offsetStart + delta).clamp(0, 1 << 62);
        newStart = newStartProposed;
        newLength = (oldEnd - newStartProposed).toInt();
        newOffset = newOffsetProposed.toInt();
      }
      return clip.copyWith(
        startTime: newStart,
        loopLength: newLength,
        offsetStart: newOffset,
      );
    }).toList();

    ref
        .read(projectProvider.notifier)
        .upsertTrack(trackId, track.copyWith(clips: updatedClips));
  }
}

// ============================================================
// Provider
// ============================================================

/// Top-level Riverpod 3 provider for track list state.
///
/// Read: `ref.watch(trackListStateProvider)`
/// Mutate: `ref.read(trackListStateProvider.notifier).syncTracksState()`
final trackListStateProvider =
    NotifierProvider<TrackListNotifier, TrackListState>(TrackListNotifier.new);

final trackWaveformProvider =
    Provider.family<Map<int, WaveformHandle>, ({int trackId})>((ref, arg) {
      ref.watch(projectProvider.select((s) => s.value?.tracks[arg.trackId]));
      final ctx = ref.read(projectProvider.notifier).dawContext;
      return getWaveformHandlesForTrack(ctx: ctx, trackId: arg.trackId);
    });
