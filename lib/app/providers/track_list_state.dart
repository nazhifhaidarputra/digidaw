import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/core/utils/color.dart';
import 'package:karbeat/core/utils/logger.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/src/rust/api/project.dart';
import 'package:karbeat/src/rust/api/session.dart' as session_api;
import 'package:karbeat/src/rust/api/track.dart';
import 'package:karbeat/src/rust/api/track.dart' as track_api;

// ============================================================
// State data class
// ============================================================

/// Immutable state for the track list / arranger view.
///
/// Owns the authoritative copy of the track map, clip selection state, and
/// view-specific metadata (track heights, open file path, max sample index).
///
/// All clip mutation actions call the Rust backend and then sync state back
/// via the matching `sync*` helpers, applying optimistic local updates first
/// wherever possible.
class TrackListState {
  /// All loaded tracks keyed by their backend ID.
  final Map<int, UiTrack> tracks;

  /// The track that currently "owns" the clip selection.
  final int? selectedTrackId;

  /// IDs of clips that are currently selected (always from [selectedTrackId]).
  final List<int> selectedClipIds;

  /// The clip that should receive keyboard focus (last clicked).
  final int? focusClipId;

  /// Per-track pixel heights for the arranger rows, keyed by track ID.
  final Map<int, int> trackIdHeightMap;

  const TrackListState({
    this.tracks = const {},
    this.selectedTrackId,
    this.selectedClipIds = const [],
    this.focusClipId,
    this.trackIdHeightMap = const {},
  });

  TrackListState copyWith({
    Map<int, UiTrack>? tracks,
    Object? selectedTrackId = _sentinel,
    List<int>? selectedClipIds,
    Object? focusClipId = _sentinel,
    Map<int, int>? trackIdHeightMap,
    Object? currentFilePath = _sentinel,
  }) {
    return TrackListState(
      tracks: tracks ?? this.tracks,
      selectedTrackId: identical(selectedTrackId, _sentinel) ? this.selectedTrackId : selectedTrackId as int?,
      selectedClipIds: selectedClipIds ?? this.selectedClipIds,
      focusClipId: identical(focusClipId, _sentinel) ? this.focusClipId : focusClipId as int?,
      trackIdHeightMap: trackIdHeightMap ?? this.trackIdHeightMap,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TrackListState &&
        other.tracks == tracks &&
        other.selectedTrackId == selectedTrackId &&
        other.selectedClipIds == selectedClipIds &&
        other.focusClipId == focusClipId &&
        other.trackIdHeightMap == trackIdHeightMap;
  }

  @override
  int get hashCode => Object.hash(tracks, selectedTrackId, selectedClipIds, focusClipId, trackIdHeightMap);
}

const Object _sentinel = Object();

// ============================================================
// Notifier
// ============================================================

/// Riverpod 3 [Notifier] that owns [TrackListState].
///
/// All actions here mirror the track-list / clip methods of [GlobalAppState]
/// and are intended as a drop-in replacement during the slow migration.
class TrackListNotifier extends Notifier<TrackListState> {
  @override
  TrackListState build() => const TrackListState();

  // ------------------------------------------------------------------
  // Synchronisation
  // ------------------------------------------------------------------

  /// Sync the full track map from the backend.
  Future<void> syncTracksState() async {
    try {
      final newTracks = await getTracks();
      state = state.copyWith(tracks: newTracks);
    } catch (e) {
      AppLogger.error('TrackListNotifier: error syncing tracks: $e');
    }
  }

  /// Sync a single track by its backend [trackId].
  Future<void> syncTrackState(int trackId) async {
    try {
      final newTrack = await getTrack(trackId: trackId);
      final newTracks = Map<int, UiTrack>.from(state.tracks);
      newTracks[trackId] = newTrack;
      state = state.copyWith(tracks: newTracks);
    } catch (e) {
      AppLogger.error('TrackListNotifier: error syncing track $trackId: $e');
    }
  }

  /// Sync a single track (creates a new map reference to trigger selectors).
  Future<void> syncTrack(int trackId) async {
    try {
      final updated = await getTrack(trackId: trackId);
      final newTracks = Map<int, UiTrack>.from(state.tracks);
      newTracks[trackId] = updated;
      state = state.copyWith(tracks: newTracks);
    } catch (e) {
      AppLogger.error('TrackListNotifier: error syncing track $trackId: $e');
    }
  }

