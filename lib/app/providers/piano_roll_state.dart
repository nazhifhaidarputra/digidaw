import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/core/utils/logger.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/shared/enums/global.dart';
import 'package:karbeat/shared/models/grid.dart';
import 'package:karbeat/src/rust/api/audio.dart';
import 'package:karbeat/src/rust/api/pattern.dart';
import 'package:karbeat/src/rust/api/pattern.dart' as pattern_api;
import 'package:karbeat/src/rust/api/project.dart';
import 'package:karbeat/src/rust/api/session.dart' as session_api;
import 'package:freezed_annotation/freezed_annotation.dart';

part 'piano_roll_state.freezed.dart';

@freezed
abstract class PianoRollStateData with _$PianoRollStateData {
  const factory PianoRollStateData({
    @Default(null) int? editingPatternId,
    @Default(PianoRollToolSelection.grab) PianoRollToolSelection tool,
    @Default(0.67) double zoomLevelTick,
    @Default(GridSize.quarter) GridSize gridSize,
    @Default(false) bool snapToGrid,
    @Default(ISetConst<int>({})) ISet<int> selectedNoteIds,
    @Default(null) int? previewGeneratorId,
  }) = _PianoRollStateData;
}

/// Top-level Riverpod 3.0 provider for Piano Roll Editor State
final pianoRollProvider = NotifierProvider<PianoRollNotifier, PianoRollStateData>(PianoRollNotifier.new);

class PianoRollNotifier extends Notifier<PianoRollStateData> {
  DawContext get _ctx => ref.read(projectProvider.notifier).dawContext;
  ProjectNotifier get _projectNotifier => ref.read(projectProvider.notifier);
  AsyncValue<ApplicationDataStore> get _projectState => ref.read(projectProvider);

