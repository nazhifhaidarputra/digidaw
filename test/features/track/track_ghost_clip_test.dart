import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karbeat/app/providers/clip_placement_state.dart';
import 'package:karbeat/features/track/view/track_ghost_clip.dart';
import 'package:karbeat/src/rust/api/project.dart';

void main() {
  // At 120 BPM and 48 kHz one tick is 25 samples.
  const audioClip = UiClip(
    name: 'Audio',
    id: 1,
    startTime: 960,
    source: UiClipSource.audio(sourceId: 1),
    offsetStart: 12000,
    loopLength: 48000,
    isSampleBased: true,
  );
  const patternClip = UiClip(
    name: 'Pattern',
    id: 2,
    startTime: 960,
    source: UiClipSource.midi(patternId: 1),
    offsetStart: 0,
    loopLength: 1920,
    isSampleBased: false,
  );

  UiClip preview(
    UiClip clip,
    BatchDragAction action,
    int deltaTicks, {
    bool stretch = false,
  }) => previewDraggedClip(
    clip,
    action: action,
    deltaTicks: deltaTicks,
    stretch: stretch,
    bpm: 120,
    sampleRate: 48000,
  );

  test('a move shifts the clip and keeps its content', () {
    final moved = preview(audioClip, BatchDragAction.move, 480);

    expect(moved, audioClip.copyWith(startTime: 1440));
  });

  test('a left resize trims the content from the start', () {
    final resized = preview(audioClip, BatchDragAction.resizeLeft, 480);

    expect(resized.startTime, 1440);
    expect(resized.loopLength, 36000);
    expect(resized.offsetStart, 24000);
  });

  test('a stretching resize stretches audio and trims other clips', () {
    final audio = preview(
      audioClip,
      BatchDragAction.resizeRight,
      1920,
      stretch: true,
    );
    final pattern = preview(
      patternClip,
      BatchDragAction.resizeRight,
      1920,
      stretch: true,
    );

    expect(audio.loopLength, 96000);
    expect(audio.offsetStart, 24000);
    expect(pattern.loopLength, 3840);
    expect(pattern.offsetStart, 0);
  });

  testWidgets('the ghost of a new clip needs no clip content', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(clipPlacementProvider.notifier)
        .updatePlacementTarget(7, 960);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Stack(
            children: [
              TrackGhostClip(
                trackId: 7,
                trackHeight: 80,
                zoomLevel: 4,
                clipBuilder: (clip, left, contentStretch) =>
                    const Text('content'),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('content'), findsNothing);
  });
}
