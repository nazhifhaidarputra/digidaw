import 'package:karbeat/src/rust/api/project.dart' show BitDepthDTO;

enum BitPerSample { b8, b16, b24, b32 }

enum TailHandling { cutRemainder, leaveRemainder, wrapRemainder }

enum SupportedAudioFormat { wav, mp3, ogg, flac }

enum SampleRate {
  hz44100(44100),
  hz48000(48000),
  hz88200(88200),
  hz96000(96000),
  hz192000(192000);

  final int value;
  const SampleRate(this.value);

  String get label =>
      '${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)} kHz';
}