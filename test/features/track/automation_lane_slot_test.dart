import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/app/providers/transport_state.dart';
import 'package:karbeat/core/utils/scroll_behavior.dart';
import 'package:karbeat/features/track/view/automation_lane_slot.dart';
import 'package:karbeat/src/rust/api/automation.dart';

class _PendingProjectNotifier extends ProjectNotifier {
  @override
  Future<ApplicationDataStore> build() =>
      Completer<ApplicationDataStore>().future;
}

class _PendingTransportNotifier extends TransportNotifier {
  @override
  Future<TransportStateData> build() => Completer<TransportStateData>().future;
}

const _lane = AutomationLaneDto(
  id: 1,
  label: 'Volume',
  points: [
    AutomationPointDto(
      id: 10,
      timeTicks: 0,
      value: 0.5,
      curveType: AutomationCurveTypeDto.linear,
      tension: 0,
    ),
  ],
  enabled: true,
  min: 0,
  max: 1,
  defaultValue: 0,
);

void main() {
  testWidgets('dragging automation points does not scroll the timeline', (
    tester,
  ) async {
    final horizontal = ScrollController();
    final vertical = ScrollController();
    addTearDown(horizontal.dispose);
    addTearDown(vertical.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          projectProvider.overrideWith(_PendingProjectNotifier.new),
          transportProvider.overrideWith(_PendingTransportNotifier.new),
        ],
        child: MaterialApp(
          home: ScrollConfiguration(
            behavior: DragScrollBehavior(),
            child: SingleChildScrollView(
              controller: horizontal,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: 4000,
                height: 600,
                child: SingleChildScrollView(
                  controller: vertical,
                  child: Column(
                    children: [
                      AutomationLaneSlot(
                        lane: _lane,
                        height: 100,
                        horizontalScrollController: horizontal,
                        trackColor: Colors.blue,
                        sampleRate: 48000,
                      ),
                      const SizedBox(height: 2000),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final lane = tester.getTopLeft(find.byType(AutomationLaneSlot));
    // Drag the existing point at time zero, then a new point placed mid-lane.
    for (final start in [
      lane + const Offset(0, 50),
      lane + const Offset(300, 50),
    ]) {
      final gesture = await tester.startGesture(
        start,
        kind: PointerDeviceKind.mouse,
      );
      for (final step in [
        ...List.filled(4, const Offset(0, -10)),
        ...List.filled(4, const Offset(-20, 0)),
      ]) {
        await gesture.moveBy(step);
        await tester.pump();
      }
      await gesture.cancel();
      await tester.pump();

      expect(vertical.offset, 0);
      expect(horizontal.offset, 0);
    }
  });
}
