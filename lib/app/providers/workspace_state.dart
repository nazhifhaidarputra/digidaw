import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/notification_provider.dart';
import 'package:karbeat/core/utils/formatter.dart';
import 'package:karbeat/core/utils/logger.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/features/workspace/models/browser_panel_state.dart';
import 'package:karbeat/features/workspace/services/sample_browser_service.dart';
import 'package:karbeat/shared/enums/global.dart';
import 'package:karbeat/shared/models/grid.dart';
import 'package:karbeat/shared/models/interaction_target.dart';
import 'package:karbeat/shared/models/menu_group.dart';
import 'package:karbeat/src/rust/api/project.dart' show DawContext;
import 'package:karbeat/src/rust/api/sample_browser.dart'
    show
        UiSampleFolderEvent,
        UiSampleFolderEvent_Restored,
        UiSampleFolderEvent_Scanned,
        UiSampleFolderEvent_Unavailable;

import 'package:freezed_annotation/freezed_annotation.dart';

part 'workspace_state.freezed.dart';

/// State for Floating midi keyboard's properties
@freezed
abstract class FloatingMidiKeyboardFieldState
    with _$FloatingMidiKeyboardFieldState {
  const FloatingMidiKeyboardFieldState._(); // enables custom methods

  const factory FloatingMidiKeyboardFieldState({
    int? selectedGeneratorId,
    @Default(48) int baseKey,
    @Default(24) int keyRange,
    @Default(false) bool showed,
  }) = _FloatingMidiKeyboardFieldState;

  /// Scientific pitch octave of [baseKey], where C4 is note 60.
  int get baseOctave => midiKeyOctave(baseKey);

  /// Pitch class of [baseKey], `0` for C through `11` for B.
  int get basePitchClass => midiKeyPitchClass(baseKey);

  /// Display label of [baseKey], combining the octave and the key, e.g. `C4`.
  String get baseNoteLabel => numToMidiKey(baseKey);

  /// Clamped factory that mirrors the original constructor logic
  factory FloatingMidiKeyboardFieldState.create({
    int? selectedGeneratorId,
    int baseKey = 48,
    int keyRange = 24,
    bool showed = false,
  }) {
    return FloatingMidiKeyboardFieldState(
      selectedGeneratorId: selectedGeneratorId,
      baseKey: baseKey.clamp(21, 120),
      keyRange: keyRange.clamp(12, 24),
      showed: showed,
    );
  }
}
// ============================================================
// State data class
// ============================================================

/// Immutable state for workspace-level UI — the active view, selected tool,
/// toolbar context, interaction panel, grid settings, zoom level, and the
/// export panel visibility.
///
/// Mirrors the workspace / editor fields that live inside [GlobalAppState],
/// expressed as a plain immutable value object so Riverpod can perform
/// fine-grained equality checks and avoid unnecessary rebuilds.
@freezed
abstract class WorkspaceState with _$WorkspaceState {
  const WorkspaceState._();

  static const double minZoom = 0.01;
  static const double maxZoom = 500.0;

  const factory WorkspaceState({
    @Default(WorkspaceView.trackList) WorkspaceView currentView,

    @Default(ToolSelection.panSelect) ToolSelection selectedTool,

    @Default(ToolbarMenuContextGroup.none)
    ToolbarMenuContextGroup currentToolbarContext,

    InteractionTarget? interactionTarget,

    int? editingPatternId,

    @Default(100.0) double horizontalZoomLevel,

    @Default(GridSize.quarter) GridSize gridSize,

    @Default(false) bool snapToGrid,

    /// The timeline and piano roll scroll to keep the moving playhead in view.
    @Default(false) bool followPlayhead,

    /// Resizing an audio clip in the timeline stretches its audio instead of trimming it.
    @Default(false) bool resizeStretches,

    /// Gain envelope shown and edited on audio clips in the timeline.
    @Default(ClipEnvelopeView.none) ClipEnvelopeView clipEnvelopeView,

    @Default(false) bool showExportPanel,

    /// The unified browser/source panel beside the track list.
    @Default(false) bool isRightPanelExpanded,
    @Default(RightPanelTab.browser) RightPanelTab rightPanelTab,

    @Default(BrowserPanelState()) BrowserPanelState browserPanelState,

    @Default(FloatingMidiKeyboardFieldState())
    FloatingMidiKeyboardFieldState floatingMidiKeyboardState,
  }) = _WorkspaceState;
}

// ============================================================
// Notifier
// ============================================================

