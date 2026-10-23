import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:karbeat/src/rust/api/mixer.dart';

part 'mixer_channel_sidepanel.freezed.dart';

/// Model class representing Mixer Channel Panel State
/// Whether it is open, and which mixer channel are opened
@freezed
abstract class MixerChannelPanelState with _$MixerChannelPanelState {
  const factory MixerChannelPanelState({
    @Default(false) bool isOpen,

    /// The track, bus or master whose strip and effect rack are shown.
    UiMixerChannelTarget? target,
  }) = _MixerChannelPanelState;
}
