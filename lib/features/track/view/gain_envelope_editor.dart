import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:karbeat/core/widgets/context_menu.dart';
import 'package:karbeat/features/track/services/gain_envelope_evaluator.dart';
import 'package:karbeat/features/track/view/automation_point_context_menu.dart';
import 'package:karbeat/src/rust/api/automation.dart';
import 'package:karbeat/src/rust/api/project.dart';

/// Linear mapping between envelope positions (samples) and editor x.
@immutable
class EnvelopeAxis {
  const EnvelopeAxis({
    required this.pixelsPerSample,
    required this.originPosition,
  });

  /// Horizontal pixels per envelope sample.
  final double pixelsPerSample;

  /// Envelope position drawn at x = 0.
  final double originPosition;

  double toX(num position) => (position - originPosition) * pixelsPerSample;

  double toPosition(double x) => originPosition + x / pixelsPerSample;

  @override
  bool operator ==(Object other) =>
      other is EnvelopeAxis &&
      other.pixelsPerSample == pixelsPerSample &&
      other.originPosition == originPosition;

  @override
  int get hashCode => Object.hash(pixelsPerSample, originPosition);
}

/// Share of the height above the unity-gain line, used for boosts up to
/// [maxEnvelopeGain].
const double _boostHeightShare = 0.25;

double _gainToY(double gain, double height) {
  final unityY = height * _boostHeightShare;
  if (gain <= 1) return height - gain * (height - unityY);
  return unityY - (gain - 1) / (maxEnvelopeGain - 1) * unityY;
}

double _yToGain(double y, double height) {
  final unityY = height * _boostHeightShare;
  final gain = y >= unityY
      ? (height - y) / (height - unityY)
      : 1 + (unityY - y) / unityY * (maxEnvelopeGain - 1);
  return gain.clamp(0.0, maxEnvelopeGain);
}

/// Draws a gain envelope over audio content and edits it in place.
///
/// Fades attach to the edges of the content, which starts at [contentStart]
/// and is [contentLength] samples long; points sit at absolute positions.
/// Drag the top fade handles to change fade lengths, the fade midpoints to
/// bend them, the bottom handle to change the crossfade, and the points to
/// move them. Double-tap to add a point; right-click or long-press a point or
/// fade handle for its curve options. Each gesture commits once, on release.
class GainEnvelopeEditor extends StatefulWidget {
  const GainEnvelopeEditor({
    super.key,
    required this.envelope,
    required this.axis,
    required this.contentStart,
    required this.contentLength,
    required this.maxCrossfade,
    required this.color,
    required this.onCommit,
    this.interactive = true,
  });

  final UiGainEnvelope envelope;
  final EnvelopeAxis axis;
  final int contentStart;
  final int contentLength;

  /// Longest allowed crossfade in samples.
  final int maxCrossfade;
  final Color color;
  final Future<void> Function(UiGainEnvelope envelope) onCommit;

  /// Paint only when false, letting pointer events reach the widgets below.
  final bool interactive;

  @override
  State<GainEnvelopeEditor> createState() => _GainEnvelopeEditorState();
}

enum _Grip { fadeIn, fadeOut, fadeInTension, fadeOutTension, crossfade, point }

class _GainEnvelopeEditorState extends State<GainEnvelopeEditor> {
  /// Envelope being dragged; shown instead of [GainEnvelopeEditor.envelope]
  /// until the commit lands.
  UiGainEnvelope? _draft;
  _Grip? _grip;
  int _pointIndex = -1;
  double _tensionAnchor = 0;
  double _dragDy = 0;
  Offset? _doubleTapPosition;

  UiGainEnvelope get _envelope => _draft ?? widget.envelope;
  int get _contentEnd => widget.contentStart + widget.contentLength;

