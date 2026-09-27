import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karbeat/app/providers/piano_roll_state.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/core/input/input.dart';
import 'package:karbeat/core/input/shortcut_models.dart';
import 'package:karbeat/shared/models/grid.dart';
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

  Future<ProviderContainer> createContainer() async {
    final container = ProviderContainer.test(
      overrides: [projectProvider.overrideWith(_ProjectNotifier.new)],
    );
    await container.read(projectProvider.future);
    container
        .read(pianoRollProvider.notifier)
        .openPattern(_patternId, previewGeneratorId: 9);
    return container;
  }

  group('snap steps', () {
    test('the draw step follows the grid until set on its own', () {
      // A quarter-note grid with eighth-note drawing.
      const state = PianoRollStateData(pianoRollGridDenom: GridSize.quarter);
      expect(state.stepTicks, 960);
      expect(state.copyWith(drawStep: GridSize.eighth).stepTicks, 480);
    });

    test('transforms fall back to the grid, then a sixteenth note', () {
      const free = PianoRollStateData(
        pianoRollGridDenom: GridSize.eighth,
        drawStep: GridSize.infinity,
      );
      expect(free.stepTicks, 1);
      expect(free.transformStepTicks, 480);
      expect(
        free.copyWith(pianoRollGridDenom: GridSize.infinity).transformStepTicks,
        240,
      );
    });

    test('opens more zoomed out than before', () {
      expect(const PianoRollStateData().zoomLevelTick, lessThan(0.67));
    });
  });

  test('quantize targets the selection and publishes the result', () async {
    final quantized = _pattern.copyWith(notes: [_note(1, 0, 60)]);
    when(
      () => api.crateApiPatternQuantizeNotes(
        ctx: any(named: 'ctx'),
        patternId: _patternId,
        noteIds: any(named: 'noteIds'),
        stepTicks: any(named: 'stepTicks'),
      ),
    ).thenAnswer((_) async => quantized);
    final container = await createContainer();
    final notifier = container.read(pianoRollProvider.notifier);
    notifier.setDrawStep(GridSize.eighth);
    notifier.selectNotes({1});

    final result = await notifier.quantizeNotes();

    expect(result.isOk(), isTrue);
    verify(
      () => api.crateApiPatternQuantizeNotes(
        ctx: any(named: 'ctx'),
        patternId: _patternId,
        noteIds: [1],
        stepTicks: 480,
      ),
    ).called(1);
    expect(
      container.read(projectProvider).requireValue.patterns[_patternId],
      quantized,
    );
  });

  test('a failed transform leaves the pattern unchanged', () async {
    when(
      () => api.crateApiPatternQuantizeNotes(
        ctx: any(named: 'ctx'),
        patternId: _patternId,
        noteIds: any(named: 'noteIds'),
        stepTicks: any(named: 'stepTicks'),
      ),
    ).thenThrow('pattern is gone');
    final container = await createContainer();

    final result = await container
        .read(pianoRollProvider.notifier)
        .quantizeNotes();

    expect(result.isErr(), isTrue);
    expect(
      container.read(projectProvider).requireValue.patterns[_patternId],
      _pattern,
    );
  });

  test('selecting notes makes them the draw template', () async {
    final container = await createContainer();
    final notifier = container.read(pianoRollProvider.notifier);

    notifier.selectNotes({2});
    notifier.clearNoteSelection();

    expect(container.read(pianoRollProvider).drawTemplate.map((n) => n.id), [
      2,
    ]);
  });

  test('playing sends the loop region before starting', () async {
    when(
      () => api.crateApiTransportSetPatternLoop(
        ctx: any(named: 'ctx'),
        startTick: any(named: 'startTick'),
        endTick: any(named: 'endTick'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => api.crateApiTransportTogglePatternPlayback(
        ctx: any(named: 'ctx'),
        patternId: _patternId,
        generatorId: 9,
      ),
    ).thenAnswer((_) async {});
    final container = await createContainer();
    final notifier = container.read(pianoRollProvider.notifier);

    await notifier.setLoopRegion(
      const PatternLoopRegion(startTick: 960, endTick: 480),
    );
    expect(container.read(pianoRollProvider).loopRegion, isNull);

    await notifier.setLoopRegion(
      const PatternLoopRegion(startTick: 960, endTick: 1920),
    );
    await notifier.togglePatternPlayback();

    verifyInOrder([
      () => api.crateApiTransportSetPatternLoop(
        ctx: any(named: 'ctx'),
        startTick: 960,
        endTick: 1920,
      ),
      () => api.crateApiTransportTogglePatternPlayback(
        ctx: any(named: 'ctx'),
        patternId: _patternId,
        generatorId: 9,
      ),
    ]);
  });

  test('piano-roll shortcuts do not collide with any default shortcut', () {
    final container = ProviderContainer.test();
    final chords = <ShortcutChord>{};
    for (final shortcut in container.read(shortcutCatalogProvider)) {
      expect(
        chords.add(ShortcutChord.fromActivator(shortcut.defaultKey)),
        isTrue,
        reason: '${shortcut.id} reuses another default key',
      );
      expect(shortcut.intent, isA<Intent>());
    }
  });
}
