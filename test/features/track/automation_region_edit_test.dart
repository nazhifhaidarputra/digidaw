import 'package:flutter_test/flutter_test.dart';
import 'package:karbeat/features/track/services/automation_region_edit.dart';
import 'package:karbeat/src/rust/api/automation.dart';
import 'package:karbeat/src/rust/api/track.dart' show UiResizeEdge;

AutomationPointDto _point(int id, int tick) => AutomationPointDto(
  id: id,
  timeTicks: tick,
  value: 0.5,
  curveType: AutomationCurveTypeDto.linear,
  tension: 0,
);

AutomationRegionDto _region(int id, int start, int length, {int content = 0}) =>
    AutomationRegionDto(
      id: id,
      name: 'Region $id',
      startTicks: start,
      lengthTicks: length,
      contentId: content,
      contentOffset: 0,
    );

/// Region 0 spans 0..100 and region 1 spans 300..400; points sit inside
/// region 0 (10, 50), free between them (250), and inside region 1 (350).
AutomationLaneDto _lane() => AutomationLaneDto(
  id: 1,
  label: 'Volume',
  points: [_point(1, 10), _point(2, 50), _point(3, 250), _point(4, 350)],
  enabled: true,
  defaultValue: 0.5,
  regions: [_region(0, 0, 100), _region(1, 300, 100, content: 1)],
);

List<int> _ticks(AutomationLaneDto lane) =>
    lane.points.map((p) => p.timeTicks).toList();

void main() {
  test('regions cover a half-open span', () {
    final lane = _lane();
    expect(lane.regionAt(99)?.id, 0);
    expect(lane.regionAt(100), isNull);
    expect(lane.regionAt(300)?.id, 1);
    expect(lane.isShared(lane.regions.first), isFalse);
  });

  test('moves stop at the neighbouring region and at tick zero', () {
    final lane = _lane();
    expect(clampRegionMove(lane, {0}, 500), 200);
    expect(clampRegionMove(lane, {1}, -500), -200);
    expect(clampRegionMove(lane, {0, 1}, -500), 0);
    expect(clampRegionMove(lane, {0}, 50), 50);
  });

  test('resizes keep one tick and stop at the neighbour', () {
    final lane = _lane();
    expect(clampRegionResize(lane, {0}, UiResizeEdge.right, 500), 200);
    expect(clampRegionResize(lane, {0}, UiResizeEdge.right, -500), -99);
    expect(clampRegionResize(lane, {1}, UiResizeEdge.left, -500), -200);
    expect(clampRegionResize(lane, {1}, UiResizeEdge.left, 500), 99);
  });

  test('a moved region carries its points and overwrites free ones', () {
    final moved = previewRegionMove(_lane(), {0}, 200);
    // 250 lay under region 0's new span 200..300 and is overwritten.
    expect(_ticks(moved), [210, 250, 350]);
    expect(moved.regions.first.startTicks, 200);
  });

  test('resizing crops and overwrites, keeping the composition in place', () {
    final grown = previewRegionResize(_lane(), {0}, UiResizeEdge.right, 200);
    expect(_ticks(grown), [10, 50, 350]);
    expect(grown.regions.first.lengthTicks, 300);

    final cropped = previewRegionResize(_lane(), {0}, UiResizeEdge.left, 30);
    expect(_ticks(cropped), [50, 250, 350]);
    expect(cropped.regions.first.startTicks, 30);
    expect(cropped.regions.first.contentOffset, 30);
  });

  test('clamping toward zero keeps the direction', () {
    expect(clampTowardZero(100, 40), 40);
    expect(clampTowardZero(100, -5), 0);
    expect(clampTowardZero(-100, -40), -40);
  });
}
