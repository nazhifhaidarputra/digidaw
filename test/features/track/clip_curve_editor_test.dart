import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karbeat/features/track/services/curve_sampler.dart';
import 'package:karbeat/features/track/view/clip_curve_editor.dart';
import 'package:karbeat/features/track/view/clip_properties_dialog.dart';
import 'package:karbeat/src/rust/api/automation.dart';
import 'package:karbeat/src/rust/api/project.dart';

import 'fake_curve_sampler.dart';

UiCurvePoint _point(int position, double value) => UiCurvePoint(
  position: position,
  value: value,
  curveType: AutomationCurveTypeDto.linear,
  tension: 0,
);

ClipCurveScale _scale() => ClipCurveScale(
  curve: UiClipCurve.pan,
  color: Colors.teal,
  toFraction: (value) => (value + 1) / 2,
  fromFraction: (fraction) => fraction * 2 - 1,
  format: (value) => '${(value * 100).round()} %',
  parse: double.tryParse,
  snap: (value) => value,
  gridLines: const [ClipCurveGridLine(0, 'C', major: true)],
  valueHint: 'Pan',
);

Future<void> _pump(
  WidgetTester tester, {
  required List<UiCurvePoint> points,
  required ValueChanged<List<UiCurvePoint>> onCommit,
  int Function(int)? snapPosition,
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
              child: ClipCurveEditor(
                points: points,
                scale: _scale(),
                withPoints: (next) =>
                    identityClipModulation.copyWith(pan: next),
                contentStart: 1000,
                contentLength: 4000,
                snapPosition: snapPosition ?? (position) => position,
                onCommit: (next) async => onCommit(next),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _doubleTap(WidgetTester tester, Offset at) async {
  await tester.tapAt(at);
  await tester.pump(const Duration(milliseconds: 50));
  await tester.tapAt(at);
  await tester.pump(kDoubleTapMinTime);
  await tester.pumpAndSettle();
}

const kDoubleTapMinTime = Duration(milliseconds: 300);

void main() {
  testWidgets('an empty curve says how to start', (tester) async {
    await _pump(tester, points: const [], onCommit: (_) {});
    expect(find.text('Double-click to add the first point'), findsOneWidget);
  });

  testWidgets('double-clicking adds a point where the click landed', (
    tester,
  ) async {
    List<UiCurvePoint>? committed;
    await _pump(tester, points: const [], onCommit: (next) => committed = next);

    final box = tester.getRect(find.byType(ClipCurveEditor));
    // A quarter across the 4000-sample span, in the top quarter of the -1 to 1
    // range.
    await _doubleTap(tester, box.topLeft + const Offset(100, 50));

    expect(committed, hasLength(1));
    expect(committed!.single.position, 2000);
    expect(committed!.single.value, closeTo(0.5, 1e-9));
  });

  testWidgets('a new point lands on the project grid', (tester) async {
    List<UiCurvePoint>? committed;
    await _pump(
      tester,
      points: const [],
      onCommit: (next) => committed = next,
      snapPosition: (position) => (position / 500).round() * 500,
    );

    final box = tester.getRect(find.byType(ClipCurveEditor));
    await _doubleTap(tester, box.topLeft + const Offset(103, 100));

    expect(committed!.single.position, 2000);
  });

  testWidgets('new points keep the curve sorted', (tester) async {
    List<UiCurvePoint>? committed;
    await _pump(
      tester,
      points: [_point(4000, 0)],
      onCommit: (next) => committed = next,
    );

    final box = tester.getRect(find.byType(ClipCurveEditor));
    await _doubleTap(tester, box.topLeft + const Offset(100, 100));

    expect(committed!.map((point) => point.position), [2000, 4000]);
  });

  testWidgets('double-clicking a point deletes it', (tester) async {
    List<UiCurvePoint>? committed;
    await _pump(
      tester,
      points: [_point(3000, 0), _point(4000, 0)],
      onCommit: (next) => committed = next,
    );

    final box = tester.getRect(find.byType(ClipCurveEditor));
    // Position 3000 sits halfway across; value 0 sits at half the height.
    await _doubleTap(tester, box.topLeft + const Offset(200, 100));

    expect(committed!.map((point) => point.position), [4000]);
  });

  testWidgets('dragging a point stays between its neighbours', (tester) async {
    List<UiCurvePoint>? committed;
    await _pump(
      tester,
      points: [_point(2000, 0), _point(3000, 0), _point(4000, 0)],
      onCommit: (next) => committed = next,
    );

    final box = tester.getRect(find.byType(ClipCurveEditor));
    await tester.dragFrom(
      box.topLeft + const Offset(200, 100),
      const Offset(300, -50),
    );
    await tester.pumpAndSettle();

    expect(committed, hasLength(3));
    expect(committed![1].position, lessThan(4000));
    expect(committed![1].position, greaterThan(3000));
    expect(committed![1].value, greaterThan(0));
    expect(committed![0].position, 2000);
    expect(committed![2].position, 4000);
  });

  group('tension handles', () {
    // Segment 2000..4000 spans x 100..300, so its handle sits at x 200, and the
    // fake sampler puts every value on the middle line at y 100.
    const handle = Offset(200, 100);

    UiCurvePoint withCurve(
      int position,
      double value,
      AutomationCurveTypeDto curveType,
    ) => _point(position, value).copyWith(curveType: curveType);

    testWidgets('every segment that bends gets one', (tester) async {
      await _pump(
        tester,
        points: [_point(1000, 0), _point(3000, 0), _point(5000, 0)],
        onCommit: (_) {},
      );
      expect(find.byTooltip(tensionHandleTooltip), findsNWidgets(2));
    });

    testWidgets('a lone point and a Bezier segment have none', (tester) async {
      await _pump(tester, points: [_point(1000, 0)], onCommit: (_) {});
      expect(find.byTooltip(tensionHandleTooltip), findsNothing);

      await _pump(
        tester,
        points: [
          withCurve(1000, 0, AutomationCurveTypeDto.bezier),
          _point(3000, 0),
        ],
        onCommit: (_) {},
      );
      expect(find.byTooltip(tensionHandleTooltip), findsNothing);
    });

    testWidgets('a segment too narrow to grab has none', (tester) async {
      await _pump(
        tester,
        points: [_point(2000, 0), _point(2100, 0)],
        onCommit: (_) {},
      );
      expect(find.byTooltip(tensionHandleTooltip), findsNothing);
    });

    testWidgets('dragging up raises a rising segment', (tester) async {
      List<UiCurvePoint>? committed;
      await _pump(
        tester,
        points: [_point(2000, -0.5), _point(4000, 0.5)],
        onCommit: (next) => committed = next,
      );
      final box = tester.getRect(find.byType(ClipCurveEditor));
      await tester.dragFrom(box.topLeft + handle, const Offset(0, -50));
      await tester.pumpAndSettle();

      expect(committed, hasLength(2));
      expect(committed![0].tension, greaterThan(0.2));
      expect(committed![0].tension, lessThanOrEqualTo(0.5));
      expect(committed![1].tension, 0, reason: 'only its own segment bends');
      expect(committed![0].position, 2000);
      expect(committed![0].value, -0.5);
    });

    testWidgets('dragging up raises a falling segment too', (tester) async {
      List<UiCurvePoint>? committed;
      await _pump(
        tester,
        points: [_point(2000, 0.5), _point(4000, -0.5)],
        onCommit: (next) => committed = next,
      );
      final box = tester.getRect(find.byType(ClipCurveEditor));
      await tester.dragFrom(box.topLeft + handle, const Offset(0, -50));
      await tester.pumpAndSettle();
      expect(committed![0].tension, lessThan(-0.2));
    });

    testWidgets('an exponential segment inverts its tension', (tester) async {
      List<UiCurvePoint>? committed;
      await _pump(
        tester,
        points: [
          withCurve(2000, -0.5, AutomationCurveTypeDto.exponential),
          _point(4000, 0.5),
        ],
        onCommit: (next) => committed = next,
      );
      final box = tester.getRect(find.byType(ClipCurveEditor));
      await tester.dragFrom(box.topLeft + handle, const Offset(0, -50));
      await tester.pumpAndSettle();
      expect(committed![0].tension, lessThan(-0.2));
    });

    testWidgets('tension stays in range', (tester) async {
      List<UiCurvePoint>? committed;
      await _pump(
        tester,
        points: [_point(2000, -0.5), _point(4000, 0.5)],
        onCommit: (next) => committed = next,
      );
      final box = tester.getRect(find.byType(ClipCurveEditor));
      await tester.dragFrom(box.topLeft + handle, const Offset(0, -2000));
      await tester.pumpAndSettle();
      expect(committed![0].tension, 1.0);
    });

    testWidgets('double-clicking straightens the segment', (tester) async {
      List<UiCurvePoint>? committed;
      await _pump(
        tester,
        points: [_point(2000, -0.5).copyWith(tension: 0.7), _point(4000, 0.5)],
        onCommit: (next) => committed = next,
      );
      final box = tester.getRect(find.byType(ClipCurveEditor));
      await _doubleTap(tester, box.topLeft + handle);
      expect(committed, hasLength(2), reason: 'no point added or removed');
      expect(committed![0].tension, 0);
    });
  });
}
