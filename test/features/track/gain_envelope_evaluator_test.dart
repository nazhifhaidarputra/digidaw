import 'package:flutter_test/flutter_test.dart';
import 'package:karbeat/features/track/services/gain_envelope_evaluator.dart';
import 'package:karbeat/src/rust/api/automation.dart';
import 'package:karbeat/src/rust/api/project.dart';

UiEnvelopePoint _point(int position, double gain) => UiEnvelopePoint(
  position: position,
  gain: gain,
  curveType: AutomationCurveTypeDto.linear,
  tension: 0,
);

UiGainEnvelope _fades(int fadeIn, int fadeOut) => identityEnvelope.copyWith(
  fadeIn: noFade.copyWith(length: fadeIn),
  fadeOut: noFade.copyWith(length: fadeOut),
);

void main() {
  // Expected values mirror the Rust tests in
  // rust/karbeat-core/src/core/project/envelope.rs.
  test('the default envelope is the identity', () {
    expect(isIdentityEnvelope(identityEnvelope), isTrue);
    expect(envelopeGainAt(identityEnvelope, 50, 100), 1.0);
  });

  test('linear fades ramp at both edges', () {
    final envelope = _fades(10, 20);
    expect(envelopeFadeGain(envelope, 0, 100), 0.0);
    expect(envelopeFadeGain(envelope, 5, 100), closeTo(0.5, 1e-9));
    expect(envelopeFadeGain(envelope, 50, 100), 1.0);
    expect(envelopeFadeGain(envelope, 90, 100), closeTo(0.5, 1e-9));
    expect(envelopeFadeGain(envelope, 100, 100), 0.0);
  });

  test('overlapping fades scale to fit', () {
    final envelope = _fades(300, 100);
    expect(envelopeFadeLengths(envelope, 200), (150, 50));
    expect(envelopeFadeLengths(envelope, 1000), (300, 100));
  });

  test('points interpolate like the engine', () {
    final points = [_point(100, 1.0), _point(200, 0.0), _point(300, 2.0)];
    expect(envelopePointGain(points, 0), 1.0);
    expect(envelopePointGain(points, 150), closeTo(0.5, 1e-9));
    expect(envelopePointGain(points, 250), closeTo(1.0, 1e-9));
    expect(envelopePointGain(points, 400), 2.0);
    expect(envelopePointGain(const [], 10), 1.0);
  });

  test('equal-power crossfade keeps constant power', () {
    for (var step = 0; step <= 10; step++) {
      final (fadingOut, fadingIn) = equalPowerCrossfade(step / 10);
      expect(fadingOut * fadingOut + fadingIn * fadingIn, closeTo(1, 1e-9));
    }
  });

  test('inserted points stay in position order', () {
    final envelope = identityEnvelope.copyWith(
      points: [_point(10, 1), _point(30, 1)],
    );
    final inserted = insertEnvelopePoint(envelope, _point(20, 0.5));
    expect(inserted.points.map((p) => p.position), [10, 20, 30]);
  });
}
