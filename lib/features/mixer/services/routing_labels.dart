import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:karbeat/src/rust/api/mixer.dart';
import 'package:karbeat/src/rust/api/plugin.dart';
import 'package:karbeat/src/rust/api/project.dart';

/// Resolves user-facing names for routing nodes and sidechain inputs.
class RoutingLabels {
  const RoutingLabels({required this.mixer, required this.tracks});

  final UiMixerState mixer;
  final IMap<int, UiTrack> tracks;

  String channelName(UiRoutingNode node) => switch (node) {
    UiRoutingNode_Track(:final field0) =>
      tracks[field0]?.name ?? 'Track $field0',
    UiRoutingNode_Bus(:final field0) =>
      mixer.buses[field0]?.name ?? 'Bus $field0',
    UiRoutingNode_Master() => 'Master',
    UiRoutingNode_PluginSidechain(:final field0) => sidechainName(field0),
  };

  /// Channel that owns the plugin fed by a sidechain into [plugin].
  UiRoutingNode? sidechainOwner(UiPluginTarget plugin) => switch (plugin) {
    UiPluginTarget_TrackEffect(:final trackId) => UiRoutingNode.track(trackId),
    UiPluginTarget_BusEffect(:final busId) => UiRoutingNode.bus(busId),
    UiPluginTarget_MasterEffect() => const UiRoutingNode.master(),
    UiPluginTarget_Generator(field0: final generatorId) =>
      tracks.values
          .where((track) => track.generatorId == generatorId)
          .map((track) => UiRoutingNode.track(track.id))
          .firstOrNull,
  };

  /// Effects in the chain of [channel], in rack order.
  List<UiEffectSummary> effectsOf(UiRoutingNode channel) => switch (channel) {
    UiRoutingNode_Track(:final field0) => mixer.channels[field0]?.effects ?? [],
    UiRoutingNode_Bus(:final field0) =>
      mixer.buses[field0]?.channel.effects ?? [],
    UiRoutingNode_Master() => mixer.masterBus.effects,
    UiRoutingNode_PluginSidechain() => [],
  };

  /// Plugin target of the effect [effectId] in the chain of [channel].
  UiPluginTarget? effectTarget(UiRoutingNode channel, int effectId) =>
      switch (channel) {
        UiRoutingNode_Track(:final field0) => UiPluginTarget.trackEffect(
          trackId: field0,
          effectId: effectId,
        ),
        UiRoutingNode_Bus(:final field0) => UiPluginTarget.busEffect(
          busId: field0,
          effectId: effectId,
        ),
        UiRoutingNode_Master() => UiPluginTarget.masterEffect(effectId),
        UiRoutingNode_PluginSidechain() => null,
      };

  /// "Lead · Sidechain Compressor" for a sidechain into [plugin].
  String sidechainName(UiPluginTarget plugin) {
    final owner = sidechainOwner(plugin);
    if (owner == null) return 'Instrument sidechain';
    final effectId = switch (plugin) {
      UiPluginTarget_TrackEffect(:final effectId) => effectId,
      UiPluginTarget_BusEffect(:final effectId) => effectId,
      UiPluginTarget_MasterEffect(:final field0) => field0,
      UiPluginTarget_Generator() => null,
    };
    final effect = effectsOf(
      owner,
    ).where((effect) => effect.id == effectId).firstOrNull;
    final pluginName = effect?.name ?? 'Instrument';
    return '${channelName(owner)} · $pluginName';
  }
}
