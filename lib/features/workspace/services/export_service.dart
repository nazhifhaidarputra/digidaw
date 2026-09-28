 import 'package:karbeat/shared/models/export_audio.dart';
import 'package:karbeat/src/rust/api/project.dart';

Stream<double> exportProject({
    required DawContext ctx,
    required String path,
    required String soundfileName,
    required SupportedAudioFormat format,
    required SampleRate sampleRate,
    BitDepthDTO? bitDepth,
    numberOfChannels = 2,
    int? bitrate,
    required TailHandling tailHandling,
  }) async* {
    // Construct final file path based on selected format
    final ext = format.name.toLowerCase();
    final fullPath = "$path/$soundfileName.$ext";

    final bitDepthProper = bitDepth ?? BitDepthDTO_BitPerSample(8);

    final tailHandlingDto = switch (tailHandling) {
      TailHandling.cutRemainder => TailHandlingDTO.cutRemaining,
      TailHandling.leaveRemainder => TailHandlingDTO.leaveRemaining,
      TailHandling.wrapRemainder => TailHandlingDTO.wrapRemaining,
    };

    final AudioExportConfigDTO config;
    switch (format) {
      case SupportedAudioFormat.wav:
        config = AudioExportConfigDTO.wav(
          WavExportConfigDTO(
            sampleRate: sampleRate.value,
            channels: numberOfChannels,
            bitDepth: bitDepthProper,
          ),
        );
        break;
      case SupportedAudioFormat.mp3:
        config = AudioExportConfigDTO.mp3(
          Mp3ExportConfigDTO(
            sampleRate: sampleRate.value,
            channels: numberOfChannels,
            bitRate: bitDepthProper,
          ),
        );
        break;
      case SupportedAudioFormat.ogg:
        // Opus always renders at 48 kHz, so the sample rate is not forwarded
        config = AudioExportConfigDTO.ogg(
          OggExportConfigDTO(
            channels: numberOfChannels,
            bitRate: bitDepthProper,
          ),
        );
        break;
      case SupportedAudioFormat.flac:
        config = AudioExportConfigDTO.flac(
          FlacExportConfigDTO(
            sampleRate: sampleRate.value,
            channels: numberOfChannels,
            bitDepth: bitDepthProper,
          ),
        );
        break;
    }
    yield* exportProjectFlutter(
      ctx: ctx,
      outputPath: fullPath,
      config: config,
      tailHandling: tailHandlingDto,
    );
  }