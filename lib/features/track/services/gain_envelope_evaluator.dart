import 'dart:math' as math;

import 'package:karbeat/src/rust/api/automation.dart';
import 'package:karbeat/src/rust/api/project.dart';

/// Layout helpers for gain envelopes.
///
/// Gains and fade shapes are not computed here: editors sample them from the
/// audio engine's own code through `CurveSampler`, so the drawn envelope is
/// exactly what plays.

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
