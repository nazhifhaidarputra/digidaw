import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:karbeat/core/input/intents/song_timeline/playback_intent.dart';
import 'package:karbeat/core/input/intents/workspace/export_intent.dart';
import 'package:karbeat/core/input/intents/workspace/open_midi_keyboard_intent.dart';
import 'package:karbeat/core/input/intents/workspace/save_intent.dart';
import 'package:karbeat/core/input/intents/workspace/action_history_intent.dart';
import 'package:karbeat/core/input/shortcut_models.dart';

const workspaceShortcuts = IListConst<DawShortcut>([
  DawShortcut(
    id: "transport.togglePlayback",
    title: "Play/Pause",
    category: "Transport",
    intent: TogglePlayIntent(),
    defaultKey: SingleActivator(LogicalKeyboardKey.space),
  ),
  DawShortcut(
    id: "transport.stopPlayback",
    title: "Stop",
    category: "Transport",
    intent: StopIntent(),
    defaultKey: SingleActivator(LogicalKeyboardKey.end),
  ),
  DawShortcut(
    id: "transport.toggleLoop",
    title: "Toggle Loop",
    category: "Transport",
    intent: ToggleLoopIntent(),
    defaultKey: SingleActivator(LogicalKeyboardKey.keyL),
  ),
  DawShortcut(
    id: 'transport.toggleMetronome',
    title: 'Toggle Metronome',
    category: 'Transport',
    intent: ToggleMetronomeIntent(),
    defaultKey: SingleActivator(LogicalKeyboardKey.keyM),
  ),
  DawShortcut(
    id: "workspace.save",
    title: "Save Project",
    category: "Workspace",
    intent: SaveIntent(),
    defaultKey: SingleActivator(LogicalKeyboardKey.keyS, control: true),
  ),
  DawShortcut(
    id: "workspace.undo",
    title: "Undo",
    category: "Workspace",
    intent: UndoIntent(),
    defaultKey: SingleActivator(LogicalKeyboardKey.keyZ, control: true),
  ),
  DawShortcut(
    id: "workspace.redo",
    title: "Redo",
    category: "Workspace",
    intent: RedoIntent(),
    defaultKey: SingleActivator(
      LogicalKeyboardKey.keyZ,
      control: true,
      alt: true,
    ),
  ),
  DawShortcut(
    id: "workspace.saveAs",
    title: "Save As",
    category: "Workspace",
    intent: SaveAsIntent(),
    defaultKey: SingleActivator(
      LogicalKeyboardKey.keyS,
      control: true,
      shift: true,
    ),
  ),
  DawShortcut(
    id: "workspace.export",
    title: "Export",
    category: "Workspace",
    intent: ExportIntent(),
    defaultKey: SingleActivator(
      LogicalKeyboardKey.keyE,
      control: true,
      shift: true,
    ),
  ),
  DawShortcut(
    id: 'workspace.toggleMidiKeyboard',
    title: 'Toggle Virtual MIDI Keyboard',
    category: 'Workspace',
    intent: ToggleVirtualMidiKeyboardIntent(),
    defaultKey: SingleActivator(LogicalKeyboardKey.keyK, alt: true),
  ),
]);
