import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/app_state.dart';
import 'package:karbeat/core/utils/logger.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/shared/models/grid.dart';
import 'package:karbeat/src/rust/api/audio.dart';
import 'package:karbeat/src/rust/api/pattern.dart';
import 'package:karbeat/src/rust/api/session.dart' as session_api;

class PianoRollStateData {
  final int? editingPatternId;
  final PianoRollToolSelection tool;
  final double zoomLevelTick;
  final GridSize gridSize;
  final bool snapToGrid;
  final Set<int> selectedNoteIds;
  final int? previewGeneratorId;

  PianoRollStateData({
    this.editingPatternId,
    required this.tool,
    required this.zoomLevelTick,
    required this.gridSize,
    required this.snapToGrid,
    required this.selectedNoteIds,
    this.previewGeneratorId,
  });

  PianoRollStateData copyWith({
    int? editingPatternId,
    PianoRollToolSelection? tool,
    double? zoomLevelTick,
    GridSize? gridSize,
    bool? snapToGrid,
    Set<int>? selectedNoteIds,
    int? previewGeneratorId,
  }) {
    return PianoRollStateData(
      editingPatternId: editingPatternId ?? this.editingPatternId,
      tool: tool ?? this.tool,
      zoomLevelTick: zoomLevelTick ?? this.zoomLevelTick,
      gridSize: gridSize ?? this.gridSize,
      snapToGrid: snapToGrid ?? this.snapToGrid,
      selectedNoteIds: selectedNoteIds ?? this.selectedNoteIds,
      previewGeneratorId: previewGeneratorId ?? this.previewGeneratorId,
    );
  }
}

/// Top-level Riverpod 3.0 provider for Piano Roll Editor State
final pianoRollProvider =
    NotifierProvider<PianoRollNotifier, PianoRollStateData>(
      PianoRollNotifier.new,
    );

class PianoRollNotifier extends Notifier<PianoRollStateData> {
  @override
  PianoRollStateData build() {
    return PianoRollStateData(
      editingPatternId: null,
      tool: PianoRollToolSelection.grab,
      zoomLevelTick: 0.67,
      gridSize: GridSize.quarter,
      snapToGrid: false,
      selectedNoteIds: const {},
      previewGeneratorId: null,
    );
  }

  // ==========================================
  // UI & Workspace Actions
  // ==========================================

  void selectPianoRollTool(PianoRollToolSelection tool) {
    if (state.tool != tool) {
      state = state.copyWith(tool: tool);
    }
  }

  void setZoomLevelTick(double value) {
    final clamped = value.clamp(0.01, 5.0);
    if (state.zoomLevelTick != clamped) {
      state = state.copyWith(zoomLevelTick: clamped);
    }
  }

  void setGridSize(GridSize newSize) {
    if (state.gridSize != newSize) {
      state = state.copyWith(gridSize: newSize);
    }
  }

  void toggleSnapToGrid() {
    state = state.copyWith(snapToGrid: !state.snapToGrid);
  }

  void openPattern(int patternId) {
    // Also clear selection when switching patterns to avoid ghost selections
    state = state.copyWith(
      editingPatternId: patternId,
      selectedNoteIds: const {},
    );
    // Note: Trigger navigation to WorkspaceView.pianoRoll in your router or WorkspaceProvider
  }

  void setPreviewGenerator({int? generatorId}) {
    state = state.copyWith(previewGeneratorId: generatorId);
  }

  // ==========================================
  // Selection Actions
  // ==========================================

  void selectNotes(Set<int> noteIds) {
    state = state.copyWith(selectedNoteIds: noteIds);
  }

  void addNotesToSelection(Set<int> noteIds) {
    state = state.copyWith(
      selectedNoteIds: {...state.selectedNoteIds, ...noteIds},
    );
  }

  void removeNotesFromSelection(Set<int> noteIds) {
    state = state.copyWith(
      selectedNoteIds: state.selectedNoteIds
          .where((id) => !noteIds.contains(id))
          .toSet(),
    );
  }

