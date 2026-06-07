import 'package:flutter/material.dart';
import 'package:karbeat/src/rust/api/automation.dart'; // Adjust path if needed
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
    if (lane.points.isEmpty || zoomLevel <= 0) return;

    double scrollX = 0;
    if (scrollController.hasClients) {
      scrollX = scrollController.offset;
    }

    final linePaint = Paint()
      ..color = lane.enabled ? trackColor : Colors.grey.shade600
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final pointPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final path = Path();
    
    // Sort points by time just in case, though backend should guarantee this
    final points = List<AutomationPointDto>.from(lane.points)
      ..sort((a, b) => a.timeTicks.compareTo(b.timeTicks));

    // Calculate pixel coordinates for a point
    Offset getPixelCoords(AutomationPointDto p) {
      final x = (p.timeTicks / zoomLevel) - scrollX;
      // Value is 0.0 - 1.0. Y=0 is the top of the canvas in Flutter.
      final y = size.height - (p.value.clamp(0.0, 1.0) * size.height);
      return Offset(x, y);
    }

    final firstPos = getPixelCoords(points.first);
    
    // Draw initial line from 0 to the first point (using default value or first value)
    final startY = size.height - (lane.defaultValue.clamp(0.0, 1.0) * size.height);
    path.moveTo(0 - scrollX, startY);
    path.lineTo(firstPos.dx, firstPos.dy);

    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];

      final pos1 = getPixelCoords(p1);
      final pos2 = getPixelCoords(p2);

      path.moveTo(pos1.dx, pos1.dy);

      // Draw interpolation based on curve type
      // Note: Adjust the type matching based on your generated FRB enums
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
          final currentTick = p1.timeTicks + (p2.timeTicks - p1.timeTicks) * t;
          final currentValue = v1 * math.pow((v2 / v1), t);
          
          final curX = (currentTick / zoomLevel) - scrollX;
          final curY = size.height - (currentValue.clamp(0.0, 1.0) * size.height);
          path.lineTo(curX, curY);
        }
        case AutomationCurveTypeDto.step:
          // Step: Hold value until the next point, then jump
          path.lineTo(pos2.dx, pos1.dy);
          path.lineTo(pos2.dx, pos2.dy);
      }
    }

    // Draw the final path
    canvas.drawPath(path, linePaint);

    // Draw the interactive points
    for (final p in points) {
      final pos = getPixelCoords(p);
      // Only draw points that are visibly on screen
      if (pos.dx >= -10 && pos.dx <= size.width + 10) {
        canvas.drawCircle(pos, 4.0, pointPaint);
        canvas.drawCircle(pos, 4.0, linePaint..strokeWidth = 1.5); // colored border
      }
    }
  }

  @override
  bool shouldRepaint(covariant AutomationCurvePainter oldDelegate) {
    return oldDelegate.zoomLevel != zoomLevel ||
           oldDelegate.lane.points.length != lane.points.length ||
           oldDelegate.scrollController != scrollController;
  }
}