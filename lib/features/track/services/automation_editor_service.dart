import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/automation_provider.dart';
import 'package:karbeat/app/providers/notification_provider.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/features/track/models/automation_lane_clipboard.dart';
import 'package:karbeat/features/track/models/automation_lane_editor.dart';
import 'package:karbeat/src/rust/api/automation.dart';

/// Owns automation lane editor UI state (hover, context target, clipboard)
/// and forwards point mutations to [AutomationNotifier] for Rust sync.
class AutomationEditorNotifier extends Notifier<AutomationLaneEditorState> {
  @override
  AutomationLaneEditorState build() => const AutomationLaneEditorState();

  // =========================================================================
  // HOVER AND CONTEXT TARGET
  // =========================================================================

  void hoverPoint({required int laneId, required int pointId}) {
    if (state.hoveredLaneId == laneId && state.hoveredPointId == pointId) {
      return;
    }
    state = state.copyWith(hoveredLaneId: laneId, hoveredPointId: pointId);
  }

  /// Clears hover only when it still belongs to the given point, so a late
  /// exit event cannot erase a newer hover on another point.
  void clearHoveredPoint({required int laneId, required int pointId}) {
    if (state.hoveredLaneId != laneId || state.hoveredPointId != pointId) {
      return;
    }
    state = state.copyWith(hoveredLaneId: null, hoveredPointId: null);
  }

  void openPointContext({required int laneId, required int pointId}) {
    state = state.copyWith(contextLaneId: laneId, contextPointId: pointId);
  }

  void closePointContext({required int laneId, required int pointId}) {
    if (state.contextLaneId != laneId || state.contextPointId != pointId) {
      return;
    }
    state = state.copyWith(contextLaneId: null, contextPointId: null);
  }

  // =========================================================================
  // POINT ACTIONS
  // =========================================================================

  /// Stores the point's normalized value in the editor clipboard.
  Result<double> copyPointValue({required int laneId, required int pointId}) {
    final point = _findPoint(laneId: laneId, pointId: pointId);
    if (point == null) {
      return ref.notifyErrorResult(
        Exception('Automation point $pointId not found in lane $laneId'),
      );
    }

    state = state.copyWith(
      clipboard: AutomationLanePointClipboard.value(
        normalizedValue: point.value,
      ),
    );
    return Result.ok(point.value);
  }

  /// Applies the clipboard value to the point. No-op when clipboard is empty.
  Future<void> pastePointValue({
    required int laneId,
    required int pointId,
  }) async {
    final clipboard = state.clipboard;
    if (clipboard is! AutomationLanePointClipboardValue) return;

    await ref
        .read(automationProvider.notifier)
        .updatePoint(
          automationLaneId: laneId,
          pointId: pointId,
          value: clipboard.normalizedValue.clamp(0.0, 1.0),
        );
  }

  Future<void> deletePoint({required int laneId, required int pointId}) async {
    clearHoveredPoint(laneId: laneId, pointId: pointId);
    closePointContext(laneId: laneId, pointId: pointId);
    await ref.read(automationProvider.notifier).removePoint(laneId, pointId);
  }

  Future<void> setPointCurveType({
    required int laneId,
    required int pointId,
    required AutomationCurveTypeDto curveType,
  }) async {
    final point = _findPoint(laneId: laneId, pointId: pointId);
    if (point == null || point.curveType == curveType) return;

    await ref
        .read(automationProvider.notifier)
        .updatePoint(
          automationLaneId: laneId,
          pointId: pointId,
          curveType: curveType,
        );
  }

  AutomationPointDto? _findPoint({required int laneId, required int pointId}) {
    final lane = ref.read(projectProvider).value?.automationPool[laneId];
    return lane?.points.where((p) => p.id == pointId).firstOrNull;
  }
}

final automationEditorProvider =
    NotifierProvider<AutomationEditorNotifier, AutomationLaneEditorState>(
      AutomationEditorNotifier.new,
    );
