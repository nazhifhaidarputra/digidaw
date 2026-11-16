import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/automation_provider.dart';
import 'package:karbeat/app/providers/clip_placement_state.dart';
import 'package:karbeat/app/providers/range_select_state.dart';
import 'package:karbeat/app/providers/track_list_state.dart';
import 'package:karbeat/app/providers/transport_state.dart';
import 'package:karbeat/app/providers/workspace_state.dart';
import 'package:karbeat/core/l10n/localizer.dart';
import 'package:karbeat/features/track/models/automation_lane_editor.dart';
import 'package:karbeat/features/track/services/automation_curve_evaluator.dart';
import 'package:karbeat/features/track/services/automation_editor_service.dart';
import 'package:karbeat/features/track/services/automation_region_edit.dart';
import 'package:karbeat/features/track/services/timeline_pointer.dart';
import 'package:karbeat/features/track/services/curve_sampler.dart';
import 'package:karbeat/features/track/view/automation_lane_header.dart';
import 'package:karbeat/features/track/view/automation_point_context_menu.dart';
import 'package:karbeat/features/track/view/automation_range_context_menu.dart';
import 'package:karbeat/features/track/view/automation_region_context_menu.dart';
import 'package:karbeat/features/track/view/grid_painter.dart';
import 'package:karbeat/features/track/view/track_range_select_overlay.dart';
import 'package:karbeat/shared/enums/global.dart';
import 'package:karbeat/src/rust/api/automation.dart';
import 'package:karbeat/src/rust/api/track.dart' show UiResizeEdge;
import 'automation_curve_painter.dart';
import 'dart:math' as math;

/// Interactive timeline surface for one automation lane.
class AutomationLaneSlot extends ConsumerStatefulWidget {
  final AutomationLaneDto lane;
  final double height;
  final ScrollController horizontalScrollController;
  final Color trackColor;
  final int sampleRate;

  const AutomationLaneSlot({
    super.key,
    required this.lane,
    required this.height,
    required this.horizontalScrollController,
    required this.trackColor,
    required this.sampleRate,
  });

  @override
  ConsumerState<AutomationLaneSlot> createState() => _AutomationLaneSlotState();
}

typedef AutomationPointId = int;

/// Where a dragged point came from, so the preview orders it like the engine:
/// [others] excludes the point; [index] and [time] are unset for new points.
typedef _PointDragOrigin = ({
  IList<AutomationPointDto> others,
  int? index,
  int? time,
});

/// In-progress vertical drag of a segment's tension handle.
typedef _TensionDrag = ({
  int pointId,
  double startY,
  double startTension,
  double direction,
});

/// In-progress drag of one Bezier handle of the segment starting at
/// [pointId]; [startHandles] detects a drag that changed nothing.
typedef _BezierDrag = ({
  int pointId,
  int nextPointId,
  bool isFirst,
  BezierHandlesDto startHandles,
});

/// In-progress move or resize of the selected regions, started on this lane.
/// [startX] is where the pointer went down and [leaderStart] / [leaderEnd]
/// span the earliest selected item, whose edge snaps to the grid.
typedef _RegionDrag = ({
  BatchDragAction action,
  double startX,
  int leaderStart,
  int leaderEnd,
});

class _AutomationLaneSlotState extends ConsumerState<AutomationLaneSlot> {
  /// Minimum segment width in pixels before a tension handle is offered.
  static const double _minTensionSegmentWidth = 16.0;

  /// Height of the title strip along the top of a region. Dragging it moves
  /// the region with any tool.
  static const double _regionHeaderHeight = 14.0;

  /// Distance from a region edge, in pixels, that the Resize tool grabs.
  static const double _regionEdgeGrab = 8.0;

  _RegionDrag? _regionDrag;

  /// Regions crossed by a Delete tool swipe.
  final Set<int> _deleteSwipeRegionIds = <int>{};
  bool _isDeleteSwiping = false;

  /// Region pressed with the Select or Slice tool, and where. It acts on
  /// release when the pointer barely moved.
  int? _pressedRegionId;
  double? _pressX;

  /// Scrolls the timeline while a region drag or range nears its edge.
  late final TimelineEdgeAutoScroller _autoScroller = TimelineEdgeAutoScroller(
    onScrolled: (_) => _replayLastPointer(),
  );

  /// Last pointer event of the drag in progress, replayed when the timeline
  /// scrolls under a still pointer.
  PointerEvent? _lastDragEvent;

  // Optimistic UI state
  IList<AutomationPointDto>? _localPoints;
  int? _draggedPointId;
  _PointDragOrigin? _pointDragOrigin;
  _TensionDrag? _tensionDrag;
  _BezierDrag? _bezierDrag;

  /// Whether a Select tool drag is painting a range on this lane.
  bool _isSelectingRange = false;

  /// Tick where the Select tool was pressed. The range only starts once the
  /// pointer moves, so pressing inside an existing range keeps it.
  int? _selectionPressTick;
  int? _hoveredTensionPointId;
  IMap<AutomationPointId, AutomationPointHitbox> _pointHitboxes =
      const IMapConst({});
  IList<AutomationTensionHitbox> _tensionHitboxes = const IListConst([]);
  IList<AutomationBezierHitbox> _bezierHitboxes = const IListConst([]);

  bool get _isInteracting =>
      _draggedPointId != null ||
      _tensionDrag != null ||
      _bezierDrag != null ||
      _regionDrag != null ||
      _isDeleteSwiping ||
      _isSelectingRange;

  CurveSampler get _sampler => ref.read(curveSamplerProvider);

  int get _laneId => widget.lane.id;

  @override
  void dispose() {
    _autoScroller.stop();
    super.dispose();
  }

  // =========================================================================
  // REGIONS
  // =========================================================================

  AutomationRegionDto? _regionAtX(double localX) =>
      widget.lane.regionAt(_getTicksFromX(localX).floor());

  /// The region whose edge is under [localX], and whether it is the left
  /// edge.
  (AutomationRegionDto, UiResizeEdge)? _regionEdgeAt(double localX) {
    final zoom = ref.read(workspaceStateProvider).horizontalZoomLevel;
    for (final region in widget.lane.regions) {
      final left = region.startTicks / zoom;
      final right = region.endTicks / zoom;
      if ((localX - left).abs() <= _regionEdgeGrab && localX >= left - 2) {
        return (region, UiResizeEdge.left);
      }
      if ((localX - right).abs() <= _regionEdgeGrab && localX <= right + 2) {
        return (region, UiResizeEdge.right);
      }
    }
    return null;
  }

