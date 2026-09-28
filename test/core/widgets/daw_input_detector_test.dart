import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karbeat/core/widgets/daw_input_detector.dart';

void main() {
  testWidgets('routes one-finger movement to pan on both axes', (tester) async {
    final panDeltas = <Offset>[];
    final pinchUpdates = <ScaleUpdateDetails>[];

    await tester.pumpWidget(
      MaterialApp(
        home: DawInputDetector(
          onOneFingerPan: panDeltas.add,
          onPinchZoom: pinchUpdates.add,
          child: const SizedBox.expand(key: Key('target')),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('target'))),
    );
    await gesture.moveBy(const Offset(-30, -45));
    await tester.pump();
    await gesture.up();

    expect(panDeltas, isNotEmpty);
    expect(panDeltas.any((delta) => delta.dx < 0), isTrue);
    expect(panDeltas.any((delta) => delta.dy < 0), isTrue);
    expect(pinchUpdates, isEmpty);
  });

  testWidgets('routes two-finger movement to pinch zoom', (tester) async {
    final panDeltas = <Offset>[];
    final pinchUpdates = <ScaleUpdateDetails>[];

    await tester.pumpWidget(
      MaterialApp(
        home: DawInputDetector(
          onOneFingerPan: panDeltas.add,
          onPinchZoom: pinchUpdates.add,
          child: const SizedBox.expand(key: Key('target')),
        ),
      ),
    );

    final center = tester.getCenter(find.byKey(const Key('target')));
    final first = await tester.startGesture(
      center.translate(-20, 0),
      pointer: 1,
    );
    final second = await tester.startGesture(
      center.translate(20, 0),
      pointer: 2,
    );
    panDeltas.clear();
    pinchUpdates.clear();

    await first.moveBy(const Offset(-20, 0));
    await second.moveBy(const Offset(20, 0));
    await tester.pump();
    await first.up();
    await second.up();

    expect(pinchUpdates, isNotEmpty);
    expect(pinchUpdates.every((details) => details.pointerCount > 1), isTrue);
    expect(panDeltas, isEmpty);
  });
}
