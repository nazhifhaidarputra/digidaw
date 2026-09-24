import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/src/rust/api/automation.dart';
import 'package:karbeat/src/rust/api/mixer.dart';
import 'package:karbeat/src/rust/api/pattern.dart';
import 'package:karbeat/src/rust/api/project.dart';

class _ProjectNotifier extends ProjectNotifier {
  @override
  Future<ApplicationDataStore> build() async => _projectData();
}

void main() {
  test('removing a MIDI track also removes its generator', () async {
    final container = ProviderContainer.test(
      overrides: [projectProvider.overrideWith(_ProjectNotifier.new)],
    );
    await container.read(projectProvider.future);

    container.read(projectProvider.notifier).removeTrack(1);

    final project = container.read(projectProvider).requireValue;
    expect(project.tracks.containsKey(1), isFalse);
    expect(project.generators.containsKey(10), isFalse);
    expect(project.generators.containsKey(20), isTrue);
  });

  test('effect removal publishes mixer and automation in one update', () async {
    final container = ProviderContainer.test(
      overrides: [projectProvider.overrideWith(_ProjectNotifier.new)],
    );
    await container.read(projectProvider.future);
    final notifier = container.read(projectProvider.notifier);
    notifier.updateAutomations(
      pool: IMap({1: _lane(1), 2: _lane(2)}),
      sources: IMap({
        11: const ModulationSourceDto.automation(laneId: 1),
        12: const ModulationSourceDto.automation(laneId: 2),
      }),
      links: IMap({21: _link(21, 11), 22: _link(22, 12)}),
    );
    final mixer = container.read(projectProvider).requireValue.mixer;

    var emissions = 0;
    container.listen(projectProvider, (_, _) => emissions++);
    notifier.commitEffectRemoval(
      mixer: mixer,
      removedAutomation: const RemovedAutomationDto(
        automationLaneIds: [1],
        modulationSourceIds: [11],
        modulationLinkIds: [21],
      ),
    );

    final project = container.read(projectProvider).requireValue;
    expect(emissions, 1);
    expect(project.automationPool.keys, [2]);
    expect(project.modulationSources.keys, [12]);
    expect(project.modulationLinks.keys, [22]);
  });

  test('audio loading failures are returned instead of escaping', () async {
    final container = ProviderContainer.test(
      overrides: [projectProvider.overrideWith(_ProjectNotifier.new)],
    );
    await container.read(projectProvider.future);

    final result = await container
        .read(projectProvider.notifier)
        .loadAudioSource('/missing/audio.wav');

    expect(result.isErr(), isTrue);
  });
}

ApplicationDataStore _projectData() {
  const master = UiMixerChannel(
    volume: 1,
    pan: 0,
    mute: false,
    solo: false,
    invertedPhase: false,
    effects: [],
  );
  return ApplicationDataStore(
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
        name: 'MIDI',
        color: '',
        trackType: UiTrackType.midi,
        clips: [],
        generatorId: 10,
        orderIdx: 0,
      ),
      2: const UiTrack(
        id: 2,
        name: 'Other MIDI',
        color: '',
        trackType: UiTrackType.midi,
        clips: [],
        generatorId: 20,
        orderIdx: 1,
      ),
    }),
    generators: IMap({
      10: const UiGeneratorInstance(
        id: 10,
        instanceType: UiGeneratorInstanceType.sampler(assetId: 1, rootNote: 60),
      ),
      20: const UiGeneratorInstance(
        id: 20,
        instanceType: UiGeneratorInstanceType.sampler(assetId: 2, rootNote: 60),
      ),
    }),
    patterns: const IMapConst<int, UiPattern>({}),
    mixer: const UiMixerState.raw(
      channels: {},
      masterBus: master,
      buses: {},
      routing: [],
    ),
    modulationLinks: const IMapConst<int, ModulationLinkDto>({}),
    automationPool: const IMapConst<int, AutomationLaneDto>({}),
    modulationSources: const IMapConst<int, ModulationSourceDto>({}),
  );
}

AutomationLaneDto _lane(int id) => AutomationLaneDto(
  id: id,
  label: 'Lane $id',
  points: const [],
  enabled: true,
  min: 0,
  max: 1,
  defaultValue: 0.5,
);

ModulationLinkDto _link(int id, int sourceId) => ModulationLinkDto(
  id: id,
  sourceId: sourceId,
  target: const AutomationTargetDto.master(
    MasterAutomationTargetDto.mixerChannel(MixerChannelParamTargetDto.volume()),
  ),
  depth: 1,
  baseValue: 0,
  orderIdx: 0,
);
