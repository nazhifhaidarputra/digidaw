import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:karbeat/core/input/shortcut_models.dart';
import 'package:karbeat/generated/shortcuts/shortcut_keys.dart';
import 'package:karbeat/shared/enums/global.dart';

/// Switches the track-list tool.
class SelectTrackListToolIntent extends Intent {
  const SelectTrackListToolIntent(this.tool);

  final ToolSelection tool;
}

/// Moves the selected clips by [steps] grid cells in time.
class NudgeClipsIntent extends Intent {
  const NudgeClipsIntent(this.steps);

  final int steps;
}

/// Copies the selected clips to the clip clipboard.
class CopyClipsIntent extends Intent {
  const CopyClipsIntent();
}

/// Pastes the clip clipboard at the last clicked timeline position.
class PasteClipsIntent extends Intent {
  const PasteClipsIntent();
}

/// Duplicates the selected clips directly after the selection.
class DuplicateClipsIntent extends Intent {
  const DuplicateClipsIntent();
}

/// Deletes the selected clips and clears the selection.
class DeleteClipsIntent extends Intent {
  const DeleteClipsIntent();
}

/// Moves the selected clips to the clip clipboard.
class CutClipsIntent extends Intent {
  const CutClipsIntent();
}

/// Snaps the starts and ends of the selected clips to the grid.
class QuantizeClipsIntent extends Intent {
  const QuantizeClipsIntent();
}

/// Snaps the starts of the selected clips to the grid, keeping their lengths.
class QuantizeClipStartsIntent extends Intent {
  const QuantizeClipStartsIntent();
}

/// Makes each selected clip end where the next selected clip starts.
class LegatoClipsIntent extends Intent {
  const LegatoClipsIntent();
}

/// Track-list shortcuts. They are active only in the track list view.
const trackListShortcuts = IListConst<DawShortcut>([
  DawShortcut(
    key: TrackListToolShortcutKeys.panSelect,
    scope: ShortcutScope.trackList,
    intent: SelectTrackListToolIntent(ToolSelection.panSelect),
    defaultKey: SingleActivator(LogicalKeyboardKey.keyQ),
  ),
  DawShortcut(
    key: TrackListToolShortcutKeys.draw,
    scope: ShortcutScope.trackList,
    intent: SelectTrackListToolIntent(ToolSelection.draw),
    defaultKey: SingleActivator(LogicalKeyboardKey.keyD),
  ),
  DawShortcut(
    key: TrackListToolShortcutKeys.resize,
    scope: ShortcutScope.trackList,
    intent: SelectTrackListToolIntent(ToolSelection.resize),
    defaultKey: SingleActivator(LogicalKeyboardKey.keyE),
  ),
  DawShortcut(
    key: TrackListToolShortcutKeys.slice,
    scope: ShortcutScope.trackList,
    intent: SelectTrackListToolIntent(ToolSelection.slice),
    defaultKey: SingleActivator(LogicalKeyboardKey.keyC),
  ),
  DawShortcut(
    key: TrackListToolShortcutKeys.move,
    scope: ShortcutScope.trackList,
    intent: SelectTrackListToolIntent(ToolSelection.move),
    defaultKey: SingleActivator(LogicalKeyboardKey.keyM),
  ),
  DawShortcut(
    key: TrackListToolShortcutKeys.rangeSelect,
    scope: ShortcutScope.trackList,
    intent: SelectTrackListToolIntent(ToolSelection.select),
    defaultKey: SingleActivator(LogicalKeyboardKey.keyR),
  ),
  DawShortcut(
    key: TrackListToolShortcutKeys.delete,
    scope: ShortcutScope.trackList,
    intent: SelectTrackListToolIntent(ToolSelection.delete),
    defaultKey: SingleActivator(LogicalKeyboardKey.keyX),
  ),
  DawShortcut(
    key: TrackListShortcutKeys.nudgeLeft,
    scope: ShortcutScope.trackList,
    intent: NudgeClipsIntent(-1),
    defaultKey: SingleActivator(LogicalKeyboardKey.arrowLeft, shift: true),
  ),
  DawShortcut(
    key: TrackListShortcutKeys.nudgeRight,
    scope: ShortcutScope.trackList,
    intent: NudgeClipsIntent(1),
    defaultKey: SingleActivator(LogicalKeyboardKey.arrowRight, shift: true),
  ),
  DawShortcut(
    key: TrackListShortcutKeys.copyClips,
    scope: ShortcutScope.trackList,
    intent: CopyClipsIntent(),
    defaultKey: SingleActivator(LogicalKeyboardKey.keyC, control: true),
  ),
  DawShortcut(
    key: TrackListShortcutKeys.pasteClips,
    scope: ShortcutScope.trackList,
    intent: PasteClipsIntent(),
    defaultKey: SingleActivator(LogicalKeyboardKey.keyV, control: true),
  ),
  DawShortcut(
    key: TrackListShortcutKeys.duplicateClips,
    scope: ShortcutScope.trackList,
    intent: DuplicateClipsIntent(),
    defaultKey: SingleActivator(LogicalKeyboardKey.keyB, control: true),
  ),
  DawShortcut(
    key: TrackListShortcutKeys.deleteClips,
    scope: ShortcutScope.trackList,
    intent: DeleteClipsIntent(),
    defaultKey: SingleActivator(LogicalKeyboardKey.delete),
  ),
  DawShortcut(
    key: TrackListShortcutKeys.cutClips,
    scope: ShortcutScope.trackList,
    intent: CutClipsIntent(),
    defaultKey: SingleActivator(LogicalKeyboardKey.keyX, control: true),
  ),
  DawShortcut(
    key: TrackListShortcutKeys.quantizeClips,
    scope: ShortcutScope.trackList,
    intent: QuantizeClipsIntent(),
    defaultKey: SingleActivator(LogicalKeyboardKey.keyQ, control: true),
  ),
  DawShortcut(
    key: TrackListShortcutKeys.quantizeClipStarts,
    scope: ShortcutScope.trackList,
    intent: QuantizeClipStartsIntent(),
    defaultKey: SingleActivator(LogicalKeyboardKey.keyQ, alt: true),
  ),
  DawShortcut(
    key: TrackListShortcutKeys.legatoClips,
    scope: ShortcutScope.trackList,
    intent: LegatoClipsIntent(),
    defaultKey: SingleActivator(LogicalKeyboardKey.keyL, control: true),
  ),
]);
