import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/notification_provider.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/features/setting/models/audio_settings_state.dart';
import 'package:karbeat/features/setting/services/audio_dsp_preferences_service.dart';
import 'package:karbeat/features/setting/services/audio_settings_service.dart';
import 'package:karbeat/src/rust/api/audio_settings.dart';
import 'package:karbeat/src/rust/api/project.dart';

final audioSettingsServiceProvider = Provider<AudioSettingsService>((ref) {
  return AudioSettingsService();
});

final audioDspPreferencesServiceProvider = Provider<AudioDspPreferencesService>(
  (ref) {
    return AudioDspPreferencesService();
  },
);

class AudioSettingsNotifier extends Notifier<AudioSettingsState> {
  bool _initializationStarted = false;
  DawContext? _dawContext;

  @override
  AudioSettingsState build() => const AudioSettingsState();

  Future<Result<void>> initialize(DawContext context) async {
    if (_initializationStarted) return Result.ok(null);
    _initializationStarted = true;
    _dawContext = context;

    final service = ref.read(audioSettingsServiceProvider);
    final results = await (
      service.supportedSampleRates(),
      service.supportedBlockSizes(),
      ref.read(audioDspPreferencesServiceProvider).load(),
    ).wait;
    if (results.$1 case Error<IList<int>>(error: final error)) {
      return _initializationFailed(error);
    }
    if (results.$2 case Error<IList<int>>(error: final error)) {
      return _initializationFailed(error);
    }
    if (results.$3 case Error<AudioDspPreferences>(error: final error)) {
      return _initializationFailed(error);
    }

    final sampleRates = results.$1.ok();
    final blockSizes = results.$2.ok();
    final preferences = results.$3.ok();
    final sampleRateValid = sampleRates.contains(preferences.sampleRate);
    final blockSizeValid = blockSizes.contains(preferences.blockSize);
    final sampleRate = sampleRateValid
        ? preferences.sampleRate
        : AudioDspPreferencesService.defaultSampleRate;
    final blockSize = blockSizeValid
        ? preferences.blockSize
        : AudioDspPreferencesService.defaultBlockSize;
    final fallbackReason = sampleRateValid && blockSizeValid
        ? null
        : 'Unsupported saved DSP values were reset to defaults.';

    state = state.copyWith(
      supportedSampleRates: sampleRates,
      supportedBlockSizes: blockSizes,
      draftSampleRate: sampleRate,
      draftBlockSize: blockSize,
      fallbackReason: fallbackReason,
    );
    final applied = await _apply(sampleRate, blockSize);
    if (applied.isErr()) return applied;
    if (fallbackReason != null) {
      ref
          .read(notificationProvider.notifier)
          .warn(fallbackReason, title: 'DSP settings reset');
    }
    return Result.ok(null);
  }

  void setDraftSampleRate(int sampleRate) {
    if (state.supportedSampleRates.contains(sampleRate)) {
      state = state.copyWith(draftSampleRate: sampleRate);
    }
  }

  void setDraftBlockSize(int blockSize) {
    if (state.supportedBlockSizes.contains(blockSize)) {
      state = state.copyWith(draftBlockSize: blockSize);
    }
  }

  Future<Result<void>> applyDraft() {
    return _apply(state.draftSampleRate, state.draftBlockSize);
  }

  void revertDraft() {
    state = state.copyWith(
      draftSampleRate: state.appliedSampleRate,
      draftBlockSize: state.appliedBlockSize,
    );
  }

  Result<void> _initializationFailed(Exception error) {
    _initializationStarted = false;
    return ref.notifyErrorResult(
      error,
      title: 'Could not initialize DSP settings',
    );
  }

  Future<Result<void>> _apply(int sampleRate, int blockSize) async {
    final context = _dawContext;
    if (context == null) {
      return Result.error(Exception('Audio settings are not initialized'));
    }
    state = state.copyWith(isApplying: true);
    final applied = await ref
        .read(audioSettingsServiceProvider)
        .applyDspConfig(context, sampleRate, blockSize);
    if (applied case Error<UiAudioRuntimeSettings>(error: final error)) {
      state = state.copyWith(isApplying: false);
      return ref.notifyErrorResult(
        error,
        title: 'Could not apply DSP settings',
      );
    }

    state = state.copyWith(
      appliedSampleRate: sampleRate,
      appliedBlockSize: blockSize,
      draftSampleRate: sampleRate,
      draftBlockSize: blockSize,
      runtimeSettings: applied.ok(),
      isApplying: false,
      isInitialized: true,
    );
    final saved = await ref.read(audioDspPreferencesServiceProvider).save((
      sampleRate: sampleRate,
      blockSize: blockSize,
    ));
    if (saved case Error<void>(error: final error)) {
      return ref.notifyErrorResult(
        error,
        title: 'DSP settings applied but not saved',
      );
    }
    return Result.ok(null);
  }
}

final audioSettingsProvider =
    NotifierProvider<AudioSettingsNotifier, AudioSettingsState>(
      AudioSettingsNotifier.new,
    );
