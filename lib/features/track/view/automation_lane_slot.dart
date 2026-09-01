import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/automation_provider.dart';
import 'package:karbeat/app/providers/transport_state.dart';
import 'package:karbeat/app/providers/workspace_state.dart';
import 'package:karbeat/features/track/view/grid_painter.dart';
import 'package:karbeat/src/rust/api/automation.dart';
import 'automation_curve_painter.dart';

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

class _AutomationLaneSlotState extends ConsumerState<AutomationLaneSlot> {
  // Optimistic UI state
  IList<AutomationPointDto>? _localPoints;
  int? _draggedPointId;
  int? _hoveredPointId;

  @override
  void didUpdateWidget(covariant AutomationLaneSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync with Rust backend changes UNLESS we are currently dragging
    if (_draggedPointId == null) {
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

  /// Returns the ID of the point if the user clicked within ~15 pixels of it
  int? _findPointIdAt(Offset localPos) {
    final points = _localPoints ?? widget.lane.points;
    final zoomLevel = ref.read(workspaceStateProvider).horizontalZoomLevel;

    const hitBoxPixels = 15.0;

    for (final p in points) {
      final px = p.timeTicks / zoomLevel;
      final py = widget.height - (p.value * widget.height);

      final distance = (Offset(px, py) - localPos).distance;
      if (distance <= hitBoxPixels) {
        return p.id;
      }
    }
    return null;
  }

  // =========================================================================
  // GESTURE HANDLERS
  // =========================================================================

  void _onPointerDown(PointerDownEvent event) {
    final isRightClick = event.buttons == kSecondaryButton;
    final pointId = _findPointIdAt(event.localPosition);

    if (isRightClick) {
      if (pointId != null) {
        // DELETE POINT
        ref
            .read(automationProvider.notifier)
            .removePoint(widget.lane.id, pointId);
      }
      return;
    }

    // Left Click Logic
    if (pointId != null) {
      setState(() {
        _draggedPointId = pointId;
        _localPoints = widget.lane.points.toIList();
      });
    } else {
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

      setState(() {
        _draggedPointId = tempId;
        // Immutably append to the IList
        _localPoints = widget.lane.points.lock.add(newPoint);
      });
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_draggedPointId != null && _localPoints != null) {
      final index = _localPoints!.indexWhere((p) => p.id == _draggedPointId);
      if (index == -1) return;

      final rawTicks = _getTicksFromX(event.localPosition.dx).toInt();
      final snappedTicks = _snapTicks(rawTicks).clamp(0, 999999999);
      final value = _getValueFromY(event.localPosition.dy);

      setState(() {
        final p = _localPoints![index];
        _localPoints = _localPoints!.replace(
          index,
          p.copyWith(timeTicks: snappedTicks, value: value),
        );
      });
    }
  }

  void _onPointerUp(PointerUpEvent event) {
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
        _localPoints = null; // Yield control back to Rust
      });
    }
  }

  void _onPointerCancel() {
    setState(() {
      _draggedPointId = null;
      _localPoints = null;
    });
  }

  /// Build Tooltip for edited automation point
  Widget _buildTooltip() {
    // Determine if we should show the tooltip based on dragging or hovering
    final targetId = _draggedPointId ?? _hoveredPointId;
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
    final colors = Theme.of(context).colorScheme;

    // Constrain the tooltip position so it doesn't clip out of the lane bounds
    final double top = (py - 32).clamp(4.0, widget.height - 24.0);
    final double left =
        px + 12; // Render slightly to the right of the cursor/finger

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
            realVal.toStringAsFixed(2),
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

    final displayLane = _localPoints != null
        ? widget.lane.copyWith(points: _localPoints!.toList())
        : widget.lane;

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
                    ),
                  ),
                ),
              ),

              // 3. Tooltip
              _buildTooltip(),
            ],
          ),
        ),
      ),
    );
  }
}
