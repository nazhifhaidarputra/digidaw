import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/shared/enums/global.dart';
import 'package:karbeat/shared/models/grid.dart';
import 'package:karbeat/shared/models/interaction_target.dart';
import 'package:karbeat/shared/models/menu_group.dart';

import 'package:freezed_annotation/freezed_annotation.dart';

part 'workspace_state.freezed.dart';

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

    @Default(ToolbarMenuContextGroup.none) ToolbarMenuContextGroup currentToolbarContext,

    InteractionTarget? interactionTarget,

    int? editingPatternId,

    @Default(100.0) double horizontalZoomLevel,

    @Default(MusicalBeatSize.none) MusicalBeatSize horizontalClipShiftSizeDenom,

    @Default(GridSize.quarter) GridSize gridSize,

    @Default(false) bool snapToGrid,

    @Default(false) bool showExportPanel,

    @Default(false) bool showFloatingMidiKeyboard,
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
    state = state.copyWith(editingPatternId: patternId, currentView: WorkspaceView.pianoRoll);
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
    final next = group == state.currentToolbarContext ? ToolbarMenuContextGroup.none : group;
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

  // Floating midi keyboard
  void toggleFloatingMidiKeyboard() {
    state = state.copyWith(showFloatingMidiKeyboard: !state.showFloatingMidiKeyboard);
  }
}

// ============================================================
// Provider
// ============================================================

/// Top-level Riverpod 3 provider for workspace UI state.
///
/// Read: `ref.watch(workspaceStateProvider)`
/// Mutate: `ref.read(workspaceStateProvider.notifier).navigateTo(…)`
final workspaceStateProvider = NotifierProvider<WorkspaceNotifier, WorkspaceState>(WorkspaceNotifier.new);
