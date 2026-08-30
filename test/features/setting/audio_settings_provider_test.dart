import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/features/setting/services/audio_dsp_preferences_service.dart';
import 'package:karbeat/features/setting/services/audio_settings_provider.dart';
import 'package:karbeat/features/setting/services/audio_settings_service.dart';
import 'package:karbeat/features/setting/view/audio_settings_page.dart';
import 'package:karbeat/src/rust/api/audio_settings.dart';
import 'package:karbeat/src/rust/api/project.dart';
import 'package:mocktail/mocktail.dart';

class _MockDawContext extends Mock implements DawContext {}

class _FakeAudioSettingsService extends AudioSettingsService {
  int? appliedSampleRate;
  int? appliedBlockSize;
  Exception? applyError;

  @override
  Future<Result<IList<int>>> supportedSampleRates() async {
    return Result.ok(IList([44100, 48000, 88200, 96000]));
  }

  @override
  Future<Result<IList<int>>> supportedBlockSizes() async {
    return Result.ok(IList([64, 128, 256, 512, 1024, 2048]));
  }

  @override
  Future<Result<UiAudioRuntimeSettings>> applyDspConfig(
    DawContext context,
    int sampleRate,
    int blockSize,
  ) async {
    final error = applyError;
    if (error != null) return Result.error(error);
    appliedSampleRate = sampleRate;
    appliedBlockSize = blockSize;
    return Result.ok(
      UiAudioRuntimeSettings(
        requestedOutput: const UiRequestedOutputConfig(
          host: UiOutputHostSelection.systemDefault(),
          device: UiOutputDeviceSelection.systemDefault(),
        ),
        requestedDsp: UiRequestedDspConfig(
          sampleRate: sampleRate,
          blockSize: blockSize,
        ),
        streamStatus: const UiDeviceStreamStatus.starting(),
      ),
    );
  }
}

class _FakeDspPreferencesService extends AudioDspPreferencesService {
  AudioDspPreferences loaded = (sampleRate: 48000, blockSize: 1024);
  AudioDspPreferences? saved;

  @override
  Future<Result<AudioDspPreferences>> load() async => Result.ok(loaded);

  @override
  Future<Result<void>> save(AudioDspPreferences value) async {
    saved = value;
    return Result.ok(null);
  }
}

void main() {
  test('restores and applies independent DSP configuration', () async {
    final service = _FakeAudioSettingsService();
    final preferences = _FakeDspPreferencesService()
      ..loaded = (sampleRate: 96000, blockSize: 256);
    final container = ProviderContainer(
      overrides: [
        audioSettingsServiceProvider.overrideWithValue(service),
        audioDspPreferencesServiceProvider.overrideWithValue(preferences),
      ],
    );
    addTearDown(container.dispose);

    final result = await container
        .read(audioSettingsProvider.notifier)
        .initialize(_MockDawContext());

    expect(result.isOk(), isTrue);
    expect(service.appliedSampleRate, 96000);
    expect(service.appliedBlockSize, 256);
    expect(container.read(audioSettingsProvider).appliedSampleRate, 96000);
    expect(preferences.saved?.sampleRate, 96000);
  });

  test(
    'unsupported restored values fall back to documented defaults',
    () async {
      final service = _FakeAudioSettingsService();
      final preferences = _FakeDspPreferencesService()
        ..loaded = (sampleRate: 12345, blockSize: 3);
      final container = ProviderContainer(
        overrides: [
          audioSettingsServiceProvider.overrideWithValue(service),
          audioDspPreferencesServiceProvider.overrideWithValue(preferences),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(audioSettingsProvider.notifier)
          .initialize(_MockDawContext());

      final state = container.read(audioSettingsProvider);
      expect(state.appliedSampleRate, 48000);
      expect(state.appliedBlockSize, 1024);
      expect(state.fallbackReason, isNotNull);
    },
  );

  test('draft can be reverted or applied and persisted', () async {
    final service = _FakeAudioSettingsService();
    final preferences = _FakeDspPreferencesService();
    final container = ProviderContainer(
      overrides: [
        audioSettingsServiceProvider.overrideWithValue(service),
        audioDspPreferencesServiceProvider.overrideWithValue(preferences),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(audioSettingsProvider.notifier);
    await notifier.initialize(_MockDawContext());

    notifier.setDraftSampleRate(88200);
    notifier.setDraftBlockSize(128);
    expect(container.read(audioSettingsProvider).hasPendingChanges, isTrue);
    notifier.revertDraft();
    expect(container.read(audioSettingsProvider).hasPendingChanges, isFalse);
    notifier.setDraftSampleRate(88200);
    notifier.setDraftBlockSize(128);
    expect((await notifier.applyDraft()).isOk(), isTrue);

    expect(service.appliedSampleRate, 88200);
    expect(preferences.saved, (sampleRate: 88200, blockSize: 128));
  });

  test('backend rejection preserves the previously applied values', () async {
    final service = _FakeAudioSettingsService();
    final preferences = _FakeDspPreferencesService();
    final container = ProviderContainer(
      overrides: [
        audioSettingsServiceProvider.overrideWithValue(service),
        audioDspPreferencesServiceProvider.overrideWithValue(preferences),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(audioSettingsProvider.notifier);
    await notifier.initialize(_MockDawContext());
    notifier.setDraftSampleRate(96000);
    service.applyError = Exception('worker rebuild rejected');

    final result = await notifier.applyDraft();

    expect(result.isErr(), isTrue);
    expect(container.read(audioSettingsProvider).appliedSampleRate, 48000);
    expect(container.read(audioSettingsProvider).isApplying, isFalse);
  });

  testWidgets('Audio page applies a supported DSP draft', (tester) async {
    final service = _FakeAudioSettingsService();
    final preferences = _FakeDspPreferencesService();
    final container = ProviderContainer(
      overrides: [
        audioSettingsServiceProvider.overrideWithValue(service),
        audioDspPreferencesServiceProvider.overrideWithValue(preferences),
      ],
    );
    addTearDown(container.dispose);
    await container
        .read(audioSettingsProvider.notifier)
        .initialize(_MockDawContext());

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(body: AudioSettingsPage()),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('dsp-sample-rate-48000')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('96000 Hz').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('apply-dsp-settings')));
    await tester.pumpAndSettle();

    expect(service.appliedSampleRate, 96000);
    expect(preferences.saved?.sampleRate, 96000);
  });
}
