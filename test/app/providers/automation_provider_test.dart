import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karbeat/app/providers/automation_provider.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/app/providers/track_list_state.dart';
import 'package:karbeat/src/rust/api/automation.dart';
import 'package:karbeat/src/rust/api/mixer.dart';
import 'package:karbeat/src/rust/api/pattern.dart';
import 'package:karbeat/src/rust/api/plugin.dart';
import 'package:karbeat/src/rust/api/project.dart';

UiMixerChannel _channel(List<UiEffectSummary> effects) => UiMixerChannel(
  volume: 0,
  pan: 0,
  mute: false,
  solo: false,
  invertedPhase: false,
  effects: effects,
);

UiEffectSummary _effect(int id, String name) =>
    UiEffectSummary(id: id, registryId: 0, name: name, bypass: false);

final _project = ApplicationDataStore(
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
  tracks: IMap(const {
    1: UiTrack(
      id: 1,
      name: 'Lead',
      color: '#ffffff',
      trackType: UiTrackType.midi,
      clips: [],
      generatorId: 2,
      orderIdx: 0,
    ),
  }),
  generators: IMap(const {
    2: UiGeneratorInstance(
      id: 2,
      instanceType: UiGeneratorInstanceType.plugin(
        UiPluginInstance(registryId: 0, name: 'Vital', bypass: false),
      ),
    ),
  }),
  patterns: const IMapConst<int, UiPattern>({}),
  mixer: UiMixerState.raw(
    channels: {
      1: _channel([_effect(4, 'Reverb')]),
    },
    masterBus: _channel([_effect(6, 'Limiter')]),
    buses: {
      5: UiBus(
        id: 5,
        name: 'Drums',
        channel: _channel([_effect(7, 'Compressor')]),
        color: '#ffffff',
      ),
    },
    routing: [],
  ),
  modulationLinks: const IMapConst<int, ModulationLinkDto>({}),
  automationPool: const IMapConst<int, AutomationLaneDto>({}),
  modulationSources: const IMapConst<int, ModulationSourceDto>({}),
);

void main() {
  test('automation lanes resize within bounds and shrink to a title row', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(automationProvider.notifier);

    expect(container.read(automationLaneLayoutProvider(3)), (
      collapsed: false,
      height: AutomationNotifier.defaultLaneHeight.toDouble(),
    ));

    notifier.changeAutomationLaneHeight(laneId: 3, newHeight: 10_000);
    expect(
      container.read(automationLaneLayoutProvider(3)).height,
      AutomationNotifier.maxLaneHeight,
    );

    notifier.toggleAutomationLaneCollapsed(laneId: 3);
    expect(container.read(automationLaneLayoutProvider(3)), (
      collapsed: true,
      height: TrackListNotifier.collapsedLaneHeight,
    ));
    expect(container.read(automationLaneLayoutProvider(4)).collapsed, isFalse);

    notifier.toggleAutomationLaneCollapsed(laneId: 3);
    notifier.resetAutomationLaneHeight(laneId: 3);
    expect(
      container.read(automationLaneLayoutProvider(3)).height,
      AutomationNotifier.defaultLaneHeight,
    );
  });

  test('effect parameters map to their channel automation targets', () {
    const param = EffectAutomationTargetDto.pluginParam(paramId: 9);
    const effect = MixerChannelParamTargetDto.plugin(
      effectId: 4,
      target: param,
    );

    expect(
      automationTargetForPluginParameter(const UiPluginTarget.generator(2), 9),
      const AutomationTargetDto.generator(generatorId: 2, paramId: 9),
    );
    expect(
      automationTargetForPluginParameter(
        const UiPluginTarget.trackEffect(trackId: 1, effectId: 4),
        9,
      ),
      const AutomationTargetDto.track(
        trackId: 1,
        trackTarget: TrackAutomationTargetDto.mixerChannel(effect),
      ),
    );
    expect(
      automationTargetForPluginParameter(
        const UiPluginTarget.busEffect(busId: 5, effectId: 4),
        9,
      ),
      const AutomationTargetDto.bus(busId: 5, mixTarget: effect),
    );
    expect(
      automationTargetForPluginParameter(
        const UiPluginTarget.masterEffect(4),
        9,
      ),
      const AutomationTargetDto.master(
        MasterAutomationTargetDto.mixerChannel(effect),
      ),
    );
  });

  test('automation sources name the plugin or channel that owns the '
      'parameter', () {
    const mix = EffectAutomationTargetDto.mix();
    String source(AutomationTargetDto target) =>
        automationSourceName(_project, target);

    expect(
      source(const AutomationTargetDto.generator(generatorId: 2, paramId: 1)),
      'Vital',
    );
    expect(
      source(
        const AutomationTargetDto.track(
          trackId: 1,
          trackTarget: TrackAutomationTargetDto.mixerChannel(
            MixerChannelParamTargetDto.volume(),
          ),
        ),
      ),
      'Lead',
    );
    expect(
      source(
        const AutomationTargetDto.track(
          trackId: 1,
          trackTarget: TrackAutomationTargetDto.mixerChannel(
            MixerChannelParamTargetDto.plugin(effectId: 4, target: mix),
          ),
        ),
      ),
      'Reverb',
    );
    expect(
      source(
        const AutomationTargetDto.bus(
          busId: 5,
          mixTarget: MixerChannelParamTargetDto.plugin(
            effectId: 7,
            target: mix,
          ),
        ),
      ),
      'Compressor',
    );
    expect(
      source(
        const AutomationTargetDto.bus(
          busId: 5,
          mixTarget: MixerChannelParamTargetDto.pan(),
        ),
      ),
      'Drums',
    );
    expect(
      source(
        const AutomationTargetDto.master(
          MasterAutomationTargetDto.mixerChannel(
            MixerChannelParamTargetDto.plugin(effectId: 6, target: mix),
          ),
        ),
      ),
      'Limiter',
    );
    expect(
      source(
        const AutomationTargetDto.master(MasterAutomationTargetDto.tempoBpm()),
      ),
      'Transport',
    );
    expect(
      source(const AutomationTargetDto.generator(generatorId: 9, paramId: 1)),
      'Missing instrument',
    );
  });

  test('shrinking a track is toggled per track', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(trackListStateProvider.notifier);

    notifier.toggleTrackCollapsed(trackId: 1);
    expect(container.read(trackListStateProvider).collapsedTrackIds, {1});

    notifier.toggleTrackCollapsed(trackId: 1);
    expect(container.read(trackListStateProvider).collapsedTrackIds, isEmpty);
  });
}
