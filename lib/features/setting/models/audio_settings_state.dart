import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:karbeat/src/rust/api/audio_settings.dart';

part 'audio_settings_state.freezed.dart';

@freezed
abstract class AudioSettingsState with _$AudioSettingsState {
  const AudioSettingsState._();

  const factory AudioSettingsState({
    @Default(IListConst<int>([44100, 48000, 88200, 96000]))
    IList<int> supportedSampleRates,
    @Default(IListConst<int>([64, 128, 256, 512, 1024, 2048]))
    IList<int> supportedBlockSizes,
    @Default(48000) int appliedSampleRate,
    @Default(1024) int appliedBlockSize,
    @Default(48000) int draftSampleRate,
    @Default(1024) int draftBlockSize,
    @Default(false) bool isApplying,
    @Default(false) bool isInitialized,
    String? fallbackReason,
    UiAudioRuntimeSettings? runtimeSettings,
  }) = _AudioSettingsState;

  bool get hasPendingChanges =>
      draftSampleRate != appliedSampleRate ||
      draftBlockSize != appliedBlockSize;
}
