import 'package:flutter/material.dart';
import 'package:karbeat/features/track/models/automation_lane_editor.dart';
import 'package:karbeat/features/track/services/automation_curve_evaluator.dart';
import 'package:karbeat/src/rust/api/automation.dart';
import 'dart:math' as math;

/// Draws an automation lane exactly as the audio engine evaluates it.
class AutomationCurvePainter extends CustomPainter {
  final AutomationLaneDto lane;
  final double zoomLevel;
  final ScrollController scrollController;
  final Color trackColor;
  final Color disabledColor;
  final Color pointColor;
  final int? highlightedPointId;

  /// Tension handles to draw, keyed by the segment's first point.
  final Iterable<AutomationTensionHitbox> tensionHandles;

  /// Segment (first point ID) whose tension handle is hovered or dragged.
  final int? highlightedTensionPointId;

  AutomationCurvePainter({
    required this.lane,
    required this.zoomLevel,
    required this.scrollController,
    required this.trackColor,
    required this.disabledColor,
    required this.pointColor,
    this.highlightedPointId,
    this.tensionHandles = const [],
    this.highlightedTensionPointId,
  }) : super(repaint: scrollController);

  /// Pixel distance between curve samples on shaped segments.
  static const double _sampleSpacing = 3.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (zoomLevel <= 0) return;

    double scrollX = 0;
    double viewportWidth = size.width;

    if (scrollController.hasClients) {
      final position = scrollController.positions.first;
      scrollX = position.pixels;
      if (position.hasViewportDimension) {
        viewportWidth = position.viewportDimension;
      }
    }

    final minVisibleX = scrollX - 20;
    final maxVisibleX = scrollX + viewportWidth + 20;
    final curveColor = lane.enabled ? trackColor : disabledColor;

    final linePaint = Paint()
      ..color = curveColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final pointPaint = Paint()
      ..color = pointColor
      ..style = PaintingStyle.fill;

    double yFor(double value) =>
        size.height - value.clamp(0.0, 1.0) * size.height;
    double xFor(num ticks) => ticks / zoomLevel;

    final path = Path();

    if (lane.points.isEmpty) {
      // The engine holds the lane default when there are no points.
      final defaultY = yFor(lane.defaultValue);
      path.moveTo(0, defaultY);
      path.lineTo(size.width, defaultY);
      canvas.drawPath(path, linePaint);
      return;
    }

    // List order is authoritative: points sharing a tick keep the order the
    // engine evaluates them in, so they must not be re-sorted here.
    final points = lane.points;

    // 1. Hold the first value from the project start.
    final first = points.first;
    path.moveTo(0, yFor(first.value));
    path.lineTo(xFor(first.timeTicks), yFor(first.value));

    // 2. Segments, drawn with the same interpolation as the engine.
    for (var i = 0; i < points.length - 1; i++) {
      final from = points[i];
      final to = points[i + 1];
      final x1 = xFor(from.timeTicks);
      final x2 = xFor(to.timeTicks);

      if (x2 < minVisibleX || x1 > maxVisibleX) {
        path.moveTo(x2, yFor(to.value));
        continue;
      }

      path.moveTo(x1, yFor(from.value));
      _addSegment(path, from, to, x1, x2, yFor);
    }

    // 3. Hold the last value to the end of the timeline.
    final last = points.last;
    final lastY = yFor(last.value);
    path.moveTo(xFor(last.timeTicks), lastY);
    path.lineTo(math.max(xFor(last.timeTicks), size.width), lastY);

    canvas.drawPath(path, linePaint);

    // Tension handles sit on the curve at each shaped segment's midpoint.
    for (final handle in tensionHandles) {
      final center = handle.center;
      if (center.dx < minVisibleX || center.dx > maxVisibleX) continue;
      final isHighlighted = handle.pointId == highlightedTensionPointId;
      if (isHighlighted) {
        canvas.drawCircle(
          center,
          7.0,
          Paint()
            ..color = curveColor.withValues(alpha: 0.3)
            ..style = PaintingStyle.fill,
        );
      }
      canvas.drawCircle(
        center,
        3.0,
        Paint()
          ..color = curveColor
          ..strokeWidth = isHighlighted ? 2.0 : 1.25
          ..style = PaintingStyle.stroke,
      );
    }

    // Draw the interactive points (with culling based on viewport)
    final borderPaint = Paint()
      ..color = curveColor
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    for (final p in points) {
      final pos = Offset(xFor(p.timeTicks), yFor(p.value));
      if (pos.dx < minVisibleX || pos.dx > maxVisibleX) continue;
      if (p.id == highlightedPointId) {
        canvas.drawCircle(
          pos,
          8.0,
          Paint()
            ..color = curveColor.withValues(alpha: 0.35)
            ..style = PaintingStyle.fill,
        );
      }
      canvas.drawCircle(pos, 4.0, pointPaint);
      canvas.drawCircle(pos, 4.0, borderPaint);
    }
  }

  void _addSegment(
    Path path,
    AutomationPointDto from,
    AutomationPointDto to,
    double x1,
    double x2,
    double Function(double value) yFor,
  ) {
    final isStraightLine =
        from.curveType == AutomationCurveTypeDto.linear && from.tension == 0;
    if (from.curveType == AutomationCurveTypeDto.step) {
      path.lineTo(x2, yFor(from.value));
      path.lineTo(x2, yFor(to.value));
      return;
    }
    if (isStraightLine || x2 - x1 <= _sampleSpacing) {
      path.lineTo(x2, yFor(to.value));
      return;
    }

    final steps = ((x2 - x1) / _sampleSpacing).ceil().clamp(2, 512);
    for (var step = 1; step <= steps; step++) {
      final t = step / steps;
      final value = evaluateAutomationSegment(from, to.value, t);
      path.lineTo(x1 + (x2 - x1) * t, yFor(value));
    }
  }

  @override
  bool shouldRepaint(covariant AutomationCurvePainter oldDelegate) {
    return oldDelegate.zoomLevel != zoomLevel ||
        oldDelegate.lane != lane ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.disabledColor != disabledColor ||
        oldDelegate.pointColor != pointColor ||
        oldDelegate.highlightedPointId != highlightedPointId ||
        oldDelegate.highlightedTensionPointId != highlightedTensionPointId ||
        oldDelegate.tensionHandles != tensionHandles ||
        oldDelegate.scrollController != scrollController;
  }
}
