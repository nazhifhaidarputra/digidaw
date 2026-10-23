import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:karbeat/src/rust/api/mixer.dart';

part 'global.freezed.dart';

enum ToolSelection {
  panSelect,
  slice,
  draw,
  move,
  delete,
  zoom,
  select,
  resize,
}

/// Piano roll specific tool selection (independent from main toolbar)
enum PianoRollToolSelection {
  grab,
  draw,
  delete,
  select,

  /// Drags a loop region on the ruler.
  selectRegion,
  slice,
  pan,
  zoom,
}

enum WorkspaceView { trackList, pianoRoll, mixer, source }

/// Which gain envelope audio clips show and edit on the timeline.
enum ClipEnvelopeView {
  none,

  /// The waveform envelope, shared by every clip referencing the waveform.
  waveform,

  /// The clip's own envelope, stacked on top of the waveform envelope.
  clip,
}

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

  const factory MixerTarget.tracks(Map<int, UiMixerChannel> channels) =
      _TrackMixerTarget;
}
