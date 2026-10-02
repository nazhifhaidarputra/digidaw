import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/app/providers/track_list_state.dart';
import 'package:karbeat/shared/models/grid.dart';
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

UiClip _clip(int id, int startTick) => UiClip(
  name: 'Clip $id',
  id: id,
  startTime: startTick,
  source: const UiClipSource.midi(patternId: 1),
  offsetStart: 0,
  loopLength: 960,
  isSampleBased: false,
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
    tracks: IMap({
      1: UiTrack(
        id: 1,
        name: 'Lead',
        color: '#345678',
        trackType: UiTrackType.midi,
        clips: [_clip(10, 480), _clip(11, 1920)],
        orderIdx: 0,
      ),
    }),
    generators: const IMapConst({}),
    patterns: const IMapConst<int, UiPattern>({}),
    mixer: UiMixerState.raw(
      channels: {1: _channel},
      masterBus: _channel,
      buses: {
        5: const UiBus(id: 5, name: 'Drums', channel: _channel, color: ''),
      },
      routing: [],
    ),
    modulationLinks: const IMapConst<int, ModulationLinkDto>({}),
    automationPool: const IMapConst<int, AutomationLaneDto>({}),
    modulationSources: const IMapConst<int, ModulationSourceDto>({}),
  );
}

Future<ProviderContainer> _container() async {
  final container = ProviderContainer(
    overrides: [projectProvider.overrideWith(_ProjectNotifier.new)],
  );
  addTearDown(container.dispose);
  await container.read(projectProvider.future);
  return container;
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
      () => api.crateApiTrackMoveClipBatch(
        ctx: any(named: 'ctx'),
        sourceTrackId: any(named: 'sourceTrackId'),
        clipIds: any(named: 'clipIds'),
        deltaTicks: any(named: 'deltaTicks'),
        newTrackId: any(named: 'newTrackId'),
      ),
    ).thenAnswer((_) async => []);
  });

  group('mixer channel panel', () {
    test(
      'selecting a channel opens it and selecting it again closes',
      () async {
        final container = await _container();
        final notifier = container.read(trackListStateProvider.notifier);
        const track = UiMixerChannelTarget.track(1);
        const bus = UiMixerChannelTarget.bus(5);

        expect(container.read(mixerChannelPanelTargetProvider), isNull);

        notifier.selectMixerChannel(track);
        expect(container.read(mixerChannelPanelTargetProvider), track);

        notifier.selectMixerChannel(bus);
        expect(container.read(mixerChannelPanelTargetProvider), bus);

        notifier.selectMixerChannel(bus);
        expect(container.read(mixerChannelPanelTargetProvider), isNull);

        notifier.selectMixerChannel(const UiMixerChannelTarget.master());
        notifier.closeMixerChannelPanel();
        expect(container.read(mixerChannelPanelTargetProvider), isNull);
      },
    );

    test('a channel that no longer exists is not shown', () async {
      final container = await _container();
      final notifier = container.read(trackListStateProvider.notifier);

      notifier.selectMixerChannel(const UiMixerChannelTarget.track(99));
      expect(container.read(mixerChannelPanelTargetProvider), isNull);

      notifier.selectMixerChannel(const UiMixerChannelTarget.track(1));
      expect(
        container.read(mixerChannelPanelTargetProvider),
        const UiMixerChannelTarget.track(1),
      );
      container.read(projectProvider.notifier)
        ..removeTrack(1)
        ..removeTrackMixerChannel(1);
      expect(container.read(mixerChannelPanelTargetProvider), isNull);
    });
  });

  group('nudging the selected clips', () {
    int movedBy() =>
        verify(
              () => api.crateApiTrackMoveClipBatch(
                ctx: any(named: 'ctx'),
                sourceTrackId: 1,
                clipIds: any(named: 'clipIds'),
                deltaTicks: captureAny(named: 'deltaTicks'),
                newTrackId: null,
              ),
            ).captured.single
            as int;

    test('moves by the move step', () async {
      final container = await _container();
      final notifier = container.read(trackListStateProvider.notifier)
        ..selectClips(trackId: 1, clipIds: [10, 11]);

      await notifier.nudgeSelectedClips(steps: 1, step: MusicalBeatSize.one);
      expect(movedBy(), 960);

      await notifier.nudgeSelectedClips(
        steps: -1,
        step: MusicalBeatSize.quarter,
      );
      expect(movedBy(), -240);
    });

    test('a move step of none moves one tick', () async {
      final container = await _container();
      final notifier = container.read(trackListStateProvider.notifier)
        ..selectClip(trackId: 1, clipId: 11);

      await notifier.nudgeSelectedClips(steps: 1, step: MusicalBeatSize.none);

      expect(movedBy(), 1);
    });

    test('stops at the start of the timeline', () async {
      final container = await _container();
      final notifier = container.read(trackListStateProvider.notifier)
        ..selectClips(trackId: 1, clipIds: [10, 11]);

      // The earliest clip starts at tick 480, less than one bar
      await notifier.nudgeSelectedClips(steps: -1, step: MusicalBeatSize.four);
      expect(movedBy(), -480);

      // Now at the start, there is nowhere left to go
      await notifier.nudgeSelectedClips(steps: -1, step: MusicalBeatSize.four);
      verifyNever(
        () => api.crateApiTrackMoveClipBatch(
          ctx: any(named: 'ctx'),
          sourceTrackId: any(named: 'sourceTrackId'),
          clipIds: any(named: 'clipIds'),
          deltaTicks: any(named: 'deltaTicks'),
          newTrackId: any(named: 'newTrackId'),
        ),
      );
    });

    test('does nothing without a selection', () async {
      final container = await _container();

      await container
          .read(trackListStateProvider.notifier)
          .nudgeSelectedClips(steps: 1, step: MusicalBeatSize.one);

      verifyNever(
        () => api.crateApiTrackMoveClipBatch(
          ctx: any(named: 'ctx'),
          sourceTrackId: any(named: 'sourceTrackId'),
          clipIds: any(named: 'clipIds'),
          deltaTicks: any(named: 'deltaTicks'),
          newTrackId: any(named: 'newTrackId'),
        ),
      );
    });
  });
}
