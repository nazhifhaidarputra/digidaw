import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/automation_provider.dart';
import 'package:karbeat/app/providers/notification_provider.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/features/track/models/automation_lane_clipboard.dart';
import 'package:karbeat/features/track/models/automation_curve_template.dart';
import 'package:karbeat/features/track/models/automation_lane_editor.dart';
import 'package:karbeat/features/track/services/automation_template_service.dart';
import 'package:karbeat/src/rust/api/automation.dart';

/// Owns automation lane editor UI state (hover, context target, range
/// selection, clipboard) and forwards point mutations to [AutomationNotifier]
/// for Rust sync.
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

  /// Sets the point to an exact normalized value, clamped to 0..1.
  Future<void> setPointValue({
    required int laneId,
    required int pointId,
    required double normalizedValue,
  }) async {
    final point = _findPoint(laneId: laneId, pointId: pointId);
    final clamped = normalizedValue.clamp(0.0, 1.0);
    if (point == null || point.value == clamped) return;

    await ref
        .read(automationProvider.notifier)
        .updatePoint(
          automationLaneId: laneId,
          pointId: pointId,
          value: clamped,
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

  /// Moves the Bezier handles of the segment that starts at the given point.
  Future<void> setPointHandles({
    required int laneId,
    required int pointId,
    required BezierHandlesDto handles,
  }) async {
    final point = _findPoint(laneId: laneId, pointId: pointId);
    if (point == null || point.handles == handles) return;

    await ref
        .read(automationProvider.notifier)
        .updatePoint(
          automationLaneId: laneId,
          pointId: pointId,
          handles: handles,
        );
  }

  /// Sets the tension of the segment that starts at the given point.
  Future<void> setPointTension({
    required int laneId,
    required int pointId,
    required double tension,
  }) async {
    final point = _findPoint(laneId: laneId, pointId: pointId);
    final clamped = tension.clamp(-1.0, 1.0);
    if (point == null || point.tension == clamped) return;

    await ref
        .read(automationProvider.notifier)
        .updatePoint(
          automationLaneId: laneId,
          pointId: pointId,
          tension: clamped,
        );
  }

  // =========================================================================
  // RANGE SELECTION
  // =========================================================================

  /// Starts a range on [laneId], replacing any earlier range.
  void startSelection({required int laneId, required int tick}) {
    state = state.copyWith(
      selectionLaneId: laneId,
      selectionAnchorTick: tick,
      selectionFocusTick: tick,
    );
  }

  /// Drags the end of the range that was started on [laneId].
  void extendSelection({required int laneId, required int tick}) {
    if (state.selectionLaneId != laneId || state.selectionFocusTick == tick) {
      return;
    }
    state = state.copyWith(selectionFocusTick: tick);
  }

  /// Remembers the tick that was right-clicked on a lane, which is where a
  /// paste from the lane menu lands.
  void markPasteTarget({required int laneId, required int tick}) {
    state = state.copyWith(pasteLaneId: laneId, pasteTick: tick);
  }

  void clearSelection() {
    if (state.selectionLaneId == null) return;
    state = state.copyWith(
      selectionLaneId: null,
      selectionAnchorTick: null,
      selectionFocusTick: null,
    );
  }

  // =========================================================================
  // CURVE COPY, PASTE AND TEMPLATES
  // =========================================================================

  /// Copies the selected range of [laneId] into the editor clipboard.
  /// Returns false when the lane has no range or the range holds no curve.
  Future<bool> copySelection(int laneId) async {
    final range = state.selectionOf(laneId);
    if (range == null) return false;
    final points = await _copyRange(laneId, range);
    if (points == null) return false;

    state = state.copyWith(
      clipboard: AutomationLanePointClipboard.curve(
        points: points,
        lengthTicks: range.$2 - range.$1,
      ),
    );
    return true;
  }

  /// Copies the selected range, then removes its points.
  Future<void> cutSelection(int laneId) async {
    if (await copySelection(laneId)) await deleteSelection(laneId);
  }

  /// Removes the points inside the selected range of [laneId].
  Future<void> deleteSelection(int laneId) async {
    final range = state.selectionOf(laneId);
    if (range == null) return;
    await ref
        .read(automationProvider.notifier)
        .deleteRange(laneId: laneId, startTick: range.$1, endTick: range.$2);
  }

  /// Saves the selected range of [laneId] to the template library as [name].
  Future<void> saveSelectionAsTemplate(int laneId, String name) async {
    final range = state.selectionOf(laneId);
    if (range == null) return;
    final points = await _copyRange(laneId, range);
    if (points == null) return;

    await ref
        .read(automationTemplatesProvider.notifier)
        .add(name: name, lengthTicks: range.$2 - range.$1, points: points);
  }

  /// Pastes the clipboard curve into [laneId] at [atTick]. With
  /// [fitSelection] the curve is stretched over the lane's selected range
  /// instead. No-op when the clipboard holds no curve.
  Future<void> pasteCurve({
    required int laneId,
    required int atTick,
    bool fitSelection = false,
  }) async {
    final clipboard = state.clipboard;
    if (clipboard is! AutomationLanePointClipboardCurve) return;
    await _paste(
      laneId: laneId,
      atTick: atTick,
      points: clipboard.points,
      lengthTicks: clipboard.lengthTicks,
      fitSelection: fitSelection,
    );
  }

  /// Pastes [template] into [laneId] at [atTick], or stretched over the
  /// lane's selected range with [fitSelection].
  Future<void> insertTemplate({
    required int laneId,
    required int atTick,
    required AutomationCurveTemplate template,
    bool fitSelection = false,
  }) => _paste(
    laneId: laneId,
    atTick: atTick,
    points: template.points,
    lengthTicks: template.lengthTicks,
    fitSelection: fitSelection,
  );

  Future<void> _paste({
    required int laneId,
    required int atTick,
    required IList<AutomationPointDto> points,
    required int lengthTicks,
    required bool fitSelection,
  }) async {
    final range = fitSelection ? state.selectionOf(laneId) : null;
    await ref
        .read(automationProvider.notifier)
        .pastePoints(
          laneId: laneId,
          atTick: range?.$1 ?? atTick,
          points: points,
          lengthTicks: lengthTicks,
          targetLength: range == null ? null : range.$2 - range.$1,
        );
  }

  /// The curve inside [range] of [laneId], or null when there is none to
  /// copy; an empty range is reported to the user.
  Future<IList<AutomationPointDto>?> _copyRange(
    int laneId,
    (int, int) range,
  ) async {
    final points = await ref
        .read(automationProvider.notifier)
        .copyRange(laneId: laneId, startTick: range.$1, endTick: range.$2);
    if (points == null) return null;
    if (points.isEmpty || range.$2 <= range.$1) {
      ref.notifyError('The selected range holds no automation curve');
      return null;
    }
    return points;
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
