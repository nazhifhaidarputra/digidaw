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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return RepaintBoundary(
      // LayoutBuilder gives us the real viewport width on every layout pass
      // (including first paint and window resize), so the painter never falls
      // back to an invalid scrollController.viewportDimension.
      child: LayoutBuilder(
        builder: (context, constraints) {
          return CustomPaint(
            size: Size.zero,
            painter: _TimelineRulerPainter(
              zoomLevel: zoomLevel,
              tempo: tempo,
              sampleRate: safeSampleRate,
              scrollController: scrollController,
              viewportWidth: constraints.maxWidth,
              majorTickColor: colors.onSurface.withValues(alpha: 0.54),
              minorTickColor: colors.onSurface.withValues(alpha: 0.24),
              labelStyle: theme.textTheme.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
                fontSize: 10,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TimelineRulerPainter extends CustomPainter {
  final double zoomLevel;
  final double tempo;
  final int sampleRate;
  final ScrollController scrollController;

  /// The pixel width of the visible viewport. Supplied by the widget's
  /// LayoutBuilder so it is accurate on first paint and after every window
  /// resize, without depending on scrollController.viewportDimension.
  final double viewportWidth;
  final Color majorTickColor;
  final Color minorTickColor;
  final TextStyle? labelStyle;

  _TimelineRulerPainter({
    required this.zoomLevel,
    required this.tempo,
    required this.sampleRate,
    required this.scrollController,
    required this.viewportWidth,
    required this.majorTickColor,
    required this.minorTickColor,
    required this.labelStyle,
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
      ..color = majorTickColor
      ..strokeWidth = 1.0;

    final Paint minorTickPaint = Paint()
      ..color = minorTickColor
      ..strokeWidth = 1.0;

    const int beatsPerBar = 4;
    final double pixelsPerBar = pixelsPerBeat * beatsPerBar;

    // Calculate Visible Range safely
    double startPixel = 0.0;
    double endPixel = size.width;

    if (scrollController.hasClients) {
      // When a controller is attached to multiple views, .offset throws.
      // We must access specific positions. Since they are synced, taking the first is fine.
      final position = scrollController.positions.first;
      final offset = position.pixels;

      const double buffer = 200.0;
      startPixel = (offset - buffer).clamp(0.0, double.infinity);
      endPixel = offset + viewportWidth + buffer;
    }

    // Determine Start Index
    int barIndex = (startPixel / pixelsPerBar).floor();
    if (barIndex < 1) barIndex = 1;

    double currentX = (barIndex - 1) * pixelsPerBar;
    final lastVisibleBar = (endPixel / pixelsPerBar).ceil() + 1;
    final barLabelStep = _barLabelStep(
      textPainter: textPainter,
      lastVisibleBar: lastVisibleBar,
      pixelsPerBar: pixelsPerBar,
    );

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

        if ((barIndex - 1) % barLabelStep == 0) {
          textPainter.text = TextSpan(text: '$barIndex', style: labelStyle);
          textPainter.layout();
          textPainter.paint(canvas, Offset(currentX + 4, 2));
        }
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

  int _barLabelStep({
    required TextPainter textPainter,
    required int lastVisibleBar,
    required double pixelsPerBar,
  }) {
    double widestDigit = 0;
    for (int digit = 0; digit <= 9; digit++) {
      textPainter.text = TextSpan(text: '$digit', style: labelStyle);
      textPainter.layout();
      widestDigit = math.max(widestDigit, textPainter.width);
    }

    final widestLabel = widestDigit * lastVisibleBar.toString().length;
    final requiredSpacing = math.max(24.0, widestLabel + 4.0);
    if (pixelsPerBar >= requiredSpacing) return 1;
    if (pixelsPerBar * 2 >= requiredSpacing) return 2;
    return 4;
  }

  @override
  bool shouldRepaint(covariant _TimelineRulerPainter oldDelegate) {
    return oldDelegate.zoomLevel != zoomLevel ||
        oldDelegate.tempo != tempo ||
        oldDelegate.sampleRate != sampleRate ||
        oldDelegate.viewportWidth != viewportWidth ||
        oldDelegate.majorTickColor != majorTickColor ||
        oldDelegate.minorTickColor != minorTickColor ||
        oldDelegate.labelStyle != labelStyle ||
        oldDelegate.scrollController != scrollController;
  }
}
