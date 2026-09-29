import 'dart:math' as math;

import 'package:karbeat/features/track/services/automation_curve_evaluator.dart';
import 'package:karbeat/src/rust/api/automation.dart';
import 'package:karbeat/src/rust/api/project.dart';

/// Dart mirror of the gain envelope evaluation used by the audio engine.
///
/// Keep in sync with `GainEnvelope` in
/// `rust/karbeat-core/src/core/project/envelope.rs` so the drawn envelope is
/// exactly what the engine plays back.

/// Largest envelope point gain (+6 dB).
const double maxEnvelopeGain = 2.0;

/// A fade of zero length with a linear curve.
const UiFade noFade = UiFade(
  length: 0,
  curveType: AutomationCurveTypeDto.linear,
  tension: 0,
);

/// An envelope that leaves audio untouched.
const UiGainEnvelope identityEnvelope = UiGainEnvelope(
  fadeIn: noFade,
  fadeOut: noFade,
  crossfade: 0,
  points: [],
);

/// Whether [envelope] leaves audio untouched.
bool isIdentityEnvelope(UiGainEnvelope envelope) =>
    envelope.fadeIn.length == 0 &&
    envelope.fadeOut.length == 0 &&
    envelope.crossfade == 0 &&
    envelope.points.isEmpty;

/// Gain of [fade] at normalized position [t], rising from 0 to 1.
double fadeShape(UiFade fade, double t) =>
    shapeAutomationSegment(fade.curveType, fade.tension, 0, 1, t);

/// Fade-in and fade-out lengths for content of [length] samples; fades that
/// would overlap are scaled down proportionally so they meet.
(int, int) envelopeFadeLengths(UiGainEnvelope envelope, int length) {
  final fadeIn = envelope.fadeIn.length;
  final fadeOut = envelope.fadeOut.length;
  final total = fadeIn + fadeOut;
  if (total <= length || total == 0) return (fadeIn, fadeOut);
  final scaledIn = fadeIn * length ~/ total;
  return (scaledIn, length - scaledIn);
}

/// Fade gain [elapsed] samples into content of [length] samples.
double envelopeFadeGain(UiGainEnvelope envelope, num elapsed, int length) {
  final (fadeIn, fadeOut) = envelopeFadeLengths(envelope, length);
  var gain = 1.0;
  if (elapsed < fadeIn) gain *= fadeShape(envelope.fadeIn, elapsed / fadeIn);
  final remaining = math.max(0, length - elapsed);
  if (remaining < fadeOut) {
    gain *= fadeShape(envelope.fadeOut, remaining / fadeOut);
  }
  return gain;
}

/// Index after every point at or before [position] in sorted [points].
int envelopeIndexAfter(List<UiEnvelopePoint> points, num position) {
  var low = 0;
  var high = points.length;
  while (low < high) {
    final mid = (low + high) >> 1;
    if (points[mid].position <= position) {
      low = mid + 1;
    } else {
      high = mid;
    }
  }
  return low;
}

/// Breakpoint gain at [position]: the first gain holds before the first
/// point, the last after the last point, and no points means unity.
double envelopePointGain(List<UiEnvelopePoint> points, num position) {
  if (points.isEmpty) return 1.0;
  final index = envelopeIndexAfter(points, position);
  if (index == 0) return points.first.gain;
  final from = points[index - 1];
  if (index == points.length) return from.gain;
  final to = points[index];
  final t = (position - from.position) / (to.position - from.position);
  return shapeAutomationSegment(
    from.curveType,
    from.tension,
    from.gain,
    to.gain,
    t,
  );
}

/// Combined fade and breakpoint gain at [position] of content that is
/// [length] samples long.
double envelopeGainAt(UiGainEnvelope envelope, num position, int length) =>
    envelopeFadeGain(envelope, position, length) *
    envelopePointGain(envelope.points, position);

/// Equal-power gains `(fadingOut, fadingIn)` at normalized position [t].
(double, double) equalPowerCrossfade(double t) {
  final angle = t.clamp(0.0, 1.0) * math.pi / 2;
  return (math.cos(angle), math.sin(angle));
}

/// Returns [envelope] with [point] inserted in position order.
UiGainEnvelope insertEnvelopePoint(
  UiGainEnvelope envelope,
  UiEnvelopePoint point,
) {
  final points = envelope.points;
  final index = envelopeIndexAfter(points, point.position);
  return envelope.copyWith(
    points: [...points.take(index), point, ...points.skip(index)],
  );
}
