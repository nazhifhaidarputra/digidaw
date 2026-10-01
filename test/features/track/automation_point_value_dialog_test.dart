import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karbeat/features/track/view/automation_point_value_dialog.dart';
import 'package:karbeat/src/rust/api/automation.dart';

import 'fake_curve_sampler.dart';

const _lane = AutomationLaneDto(
  id: 1,
  label: 'Volume',
  points: [],
  enabled: true,
  defaultValue: 0,
);

// 0.5 of the fake parameter's -100 to 6 range is -47.
const _point = AutomationPointDto(
  id: 10,
  timeTicks: 0,
  value: 0.5,
  curveType: AutomationCurveTypeDto.linear,
  tension: 0,
);

Future<double? Function()> _openDialog(WidgetTester tester) async {
  double? result;
  var closed = false;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            result = await showAutomationPointValueDialog(
              context: context,
              lane: _lane,
              point: _point,
              sampler: FakeCurveSampler(),
            );
            closed = true;
          },
          child: const Text('Open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
  return () {
    expect(closed, isTrue, reason: 'dialog should have closed');
    return result;
  };
}

void main() {
  testWidgets('prefills the value in the parameter unit and keeps it', (
    tester,
  ) async {
    final result = await _openDialog(tester);

    expect(find.text('-47.00'), findsOneWidget);
    expect(find.text('Value (-100.00 to 6.00)'), findsOneWidget);

    await tester.tap(find.text('Set'));
    await tester.pumpAndSettle();
    expect(result(), isNull);
  });

  testWidgets('returns the typed parameter value normalized', (tester) async {
    final result = await _openDialog(tester);

    await tester.enterText(find.byType(TextField), '-20.5');
    await tester.pump();
    expect(find.text('Sets -20.50'), findsOneWidget);

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(result(), closeTo(0.75, 1e-9));
  });

  testWidgets('rejects text the parameter cannot parse', (tester) async {
    await _openDialog(tester);

    await tester.enterText(find.byType(TextField), 'loud');
    await tester.pump();

    expect(find.text('Not a value of Volume'), findsOneWidget);
    final setButton = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(setButton.onPressed, isNull);
  });
}
