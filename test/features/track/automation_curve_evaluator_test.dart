import 'package:flutter_test/flutter_test.dart';
import 'package:karbeat/features/track/services/automation_curve_evaluator.dart';
import 'package:karbeat/src/rust/api/automation.dart';

AutomationPointDto _point(int ticks, double value, {required int id}) =>
    AutomationPointDto(
      id: id,
      timeTicks: ticks,
      value: value,
      curveType: AutomationCurveTypeDto.linear,
      tension: 0,
    );

void main() {
  // Curve shapes are tested where they are computed, in
  // rust/karbeat-core/src/core/project/automation.rs. These tests cover the
  // point ordering the editor previews, which mirrors `AutomationLane`.
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

  test('the index after a tick counts every point at or before it', () {
    final points = [
      _point(0, 0, id: 1),
      _point(100, 0, id: 2),
      _point(100, 1, id: 3),
      _point(200, 1, id: 4),
    ];

    expect(automationIndexAfterTick(points, -1), 0);
    expect(automationIndexAfterTick(points, 100), 3);
    expect(automationIndexAfterTick(points, 150.5), 3);
    expect(automationIndexAfterTick(points, 500), 4);
  });
}
