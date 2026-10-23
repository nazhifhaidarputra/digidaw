import 'package:flutter_test/flutter_test.dart';
import 'package:karbeat/core/utils/clip_time_utils.dart';
import 'package:karbeat/src/rust/api/project.dart';
import 'package:karbeat/src/rust/api/track.dart' show UiResizeEdge;

void main() {
  const audioClip = UiClip(
    name: 'Audio',
    id: 1,
    startTime: 960,
    source: UiClipSource.audio(sourceId: 1),
    offsetStart: 0,
    loopLength: 48000,
    isSampleBased: true,
  );

  test('audio placement remains at the same tick when BPM changes', () {
    expect(audioClip.startTimeInTicks, 960);
    expect(audioClip.loopLengthInTicks(120, 48000), 1920);
    expect(audioClip.loopLengthInTicks(60, 48000), 960);
  });

  group('resized clip', () {
    // At 120 BPM and 48 kHz one tick is 25 samples.
    const trimmed = UiClip(
      name: 'Audio',
      id: 2,
      startTime: 960,
      source: UiClipSource.audio(sourceId: 1),
      offsetStart: 12000,
      loopLength: 48000,
      isSampleBased: true,
    );
    const pattern = UiClip(
      name: 'Pattern',
      id: 3,
      startTime: 960,
      source: UiClipSource.midi(patternId: 1),
      offsetStart: 0,
      loopLength: 1920,
      isSampleBased: false,
    );

    test('the right edge changes only the length', () {
      final resized = resizedClip(trimmed, UiResizeEdge.right, 480, 120, 48000);

      expect(resized.startTime, 960);
      expect(resized.loopLength, 60000);
      expect(resized.offsetStart, 12000);
    });

    test('the left edge moves the start and the content offset together', () {
      final resized = resizedClip(trimmed, UiResizeEdge.left, 480, 120, 48000);

      expect(resized.startTime, 1440);
      expect(resized.loopLength, 36000);
      expect(resized.offsetStart, 24000);
    });

    test('a clip never shrinks below ten ticks or starts before zero', () {
      final shrunk = resizedClip(
        pattern,
        UiResizeEdge.right,
        -5000,
        120,
        48000,
      );
      final extended = resizedClip(
        pattern,
        UiResizeEdge.left,
        -5000,
        120,
        48000,
      );

      expect(shrunk.loopLength, 10);
      expect(extended.startTime, 0);
      expect(extended.loopLength, 2880);
      expect(extended.offsetStart, 0);
    });

    test('a stretching resize scales the content offset with the length', () {
      final stretched = stretchResizedClip(
        trimmed,
        UiResizeEdge.left,
        -1920,
        120,
        48000,
      );

      expect(stretched.startTime, 0);
      expect(stretched.loopLength, 72000);
      expect(stretched.offsetStart, 18000);
    });
  });
}
