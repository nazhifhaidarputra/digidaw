import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A rotary knob for continuous or discrete Digidaw DAW parameters.
/// Mirrors the fader's visual language (metallic dome, cyan value indicator)
/// so knobs and sliders read as the same instrument family.
class DigidawParameterKnob extends StatefulWidget {
  final double value;
  final double min;
  final double max;
  final double defaultValue;
  final double step;
  final double diameter;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeStart;
  final ValueChanged<double>? onChangeEnd;

  /// Vertical pixels of drag needed to sweep the full min→max range.
  /// Lower = more sensitive.
  final double sensitivity;

  final Color? activeColor;
  final Color? inactiveColor;

  const DigidawParameterKnob({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.defaultValue,
    this.step = 0.0,
    this.diameter = 52.0,
    required this.onChanged,
    this.onChangeStart,
    this.onChangeEnd,
    this.sensitivity = 150.0,
    this.activeColor,
    this.inactiveColor,
  });

  @override
  State<DigidawParameterKnob> createState() => _DigidawParameterKnobState();
}

class _DigidawParameterKnobState extends State<DigidawParameterKnob> {
  bool _dragging = false;

  double get _range => widget.max - widget.min;

  double _quantize(double v) {
    if (widget.step <= 0) return v.clamp(widget.min, widget.max);
    final snapped = (v / widget.step).round() * widget.step;
    return snapped.clamp(widget.min, widget.max);
  }

  void _applyDelta(double dyDelta) {
    // Hold Shift for fine control — standard DAW knob behavior.
    final fine = HardwareKeyboard.instance.isShiftPressed ? 0.2 : 1.0;
    final deltaValue = -(dyDelta / widget.sensitivity) * _range * fine;
    final next = _quantize(
      (widget.value + deltaValue).clamp(widget.min, widget.max),
    );
    if (next != widget.value) widget.onChanged(next);
  }

  void _nudge(int direction) {
    final increment = widget.step > 0 ? widget.step : _range * 0.01;
    final next = _quantize(
      (widget.value + increment * direction).clamp(widget.min, widget.max),
    );
    widget.onChangeStart?.call(widget.value);
    widget.onChanged(next);
    widget.onChangeEnd?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final t = _range == 0 ? 0.0 : (widget.value - widget.min) / _range;

    return Listener(
      onPointerSignal: (event) {
        if (event is PointerScrollEvent) {
          _nudge(event.scrollDelta.dy > 0 ? -1 : 1);
        }
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragStart: (_) {
          _dragging = true;
          widget.onChangeStart?.call(widget.value);
          setState(() {});
        },
        onVerticalDragUpdate: (details) => _applyDelta(details.delta.dy),
        onVerticalDragEnd: (_) {
          _dragging = false;
          widget.onChangeEnd?.call(widget.value);
          setState(() {});
        },
        onDoubleTap: () {
          widget.onChangeStart?.call(widget.value);
          widget.onChanged(widget.defaultValue);
          widget.onChangeEnd?.call(widget.defaultValue);
        },
        child: SizedBox(
          width: widget.diameter,
          height: widget.diameter,
          child: CustomPaint(
            painter: _StudioKnobPainter(
              t: t,
              pressed: _dragging,
              activeColor: widget.activeColor ?? colors.primary,
              inactiveColor:
                  widget.inactiveColor ?? colors.surfaceContainerHighest,
            ),
          ),
        ),
      ),
    );
  }
}

class _StudioKnobPainter extends CustomPainter {
  final double t; // 0..1 normalized value
  final bool pressed;
  final Color activeColor;
  final Color inactiveColor;

  // 270° sweep, leaving a 90° gap at the bottom — standard hardware-knob geometry.
  static const double _startAngle = 0.75 * math.pi; // 135°
  static const double _sweepAngle = 1.5 * math.pi; // 270°

  _StudioKnobPainter({
    required this.t,
    required this.pressed,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final outerRadius = size.width / 2;
    const trackWidth = 3.5;
    final trackRadius = outerRadius - trackWidth;
    final trackRect = Rect.fromCircle(center: center, radius: trackRadius);

    // Inactive track (full sweep)
    canvas.drawArc(
      trackRect,
      _startAngle,
      _sweepAngle,
      false,
      Paint()
        ..color = inactiveColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = trackWidth
        ..strokeCap = StrokeCap.round,
    );

    // Active arc (glow + solid, matching the fader's cyan)
    if (t > 0) {
      canvas.drawArc(
        trackRect,
        _startAngle,
        _sweepAngle * t,
        false,
        Paint()
          ..color = activeColor.withAlpha(90)
          ..style = PaintingStyle.stroke
          ..strokeWidth = trackWidth + 3
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
      canvas.drawArc(
        trackRect,
        _startAngle,
        _sweepAngle * t,
        false,
        Paint()
          ..color = activeColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = trackWidth
          ..strokeCap = StrokeCap.round,
      );
    }

    // Tick marks at min / center / max, just outside the track
    for (final frac in [0.0, 0.5, 1.0]) {
      final angle = _startAngle + _sweepAngle * frac;
      final p1 =
          center + Offset(math.cos(angle), math.sin(angle)) * (outerRadius + 1);
      final p2 =
          center + Offset(math.cos(angle), math.sin(angle)) * (outerRadius + 4);
      canvas.drawLine(
        p1,
        p2,
        Paint()
          ..color = Colors.grey.shade600
          ..strokeWidth = 1.5,
      );
    }

    // Knob cap — same 3D dome gradient as the fader thumb
    final capRadius = trackRadius - 6;
    final capRect = Rect.fromCircle(center: center, radius: capRadius);
    final capPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: pressed
            ? [Colors.grey.shade500, Colors.grey.shade800, Colors.grey.shade900]
            : [
                Colors.grey.shade400,
                Colors.grey.shade300,
                Colors.grey.shade700,
                Colors.grey.shade900,
              ],
        stops: pressed ? const [0.0, 0.5, 1.0] : const [0.0, 0.45, 0.55, 1.0],
      ).createShader(capRect);
    canvas.drawCircle(center, capRadius, capPaint);
    canvas.drawCircle(
      center,
      capRadius,
      Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Pointer indicator — shows current rotation
    final pointerAngle = _startAngle + _sweepAngle * t;
    final dir = Offset(math.cos(pointerAngle), math.sin(pointerAngle));
    canvas.drawLine(
      center + dir * (capRadius * 0.15),
      center + dir * (capRadius * 0.82),
      Paint()
        ..color = activeColor
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _StudioKnobPainter oldDelegate) {
    return oldDelegate.t != t || oldDelegate.pressed != pressed;
  }
}
