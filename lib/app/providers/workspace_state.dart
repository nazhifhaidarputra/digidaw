import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/notification_provider.dart';
import 'package:karbeat/core/utils/logger.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/features/workspace/models/browser_panel_state.dart';
import 'package:karbeat/features/workspace/services/sample_browser_service.dart';
import 'package:karbeat/shared/enums/global.dart';
import 'package:karbeat/shared/models/grid.dart';
import 'package:karbeat/shared/models/interaction_target.dart';
import 'package:karbeat/shared/models/menu_group.dart';
import 'package:karbeat/src/rust/api/project.dart' show DawContext;

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
    @Default(15) int keyRange,
    @Default(false) bool showed,
  }) = _FloatingMidiKeyboardFieldState;

  /// Clamped factory that mirrors the original constructor logic
  factory FloatingMidiKeyboardFieldState.create({
    int? selectedGeneratorId,
    int baseKey = 48,
    int keyRange = 15,
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

    @Default(ToolSelection.pointer) ToolSelection selectedTool,

    @Default(ToolbarMenuContextGroup.none)
    ToolbarMenuContextGroup currentToolbarContext,

    InteractionTarget? interactionTarget,

    int? editingPatternId,

    @Default(100.0) double horizontalZoomLevel,

    @Default(MusicalBeatSize.none) MusicalBeatSize horizontalClipShiftSizeDenom,

    @Default(GridSize.quarter) GridSize gridSize,

    @Default(false) bool snapToGrid,

    @Default(false) bool showExportPanel,

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
  bool _didRestoreSampleDirectories = false;
  DawContext? _dawContextLifetimeAnchor;

  // ---- static data (menu groups are app-level constants) ----
  static final List<DawToolbarMenuGroup> menuGroups = [
    DawToolbarMenuGroupFactory.createProjectMenuGroup(),
    DawToolbarMenuGroupFactory.createEditMenuGroup(),
    DawToolbarMenuGroupFactory.createViewMenuGroup(),
  ];

  @override
  WorkspaceState build() => const WorkspaceState();

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

  /// Toggle snap-to-grid on or off.
  void toggleSnapToGrid() {
    state = state.copyWith(snapToGrid: !state.snapToGrid);
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
  // Clip shift size
  // ------------------------------------------------------------------

  /// Set the beat-size used when nudging clips horizontally by a fixed step.
  void setHorizontalClipShiftSizeDenom(MusicalBeatSize value) {
    if (state.horizontalClipShiftSizeDenom != value) {
      state = state.copyWith(horizontalClipShiftSizeDenom: value);
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
  // Sample browser
  // ------------------------------------------------------------------

  void toggleBrowserPanel() {
    state = state.copyWith(
      browserPanelState: state.browserPanelState.copyWith(
        isExpanded: !state.browserPanelState.isExpanded,
      ),
    );
  }

  void closeBrowserPanel() {
    if (!state.browserPanelState.isExpanded) return;
    state = state.copyWith(
      browserPanelState: state.browserPanelState.copyWith(isExpanded: false),
    );
  }

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
    return restoreSampleDirectories();
  }

  Future<Result<void>> restoreSampleDirectories() async {
    if (_didRestoreSampleDirectories) return Result.ok(null);
    _didRestoreSampleDirectories = true;

    state = state.copyWith(
      browserPanelState: state.browserPanelState.copyWith(
        isLoadingDirectory: true,
      ),
    );

    final service = ref.read(sampleBrowserServiceProvider);
    final loadResult = await service.loadPersistedDirectoryPaths();
    if (!ref.mounted) return Result.ok(null);
    if (loadResult case Error(error: final error)) {
      _didRestoreSampleDirectories = false;
      state = state.copyWith(
        browserPanelState: state.browserPanelState.copyWith(
          isLoadingDirectory: false,
        ),
      );
      AppLogger.error(
        'Failed to restore persisted sample directories',
        error: error,
      );
      return ref.notifyErrorResult(error);
    }

    final restoredTrees = <String, FileTree>{};
    for (final path in loadResult.ok().toSet()) {
      final scanResult = await service.scanDirectory(path);
      if (!ref.mounted) return Result.ok(null);
      switch (scanResult) {
        case Ok(value: final tree):
          restoredTrees[tree.path] = tree;
        case Error(error: final error):
          // Keep the path persisted: removable or network storage may return.
          AppLogger.warn(
            'Persisted sample directory is currently unavailable: $path ($error)',
          );
      }
    }

    var directories = state.browserPanelState.directories;
    var expandedDirectoryPaths = state.browserPanelState.expandedDirectoryPaths;
    for (final tree in restoredTrees.values) {
      directories = directories.add(tree.path, tree);
      expandedDirectoryPaths = expandedDirectoryPaths.add(tree.path);
    }

    state = state.copyWith(
      browserPanelState: state.browserPanelState.copyWith(
        isLoadingDirectory: false,
        directories: directories,
        expandedDirectoryPaths: expandedDirectoryPaths,
      ),
    );
    return Result.ok(null);
  }

  Future<Result<void>> addSampleDirectory() async {
    if (state.browserPanelState.isLoadingDirectory) return Result.ok(null);

    state = state.copyWith(
      browserPanelState: state.browserPanelState.copyWith(
        isLoadingDirectory: true,
      ),
    );

    final service = ref.read(sampleBrowserServiceProvider);
    final pickResult = await service.pickDirectory();
    if (!ref.mounted) return Result.ok(null);
    if (pickResult case Error(error: final error)) {
      state = state.copyWith(
        browserPanelState: state.browserPanelState.copyWith(
          isLoadingDirectory: false,
        ),
      );
      AppLogger.error(
        'Failed to open the sample directory picker',
        error: error,
      );
      return ref.notifyErrorResult(error);
    }

    final path = pickResult.ok();
    if (path == null) {
      state = state.copyWith(
        browserPanelState: state.browserPanelState.copyWith(
          isLoadingDirectory: false,
        ),
      );
      return Result.ok(null);
    }

    final scanResult = await service.scanDirectory(path);
    if (!ref.mounted) return Result.ok(null);
    if (scanResult case Error(error: final error)) {
      state = state.copyWith(
        browserPanelState: state.browserPanelState.copyWith(
          isLoadingDirectory: false,
        ),
      );
      AppLogger.error('Failed to scan sample directory', error: error);
      return ref.notifyErrorResult(error);
    }

    final tree = scanResult.ok();
    final updatedDirectories = state.browserPanelState.directories.add(
      tree.path,
      tree,
    );
    state = state.copyWith(
      browserPanelState: state.browserPanelState.copyWith(
        isLoadingDirectory: false,
        directories: updatedDirectories,
        expandedDirectoryPaths: state.browserPanelState.expandedDirectoryPaths
            .add(tree.path),
      ),
    );

    final saveResult = await service.savePersistedDirectoryPaths(
      updatedDirectories.keys,
    );
    if (!ref.mounted) return Result.ok(null);
    if (saveResult case Error(error: final error)) {
      AppLogger.error('Failed to persist sample directories', error: error);
      return ref.notifyErrorResult(error);
    }
    return Result.ok(null);
  }

  void setMidiKeyboardBaseKey(int key) {
    state = state.copyWith(
      floatingMidiKeyboardState: state.floatingMidiKeyboardState.copyWith(
        baseKey: key.clamp(21, 120),
      ),
    );
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