  // ------------------------------------------------------------------
  // Clip selection
  // ------------------------------------------------------------------

  /// Select a single clip (clears any existing multi-selection).
  void selectClip({required int trackId, required int clipId}) {
    state = state.copyWith(selectedTrackId: trackId, selectedClipIds: [clipId], focusClipId: clipId);
  }

  /// Add a clip to the selection (Ctrl+Click behaviour).
  void addClipToSelection({required int trackId, required int clipId}) {
    // Switching to a different track resets the selection.
    List<int> current = state.selectedClipIds;
    if (state.selectedTrackId != null && state.selectedTrackId != trackId) {
      current = [];
    }
    final updated = current.contains(clipId) ? current : [...current, clipId];
    state = state.copyWith(selectedTrackId: trackId, selectedClipIds: updated, focusClipId: clipId);
  }

  /// Remove a clip from the selection.
  void removeClipFromSelection({required int clipId}) {
    final updated = state.selectedClipIds.where((id) => id != clipId).toList();

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
    state = state.copyWith(
      selectedTrackId: trackId,
      selectedClipIds: List.from(clipIds),
      focusClipId: clipIds.isNotEmpty ? clipIds.last : null,
    );
  }

  /// Clear all clip selection.
  void deselectAllClips() {
    state = state.copyWith(selectedTrackId: null, selectedClipIds: const [], focusClipId: null);
  }

  // ------------------------------------------------------------------
  // Track metadata mutations
  // ------------------------------------------------------------------

  /// Rename a track with optimistic update and backend rollback on failure.
  Future<Result<void>> changeTrackName(int trackId, String newName) async {
    final original = state.tracks[trackId];
    if (original == null) return Result.error(Exception('Track not found'));

    // Optimistic update
    _patchTrack(trackId, name: newName, color: original.color);

    try {
      await track_api.changeTrackName(trackId: trackId, newName: newName);
      return Result.ok(null);
    } catch (e) {
      AppLogger.error('TrackListNotifier: failed to rename track: $e');
      // Rollback
      if (state.tracks.containsKey(trackId)) {
        _patchTrack(trackId, name: original.name, color: original.color);
      }
      return Result.error(Exception('$e'));
    }
  }

  /// Change a track's color with optimistic update and backend rollback.
  Future<Result<void>> changeTrackColor(int trackId, Color newColor) async {
    final original = state.tracks[trackId];
    if (original == null) return Result.error(Exception('Track not found'));

    final colorStr = newColor.toRGBA();
    _patchTrack(trackId, color: colorStr, name: original.name);

    try {
      await track_api.changeTrackColor(trackId: trackId, newColor: colorStr);
      return Result.ok(null);
    } catch (e) {
      AppLogger.error('TrackListNotifier: failed to change track color: $e');
      if (state.tracks.containsKey(trackId)) {
        _patchTrack(trackId, color: original.color, name: original.name);
      }
      return Result.error(Exception('$e'));
    }
  }

  // ------------------------------------------------------------------
  // Clip CRUD
  // ------------------------------------------------------------------

  /// Create an empty MIDI pattern clip on [trackId] at [startTime].
  Future<Result<void>> createEmptyPatternClip({required int trackId, required int startTime}) async {
    try {
      await createClip(sourceType: UiSourceType.midi, trackId: trackId, startTime: startTime);
      await syncTrack(trackId);
      return Result.ok(null);
    } catch (e) {
      AppLogger.error('TrackListNotifier: error creating pattern clip: $e');
      return Result.error(Exception('$e'));
    }
  }

  /// Delete a single clip, with an optimistic local removal.
  Future<Result<void>> deleteClip(int trackId, int clipId) async {
    _optimisticDeleteClips(trackId, {clipId});
    try {
      await track_api.deleteClip(trackId: trackId, clipId: clipId);
      return Result.ok(null);
    } catch (e) {
      AppLogger.error('TrackListNotifier: error deleting clip: $e');
      return Result.error(Exception('$e'));
    }
  }