/// Riverpod 3 [Notifier] owning all workspace-level UI state.
///
/// All actions here mirror the workspace / editor methods of [GlobalAppState]
/// and are intended as a drop-in replacement during the slow migration.
class WorkspaceNotifier extends Notifier<WorkspaceState> {
  StreamSubscription<UiSampleFolderEvent>? _sampleFolderSubscription;
  Completer<Result<void>>? _sampleFoldersRestored;
  DawContext? _dawContextLifetimeAnchor;

  // ---- static data (menu groups are app-level constants) ----
  static final List<DawToolbarMenuGroup> menuGroups = [
    DawToolbarMenuGroupFactory.createProjectMenuGroup(),
    DawToolbarMenuGroupFactory.createEditMenuGroup(),
    DawToolbarMenuGroupFactory.createViewMenuGroup(),
  ];

  @override
  WorkspaceState build() {
    ref.onDispose(() {
      unawaited(_sampleFolderSubscription?.cancel());
      _sampleFolderSubscription = null;
    });
    return const WorkspaceState();
  }

  // ------------------------------------------------------------------
  // Navigation
  // ------------------------------------------------------------------

  /// Switch to a different top-level workspace view.
  void navigateTo(WorkspaceView view) {
    if (state.currentView != view) {
      state = state.copyWith(currentView: view);
    }
  }

  /// Open a pattern for editing: sets [editingPatternId] and navigates to
  /// the piano roll view.
  void openPattern(int patternId) {
    openPianoRoll(patternId: patternId);
  }

  /// Open the piano roll, optionally with a pattern selected for editing.
  void openPianoRoll({int? patternId}) {
    state = state.copyWith(
      editingPatternId: patternId,
      currentView: WorkspaceView.pianoRoll,
    );
  }

  // ------------------------------------------------------------------
  // Tool selection
  // ------------------------------------------------------------------

  /// Change the active tool in the main toolbar.
  void selectTool(ToolSelection tool) {
    if (state.selectedTool != tool) {
      state = state.copyWith(selectedTool: tool);
    }
  }

  // ------------------------------------------------------------------
  // Toolbar context menu
  // ------------------------------------------------------------------

  /// Toggle a toolbar menu group on/off.
  /// Selecting the already-open group collapses it.
  void toggleToolbarContext(ToolbarMenuContextGroup group) {
    final next = group == state.currentToolbarContext
        ? ToolbarMenuContextGroup.none
        : group;
    state = state.copyWith(currentToolbarContext: next);
  }

  /// Collapse whatever toolbar context menu is currently open.
  void closeContextPanel() {
    state = state.copyWith(currentToolbarContext: ToolbarMenuContextGroup.none);
  }

  // ------------------------------------------------------------------
  // Interaction panel
  // ------------------------------------------------------------------

  /// Show the interaction panel for a given [target] (clip, track header…).
  void showInteractionPanel(InteractionTarget target) {
    state = state.copyWith(interactionTarget: target);
  }

  /// Hide the interaction panel.
  void hideInteractionPanel() {
    if (state.interactionTarget != null) {
      state = state.copyWith(interactionTarget: null);
    }
  }

  // ------------------------------------------------------------------
  // Grid
  // ------------------------------------------------------------------

  /// Set the grid subdivision denominator.
  void setGridSize(GridSize newSize) {
    if (state.gridSize != newSize) {
      state = state.copyWith(gridSize: newSize);
    }
  }

  /// Show [view] on audio clips, or hide envelopes when [view] is already shown.
  void toggleClipEnvelopeView(ClipEnvelopeView view) {
    state = state.copyWith(
      clipEnvelopeView: state.clipEnvelopeView == view
          ? ClipEnvelopeView.none
          : view,
    );
  }

  /// Toggle snap-to-grid on or off.
  void toggleSnapToGrid() {
    state = state.copyWith(snapToGrid: !state.snapToGrid);
  }

  /// Toggle whether the views scroll to follow the playhead.
  void toggleFollowPlayhead() {
    state = state.copyWith(followPlayhead: !state.followPlayhead);
  }

  /// Toggle whether resizing audio clips stretches their audio.
  void toggleResizeStretches() {
    state = state.copyWith(resizeStretches: !state.resizeStretches);
  }

  // ------------------------------------------------------------------
  // Horizontal zoom
  // ------------------------------------------------------------------

