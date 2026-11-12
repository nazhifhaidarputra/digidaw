import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/core/l10n/localizer.dart';
import 'package:karbeat/core/widgets/context_menu.dart';
import 'package:karbeat/features/track/services/curve_sampler.dart';
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
/// The ADSR fade attaches to the edges of the content, which starts at
/// [contentStart] and is [contentLength] samples long; points sit at absolute
/// positions. Drag the Attack, Decay, and Release handles to change their
/// lengths, the Sustain handle to change the held level, and a stage's midpoint
/// to bend it. The Decay handle appears once the sustain is below unity, since
/// a decay to unity changes nothing. Drag the bottom handle to change the
/// crossfade and the points to move them. Drag the small ring between two
/// points to bend that segment, and double-tap the ring to straighten it.
/// Double-tap to add a point when [canAddPoints] is true; right-click or
/// long-press a point or stage handle for its options. Each gesture commits
/// once, on release.
class GainEnvelopeEditor extends ConsumerStatefulWidget {
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
    this.canAddPoints = true,
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

  /// Whether double-tapping adds a point. Points already in the envelope stay
  /// editable either way.
  final bool canAddPoints;

  @override
  ConsumerState<GainEnvelopeEditor> createState() => _GainEnvelopeEditorState();
}

enum _Grip {
  fadeIn,
  decay,
  sustain,
  fadeOut,
  fadeInTension,
  decayTension,
  fadeOutTension,
  crossfade,
  point,
  pointTension,
}

/// Minimum segment width in pixels before a tension handle is offered.
const double _minTensionSegmentWidth = 16;

class _GainEnvelopeEditorState extends ConsumerState<GainEnvelopeEditor> {
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
        _Grip.decayTension => _envelope.decay.tension,
        _Grip.fadeOutTension => _envelope.fadeOut.tension,
        _Grip.pointTension => _envelope.points[pointIndex].tension,
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
      final traits = ref.read(curveSamplerProvider).traits(fade.curveType);
      // A Step fade switches to the far side when dragged toward it, while
      // bendable curves follow the usual up-raises-the-curve direction.
      final direction = switch (fade.curveType) {
        AutomationCurveTypeDto.step => 1.0,
        _ => traits.tensionInverted ? 1.0 : -1.0,
      };
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
      _Grip.decay => envelope.copyWith(
        decay: envelope.decay.copyWith(
          length:
              (position -
                      widget.contentStart -
                      envelopeStageLengths(envelope, length).$1)
                  .clamp(0, length),
        ),
      ),
      _Grip.sustain => envelope.copyWith(
        sustain: _yToGain(local.dy, height).clamp(0.0, 1.0),
      ),
      _Grip.fadeOut => envelope.copyWith(
        fadeOut: envelope.fadeOut.copyWith(
          length: (_contentEnd - position).clamp(0, length),
        ),
      ),
      _Grip.fadeInTension => envelope.copyWith(fadeIn: bend(envelope.fadeIn)),
      _Grip.decayTension => _bendDecay(envelope, details.delta.dy, height),
      _Grip.fadeOutTension => envelope.copyWith(
        fadeOut: bend(envelope.fadeOut),
      ),
      _Grip.crossfade => envelope.copyWith(
        crossfade: (_contentEnd - position).clamp(0, widget.maxCrossfade),
      ),
      _Grip.point => _movePoint(envelope, position, local.dy, height),
      _Grip.pointTension => _bendPoint(envelope, details.delta.dy, height),
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

  /// Bends the segment after the dragged point. Dragging the full height sweeps
  /// the whole -1..1 tension range, and dragging up always raises the curve.
  UiGainEnvelope _bendPoint(UiGainEnvelope envelope, double dy, double height) {
    final points = envelope.points;
    if (_pointIndex < 0 || _pointIndex >= points.length - 1) return envelope;
    final from = points[_pointIndex];
    _dragDy += dy;
    final direction = tensionDragDirection(
      ref.read(curveSamplerProvider).traits(from.curveType),
      from.curveType,
      points[_pointIndex + 1].gain - from.gain,
    );
    final tension = (_tensionAnchor - _dragDy / height * 2.0 * direction).clamp(
      -1.0,
      1.0,
    );
    return _withPointTension(envelope, _pointIndex, tension);
  }