  /// Slice a clip at [cutPoint] (sample position).
  Future<Result<void>> sliceClip(int trackId, int clipId, int cutPoint) async {
    try {
      await track_api.sliceClip(sourceTrackId: trackId, clipId: clipId, cutPoint: cutPoint);
      await syncTrack(trackId);
      return Result.ok(null);
    } catch (e) {
      AppLogger.error('TrackListNotifier: error slicing clip: $e');
      return Result.error(Exception('$e'));
    }
  }

  /// Resize a clip edge, with an optimistic local update.
  Future<Result<void>> resizeClip(int trackId, int clipId, UiResizeEdge edge, int newTime) async {
    _applyOptimisticResize(trackId, clipId, edge, newTime);
    try {
      await track_api.resizeClip(trackId: trackId, clipId: clipId, edge: edge, newTimeVal: newTime);
      return Result.ok(null);
    } catch (e) {
      AppLogger.error('TrackListNotifier: error resizing clip: $e');
      return Result.error(Exception('$e'));
    }
  }

  /// Move a clip, optionally to a different track, with an optimistic update.
  Future<Result<void>> moveClip(int trackId, int clipId, int newStartTime, {int? newTrackId}) async {
    _applyOptimisticMove(trackId, clipId, newStartTime, newTrackId);
    try {
      await track_api.moveClip(
        sourceTrackId: trackId,
        clipId: clipId,
        newStartTime: newStartTime,
        newTrackId: newTrackId,
      );
      return Result.ok(null);
    } catch (e) {
      AppLogger.error('TrackListNotifier: error moving clip: $e');
      return Result.error(Exception('$e'));
    }
  }

  // ------------------------------------------------------------------
  // Batch clip operations
  // ------------------------------------------------------------------

  /// Move multiple clips by [deltaTicks], with an optimistic update.
  Future<Result<void>> moveClipBatch(int trackId, List<int> clipIds, int deltaTicks, {int? newTrackId}) async {
    _applyOptimisticMoveBatch(trackId, clipIds, deltaTicks, newTrackId);
    try {
      await track_api.moveClipBatch(
        sourceTrackId: trackId,
        clipIds: clipIds,
        deltaTicks: deltaTicks,
        newTrackId: newTrackId,
      );
      return Result.ok(null);
    } catch (e) {
      AppLogger.error('TrackListNotifier: error batch-moving clips: $e');
      return Result.error(Exception('$e'));
    }
  }

  /// Resize multiple clips by [deltaTicks], with an optimistic update.
  Future<Result<void>> resizeClipBatch(int trackId, List<int> clipIds, UiResizeEdge edge, int deltaTicks) async {
    _applyOptimisticResizeBatch(trackId, clipIds, edge, deltaTicks);
    try {
      await track_api.resizeClipBatch(trackId: trackId, clipIds: clipIds, edge: edge, deltaTicks: deltaTicks);
      return Result.ok(null);
    } catch (e) {
      AppLogger.error('TrackListNotifier: error batch-resizing clips: $e');
      return Result.error(Exception('$e'));
    }
  }

  /// Delete multiple clips at once, with an optimistic local removal.
  Future<Result<void>> deleteClipBatch(int trackId, List<int> clipIds) async {
    _optimisticDeleteClips(trackId, clipIds.toSet());
    try {
      await track_api.deleteClipBatch(trackId: trackId, clipIds: clipIds);
      await syncTrack(trackId);
      return Result.ok(null);
    } catch (e) {
      AppLogger.error('TrackListNotifier: error batch-deleting clips: $e');
      return Result.error(Exception('$e'));
    }
  }

  /// Delete all currently selected clips and clear the selection.
  Future<Result<void>> deleteSelectedClips() async {
    final trackId = state.selectedTrackId;
    final clipIds = state.selectedClipIds;
    if (trackId == null || clipIds.isEmpty) return Result.ok(null);
    final result = await deleteClipBatch(trackId, clipIds);
    deselectAllClips();
    return result;
  }

  // ------------------------------------------------------------------
  // Clipboard (clips)
  // ------------------------------------------------------------------

  /// Copy the given clips to the session clipboard.
  Future<Result<void>> copySelectedClips({required int trackId, required List<int> clipIds}) async {
    try {
      await session_api.copyClips(trackId: trackId, clipIds: clipIds);
      return Result.ok(null);
    } catch (e) {
      AppLogger.error('TrackListNotifier: error copying clips: $e');
      return Result.error(Exception('$e'));
    }
  }

