import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karbeat/app/providers/piano_roll_state.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/features/piano_roll/view/note_param_editor.dart';
import 'package:karbeat/src/rust/api/automation.dart';
import 'package:karbeat/src/rust/api/mixer.dart';
import 'package:karbeat/src/rust/api/pattern.dart';
import 'package:karbeat/src/rust/api/project.dart';
import 'package:karbeat/src/rust/frb_generated.dart';
import 'package:mocktail/mocktail.dart';

class _MockDawContext extends Mock implements DawContext {}

class _MockRustLibApi extends Mock implements RustLibApi {}

const _patternId = 3;

UiNote _note(int id, int start, int key) => UiNote(
  id: id,
  startTick: start,
  duration: 240,
  key: key,
  velocity: 100,
  probability: 1,
  microOffset: 0,
  mute: false,
  pan: 0,
  pitch: 0,
);

final _pattern = UiPattern(
  id: _patternId,
  name: 'Lead',
  lengthTicks: 3840,
  notes: [_note(1, 0, 60), _note(2, 480, 64)],
);

const _channel = UiMixerChannel(
  volume: 0,
  pan: 0,
  mute: false,
  solo: false,
  invertedPhase: false,
  effects: [],
);

class _ProjectNotifier extends ProjectNotifier {
  final DawContext context = _MockDawContext();

  @override
  DawContext get dawContext => context;

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
    tracks: const IMapConst({}),
    generators: const IMapConst({}),
    patterns: IMap({_patternId: _pattern}),
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
}

void main() {
  final api = _MockRustLibApi();

  setUpAll(() {
    registerFallbackValue(_MockDawContext());
    RustLib.initMock(api: api);
  });

  setUp(() => reset(api));

  testWidgets('dragging across the lane sets velocity as one edit', (
    tester,
  ) async {
    final commits = <List<UiNoteParamUpdate>>[];
    when(
      () => api.crateApiPatternSetNoteParamsBatch(
        ctx: any(named: 'ctx'),
        patternId: _patternId,
        updates: any(named: 'updates'),
      ),
    ).thenAnswer((invocation) async {
      commits.add(
        invocation.namedArguments[#updates] as List<UiNoteParamUpdate>,
      );
      return _pattern;
    });
    final container = ProviderContainer.test(
      overrides: [projectProvider.overrideWith(_ProjectNotifier.new)],
    );
    await container.read(projectProvider.future);
    container.read(pianoRollProvider.notifier).openPattern(_patternId);
    final scroll = ScrollController();
    addTearDown(scroll.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 235,
              // Notes start at 0 and 48 pixels at 0.1 pixels per tick.
              child: NoteParamEditorPanel(
                scrollController: scroll,
                zoomX: 0.1,
                gutterWidth: 0,
              ),
            ),
          ),
        ),
      ),
    );

    // The lane sits under the 35-pixel header and is 200 pixels tall.
    final origin = tester.getTopLeft(find.byType(NoteParamEditorPanel));
    final gesture = await tester.startGesture(origin + const Offset(1, 36));
    await gesture.moveTo(origin + const Offset(60, 36));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(commits, hasLength(1));
    expect(commits.single.map((update) => update.noteId).toSet(), {1, 2});
    for (final update in commits.single) {
      expect(update.velocity, greaterThan(120));
      expect(update.pan, isNull);
      expect(update.pitch, isNull);
    }
  });
}
