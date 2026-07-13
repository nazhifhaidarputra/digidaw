import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/transport_state.dart';
import 'package:karbeat/app/providers/workspace_state.dart';
import 'package:karbeat/features/track/view/grid_painter.dart';
import 'package:karbeat/src/rust/api/automation.dart';
import 'automation_curve_painter.dart';

class AutomationLaneSlot extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(workspaceStateProvider);
    final transportState = ref.watch(transportProvider).value;
    final zoomLevel = state.horizontalZoomLevel;
    final gridSize = state.gridSize;
    final tempo = transportState?.state?.bpm ?? 120.0;
    final safeSampleRate = sampleRate <= 0 ? 48000 : sampleRate;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(80),
        border: Border(
          bottom: BorderSide(color: Colors.white.withAlpha(16), width: 1),
          right: BorderSide(color: Colors.white.withAlpha(16), width: 1),
        ),
      ),
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
                  scrollController: horizontalScrollController,
                ),
              ),
            ),
          ),

          // 2. Automation Curve Overlay
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: AutomationCurvePainter(
                  lane: lane,
                  zoomLevel: zoomLevel,
                  scrollController: horizontalScrollController,
                  trackColor: trackColor,
                ),
              ),
            ),
          ),

          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) {
                _handlePointInteraction(context, ref, details.localPosition);
              },
              onPanUpdate: (details) {
                _handlePointDrag(
                  context,
                  ref,
                  details.localPosition,
                  details.delta,
                );
              },
              onPanEnd: (details) {
                _finalizePointDrag(context, ref);
              },
            ),
          ),
        ],
      ),
    );
  }

  void _handlePointInteraction(
    BuildContext context,
    WidgetRef ref,
    Offset localPos,
  ) {
    final zoomLevel = ref.read(workspaceStateProvider).horizontalZoomLevel;
    double scrollX = 0;
    if (horizontalScrollController.hasClients) {
      scrollX = horizontalScrollController.offset;
    }

    final absoluteX = localPos.dx + scrollX;

    // 1. Math: Convert Screen Pixels to Data Space
    final ticks = (absoluteX * zoomLevel).toInt();

    // Y=0 is top of screen, Y=height is bottom. Normalized value is 0.0 (bottom) to 1.0 (top)
    final normalizedValue = 1.0 - (localPos.dy / height).clamp(0.0, 1.0);

    // 2. Hit-testing: Did they click near an existing point?
    final existingPointIndex = _findPointIndexAt(
      ticks,
      normalizedValue,
      zoomLevel,
    );

    // TODO: if existingPointIndex != null => Select point for dragging or right-click to delete
    // TODO: if existingPointIndex == null => Create a NEW point at `ticks` and `normalizedValue`
  }

  void _handlePointDrag(
    BuildContext context,
    WidgetRef ref,
    Offset localPos,
    Offset delta,
  ) {
    // TODO: If a point is selected, update its local position visually and snap to grid if enabled
  }

  void _finalizePointDrag(BuildContext context, WidgetRef ref) {
    // TODO: Send the updated point position to Rust via FFI `updateAutomationPoint`
  }

  /// Returns the index of the point if the user clicked within ~15 pixels of it
  int? _findPointIndexAt(
    int targetTicks,
    double targetValue,
    double zoomLevel,
  ) {
    const hitBoxPixels = 15.0;

    for (int i = 0; i < lane.points.length; i++) {
      final p = lane.points[i];

      // Convert point to pixel distance
      final pixelDistX = ((p.timeTicks - targetTicks) / zoomLevel).abs();
      final pixelDistY = ((p.value - targetValue) * height).abs();

      if (pixelDistX <= hitBoxPixels && pixelDistY <= hitBoxPixels) {
        return i;
      }
    }
    return null;
  }
}