  /// Cut the given clips to the session clipboard, with optimistic removal.
  Future<Result<void>> cutSelectedClips({required int trackId, required List<int> clipIds}) async {
    try {
      await session_api.cutClips(trackId: trackId, clipIds: clipIds);
      _optimisticDeleteClips(trackId, clipIds.toSet());
      // Clear selection
      if (state.selectedTrackId == trackId) {
        state = state.copyWith(selectedClipIds: const [], selectedTrackId: null, focusClipId: null);
      }
      return Result.ok(null);
    } catch (e) {
      AppLogger.error('TrackListNotifier: error cutting clips: $e');
      return Result.error(Exception('$e'));
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
        targetTrackId: targetTrackId,
        pasteStartTime: pasteStartTime,
        trackType: trackType,
      );

      if (clips.isEmpty) return Result.ok(null);

      // Optimistic: append pasted clips immediately
      if (state.tracks.containsKey(targetTrackId)) {
        final track = state.tracks[targetTrackId]!;
        final updatedClips = List<UiClip>.from(track.clips)..addAll(clips);
        final newTracks = Map<int, UiTrack>.from(state.tracks);
        newTracks[targetTrackId] = track.copyWith(clips: updatedClips);

        state = state.copyWith(
          tracks: newTracks,
          selectedTrackId: targetTrackId,
          selectedClipIds: clips.map((c) => c.id).toList(),
          focusClipId: clips.last.id,
        );
      }

      // Background sync for authoritative state
      await syncTrack(targetTrackId);
      return Result.ok(null);
    } catch (e) {
      AppLogger.error('TrackListNotifier: error pasting clips: $e');
      return Result.error(Exception('$e'));
    }
  }

  // ------------------------------------------------------------------
  // View metadata (non-backend)
  // ------------------------------------------------------------------

  /// Update the pixel height for a specific track row.
  void setTrackHeight(int trackId, int height) {
    final updated = Map<int, int>.from(state.trackIdHeightMap);
    updated[trackId] = height;
    state = state.copyWith(trackIdHeightMap: updated);
  }

  /// Record the path of the currently open project file.
  void setCurrentFilePath(String? path) {
    state = state.copyWith(currentFilePath: path);
  }

  // ------------------------------------------------------------------
  // Optimistic helpers
  // ------------------------------------------------------------------

  void _patchTrack(int trackId, {required String name, required String color}) {
    final original = state.tracks[trackId];
    if (original == null) return;
    final newTracks = Map<int, UiTrack>.from(state.tracks);
    newTracks[trackId] = original.copyWith(name: name, color: color);
    state = state.copyWith(tracks: newTracks);
  }

  void _optimisticDeleteClips(int trackId, Set<int> clipIdSet) {
    final track = state.tracks[trackId];
    if (track == null) return;
    final updatedClips = track.clips.where((c) => !clipIdSet.contains(c.id)).toList();
    final newTracks = Map<int, UiTrack>.from(state.tracks);
    newTracks[trackId] = track.copyWith(clips: updatedClips);
    state = state.copyWith(tracks: newTracks);
  }

  void _applyOptimisticResize(int trackId, int clipId, UiResizeEdge edge, int newTime) {
    final track = state.tracks[trackId];
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
    updatedClips[clipIndex] = clip.copyWith(startTime: newStart, loopLength: newLength, offsetStart: newOffset);
    final newTracks = Map<int, UiTrack>.from(state.tracks);
    newTracks[trackId] = track.copyWith(clips: updatedClips);
    state = state.copyWith(tracks: newTracks);
  }

