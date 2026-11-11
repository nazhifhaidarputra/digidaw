import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karbeat/features/track/view/grid_painter.dart';
import 'package:karbeat/shared/models/grid.dart';

/// Counts the grid lines a painter draws.
class _LineCountingCanvas implements Canvas {
  int lines = 0;

  @override
  void drawLine(Offset p1, Offset p2, Paint paint) => lines += 1;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  testWidgets('paints only the lines near the visible viewport', (
    tester,
  ) async {
    const timelineWidth = 200000.0;
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              controller: controller,
              child: const SizedBox(width: timelineWidth, height: 50),
            ),
          ),
        ),
      ),
    );
    controller.jumpTo(50000);

    // On the timeline the painter's LayoutBuilder sits inside the scrolled
    // content, so the width it is handed is the whole timeline.
    final painter = GridPainter(
      zoomLevel: 1,
      gridSize: GridSize.eighth,
      tempo: 120,
      sampleRate: 48000,
      scrollController: controller,
      viewportWidth: timelineWidth,
      lineColor: Colors.black,
      barLineColor: Colors.black,
    );
    final canvas = _LineCountingCanvas();
    painter.paint(canvas, const Size(timelineWidth, 50));

    // 400px of viewport plus 200px of buffer each side, lines >= 15px apart.
    expect(canvas.lines, lessThanOrEqualTo((400 + 2 * 200) ~/ 15 + 1));
    expect(canvas.lines, greaterThan(0));
  });
}
