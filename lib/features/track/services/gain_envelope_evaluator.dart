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

/// An ADSR stage of zero length with a linear curve.
const UiFade noFade = UiFade(
  length: 0,
  curveType: AutomationCurveTypeDto.linear,
  tension: 0,
);

/// An envelope that leaves audio untouched.
const UiGainEnvelope identityEnvelope = UiGainEnvelope(
  fadeIn: noFade,
  decay: noFade,
  sustain: 1,
  fadeOut: noFade,
  crossfade: 0,
  points: [],
);

/// Whether [envelope] leaves audio untouched.
bool isIdentityEnvelope(UiGainEnvelope envelope) =>
    envelope.fadeIn.length == 0 &&
    envelope.fadeOut.length == 0 &&
    envelope.decay.length == 0 &&
    envelope.sustain >= 1 &&
    envelope.crossfade == 0 &&
    envelope.points.isEmpty;

/// Attack, decay, and release lengths for content of [length] samples; stages
/// that would overlap are scaled down proportionally so they meet. A decay
/// toward unity changes nothing, so it takes no room.
(int, int, int) envelopeStageLengths(UiGainEnvelope envelope, int length) {
  final attack = envelope.fadeIn.length;
  final decay = envelope.sustain < 1 ? envelope.decay.length : 0;
  final release = envelope.fadeOut.length;
  final total = attack + decay + release;
  if (total <= length || total == 0) return (attack, decay, release);
  final scaledAttack = attack * length ~/ total;
  final scaledDecay = decay * length ~/ total;
  return (scaledAttack, scaledDecay, length - scaledAttack - scaledDecay);
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