  void clearNoteSelection() {
    if (state.selectedNoteIds.isNotEmpty) {
      state = state.copyWith(selectedNoteIds: const {});
    }
  }

  // ==========================================
  // Backend Note Actions
  // ==========================================
  // Note: These methods push to Rust, then tell the *ProjectData* provider to update.
  // Replace `ref.read(projectProvider.notifier)` with your actual project data provider.

  Future<Result<void>> previewNote({
    required int trackId,
    required int noteKey,
    required bool isOn,
    int velocity = 0,
  }) async {
    try {
      await playPreviewNote(
        trackId: trackId,
        noteKey: noteKey,
        velocity: velocity,
        isOn: isOn,
      );
      return Result.ok(null);
    } catch (e) {
      AppLogger.error("Error previewing note: $e");
      return Result.error(Exception("$e"));
    }
  }

  Future<Result<void>> addPatternNote({
    required int patternId,
    required int key,
    required int startTick,
    required int duration,
  }) async {
    try {
      await addNote(
        patternId: patternId,
        key: key,
        startTick: startTick,
        duration: duration,
      );
      // ref.read(projectProvider.notifier).syncPattern(patternId);
      return Result.ok(null);
    } catch (e) {
      AppLogger.error("Error adding note: $e");
      return Result.error(Exception("$e"));
    }
  }

  Future<Result<void>> deletePatternNoteBatch({
    required int patternId,
    required List<int> noteIds,
  }) async {
    // ref.read(projectProvider.notifier).applyOptimisticNoteDeletionBatch(patternId, noteIds);
    try {
      await deleteNotesBatch(patternId: patternId, noteIds: noteIds);
      // ref.read(projectProvider.notifier).syncPattern(patternId);
      return Result.ok(null);
    } catch (e) {
      AppLogger.error("Error deleting notes in batch: $e");
      // ref.read(projectProvider.notifier).syncPattern(patternId); // Rollback
      return Result.error(Exception("$e"));
    }
  }

  Future<Result<void>> movePatternNoteBatch({
    required int patternId,
    required List<(int, int, int)> updates,
  }) async {
    try {
      await moveNotesBatch(patternId: patternId, updates: updates);
      // ref.read(projectProvider.notifier).syncPattern(patternId);
      return Result.ok(null);
    } catch (e) {
      AppLogger.error("Error moving notes in batch: $e");
      return Result.error(Exception("$e"));
    }
  }

  // ==========================================
  // Clipboard Actions
  // ==========================================

  Future<void> copyNotesFromPattern(int patternId, List<int> noteIds) async {
    try {
      session_api.copyPatternNotes(patternId: patternId, noteIds: noteIds);
    } catch (e) {
      AppLogger.error(e.toString());
    }
  }

  Future<void> cutNotesFromPattern(int patternId, List<int> noteIds) async {
    // ref.read(projectProvider.notifier).applyOptimisticNoteDeletionBatch(patternId, noteIds);
    clearNoteSelection();

    try {
      await session_api.cutPatternNotes(patternId: patternId, noteIds: noteIds);
      // ref.read(projectProvider.notifier).syncPattern(patternId);
    } catch (e) {
      AppLogger.error(e.toString());
      // ref.read(projectProvider.notifier).syncPattern(patternId); // Rollback
    }
  }

  Future<void> pasteNotesFromClipboardToPattern(
    int targetPatternId,
    int newTickStart,
    int newKey,
  ) async {
    try {
      final pastedNotes = await session_api.pastePatternNotes(
        targetPatternId: targetPatternId,
        playheadTick: newTickStart,
        targetKey: newKey,
      );

      if (pastedNotes.isEmpty) return;

      // ref.read(projectProvider.notifier).applyOptimisticNotePaste(targetPatternId, pastedNotes);

      // Auto-select the newly pasted notes
      selectNotes(pastedNotes.map((n) => n.id).toSet());

      // Trigger background sync to ensure authoritative state
      // ref.read(projectProvider.notifier).syncPattern(targetPatternId);
    } catch (e) {
      AppLogger.error(e.toString());
    }
  }
}
