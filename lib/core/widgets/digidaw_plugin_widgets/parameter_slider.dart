import 'package:flutter/material.dart';

/// A highly stylized parameter slider. The styling is very different from
/// standard flutter slider.
class DigidawParameterSlider extends StatelessWidget {
  final Slider slider;

  const DigidawParameterSlider({super.key, required this.slider});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 14.0, // Thick, boxy track gauge
        activeTrackColor: colors.primary.withValues(alpha: 0.8),
        inactiveTrackColor: colors.surfaceContainerHighest,
        thumbColor: colors.primary,
        overlayShape: const _StudioFaderOverlayShape(
          thumbWidth: 26.0,
          thumbHeight: 46.0,
        ),
        trackShape: const _StudioFaderTrackShape(),
        thumbShape: const _StudioFaderThumbShape(
          thumbWidth: 26.0,
          thumbHeight: 46.0,
        ),
      ),
      child: slider,
    );
  }
}

/// Draws a thick, rectangular track resembling the physical slot of a fader.
class _StudioFaderTrackShape extends SliderTrackShape
    with BaseSliderTrackShape {
  const _StudioFaderTrackShape();

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 0,
  }) {
    if (sliderTheme.trackHeight! <= 0) return;

    final Rect trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );

    final Color activeColor = isEnabled
        ? sliderTheme.activeTrackColor!
        : sliderTheme.disabledActiveTrackColor!;
    final Color inactiveColor = isEnabled
        ? sliderTheme.inactiveTrackColor!
        : sliderTheme.disabledInactiveTrackColor!;

    final Paint activePaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.fill;

    final Paint inactivePaint = Paint()
      ..color = inactiveColor
      ..style = PaintingStyle.fill;

    final Paint borderPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Draw the dark background slot (inactive portion)
    context.canvas.drawRect(trackRect, inactivePaint);

    // Draw the illuminated active portion
    final Rect activeRect = Rect.fromLTRB(
      trackRect.left,
      trackRect.top,
      thumbCenter.dx,
      trackRect.bottom,
    );
    context.canvas.drawRect(activeRect, activePaint);

    // Draw a sharp inner border to give the track depth
    context.canvas.drawRect(trackRect, borderPaint);
  }
}

/// Draws a thick, rectangular thumb with a 3D gradient and a colored center line.
class _StudioFaderThumbShape extends SliderComponentShape {
  final double thumbWidth;
  final double thumbHeight;

  const _StudioFaderThumbShape({
    required this.thumbWidth,
    required this.thumbHeight,
  });

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return Size(thumbWidth, thumbHeight);
  }

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final Canvas canvas = context.canvas;

    final Rect thumbRect = Rect.fromCenter(
      center: center,
      width: thumbWidth,
      height: thumbHeight,
    );

    // Create a 3D metallic/plastic gradient for the fader cap
    final Paint thumbPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.grey.shade400,
          Colors.grey.shade300,
          Colors.grey.shade700,
          Colors.grey.shade900,
        ],
        stops: const [0.0, 0.45, 0.55, 1.0],
      ).createShader(thumbRect);

    // Outline the fader cap
    final Paint borderPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // The glowing indicator line in the middle of the fader
    final Paint indicatorLinePaint = Paint()
      ..color = sliderTheme.thumbColor ?? Colors.cyanAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;

    // Draw the main fader block with slightly rounded corners
    final RRect roundedThumb = RRect.fromRectAndRadius(
      thumbRect,
      const Radius.circular(3.0),
    );
    canvas.drawRRect(roundedThumb, thumbPaint);
    canvas.drawRRect(roundedThumb, borderPaint);

    // Draw the center indicator line
    final Offset lineStart = Offset(thumbRect.left + 3, center.dy);
    final Offset lineEnd = Offset(thumbRect.right - 3, center.dy);
    canvas.drawLine(lineStart, lineEnd, indicatorLinePaint);
  }
}

/// Same footprint as the visible fader cap, used purely so
/// SliderInteraction.slideThumb has a non-zero hit area to test against.
/// Paints nothing — no glow/ripple.
class _StudioFaderOverlayShape extends SliderComponentShape {
  final double thumbWidth;
  final double thumbHeight;
  const _StudioFaderOverlayShape({
    required this.thumbWidth,
    required this.thumbHeight,
  });

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return Size(thumbWidth, thumbHeight);
  }

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    // Intentionally empty — this shape exists only to size the hit-test
    // rect used by SliderInteraction.slideThumb.
  }
}
