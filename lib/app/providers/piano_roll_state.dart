import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/app/providers/notification_provider.dart';
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
    @Default(false) bool snapToGrid,
    @Default(ISetConst<int>({})) ISet<int> selectedNoteIds,
    @Default(null) int? previewGeneratorId,
    @Default(GridSize.quarter) GridSize pianoRollGridDenom,
  }) = _PianoRollStateData;
}

/// Top-level Riverpod 3.0 provider for Piano Roll Editor State
final pianoRollProvider =
    NotifierProvider<PianoRollNotifier, PianoRollStateData>(
      PianoRollNotifier.new,
    );

class PianoRollNotifier extends Notifier<PianoRollStateData> {
  DawContext get _ctx {
    assert(
      ref.read(projectProvider).hasValue,
      "Attempted to access DawContext before ProjectProvider finished loading!",
    );
    return ref.read(projectProvider.notifier).dawContext;
  }

  ProjectNotifier get _projectNotifier => ref.read(projectProvider.notifier);
  AsyncValue<ApplicationDataStore> get _projectState =>
      ref.read(projectProvider);

  @override
  PianoRollStateData build() {
    return PianoRollStateData(
      editingPatternId: null,
      tool: PianoRollToolSelection.grab,
      zoomLevelTick: 0.67,
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
    if (state.pianoRollGridDenom != newSize) {
      state = state.copyWith(pianoRollGridDenom: newSize);
    }
  }

  void toggleSnapToGrid() {
    state = state.copyWith(snapToGrid: !state.snapToGrid);
  }

  void openPattern(int patternId, {int? previewGeneratorId}) {
    state = state.copyWith(
      editingPatternId: patternId,
      selectedNoteIds: const ISetConst({}),
      previewGeneratorId: previewGeneratorId,
    );
  }

  void clearEditingPattern() {
    state = state.copyWith(
      editingPatternId: null,
      selectedNoteIds: const ISetConst({}),
      previewGeneratorId: null,
    );
  }

  void setPreviewGenerator({int? generatorId}) {
    state = state.copyWith(previewGeneratorId: generatorId);
  }

  Future<void> syncPatterns() async {
    final newPatternsRes = await ref.guardApi(() async {
      final newPatterns = await pattern_api.getPatterns(ctx: _ctx);

      // update the pattern inside the project notifier
      _projectNotifier.upsertPatternBulk(newPatterns);
    });

    if (newPatternsRes.hasError) {
      AppLogger.error(
        "Error when syncing patterns: ${newPatternsRes.error!.toString()}",
      );
    }
  }

  Future<void> syncPattern(int patternId) async {
    final syncPatternRes = await ref.guardApi(() async {
      final newPattern = await pattern_api.getPattern(
        ctx: _ctx,
        patternId: patternId,
      );
      _projectNotifier.upsertPattern(patternId, newPattern);
    });

    if (syncPatternRes.hasError) {
      AppLogger.error(
        "Error when syncing pattern $patternId: ${syncPatternRes.error!.toString()}",
      );
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
    state = state.copyWith(
      selectedNoteIds: state.selectedNoteIds.addAll(noteIds),
    );
  }

  void removeNotesFromSelection(Iterable<int> noteIds) {
    // O(1) immutable removal
    state = state.copyWith(
      selectedNoteIds: state.selectedNoteIds.removeAll(noteIds),
    );
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
      () => playPreviewNote(
        ctx: _ctx,
        trackId: trackId,
        noteKey: noteKey,
        velocity: velocity,
        isOn: isOn,
      ),
    );

    if (result.hasError) {
      AppLogger.error("Error previewing note: ${result.error}");
      return ref.notifyErrorResult(Exception(result.error.toString()));
    }
    return Result.ok(null);
  }

  Future<Result<void>> addPatternNote({
    required int patternId,
    required int key,
    required int startTick,
    required int duration,
  }) async {
    if (!ref.read(projectProvider).hasValue) {
      return ref.notifyErrorResult(
        Exception("projectProvider has not been initialized"),
      );
    }
    final patternToUpdate = ref
        .read(projectProvider)
        .requireValue
        .patterns[patternId];
    if (patternToUpdate == null) {
      return ref.notifyErrorResult(
        Exception("Pattern not found in the project Provider"),
      );
    }
    final result = await AsyncValue.guard(() async {
      final newNote = await addNote(
        ctx: _ctx,
        patternId: patternId,
        key: key,
        startTick: startTick,
        duration: duration,
      );
      // Add this note into the pattern
      ref
          .read(projectProvider.notifier)
          .upsertPattern(
            patternId,
            patternToUpdate.copyWith(
              notes: [...patternToUpdate.notes, newNote],
            ),
          );
    });

    if (result.hasError) {
      AppLogger.error("Error adding note: ${result.error}");
      return ref.notifyErrorResult(Exception(result.error.toString()));
    }
    return Result.ok(null);
  }

  Future<void> addPatternNoteBatch({
    required int patternId,
    required List<(int, int, int?)> notesToInsert,
  }) async {
    if (!ref.read(projectProvider).hasValue) {
      AppLogger.error("projectProvider has not been initialized");
      ref.notifyError('Project provider has not been initialized');
      return;
    }
    final patternToUpdate = ref
        .read(projectProvider)
        .requireValue
        .patterns[patternId];
    if (patternToUpdate == null) {
      AppLogger.error("Pattern not found in the project Provider");
      ref.notifyError('Pattern not found in the project provider');
      return;
    }

    final result = await ref.guardApi(() async {
      final addedNotes = await addNotesBatch(
        ctx: _ctx,
        patternId: patternId,
        notes: notesToInsert,
      );

      // Update notes here and then push into the upsertPattern
      ref
          .read(projectProvider.notifier)
          .upsertPattern(
            patternId,
            patternToUpdate.copyWith(
              notes: [...patternToUpdate.notes, ...addedNotes],
            ),
          );
    });

    if (result.hasError) {
      AppLogger.error(
        "Error when adding note batch in pattern $patternId: ${result.error.toString()}",
      );
    }
  }

  Future<void> deletePatternNote({
    required int patternId,
    required int noteId,
  }) async {
    final pattern = _projectState.value?.patterns[patternId];
    if (pattern == null) {
      AppLogger.error("Pattern not found");
      ref.notifyError('Pattern not found');
      return;
    }
    final result = await ref.guardApi(() async {
      await deleteNote(ctx: _ctx, patternId: patternId, noteId: noteId);

      _projectNotifier.upsertPattern(
        patternId,
        pattern.copyWith(
          notes: pattern.notes.where((note) {
            return note.id != noteId;
          }).toList(),
        ),
      );
    });

    if (result.hasError) {
      AppLogger.error(
        "Error when deleting note $noteId in pattern $patternId: ${result.error.toString()}",
      );
    }
  }

  Future<Result<void>> deletePatternNoteBatch({
    required int patternId,
    required List<int> noteIds,
  }) async {
    // Preserve an in-memory copy of the original pattern for instant rollback
    final patternOriCopy = _projectState.value?.patterns[patternId];
    if (patternOriCopy == null) {
      return ref.notifyErrorResult(Exception("Pattern not found"));
    }

    _applyOptimisticNoteDeletionBatch(patternId, noteIds);

    final result = await AsyncValue.guard(() async {
      await deleteNotesBatch(ctx: _ctx, patternId: patternId, noteIds: noteIds);
    });

    if (result.hasError) {
      AppLogger.error("Error deleting notes in batch: ${result.error}");
      _projectNotifier.upsertPattern(patternId, patternOriCopy);
      return ref.notifyErrorResult(Exception(result.error.toString()));
    }
    return Result.ok(null);
  }

  Future<Result<void>> movePatternNote({
    required int patternId,
    required int noteId,
    required int newStartTick,
    required int newKey,
  }) async {
    final patternOriCopy = _projectState.value?.patterns[patternId];
    if (patternOriCopy == null) {
      return ref.notifyErrorResult(Exception("Pattern not found"));
    }

    // 1. Optimistic Update
    _applyOptimisticNoteMove(patternId, noteId, newStartTick, newKey);

    // 2. Fire FFI
    final result = await AsyncValue.guard(() async {
      await pattern_api.moveNote(
        ctx: _ctx,
        patternId: patternId,
        noteId: noteId,
        newStartTick: newStartTick,
        newKey: newKey,
      );
    });

    // 3. Rollback on Error
    if (result.hasError) {
      AppLogger.error("Error moving note: ${result.error}");
      _projectNotifier.upsertPattern(patternId, patternOriCopy);
      return ref.notifyErrorResult(Exception(result.error.toString()));
    }
    return Result.ok(null);
  }

  Future<Result<void>> movePatternNoteBatch({
    required int patternId,
    required List<(int, int, int)> updates,
  }) async {
    final patternOriCopy = _projectState.value?.patterns[patternId];
    if (patternOriCopy == null) {
      return ref.notifyErrorResult(Exception("Pattern not found"));
    }

    _applyOptimisticNoteMoveBatch(patternId, updates);

    final result = await AsyncValue.guard(() async {
      // Backend applies changes. No need to sync afterwards because we optimistically updated!
      await moveNotesBatch(ctx: _ctx, patternId: patternId, updates: updates);
    });

    if (result.hasError) {
      AppLogger.error("Error moving notes in batch: ${result.error}");
      _projectNotifier.upsertPattern(patternId, patternOriCopy);
      return ref.notifyErrorResult(Exception(result.error.toString()));
    }
    return Result.ok(null);
  }

  // ==========================================
  // Clipboard Actions
  // ==========================================

  Future<void> copyNotesFromPattern(int patternId, List<int> noteIds) async {
    final result = await ref.guardApi(
      () => session_api.copyPatternNotes(
        ctx: _ctx,
        patternId: patternId,
        noteIds: noteIds,
      ),
    );

    if (result.hasError) {
      AppLogger.error(result.error.toString());
    }
  }

  Future<void> cutNotesFromPattern(int patternId, List<int> noteIds) async {
    final patternOriCopy = _projectState.value?.patterns[patternId];
    if (patternOriCopy == null) return;

    _applyOptimisticNoteDeletionBatch(patternId, noteIds);
    clearNoteSelection();

    final result = await ref.guardApi(() async {
      await session_api.cutPatternNotes(
        ctx: _ctx,
        patternId: patternId,
        noteIds: noteIds,
      );
    });

    if (result.hasError) {
      AppLogger.error(result.error.toString());
      // Rollback instantly from memory
      _projectNotifier.upsertPattern(patternId, patternOriCopy);
    }
  }

  Future<Result<void>> resizePatternNote({
    required int patternId,
    required int noteId,
    required int newDuration,
  }) async {
    final patternOriCopy = _projectState.value?.patterns[patternId];
    if (patternOriCopy == null) {
      return ref.notifyErrorResult(Exception("Pattern not found"));
    }

    // 1. Optimistic Update
    _applyOptimisticNoteResize(patternId, noteId, newDuration);

    // 2. Fire FFI
    final result = await AsyncValue.guard(() async {
      await pattern_api.resizeNote(
        ctx: _ctx,
        patternId: patternId,
        noteId: noteId,
        newDuration: newDuration,
      );
    });

    // 3. Rollback on Error
    if (result.hasError) {
      AppLogger.error("Error resizing note: ${result.error}");
      _projectNotifier.upsertPattern(patternId, patternOriCopy);
      return ref.notifyErrorResult(Exception(result.error.toString()));
    }
    return Result.ok(null);
  }

  Future<Result<void>> resizePatternNoteBatch({
    required int patternId,
    required List<(int, int)> updates,
  }) async {
    final patternOriCopy = _projectState.value?.patterns[patternId];
    if (patternOriCopy == null) {
      return ref.notifyErrorResult(Exception("Pattern not found"));
    }

    // 1. Optimistic Update
    _applyOptimisticNoteResizeBatch(patternId, updates);

    // 2. Fire FFI
    final result = await AsyncValue.guard(() async {
      await pattern_api.resizeNotesBatch(
        ctx: _ctx,
        patternId: patternId,
        updates: updates,
      );
    });

    // 3. Rollback on Error
    if (result.hasError) {
      AppLogger.error("Error resizing notes in batch: ${result.error}");
      _projectNotifier.upsertPattern(patternId, patternOriCopy);
      return ref.notifyErrorResult(Exception(result.error.toString()));
    }
    return Result.ok(null);
  }

  Future<void> pasteNotesFromClipboardToPattern(
    int targetPatternId,
    int newTickStart,
    int newKey,
  ) async {
    final result = await ref.guardApi(() async {
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

  void _applyOptimisticNoteMove(
    int patternId,
    int noteId,
    int newStartTick,
    int newKey,
  ) {
    final pattern = _projectState.value?.patterns[patternId];
    if (pattern == null) return;

    final newNotes = pattern.notes.map((n) {
      if (n.id == noteId) {
        return n.copyWith(startTick: newStartTick, key: newKey);
      }
      return n;
    }).toList();

    _projectNotifier.upsertPattern(
      patternId,
      pattern.copyWith(notes: newNotes),
    );
  }

  void _applyOptimisticNoteMoveBatch(
    int patternId,
    List<(int, int, int)> updates,
  ) {
    final pattern = _projectState.value?.patterns[patternId];
    if (pattern == null) return;

    final updateMap = {for (var u in updates) u.$1: u};

    final newNotes = pattern.notes.map((n) {
      final update = updateMap[n.id];
      if (update != null) {
        return n.copyWith(startTick: update.$2, key: update.$3);
      }
      return n;
    }).toList();

    _projectNotifier.upsertPattern(
      patternId,
      pattern.copyWith(notes: newNotes),
    );
  }

  void _applyOptimisticNoteResize(int patternId, int noteId, int newDuration) {
    final pattern = _projectState.value?.patterns[patternId];
    if (pattern == null) return;

    final newNotes = pattern.notes.map((n) {
      if (n.id == noteId) {
        return n.copyWith(duration: newDuration);
      }
      return n;
    }).toList();

    _projectNotifier.upsertPattern(
      patternId,
      pattern.copyWith(notes: newNotes),
    );
  }

  void _applyOptimisticNoteResizeBatch(
    int patternId,
    List<(int, int)> updates,
  ) {
    final pattern = _projectState.value?.patterns[patternId];
    if (pattern == null) return;

    // Map of noteId -> newDuration
    final updateMap = {for (var u in updates) u.$1: u.$2};

    final newNotes = pattern.notes.map((n) {
      final newDuration = updateMap[n.id];
      if (newDuration != null) {
        return n.copyWith(duration: newDuration);
      }
      return n;
    }).toList();

    _projectNotifier.upsertPattern(
      patternId,
      pattern.copyWith(notes: newNotes),
    );
  }
}
