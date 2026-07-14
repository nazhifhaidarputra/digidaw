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
  List<AutomationPointDto>? _localPoints;
  int? _draggedPointId;

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
    final scrollX = widget.horizontalScrollController.hasClients
        ? widget.horizontalScrollController.offset
        : 0.0;
    return (localX + scrollX) * zoomLevel;
  }

  double _getValueFromY(double localY) {
    // Y=0 is top (1.0), Y=height is bottom (0.0)
    final normalized = 1.0 - (localY / widget.height);
    return normalized.clamp(0.0, 1.0);
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
    final scrollX = widget.horizontalScrollController.hasClients
        ? widget.horizontalScrollController.offset
        : 0.0;

    const hitBoxPixels = 15.0;

    for (final p in points) {
      final px = (p.timeTicks / zoomLevel) - scrollX;
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
        ref.read(automationProvider.notifier).removePoint(
              widget.lane.id,
              pointId,
            );
      }
    } else {
      if (pointId == null) {
        // ADD NEW POINT
        final rawTicks = _getTicksFromX(event.localPosition.dx).toInt();
        final snappedTicks = _snapTicks(rawTicks).clamp(0, 999999999);
        final value = _getValueFromY(event.localPosition.dy);

        ref.read(automationProvider.notifier).addPoint(
              widget.lane.id,
              snappedTicks,
              value,
            );
      }
    }
  }

  void _onPanStart(DragStartDetails details) {
    final pointId = _findPointIdAt(details.localPosition);
    if (pointId != null) {
      setState(() {
        _draggedPointId = pointId;
        _localPoints = List.from(widget.lane.points);
      });
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_draggedPointId != null && _localPoints != null) {
      final index = _localPoints!.indexWhere((p) => p.id == _draggedPointId);
      if (index == -1) return;

      final rawTicks = _getTicksFromX(details.localPosition.dx).toInt();
      final snappedTicks = _snapTicks(rawTicks).clamp(0, 999999999);
      final value = _getValueFromY(details.localPosition.dy);

      setState(() {
        final p = _localPoints![index];
        _localPoints![index] = p.copyWith(
          timeTicks: snappedTicks,
          value: value,
        );
        // Optional: you can sort _localPoints here if you want lines to uncross 
        // mid-drag, but it's often cleaner to just let the backend fix it on drop.
      });
    }
  }

  void _onPanEnd(DragEndDetails details) {
    if (_draggedPointId != null && _localPoints != null) {
      final p = _localPoints!.firstWhere((p) => p.id == _draggedPointId);

      // Finalize the drag by sending the data to Rust
      ref.read(automationProvider.notifier).updatePoint(
            automationLaneId: widget.lane.id,
            pointId: p.id,
            timeTicks: p.timeTicks,
            value: p.value,
            tension: p.tension,
          );

      setState(() {
        _draggedPointId = null;
        _localPoints = null; // Yield control back to Rust
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(workspaceStateProvider);
    final transportState = ref.watch(transportProvider).value;
    final zoomLevel = state.horizontalZoomLevel;
    final gridSize = state.gridSize;
    final tempo = transportState?.state?.bpm ?? 120.0;
    final safeSampleRate = widget.sampleRate <= 0 ? 48000 : widget.sampleRate;

    final displayLane = _localPoints != null
        ? widget.lane.copyWith(points: _localPoints!)
        : widget.lane;

    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(80),
        border: Border(
          bottom: BorderSide(color: Colors.white.withAlpha(16), width: 1),
          right: BorderSide(color: Colors.white.withAlpha(16), width: 1),
        ),
      ),
      child: Listener(
        onPointerDown: _onPointerDown,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
            onPanStart: _onPanStart,
            onPanUpdate: _onPanUpdate,
            onPanEnd: _onPanEnd,
            onPanCancel: () {
              setState(() {
                _draggedPointId = null;
                _localPoints = null;
              });
            },
          child: Stack(
            children: [
              // 1. Background Grid
              Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: GridPainter(
                      zoomLevel: zoomLevel,
                      gridSize: gridSize,
                      tempo: tempo,
                      sampleRate: safeSampleRate,
                      scrollController: widget.horizontalScrollController,
                    ),
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
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