  @override
  PianoRollStateData build() {
    return PianoRollStateData(
      editingPatternId: null,
      tool: PianoRollToolSelection.grab,
      zoomLevelTick: 0.67,
      gridSize: GridSize.quarter,
      snapToGrid: false,
      selectedNoteIds: const ISetConst<int>({}),
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
    state = state.copyWith(editingPatternId: patternId, selectedNoteIds: const ISetConst({}));
    // Note: Trigger navigation to WorkspaceView.pianoRoll in your router or WorkspaceProvider
  }

  void setPreviewGenerator({int? generatorId}) {
    state = state.copyWith(previewGeneratorId: generatorId);
  }

  Future<void> syncPatterns() async {
    final newPatternsRes = await AsyncValue.guard(() async {
      final newPatterns = await pattern_api.getPatterns(ctx: _ctx);

      // update the pattern inside the project notifier
      _projectNotifier.upsertPatternBulk(newPatterns);
    });

    if (newPatternsRes.hasError) {
      AppLogger.error("Error when syncing patterns: ${newPatternsRes.error!.toString()}");
    }
  }

  Future<void> syncPattern(int patternId) async {
    final syncPatternRes = await AsyncValue.guard(() async {
      final newPattern = await pattern_api.getPattern(ctx: _ctx, patternId: patternId);
      _projectNotifier.upsertPattern(patternId, newPattern);
    });

    if (syncPatternRes.hasError) {
      AppLogger.error("Error when syncing pattern $patternId: ${syncPatternRes.error!.toString()}");
    }
  }

  // ==========================================
  // Selection Actions
  // ==========================================

  void selectNotes(Iterable<int> noteIds) {
    state = state.copyWith(selectedNoteIds: noteIds.toISet());
  }

  void addNotesToSelection(Iterable<int> noteIds) {
    // O(1) immutable addition
    state = state.copyWith(selectedNoteIds: state.selectedNoteIds.addAll(noteIds));
  }

  void removeNotesFromSelection(Iterable<int> noteIds) {
    // O(1) immutable removal
    state = state.copyWith(selectedNoteIds: state.selectedNoteIds.removeAll(noteIds));
  }

  void clearNoteSelection() {
    if (state.selectedNoteIds.isNotEmpty) {
      state = state.copyWith(selectedNoteIds: const ISetConst({}));
    }
  }

  // ==========================================
  // Backend Note Actions
  // ==========================================
  // Note: These methods push to Rust, then tell the *ProjectData* provider to update.

  Future<Result<void>> previewNote({
    required int trackId,
    required int noteKey,
    required bool isOn,
    int velocity = 0,
  }) async {
    final result = await AsyncValue.guard(
      () => playPreviewNote(ctx: _ctx, trackId: trackId, noteKey: noteKey, velocity: velocity, isOn: isOn),
    );

    if (result.hasError) {
      AppLogger.error("Error previewing note: ${result.error}");
      return Result.error(Exception(result.error.toString()));
    }
    return Result.ok(null);
  }

  Future<Result<void>> addPatternNote({
    required int patternId,
    required int key,
    required int startTick,
    required int duration,
  }) async {
    final result = await AsyncValue.guard(() async {
      await addNote(ctx: _ctx, patternId: patternId, key: key, startTick: startTick, duration: duration);
      syncPattern(patternId);
    });

    if (result.hasError) {
      AppLogger.error("Error adding note: ${result.error}");
      return Result.error(Exception(result.error.toString()));
    }
    return Result.ok(null);
  }

  Future<Result<void>> deletePatternNoteBatch({required int patternId, required List<int> noteIds}) async {
    _applyOptimisticNoteDeletionBatch(patternId, noteIds);

    final result = await AsyncValue.guard(() async {
      await deleteNotesBatch(ctx: _ctx, patternId: patternId, noteIds: noteIds);
      await syncPattern(patternId);
    });

    if (result.hasError) {
      AppLogger.error("Error deleting notes in batch: ${result.error}");
      syncPattern(patternId); // Rollback
      return Result.error(Exception(result.error.toString()));
    }
    return Result.ok(null);
  }

  Future<Result<void>> movePatternNoteBatch({required int patternId, required List<(int, int, int)> updates}) async {
    final result = await AsyncValue.guard(() async {
      await moveNotesBatch(ctx: _ctx, patternId: patternId, updates: updates);
      syncPattern(patternId);
    });

    if (result.hasError) {
      AppLogger.error("Error moving notes in batch: ${result.error}");
      syncPattern(patternId);
      return Result.error(Exception(result.error.toString()));
    }
    return Result.ok(null);
  }

  // ==========================================
  // Clipboard Actions
  // ==========================================

  Future<void> copyNotesFromPattern(int patternId, List<int> noteIds) async {
    final result = await AsyncValue.guard(
      () => session_api.copyPatternNotes(ctx: _ctx, patternId: patternId, noteIds: noteIds),
    );

    if (result.hasError) {
      AppLogger.error(result.error.toString());
    }
  }

  Future<void> cutNotesFromPattern(int patternId, List<int> noteIds) async {
    _applyOptimisticNoteDeletionBatch(patternId, noteIds);
    clearNoteSelection();

    final result = await AsyncValue.guard(() async {
      await session_api.cutPatternNotes(ctx: _ctx, patternId: patternId, noteIds: noteIds);
    });

    if (result.hasError) {
      AppLogger.error(result.error.toString());
    }

    syncPattern(patternId);
  }

  Future<void> pasteNotesFromClipboardToPattern(int targetPatternId, int newTickStart, int newKey) async {
    final result = await AsyncValue.guard(() async {
      final pastedNotes = await session_api.pastePatternNotes(
        ctx: _ctx,
        targetPatternId: targetPatternId,
        playheadTick: newTickStart,
        targetKey: newKey,
      );

      if (pastedNotes.isNotEmpty) {
        _applyOptimisticNotePaste(targetPatternId, pastedNotes);

        // Auto-select the newly pasted notes
        selectNotes(pastedNotes.map((n) => n.id));

        // Trigger background sync to ensure authoritative state
        syncPattern(targetPatternId);
      }
    });

    if (result.hasError) {
      AppLogger.error(result.error.toString());
    }
  }

  void _applyOptimisticNoteDeletionBatch(int patternId, List<int> noteIds) {
    _projectNotifier.removeNotesBulk(patternId, noteIds);
  }

  void _applyOptimisticNotePaste(int patternId, Iterable<UiNote> pastedNotes) {
    final pattern = _projectState.value?.patterns[patternId];
    if (pattern == null) return;

    final newPattern = pattern.copyWith(
      notes: List.of(pattern.notes)..addAll(pastedNotes),
    );

    _projectNotifier.upsertPattern(patternId, newPattern);
  }
}
