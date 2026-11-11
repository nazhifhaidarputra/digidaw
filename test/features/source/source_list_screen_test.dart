import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karbeat/app/providers/piano_roll_state.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/app/providers/workspace_state.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/features/source/services/audio_waveform_services.dart';
import 'package:karbeat/features/source/services/source_actions.dart';
import 'package:karbeat/features/source/view/source_list_screen.dart';
import 'package:karbeat/shared/enums/global.dart';
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
    input: const UiTrackInput(firstChannel: 0, channels: 2, monitor: false),
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
    input: const UiTrackInput(firstChannel: 0, channels: 2, monitor: false),
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
  _ProjectNotifier({
    this.patterns = const IMapConst<int, UiPattern>({}),
    this.generators = const IMapConst<int, UiGeneratorInstance>({}),
  });

  final IMap<int, UiPattern> patterns;
  final IMap<int, UiGeneratorInstance> generators;
  final List<(int, String)> renames = [];
  final List<int> removedSources = [];
  final List<int> removedPatterns = [];

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
    generators: generators,
    patterns: patterns,
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
  Future<void> renameGenerator(int generatorId, String displayName) async {
    renames.add((generatorId, displayName));
  }

  @override
  Future<Result<void>> removeAudioSource(int sourceId) async {
    removedSources.add(sourceId);
    return Result.ok(null);
  }

  @override
  Future<Result<void>> removePattern(int patternId) async {
    removedPatterns.add(patternId);
    return Result.ok(null);
  }
}

void main() {
  test('only audio clips of the source are counted', () {
    expect(audioSourceClipCount(_tracks.values, _sourceId), 2);
    expect(audioSourceClipCount(_tracks.values, 99), 1);
    expect(audioSourceClipCount(_tracks.values, 5), 0);
  });

  test('only clips of the pattern are counted', () {
    expect(patternClipCount(_tracks.values, _sourceId), 1);
    expect(patternClipCount(_tracks.values, 99), 0);
  });

  testWidgets('a renamed generator shows both names and the pencil renames', (
    tester,
  ) async {
    final project = _ProjectNotifier(
      generators: IMap({
        3: const UiGeneratorInstance(
          id: 3,
          instanceType: UiGeneratorInstanceType.plugin(
            UiPluginInstance(
              registryId: 42,
              name: 'Vital',
              displayName: 'Lead 1',
              label: 'Lead 1 (Vital)',
              bypass: false,
            ),
          ),
        ),
      }),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          projectProvider.overrideWith(() => project),
          audioSourcesProvider.overrideWith((ref) async => const {}),
        ],
        child: const MaterialApp(home: SourceListScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Lead 1 (Vital)'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.edit));
    await tester.pumpAndSettle();
    expect(find.text('Rename Vital'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'Bass 2');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Rename'));
    await tester.pumpAndSettle();
    expect(project.renames, [(3, 'Bass 2')]);

    // Emptying the field goes back to the plugin's own name.
    await tester.tap(find.byIcon(Icons.edit));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '   ');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Rename'));
    await tester.pumpAndSettle();
    expect(project.renames.last, (3, ''));
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

  testWidgets('Deleting a pattern asks first, then removes it', (tester) async {
    final project = _ProjectNotifier(
      patterns: IMap({
        _sourceId: const UiPattern(
          id: _sourceId,
          name: 'Lead',
          lengthTicks: 3840,
          notes: [],
        ),
      }),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          projectProvider.overrideWith(() => project),
          audioSourcesProvider.overrideWith((ref) async => const {}),
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
    expect(find.text('Delete pattern?'), findsOneWidget);
    expect(
      find.textContaining('1 clip that plays it will be removed'),
      findsOneWidget,
    );

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(project.removedPatterns, isEmpty);

    await openDeleteDialog();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(project.removedPatterns, [_sourceId]);
  });

  testWidgets('tapping a pattern opens it in the piano roll', (tester) async {
    final project = _ProjectNotifier(
      patterns: IMap({
        3: const UiPattern(id: 3, name: 'Lead', lengthTicks: 3840, notes: []),
      }),
    );
    late WidgetRef ref;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          projectProvider.overrideWith(() => project),
          audioSourcesProvider.overrideWith((ref) async => const {}),
        ],
        child: MaterialApp(
          home: Consumer(
            builder: (context, widgetRef, _) {
              ref = widgetRef;
              return const SourceListScreen();
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Lead'));
    await tester.pump();

    expect(ref.read(pianoRollProvider).editingPatternId, 3);
    final workspace = ref.read(workspaceStateProvider);
    expect(workspace.currentView, WorkspaceView.pianoRoll);
    expect(workspace.editingPatternId, 3);
  });
}
