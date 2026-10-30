import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:karbeat/core/input/intents/song_timeline/playback_intent.dart';
import 'package:karbeat/core/input/intents/workspace/export_intent.dart';
import 'package:karbeat/core/input/intents/workspace/open_midi_keyboard_intent.dart';
import 'package:karbeat/core/input/intents/workspace/save_intent.dart';
import 'package:karbeat/core/input/intents/workspace/action_history_intent.dart';
import 'package:karbeat/core/input/shortcut_models.dart';

/// Opens the application settings screen.
class OpenSettingsIntent extends Intent {
  const OpenSettingsIntent();
}

/// Imports an audio file into the project's source list.
class ImportAudioIntent extends Intent {
  const ImportAudioIntent();
}

class OpenProjectIntent extends Intent {
  const OpenProjectIntent();
}

class NewProjectIntent extends Intent {
  const NewProjectIntent();
}

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
    defaultKey: SingleActivator(LogicalKeyboardKey.keyM, control: true),
  ),
  DawShortcut(
    id: 'transport.recordSelectedTrack',
    title: 'Record Selected Track',
    category: 'Transport',
    intent: RecordSelectedTrackIntent(),
    defaultKey: SingleActivator(
      LogicalKeyboardKey.keyR,
      control: true,
      alt: true,
    ),
  ),
  DawShortcut(
    id: 'transport.stopRecording',
    title: 'Stop Recording',
    category: 'Transport',
    intent: StopRecordingIntent(),
    defaultKey: SingleActivator(
      LogicalKeyboardKey.keyE,
      control: true,
      alt: true,
    ),
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
  DawShortcut(
    id: 'workspace.openSettings',
    title: 'Open Settings',
    category: 'Workspace',
    intent: OpenSettingsIntent(),
    defaultKey: SingleActivator(LogicalKeyboardKey.f2),
  ),
  DawShortcut(
    id: 'workspace.importAudio',
    title: 'Import Audio',
    category: 'Workspace',
    intent: ImportAudioIntent(),
    defaultKey: SingleActivator(LogicalKeyboardKey.keyI, control: true),
  ),
  DawShortcut(
    id: 'workspace.openProject',
    title: "Open Project",
    category: 'Workspace',
    intent: OpenProjectIntent(),
    defaultKey: SingleActivator(LogicalKeyboardKey.keyO, control: true),
  ),
  DawShortcut(
    id: 'workspace.newProject',
    title: "New Empty Project",
    category: 'Workspace',
    intent: NewProjectIntent(),
    defaultKey: SingleActivator(LogicalKeyboardKey.keyN, control: true),
  ),
]);