  /// Follows a drag with the edge auto-scroller.
  void _trackDragPointer(PointerEvent event) {
    _lastDragEvent = event;
    _autoScroller.update(context, event.position);
  }

  void _endDragPointer() {
    _lastDragEvent = null;
    _autoScroller.stop();
  }

  /// Runs the active drag again for its last pointer position, which now lies
  /// over another part of the scrolled timeline.
  void _replayLastPointer() {
    final last = _lastDragEvent;
    final box = context.findRenderObject();
    if (last == null || box is! RenderBox || !mounted) return;
    _onPointerMove(
      PointerMoveEvent(
        pointer: last.pointer,
        position: last.position,
        buttons: last.buttons,
        kind: last.kind,
      ).transformed(Matrix4.tryInvert(box.getTransformTo(null))),
    );
  }

  /// Starts moving or resizing the selected regions from [region]. A region
  /// outside the selection replaces it, or joins it with Ctrl held.
  void _startRegionDrag(
    AutomationRegionDto region,
    BatchDragAction action,
    double localX,
  ) {
    final trackList = ref.read(trackListStateProvider.notifier);
    if (!ref
        .read(trackListStateProvider)
        .regionsSelectedOn(_laneId)
        .contains(region.id)) {
      trackList.selectRegion(
        laneId: _laneId,
        regionId: region.id,
        additive: HardwareKeyboard.instance.isControlPressed,
      );
    }
    final spans = trackList.selectionSpans();
    final leader = spans.isEmpty
        ? (region.startTicks, region.endTicks)
        : spans.reduce((a, b) => a.$1 <= b.$1 ? a : b);
    setState(() {
      _regionDrag = (
        action: action,
        startX: localX,
        leaderStart: leader.$1,
        leaderEnd: leader.$2,
      );
    });
    ref
        .read(clipPlacementProvider.notifier)
        .startBatchDrag(
          clipIds: const [],
          action: action,
          originalTrackId: -1,
          isSelectionDrag: true,
        );
  }

  void _updateRegionDrag(_RegionDrag drag, double localX) {
    final raw = _getTicksFromX(localX - drag.startX).round();
    final trackList = ref.read(trackListStateProvider.notifier);
    final delta = switch (drag.action) {
      BatchDragAction.move => trackList.clampSelectionMove(
        _snapTicks(drag.leaderStart + raw) - drag.leaderStart,
      ),
      BatchDragAction.resizeLeft => trackList.clampSelectionResize(
        UiResizeEdge.left,
        _snapTicks(drag.leaderStart + raw) - drag.leaderStart,
      ),
      BatchDragAction.resizeRight => trackList.clampSelectionResize(
        UiResizeEdge.right,
        _snapTicks(drag.leaderEnd + raw) - drag.leaderEnd,
      ),
      BatchDragAction.none => 0,
    };
    ref
        .read(clipPlacementProvider.notifier)
        .updateBatchDrag(targetTrackId: -1, snappedDeltaTicks: delta);
  }

  void _finishRegionDrag(_RegionDrag drag) {
    final delta = ref.read(clipPlacementProvider).snappedDeltaTicks;
    ref.read(clipPlacementProvider.notifier).cancelBatchDrag();
    setState(() => _regionDrag = null);
    final trackList = ref.read(trackListStateProvider.notifier);
    switch (drag.action) {
      case BatchDragAction.move:
        trackList.moveSelection(delta);
      case BatchDragAction.resizeLeft:
        trackList.resizeSelection(
          UiResizeEdge.left,
          delta,
          stretch: ref.read(workspaceStateProvider).resizeStretches,
        );
      case BatchDragAction.resizeRight:
        trackList.resizeSelection(
          UiResizeEdge.right,
          delta,
          stretch: ref.read(workspaceStateProvider).resizeStretches,
        );
      case BatchDragAction.none:
        break;
    }
  }

  /// Cuts [regionId] at the snapped tick under [localX]. A region of a
  /// multi-lane selection cuts the whole selection.
  void _sliceRegionAt(int regionId, double localX) {
    final tick = _tickAt(localX);
    final selection = ref.read(trackListStateProvider);
    if (selection.spansLanes &&
        selection.regionsSelectedOn(_laneId).contains(regionId)) {
      ref.read(trackListStateProvider.notifier).sliceSelection(tick);
      return;
    }
    ref
        .read(automationProvider.notifier)
        .sliceRegion(laneId: _laneId, regionId: regionId, atTick: tick);
  }

  /// Selects the region clicked with the Select tool; Ctrl toggles it in the
  /// selection instead.
  void _clickRegion(int regionId) {
    final trackList = ref.read(trackListStateProvider.notifier);
    final selected = ref
        .read(trackListStateProvider)
        .regionsSelectedOn(_laneId)
        .contains(regionId);
    if (!HardwareKeyboard.instance.isControlPressed) {
      trackList.selectRegion(laneId: _laneId, regionId: regionId);
    } else if (selected) {
      trackList.removeRegionFromSelection(laneId: _laneId, regionId: regionId);
    } else {
      trackList.selectRegion(
        laneId: _laneId,
        regionId: regionId,
        additive: true,
      );
    }
  }

  void _collectDeleteRegion(double localX) {
    final region = _regionAtX(localX);
    if (region == null || _deleteSwipeRegionIds.contains(region.id)) return;
    setState(() => _deleteSwipeRegionIds.add(region.id));
  }

  void _finishDeleteSwipe() {
    final regionIds = _deleteSwipeRegionIds.toList(growable: false);
    setState(() {
      _isDeleteSwiping = false;
      _deleteSwipeRegionIds.clear();
    });
    if (regionIds.isEmpty) return;
    ref
        .read(automationProvider.notifier)
        .deleteRegions(laneId: _laneId, regionIds: regionIds);
  }

  @override
  void didUpdateWidget(covariant AutomationLaneSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync with Rust backend changes UNLESS we are currently dragging
    if (!_isInteracting) {
      _localPoints = null;
    }
  }

