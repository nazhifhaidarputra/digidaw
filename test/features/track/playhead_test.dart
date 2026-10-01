import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karbeat/app/providers/transport_state.dart';
import 'package:karbeat/app/providers/workspace_state.dart';
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

  group('followPageScrollOffset', () {
    test('keeps the view still while the playhead is visible', () {
      expect(
        followPageScrollOffset(
          playheadX: 300,
          scrollOffset: 100,
          viewportWidth: 400,
          maxScrollExtent: 5000,
        ),
        isNull,
      );
    });

    test('pages forward when the playhead passes the right edge', () {
      expect(
        followPageScrollOffset(
          playheadX: 501,
          scrollOffset: 100,
          viewportWidth: 400,
          maxScrollExtent: 5000,
        ),
        461,
      );
    });

    test('pages back when the playhead is behind the left edge', () {
      expect(
        followPageScrollOffset(
          playheadX: 200,
          scrollOffset: 1000,
          viewportWidth: 400,
          maxScrollExtent: 5000,
        ),
        160,
      );
    });

    test('clamps to the scrollable range', () {
      expect(
        followPageScrollOffset(
          playheadX: 10,
          scrollOffset: 1000,
          viewportWidth: 400,
          maxScrollExtent: 5000,
        ),
        0,
      );
      expect(
        followPageScrollOffset(
          playheadX: 6000,
          scrollOffset: 1000,
          viewportWidth: 400,
          maxScrollExtent: 5000,
        ),
        5000,
      );
    });
  });

  group('follow playhead', () {
    Future<ScrollController> pumpTimeline(
      WidgetTester tester, {
      required StreamController<UiTransportFeedback> positions,
      required bool follow,
    }) async {
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            transportPositionStreamProvider.overrideWith(
              (ref) => positions.stream,
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    controller: scrollController,
                    child: const SizedBox(width: 10000, height: 100),
                  ),
                  Positioned.fill(
                    child: PlayheadOverlay(
                      offsetAdjustment: 0,
                      scrollController: scrollController,
                      zoomLevel: 1,
                      sampleSelector: (pos) => pos.ticks,
                      onSeek: (_) {},
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      if (follow) {
        ProviderScope.containerOf(
          tester.element(find.byType(PlayheadOverlay)),
        ).read(workspaceStateProvider.notifier).toggleFollowPlayhead();
      }
      await tester.pump();
      return scrollController;
    }

    testWidgets('pages the view to a playhead that left it', (tester) async {
      final positions = StreamController<UiTransportFeedback>();
      addTearDown(positions.close);
      final scrollController = await pumpTimeline(
        tester,
        positions: positions,
        follow: true,
      );

      positions.add(_position);
      await tester.pump();
      expect(scrollController.offset, 0);

      positions.add(_position.copyWith(ticks: 3000));
      await tester.pump();
      expect(scrollController.offset, 2960);
    });

    testWidgets('leaves the view alone when following is off', (tester) async {
      final positions = StreamController<UiTransportFeedback>();
      addTearDown(positions.close);
      final scrollController = await pumpTimeline(
        tester,
        positions: positions,
        follow: false,
      );

      positions.add(_position);
      await tester.pump();
      positions.add(_position.copyWith(ticks: 3000));
      await tester.pump();
      expect(scrollController.offset, 0);
    });
  });
}
