import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:karbeat/src/rust/api/mixer.dart';

part 'global.freezed.dart';

enum ToolSelection { pointer, slice, draw, move, delete, zoom, select, resize }

/// Piano roll specific tool selection (independent from main toolbar)
enum PianoRollToolSelection { grab, draw, delete, select, slice, pan, zoom }

enum WorkspaceView { trackList, pianoRoll, mixer, source }

enum ToolbarMenuContextGroup { none, project, edit, view }

/// Events that trigger a state refresh
enum ProjectEvent {
  tracksChanged,
  transportChanged,
  metadataChanged,
  sourceListChanged,
  generatorListChanged,
  effectListChanged,
  configChanged,
  patternChanged,
  mixerChanged,
}

@freezed
sealed class MixerTarget with _$MixerTarget {
  const factory MixerTarget.master(UiMixerChannel channel) = _MasterMixerTarget;

  const factory MixerTarget.buses(Map<int, UiBus> channels) = _BusMixerTarget;

  const factory MixerTarget.tracks(Map<int, UiMixerChannel> channels) = _TrackMixerTarget;
}
