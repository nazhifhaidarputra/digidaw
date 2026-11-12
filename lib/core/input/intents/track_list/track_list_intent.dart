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
    titleId: 'shortcuts-track-list-tool-pan-select',
    categoryId: 'shortcuts-category-track-list-tools',
    scope: ShortcutScope.trackList,
    intent: SelectTrackListToolIntent(ToolSelection.panSelect),
    defaultKey: SingleActivator(LogicalKeyboardKey.keyQ),
  ),
  DawShortcut(
    id: 'trackList.tool.draw',
    titleId: 'shortcuts-track-list-tool-draw',
    categoryId: 'shortcuts-category-track-list-tools',
    scope: ShortcutScope.trackList,
    intent: SelectTrackListToolIntent(ToolSelection.draw),
    defaultKey: SingleActivator(LogicalKeyboardKey.keyD),
  ),
  DawShortcut(
    id: 'trackList.tool.resize',
    titleId: 'shortcuts-track-list-tool-resize',
    categoryId: 'shortcuts-category-track-list-tools',
    scope: ShortcutScope.trackList,
    intent: SelectTrackListToolIntent(ToolSelection.resize),
    defaultKey: SingleActivator(LogicalKeyboardKey.keyE),
  ),
  DawShortcut(
    id: 'trackList.tool.slice',
    titleId: 'shortcuts-track-list-tool-slice',
    categoryId: 'shortcuts-category-track-list-tools',
    scope: ShortcutScope.trackList,
    intent: SelectTrackListToolIntent(ToolSelection.slice),
    defaultKey: SingleActivator(LogicalKeyboardKey.keyC),
  ),
  DawShortcut(
    id: 'trackList.tool.move',
    titleId: 'shortcuts-track-list-tool-move',
    categoryId: 'shortcuts-category-track-list-tools',
    scope: ShortcutScope.trackList,
    intent: SelectTrackListToolIntent(ToolSelection.move),
    defaultKey: SingleActivator(LogicalKeyboardKey.keyM),
  ),
  DawShortcut(
    id: 'trackList.tool.rangeSelect',
    titleId: 'shortcuts-track-list-tool-range-select',
    categoryId: 'shortcuts-category-track-list-tools',
    scope: ShortcutScope.trackList,
    intent: SelectTrackListToolIntent(ToolSelection.select),
    defaultKey: SingleActivator(LogicalKeyboardKey.keyR),
  ),
  DawShortcut(
    id: 'trackList.nudgeLeft',
    titleId: 'shortcuts-track-list-nudge-left',
    categoryId: 'shortcuts-category-track-list',
    scope: ShortcutScope.trackList,
    intent: NudgeClipsIntent(-1),
    defaultKey: SingleActivator(LogicalKeyboardKey.arrowLeft, shift: true),
  ),
  DawShortcut(
    id: 'trackList.nudgeRight',
    titleId: 'shortcuts-track-list-nudge-right',
    categoryId: 'shortcuts-category-track-list',
    scope: ShortcutScope.trackList,
    intent: NudgeClipsIntent(1),
    defaultKey: SingleActivator(LogicalKeyboardKey.arrowRight, shift: true),
  ),
  DawShortcut(
    id: 'trackList.copyClips',
    titleId: 'shortcuts-track-list-copy-clips',
    categoryId: 'shortcuts-category-track-list',
    scope: ShortcutScope.trackList,
    intent: CopyClipsIntent(),
    defaultKey: SingleActivator(LogicalKeyboardKey.keyC, control: true),
  ),
  DawShortcut(
    id: 'trackList.pasteClips',
    titleId: 'shortcuts-track-list-paste-clips',
    categoryId: 'shortcuts-category-track-list',
    scope: ShortcutScope.trackList,
    intent: PasteClipsIntent(),
    defaultKey: SingleActivator(LogicalKeyboardKey.keyV, control: true),
  ),
  DawShortcut(
    id: 'trackList.duplicateClips',
    titleId: 'shortcuts-track-list-duplicate-clips',
    categoryId: 'shortcuts-category-track-list',
    scope: ShortcutScope.trackList,
    intent: DuplicateClipsIntent(),
    defaultKey: SingleActivator(LogicalKeyboardKey.keyB, control: true),
  ),
  DawShortcut(
    id: 'trackList.deleteClips',
    titleId: 'shortcuts-track-list-delete-clips',
    categoryId: 'shortcuts-category-track-list',
    scope: ShortcutScope.trackList,
    intent: DeleteClipsIntent(),
    defaultKey: SingleActivator(LogicalKeyboardKey.delete),
  ),
]);
