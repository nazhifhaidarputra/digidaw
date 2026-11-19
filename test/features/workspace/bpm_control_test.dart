import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karbeat/app/providers/transport_state.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/features/workspace/view/control_panel.dart';
import 'package:karbeat/src/rust/api/project.dart';

/// Records tempo writes. Each write stays pending until [finishWrite].
class _TransportNotifier extends TransportNotifier {
  final List<double> writes = [];
  Completer<void>? _pending;

  @override
  Future<TransportStateData> build() async => const TransportStateData(
    state: UiTransportState(bpm: 120, timeSignature: (4, 4)),
    sampleRate: 48000,
  );

  @override
  Future<Result<void>> setBpm(double value) async {
    writes.add(value);
    final pending = _pending = Completer<void>();
    await pending.future;
    state = AsyncData(
      state.requireValue.copyWith(
        state: state.requireValue.state!.copyWith(bpm: value),
      ),
    );
    return Result.ok(null);
  }

  void finishWrite() => _pending?.complete();
}

void main() {
  late _TransportNotifier transport;

  Future<void> pumpControl(WidgetTester tester) async {
    transport = _TransportNotifier();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [transportProvider.overrideWith(() => transport)],
        child: const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(width: 80, height: 80, child: BpmControl()),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a drag previews the tempo and sends it once on release', (
    tester,
  ) async {
    await pumpControl(tester);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(BpmControl)),
    );
    for (var i = 0; i < 5; i++) {
      await gesture.moveBy(const Offset(0, -10));
      await tester.pump();
    }

    // 50 px up at 0.5 BPM per pixel, after the drag slop.
    expect(transport.writes, isEmpty);
    final preview = double.parse(
      tester.widget<Text>(find.textContaining('.').last).data!,
    );
    expect(preview, greaterThan(120));

    await gesture.up();
    await tester.pump();
    expect(transport.writes, [preview]);
    // The released tempo stays shown while it is being stored.
    expect(find.text(preview.toStringAsFixed(1)), findsOneWidget);

    transport.finishWrite();
    await tester.pumpAndSettle();
    expect(find.text(preview.toStringAsFixed(1)), findsOneWidget);
  });

  testWidgets('a new drag waits until the last tempo is stored', (
    tester,
  ) async {
    await pumpControl(tester);
    final center = tester.getCenter(find.byType(BpmControl));
    await tester.dragFrom(center, const Offset(0, -40));
    await tester.pump();
    expect(transport.writes, hasLength(1));

    // Still storing the first tempo: this drag is ignored.
    await tester.dragFrom(center, const Offset(0, -40));
    await tester.pump();
    expect(transport.writes, hasLength(1));

    transport.finishWrite();
    await tester.pumpAndSettle();
  });
}
