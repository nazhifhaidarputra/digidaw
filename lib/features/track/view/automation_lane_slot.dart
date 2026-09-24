import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/automation_provider.dart';
import 'package:karbeat/app/providers/transport_state.dart';
import 'package:karbeat/app/providers/workspace_state.dart';
import 'package:karbeat/features/track/models/automation_lane_editor.dart';
import 'package:karbeat/features/track/services/automation_curve_evaluator.dart';
import 'package:karbeat/features/track/services/automation_editor_service.dart';
import 'package:karbeat/features/track/view/automation_point_context_menu.dart';
import 'package:karbeat/features/track/view/grid_painter.dart';
import 'package:karbeat/src/rust/api/automation.dart';
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

class _AutomationLaneSlotState extends ConsumerState<AutomationLaneSlot> {
  /// Minimum segment width in pixels before a tension handle is offered.
  static const double _minTensionSegmentWidth = 16.0;

  // Optimistic UI state
  IList<AutomationPointDto>? _localPoints;
  int? _draggedPointId;
  _PointDragOrigin? _pointDragOrigin;
  _TensionDrag? _tensionDrag;
  int? _hoveredTensionPointId;
  IMap<AutomationPointId, AutomationPointHitbox> _pointHitboxes =
      const IMapConst({});
  IList<AutomationTensionHitbox> _tensionHitboxes = const IListConst([]);

  bool get _isInteracting => _draggedPointId != null || _tensionDrag != null;

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

  /// Optional: Use this if you ever need to draw a UI tooltip while dragging
  /// to show the user the real-world parameter value (e.g., " -6.0 dB").
  double _getDenormalizedValue(double normalizedValue) {
    return widget.lane.min +
        normalizedValue * (widget.lane.max - widget.lane.min);
  }

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

  /// Builds one tension handle per shaped segment, placed on the curve at the
  /// segment's time midpoint.
  IList<AutomationTensionHitbox> _buildTensionHitboxes({
    required Iterable<AutomationPointDto> points,
    required double zoom,
    required double height,
  }) {
    const hitRadius = 7.0;
    final sorted = points.toList();
    final handles = <AutomationTensionHitbox>[];

    for (var i = 0; i < sorted.length - 1; i++) {
      final from = sorted[i];
      final to = sorted[i + 1];
      if (!automationSegmentSupportsTension(from)) continue;

      final x1 = from.timeTicks / zoom;
      final x2 = to.timeTicks / zoom;
      if (x2 - x1 < _minTensionSegmentWidth) continue;

      final value = evaluateAutomationSegment(from, to.value, 0.5);
      final center = Offset((x1 + x2) / 2, height - value * height);
      handles.add((
        pointId: from.id,
        nextPointId: to.id,
        center: center,
        rect: Rect.fromCircle(center: center, radius: hitRadius),
      ));
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

    if (isRightClick) {
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

    final tensionHandle = _findTensionHandleAt(event.localPosition);
    if (tensionHandle != null) {
      _startTensionDrag(tensionHandle, event.localPosition.dy);
      return;
    }

    final rawTicks = _getTicksFromX(event.localPosition.dx).toInt();
    final snappedTicks = _snapTicks(rawTicks).clamp(0, 999999999);
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
        direction: automationTensionDirection(from, to.value),
      );
      _localPoints = points.toIList();
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

      final rawTicks = _getTicksFromX(event.localPosition.dx).toInt();
      final snappedTicks = _snapTicks(rawTicks).clamp(0, 999999999);
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
          message: 'Drag to bend the curve, double-click to reset',
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
    setState(() {
      _draggedPointId = null;
      _pointDragOrigin = null;
      _tensionDrag = null;
      _localPoints = null;
    });
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

    final realVal = _getDenormalizedValue(p.value);
    return _positionedTooltip(Offset(px, py), realVal.toStringAsFixed(2));
  }

  Widget _buildTensionTooltip(_TensionDrag drag) {
    final handle = _tensionHitboxes
        .where((h) => h.pointId == drag.pointId)
        .firstOrNull;
    final point = _localPoints?.where((p) => p.id == drag.pointId).firstOrNull;
    if (handle == null || point == null) {
      return const Positioned.fill(child: SizedBox.shrink());
    }
    return _positionedTooltip(
      handle.center,
      'Tension ${point.tension.toStringAsFixed(2)}',
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
    final state = ref.watch(workspaceStateProvider);
    final transportState = ref.watch(transportProvider).value;
    final zoomLevel = state.horizontalZoomLevel;
    final gridSize = state.gridSize;
    final tempo = transportState?.state?.bpm ?? 120.0;
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

    final displayLane = _localPoints != null
        ? widget.lane.copyWith(points: _localPoints!.toList())
        : widget.lane;

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

    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.55),
        border: Border(
          bottom: BorderSide(color: colors.outlineVariant, width: 1),
          right: BorderSide(color: colors.outlineVariant, width: 1),
        ),
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // Empty callbacks absorb the drag gestures, preventing the parent
        // horizontalScrollController from scrolling while interacting here.
        onHorizontalDragStart: (_) {},
        onHorizontalDragUpdate: (_) {},
        onHorizontalDragEnd: (_) {},
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

              // 2. Automation Curve Overlay
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
                      highlightedPointId:
                          _draggedPointId ?? contextPointId ?? hoveredPointId,
                      tensionHandles: _tensionHitboxes,
                      highlightedTensionPointId:
                          _tensionDrag?.pointId ?? _hoveredTensionPointId,
                    ),
                  ),
                ),
              ),

              // 3. Tension handles, below points so points win overlaps
              for (final hitbox in _tensionHitboxes)
                if (hitbox.pointId >= 0 && hitbox.nextPointId >= 0)
                  _buildTensionHitArea(hitbox),

              // 4. Point hit areas for hover and secondary click actions
              for (final hitbox in _pointHitboxes.values)
                if (hitbox.pointId >= 0) _buildPointHitArea(hitbox),

              // 5. Tooltip
              _buildTooltip(hoveredPointId),
            ],
          ),
        ),
      ),
    );
  }
}

/// Title-only stand-in for a shrunk automation lane on the timeline. The
/// label follows the horizontal scroll so it stays readable.
class AutomationLaneCollapsedSlot extends StatelessWidget {
  final AutomationLaneDto lane;
  final double height;
  final ScrollController horizontalScrollController;
  final Color trackColor;

  const AutomationLaneCollapsedSlot({
    super.key,
    required this.lane,
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
          child: Text(
            lane.label,
            style: TextStyle(
              color: lane.enabled ? colors.onSurface : colors.onSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
          ),
        ),
      ),
    );
  }
}