  @override
  void didUpdateWidget(covariant GainEnvelopeEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_grip == null && oldWidget.envelope != widget.envelope) _draft = null;
  }

  Offset _local(Offset global) {
    final box = context.findRenderObject() as RenderBox?;
    return box?.globalToLocal(global) ?? global;
  }

  Future<void> _commit(UiGainEnvelope envelope) async {
    setState(() => _draft = envelope);
    await widget.onCommit(envelope);
    if (mounted && _grip == null) setState(() => _draft = null);
  }

  void _startDrag(_Grip grip, {int pointIndex = -1}) {
    setState(() {
      _grip = grip;
      _pointIndex = pointIndex;
      _dragDy = 0;
      _draft = _envelope;
      _tensionAnchor = switch (grip) {
        _Grip.fadeInTension => _envelope.fadeIn.tension,
        _Grip.fadeOutTension => _envelope.fadeOut.tension,
        _ => 0,
      };
    });
  }

  void _updateDrag(DragUpdateDetails details, double height) {
    final grip = _grip;
    final envelope = _draft;
    if (grip == null || envelope == null) return;
    final local = _local(details.globalPosition);
    final position = widget.axis.toPosition(local.dx).round();
    final length = widget.contentLength;

    UiFade bend(UiFade fade) {
      _dragDy += details.delta.dy;
      final direction = fade.curveType == AutomationCurveTypeDto.exponential
          ? 1.0
          : -1.0;
      final tension = (_tensionAnchor + direction * _dragDy / 60).clamp(
        -1.0,
        1.0,
      );
      return fade.copyWith(tension: tension);
    }

    final next = switch (grip) {
      _Grip.fadeIn => envelope.copyWith(
        fadeIn: envelope.fadeIn.copyWith(
          length: (position - widget.contentStart).clamp(0, length),
        ),
      ),
      _Grip.fadeOut => envelope.copyWith(
        fadeOut: envelope.fadeOut.copyWith(
          length: (_contentEnd - position).clamp(0, length),
        ),
      ),
      _Grip.fadeInTension => envelope.copyWith(fadeIn: bend(envelope.fadeIn)),
      _Grip.fadeOutTension => envelope.copyWith(
        fadeOut: bend(envelope.fadeOut),
      ),
      _Grip.crossfade => envelope.copyWith(
        crossfade: (_contentEnd - position).clamp(0, widget.maxCrossfade),
      ),
      _Grip.point => _movePoint(envelope, position, local.dy, height),
    };
    setState(() => _draft = next);
  }

  UiGainEnvelope _movePoint(
    UiGainEnvelope envelope,
    int position,
    double y,
    double height,
  ) {
    final points = envelope.points;
    if (_pointIndex < 0 || _pointIndex >= points.length) return envelope;
    // Stay between the neighbours so the points remain sorted.
    final lower = _pointIndex > 0 ? points[_pointIndex - 1].position : 0;
    final upper = _pointIndex < points.length - 1
        ? points[_pointIndex + 1].position
        : math.max(lower, _contentEnd);
    final moved = points[_pointIndex].copyWith(
      position: position.clamp(lower, math.max(lower, upper)),
      gain: _yToGain(y, height),
    );
    return envelope.copyWith(
      points: [
        for (var i = 0; i < points.length; i++)
          i == _pointIndex ? moved : points[i],
      ],
    );
  }

  void _endDrag() {
    final envelope = _draft;
    setState(() => _grip = null);
    if (envelope != null) _commit(envelope);
  }

  void _addPoint(double height) {
    final at = _doubleTapPosition;
    if (at == null) return;
    final point = UiEnvelopePoint(
      position: math.max(0, widget.axis.toPosition(at.dx).round()),
      gain: _yToGain(at.dy, height),
      curveType: AutomationCurveTypeDto.linear,
      tension: 0,
    );
    _commit(insertEnvelopePoint(_envelope, point));
  }

  List<DawContextAction> _curveActions({
    required AutomationCurveTypeDto current,
    required double tension,
    required ValueChanged<AutomationCurveTypeDto> onCurve,
    required VoidCallback onResetTension,
  }) {
    final colors = Theme.of(context).colorScheme;
    return [
      DawContextAction.submenu(
        title: 'Curve type',
        subtitle: automationCurveTypeLabel(current),
        icon: automationCurveTypeIcon(current),
        children: [
          for (final curveType in AutomationCurveTypeDto.values)
            DawContextAction(
              title: automationCurveTypeLabel(curveType),
              icon: current == curveType
                  ? Icons.check
                  : automationCurveTypeIcon(curveType),
              color: current == curveType ? colors.primary : null,
              onTap: () => onCurve(curveType),
            ),
        ],
      ),
      if (tension != 0 && current != AutomationCurveTypeDto.step)
        DawContextAction(
          title: 'Reset tension',
          icon: Icons.restart_alt,
          onTap: onResetTension,
        ),
    ];
  }

  void _openFadeMenu({required bool fadeIn}) {
    final envelope = _envelope;
    final fade = fadeIn ? envelope.fadeIn : envelope.fadeOut;
    UiGainEnvelope withFade(UiFade next) => fadeIn
        ? envelope.copyWith(fadeIn: next)
        : envelope.copyWith(fadeOut: next);

    showDawContextMenu(
      context: context,
      title: fadeIn ? 'Fade in' : 'Fade out',
      actions: [
        ..._curveActions(
          current: fade.curveType,
          tension: fade.tension,
          onCurve: (curve) =>
              _commit(withFade(fade.copyWith(curveType: curve))),
          onResetTension: () => _commit(withFade(fade.copyWith(tension: 0))),
        ),
        DawContextAction(
          title: 'Remove fade',
          icon: Icons.delete_outline,
          isDestructive: true,
          onTap: () => _commit(withFade(fade.copyWith(length: 0))),
        ),
      ],
    );
  }

  void _openPointMenu(int index) {
    final envelope = _envelope;
    final point = envelope.points[index];
    UiGainEnvelope withPoint(UiEnvelopePoint? next) => envelope.copyWith(
      points: [
        for (var i = 0; i < envelope.points.length; i++)
          if (i != index) envelope.points[i] else ?next,
      ],
    );
    final colors = Theme.of(context).colorScheme;

    showDawContextMenu(
      context: context,
      title: 'Envelope point',
      header: Text(
        'Gain ${(20 * math.log(math.max(point.gain, 1e-6)) / math.ln10).toStringAsFixed(1)} dB',
        style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
      ),
      actions: [
        ..._curveActions(
          current: point.curveType,
          tension: point.tension,
          onCurve: (curve) =>
              _commit(withPoint(point.copyWith(curveType: curve))),
          onResetTension: () => _commit(withPoint(point.copyWith(tension: 0))),
        ),
        DawContextAction(
          title: 'Delete point',
          icon: Icons.delete_outline,
          isDestructive: true,
          onTap: () => _commit(withPoint(null)),
        ),
      ],
    );
  }

  Widget _handle({
    required Offset center,
    required _Grip grip,
    required double height,
    required MouseCursor cursor,
    required BoxShape shape,
    int pointIndex = -1,
    VoidCallback? onMenu,
  }) {
    const size = 12.0;
    final active = _grip == grip && _pointIndex == pointIndex;
    return Positioned(
      left: center.dx - size / 2,
      top: center.dy - size / 2,
      width: size,
      height: size,
      child: MouseRegion(
        cursor: cursor,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (_) => _startDrag(grip, pointIndex: pointIndex),
          onPanUpdate: (details) => _updateDrag(details, height),
          onPanEnd: (_) => _endDrag(),
          onPanCancel: () => setState(() {
            _grip = null;
            _draft = null;
          }),
          onSecondaryTap: onMenu,
          onLongPress: onMenu,
          child: Center(
            child: Container(
              width: active ? 10 : 8,
              height: active ? 10 : 8,
              decoration: BoxDecoration(
                shape: shape,
                color: active ? widget.color : Colors.white,
                border: Border.all(color: widget.color, width: 1.5),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final envelope = _envelope;
    final axis = widget.axis;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final painter = CustomPaint(
          size: Size.infinite,
          painter: _GainEnvelopePainter(
            envelope: envelope,
            axis: axis,
            contentStart: widget.contentStart,
            contentLength: widget.contentLength,
            color: widget.color,
            crossfadeColor: Theme.of(context).colorScheme.tertiary,
          ),
        );
        if (!widget.interactive) return IgnorePointer(child: painter);

        final (fadeIn, fadeOut) = envelopeFadeLengths(
          envelope,
          widget.contentLength,
        );
        final unityY = _gainToY(1, height);
        bool visible(double x) => x >= -6 && x <= width + 6;

        final handles = <Widget>[];
        void add(Widget Function() build, double x) {
          if (visible(x)) handles.add(build());
        }

        final fadeInX = axis.toX(widget.contentStart + fadeIn);
        add(
          () => _handle(
            center: Offset(fadeInX, unityY),
            grip: _Grip.fadeIn,
            height: height,
            cursor: SystemMouseCursors.resizeLeftRight,
            shape: BoxShape.rectangle,
            onMenu: () => _openFadeMenu(fadeIn: true),
          ),
          fadeInX,
        );
        final fadeOutX = axis.toX(_contentEnd - fadeOut);
        add(
          () => _handle(
            center: Offset(fadeOutX, unityY),
            grip: _Grip.fadeOut,
            height: height,
            cursor: SystemMouseCursors.resizeLeftRight,
            shape: BoxShape.rectangle,
            onMenu: () => _openFadeMenu(fadeIn: false),
          ),
          fadeOutX,
        );
        if (fadeIn > 0 &&
            envelope.fadeIn.curveType != AutomationCurveTypeDto.step) {
          final x = axis.toX(widget.contentStart + fadeIn / 2);
          add(
            () => _handle(
              center: Offset(
                x,
                _gainToY(fadeShape(envelope.fadeIn, 0.5), height),
              ),
              grip: _Grip.fadeInTension,
              height: height,
              cursor: SystemMouseCursors.resizeUpDown,
              shape: BoxShape.circle,
            ),
            x,
          );
        }
        if (fadeOut > 0 &&
            envelope.fadeOut.curveType != AutomationCurveTypeDto.step) {
          final x = axis.toX(_contentEnd - fadeOut / 2);
          add(
            () => _handle(
              center: Offset(
                x,
                _gainToY(fadeShape(envelope.fadeOut, 0.5), height),
              ),
              grip: _Grip.fadeOutTension,
              height: height,
              cursor: SystemMouseCursors.resizeUpDown,
              shape: BoxShape.circle,
            ),
            x,
          );
        }
        final crossfadeX = axis.toX(_contentEnd - envelope.crossfade);
        add(
          () => _handle(
            center: Offset(crossfadeX, height - 7),
            grip: _Grip.crossfade,
            height: height,
            cursor: SystemMouseCursors.resizeLeftRight,
            shape: BoxShape.rectangle,
          ),
          crossfadeX,
        );
        for (var i = 0; i < envelope.points.length; i++) {
          final point = envelope.points[i];
          final x = axis.toX(point.position);
          add(
            () => _handle(
              center: Offset(x, _gainToY(point.gain, height)),
              grip: _Grip.point,
              pointIndex: i,
              height: height,
              cursor: SystemMouseCursors.move,
              shape: BoxShape.circle,
              onMenu: () => _openPointMenu(i),
            ),
            x,
          );
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onDoubleTapDown: (details) =>
                    _doubleTapPosition = details.localPosition,
                onDoubleTap: () => _addPoint(height),
                child: painter,
              ),
            ),
            ...handles,
          ],
        );
      },
    );
  }
}

