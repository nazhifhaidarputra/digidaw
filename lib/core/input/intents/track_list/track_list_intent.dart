import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:karbeat/core/input/shortcut_models.dart';
import 'package:karbeat/shared/enums/global.dart';

/// Switches the track-list tool.
class SelectTrackListToolIntent extends Intent {
  const SelectTrackListToolIntent(this.tool);

  final ToolSelection tool;
}

/// Moves the selected clips by [steps] move steps in time.
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

/// Track-list shortcuts. They are active only in the track list view.
const trackListShortcuts = IListConst<DawShortcut>([
  DawShortcut(
    id: 'trackList.tool.panSelect',
    title: 'Pan/Select Tool',
    category: 'Track List Tools',
    scope: ShortcutScope.trackList,
    intent: SelectTrackListToolIntent(ToolSelection.panSelect),
    defaultKey: SingleActivator(LogicalKeyboardKey.keyQ),
  ),
  DawShortcut(
    id: 'trackList.tool.draw',
    title: 'Draw Tool',
    category: 'Track List Tools',
    scope: ShortcutScope.trackList,
    intent: SelectTrackListToolIntent(ToolSelection.draw),
    defaultKey: SingleActivator(LogicalKeyboardKey.keyD),
  ),
  DawShortcut(
    id: 'trackList.tool.resize',
    title: 'Resize Tool',
    category: 'Track List Tools',
    scope: ShortcutScope.trackList,
    intent: SelectTrackListToolIntent(ToolSelection.resize),
    defaultKey: SingleActivator(LogicalKeyboardKey.keyE),
  ),
  DawShortcut(
    id: 'trackList.tool.slice',
    title: 'Slice Tool',
    category: 'Track List Tools',
    scope: ShortcutScope.trackList,
    intent: SelectTrackListToolIntent(ToolSelection.slice),
    defaultKey: SingleActivator(LogicalKeyboardKey.keyC),
  ),
  DawShortcut(
    id: 'trackList.tool.move',
    title: 'Move Tool',
    category: 'Track List Tools',
    scope: ShortcutScope.trackList,
    intent: SelectTrackListToolIntent(ToolSelection.move),
    defaultKey: SingleActivator(LogicalKeyboardKey.keyM),
  ),
  DawShortcut(
    id: 'trackList.tool.rangeSelect',
    title: 'Range Select Tool',
    category: 'Track List Tools',
    scope: ShortcutScope.trackList,
    intent: SelectTrackListToolIntent(ToolSelection.select),
    defaultKey: SingleActivator(LogicalKeyboardKey.keyR),
  ),
  DawShortcut(
    id: 'trackList.nudgeLeft',
    title: 'Move Clips Left One Step',
    category: 'Track List',
    scope: ShortcutScope.trackList,
    intent: NudgeClipsIntent(-1),
    defaultKey: SingleActivator(LogicalKeyboardKey.arrowLeft, shift: true),
  ),
  DawShortcut(
    id: 'trackList.nudgeRight',
    title: 'Move Clips Right One Step',
    category: 'Track List',
    scope: ShortcutScope.trackList,
    intent: NudgeClipsIntent(1),
    defaultKey: SingleActivator(LogicalKeyboardKey.arrowRight, shift: true),
  ),
  DawShortcut(
    id: 'trackList.copyClips',
    title: 'Copy Clips',
    category: 'Track List',
    scope: ShortcutScope.trackList,
    intent: CopyClipsIntent(),
    defaultKey: SingleActivator(LogicalKeyboardKey.keyC, control: true),
  ),
  DawShortcut(
    id: 'trackList.pasteClips',
    title: 'Paste Clips',
    category: 'Track List',
    scope: ShortcutScope.trackList,
    intent: PasteClipsIntent(),
    defaultKey: SingleActivator(LogicalKeyboardKey.keyV, control: true),
  ),
  DawShortcut(
    id: 'trackList.duplicateClips',
    title: 'Duplicate Clips',
    category: 'Track List',
    scope: ShortcutScope.trackList,
    intent: DuplicateClipsIntent(),
    defaultKey: SingleActivator(LogicalKeyboardKey.keyB, control: true),
  ),
  DawShortcut(
    id: 'trackList.deleteClips',
    title: 'Delete Clips',
    category: 'Track List',
    scope: ShortcutScope.trackList,
    intent: DeleteClipsIntent(),
    defaultKey: SingleActivator(LogicalKeyboardKey.delete),
  ),
]);
