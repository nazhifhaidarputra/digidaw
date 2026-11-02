import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karbeat/app/providers/automation_provider.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/src/rust/api/automation.dart';
import 'package:karbeat/src/rust/api/mixer.dart';
import 'package:karbeat/src/rust/api/pattern.dart';
import 'package:karbeat/src/rust/api/project.dart';
import 'package:mocktail/mocktail.dart';

class _MockDawContext extends Mock implements DawContext {}

class _ProjectNotifier extends ProjectNotifier {
  _ProjectNotifier(this.project);

  final ApplicationDataStore project;
  final DawContext context = _MockDawContext();

  @override
  DawContext get dawContext => context;

  @override
  Future<ApplicationDataStore> build() async => project;
}

const _volume = MixerChannelParamTargetDto.volume();
const _pan = MixerChannelParamTargetDto.pan();

const _channel = UiMixerChannel(
  volume: 1,
  pan: 0,
  mute: false,
  solo: false,
  invertedPhase: false,
  effects: [],
);

AutomationLaneDto _lane(int id) => AutomationLaneDto(
  id: id,
  label: 'Lane $id',
  points: const [],
  enabled: true,
  defaultValue: 0,
);

ModulationLinkDto _link(int id, AutomationTargetDto target, int orderIdx) =>
    ModulationLinkDto(
      id: id,
      // Each link reads the source with its own id.
      sourceId: id,
      target: target,
      depth: 1,
      baseValue: 0,
      orderIdx: orderIdx,
    );

ApplicationDataStore _project() => ApplicationDataStore(
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
      name: 'Synth',
      color: '#345678',
      trackType: UiTrackType.midi,
      clips: [],
      generatorId: 7,
      orderIdx: 0,
      input: UiTrackInput(firstChannel: 0, channels: 2, monitor: false),
    ),
  }),
  generators: IMap({
    7: const UiGeneratorInstance(
      id: 7,
      instanceType: UiGeneratorInstanceType.plugin(
        UiPluginInstance(
          registryId: 42,
          name: 'Test Synth',
          label: 'Test Synth',
          bypass: false,
        ),
      ),
    ),
  }),
  patterns: const IMapConst<int, UiPattern>({}),
  mixer: UiMixerState.raw(
    channels: {1: _channel},
    masterBus: _channel,
    buses: {},
    routing: [],
  ),
  modulationLinks: IMap({
    // The generator lane sorts after the track's volume lane.
    10: _link(
      10,
      const AutomationTargetDto.generator(generatorId: 7, paramId: 0),
      2,
    ),
    11: _link(
      11,
      const AutomationTargetDto.track(
        trackId: 1,
        trackTarget: TrackAutomationTargetDto.mixerChannel(_volume),
      ),
      1,
    ),
    12: _link(12, const AutomationTargetDto.bus(busId: 3, mixTarget: _pan), 0),
    13: _link(
      13,
      const AutomationTargetDto.master(
        MasterAutomationTargetDto.mixerChannel(_volume),
      ),
      0,
    ),
    // An LFO-driven link has no lane.
    14: _link(
      14,
      const AutomationTargetDto.track(
        trackId: 1,
        trackTarget: TrackAutomationTargetDto.mixerChannel(_pan),
      ),
      0,
    ),
  }),
  automationPool: IMap({
    for (final id in [100, 101, 102, 103]) id: _lane(id),
  }),
  modulationSources: IMap({
    10: const ModulationSourceDto.automation(laneId: 100),
    11: const ModulationSourceDto.automation(laneId: 101),
    12: const ModulationSourceDto.automation(laneId: 102),
    13: const ModulationSourceDto.automation(laneId: 103),
    14: const ModulationSourceDto.lfo(rateHz: 1),
  }),
);

Future<ProviderContainer> _container() async {
  final container = ProviderContainer(
    overrides: [
      projectProvider.overrideWith(() => _ProjectNotifier(_project())),
    ],
  );
  addTearDown(container.dispose);
  await container.read(projectProvider.future);
  return container;
}

void main() {
  test(
    'groups lanes by channel, with generator lanes on their track',
    () async {
      final container = await _container();

      expect(container.read(trackAutomationProvider(1)).map((e) => e.linkId), [
        11,
        10,
      ]);
      expect(
        container.read(trackAutomationProvider(1)).map((e) => e.sourceName),
        ['Synth', 'Test Synth'],
      );
      expect(container.read(busAutomationProvider(3)).map((e) => e.linkId), [
        12,
      ]);
      expect(container.read(masterAutomationProvider).map((e) => e.laneId), [
        103,
      ]);
      expect(container.read(trackAutomationProvider(2)), isEmpty);
    },
  );

  test(
    'a project publish that leaves the lanes alone notifies no channel',
    () async {
      final container = await _container();
      var trackNotifications = 0;
      var masterNotifications = 0;
      container.listen(
        trackAutomationProvider(1),
        (_, _) => trackNotifications += 1,
      );
      container.listen(
        masterAutomationProvider,
        (_, _) => masterNotifications += 1,
      );

      // Automation moving a volume republishes the mixer.
      final mixer = container.read(projectProvider).requireValue.mixer;
      container
          .read(projectProvider.notifier)
          .updateMixer(
            mixer.copyWith(
              channels: {
                1: const UiMixerChannel(
                  volume: 0.5,
                  pan: 0,
                  mute: false,
                  solo: false,
                  invertedPhase: false,
                  effects: [],
                ),
              },
            ),
          );
      await container.pump();

      expect(trackNotifications, 0);
      expect(masterNotifications, 0);
    },
  );
}