  void _applyOptimisticMove(int trackId, int clipId, int newStartTime, int? newTrackId) {
    if (!state.tracks.containsKey(trackId)) return;
    final track = state.tracks[trackId]!;
    final clipIndex = track.clips.indexWhere((c) => c.id == clipId);
    if (clipIndex == -1) return;

    final clip = track.clips[clipIndex];
    final updatedClip = clip.copyWith(startTime: newStartTime);

    final newTracks = Map<int, UiTrack>.from(state.tracks);

    if (newTrackId != null && newTrackId != trackId) {
      if (!state.tracks.containsKey(newTrackId)) return;
      final targetTrack = state.tracks[newTrackId]!;
      final sourceClips = List<UiClip>.from(track.clips)..removeAt(clipIndex);
      final targetClips = List<UiClip>.from(targetTrack.clips)..add(updatedClip);
      newTracks[trackId] = track.copyWith(clips: sourceClips);
      newTracks[newTrackId] = targetTrack.copyWith(clips: targetClips);
    } else {
      final updatedClips = List<UiClip>.from(track.clips);
      updatedClips[clipIndex] = updatedClip;
      newTracks[trackId] = track.copyWith(clips: updatedClips);
    }
    state = state.copyWith(tracks: newTracks);
  }

  void _applyOptimisticMoveBatch(int trackId, List<int> clipIds, int deltaSamples, int? newTrackId) {
    if (!state.tracks.containsKey(trackId)) return;
    final track = state.tracks[trackId]!;
    final targetId = newTrackId ?? trackId;
    if (!state.tracks.containsKey(targetId)) return;
    final targetTrack = state.tracks[targetId]!;

    final clipIdSet = clipIds.toSet();
    final clipsToMove = track.clips.where((c) => clipIdSet.contains(c.id)).toList();

    final newTracks = Map<int, UiTrack>.from(state.tracks);

    if (trackId != targetId) {
      final sourceClips = track.clips.where((c) => !clipIdSet.contains(c.id)).toList();
      final targetClips = List<UiClip>.from(targetTrack.clips);
      for (final clip in clipsToMove) {
        final newStart = (clip.startTime + deltaSamples).clamp(0, 1 << 62);
        targetClips.add(clip.copyWith(startTime: newStart.toInt()));
      }
      newTracks[trackId] = track.copyWith(clips: sourceClips);
      newTracks[targetId] = targetTrack.copyWith(clips: targetClips);
    } else {
      final updatedClips = track.clips.map((clip) {
        if (clipIdSet.contains(clip.id)) {
          final newStart = (clip.startTime + deltaSamples).clamp(0, 1 << 62);
          return clip.copyWith(startTime: newStart.toInt());
        }
        return clip;
      }).toList();
      newTracks[trackId] = track.copyWith(clips: updatedClips);
    }
    state = state.copyWith(tracks: newTracks);
  }

  void _applyOptimisticResizeBatch(int trackId, List<int> clipIds, UiResizeEdge edge, int deltaSamples) {
    if (!state.tracks.containsKey(trackId)) return;
    final track = state.tracks[trackId]!;
    final clipIdSet = clipIds.toSet();

    final updatedClips = track.clips.map((clip) {
      if (!clipIdSet.contains(clip.id)) return clip;
      int newStart = clip.startTime;
      int newLength = clip.loopLength;
      int newOffset = clip.offsetStart;

      if (edge == UiResizeEdge.right) {
        final newEnd = (clip.startTime + clip.loopLength + deltaSamples).clamp(clip.startTime + 100, 1 << 62);
        newLength = newEnd.toInt() - clip.startTime;
      } else {
        final oldEnd = clip.startTime + clip.loopLength;
        int newStartProposed = (clip.startTime + deltaSamples).clamp(0, oldEnd - 100);
        final delta = newStartProposed - clip.startTime;
        final newOffsetProposed = (clip.offsetStart + delta).clamp(0, 1 << 62);
        newStart = newStartProposed.toInt();
        newLength = oldEnd - newStartProposed;
        newOffset = newOffsetProposed.toInt();
      }
      return clip.copyWith(startTime: newStart, loopLength: newLength, offsetStart: newOffset);
    }).toList();

    final newTracks = Map<int, UiTrack>.from(state.tracks);
    newTracks[trackId] = track.copyWith(clips: updatedClips);
    state = state.copyWith(tracks: newTracks);
  }
}

// ============================================================
// Provider
// ============================================================

/// Top-level Riverpod 3 provider for track list state.
///
/// Read: `ref.watch(trackListStateProvider)`
/// Mutate: `ref.read(trackListStateProvider.notifier).syncTracksState()`
final trackListStateProvider = NotifierProvider<TrackListNotifier, TrackListState>(TrackListNotifier.new);
