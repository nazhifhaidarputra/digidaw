import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karbeat/core/widgets/db_level_meter.dart';

void main() {
  test('converts linear magnitude to decibels with a silence floor', () {
    expect(magnitudeToDb(1.0), closeTo(0.0, 1.0e-9));
    expect(magnitudeToDb(0.5), closeTo(-6.0206, 1.0e-3));
    expect(magnitudeToDb(0.0), defaultMeterFloorDb);
    expect(magnitudeToDb(double.nan), defaultMeterFloorDb);
  });

  test('normalizes the dB display range', () {
    expect(normalizeMeterDb(-60.0), 0.0);
    expect(normalizeMeterDb(6.0), 1.0);
    expect(normalizeMeterDb(-27.0), closeTo(0.5, 1.0e-9));
    expect(normalizeMeterDb(20.0), 1.0);
  });

  testWidgets('renders compact and detailed meter orientations', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Row(
          children: [
            SizedBox(
              width: 26,
              height: 180,
              child: DbLevelMeter(magnitude: 1.0, showScale: true),
            ),
            SizedBox(
              width: 180,
              height: 7,
              child: DbLevelMeter(magnitude: 0.25, axis: Axis.horizontal),
            ),
          ],
        ),
      ),
    );

    expect(find.byType(DbLevelMeter), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}
