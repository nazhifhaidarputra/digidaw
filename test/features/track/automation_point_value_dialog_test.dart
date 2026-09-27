import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karbeat/features/track/view/automation_point_value_dialog.dart';
import 'package:karbeat/src/rust/api/automation.dart';

const _lane = AutomationLaneDto(
  id: 1,
  label: 'Volume',
  points: [],
  enabled: true,
  min: -60,
  max: 6,
  defaultValue: 0,
);

const _point = AutomationPointDto(
  id: 10,
  timeTicks: 0,
  value: 0.4375,
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
  test('formats normalized values without a tail of zeros', () {
    expect(formatNormalizedValue(0.4375), '0.4375');
    expect(formatNormalizedValue(1), '1.0');
    expect(formatNormalizedValue(0), '0.0');
    expect(formatNormalizedValue(1 / 3), '0.333333');
  });

  testWidgets('prefills the exact value and keeps it when confirmed', (
    tester,
  ) async {
    final result = await _openDialog(tester);

    expect(find.text('0.4375'), findsOneWidget);
    expect(find.text('Parameter value -31.13'), findsOneWidget);

    await tester.tap(find.text('Set'));
    await tester.pumpAndSettle();
    expect(result(), isNull);
  });

  testWidgets('returns a typed value within range', (tester) async {
    final result = await _openDialog(tester);

    await tester.enterText(find.byType(TextField), '0.75');
    await tester.pump();
    expect(find.text('Parameter value -10.50'), findsOneWidget);

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(result(), 0.75);
  });

  testWidgets('rejects values outside 0 to 1', (tester) async {
    await _openDialog(tester);

    await tester.enterText(find.byType(TextField), '1.5');
    await tester.pump();

    expect(find.text('Enter a number from 0 to 1'), findsOneWidget);
    final setButton = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(setButton.onPressed, isNull);
  });
}
