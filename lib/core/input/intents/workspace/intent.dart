import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:karbeat/core/input/intents/song_timeline/playback_intent.dart';
import 'package:karbeat/core/input/intents/workspace/export_intent.dart';
import 'package:karbeat/core/input/intents/workspace/open_midi_keyboard_intent.dart';
import 'package:karbeat/core/input/intents/workspace/save_intent.dart';
import 'package:karbeat/core/input/intents/workspace/action_history_intent.dart';
import 'package:karbeat/core/input/shortcut_models.dart';
import 'package:karbeat/generated/shortcuts/shortcut_keys.dart';

/// Opens the application settings screen.
class OpenSettingsIntent extends Intent {
  const OpenSettingsIntent();
}

/// Imports an audio file into the project's source list.
class ImportAudioIntent extends Intent {
  const ImportAudioIntent();
}

/// Cancels whatever is selected or being placed, in any view.
class CancelSelectionIntent extends Intent {
  const CancelSelectionIntent();
}

class OpenProjectIntent extends Intent {
  const OpenProjectIntent();
}

class NewProjectIntent extends Intent {
  const NewProjectIntent();
}

const workspaceShortcuts = IListConst<DawShortcut>([
  DawShortcut(
    key: TransportShortcutKeys.togglePlayback,
    intent: TogglePlayIntent(),
    defaultKey: SingleActivator(LogicalKeyboardKey.space),
  ),
  DawShortcut(
    key: TransportShortcutKeys.stopPlayback,
    intent: StopIntent(),
    defaultKey: SingleActivator(LogicalKeyboardKey.end),
  ),
  DawShortcut(
    key: TransportShortcutKeys.toggleLoop,
    intent: ToggleLoopIntent(),
    defaultKey: SingleActivator(LogicalKeyboardKey.keyL),
  ),
  DawShortcut(
    key: TransportShortcutKeys.toggleMetronome,
    intent: ToggleMetronomeIntent(),
    defaultKey: SingleActivator(LogicalKeyboardKey.keyM, control: true),
  ),
  DawShortcut(
    key: TransportShortcutKeys.recordSelectedTrack,
    intent: RecordSelectedTrackIntent(),
    defaultKey: SingleActivator(
      LogicalKeyboardKey.keyR,
      control: true,
      alt: true,
    ),
  ),
  DawShortcut(
    key: TransportShortcutKeys.stopRecording,
    intent: StopRecordingIntent(),
    defaultKey: SingleActivator(
      LogicalKeyboardKey.keyE,
      control: true,
      alt: true,
    ),
  ),
  DawShortcut(
    key: WorkspaceShortcutKeys.save,
    intent: SaveIntent(),
    defaultKey: SingleActivator(LogicalKeyboardKey.keyS, control: true),
  ),
  DawShortcut(
    key: WorkspaceShortcutKeys.undo,
    intent: UndoIntent(),
    defaultKey: SingleActivator(LogicalKeyboardKey.keyZ, control: true),
  ),
  DawShortcut(
    key: WorkspaceShortcutKeys.redo,
    intent: RedoIntent(),
    defaultKey: SingleActivator(
      LogicalKeyboardKey.keyZ,
      control: true,
      alt: true,
    ),
  ),
  DawShortcut(
    key: WorkspaceShortcutKeys.saveAs,
    intent: SaveAsIntent(),
    defaultKey: SingleActivator(
      LogicalKeyboardKey.keyS,
      control: true,
      shift: true,
    ),
  ),
  DawShortcut(
    key: WorkspaceShortcutKeys.export,
    intent: ExportIntent(),
    defaultKey: SingleActivator(
      LogicalKeyboardKey.keyE,
      control: true,
      shift: true,
    ),
  ),
  DawShortcut(
    key: WorkspaceShortcutKeys.toggleMidiKeyboard,
    intent: ToggleVirtualMidiKeyboardIntent(),
    defaultKey: SingleActivator(LogicalKeyboardKey.keyK, alt: true),
  ),
  DawShortcut(
    key: WorkspaceShortcutKeys.openSettings,
    intent: OpenSettingsIntent(),
    defaultKey: SingleActivator(LogicalKeyboardKey.f2),
  ),
  DawShortcut(
    key: WorkspaceShortcutKeys.importAudio,
    intent: ImportAudioIntent(),
    defaultKey: SingleActivator(LogicalKeyboardKey.keyI, control: true),
  ),
  DawShortcut(
    key: WorkspaceShortcutKeys.openProject,
    intent: OpenProjectIntent(),
    defaultKey: SingleActivator(LogicalKeyboardKey.keyO, control: true),
  ),
  DawShortcut(
    key: WorkspaceShortcutKeys.newProject,
    intent: NewProjectIntent(),
    defaultKey: SingleActivator(LogicalKeyboardKey.keyN, control: true),
  ),
  DawShortcut(
    key: WorkspaceShortcutKeys.cancelSelection,
    intent: CancelSelectionIntent(),
    defaultKey: SingleActivator(LogicalKeyboardKey.escape),
  ),
]);