  /// Bends the decay the same way as a segment between two points.
  UiGainEnvelope _bendDecay(UiGainEnvelope envelope, double dy, double height) {
    final decay = envelope.decay;
    _dragDy += dy;
    final direction = tensionDragDirection(
      ref.read(curveSamplerProvider).traits(decay.curveType),
      decay.curveType,
      envelope.sustain - 1,
    );
    final tension = (_tensionAnchor - _dragDy / height * 2.0 * direction).clamp(
      -1.0,
      1.0,
    );
    return envelope.copyWith(decay: decay.copyWith(tension: tension));
  }

  UiGainEnvelope _withPointTension(
    UiGainEnvelope envelope,
    int index,
    double tension,
  ) => envelope.copyWith(
    points: [
      for (var i = 0; i < envelope.points.length; i++)
        i == index
            ? envelope.points[i].copyWith(tension: tension)
            : envelope.points[i],
    ],
  );

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
    final sampler = ref.read(curveSamplerProvider);
    return [
      DawContextAction.submenu(
        title: tr('track-curve-type'),
        subtitle: automationCurveTypeLabel(current),
        icon: automationCurveTypeIcon(current),
        children: [
          // Envelope points and fades have no Bezier handles.
          for (final curveType in automationCurveTypeMenuOrder)
            if (!sampler.traits(curveType).usesHandles)
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
      if (tension != 0 && sampler.traits(current).supportsTension)
        DawContextAction(
          title: tr('track-reset-tension'),
          icon: Icons.restart_alt,
          onTap: onResetTension,
        ),
    ];
  }

  void _openStageMenu({
    required String title,
    required UiFade fade,
    required UiGainEnvelope Function(UiFade next) withFade,
  }) {
    showDawContextMenu(
      context: context,
      title: title,
      actions: [
        ..._curveActions(
          current: fade.curveType,
          tension: fade.tension,
          onCurve: (curve) =>
              _commit(withFade(fade.copyWith(curveType: curve))),
          onResetTension: () => _commit(withFade(fade.copyWith(tension: 0))),
        ),
        DawContextAction(
          title: tr('track-remove', {'title': title}),
          icon: Icons.delete_outline,
          isDestructive: true,
          onTap: () => _commit(withFade(fade.copyWith(length: 0))),
        ),
      ],
    );
  }

  void _openSustainMenu() {
    showDawContextMenu(
      context: context,
      title: tr('track-sustain'),
      actions: [
        DawContextAction(
          title: tr('track-reset-sustain'),
          icon: Icons.restart_alt,
          onTap: () => _commit(_envelope.copyWith(sustain: 1)),
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
      title: tr('track-envelope-point'),
      header: Text(
        tr('track-envelope-gain', {
          'decibels': (20 * math.log(math.max(point.gain, 1e-6)) / math.ln10)
              .toStringAsFixed(1),
        }),
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
          title: tr('track-delete-point'),
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
    VoidCallback? onDoubleTap,
    String? tooltip,
    bool ring = false,
  }) {
    const size = 12.0;
    final active = _grip == grip && _pointIndex == pointIndex;
    final dotSize = ring && !active ? 7.0 : (active ? 10.0 : 8.0);
    Widget handle = MouseRegion(
      cursor: cursor,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onDoubleTap: onDoubleTap,
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
            width: dotSize,
            height: dotSize,
            decoration: BoxDecoration(
              shape: shape,
              color: active
                  ? widget.color
                  : ring
                  ? null
                  : Colors.white,
              border: Border.all(
                color: widget.color,
                width: ring && !active ? 1.25 : 1.5,
              ),
            ),
          ),
        ),
      ),
    );
    if (tooltip != null) {
      handle = Tooltip(
        message: tooltip,
        waitDuration: const Duration(milliseconds: 600),
        child: handle,
      );
    }
    return Positioned(
      left: center.dx - size / 2,
      top: center.dy - size / 2,
      width: size,
      height: size,
      child: handle,
    );
  }

  /// One ring per segment between two points whose curve responds to tension,
  /// on the drawn curve at the segment's midpoint.
  List<Widget> _pointTensionHandles(
    CurveSampler sampler,
    UiGainEnvelope envelope,
    double width,
    double height,
  ) {
    final axis = widget.axis;
    final points = envelope.points;
    final segments = [
      for (var i = 0; i < points.length - 1; i++)
        if (sampler.traits(points[i].curveType).supportsTension &&
            axis.toX(points[i + 1].position) - axis.toX(points[i].position) >=
                _minTensionSegmentWidth)
          i,
    ];
    if (segments.isEmpty) return const [];
    final midpoints = [
      for (final i in segments)
        (points[i].position + points[i + 1].position) / 2,
    ];
    final gains = sampler.sampleEnvelope(
      envelope,
      contentStart: widget.contentStart,
      contentLength: widget.contentLength,
      positions: midpoints,
    );
    return [
      for (var n = 0; n < segments.length; n++)
        if (axis.toX(midpoints[n]) >= -6 && axis.toX(midpoints[n]) <= width + 6)
          _handle(
            center: Offset(axis.toX(midpoints[n]), _gainToY(gains[n], height)),
            grip: _Grip.pointTension,
            pointIndex: segments[n],
            height: height,
            cursor: SystemMouseCursors.resizeUpDown,
            shape: BoxShape.circle,
            ring: true,
            tooltip: tensionHandleTooltip,
            onMenu: () => _openPointMenu(segments[n]),
            onDoubleTap: () =>
                _commit(_withPointTension(_envelope, segments[n], 0)),
          ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final envelope = _envelope;
    final axis = widget.axis;
    final sampler = ref.watch(curveSamplerProvider);

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
            sampler: sampler,
          ),
        );
        if (!widget.interactive) return IgnorePointer(child: painter);

        final (attack, decay, release) = envelopeStageLengths(
          envelope,
          widget.contentLength,
        );
        final unityY = _gainToY(1, height);
        final sustainY = _gainToY(envelope.sustain, height);
        final decayEnd = widget.contentStart + attack + decay;
        final releaseStart = _contentEnd - release;
        bool visible(double x) => x >= -6 && x <= width + 6;

        final handles = <Widget>[];
        void add(Widget Function() build, double x) {
          if (visible(x)) handles.add(build());
        }

        final attackX = axis.toX(widget.contentStart + attack);
        add(
          () => _handle(
            center: Offset(attackX, unityY),
            grip: _Grip.fadeIn,
            height: height,
            cursor: SystemMouseCursors.resizeLeftRight,
            shape: BoxShape.rectangle,
            tooltip: tr('track-attack'),
            onMenu: () => _openStageMenu(
              title: tr('track-attack'),
              fade: envelope.fadeIn,
              withFade: (next) => envelope.copyWith(fadeIn: next),
            ),
          ),
          attackX,
        );
        // A decay to unity changes nothing, and its handle would hide Attack.
        if (envelope.sustain < 1) {
          final decayX = axis.toX(decayEnd);
          add(
            () => _handle(
              center: Offset(decayX, sustainY),
              grip: _Grip.decay,
              height: height,
              cursor: SystemMouseCursors.resizeLeftRight,
              shape: BoxShape.rectangle,
              tooltip: tr('track-decay'),
              onMenu: () => _openStageMenu(
                title: tr('track-decay'),
                fade: envelope.decay,
                withFade: (next) => envelope.copyWith(decay: next),
              ),
            ),
            decayX,
          );
        }
        final sustainX = axis.toX((decayEnd + releaseStart) / 2);
        add(
          () => _handle(
            center: Offset(sustainX, sustainY),
            grip: _Grip.sustain,
            height: height,
            cursor: SystemMouseCursors.resizeUpDown,
            shape: BoxShape.rectangle,
            tooltip: tr('track-sustain'),
            onMenu: _openSustainMenu,
          ),
          sustainX,
        );
        final releaseX = axis.toX(releaseStart);
        add(
          () => _handle(
            center: Offset(releaseX, sustainY),
            grip: _Grip.fadeOut,
            height: height,
            cursor: SystemMouseCursors.resizeLeftRight,
            shape: BoxShape.rectangle,
            tooltip: tr('track-release'),
            onMenu: () => _openStageMenu(
              title: tr('track-release'),
              fade: envelope.fadeOut,
              withFade: (next) => envelope.copyWith(fadeOut: next),
            ),
          ),
          releaseX,
        );
        if (attack > 0 &&
            sampler.traits(envelope.fadeIn.curveType).supportsTension) {
          final x = axis.toX(widget.contentStart + attack / 2);
          add(
            () => _handle(
              center: Offset(
                x,
                _gainToY(sampler.fadeGain(envelope.fadeIn, 0.5), height),
              ),
              grip: _Grip.fadeInTension,
              height: height,
              cursor: SystemMouseCursors.resizeUpDown,
              shape: BoxShape.circle,
            ),
            x,
          );
        }
        if (decay > 0 &&
            sampler.traits(envelope.decay.curveType).supportsTension) {
          final midpoint = widget.contentStart + attack + decay / 2;
          final x = axis.toX(midpoint);
          // Sampled without the points, so the ring stays on the decay itself.
          final gain = sampler.sampleEnvelope(
            envelope.copyWith(points: const []),
            contentStart: widget.contentStart,
            contentLength: widget.contentLength,
            positions: [midpoint],
          )[0];
          add(
            () => _handle(
              center: Offset(x, _gainToY(gain, height)),
              grip: _Grip.decayTension,
              height: height,
              cursor: SystemMouseCursors.resizeUpDown,
              shape: BoxShape.circle,
            ),
            x,
          );
        }
        if (release > 0 &&
            sampler.traits(envelope.fadeOut.curveType).supportsTension) {
          final x = axis.toX(_contentEnd - release / 2);
          add(
            () => _handle(
              center: Offset(
                x,
                _gainToY(
                  sampler.fadeGain(envelope.fadeOut, 0.5) * envelope.sustain,
                  height,
                ),
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
        // Under the points, which win where the two overlap.
        handles.addAll(_pointTensionHandles(sampler, envelope, width, height));
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
                onDoubleTapDown: widget.canAddPoints
                    ? (details) => _doubleTapPosition = details.localPosition
                    : null,
                onDoubleTap: widget.canAddPoints
                    ? () => _addPoint(height)
                    : null,
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
    required this.sampler,
  });

  final UiGainEnvelope envelope;
  final EnvelopeAxis axis;
  final int contentStart;
  final int contentLength;
  final Color color;
  final Color crossfadeColor;

  /// Source of the drawn gains: the audio engine's envelope code.
  final CurveSampler sampler;

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

    // Sample the curve; breakpoints and stage edges are added so corners stay
    // exact whatever the sampling step.
    final (attack, decay, release) = envelopeStageLengths(
      envelope,
      contentLength,
    );
    final step = math.max(2.0, (right - left) / 1500);
    final xs = <double>[
      for (var x = left; x < right; x += step) x,
      right,
      for (final point in envelope.points) axis.toX(point.position),
      axis.toX(contentStart + attack),
      axis.toX(contentStart + attack + decay),
      axis.toX(contentEnd - release),
    ].where((x) => x >= left && x <= right).toList()..sort();

    // An untouched envelope is unity everywhere, so it needs no sampling.
    final gains = isIdentityEnvelope(envelope)
        ? null
        : sampler.sampleEnvelope(
            envelope,
            contentStart: contentStart,
            contentLength: contentLength,
            positions: [for (final x in xs) axis.toPosition(x)],
          );

    final line = Path();
    final fill = Path()..moveTo(xs.first, height);
    for (var i = 0; i < xs.length; i++) {
      final x = xs[i];
      final y = _gainToY(gains == null ? 1.0 : gains[i], height);
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
