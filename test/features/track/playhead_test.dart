import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karbeat/app/providers/transport_state.dart';
import 'package:karbeat/features/track/view/playhead.dart';
import 'package:karbeat/src/rust/api/audio.dart';

const _position = UiTransportFeedback(
  samples: 0,
  ticks: 50,
  beat: 0,
  bar: 0,
  tempo: 120,
  sampleRate: 48000,
  isPlaying: false,
  isLooping: false,
  isRecording: false,
  isPatternPlaying: false,
  isPatternMode: false,
  patternSamples: 0,
  patternTicks: 0,
  patternBeat: 0,
  patternBar: 0,
);

void main() {
  testWidgets('seeks to the snapped position after dragging the playhead', (
    tester,
  ) async {
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);
    final seeks = <int>[];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transportPositionStreamProvider.overrideWith(
            (ref) => Stream.value(_position),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: PlayheadOverlay(
              offsetAdjustment: 0,
              scrollController: scrollController,
              zoomLevel: 1,
              sampleSelector: (pos) => pos.ticks,
              snapPosition: (ticks) => (ticks / 100).round() * 100,
              onSeek: seeks.add,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final handle = find.descendant(
      of: find.byType(PlayheadOverlay),
      matching: find.byType(CustomPaint),
    );
    await tester.drag(handle.first, const Offset(160, 0));
    await tester.pumpAndSettle();

    expect(seeks, [200]);
  });
}