class _GainEnvelopePainter extends CustomPainter {
  _GainEnvelopePainter({
    required this.envelope,
    required this.axis,
    required this.contentStart,
    required this.contentLength,
    required this.color,
    required this.crossfadeColor,
  });

  final UiGainEnvelope envelope;
  final EnvelopeAxis axis;
  final int contentStart;
  final int contentLength;
  final Color color;
  final Color crossfadeColor;

  @override
  void paint(Canvas canvas, Size size) {
    final height = size.height;
    final contentEnd = contentStart + contentLength;
    final left = math.max(0.0, axis.toX(contentStart));
    final right = math.min(size.width, axis.toX(contentEnd));
    if (right <= left) return;

    final unityY = _gainToY(1, height);
    canvas.drawLine(
      Offset(left, unityY),
      Offset(right, unityY),
      Paint()
        ..color = color.withAlpha(50)
        ..strokeWidth = 1,
    );

    // Sample the curve; breakpoints and fade edges are added so corners stay
    // exact whatever the sampling step.
    final step = math.max(2.0, (right - left) / 1500);
    final xs = <double>[
      for (var x = left; x < right; x += step) x,
      right,
      for (final point in envelope.points) axis.toX(point.position),
      axis.toX(contentStart + envelope.fadeIn.length),
      axis.toX(contentEnd - envelope.fadeOut.length),
    ].where((x) => x >= left && x <= right).toList()..sort();

    final line = Path();
    final fill = Path()..moveTo(xs.first, height);
    for (var i = 0; i < xs.length; i++) {
      final x = xs[i];
      final position = axis.toPosition(x);
      final gain =
          envelopeFadeGain(envelope, position - contentStart, contentLength) *
          envelopePointGain(envelope.points, position);
      final y = _gainToY(gain, height);
      if (i == 0) {
        line.moveTo(x, y);
      } else {
        line.lineTo(x, y);
      }
      fill.lineTo(x, y);
    }
    fill
      ..lineTo(xs.last, height)
      ..close();

    canvas
      ..drawPath(fill, Paint()..color = color.withAlpha(35))
      ..drawPath(
        line,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );

    _paintCrossfade(canvas, height, contentEnd, left, right);
  }

