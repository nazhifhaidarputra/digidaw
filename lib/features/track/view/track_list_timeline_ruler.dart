part of 'track_list_screen.dart';

class _TimelineRuler extends ConsumerWidget {
  final ScrollController scrollController;
  final int sampleRate;

  const _TimelineRuler({
    required this.scrollController,
    required this.sampleRate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Read state for drawing
    final zoomLevel = ref.watch(
      workspaceStateProvider.select((s) => s.horizontalZoomLevel),
    );
    final tempo = ref.watch(
      transportProvider.select((s) => s.value?.state?.bpm ?? 120),
    );
    final safeSampleRate = sampleRate <= 0 ? 48000 : sampleRate;

    return RepaintBoundary(
      child: CustomPaint(
        size: Size.zero,
        painter: _TimelineRulerPainter(
          zoomLevel: zoomLevel,
          tempo: tempo,
          sampleRate: safeSampleRate,
          scrollController: scrollController,
        ),
      ),
    );
  }
}

class _TimelineRulerPainter extends CustomPainter {
  final double zoomLevel;
  final double tempo;
  final int sampleRate;
  final ScrollController scrollController;

  _TimelineRulerPainter({
    required this.zoomLevel,
    required this.tempo,
    required this.sampleRate,
    required this.scrollController,
  }) : super(repaint: scrollController);

  @override
  void paint(Canvas canvas, Size size) {
    if (zoomLevel <= 0 || tempo <= 0 || sampleRate <= 0) return;

    // Calculate Intervals
    // In Karbeat, 1 beat is always 960 ticks. zoomLevel is in ticks/pixel.
    const double ticksPerBeat = 960.0;
    final double pixelsPerBeat = ticksPerBeat / zoomLevel;

    if (pixelsPerBeat < 1.0) return;

    // Drawing Settings
    final TextPainter textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    final Paint majorTickPaint = Paint()
      ..color = Colors.white54
      ..strokeWidth = 1.0;

    final Paint minorTickPaint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1.0;

    const int beatsPerBar = 4;
    final double pixelsPerBar = pixelsPerBeat * beatsPerBar;

    // Calculate Visible Range safely
    double startPixel = 0.0;
    double endPixel = size.width;

    // Handle multiple clients safely
    if (scrollController.hasClients) {
      // When a controller is attached to multiple views, .offset throws.
      // We must access specific positions. Since they are synced, taking the first is fine.
      final position = scrollController.positions.first;

      final offset = position.pixels;
      final viewportWidth = position.hasViewportDimension
          ? position.viewportDimension
          : 1000.0;

      const double buffer = 200.0;
      startPixel = (offset - buffer).clamp(0.0, double.infinity);
      endPixel = offset + viewportWidth + buffer;
    }

    // Determine Start Index
    int barIndex = (startPixel / pixelsPerBar).floor();
    if (barIndex < 1) barIndex = 1;

    double currentX = (barIndex - 1) * pixelsPerBar;

    // Draw Loop
    while (currentX < endPixel) {
      if (currentX > size.width) break;

      if (currentX >= startPixel) {
        // Draw Major Tick
        canvas.drawLine(
          Offset(currentX, 15),
          Offset(currentX, size.height),
          majorTickPaint,
        );

        // Draw Bar Number
        textPainter.text = TextSpan(
          text: '$barIndex',
          style: const TextStyle(color: Colors.white70, fontSize: 10),
        );
        textPainter.layout();
        textPainter.paint(canvas, Offset(currentX + 4, 2));
      }

      // Draw Beat Ticks
      if (pixelsPerBeat > 5.0) {
        for (int i = 1; i < beatsPerBar; i++) {
          double beatX = currentX + (pixelsPerBeat * i);

          if (beatX >= startPixel && beatX < endPixel && beatX < size.width) {
            canvas.drawLine(
              Offset(beatX, 22),
              Offset(beatX, size.height),
              minorTickPaint,
            );
          }
        }
      }

      currentX += pixelsPerBar;
      barIndex++;
    }
  }

  @override
  bool shouldRepaint(covariant _TimelineRulerPainter oldDelegate) {
    return oldDelegate.zoomLevel != zoomLevel ||
        oldDelegate.tempo != tempo ||
        oldDelegate.sampleRate != sampleRate ||
        oldDelegate.scrollController != scrollController;
  }
}
