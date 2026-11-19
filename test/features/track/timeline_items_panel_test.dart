import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/app/providers/range_select_state.dart';
import 'package:karbeat/app/providers/track_list_state.dart';
import 'package:karbeat/features/track/view/timeline_items_panel.dart';
import 'package:karbeat/src/rust/api/automation.dart';
import 'package:karbeat/src/rust/api/mixer.dart';
import 'package:karbeat/src/rust/api/pattern.dart';
import 'package:karbeat/src/rust/api/project.dart';
import 'package:karbeat/src/rust/frb_generated.dart';
import 'package:mocktail/mocktail.dart';

class _MockDawContext extends Mock implements DawContext {}

class _MockRustLibApi extends Mock implements RustLibApi {}

const _channel = UiMixerChannel(
  volume: 0,
  pan: 0,
  mute: false,
  solo: false,
  invertedPhase: false,
  effects: [],
);

/// One MIDI track holding the clips "Intro" and "Verse".
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
    tracks: IMap({
      1: const UiTrack(
        id: 1,
        name: 'Lead',
        color: '#345678',
        trackType: UiTrackType.midi,
        clips: [
          UiClip(
            name: 'Verse',
            id: 11,
            startTime: 3840,
            source: UiClipSource.midi(patternId: 1),
            offsetStart: 0,
            loopLength: 960,
            isSampleBased: false,
          ),
          UiClip(
            name: 'Intro',
            id: 10,
            startTime: 0,
            source: UiClipSource.midi(patternId: 1),
            offsetStart: 0,
            loopLength: 960,
            isSampleBased: false,
          ),
        ],
        orderIdx: 0,
        input: UiTrackInput(firstChannel: 0, channels: 2, monitor: false),
      ),
    }),
    generators: const IMapConst({}),
    patterns: const IMapConst<int, UiPattern>({}),
    mixer: UiMixerState.raw(
      channels: {1: _channel},
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
      () => api.crateApiTrackDeleteClipBatch(
        ctx: any(named: 'ctx'),
        trackId: any(named: 'trackId'),
        clipIds: any(named: 'clipIds'),
      ),
    ).thenAnswer((_) async {});
  });

  Future<(ProviderContainer, List<(TimelineRow, int)>)> pumpPanel(
    WidgetTester tester,
  ) async {
    final revealed = <(TimelineRow, int)>[];
    final container = ProviderContainer(
      overrides: [projectProvider.overrideWith(_ProjectNotifier.new)],
    );
    addTearDown(container.dispose);
    await container.read(projectProvider.future);
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: TimelineItemsPanel(
              scrollController: scrollController,
              onReveal: (row, tick) => revealed.add((row, tick)),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (container, revealed);
  }

  testWidgets('lists clips in timeline order', (tester) async {
    await pumpPanel(tester);
    final intro = tester.getTopLeft(find.text('Intro'));
    final verse = tester.getTopLeft(find.text('Verse'));
    expect(intro.dy, lessThan(verse.dy));
  });

  testWidgets('tapping a clip selects it and reveals it', (tester) async {
    final (container, revealed) = await pumpPanel(tester);
    await tester.tap(find.text('Verse'));
    await tester.pump();

    expect(revealed, [(const TimelineRow.track(1), 3840)]);
    expect(container.read(trackListStateProvider).selectedClipIds, [11]);
  });

  testWidgets('right-clicking a clip opens its actions', (tester) async {
    final (container, _) = await pumpPanel(tester);
    await tester.tap(find.text('Intro'), buttons: kSecondaryButton);
    await tester.pumpAndSettle();

    // The clip's own menu, as on the timeline.
    expect(find.text('Rename'), findsOneWidget);
    expect(find.text('Go to Piano Roll'), findsOneWidget);
    expect(container.read(trackListStateProvider).selectedClipIds, [10]);

    // Delete ends the menu, below the test screen's fold.
    await tester.ensureVisible(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    verify(
      () => api.crateApiTrackDeleteClipBatch(
        ctx: any(named: 'ctx'),
        trackId: 1,
        clipIds: [10],
      ),
    ).called(1);
  });
}
