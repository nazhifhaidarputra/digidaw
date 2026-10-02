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
]);
