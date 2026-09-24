import 'package:flutter_test/flutter_test.dart';
import 'package:karbeat/features/track/services/automation_curve_evaluator.dart';
import 'package:karbeat/src/rust/api/automation.dart';

AutomationPointDto _point(
  int ticks,
  double value, {
  int? id,
  AutomationCurveTypeDto curve = AutomationCurveTypeDto.linear,
  double tension = 0,
}) => AutomationPointDto(
  id: id ?? ticks,
  timeTicks: ticks,
  value: value,
  curveType: curve,
  tension: tension,
);

void main() {
  // Expected values mirror the Rust tests in
  // rust/karbeat-core/src/core/project/automation.rs.
  test('holds the first and last values outside the points', () {
    final points = [_point(100, 0.2), _point(200, 0.8)];

    expect(evaluateAutomationPoints(points, 0), 0.2);
    expect(evaluateAutomationPoints(points, 5000), 0.8);
    expect(evaluateAutomationPoints(const [], 10), isNull);
  });

  test('linear tension bends the segment like the engine', () {
    expect(
      evaluateAutomationPoints([_point(0, 0), _point(100, 1)], 50),
      closeTo(0.5, 1e-9),
    );
    expect(
      evaluateAutomationPoints([_point(0, 0, tension: 1), _point(100, 1)], 25),
      closeTo(0.5, 1e-9),
    );
    expect(
      evaluateAutomationPoints([_point(0, 0, tension: -1), _point(100, 1)], 50),
      closeTo(0.25, 1e-9),
    );
  });

  test('step holds until the next point regardless of tension', () {
    final points = [
      _point(0, 0.1, curve: AutomationCurveTypeDto.step, tension: 0.9),
      _point(100, 0.9),
    ];

    expect(evaluateAutomationPoints(points, 99), 0.1);
    expect(evaluateAutomationPoints(points, 100), 0.9);
    expect(automationSegmentSupportsTension(points.first), isFalse);
  });

  test('exponential segments follow a geometric ramp', () {
    final from = _point(0, 0.1, curve: AutomationCurveTypeDto.exponential);

    expect(evaluateAutomationSegment(from, 0.9, 0.5), closeTo(0.3, 1e-9));
  });

  test('dragging up always raises the curve midpoint', () {
    final rising = _point(0, 0.2);
    final falling = _point(0, 0.8);
    final exponential = _point(
      0,
      0.2,
      curve: AutomationCurveTypeDto.exponential,
    );

    for (final (from, to) in [
      (rising, 0.8),
      (falling, 0.2),
      (exponential, 0.8),
    ]) {
      final direction = automationTensionDirection(from, to);
      final base = evaluateAutomationSegment(from, to, 0.5);
      final bent = evaluateAutomationSegment(
        from.copyWith(tension: 0.5 * direction),
        to,
        0.5,
      );
      expect(bent, greaterThan(base));
    }
  });

  group('points sharing a tick', () {
    final c = _point(0, 1.0, id: 1);
    final a = _point(100, 0.5, id: 2);
    final d = _point(200, 1.0, id: 3);
    final b = _point(100, 0.0, id: 4);
    List<int> ids(List<AutomationPointDto> points) =>
        points.map((p) => p.id).toList();

    test('a point added on an occupied tick starts the next segment', () {
      final points = placeAutomationPoint([c, a, d], b);

      expect(ids(points), [1, 2, 4, 3]);
      expect(evaluateAutomationPoints(points, 50), closeTo(0.75, 1e-9));
      expect(evaluateAutomationPoints(points, 100), 0.0);
      expect(evaluateAutomationPoints(points, 150), closeTo(0.5, 1e-9));
    });

    test('editing a point on its tick keeps its position', () {
      final edited = placeAutomationPoint(
        [c, b, d],
        a.copyWith(value: 0.9),
        previousIndex: 1,
        previousTime: 100,
      );

      expect(ids(edited), [1, 2, 4, 3]);
    });

    test('a point moved onto an occupied tick goes after the others', () {
      final moved = placeAutomationPoint(
        [c, a, b],
        d.copyWith(timeTicks: 100),
        previousIndex: 3,
        previousTime: 200,
      );

      expect(ids(moved), [1, 2, 4, 3]);
    });
  });
}
