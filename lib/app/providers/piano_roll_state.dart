import 'dart:math';

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
import 'package:karbeat/src/rust/api/transport.dart' as transport_api;
import 'package:freezed_annotation/freezed_annotation.dart';

part 'piano_roll_state.freezed.dart';

/// Default horizontal zoom, in pixels per tick: one bar spans about 580 pixels.
const defaultPianoRollZoom = 0.15;

/// Smallest and largest piano-roll row height, in pixels.
const minPianoRollKeyHeight = 8.0;
const maxPianoRollKeyHeight = 60.0;

/// Ticks per 4/4 bar at 960 PPQ.
const _ticksPerBar = 3840;

/// Ticks spanned by one [size] cell; 1 for [GridSize.infinity] (no snapping).
int ticksForGrid(GridSize size) =>
    size == GridSize.infinity ? 1 : (_ticksPerBar / size.value).round();

/// A pattern playback loop between two ticks.
@freezed
abstract class PatternLoopRegion with _$PatternLoopRegion {
  const factory PatternLoopRegion({
    required int startTick,
    required int endTick,
  }) = _PatternLoopRegion;
}

@freezed
abstract class PianoRollStateData with _$PianoRollStateData {
  const PianoRollStateData._();

  const factory PianoRollStateData({
    @Default(null) int? editingPatternId,
    @Default(PianoRollToolSelection.grab) PianoRollToolSelection tool,
    @Default(defaultPianoRollZoom) double zoomLevelTick,
    @Default(false) bool snapToGrid,
    @Default(ISetConst<int>({})) ISet<int> selectedNoteIds,
    @Default(null) int? previewGeneratorId,

    /// Visual grid drawn behind the notes.
    @Default(GridSize.quarter) GridSize pianoRollGridDenom,

    /// Step that drawing, moving, and resizing snap to, or null to follow the
    /// grid, so a one-beat grid can still place half-beat notes.
    @Default(null) GridSize? drawStep,

    /// Height of one key row, in pixels.
    @Default(20.0) double keyHeight,

    /// Loop region for pattern playback; the whole pattern loops when null.
    @Default(null) PatternLoopRegion? loopRegion,

    /// Notes the draw tool stamps: the latest selection, like FL Studio.
    @Default(IListConst<UiNote>([])) IList<UiNote> drawTemplate,
  }) = _PianoRollStateData;

  /// Step used for drawing, moving, and resizing.
  GridSize get effectiveStep => drawStep ?? pianoRollGridDenom;

  /// Snap distance in ticks for drawing, moving, and resizing.
  int get stepTicks => ticksForGrid(effectiveStep);

  /// Step for quantize, chop, and shift: the draw step, falling back to the
  /// grid and then to a sixteenth note when both are off.
  int get transformStepTicks {
    for (final size in [effectiveStep, pianoRollGridDenom]) {
      if (size != GridSize.infinity) return ticksForGrid(size);
    }
    return ticksForGrid(GridSize.sixteenth);
  }
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
  PianoRollStateData build() => const PianoRollStateData();

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

  /// Sets the drawing/moving step, or follows the grid when [step] is null.
  void setDrawStep(GridSize? step) {
    if (state.drawStep != step) state = state.copyWith(drawStep: step);
  }

  void setKeyHeight(double height) {
    final clamped = height.clamp(minPianoRollKeyHeight, maxPianoRollKeyHeight);
    if (state.keyHeight != clamped) {
      state = state.copyWith(keyHeight: clamped);
    }
  }

  void scaleKeyHeight(double factor) => setKeyHeight(state.keyHeight * factor);

