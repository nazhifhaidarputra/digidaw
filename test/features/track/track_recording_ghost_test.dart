import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karbeat/app/providers/recording_state.dart';
import 'package:karbeat/features/track/view/track_recording_ghost.dart';

void main() {
  testWidgets('an idle recording layer keeps the lane at its full size', (
    tester,
  ) async {
    final lane = GlobalKey();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          recordingProgressStreamProvider.overrideWith(
            (ref) => const Stream.empty(),
          ),
        ],
        child: Directionality(
          textDirection: TextDirection.ltr,
          // Loose constraints, as the lane gets: a Stack of only positioned
          // children fills them, while a non-positioned child shrinks it.
          child: Center(
            child: Stack(
              key: lane,
              children: const [
                Positioned.fill(child: ColoredBox(color: Color(0xFF000000))),
                TrackRecordingGhost(trackId: 1, trackHeight: 80, zoomLevel: 4),
              ],
            ),
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byKey(lane)),
      tester.getSize(find.byType(Center)),
    );
  });
}
