import 'package:flutter/material.dart';
import 'package:karbeat/src/rust/api/automation.dart';
import 'dart:math' as math;

class AutomationCurvePainter extends CustomPainter {
  final AutomationLaneDto lane;
  final double zoomLevel;
  final ScrollController scrollController;
  final Color trackColor;

  AutomationCurvePainter({
    required this.lane,
    required this.zoomLevel,
    required this.scrollController,
    required this.trackColor,
  }) : super(repaint: scrollController);

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

    final linePaint = Paint()
      ..color = lane.enabled ? trackColor : Colors.grey.shade600
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final pointPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final path = Path();
    
    // Default Y coordinate (0.0 - 1.0 clamped)
    final defaultY = size.height - (lane.defaultValue.clamp(0.0, 1.0) * size.height);
    
    // Project start X (Tick 0)
    final projectStartX = 0.0;

    if (lane.points.isEmpty) {
      // If there are no points, draw a continuous plateau at the default value
      path.moveTo(projectStartX, defaultY);
      path.lineTo(size.width, defaultY);
      canvas.drawPath(path, linePaint);
      return;
    }

    // Sort points by time just in case, though backend should guarantee this
    final points = List<AutomationPointDto>.from(lane.points)
      ..sort((a, b) => a.timeTicks.compareTo(b.timeTicks));

    // Calculate pixel coordinates for a point
    Offset getPixelCoords(AutomationPointDto p) {
      final x = (p.timeTicks / zoomLevel);
      // Value is 0.0 - 1.0. Y=0 is the top of the canvas in Flutter.
      final y = size.height - (p.value.clamp(0.0, 1.0) * size.height);
      return Offset(x, y);
    }

    final firstPos = getPixelCoords(points.first);

    // 1. Plateau BEFORE the first point
    path.moveTo(projectStartX, firstPos.dy);
    path.lineTo(firstPos.dx, firstPos.dy);
    // Vertical jump to the actual first point value
    path.lineTo(firstPos.dx, firstPos.dy);

    // 2. Draw interpolations BETWEEN points
    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];

      final pos1 = getPixelCoords(p1);
      final pos2 = getPixelCoords(p2);

      path.moveTo(pos1.dx, pos1.dy);

      final curveType = p1.curveType;

      switch (curveType) {
        case AutomationCurveTypeDto.linear:
          path.lineTo(pos2.dx, pos2.dy);
        case AutomationCurveTypeDto.exponential:
          // Exponential: Approximate the curve with multiple small segments
          const int segments = 15;
          final v1 = math.max(p1.value, 0.0001);
          final v2 = math.max(p2.value, 0.0001);

          for (int step = 1; step <= segments; step++) {
            final t = step / segments;
            final currentTick =
                p1.timeTicks + (p2.timeTicks - p1.timeTicks) * t;
            final currentValue = v1 * math.pow((v2 / v1), t);

            final curX = currentTick / zoomLevel;
            final curY =
                size.height - (currentValue.clamp(0.0, 1.0) * size.height);
            path.lineTo(curX, curY);
          }
        case AutomationCurveTypeDto.step:
          // Step: Hold value until the next point, then jump
          path.lineTo(pos2.dx, pos1.dy);
          path.lineTo(pos2.dx, pos2.dy);
      }
    }

    // 3. Plateau AFTER the last point
    final lastPos = getPixelCoords(points.last);
    
    // Ensure we are at the end of the last point's path
    path.moveTo(lastPos.dx, lastPos.dy); 
    // Vertical jump down/up to the default value
    path.lineTo(lastPos.dx, lastPos.dy);
    // Extend the line infinitely to the right (or at least to screen edge)
    path.lineTo(math.max(lastPos.dx, size.width), defaultY);

    // Draw the final path
    canvas.drawPath(path, linePaint);

    // Draw the interactive points (with culling based on viewport)
    final minVisibleX = scrollX - 20;
    final maxVisibleX = scrollX + viewportWidth + 20;

    for (final p in points) {
      final pos = getPixelCoords(p);
      // Only draw points that are visibly on screen (plus a small buffer)
      if (pos.dx >= minVisibleX && pos.dx <= maxVisibleX) {
        canvas.drawCircle(pos, 4.0, pointPaint);
        canvas.drawCircle(
          pos,
          4.0,
          linePaint..strokeWidth = 1.5,
        ); // colored border
      }
    }
  }

  @override
  bool shouldRepaint(covariant AutomationCurvePainter oldDelegate) {
    return oldDelegate.zoomLevel != zoomLevel ||
        oldDelegate.lane != lane || 
        oldDelegate.scrollController != scrollController;
  }
}
