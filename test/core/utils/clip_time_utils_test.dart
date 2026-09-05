import 'package:flutter_test/flutter_test.dart';
import 'package:karbeat/core/utils/clip_time_utils.dart';
import 'package:karbeat/src/rust/api/project.dart';

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
}