  double _getTicksFromX(double localX) {
    final zoomLevel = ref.read(workspaceStateProvider).horizontalZoomLevel;
    return localX * zoomLevel;
  }

  /// Calculates the purely normalized value (0.0 to 1.0) from the Y pixel coordinate.
  /// This perfectly maps to the backend's NormalizedF64 newtype.
  double _getValueFromY(double localY) {
    // Y=0 is top (1.0), Y=height is bottom (0.0)
    final normalized = 1.0 - (localY / widget.height);
    return normalized.clamp(0.0, 1.0);
  }

  /// Snapped tick under the horizontal pixel position [localX].
  int _tickAt(double localX) =>
      _snapTicks(_getTicksFromX(localX).toInt()).clamp(0, 999999999);

  int _snapTicks(int ticks) {
    final state = ref.read(workspaceStateProvider);

    if (!state.snapToGrid) return ticks;

    final ticksPerGrid = (960 * state.gridSize.sizeInBeat).round();

    if (ticksPerGrid <= 0) return ticks;

    return ((ticks / ticksPerGrid).round() * ticksPerGrid).toInt();
  }

  /// Returns the ID of the nearest point whose hit area contains [localPos]
  int? _findPointIdAt(Offset localPos) {
    AutomationPointHitbox? nearest;
    var nearestDistance = double.infinity;

    for (final hitbox in _pointHitboxes.values) {
      if (!hitbox.rect.contains(localPos)) continue;
      final distance = (hitbox.center - localPos).distanceSquared;
      if (distance < nearestDistance) {
        nearest = hitbox;
        nearestDistance = distance;
      }
    }
    return nearest?.pointId;
  }

  /// Returns the tension handle under [localPos], if any.
  AutomationTensionHitbox? _findTensionHandleAt(Offset localPos) {
    for (final hitbox in _tensionHitboxes) {
      if (hitbox.rect.contains(localPos)) return hitbox;
    }
    return null;
  }

  /// Builds one tension handle per segment whose curve bends with tension,
  /// placed on the curve at the segment's time midpoint.
  IList<AutomationTensionHitbox> _buildTensionHitboxes({
    required List<AutomationPointDto> points,
    required double zoom,
    required double height,
  }) {
    const hitRadius = 7.0;
    if (points.length < 2) return const IListConst([]);
    final sampler = _sampler;
    final midpoints = sampler.segmentMidpoints(points);
    final handles = <AutomationTensionHitbox>[];

    for (var i = 0; i < points.length - 1 && i < midpoints.length; i++) {
      final from = points[i];
      final to = points[i + 1];
      if (!sampler.traits(from.curveType).supportsTension) continue;

      final x1 = from.timeTicks / zoom;
      final x2 = to.timeTicks / zoom;
      if (x2 - x1 < _minTensionSegmentWidth) continue;

      final center = Offset((x1 + x2) / 2, height - midpoints[i] * height);
      handles.add((
        pointId: from.id,
        nextPointId: to.id,
        center: center,
        rect: Rect.fromCircle(center: center, radius: hitRadius),
      ));
    }
    return handles.lock;
  }

  /// Builds the two handles of every Bezier segment. A handle's horizontal
  /// position is a fraction of its segment and its height a lane value.
  IList<AutomationBezierHitbox> _buildBezierHitboxes({
    required List<AutomationPointDto> points,
    required double zoom,
    required double height,
  }) {
    const hitRadius = 8.0;
    final sampler = _sampler;
    final handles = <AutomationBezierHitbox>[];

    for (var i = 0; i < points.length - 1; i++) {
      final from = points[i];
      final to = points[i + 1];
      final bezier = from.handles;
      if (bezier == null || !sampler.traits(from.curveType).usesHandles) {
        continue;
      }

      final x1 = from.timeTicks / zoom;
      final x2 = to.timeTicks / zoom;
      if (x2 - x1 < _minTensionSegmentWidth) continue;

      Offset at(double x, double y) =>
          Offset(x1 + (x2 - x1) * x, height - y.clamp(0.0, 1.0) * height);
      for (final (isFirst, center, anchor) in [
        (true, at(bezier.x1, bezier.y1), at(0, from.value)),
        (false, at(bezier.x2, bezier.y2), at(1, to.value)),
      ]) {
        handles.add((
          pointId: from.id,
          isFirst: isFirst,
          center: center,
          anchor: anchor,
          rect: Rect.fromCircle(center: center, radius: hitRadius),
        ));
      }
    }
    return handles.lock;
  }

  IMap<int, AutomationPointHitbox> _buildHitboxes({
    required Iterable<AutomationPointDto> points,
    required double zoom,
    required double height,
  }) {
    const hitRadius = 10.0;

    return IMap.fromEntries(
      points.map((point) {
        final center = Offset(
          point.timeTicks / zoom,
          height - point.value.clamp(0.0, 1.0) * height,
        );

        return MapEntry(point.id, (
          pointId: point.id,
          center: center,
          rect: Rect.fromCircle(center: center, radius: hitRadius),
        ));
      }),
    );
  }

  // =========================================================================
  // GESTURE HANDLERS
  // =========================================================================

