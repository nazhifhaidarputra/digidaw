import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karbeat/app/providers/automation_provider.dart';
import 'package:karbeat/app/providers/track_list_state.dart';
import 'package:karbeat/src/rust/api/automation.dart';
import 'package:karbeat/src/rust/api/plugin.dart';

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
