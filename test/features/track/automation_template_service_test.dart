import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karbeat/features/track/models/automation_curve_template.dart';
import 'package:karbeat/features/track/services/automation_template_service.dart';
import 'package:karbeat/src/rust/api/automation.dart';

final _template = AutomationCurveTemplate(
  id: 'a',
  name: 'Build-up',
  lengthTicks: 1920,
  points: const [
    AutomationPointDto(
      id: 0,
      timeTicks: 0,
      value: 0.1,
      curveType: AutomationCurveTypeDto.bezier,
      tension: 0,
      handles: BezierHandlesDto(x1: 0.25, y1: 0.1, x2: 0.5, y2: 1),
    ),
    AutomationPointDto(
      id: 0,
      timeTicks: 1920,
      value: 1,
      curveType: AutomationCurveTypeDto.stairs,
      tension: -0.5,
    ),
  ].lock,
);

void main() {
  test('templates round-trip through their stored form', () {
    final stored = encodeAutomationTemplates([_template]);

    expect(decodeAutomationTemplates(stored), [_template].lock);
  });

  test('a damaged entry does not hide the rest of the library', () {
    final stored = [
      'not json',
      '{"id":"b","name":"No points","lengthTicks":10,"points":[]}',
      '{"id":"c","name":"Unknown curve","lengthTicks":10,"points":'
          '[{"timeTicks":0,"value":0.5,"curveType":"zigzag","tension":0}]}',
      ...encodeAutomationTemplates([_template]),
    ];

    expect(decodeAutomationTemplates(stored), [_template].lock);
  });
}
