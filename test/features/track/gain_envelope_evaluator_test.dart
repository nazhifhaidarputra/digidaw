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
  // Gains and fade shapes are tested where they are computed, in
  // rust/karbeat-core/src/core/project/envelope.rs.
  test('the default envelope is the identity', () {
    expect(isIdentityEnvelope(identityEnvelope), isTrue);
    expect(isIdentityEnvelope(_fades(10, 0)), isFalse);
  });

  test('a lowered sustain or a decay is not the identity', () {
    expect(
      isIdentityEnvelope(identityEnvelope.copyWith(sustain: 0.5)),
      isFalse,
    );
    expect(
      isIdentityEnvelope(
        identityEnvelope.copyWith(decay: noFade.copyWith(length: 10)),
      ),
      isFalse,
    );
  });

  test('overlapping stages scale to fit', () {
    final envelope = _fades(300, 100);
    expect(envelopeStageLengths(envelope, 200), (150, 0, 50));
    expect(envelopeStageLengths(envelope, 1000), (300, 0, 100));

    final withDecay = envelope.copyWith(
      decay: noFade.copyWith(length: 100),
      sustain: 0.5,
    );
    expect(envelopeStageLengths(withDecay, 250), (150, 50, 50));
  });

  test('a decay toward unity takes no room', () {
    final envelope = _fades(
      100,
      100,
    ).copyWith(decay: noFade.copyWith(length: 100));
    expect(envelopeStageLengths(envelope, 200), (100, 0, 100));
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
