import 'package:flutter/material.dart';
import 'package:karbeat/features/track/models/automation_lane_editor.dart';
import 'package:karbeat/features/track/services/automation_curve_evaluator.dart';
import 'package:karbeat/features/track/services/curve_sampler.dart';
import 'package:karbeat/src/rust/api/automation.dart';
import 'dart:math' as math;

/// Draws an automation lane exactly as the audio engine evaluates it: every
/// curve value comes from the engine's own code through [sampler].
class AutomationCurvePainter extends CustomPainter {
  final AutomationLaneDto lane;
  final double zoomLevel;
  final ScrollController scrollController;
  final Color trackColor;
  final Color disabledColor;
  final Color pointColor;
  final int? highlightedPointId;

  /// Source of the drawn curve values.
  final CurveSampler sampler;

  /// Tension handles to draw, keyed by the segment's first point.
  final Iterable<AutomationTensionHitbox> tensionHandles;

  /// Segment (first point ID) whose tension handle is hovered or dragged.
  final int? highlightedTensionPointId;

  /// Bezier handles to draw, two per Bezier segment.
  final Iterable<AutomationBezierHitbox> bezierHandles;

  AutomationCurvePainter({
    required this.lane,
    required this.zoomLevel,
    required this.scrollController,
    required this.trackColor,
    required this.disabledColor,
    required this.pointColor,
    required this.sampler,
    this.highlightedPointId,
    this.tensionHandles = const [],
    this.highlightedTensionPointId,
    this.bezierHandles = const [],
  }) : super(repaint: scrollController);

  /// Pixel distance between curve samples.
  static const double _sampleSpacing = 1.5;

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

    if (lane.points.isEmpty) {
      // The engine holds the lane default when there are no points.
      final defaultY = yFor(lane.defaultValue);
      canvas.drawLine(
        Offset(0, defaultY),
        Offset(size.width, defaultY),
        linePaint,
      );
      return;
    }

    // List order is authoritative: points sharing a tick keep the order the
    // engine evaluates them in, so they must not be re-sorted here.
    final points = lane.points;

    final startX = math.max(0.0, minVisibleX);
    final endX = math.min(size.width, maxVisibleX);
    if (endX > startX) {
      canvas.drawPath(_curvePath(points, startX, endX, xFor, yFor), linePaint);
    }

    // Bezier handles hang off the two points of their segment.
    final guidePaint = Paint()
      ..color = curveColor.withValues(alpha: 0.6)
      ..strokeWidth = 1.0;
    for (final handle in bezierHandles) {
      if (handle.center.dx < minVisibleX && handle.anchor.dx < minVisibleX) {
        continue;
      }
      if (handle.center.dx > maxVisibleX && handle.anchor.dx > maxVisibleX) {
        continue;
      }
      canvas.drawLine(handle.anchor, handle.center, guidePaint);
      canvas.drawRect(
        Rect.fromCenter(center: handle.center, width: 6, height: 6),
        Paint()..color = curveColor,
      );
    }

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

  /// Builds the curve between [startX] and [endX] from engine samples. The
  /// lane's points are added as exact vertices so corners and jumps stay
  /// sharp whatever the sampling step.
  Path _curvePath(
    List<AutomationPointDto> points,
    double startX,
    double endX,
    double Function(num ticks) xFor,
    double Function(double value) yFor,
  ) {
    final startTick = startX * zoomLevel;
    final endTick = endX * zoomLevel;

    // Only the points that shape the visible window cross the bridge: the
    // one before it, those inside it, and the one after it.
    final first = math.max(0, automationIndexAfterTick(points, startTick) - 1);
    final last = math.min(
      points.length,
      automationIndexAfterTick(points, endTick) + 1,
    );
    final visible = points.sublist(first, last);

    final count = ((endX - startX) / _sampleSpacing).ceil().clamp(2, 4096);
    final samples = sampler.sampleLane(
      visible,
      startTick: startTick,
      endTick: endTick,
      count: count,
    );

    final path = Path();
    if (samples.isEmpty) return path;
    path.moveTo(startX, yFor(samples.first));

    var next = 0;
    while (next < visible.length && xFor(visible[next].timeTicks) <= startX) {
      next++;
    }
    final step = (endX - startX) / (count - 1);
    for (var i = 1; i < samples.length; i++) {
      final x = startX + step * i;
      while (next < visible.length && xFor(visible[next].timeTicks) <= x) {
        final point = visible[next];
        path.lineTo(xFor(point.timeTicks), yFor(point.value));
        next++;
      }
      path.lineTo(x, yFor(samples[i]));
    }
    return path;
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
        oldDelegate.bezierHandles != bezierHandles ||
        oldDelegate.sampler != sampler ||
        oldDelegate.scrollController != scrollController;
  }
}
