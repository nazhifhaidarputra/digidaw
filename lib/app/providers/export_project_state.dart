import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/shared/models/export_audio.dart';
import 'package:karbeat/src/rust/api/project.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
part 'export_project_state.freezed.dart';

@freezed
abstract class ExportProjectStateData with _$ExportProjectStateData {
  const factory ExportProjectStateData({
    String? exportDirectory,
    @Default(SupportedAudioFormat.wav)
    SupportedAudioFormat selectedFormat,
    @Default(BitDepthDTO.bitPerSample(16))
    BitDepthDTO selectedBitDepth,
    @Default(SampleRate.hz44100)
    SampleRate selectedSampleRate,
    @Default(TailHandling.leaveRemainder)
    TailHandling tailHandling,
    @Default(false)
    bool openFolderAfterExport,
  }) = _ExportProjectStateData;
}

class ExportProjectNotifier extends Notifier<ExportProjectStateData> {
  @override
  ExportProjectStateData build() {
    // Initialize with the default state
    return const ExportProjectStateData();
  }

  void updateExportDirectory(String directory) {
    state = state.copyWith(exportDirectory: directory);
  }

  void updateFormat(SupportedAudioFormat format) {
    // Automatically switch the associated bit depth/bitrate setting 
    // to a safe default whenever the format changes.
    final BitDepthDTO newBitDepth = switch (format) {
      SupportedAudioFormat.wav ||
      SupportedAudioFormat.flac =>
        const BitDepthDTO.bitPerSample(16),
      SupportedAudioFormat.mp3 ||
      SupportedAudioFormat.ogg =>
        const BitDepthDTO.bitPerSecond(192),
    };

    state = state.copyWith(
      selectedFormat: format,
      selectedBitDepth: newBitDepth,
    );
  }

  void updateBitDepth(BitDepthDTO bitDepth) {
    state = state.copyWith(selectedBitDepth: bitDepth);
  }

  void updateSampleRate(SampleRate sampleRate) {
    state = state.copyWith(selectedSampleRate: sampleRate);
  }

  void updateTailHandling(TailHandling tailHandling) {
    state = state.copyWith(tailHandling: tailHandling);
  }

  void setOpenFolderAfterExport(bool value) {
    state = state.copyWith(openFolderAfterExport: value);
  }
}

/// Provider to access the export project state and its mutator methods
final exportProjectProvider = NotifierProvider<ExportProjectNotifier, ExportProjectStateData>(
  ExportProjectNotifier.new,
);
