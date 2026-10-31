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
                envelope: identityEnvelope.copyWith(points: points),
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
}