  void _onPointerDown(PointerDownEvent event) {
    final isRightClick = event.buttons == kSecondaryButton;
    final pointId = _findPointIdAt(event.localPosition);

    // A paste from the lane menu or Ctrl+V lands where the lane was last
    // clicked.
    ref
        .read(automationEditorProvider.notifier)
        .markPasteTarget(
          laneId: widget.lane.id,
          tick: _tickAt(event.localPosition.dx),
        );
    if (isRightClick) return;

    final tool = ref.read(workspaceStateProvider).selectedTool;
    final local = event.localPosition;
    final region = _regionAtX(local.dx);

    // The Select tool paints a time range instead of editing points. The
    // range may go on over other tracks and lanes.
    if (tool == ToolSelection.select) {
      final tick = _tickAt(local.dx);
      setState(() {
        _isSelectingRange = true;
        _selectionPressTick = tick;
        _pressedRegionId = region?.id;
      });
      ref
          .read(rangeSelectProvider.notifier)
          .start(TimelineRow.lane(_laneId), tick.toDouble());
      return;
    }

    switch (tool) {
      case ToolSelection.move when region != null:
        _startRegionDrag(region, BatchDragAction.move, local.dx);
        return;
      case ToolSelection.resize:
        final edge = _regionEdgeAt(local.dx);
        if (edge != null) {
          _startRegionDrag(
            edge.$1,
            edge.$2 == UiResizeEdge.left
                ? BatchDragAction.resizeLeft
                : BatchDragAction.resizeRight,
            local.dx,
          );
          return;
        }
      case ToolSelection.slice when region != null && pointId == null:
        _pressedRegionId = region.id;
        _pressX = local.dx;
        return;
      case ToolSelection.delete when pointId != null:
        ref
            .read(automationEditorProvider.notifier)
            .deletePoint(laneId: _laneId, pointId: pointId);
        return;
      case ToolSelection.delete when region != null:
        setState(() {
          _isDeleteSwiping = true;
          _deleteSwipeRegionIds
            ..clear()
            ..add(region.id);
        });
        return;
      default:
        break;
    }

    // With any other tool, a region's title strip moves the region.
    if (pointId == null && region != null && local.dy < _regionHeaderHeight) {
      _startRegionDrag(region, BatchDragAction.move, local.dx);
      return;
    }

    // Left Click Logic
    if (pointId != null) {
      final points = widget.lane.points;
      final index = points.indexWhere((p) => p.id == pointId);
      setState(() {
        _draggedPointId = pointId;
        _pointDragOrigin = (
          others: points.where((p) => p.id != pointId).toIList(),
          index: index,
          time: points[index].timeTicks,
        );
        _localPoints = points.toIList();
      });
      return;
    }

    final bezierHandle = _bezierHitboxes
        .where((hitbox) => hitbox.rect.contains(event.localPosition))
        .firstOrNull;
    if (bezierHandle != null) {
      _startBezierDrag(bezierHandle);
      return;
    }

    final tensionHandle = _findTensionHandleAt(event.localPosition);
    if (tensionHandle != null) {
      _startTensionDrag(tensionHandle, event.localPosition.dy);
      return;
    }

    final snappedTicks = _tickAt(event.localPosition.dx);
    final value = _getValueFromY(event.localPosition.dy);

    final tempId = -DateTime.now().microsecondsSinceEpoch;

    final newPoint = AutomationPointDto(
      id: tempId,
      timeTicks: snappedTicks,
      value: value,
      curveType: AutomationCurveTypeDto.linear,
      tension: 0.0,
    );

    final others = widget.lane.points.toIList();
    setState(() {
      _draggedPointId = tempId;
      _pointDragOrigin = (others: others, index: null, time: null);
      _localPoints = placeAutomationPoint(others.unlockView, newPoint).lock;
    });
  }

  void _startTensionDrag(AutomationTensionHitbox handle, double startY) {
    final points = widget.lane.points;
    final from = points.where((p) => p.id == handle.pointId).firstOrNull;
    final to = points.where((p) => p.id == handle.nextPointId).firstOrNull;
    if (from == null || to == null) return;

    setState(() {
      _tensionDrag = (
        pointId: from.id,
        startY: startY,
        startTension: from.tension,
        direction: _tensionDirection(from, to.value),
      );
      _localPoints = points.toIList();
    });
  }

  double _tensionDirection(AutomationPointDto from, double toValue) =>
      tensionDragDirection(
        _sampler.traits(from.curveType),
        from.curveType,
        toValue - from.value,
      );

  void _startBezierDrag(AutomationBezierHitbox handle) {
    final points = widget.lane.points;
    final index = points.indexWhere((p) => p.id == handle.pointId);
    if (index < 0 || index + 1 >= points.length) return;
    final handles = points[index].handles;
    if (handles == null) return;

    setState(() {
      _bezierDrag = (
        pointId: handle.pointId,
        nextPointId: points[index + 1].id,
        isFirst: handle.isFirst,
        startHandles: handles,
      );
      _localPoints = points.toIList();
    });
  }

  void _updateBezierDrag(_BezierDrag drag, Offset local) {
    final points = _localPoints;
    if (points == null) return;
    final index = points.indexWhere((p) => p.id == drag.pointId);
    final nextIndex = points.indexWhere((p) => p.id == drag.nextPointId);
    if (index == -1 || nextIndex == -1) return;
    final from = points[index];
    final handles = from.handles;
    if (handles == null) return;

    final zoom = ref.read(workspaceStateProvider).horizontalZoomLevel;
    final x1 = from.timeTicks / zoom;
    final x2 = points[nextIndex].timeTicks / zoom;
    if (x2 <= x1) return;
    // Handles stay inside their segment so the curve never runs back in time.
    final x = ((local.dx - x1) / (x2 - x1)).clamp(0.0, 1.0);
    final y = _getValueFromY(local.dy);

    setState(() {
      _localPoints = points.replace(
        index,
        from.copyWith(
          handles: drag.isFirst
              ? handles.copyWith(x1: x, y1: y)
              : handles.copyWith(x2: x, y2: y),
        ),
      );
    });
  }

  void _finishBezierDrag(_BezierDrag drag) {
    final handles = _localPoints
        ?.where((p) => p.id == drag.pointId)
        .firstOrNull
        ?.handles;
    if (handles != null && handles != drag.startHandles) {
      ref
          .read(automationEditorProvider.notifier)
          .setPointHandles(
            laneId: widget.lane.id,
            pointId: drag.pointId,
            handles: handles,
          );
    }

    setState(() {
      _bezierDrag = null;
      _localPoints = null; // Yield control back to Rust
    });
  }

  void _updateTensionDrag(_TensionDrag drag, double localY) {
    final points = _localPoints;
    if (points == null) return;
    final index = points.indexWhere((p) => p.id == drag.pointId);
    if (index == -1) return;

    // Dragging a full lane height sweeps the whole -1..1 tension range, and
    // dragging up always raises the curve.
    final delta = (drag.startY - localY) / widget.height * 2.0;
    final tension = (drag.startTension + delta * drag.direction).clamp(
      -1.0,
      1.0,
    );

    setState(() {
      _localPoints = points.replace(
        index,
        points[index].copyWith(tension: tension),
      );
    });
  }

