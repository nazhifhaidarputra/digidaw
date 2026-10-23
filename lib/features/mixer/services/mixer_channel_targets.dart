import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/painting.dart' show Color;
import 'package:karbeat/core/utils/color.dart';
import 'package:karbeat/features/mixer/services/routing_labels.dart';
import 'package:karbeat/src/rust/api/mixer.dart';
import 'package:karbeat/src/rust/api/plugin.dart';
import 'package:karbeat/src/rust/api/project.dart';

/// Conversions from a mixer channel to the other IDs that address it.
extension MixerChannelTargetLookup on UiMixerChannelTarget {
  UiRoutingNode get routingNode => switch (this) {
    UiMixerChannelTarget_Track(:final field0) => UiRoutingNode.track(field0),
    UiMixerChannelTarget_Bus(:final field0) => UiRoutingNode.bus(field0),
    UiMixerChannelTarget_Master() => const UiRoutingNode.master(),
  };

  /// Plugin target of the effect [effectId] in this channel's rack.
  UiPluginTarget effectTarget(int effectId) => switch (this) {
    UiMixerChannelTarget_Track(:final field0) => UiPluginTarget.trackEffect(
      trackId: field0,
      effectId: effectId,
    ),
    UiMixerChannelTarget_Bus(:final field0) => UiPluginTarget.busEffect(
      busId: field0,
      effectId: effectId,
    ),
    UiMixerChannelTarget_Master() => UiPluginTarget.masterEffect(effectId),
  };

  /// "Track", "Bus" or "Master".
  String get kindLabel => switch (this) {
    UiMixerChannelTarget_Track() => 'Track',
    UiMixerChannelTarget_Bus() => 'Bus',
    UiMixerChannelTarget_Master() => 'Master',
  };

  /// Track or bus ID; null for the master.
  int? get channelId => switch (this) {
    UiMixerChannelTarget_Track(:final field0) => field0,
    UiMixerChannelTarget_Bus(:final field0) => field0,
    UiMixerChannelTarget_Master() => null,
  };

  /// The channel in [mixer], or null when its track or bus is gone.
  UiMixerChannel? channelIn(UiMixerState mixer) => switch (this) {
    UiMixerChannelTarget_Track(:final field0) => mixer.channels[field0],
    UiMixerChannelTarget_Bus(:final field0) => mixer.buses[field0]?.channel,
    UiMixerChannelTarget_Master() => mixer.masterBus,
  };

  /// Track name, bus name, or "Master".
  String displayName(UiMixerState mixer, IMap<int, UiTrack> tracks) =>
      RoutingLabels(mixer: mixer, tracks: tracks).channelName(routingNode);

  /// Colour of the track or bus; null for the master.
  Color? colorIn(UiMixerState mixer, IMap<int, UiTrack> tracks) =>
      switch (this) {
        UiMixerChannelTarget_Track(:final field0) =>
          tracks[field0]?.color.fromRGBorRGBAtoColor(),
        UiMixerChannelTarget_Bus(:final field0) =>
          mixer.buses[field0]?.color.fromRGBorRGBAtoColor(),
        UiMixerChannelTarget_Master() => null,
      };
}