  /// Draws the equal-power crossfade at the content end as a crossing pair of
  /// curves: the content fading out and the next part fading in.
  void _paintCrossfade(
    Canvas canvas,
    double height,
    int contentEnd,
    double left,
    double right,
  ) {
    final crossfade = math.min(envelope.crossfade, contentLength);
    if (crossfade <= 0) return;
    final startX = axis.toX(contentEnd - crossfade);
    final endX = axis.toX(contentEnd);
    final fadingOut = Path();
    final fadingIn = Path();
    const segments = 24;
    for (var i = 0; i <= segments; i++) {
      final t = i / segments;
      final x = startX + (endX - startX) * t;
      final (outGain, inGain) = equalPowerCrossfade(t);
      final outY = _gainToY(outGain, height);
      final inY = _gainToY(inGain, height);
      if (i == 0) {
        fadingOut.moveTo(x, outY);
        fadingIn.moveTo(x, inY);
      } else {
        fadingOut.lineTo(x, outY);
        fadingIn.lineTo(x, inY);
      }
    }
    canvas
      ..save()
      ..clipRect(Rect.fromLTRB(left, 0, right, height))
      ..drawRect(
        Rect.fromLTRB(startX, 0, endX, height),
        Paint()..color = crossfadeColor.withAlpha(25),
      );
    final stroke = Paint()
      ..color = crossfadeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas
      ..drawPath(fadingOut, stroke)
      ..drawPath(fadingIn, stroke)
      ..restore();
  }

  @override
  bool shouldRepaint(covariant _GainEnvelopePainter oldDelegate) =>
      oldDelegate.envelope != envelope ||
      oldDelegate.axis != axis ||
      oldDelegate.contentStart != contentStart ||
      oldDelegate.contentLength != contentLength ||
      oldDelegate.color != color ||
      oldDelegate.crossfadeColor != crossfadeColor;
}
