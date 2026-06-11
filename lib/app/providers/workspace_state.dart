import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/shared/enums/global.dart';
import 'package:karbeat/shared/models/grid.dart';
import 'package:karbeat/shared/models/interaction_target.dart';
import 'package:karbeat/shared/models/menu_group.dart';

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
class WorkspaceState {
  /// The currently active top-level view (track list, piano roll, mixer…).
  final WorkspaceView currentView;

  /// The tool selected in the main track-list toolbar.
  final ToolSelection selectedTool;

  /// Which menu context group is currently expanded in the toolbar.
  final ToolbarMenuContextGroup currentToolbarContext;

  /// The item the user is currently interacting with (clip, track header…).
  /// `null` when the interaction panel is hidden.
  final InteractionTarget? interactionTarget;

  /// The pattern currently open for editing in the piano roll.
  /// `null` when no pattern is open.
  final int? editingPatternId;

  /// Horizontal zoom level expressed as ticks-per-pixel.
  /// Clamped to [[_minZoom], [_maxZoom]].
  final double horizontalZoomLevel;

  /// Shift amount used when moving clips horizontally by a fixed beat grid step.
  final MusicalBeatSize horizontalClipShiftSizeDenom;

  /// Global grid subdivision denominator for the track list / arranger.
  final GridSize gridSize;

  /// Whether newly-placed or moved clips snap to the active [gridSize].
  final bool snapToGrid;

  /// Whether the audio-export panel is visible.
  final bool showExportPanel;

  // ---- zoom bounds (intentionally not in state, just referenced here) ----
  static const double minZoom = 0.01;
  static const double maxZoom = 500.0;

  const WorkspaceState({
    this.currentView = WorkspaceView.trackList,
    this.selectedTool = ToolSelection.pointer,
    this.currentToolbarContext = ToolbarMenuContextGroup.none,
    this.interactionTarget,
    this.editingPatternId,
    this.horizontalZoomLevel = 100,
    this.horizontalClipShiftSizeDenom = MusicalBeatSize.none,
    this.gridSize = GridSize.quarter,
    this.snapToGrid = false,
    this.showExportPanel = false,
  });

  WorkspaceState copyWith({
    WorkspaceView? currentView,
    ToolSelection? selectedTool,
    ToolbarMenuContextGroup? currentToolbarContext,
    Object? interactionTarget = _sentinel,
    Object? editingPatternId = _sentinel,
    double? horizontalZoomLevel,
    MusicalBeatSize? horizontalClipShiftSizeDenom,
    GridSize? gridSize,
    bool? snapToGrid,
    bool? showExportPanel,
  }) {
    return WorkspaceState(
      currentView: currentView ?? this.currentView,
      selectedTool: selectedTool ?? this.selectedTool,
      currentToolbarContext:
          currentToolbarContext ?? this.currentToolbarContext,
      interactionTarget: identical(interactionTarget, _sentinel)
          ? this.interactionTarget
          : interactionTarget as InteractionTarget?,
      editingPatternId: identical(editingPatternId, _sentinel)
          ? this.editingPatternId
          : editingPatternId as int?,
      horizontalZoomLevel: horizontalZoomLevel ?? this.horizontalZoomLevel,
      horizontalClipShiftSizeDenom:
          horizontalClipShiftSizeDenom ?? this.horizontalClipShiftSizeDenom,
      gridSize: gridSize ?? this.gridSize,
      snapToGrid: snapToGrid ?? this.snapToGrid,
      showExportPanel: showExportPanel ?? this.showExportPanel,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WorkspaceState &&
        other.currentView == currentView &&
        other.selectedTool == selectedTool &&
        other.currentToolbarContext == currentToolbarContext &&
        other.interactionTarget == interactionTarget &&
        other.editingPatternId == editingPatternId &&
        other.horizontalZoomLevel == horizontalZoomLevel &&
        other.horizontalClipShiftSizeDenom == horizontalClipShiftSizeDenom &&
        other.gridSize == gridSize &&
        other.snapToGrid == snapToGrid &&
        other.showExportPanel == showExportPanel;
  }

  @override
  int get hashCode => Object.hash(
        currentView,
        selectedTool,
        currentToolbarContext,
        interactionTarget,
        editingPatternId,
        horizontalZoomLevel,
        horizontalClipShiftSizeDenom,
        gridSize,
        snapToGrid,
        showExportPanel,
      );
}

const Object _sentinel = Object();

// ============================================================
// Notifier
// ============================================================

/// Riverpod 3 [Notifier] owning all workspace-level UI state.
///
/// All actions here mirror the workspace / editor methods of [GlobalAppState]
/// and are intended as a drop-in replacement during the slow migration.
class WorkspaceNotifier extends Notifier<WorkspaceState> {
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
    state = state.copyWith(
      currentToolbarContext: ToolbarMenuContextGroup.none,
    );
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
}

// ============================================================
// Provider
// ============================================================

/// Top-level Riverpod 3 provider for workspace UI state.
///
/// Read: `ref.watch(workspaceStateProvider)`
/// Mutate: `ref.read(workspaceStateProvider.notifier).navigateTo(…)`
final workspaceStateProvider =
    NotifierProvider<WorkspaceNotifier, WorkspaceState>(
  WorkspaceNotifier.new,
);
