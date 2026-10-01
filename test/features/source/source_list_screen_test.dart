import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/features/source/services/audio_waveform_services.dart';
import 'package:karbeat/features/source/view/source_list_screen.dart';
import 'package:karbeat/src/rust/api/automation.dart';
import 'package:karbeat/src/rust/api/mixer.dart';
import 'package:karbeat/src/rust/api/pattern.dart';
import 'package:karbeat/src/rust/api/project.dart';

const _sourceId = 7;

UiClip _audioClip(int id, int sourceId) => UiClip(
  name: 'clip $id',
  id: id,
  startTime: id * 960,
  source: UiClipSource.audio(sourceId: sourceId),
  offsetStart: 0,
  loopLength: 48000,
  isSampleBased: false,
);

final _tracks = {
  1: UiTrack(
    id: 1,
    name: 'Audio',
    color: '#000000',
    trackType: UiTrackType.audio,
    clips: [_audioClip(10, _sourceId), _audioClip(11, 99)],
    orderIdx: 0,
  ),
  2: UiTrack(
    id: 2,
    name: 'More audio',
    color: '#000000',
    trackType: UiTrackType.audio,
    clips: [
      _audioClip(12, _sourceId),
      const UiClip(
        name: 'pattern',
        id: 13,
        startTime: 0,
        source: UiClipSource.midi(patternId: _sourceId),
        offsetStart: 0,
        loopLength: 960,
        isSampleBased: false,
      ),
    ],
    orderIdx: 1,
  ),
};

const _channel = UiMixerChannel(
  volume: 0,
  pan: 0,
  mute: false,
  solo: false,
  invertedPhase: false,
  effects: [],
);

class _ProjectNotifier extends ProjectNotifier {
  final List<int> removedSources = [];

  @override
  Future<ApplicationDataStore> build() async => ApplicationDataStore(
    metadata: const UiProjectMetadata(
      name: '',
      author: '',
      description: '',
      genre: '',
      version: '',
      createdAt: '',
    ),
    transport: const UiTransportState(bpm: 120, timeSignature: (4, 4)),
    hardwareConfig: const UiAudioHardwareConfig(
      selectedInputDevice: '',
      selectedOutputDevice: '',
      sampleRate: 48000,
      bufferSize: 1024,
      cpuLoad: 0,
    ),
    tracks: _tracks.lock,
    generators: const IMapConst({}),
    patterns: const IMapConst<int, UiPattern>({}),
    mixer: UiMixerState.raw(
      channels: {},
      masterBus: _channel,
      buses: {},
      routing: [],
    ),
    modulationLinks: const IMapConst<int, ModulationLinkDto>({}),
    automationPool: const IMapConst<int, AutomationLaneDto>({}),
    modulationSources: const IMapConst<int, ModulationSourceDto>({}),
  );

  @override
  Future<Result<void>> removeAudioSource(int sourceId) async {
    removedSources.add(sourceId);
    return Result.ok(null);
  }
}

void main() {
  test('only audio clips of the source are counted', () {
    expect(SourceListScreen.audioSourceClipCount(_tracks.values, _sourceId), 2);
    expect(SourceListScreen.audioSourceClipCount(_tracks.values, 99), 1);
    expect(SourceListScreen.audioSourceClipCount(_tracks.values, 5), 0);
  });

  testWidgets('Delete asks first, then removes the audio source', (
    tester,
  ) async {
    final project = _ProjectNotifier();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          projectProvider.overrideWith(() => project),
          audioSourcesProvider.overrideWith(
            (ref) async => const {
              _sourceId: AudioWaveformUiForSourceList(
                name: 'kick.wav',
                muted: false,
                sampleRate: 48000,
              ),
            },
          ),
        ],
        child: const MaterialApp(home: SourceListScreen()),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> openDeleteDialog() async {
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
    }

    await openDeleteDialog();
    expect(find.text('Delete audio source?'), findsOneWidget);
    expect(
      find.textContaining('2 clips that play it will be removed'),
      findsOneWidget,
    );

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(project.removedSources, isEmpty);

    await openDeleteDialog();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(project.removedSources, [_sourceId]);
  });
}
