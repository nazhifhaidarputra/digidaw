import 'dart:math' as math;

import 'package:flutter/material.dart';

/// An animated rainbow that drifts sideways, with sparkles twinkling on top.
///
/// Paints either a filled area behind [child], or only an outline when
/// [borderWidth] is set. Repaints on its own layer without rebuilding
/// [child].
class RainbowSparkle extends StatefulWidget {
  const RainbowSparkle({
    super.key,
    this.child,
    this.borderRadius = BorderRadius.zero,
    this.borderWidth,
    this.opacity = 1.0,
    this.sparkleCount = 10,
  });

  final Widget? child;
  final BorderRadius borderRadius;

  /// Draws an outline of this width instead of filling the area.
  final double? borderWidth;

  /// Strength of the rainbow; sparkles stay fully bright.
  final double opacity;
  final int sparkleCount;

  /// One full trip through the hues, and the loop length of the sparkles.
  static const Duration cycle = Duration(seconds: 6);

  /// A readable, saturated colour at [hue] degrees.
  static Color colorAt(double hue) =>
      HSVColor.fromAHSV(1, hue % 360, 0.72, 1).toColor();

  @override
  State<RainbowSparkle> createState() => _RainbowSparkleState();
}

class _RainbowSparkleState extends State<RainbowSparkle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: RainbowSparkle.cycle,
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final painter = _RainbowSparklePainter(
      progress: _controller,
      borderRadius: widget.borderRadius,
      borderWidth: widget.borderWidth,
      opacity: widget.opacity,
      sparkleCount: widget.sparkleCount,
    );
    return RepaintBoundary(
      child: CustomPaint(
        painter: widget.borderWidth == null ? painter : null,
        foregroundPainter: widget.borderWidth == null ? null : painter,
        child: widget.child,
      ),
    );
  }
}

class _RainbowSparklePainter extends CustomPainter {
  _RainbowSparklePainter({
    required this.progress,
    required this.borderRadius,
    required this.borderWidth,
    required this.opacity,
    required this.sparkleCount,
  }) : super(repaint: progress);

  final Animation<double> progress;
  final BorderRadius borderRadius;
  final double? borderWidth;
  final double opacity;
  final int sparkleCount;

  static const int _stops = 7;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final t = progress.value;
    final rect = Offset.zero & size;
    final rrect = borderRadius.toRRect(rect);

    final colors = [
      for (var i = 0; i < _stops; i++)
        RainbowSparkle.colorAt(
          360 * (i / (_stops - 1) - t),
        ).withValues(alpha: opacity),
    ];
    final paint = Paint()
      ..shader = LinearGradient(colors: colors).createShader(rect);

    final width = borderWidth;
    if (width != null) {
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = width;
      canvas.drawRRect(rrect.deflate(width / 2), paint);
      return;
    }

    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawRect(rect, paint);
    _paintSparkles(canvas, size, t);
    canvas.restore();
  }

  void _paintSparkles(Canvas canvas, Size size, double t) {
    final sparkle = Paint()..strokeCap = StrokeCap.round;
    for (var i = 0; i < sparkleCount; i++) {
      // Fixed positions and phases, so sparkles twinkle in place.
      final x = _fraction(i * 12.9898) * size.width;
      final y = _fraction(i * 78.233) * size.height;
      final phase = _fraction(i * 37.719);
      final twinkles = 1 + i % 3;
      final wave = math.sin((t * twinkles + phase) * 2 * math.pi);
      if (wave <= 0) continue;
      final brightness = wave * wave * wave;
      final radius = 1.5 + 2.5 * brightness;
      sparkle
        ..color = Colors.white.withValues(alpha: brightness)
        ..strokeWidth = 1;
      canvas.drawLine(Offset(x - radius, y), Offset(x + radius, y), sparkle);
      canvas.drawLine(Offset(x, y - radius), Offset(x, y + radius), sparkle);
    }
  }

  /// A stable pseudo-random value in 0..1 for [seed].
  static double _fraction(double seed) {
    final value = math.sin(seed + 1) * 43758.5453;
    return value - value.floorToDouble();
  }

  @override
  bool shouldRepaint(covariant _RainbowSparklePainter oldDelegate) =>
      oldDelegate.borderRadius != borderRadius ||
      oldDelegate.borderWidth != borderWidth ||
      oldDelegate.opacity != opacity ||
      oldDelegate.sparkleCount != sparkleCount;
}
