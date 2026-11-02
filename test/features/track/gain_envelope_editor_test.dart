import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karbeat/features/track/services/curve_sampler.dart';
import 'package:karbeat/features/track/services/gain_envelope_evaluator.dart';
import 'package:karbeat/features/track/view/gain_envelope_editor.dart';
import 'package:karbeat/src/rust/api/automation.dart';
import 'package:karbeat/src/rust/api/project.dart';

import 'fake_curve_sampler.dart';

UiEnvelopePoint _point(
  int position,
  double gain, {
  double tension = 0,
  AutomationCurveTypeDto curveType = AutomationCurveTypeDto.linear,
}) => UiEnvelopePoint(
  position: position,
  gain: gain,
  curveType: curveType,
  tension: tension,
);

Future<void> _pump(
  WidgetTester tester, {
  required List<UiEnvelopePoint> points,
  required ValueChanged<UiGainEnvelope> onCommit,
  UiGainEnvelope? envelope,
  bool canAddPoints = true,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [curveSamplerProvider.overrideWithValue(FakeCurveSampler())],
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 400,
              height: 200,
              child: GainEnvelopeEditor(
                envelope: envelope ?? identityEnvelope.copyWith(points: points),
                canAddPoints: canAddPoints,
                axis: const EnvelopeAxis(
                  pixelsPerSample: 0.1,
                  originPosition: 0,
                ),
                contentStart: 0,
                contentLength: 4000,
                maxCrossfade: 4000,
                color: Colors.amber,
                onCommit: (next) async => onCommit(next),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  // Points 1000 and 3000 are at x 100 and 300. The fake sampler draws unity
  // gain, which sits a quarter of the way down the 200 pixel height.
  const handle = Offset(200, 50);

  testWidgets('segments between points get a tension handle', (tester) async {
    await _pump(
      tester,
      points: [_point(1000, 0.5), _point(3000, 1)],
      onCommit: (_) {},
    );
    expect(find.byTooltip(tensionHandleTooltip), findsOneWidget);
  });

  testWidgets('a lone point has no tension handle', (tester) async {
    await _pump(tester, points: [_point(1000, 0.5)], onCommit: (_) {});
    expect(find.byTooltip(tensionHandleTooltip), findsNothing);
  });

  testWidgets('dragging up raises a rising segment and keeps the points', (
    tester,
  ) async {
    UiGainEnvelope? committed;
    await _pump(
      tester,
      points: [_point(1000, 0.5), _point(3000, 1)],
      onCommit: (next) => committed = next,
    );
    final box = tester.getRect(find.byType(GainEnvelopeEditor));
    await tester.dragFrom(box.topLeft + handle, const Offset(0, -50));
    await tester.pumpAndSettle();

    final points = committed!.points;
    expect(points, hasLength(2));
    expect(points[0].tension, greaterThan(0.2));
    expect(points[0].tension, lessThanOrEqualTo(0.5));
    expect(points[0].position, 1000);
    expect(points[0].gain, 0.5);
    expect(points[1].tension, 0);
  });

  testWidgets('dragging up raises a falling segment too', (tester) async {
    UiGainEnvelope? committed;
    await _pump(
      tester,
      points: [_point(1000, 1), _point(3000, 0.5)],
      onCommit: (next) => committed = next,
    );
    final box = tester.getRect(find.byType(GainEnvelopeEditor));
    await tester.dragFrom(box.topLeft + handle, const Offset(0, -50));
    await tester.pumpAndSettle();
    expect(committed!.points[0].tension, lessThan(-0.2));
  });

  testWidgets('double-tapping straightens the segment', (tester) async {
    UiGainEnvelope? committed;
    await _pump(
      tester,
      points: [_point(1000, 0.5, tension: 0.7), _point(3000, 1)],
      onCommit: (next) => committed = next,
    );
    final box = tester.getRect(find.byType(GainEnvelopeEditor));
    await tester.tapAt(box.topLeft + handle);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(box.topLeft + handle);
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    expect(committed!.points, hasLength(2));
    expect(committed!.points[0].tension, 0);
  });

  group('ADSR', () {
    // Attack 1000 ends at x 100, the release of 1000 starts at x 300, and a
    // sustain of 0.5 sits at y 125, halfway between unity (50) and silence (200).
    final adsr = identityEnvelope.copyWith(
      fadeIn: noFade.copyWith(length: 1000),
      fadeOut: noFade.copyWith(length: 1000),
      sustain: 0.5,
    );

    testWidgets('each stage has a named handle', (tester) async {
      await _pump(tester, points: const [], envelope: adsr, onCommit: (_) {});
      for (final stage in ['Attack', 'Decay', 'Sustain', 'Release']) {
        expect(find.byTooltip(stage), findsOneWidget, reason: stage);
      }
    });

    testWidgets('a full sustain hides the decay handle', (tester) async {
      await _pump(
        tester,
        points: const [],
        envelope: adsr.copyWith(sustain: 1),
        onCommit: (_) {},
      );
      expect(find.byTooltip('Attack'), findsOneWidget);
      expect(find.byTooltip('Decay'), findsNothing);
    });

    testWidgets('dragging Sustain changes only the held level', (tester) async {
      UiGainEnvelope? committed;
      await _pump(
        tester,
        points: const [],
        envelope: adsr,
        onCommit: (next) => committed = next,
      );
      await tester.drag(find.byTooltip('Sustain'), const Offset(30, 40));
      await tester.pumpAndSettle();

      expect(committed!.sustain, lessThan(0.5));
      expect(committed!.fadeIn.length, 1000);
      expect(committed!.fadeOut.length, 1000);
    });

    testWidgets('Sustain cannot rise above the attack peak', (tester) async {
      UiGainEnvelope? committed;
      await _pump(
        tester,
        points: const [],
        envelope: adsr,
        onCommit: (next) => committed = next,
      );
      await tester.drag(find.byTooltip('Sustain'), const Offset(0, -150));
      await tester.pumpAndSettle();
      expect(committed!.sustain, 1);
    });

    testWidgets('dragging Decay lengthens the decay after the attack', (
      tester,
    ) async {
      UiGainEnvelope? committed;
      await _pump(
        tester,
        points: const [],
        envelope: adsr,
        onCommit: (next) => committed = next,
      );
      await tester.drag(find.byTooltip('Decay'), const Offset(60, 0));
      await tester.pumpAndSettle();

      // The drag ends at x 160 at most, so the decay is at most 600 samples.
      expect(committed!.decay.length, inInclusiveRange(1, 600));
      expect(committed!.fadeIn.length, 1000);
      expect(committed!.sustain, 0.5);
    });

    testWidgets('double-tapping adds no point when points are off', (
      tester,
    ) async {
      UiGainEnvelope? committed;
      await _pump(
        tester,
        points: const [],
        envelope: adsr,
        canAddPoints: false,
        onCommit: (next) => committed = next,
      );
      final box = tester.getRect(find.byType(GainEnvelopeEditor));
      final blank = box.topLeft + const Offset(160, 20);
      await tester.tapAt(blank);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(blank);
      await tester.pumpAndSettle(const Duration(milliseconds: 400));
      expect(committed, isNull);
    });

    testWidgets('double-tapping adds a point when points are on', (
      tester,
    ) async {
      UiGainEnvelope? committed;
      await _pump(
        tester,
        points: const [],
        envelope: adsr,
        onCommit: (next) => committed = next,
      );
      final box = tester.getRect(find.byType(GainEnvelopeEditor));
      final blank = box.topLeft + const Offset(160, 20);
      await tester.tapAt(blank);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(blank);
      await tester.pumpAndSettle(const Duration(milliseconds: 400));
      expect(committed!.points, hasLength(1));
    });
  });
}