  void _finishTensionDrag(_TensionDrag drag) {
    final point = _localPoints?.where((p) => p.id == drag.pointId).firstOrNull;
    if (point != null && point.tension != drag.startTension) {
      ref
          .read(automationProvider.notifier)
          .updatePoint(
            automationLaneId: widget.lane.id,
            pointId: point.id,
            tension: point.tension,
          );
    }

    setState(() {
      _tensionDrag = null;
      _localPoints = null; // Yield control back to Rust
    });
  }

  void _onPointerMove(PointerMoveEvent event) {
    final regionDrag = _regionDrag;
    if (regionDrag != null) {
      _trackDragPointer(event);
      _updateRegionDrag(regionDrag, event.localPosition.dx);
      return;
    }

    if (_isDeleteSwiping) {
      _trackDragPointer(event);
      _collectDeleteRegion(event.localPosition.dx);
      return;
    }

    if (_isSelectingRange) {
      _trackDragPointer(event);
      final editor = ref.read(automationEditorProvider.notifier);
      final tick = _tickAt(event.localPosition.dx);
      final row = timelineRowAt(context, event.position);
      ref.read(rangeSelectProvider.notifier).update(tick.toDouble(), row: row);
      final pressTick = _selectionPressTick;
      if (pressTick != null) {
        if (tick == pressTick) return;
        editor.startSelection(laneId: widget.lane.id, tick: pressTick);
        _selectionPressTick = null;
      }
      // A range reaching other rows selects items, not this lane's curve.
      if (row != null && row != TimelineRow.lane(_laneId)) {
        editor.clearSelection();
      } else if (ref.read(automationEditorProvider).selectionLaneId ==
          widget.lane.id) {
        editor.extendSelection(laneId: widget.lane.id, tick: tick);
      } else {
        editor.startSelection(laneId: widget.lane.id, tick: tick);
      }
      return;
    }

    final bezierDrag = _bezierDrag;
    if (bezierDrag != null) {
      _updateBezierDrag(bezierDrag, event.localPosition);
      return;
    }

    final tensionDrag = _tensionDrag;
    if (tensionDrag != null) {
      _updateTensionDrag(tensionDrag, event.localPosition.dy);
      return;
    }

    final origin = _pointDragOrigin;
    if (_draggedPointId != null && _localPoints != null && origin != null) {
      final point = _localPoints!
          .where((p) => p.id == _draggedPointId)
          .firstOrNull;
      if (point == null) return;

      final snappedTicks = _tickAt(event.localPosition.dx);
      final value = _getValueFromY(event.localPosition.dy);

      setState(() {
        _localPoints = placeAutomationPoint(
          origin.others.unlockView,
          point.copyWith(timeTicks: snappedTicks, value: value),
          previousIndex: origin.index,
          previousTime: origin.time,
        ).lock;
      });
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    _endDragPointer();

    final regionDrag = _regionDrag;
    if (regionDrag != null) {
      _finishRegionDrag(regionDrag);
      return;
    }

    if (_isDeleteSwiping) {
      _finishDeleteSwipe();
      return;
    }

    final slicedRegionId = _pressedRegionId;
    final pressX = _pressX;
    if (!_isSelectingRange && slicedRegionId != null && pressX != null) {
      _pressedRegionId = null;
      _pressX = null;
      if ((event.localPosition.dx - pressX).abs() < 4) {
        _sliceRegionAt(slicedRegionId, event.localPosition.dx);
      }
      return;
    }

    if (_isSelectingRange) {
      final pressTick = _selectionPressTick;
      final clickedRegionId = _pressedRegionId;
      final rangeSelect = ref.read(rangeSelectProvider.notifier);
      if (pressTick == null) {
        // The pointer dragged: select what the range touched.
        rangeSelect.finish();
      } else {
        rangeSelect.cancel();
        // A click without a drag clears the range, unless it landed inside
        // it. A click on a region selects the region.
        final range = ref
            .read(automationEditorProvider)
            .selectionOf(widget.lane.id);
        final pressedInside =
            range != null && pressTick >= range.$1 && pressTick <= range.$2;
        if (!pressedInside) {
          ref.read(automationEditorProvider.notifier).clearSelection();
        }
        if (clickedRegionId != null) {
          _clickRegion(clickedRegionId);
        } else if (!pressedInside) {
          ref.read(trackListStateProvider.notifier).deselectAllClips();
        }
      }
      setState(() {
        _isSelectingRange = false;
        _selectionPressTick = null;
        _pressedRegionId = null;
      });
      return;
    }

    final bezierDrag = _bezierDrag;
    if (bezierDrag != null) {
      _finishBezierDrag(bezierDrag);
      return;
    }

    final tensionDrag = _tensionDrag;
    if (tensionDrag != null) {
      _finishTensionDrag(tensionDrag);
      return;
    }

    if (_draggedPointId != null && _localPoints != null) {
      final p = _localPoints!.firstWhere((p) => p.id == _draggedPointId);

      if (_draggedPointId! < 0) {
        // A. It was a temporary point -> Tell Rust to ADD it officially
        ref
            .read(automationProvider.notifier)
            .addPoint(widget.lane.id, p.timeTicks, p.value);
      } else {
        // B. It was an existing point -> Tell Rust to UPDATE it
        ref
            .read(automationProvider.notifier)
            .updatePoint(
              automationLaneId: widget.lane.id,
              pointId: p.id,
              timeTicks: p.timeTicks,
              value: p.value,
              tension: p.tension,
            );
      }

      setState(() {
        _draggedPointId = null;
        _pointDragOrigin = null;
        _localPoints = null; // Yield control back to Rust
      });
    }
  }

  /// Opens the point actions menu. Any drag started by the same pointer is
  /// discarded so a long press does not also commit a move.
  void _openPointContextMenu(int pointId) {
    final point = widget.lane.points.where((p) => p.id == pointId).firstOrNull;

    if (_draggedPointId != null) {
      setState(() {
        _draggedPointId = null;
        _pointDragOrigin = null;
        _localPoints = null;
      });
    }

    if (point == null) return;

    showAutomationPointContextMenu(
      context: context,
      ref: ref,
      lane: widget.lane,
      point: point,
    );
  }

  Widget _buildPointHitArea(AutomationPointHitbox hitbox) {
    final editor = ref.read(automationEditorProvider.notifier);
    final laneId = widget.lane.id;

    return Positioned.fromRect(
      key: ValueKey(hitbox.pointId),
      rect: hitbox.rect,
      child: MouseRegion(
        cursor: SystemMouseCursors.grab,
        onEnter: (_) =>
            editor.hoverPoint(laneId: laneId, pointId: hitbox.pointId),
        onExit: (_) =>
            editor.clearHoveredPoint(laneId: laneId, pointId: hitbox.pointId),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onSecondaryTapUp: (_) => _openPointContextMenu(hitbox.pointId),
          onLongPressStart: (_) => _openPointContextMenu(hitbox.pointId),
        ),
      ),
    );
  }

