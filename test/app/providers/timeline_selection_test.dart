import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karbeat/app/providers/automation_provider.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/app/providers/range_select_state.dart';
import 'package:karbeat/app/providers/track_list_state.dart';
import 'package:karbeat/shared/models/grid.dart';
import 'package:karbeat/src/rust/api/automation.dart';
import 'package:karbeat/src/rust/api/mixer.dart';
import 'package:karbeat/src/rust/api/pattern.dart';
import 'package:karbeat/src/rust/api/project.dart';
import 'package:karbeat/src/rust/api/track.dart';
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

UiClip _clip(int id, int startTick) => UiClip(
  name: 'Clip $id',
  id: id,
  startTime: startTick,
  source: const UiClipSource.midi(patternId: 1),
  offsetStart: 0,
  loopLength: 960,
  isSampleBased: false,
);

UiTrack _track(int id, int orderIdx, List<UiClip> clips) => UiTrack(
  id: id,
  name: 'Track $id',
  color: '#345678',
  trackType: UiTrackType.midi,
  clips: clips,
  orderIdx: orderIdx,
  input: const UiTrackInput(firstChannel: 0, channels: 2, monitor: false),
);

AutomationRegionDto _region(int id, int start, int length) =>
    AutomationRegionDto(
      id: id,
      name: 'Region $id',
      startTicks: start,
      lengthTicks: length,
      contentId: id,
      contentOffset: 0,
    );

/// Track 1 sits above track 2, whose volume lane 7 has two regions.
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
      1: _track(1, 0, [_clip(10, 0), _clip(11, 4000)]),
      2: _track(2, 1, [_clip(20, 500)]),
    }),
    generators: const IMapConst({}),
    patterns: const IMapConst<int, UiPattern>({}),
    mixer: UiMixerState.raw(
      channels: {1: _channel, 2: _channel},
      masterBus: _channel,
      buses: {},
      routing: [],
    ),
    modulationLinks: const IMapConst({
      3: ModulationLinkDto(
        id: 3,
        sourceId: 4,
        target: AutomationTargetDto.track(
          trackId: 2,
          trackTarget: TrackAutomationTargetDto.mixerChannel(
            MixerChannelParamTargetDto.volume(),
          ),
        ),
        depth: 1,
        baseValue: 0,
        orderIdx: 0,
      ),
    }),
    automationPool: IMap({
      7: AutomationLaneDto(
        id: 7,
        label: 'Volume',
        points: const [],
        enabled: true,
        defaultValue: 0.5,
        regions: [_region(0, 200, 400), _region(1, 3000, 500)],
      ),
    }),
    modulationSources: const IMapConst({
      4: ModulationSourceDto.automation(laneId: 7),
    }),
  );
}