  /// Set the horizontal zoom level (ticks per pixel).
  /// Automatically clamped to [[WorkspaceState.minZoom], [WorkspaceState.maxZoom]].
  void setHorizontalZoom(double level) {
    final clamped = level.clamp(WorkspaceState.minZoom, WorkspaceState.maxZoom);
    if (state.horizontalZoomLevel != clamped) {
      state = state.copyWith(horizontalZoomLevel: clamped);
    }
  }

  // ------------------------------------------------------------------
  // Export panel
  // ------------------------------------------------------------------

  /// Show the audio export panel.
  void openExportPanel() {
    state = state.copyWith(showExportPanel: true);
  }

  /// Hide the audio export panel.
  void closeExportPanel() {
    state = state.copyWith(showExportPanel: false);
  }

  // ------------------------------------------------------------------
  // Right side panel
  // ------------------------------------------------------------------

  /// Toggle the unified right-side panel.
  void toggleRightPanel() {
    state = state.copyWith(isRightPanelExpanded: !state.isRightPanelExpanded);
  }

  /// Switch the right-side panel to [tab], opening the panel if needed.
  void selectRightPanelTab(RightPanelTab tab) {
    if (state.isRightPanelExpanded && state.rightPanelTab == tab) return;
    state = state.copyWith(isRightPanelExpanded: true, rightPanelTab: tab);
  }

  /// Hide the right-side panel.
  void closeRightPanel() {
    if (!state.isRightPanelExpanded) return;
    state = state.copyWith(isRightPanelExpanded: false);
  }

  // ------------------------------------------------------------------
  // Sample browser
  // ------------------------------------------------------------------

  void selectBrowserSample(String path) {
    if (state.browserPanelState.selectedSamplePath == path) return;
    state = state.copyWith(
      browserPanelState: state.browserPanelState.copyWith(
        selectedSamplePath: path,
      ),
    );
  }

  void toggleBrowserDirectory(String path) {
    final expandedPaths = state.browserPanelState.expandedDirectoryPaths;
    state = state.copyWith(
      browserPanelState: state.browserPanelState.copyWith(
        expandedDirectoryPaths: expandedPaths.contains(path)
            ? expandedPaths.remove(path)
            : expandedPaths.add(path),
      ),
    );
  }

  Future<Result<void>> initializeSampleBrowser(DawContext dawContext) {
    // The browser does not call the engine while reading preferences, but it
    // belongs to the DAW session. Retaining this opaque handle guarantees the
    // Rust context cannot be finalized before an in-flight browser operation.
    _dawContextLifetimeAnchor ??= dawContext;
    return watchSampleDirectories();
  }

  /// Starts receiving the sample folders from Rust, which scans the saved
  /// folders and then rescans each one whose files change on disk. Completes
  /// once every saved folder was scanned; later calls return the same result.
  Future<Result<void>> watchSampleDirectories() {
    final restored = _sampleFoldersRestored;
    if (restored != null) return restored.future;
    final completer = _sampleFoldersRestored = Completer<Result<void>>();

    _setLoadingDirectory(true);
    _sampleFolderSubscription = ref
        .read(sampleBrowserServiceProvider)
        .watchDirectories()
        .listen(
          _applySampleFolderEvent,
          onError: (Object error, StackTrace stackTrace) {
            if (!ref.mounted) return;
            // Rust ends the stream on error; a later call may retry.
            _sampleFolderSubscription = null;
            _sampleFoldersRestored = null;
            _setLoadingDirectory(false);
            AppLogger.error(
              'Failed to watch the sample folders',
              error: error,
              stackTrace: stackTrace,
            );
            final result = ref.notifyErrorResult<void>(
              error,
              stackTrace: stackTrace,
            );
            if (!completer.isCompleted) completer.complete(result);
          },
          onDone: () {
            if (!completer.isCompleted) completer.complete(Result.ok(null));
          },
        );
    return completer.future;
  }

  void _applySampleFolderEvent(UiSampleFolderEvent event) {
    if (!ref.mounted) return;
    switch (event) {
      case UiSampleFolderEvent_Scanned(:final tree):
        _showSampleDirectory(fileTreeFrom(tree));
      case UiSampleFolderEvent_Unavailable(:final path):
        final browser = state.browserPanelState;
        if (!browser.directories.containsKey(path)) return;
        state = state.copyWith(
          browserPanelState: browser.copyWith(
            directories: browser.directories.remove(path),
          ),
        );
      case UiSampleFolderEvent_Restored():
        _setLoadingDirectory(false);
        final restored = _sampleFoldersRestored;
        if (restored != null && !restored.isCompleted) {
          restored.complete(Result.ok(null));
        }
    }
  }