  void openPattern(int patternId, {int? previewGeneratorId}) {
    final changed = state.editingPatternId != patternId;
    state = state.copyWith(
      editingPatternId: patternId,
      selectedNoteIds: const ISetConst({}),
      previewGeneratorId: previewGeneratorId,
      loopRegion: changed ? null : state.loopRegion,
      drawTemplate: changed ? const IListConst([]) : state.drawTemplate,
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

  Future<Result<void>> renamePattern({
    required int patternId,
    required String newName,
  }) async {
    final project = _projectState.value;
    final pattern = project?.patterns[patternId];
    if (project == null || pattern == null) {
      return ref.notifyErrorResult(Exception("Pattern not found"));
    }

    final result = await AsyncValue.guard(
      () => pattern_api.renamePattern(
        ctx: _ctx,
        patternId: patternId,
        newName: newName,
      ),
    );
    if (result.hasError) {
      AppLogger.error("Error renaming pattern: ${result.error}");
      return ref.notifyErrorResult(Exception(result.error.toString()));
    }

    _projectNotifier.upsertPattern(patternId, pattern.copyWith(name: newName));
    for (final entry in project.tracks.entries) {
      var changed = false;
      final clips = entry.value.clips.map((clip) {
        final usesPattern = switch (clip.source) {
          UiClipSource_Midi(patternId: final clipPatternId) =>
            clipPatternId == patternId,
          _ => false,
        };
        if (usesPattern && clip.name == pattern.name) {
          changed = true;
          return clip.copyWith(name: newName);
        }
        return clip;
      }).toList();

      if (changed) {
        _projectNotifier.upsertTrack(
          entry.key,
          entry.value.copyWith(clips: clips),
        );
      }
    }

    return Result.ok(null);
  }

  // ==========================================
  // Selection Actions
  // ==========================================

  void selectNotes(Iterable<int> noteIds) {
    final selection = noteIds.toISet();
    state = state.copyWith(
      selectedNoteIds: selection,
      drawTemplate: _templateFor(selection) ?? state.drawTemplate,
    );
  }

  void addNotesToSelection(Iterable<int> noteIds) {
    // O(1) immutable addition
    final selection = state.selectedNoteIds.addAll(noteIds);
    state = state.copyWith(
      selectedNoteIds: selection,
      drawTemplate: _templateFor(selection) ?? state.drawTemplate,
    );
  }

  /// Notes the draw tool stamps after [selection], or null to keep the
  /// current template when nothing is selected.
  IList<UiNote>? _templateFor(ISet<int> selection) {
    final patternId = state.editingPatternId;
    if (selection.isEmpty || patternId == null) return null;
    final notes = _projectState.value?.patterns[patternId]?.notes ?? const [];
    final template = notes.where((note) => selection.contains(note.id));
    return template.isEmpty ? null : template.toIList();
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

  // ==========================================
  // Note Transforms
  // ==========================================
  // Each applies to the selection, or to the whole pattern when nothing is
  // selected, is one undo step, and republishes the pattern the backend returns.

  List<int> get _targetNoteIds => state.selectedNoteIds.toList();

  Future<Result<void>> _transformPattern(
    String action,
    Future<UiPattern> Function(DawContext ctx, int patternId) transform,
  ) async {
    final patternId = state.editingPatternId;
    if (patternId == null) {
      return ref.notifyErrorResult(Exception('No pattern is open'));
    }
    final result = await AsyncValue.guard(() => transform(_ctx, patternId));
    if (result case AsyncData(:final value)) {
      _projectNotifier.upsertPattern(patternId, value);
      return Result.ok(null);
    }
    AppLogger.error('Could not $action notes: ${result.error}');
    return ref.notifyErrorResult(
      result.error ?? Exception('Unknown error'),
      title: 'Could not $action notes',
    );
  }

  Future<Result<void>> quantizeNotes() => _transformPattern(
    'quantize',
    (ctx, patternId) => pattern_api.quantizeNotes(
      ctx: ctx,
      patternId: patternId,
      noteIds: _targetNoteIds,
      stepTicks: state.transformStepTicks,
    ),
  );

  Future<Result<void>> quantizeNoteStarts() => _transformPattern(
    'quantize',
    (ctx, patternId) => pattern_api.quantizeNoteStarts(
      ctx: ctx,
      patternId: patternId,
      noteIds: _targetNoteIds,
      stepTicks: state.transformStepTicks,
    ),
  );

  Future<Result<void>> legatoNotes() => _transformPattern(
    'legato',
    (ctx, patternId) => pattern_api.legatoNotes(
      ctx: ctx,
      patternId: patternId,
      noteIds: _targetNoteIds,
    ),
  );

  /// Nudges timing by up to a quarter step and velocity by up to 12.
  Future<Result<void>> humanizeNotes() => _transformPattern(
    'humanize',
    (ctx, patternId) => pattern_api.humanizeNotes(
      ctx: ctx,
      patternId: patternId,
      noteIds: _targetNoteIds,
      timingTicks: max(1, state.transformStepTicks ~/ 4),
      velocityAmount: 12,
      seed: DateTime.now().microsecondsSinceEpoch,
    ),
  );

  Future<Result<void>> chopNotes() => _transformPattern(
    'chop',
    (ctx, patternId) => pattern_api.chopNotes(
      ctx: ctx,
      patternId: patternId,
      noteIds: _targetNoteIds,
      stepTicks: state.transformStepTicks,
    ),
  );

  Future<Result<void>> sliceNote({required int noteId, required int atTick}) =>
      _transformPattern(
        'slice',
        (ctx, patternId) => pattern_api.sliceNote(
          ctx: ctx,
          patternId: patternId,
          noteId: noteId,
          atTick: atTick,
        ),
      );

  Future<Result<void>> transposeNotes(int semitones) => _transformPattern(
    'transpose',
    (ctx, patternId) => pattern_api.transposeNotes(
      ctx: ctx,
      patternId: patternId,
      noteIds: _targetNoteIds,
      semitones: semitones,
    ),
  );

  /// Moves notes by [steps] draw steps; negative moves earlier.
  Future<Result<void>> shiftNotes(int steps) => _transformPattern(
    'shift',
    (ctx, patternId) => pattern_api.shiftNotes(
      ctx: ctx,
      patternId: patternId,
      noteIds: _targetNoteIds,
      deltaTicks: steps * state.transformStepTicks,
    ),
  );

  Future<Result<void>> setNoteParams(List<UiNoteParamUpdate> updates) =>
      _transformPattern(
        'edit',
        (ctx, patternId) => pattern_api.setNoteParamsBatch(
          ctx: ctx,
          patternId: patternId,
          updates: updates,
        ),
      );

  /// Inserts complete copies of notes, such as the draw tool's stamps.
  Future<Result<void>> stampNotes(List<UiNoteDraft> notes) => _transformPattern(
    'draw',
    (ctx, patternId) =>
        pattern_api.addNoteCopies(ctx: ctx, patternId: patternId, notes: notes),
  );

  // ==========================================
  // Pattern Transport
  // ==========================================

  /// Plays or pauses the open pattern from the pattern playhead.
  Future<Result<void>> togglePatternPlayback() async {
    final patternId = state.editingPatternId;
    final generatorId = state.previewGeneratorId;
    if (patternId == null || generatorId == null) {
      return ref.notifyErrorResult(
        Exception('Choose a generator to play this pattern'),
      );
    }
    final result = await AsyncValue.guard(() async {
      await _sendLoopRegion(state.loopRegion);
      await transport_api.togglePatternPlayback(
        ctx: _ctx,
        patternId: patternId,
        generatorId: generatorId,
      );
    });
    return _transportResult(result, 'play the pattern');
  }

  /// Stops pattern playback and rewinds to the start of the pattern.
  Future<Result<void>> stopPatternPlayback() async {
    final result = await AsyncValue.guard(
      () => transport_api.stopPatternPlayback(ctx: _ctx),
    );
    return _transportResult(result, 'stop the pattern');
  }

  /// Moves the pattern playhead, whether or not the pattern is playing.
  Future<Result<void>> seekPattern(int samples) async {
    final result = await AsyncValue.guard(
      () =>
          transport_api.setPatternPlayhead(ctx: _ctx, samples: max(0, samples)),
    );
    return _transportResult(result, 'move the pattern playhead');
  }

  /// Loops pattern playback over [region], or the whole pattern when null.
  Future<Result<void>> setLoopRegion(PatternLoopRegion? region) async {
    final valid = region != null && region.endTick > region.startTick
        ? region
        : null;
    final previous = state.loopRegion;
    state = state.copyWith(loopRegion: valid);
    final result = await AsyncValue.guard(() => _sendLoopRegion(valid));
    if (result.hasError) state = state.copyWith(loopRegion: previous);
    return _transportResult(result, 'set the loop region');
  }

  Future<void> _sendLoopRegion(PatternLoopRegion? region) =>
      transport_api.setPatternLoop(
        ctx: _ctx,
        startTick: region?.startTick,
        endTick: region?.endTick,
      );

  Result<void> _transportResult(AsyncValue<void> result, String action) {
    if (!result.hasError) return Result.ok(null);
    AppLogger.error('Could not $action: ${result.error}');
    return ref.notifyErrorResult(
      result.error ?? Exception('Unknown error'),
      title: 'Could not $action',
    );
  }
}
