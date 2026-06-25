import 'package:flutter/material.dart';
import 'package:karbeat/shared/models/grid.dart';

class GridPainter extends CustomPainter {
  final double zoomLevel;
  final GridSize gridSize;
  final double tempo;
  final int sampleRate;
  final ScrollController scrollController;

  GridPainter({
    required this.zoomLevel,
    required this.gridSize,
    required this.tempo,
    required this.sampleRate,
    required this.scrollController,
  }) : super(repaint: scrollController);

  @override
  void paint(Canvas canvas, Size size) {
    if (tempo <= 0 ||
        sampleRate <= 0 ||
        zoomLevel <= 0 ||
        gridSize.value <= 0) {
      return;
    }

    // Calculate Grid Dimensions
    final double ticksPerGridLine = (960.0 * 4.0) / gridSize.value;
    double pixelsPerGridLine = ticksPerGridLine / zoomLevel;

    if (pixelsPerGridLine < 0.0001) return;

    int skipFactor = 1;
    while (pixelsPerGridLine * skipFactor < 15.0) {
      skipFactor *= 2;
      if (skipFactor > 1000000) break;
    }

    final double visualInterval = pixelsPerGridLine * skipFactor;

    double startX = 0.0;
    double endX = size.width;

    if (scrollController.hasClients) {
      final position = scrollController.positions.first;
      final double offset = position.pixels;
      double viewportWidth = size.width;
      // Use the local `position` variable — scrollController.position throws
      // when multiple scroll views share the same controller.
      if (position.hasViewportDimension) {
        viewportWidth = position.viewportDimension;
      }

      const double buffer = 200.0;
      startX = (offset - buffer).clamp(0.0, double.infinity);
      endX = offset + viewportWidth + buffer;
    }

    final paint = Paint()
      ..color = Colors.white.withAlpha((0.08 * 255).round())
      ..strokeWidth = 1.0;

    final barPaint = Paint()
      ..color = Colors.white.withAlpha((0.25 * 255).round())
      ..strokeWidth = 1.0;

    // Calculate start index
    int gridIndex = (startX / visualInterval).floor();

    // Use multiplication instead of addition to prevent float drift
    double currentX = gridIndex * visualInterval;

    while (currentX < endX) {
      if (currentX > size.width) break;

      final int actualGridLines = gridIndex * skipFactor;
      // Is this a bar line?
      // A bar = 4 beats × 960 ticks = 3840 ticks. Use integer tick math to
      // avoid a division-by-zero from the old reciprocal `(1/gridSize.value)`.
      final int ticksAtLine = (actualGridLines * ticksPerGridLine).round();
      final bool isBar = (ticksAtLine % 3840 == 0);

      if (currentX >= 0) {
        canvas.drawLine(
          Offset(currentX, 0),
          Offset(currentX, size.height),
          isBar ? barPaint : paint,
        );
      }

      // Increment index and recalculate X to stay precise
      gridIndex++;
      currentX = gridIndex * visualInterval;
    }
  }

  @override
  bool shouldRepaint(covariant GridPainter oldDelegate) {
    return oldDelegate.zoomLevel != zoomLevel ||
        oldDelegate.gridSize != gridSize ||
        oldDelegate.tempo != tempo ||
        oldDelegate.sampleRate != sampleRate ||
        oldDelegate.scrollController != scrollController;
  }
}