void main() {
  final api = _MockRustLibApi();
  late ProviderContainer container;

  setUpAll(() {
    registerFallbackValue(_MockDawContext());
    RustLib.initMock(api: api);
  });

  setUp(() async {
    reset(api);
    when(
      () => api.crateApiProjectGetTracks(ctx: any(named: 'ctx')),
    ).thenAnswer((_) async => {});
    when(
      () => api.crateApiPatternGetPatterns(ctx: any(named: 'ctx')),
    ).thenAnswer((_) async => {});
    when(
      () =>
          api.crateApiAutomationGetAutomationsLanesAll(ctx: any(named: 'ctx')),
    ).thenAnswer((_) async => {});
    when(
      () => api.crateApiTrackMoveSelection(
        ctx: any(named: 'ctx'),
        clips: any(named: 'clips'),
        regions: any(named: 'regions'),
        deltaTicks: any(named: 'deltaTicks'),
      ),
    ).thenAnswer((invocation) async => 0);

    container = ProviderContainer(
      overrides: [projectProvider.overrideWith(_ProjectNotifier.new)],
    );
    addTearDown(container.dispose);
    await container.read(projectProvider.future);
  });

  group('timeline rows', () {
    test('follow the arranger order and skip hidden lanes', () {
      expect(container.read(timelineRowsProvider), [
        const TimelineRow.track(1),
        const TimelineRow.track(2),
        const TimelineRow.lane(7),
      ]);

      container
          .read(automationProvider.notifier)
          .toggleTrackAutomationExpanded(2);
      expect(container.read(timelineRowsProvider), [
        const TimelineRow.track(1),
        const TimelineRow.track(2),
      ]);

      container.read(automationProvider.notifier)
        ..toggleTrackAutomationExpanded(2)
        ..toggleAutomationLaneCollapsed(laneId: 7);
      expect(
        container.read(timelineRowsProvider),
        isNot(contains(const TimelineRow.lane(7))),
      );
    });
  });

  group('range selection', () {
    test('selects clips and regions on every row it spans', () {
      container.read(rangeSelectProvider.notifier)
        ..start(const TimelineRow.track(1), 100)
        ..update(3200, row: const TimelineRow.lane(7))
        ..finish();

      final selection = container.read(trackListStateProvider);
      expect(
        selection.selectedClips,
        {
          1: [10].lock,
          2: [20].lock,
        }.lock,
      );
      expect(
        selection.selectedRegions,
        {
          7: [0, 1].lock,
        }.lock,
      );
      expect(selection.spansLanes, isTrue);
      expect(selection.selectedTrackId, isNull);
      expect(selection.selectedClipIds, isEmpty);
      expect(selection.selectionCount, 4);
      expect(container.read(rangeSelectProvider).isSelecting, isFalse);
    });

    test('drawn on the ruler covers every row', () {
      container.read(rangeSelectProvider.notifier)
        ..startAllRows(3900)
        ..update(4100)
        ..finish();

      final selection = container.read(trackListStateProvider);
      expect(
        selection.selectedClips,
        {
          1: [11].lock,
        }.lock,
      );
      expect(selection.selectedRegions, isEmpty);
      expect(selection.selectedTrackId, 1);
    });

    test('a range over nothing clears the selection', () {
      container
          .read(trackListStateProvider.notifier)
          .selectClip(trackId: 1, clipId: 10);
      container.read(rangeSelectProvider.notifier)
        ..start(const TimelineRow.track(2), 8000)
        ..update(9000)
        ..finish();

      expect(container.read(trackListStateProvider).hasSelection, isFalse);
    });
  });

  group('selection edits', () {
    test('a move stops where a region meets its neighbour', () {
      final notifier = container.read(trackListStateProvider.notifier)
        ..selectTimelineItems(
          clips: IMap({
            2: [20].lock,
          }),
          regions: IMap({
            7: [0].lock,
          }),
        );

      // Region 0 ends at 600 and region 1 starts at 3000.
      expect(notifier.clampSelectionMove(5000), 2400);
      // The earliest item, region 0, starts at 200.
      expect(notifier.clampSelectionMove(-1000), -200);
    });

    test('nudging a multi-lane selection moves it as one edit', () async {
      final notifier = container.read(trackListStateProvider.notifier)
        ..selectTimelineItems(
          clips: IMap({
            1: [10].lock,
            2: [20].lock,
          }),
          regions: const IMapConst({}),
        );

      await notifier.nudgeSelectedClips(steps: 1, grid: GridSize.quarter);

      final captured = verify(
        () => api.crateApiTrackMoveSelection(
          ctx: any(named: 'ctx'),
          clips: captureAny(named: 'clips'),
          regions: any(named: 'regions'),
          deltaTicks: captureAny(named: 'deltaTicks'),
        ),
      ).captured;
      expect(
        {
          for (final group in captured[0] as List<UiSelectedClips>)
            group.trackId: group.clipIds,
        },
        {
          1: [10],
          2: [20],
        },
      );
      expect(captured[1], 960);
    });

    test('pruning drops regions that no longer exist', () {
      final notifier = container.read(trackListStateProvider.notifier)
        ..selectTimelineItems(
          clips: const IMapConst({}),
          regions: IMap({
            7: [0, 1].lock,
          }),
        );

      notifier.pruneRegionSelection(7, {1});
      expect(container.read(trackListStateProvider).regionsSelectedOn(7), [1]);
      notifier.pruneRegionSelection(7, {});
      expect(container.read(trackListStateProvider).hasSelection, isFalse);
    });
  });
}