  /// Shows [tree], expanding it when it is a new source folder.
  void _showSampleDirectory(FileTree tree) {
    final browser = state.browserPanelState;
    final isNew = !browser.directories.containsKey(tree.path);
    state = state.copyWith(
      browserPanelState: browser.copyWith(
        directories: browser.directories.add(tree.path, tree),
        expandedDirectoryPaths: isNew
            ? browser.expandedDirectoryPaths.add(tree.path)
            : browser.expandedDirectoryPaths,
      ),
    );
  }

  void _setLoadingDirectory(bool isLoading) {
    if (state.browserPanelState.isLoadingDirectory == isLoading) return;
    state = state.copyWith(
      browserPanelState: state.browserPanelState.copyWith(
        isLoadingDirectory: isLoading,
      ),
    );
  }

  Future<Result<void>> addSampleDirectory() async {
    if (state.browserPanelState.isLoadingDirectory) return Result.ok(null);
    _setLoadingDirectory(true);

    final service = ref.read(sampleBrowserServiceProvider);
    final pickResult = await service.pickDirectory();
    if (!ref.mounted) return Result.ok(null);
    if (pickResult case Error(error: final error)) {
      _setLoadingDirectory(false);
      AppLogger.error(
        'Failed to open the sample directory picker',
        error: error,
      );
      return ref.notifyErrorResult(error);
    }

    final path = pickResult.ok();
    if (path == null) {
      _setLoadingDirectory(false);
      return Result.ok(null);
    }

    final addResult = await service.addDirectory(path);
    if (!ref.mounted) return Result.ok(null);
    _setLoadingDirectory(false);
    switch (addResult) {
      case Ok(value: final tree):
        _showSampleDirectory(tree);
        return Result.ok(null);
      case Error(error: final error):
        AppLogger.error('Failed to add sample directory', error: error);
        return ref.notifyErrorResult(error);
    }
  }

  void setMidiKeyboardBaseKey(int key) {
    state = state.copyWith(
      floatingMidiKeyboardState: state.floatingMidiKeyboardState.copyWith(
        baseKey: key.clamp(21, 120),
      ),
    );
  }

  /// Move the keyboard's lowest key to [octave], keeping the selected key.
  void setMidiKeyboardOctave(int octave) {
    final pitchClass = state.floatingMidiKeyboardState.basePitchClass;
    final targetOctave = _midiKeyboardOctaveFor(octave, pitchClass);
    setMidiKeyboardBaseKey((targetOctave + 1) * 12 + pitchClass);
  }

  /// Choose the key (pitch class, C through B) of the keyboard's lowest key.
  void setMidiKeyboardKey(int pitchClass) {
    final baseKey = state.floatingMidiKeyboardState.baseKey;
    final key = pitchClass.clamp(0, 11);
    final targetOctave = _midiKeyboardOctaveFor(midiKeyOctave(baseKey), key);
    setMidiKeyboardBaseKey((targetOctave + 1) * 12 + key);
  }

  /// Keeps [pitchClass] inside the playable MIDI range while moving octaves.
  int _midiKeyboardOctaveFor(int octave, int pitchClass) {
    final minOctave = ((21 - pitchClass) / 12).ceil() - 1;
    final maxOctave = ((120 - pitchClass) ~/ 12) - 1;
    return octave.clamp(minOctave, maxOctave);
  }

  void setMidiKeyboardRange(int range) {
    state = state.copyWith(
      floatingMidiKeyboardState: state.floatingMidiKeyboardState.copyWith(
        keyRange: range.clamp(12, 24),
      ),
    );
  }

  void setMidiKeyboardGenerator(int? generatorId) {
    state = state.copyWith(
      floatingMidiKeyboardState: state.floatingMidiKeyboardState.copyWith(
        selectedGeneratorId: generatorId,
      ),
    );
  }

  void toggleFloatingMidiKeyboard() {
    state = state.copyWith(
      floatingMidiKeyboardState: state.floatingMidiKeyboardState.copyWith(
        showed: !state.floatingMidiKeyboardState.showed,
      ),
    );
  }
}

// ============================================================
// Provider
// ============================================================

/// Top-level Riverpod 3 provider for workspace UI state.
///
/// Read: `ref.watch(workspaceStateProvider)`
/// Mutate: `ref.read(workspaceStateProvider.notifier).navigateTo(…)`
final workspaceStateProvider =
    NotifierProvider<WorkspaceNotifier, WorkspaceState>(WorkspaceNotifier.new);