  Widget _buildTensionHitArea(AutomationTensionHitbox hitbox) {
    final editor = ref.read(automationEditorProvider.notifier);
    final laneId = widget.lane.id;

    return Positioned.fromRect(
      key: ValueKey(('tension', hitbox.pointId)),
      rect: hitbox.rect,
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeUpDown,
        onEnter: (_) => setState(() => _hoveredTensionPointId = hitbox.pointId),
        onExit: (_) {
          if (_hoveredTensionPointId != hitbox.pointId) return;
          setState(() => _hoveredTensionPointId = null);
        },
        child: Tooltip(
          message: tensionHandleTooltip,
          waitDuration: const Duration(milliseconds: 600),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onDoubleTap: () => editor.setPointTension(
              laneId: laneId,
              pointId: hitbox.pointId,
              tension: 0,
            ),
          ),
        ),
      ),
    );
  }

  void _onPointerCancel() {
    _endDragPointer();
    if (_regionDrag != null) {
      ref.read(clipPlacementProvider.notifier).cancelBatchDrag();
    }
    if (_isSelectingRange) ref.read(rangeSelectProvider.notifier).cancel();
    setState(() {
      _draggedPointId = null;
      _pointDragOrigin = null;
      _tensionDrag = null;
      _bezierDrag = null;
      _regionDrag = null;
      _isDeleteSwiping = false;
      _deleteSwipeRegionIds.clear();
      _pressedRegionId = null;
      _pressX = null;
      _isSelectingRange = false;
      _selectionPressTick = null;
      _localPoints = null;
    });
  }

  /// One region on the lane: a tinted box with a title strip. Right-click or
  /// long-press opens the region actions; the lane's pointer handlers do the
  /// editing.
  Widget _buildRegion(
    AutomationLaneDto lane,
    AutomationRegionDto region,
    double zoomLevel, {
    required bool selected,
    required bool pendingDelete,
    required ToolSelection tool,
  }) {
    final colors = Theme.of(context).colorScheme;
    final shared = lane.isShared(region);
    final border = selected ? colors.primary : widget.trackColor;
    final width = math.max(2.0, region.lengthTicks / zoomLevel);
    // A long press must not also commit the edit its pointer started.
    void openMenu() {
      _onPointerCancel();
      showAutomationRegionContextMenu(
        context: context,
        ref: ref,
        lane: widget.lane,
        region: region,
      );
    }

    final box = Opacity(
      opacity: pendingDelete ? 0.3 : 1,
      child: Container(
        decoration: BoxDecoration(
          color: widget.trackColor.withValues(alpha: selected ? 0.22 : 0.12),
          border: Border.all(
            color: border.withValues(alpha: selected ? 1 : 0.6),
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Align(
          alignment: Alignment.topLeft,
          child: Container(
            height: _regionHeaderHeight,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            color: border.withValues(alpha: selected ? 0.55 : 0.35),
            child: Row(
              children: [
                if (shared)
                  Padding(
                    padding: const EdgeInsets.only(right: 3),
                    child: Icon(Icons.link, size: 10, color: colors.onSurface),
                  ),
                Expanded(
                  child: Text(
                    region.name,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: TextStyle(
                      color: colors.onSurface,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final cursor = switch (tool) {
      ToolSelection.move => SystemMouseCursors.move,
      ToolSelection.slice => SystemMouseCursors.text,
      ToolSelection.delete => SystemMouseCursors.click,
      _ => MouseCursor.defer,
    };

    return Positioned(
      key: ValueKey(('region', region.id)),
      left: region.startTicks / zoomLevel,
      top: 0,
      width: width,
      height: widget.height,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onSecondaryTapUp: (_) => openMenu(),
        onLongPress: openMenu,
        child: MouseRegion(
          cursor: cursor,
          child: Stack(
            children: [
              Positioned.fill(child: box),
              // The title strip moves the region with any tool.
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: _regionHeaderHeight,
                child: const MouseRegion(cursor: SystemMouseCursors.move),
              ),
              if (tool == ToolSelection.resize) ...[
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: _regionEdgeGrab,
                  child: const MouseRegion(
                    cursor: SystemMouseCursors.resizeLeftRight,
                  ),
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  width: _regionEdgeGrab,
                  child: const MouseRegion(
                    cursor: SystemMouseCursors.resizeLeftRight,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// The selected range; right-click or long-press it for the range actions.
  Widget _buildSelection((int, int) range, double zoomLevel) {
    final colors = Theme.of(context).colorScheme;
    void openMenu() => showAutomationRangeContextMenu(
      context: context,
      ref: ref,
      lane: widget.lane,
    );

    return Positioned(
      left: range.$1 / zoomLevel,
      top: 0,
      bottom: 0,
      width: math.max(2.0, (range.$2 - range.$1) / zoomLevel),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onSecondaryTap: openMenu,
        onLongPress: openMenu,
        child: Container(
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.2),
            border: Border.symmetric(
              vertical: BorderSide(color: colors.primary, width: 2),
            ),
          ),
        ),
      ),
    );
  }

  /// Build Tooltip for edited automation point
  Widget _buildTooltip(int? hoveredPointId) {
    final tensionDrag = _tensionDrag;
    if (tensionDrag != null) return _buildTensionTooltip(tensionDrag);

    // Determine if we should show the tooltip based on dragging or hovering
    final targetId = _draggedPointId ?? hoveredPointId;
    if (targetId == null) {
      return const Positioned.fill(child: SizedBox.shrink());
    }

    final points = _localPoints ?? widget.lane.points;
    final p = points.where((p) => p.id == targetId).firstOrNull;
    if (p == null) return const Positioned.fill(child: SizedBox.shrink());

    final zoomLevel = ref.read(workspaceStateProvider).horizontalZoomLevel;
    final px = p.timeTicks / zoomLevel;
    final py = widget.height - (p.value * widget.height);

    // The automated parameter formats the value in its own unit.
    return _positionedTooltip(
      Offset(px, py),
      _sampler.valueText(widget.lane.id, p.value),
    );
  }

  Widget _buildTensionTooltip(_TensionDrag drag) {
    final handle = _tensionHitboxes
        .where((h) => h.pointId == drag.pointId)
        .firstOrNull;
    final point = _localPoints?.where((p) => p.id == drag.pointId).firstOrNull;
    if (handle == null || point == null) {
      return const Positioned.fill(child: SizedBox.shrink());
    }
    final sampler = _sampler;
    return _positionedTooltip(
      handle.center,
      sampler.traits(point.curveType).tensionIsCount
          ? tr('track-tension-count', {
              'count': sampler.tensionCount(point.tension),
            })
          : tr('track-tension-value', {
              'tension': point.tension.toStringAsFixed(2),
            }),
    );
  }

  Widget _positionedTooltip(Offset anchor, String text) {
    final colors = Theme.of(context).colorScheme;

    // Constrain the tooltip position so it doesn't clip out of the lane bounds
    final double top = (anchor.dy - 32).clamp(
      4.0,
      math.max(4.0, widget.height - 24.0),
    );
    final double left =
        anchor.dx + 12; // Render slightly to the right of the cursor/finger

    return Positioned(
      left: left,
      top: top,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: colors.inverseSurface.withValues(alpha: 0.92),
            border: Border.all(color: widget.trackColor.withAlpha(128)),
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(
                color: colors.shadow.withValues(alpha: 0.6),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            text,
            style: TextStyle(
              color: colors.onInverseSurface,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    // Select only what the lane draws with; the whole workspace and transport
    // stores change for unrelated reasons (playback, other panels).
    final state = ref.watch(
      workspaceStateProvider.select(
        (s) => (
          horizontalZoomLevel: s.horizontalZoomLevel,
          gridSize: s.gridSize,
          selectedTool: s.selectedTool,
        ),
      ),
    );
    final zoomLevel = state.horizontalZoomLevel;
    final gridSize = state.gridSize;
    final tempo =
        ref.watch(transportProvider.select((s) => s.value?.state?.bpm)) ??
        120.0;
    final safeSampleRate = widget.sampleRate <= 0 ? 48000 : widget.sampleRate;

    final laneId = widget.lane.id;
    final hoveredPointId = ref.watch(
      automationEditorProvider.select(
        (s) => s.hoveredLaneId == laneId ? s.hoveredPointId : null,
      ),
    );
    final contextPointId = ref.watch(
      automationEditorProvider.select(
        (s) => s.contextLaneId == laneId ? s.contextPointId : null,
      ),
    );

    final selection = ref.watch(
      automationEditorProvider.select((s) => s.selectionOf(laneId)),
    );
    // The lane's own range is drawn once the range drag is released.
    final isPaintingRange = ref.watch(
      rangeSelectProvider.select((s) => s.isSelecting),
    );
    final isSelectTool = state.selectedTool == ToolSelection.select;
    final sampler = ref.watch(curveSamplerProvider);
    final selectedRegionIds = ref.watch(
      trackListStateProvider.select((s) => s.regionsSelectedOn(laneId)),
    );
    // A drag of the timeline selection previews it on every lane.
    final selectionDrag = ref.watch(
      clipPlacementProvider.select(
        (s) => s.isSelectionDrag && s.isDraggingExisting
            ? (action: s.dragAction, delta: s.snappedDeltaTicks)
            : null,
      ),
    );

    var displayLane = _localPoints != null
        ? widget.lane.copyWith(points: _localPoints!.toList())
        : widget.lane;
    final isPreviewingDrag =
        selectionDrag != null && selectedRegionIds.isNotEmpty;
    if (isPreviewingDrag) {
      final ids = selectedRegionIds.toSet();
      displayLane = switch (selectionDrag.action) {
        BatchDragAction.move => previewRegionMove(
          displayLane,
          ids,
          selectionDrag.delta,
        ),
        BatchDragAction.resizeLeft => previewRegionResize(
          displayLane,
          ids,
          UiResizeEdge.left,
          selectionDrag.delta,
        ),
        BatchDragAction.resizeRight => previewRegionResize(
          displayLane,
          ids,
          UiResizeEdge.right,
          selectionDrag.delta,
        ),
        BatchDragAction.none => displayLane,
      };
    }

    _pointHitboxes = _buildHitboxes(
      points: displayLane.points,
      zoom: zoomLevel,
      height: widget.height,
    );
    _tensionHitboxes = _buildTensionHitboxes(
      points: displayLane.points,
      zoom: zoomLevel,
      height: widget.height,
    );
    _bezierHitboxes = _buildBezierHitboxes(
      points: displayLane.points,
      zoom: zoomLevel,
      height: widget.height,
    );

    return TimelineRowMarker(
      row: TimelineRow.lane(laneId),
      child: Container(
        height: widget.height,
        decoration: BoxDecoration(
          color: colors.surface.withValues(alpha: 0.55),
          border: Border(
            bottom: BorderSide(color: colors.outlineVariant, width: 1),
            right: BorderSide(color: colors.outlineVariant, width: 1),
          ),
        ),
        child: RawGestureDetector(
          behavior: HitTestBehavior.opaque,
          // Claims point and tension drags so the timeline's scroll views and
          // pan gestures never move while a point is being edited.
          gestures: {
            _AutomationEditDragRecognizer:
                GestureRecognizerFactoryWithHandlers<
                  _AutomationEditDragRecognizer
                >(
                  () => _AutomationEditDragRecognizer(debugOwner: this),
                  (recognizer) => recognizer.isEditing = () => _isInteracting,
                ),
          },
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: _onPointerDown,
            onPointerMove: _onPointerMove,
            onPointerUp: _onPointerUp,
            onPointerCancel: (_) => _onPointerCancel(),
            child: Stack(
              children: [
                // 1. Background Grid
                Positioned.fill(
                  child: RepaintBoundary(
                    child: LayoutBuilder(
                      builder: (context, constraint) {
                        return CustomPaint(
                          painter: GridPainter(
                            zoomLevel: zoomLevel,
                            gridSize: gridSize,
                            tempo: tempo,
                            sampleRate: safeSampleRate,
                            scrollController: widget.horizontalScrollController,
                            viewportWidth: constraint.maxWidth,
                            lineColor: colors.onSurface.withValues(alpha: 0.08),
                            barLineColor: colors.onSurface.withValues(
                              alpha: 0.25,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // 2. Regions, under the curve. While the selection is dragged
                // its regions show where they started, faded, under their
                // preview.
                if (isPreviewingDrag)
                  for (final region in widget.lane.regions)
                    if (selectedRegionIds.contains(region.id))
                      Positioned(
                        key: ValueKey(('region-origin', region.id)),
                        left: region.startTicks / zoomLevel,
                        top: 0,
                        width: math.max(2.0, region.lengthTicks / zoomLevel),
                        height: widget.height,
                        child: IgnorePointer(
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: widget.trackColor.withValues(alpha: 0.3),
                              ),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                for (final region in displayLane.regions)
                  _buildRegion(
                    displayLane,
                    region,
                    zoomLevel,
                    selected: selectedRegionIds.contains(region.id),
                    pendingDelete: _deleteSwipeRegionIds.contains(region.id),
                    tool: state.selectedTool,
                  ),

                // 3. Automation Curve Overlay
                Positioned.fill(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: AutomationCurvePainter(
                        lane: displayLane,
                        zoomLevel: zoomLevel,
                        scrollController: widget.horizontalScrollController,
                        trackColor: widget.trackColor,
                        disabledColor: colors.outline,
                        pointColor: colors.onSurface,
                        sampler: sampler,
                        bezierHandles: _bezierHitboxes,
                        highlightedPointId:
                            _draggedPointId ?? contextPointId ?? hoveredPointId,
                        tensionHandles: _tensionHitboxes,
                        highlightedTensionPointId:
                            _tensionDrag?.pointId ?? _hoveredTensionPointId,
                      ),
                    ),
                  ),
                ),

                // 4. Range painted with the Select tool
                if (selection != null &&
                    selection.$2 > selection.$1 &&
                    !isPaintingRange)
                  _buildSelection(selection, zoomLevel),

                // 5. A range being painted across rows
                TrackRangeSelectOverlay(
                  row: TimelineRow.lane(laneId),
                  trackHeight: widget.height,
                  zoomLevel: zoomLevel,
                ),

                // While the Select tool is active the lane only paints ranges,
                // so the point and handle hit areas are left out.
                if (!isSelectTool) ...[
                  // 4. Tension handles, below points so points win overlaps
                  for (final hitbox in _tensionHitboxes)
                    if (hitbox.pointId >= 0 && hitbox.nextPointId >= 0)
                      _buildTensionHitArea(hitbox),

                  // 5. Bezier handles
                  for (final hitbox in _bezierHitboxes)
                    Positioned.fromRect(
                      key: ValueKey(('bezier', hitbox.pointId, hitbox.isFirst)),
                      rect: hitbox.rect,
                      child: const MouseRegion(cursor: SystemMouseCursors.move),
                    ),

                  // 6. Point hit areas for hover and secondary click actions
                  for (final hitbox in _pointHitboxes.values)
                    if (hitbox.pointId >= 0) _buildPointHitArea(hitbox),
                ],

                // 7. Tooltip
                _buildTooltip(hoveredPointId),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Wins the gesture arena once a primary pointer that started a point or
/// tension edit moves past the platform's drag slop, so enclosing scroll views
/// and timeline pan gestures reject the drag. Pointers that lift without
/// moving are released, keeping taps and double-taps on the lane working.
class _AutomationEditDragRecognizer extends OneSequenceGestureRecognizer {
  _AutomationEditDragRecognizer({super.debugOwner})
    : super(allowedButtonsFilter: (buttons) => buttons == kPrimaryButton);

  /// Whether the lane is currently dragging a point or tension handle.
  bool Function() isEditing = () => false;

  Offset? _downPosition;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    _downPosition = event.position;
  }

  @override
  void handleEvent(PointerEvent event) {
    final downPosition = _downPosition;
    if (event is PointerMoveEvent && downPosition != null) {
      final slop = computeHitSlop(event.kind, gestureSettings);
      if (isEditing() && (event.position - downPosition).distance > slop) {
        resolve(GestureDisposition.accepted);
        _release(event.pointer);
      }
    } else if (event is PointerUpEvent || event is PointerCancelEvent) {
      resolve(GestureDisposition.rejected);
      _release(event.pointer);
    }
  }

  @override
  void rejectGesture(int pointer) => _release(pointer);

  void _release(int pointer) {
    _downPosition = null;
    stopTrackingPointer(pointer);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {}

  @override
  String get debugDescription => 'automation edit drag';
}

/// Title-only stand-in for a shrunk automation lane on the timeline. The
/// label follows the horizontal scroll so it stays readable.
class AutomationLaneCollapsedSlot extends StatelessWidget {
  final AutomationLaneDto lane;

  /// What owns the automated parameter, such as the plugin or mixer channel.
  final String sourceName;
  final double height;
  final ScrollController horizontalScrollController;
  final Color trackColor;

  const AutomationLaneCollapsedSlot({
    super.key,
    required this.lane,
    required this.sourceName,
    required this.height,
    required this.horizontalScrollController,
    required this.trackColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          trackColor.withValues(alpha: lane.enabled ? 0.18 : 0.08),
          colors.surface,
        ),
        border: Border(
          bottom: BorderSide(color: colors.outlineVariant, width: 1),
          right: BorderSide(color: colors.outlineVariant, width: 1),
        ),
      ),
      child: AnimatedBuilder(
        animation: horizontalScrollController,
        builder: (context, child) {
          final scrollX = horizontalScrollController.hasClients
              ? horizontalScrollController.positions.first.pixels
              : 0.0;
          return Stack(
            children: [
              Positioned(left: scrollX + 8, top: 0, bottom: 0, child: child!),
            ],
          );
        },
        child: Align(
          alignment: Alignment.centerLeft,
          child: AutomationLaneTitle(
            sourceName: sourceName,
            lane: lane,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}
