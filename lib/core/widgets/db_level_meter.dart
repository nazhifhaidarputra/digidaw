import 'dart:math' as math;

import 'package:flutter/material.dart';

const double defaultMeterFloorDb = -60.0;
const double defaultMeterCeilingDb = 6.0;

double magnitudeToDb(double magnitude, {double floorDb = defaultMeterFloorDb}) {
  if (!magnitude.isFinite || magnitude <= 0.0) return floorDb;
  return math.max(floorDb, 20.0 * math.log(magnitude) / math.ln10);
}

double normalizeMeterDb(
  double db, {
  double minDb = defaultMeterFloorDb,
  double maxDb = defaultMeterCeilingDb,
}) {
  if (!db.isFinite || maxDb <= minDb) return 0.0;
  return ((db - minDb) / (maxDb - minDb)).clamp(0.0, 1.0);
}

/// Peak level meter using the conventional green, yellow and red loudness
/// regions. Mixer strips can enable [showScale] for detailed dB guide lines;
/// compact track-header meters intentionally omit them.
class DbLevelMeter extends StatelessWidget {
  const DbLevelMeter({
    super.key,
    required this.magnitude,
    this.axis = Axis.vertical,
    this.showScale = false,
    this.minDb = defaultMeterFloorDb,
    this.maxDb = defaultMeterCeilingDb,
  });

  final double magnitude;
  final Axis axis;
  final bool showScale;
  final double minDb;
  final double maxDb;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _DbLevelMeterPainter(
          magnitude: magnitude,
          axis: axis,
          showScale: showScale,
          minDb: minDb,
          maxDb: maxDb,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _DbLevelMeterPainter extends CustomPainter {
  const _DbLevelMeterPainter({
    required this.magnitude,
    required this.axis,
    required this.showScale,
    required this.minDb,
    required this.maxDb,
  });

  final double magnitude;
  final Axis axis;
  final bool showScale;
  final double minDb;
  final double maxDb;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final bounds = Offset.zero & size;
    final background = RRect.fromRectAndRadius(bounds, Radius.zero);
    canvas.drawRRect(background, Paint()..color = const Color(0xFF090C12));

    final db = magnitudeToDb(magnitude, floorDb: minDb).clamp(minDb, maxDb);
    final amount = normalizeMeterDb(db, minDb: minDb, maxDb: maxDb);
    final yellowStop = normalizeMeterDb(-12.0, minDb: minDb, maxDb: maxDb);
    final redStop = normalizeMeterDb(-3.0, minDb: minDb, maxDb: maxDb);
    final gradient = LinearGradient(
      begin: axis == Axis.vertical
          ? Alignment.bottomCenter
          : Alignment.centerLeft,
      end: axis == Axis.vertical ? Alignment.topCenter : Alignment.centerRight,
      colors: const [Color(0xFF20C768), Color(0xFFFFD23F), Color(0xFFFF3B30)],
      stops: [0.0, yellowStop, redStop],
    );

    final fillRect = axis == Axis.vertical
        ? Rect.fromLTWH(
            0,
            size.height * (1.0 - amount),
            size.width,
            size.height * amount,
          )
        : Rect.fromLTWH(0, 0, size.width * amount, size.height);
    canvas.save();
    canvas.clipRRect(background);
    canvas.drawRect(fillRect, Paint()..shader = gradient.createShader(bounds));
    canvas.restore();

    if (showScale && axis == Axis.vertical) {
      _paintVerticalScale(canvas, size);
    }

    canvas.drawRRect(
      background,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke,
    );
  }

  void _paintVerticalScale(Canvas canvas, Size size) {
    const marks = <double>[0, -3, -6, -12, -24, -36, -48, -60];
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.42)
      ..strokeWidth = 0.7;

    for (final mark in marks) {
      if (mark < minDb || mark > maxDb) continue;
      final normalized = normalizeMeterDb(mark, minDb: minDb, maxDb: maxDb);
      final y = size.height * (1.0 - normalized);
      final major =
          mark == 0 || mark == -12 || mark == -24 || mark == -48 || mark == -60;
      canvas.drawLine(
        Offset(major ? 0 : size.width * 0.48, y),
        Offset(size.width, y),
        linePaint,
      );

      if (major && size.width >= 22) {
        final label = TextPainter(
          text: TextSpan(
            text: mark.round().toString(),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 6,
              fontFamily: 'monospace',
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        label.paint(
          canvas,
          Offset(
            1,
            (y - label.height / 2).clamp(0.0, size.height - label.height),
          ),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DbLevelMeterPainter oldDelegate) {
    return magnitude != oldDelegate.magnitude ||
        axis != oldDelegate.axis ||
        showScale != oldDelegate.showScale ||
        minDb != oldDelegate.minDb ||
        maxDb != oldDelegate.maxDb;
  }
}
