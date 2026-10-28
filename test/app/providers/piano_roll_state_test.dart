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

  setUp(() {
    reset(api);
    when(
      () => api.crateApiTransportSwitchPattern(
        ctx: any(named: 'ctx'),
        patternId: any(named: 'patternId'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => api.crateApiTransportSwitchPatternGenerator(
        ctx: any(named: 'ctx'),
        generatorId: any(named: 'generatorId'),
      ),
    ).thenAnswer((_) async {});
  });

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

  group('pattern switching', () {
    test('opening another pattern keeps the selected generator', () async {
      final container = await createContainer();

      container.read(pianoRollProvider.notifier).openPattern(4);

      expect(container.read(pianoRollProvider).previewGeneratorId, 9);
    });

    test('following the opened pattern retargets pattern playback', () async {
      final container = await createContainer();
      final notifier = container.read(pianoRollProvider.notifier);

      notifier.openPattern(4);
      await notifier.followPlaybackPattern(4);

      verify(
        () => api.crateApiTransportSwitchPatternGenerator(
          ctx: any(named: 'ctx'),
          generatorId: 9,
        ),
      ).called(1);
      verify(
        () => api.crateApiTransportSwitchPattern(
          ctx: any(named: 'ctx'),
          patternId: 4,
        ),
      ).called(1);
    });
  });

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

  test('selecting one note makes it the single-note draw template', () async {
    final container = await createContainer();
    final notifier = container.read(pianoRollProvider.notifier);

    notifier.selectNotes({2});
    notifier.clearNoteSelection();

    expect(container.read(pianoRollProvider).drawTemplate.map((n) => n.id), [
      2,
    ]);
  });

  test('clearing a batch selection keeps the last single note armed', () async {
    final container = await createContainer();
    final notifier = container.read(pianoRollProvider.notifier);
    final pattern = container
        .read(projectProvider)
        .requireValue
        .patterns[_patternId]!;

    notifier.selectNotes({2});
    notifier.selectNotes({1, 2});
    expect(notifier.drawTemplateFor(pattern).map((note) => note.id), [1, 2]);

    notifier.clearNoteSelection();

    expect(container.read(pianoRollProvider).drawTemplate.map((n) => n.id), [
      2,
    ]);
    expect(notifier.drawTemplateFor(pattern).map((note) => note.id), [2]);
  });

  test('touching a note in a batch arms only that note for later', () async {
    final container = await createContainer();
    final notifier = container.read(pianoRollProvider.notifier);
    final pattern = container
        .read(projectProvider)
        .requireValue
        .patterns[_patternId]!;

    notifier.selectNotes({1, 2});
    notifier.rememberSingleNote(1);

    expect(container.read(pianoRollProvider).selectedNoteIds.toSet(), {1, 2});
    expect(notifier.drawTemplateFor(pattern).map((note) => note.id), [1, 2]);

    notifier.clearNoteSelection();

    expect(notifier.drawTemplateFor(pattern).map((note) => note.id), [1]);
  });

  test('the draw template ignores a deleted single note', () async {
    final container = await createContainer();
    final notifier = container.read(pianoRollProvider.notifier);
    final pattern = container
        .read(projectProvider)
        .requireValue
        .patterns[_patternId]!;

    notifier.selectNotes({2});
    notifier.clearNoteSelection();

    expect(
      notifier
          .drawTemplateFor(pattern.copyWith(notes: [_note(1, 0, 60)]))
          .isEmpty,
      isTrue,
    );
  });

  test('stretch targets the selection and passes the factor', () async {
    final stretched = _pattern.copyWith(notes: [_note(1, 0, 60)]);
    when(
      () => api.crateApiPatternStretchNotes(
        ctx: any(named: 'ctx'),
        patternId: _patternId,
        noteIds: any(named: 'noteIds'),
        factor: any(named: 'factor'),
      ),
    ).thenAnswer((_) async => stretched);
    final container = await createContainer();
    final notifier = container.read(pianoRollProvider.notifier);
    notifier.selectNotes({1, 2});

    final result = await notifier.stretchNotes(1.5);

    expect(result.isOk(), isTrue);
    verify(
      () => api.crateApiPatternStretchNotes(
        ctx: any(named: 'ctx'),
        patternId: _patternId,
        noteIds: [1, 2],
        factor: 1.5,
      ),
    ).called(1);
    expect(
      container.read(projectProvider).requireValue.patterns[_patternId],
      stretched,
    );
  });

  test(
    'duplicate places copies after the selection on the next step',
    () async {
      final duplicated = _pattern.copyWith(
        notes: [..._pattern.notes, _note(3, 960, 64)],
      );
      when(
        () => api.crateApiPatternDuplicatePatternNotes(
          ctx: any(named: 'ctx'),
          patternId: _patternId,
          noteIds: any(named: 'noteIds'),
          startTick: any(named: 'startTick'),
        ),
      ).thenAnswer((_) async => duplicated);
      final container = await createContainer();
      final notifier = container.read(pianoRollProvider.notifier);
      notifier.selectNotes({2});

      final result = await notifier.duplicateSelectedNotes();

      expect(result.isOk(), isTrue);
      verify(
        () => api.crateApiPatternDuplicatePatternNotes(
          ctx: any(named: 'ctx'),
          patternId: _patternId,
          noteIds: [2],
          startTick: 960,
        ),
      ).called(1);
      expect(
        container.read(projectProvider).requireValue.patterns[_patternId],
        duplicated,
      );
      expect(container.read(pianoRollProvider).selectedNoteIds.toSet(), {3});
    },
  );

  test('Delete removes the selected notes and clears the selection', () async {
    when(
      () => api.crateApiPatternDeleteNotesBatch(
        ctx: any(named: 'ctx'),
        patternId: _patternId,
        noteIds: any(named: 'noteIds'),
      ),
    ).thenAnswer((_) async {});
    final container = await createContainer();
    final notifier = container.read(pianoRollProvider.notifier);
    notifier.selectNotes({2});

    final result = await notifier.deleteSelectedNotes();

    expect(result.isOk(), isTrue);
    verify(
      () => api.crateApiPatternDeleteNotesBatch(
        ctx: any(named: 'ctx'),
        patternId: _patternId,
        noteIds: [2],
      ),
    ).called(1);
    expect(container.read(pianoRollProvider).selectedNoteIds, isEmpty);
    expect(
      container
          .read(projectProvider)
          .requireValue
          .patterns[_patternId]!
          .notes
          .map((note) => note.id),
      [1],
    );
  });

  test('paste starts after the selection on the next step', () async {
    when(
      () => api.crateApiSessionPastePatternNotes(
        ctx: any(named: 'ctx'),
        targetPatternId: _patternId,
        playheadTick: any(named: 'playheadTick'),
        targetKey: any(named: 'targetKey'),
      ),
    ).thenAnswer((_) async => [_note(3, 960, 64)]);
    final container = await createContainer();
    final notifier = container.read(pianoRollProvider.notifier);
    notifier.selectNotes({2});

    final result = await notifier.pasteNotesAfterSelection();

    expect(result.isOk(), isTrue);
    verify(
      () => api.crateApiSessionPastePatternNotes(
        ctx: any(named: 'ctx'),
        targetPatternId: _patternId,
        playheadTick: 960,
        targetKey: null,
      ),
    ).called(1);
    expect(container.read(pianoRollProvider).selectedNoteIds.toSet(), {3});
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
    // Only shortcuts that can be active together must differ: a track-list
    // key may repeat in the piano roll, but neither may repeat a global one
    final chords = <ShortcutChord, List<ShortcutScope>>{};
    for (final shortcut in container.read(shortcutCatalogProvider)) {
      final scopes = chords.putIfAbsent(
        ShortcutChord.fromActivator(shortcut.defaultKey),
        () => [],
      );
      expect(
        scopes.any(shortcut.scope.overlaps),
        isFalse,
        reason: '${shortcut.id} reuses another default key',
      );
      scopes.add(shortcut.scope);
      expect(shortcut.intent, isA<Intent>());
    }
  });
}
