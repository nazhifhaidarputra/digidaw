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
    id: 'transport.togglePlayback',
    titleId: 'shortcuts-transport-toggle-playback',
    categoryId: 'shortcuts-category-transport',
    intent: TogglePlayIntent(),
    defaultKey: SingleActivator(LogicalKeyboardKey.space),
  ),
  DawShortcut(
    id: 'transport.stopPlayback',
    titleId: 'shortcuts-transport-stop-playback',
    categoryId: 'shortcuts-category-transport',
    intent: StopIntent(),
    defaultKey: SingleActivator(LogicalKeyboardKey.end),
  ),
  DawShortcut(
    id: 'transport.toggleLoop',
    titleId: 'shortcuts-transport-toggle-loop',
    categoryId: 'shortcuts-category-transport',
    intent: ToggleLoopIntent(),
    defaultKey: SingleActivator(LogicalKeyboardKey.keyL),
  ),
  DawShortcut(
    id: 'transport.toggleMetronome',
    titleId: 'shortcuts-transport-toggle-metronome',
    categoryId: 'shortcuts-category-transport',
    intent: ToggleMetronomeIntent(),
    defaultKey: SingleActivator(LogicalKeyboardKey.keyM, control: true),
  ),
  DawShortcut(
    id: 'transport.recordSelectedTrack',
    titleId: 'shortcuts-transport-record-selected-track',
    categoryId: 'shortcuts-category-transport',
    intent: RecordSelectedTrackIntent(),
    defaultKey: SingleActivator(
      LogicalKeyboardKey.keyR,
      control: true,
      alt: true,
    ),
  ),
  DawShortcut(
    id: 'transport.stopRecording',
    titleId: 'shortcuts-transport-stop-recording',
    categoryId: 'shortcuts-category-transport',
    intent: StopRecordingIntent(),
    defaultKey: SingleActivator(
      LogicalKeyboardKey.keyE,
      control: true,
      alt: true,
    ),
  ),
  DawShortcut(
    id: 'workspace.save',
    titleId: 'shortcuts-workspace-save',
    categoryId: 'shortcuts-category-workspace',
    intent: SaveIntent(),
    defaultKey: SingleActivator(LogicalKeyboardKey.keyS, control: true),
  ),
  DawShortcut(
    id: 'workspace.undo',
    titleId: 'shortcuts-workspace-undo',
    categoryId: 'shortcuts-category-workspace',
    intent: UndoIntent(),
    defaultKey: SingleActivator(LogicalKeyboardKey.keyZ, control: true),
  ),
  DawShortcut(
    id: 'workspace.redo',
    titleId: 'shortcuts-workspace-redo',
    categoryId: 'shortcuts-category-workspace',
    intent: RedoIntent(),
    defaultKey: SingleActivator(
      LogicalKeyboardKey.keyZ,
      control: true,
      alt: true,
    ),
  ),
  DawShortcut(
    id: 'workspace.saveAs',
    titleId: 'shortcuts-workspace-save-as',
    categoryId: 'shortcuts-category-workspace',
    intent: SaveAsIntent(),
    defaultKey: SingleActivator(
      LogicalKeyboardKey.keyS,
      control: true,
      shift: true,
    ),
  ),
  DawShortcut(
    id: 'workspace.export',
    titleId: 'shortcuts-workspace-export',
    categoryId: 'shortcuts-category-workspace',
    intent: ExportIntent(),
    defaultKey: SingleActivator(
      LogicalKeyboardKey.keyE,
      control: true,
      shift: true,
    ),
  ),
  DawShortcut(
    id: 'workspace.toggleMidiKeyboard',
    titleId: 'shortcuts-workspace-toggle-midi-keyboard',
    categoryId: 'shortcuts-category-workspace',
    intent: ToggleVirtualMidiKeyboardIntent(),
    defaultKey: SingleActivator(LogicalKeyboardKey.keyK, alt: true),
  ),
  DawShortcut(
    id: 'workspace.openSettings',
    titleId: 'shortcuts-workspace-open-settings',
    categoryId: 'shortcuts-category-workspace',
    intent: OpenSettingsIntent(),
    defaultKey: SingleActivator(LogicalKeyboardKey.f2),
  ),
  DawShortcut(
    id: 'workspace.importAudio',
    titleId: 'shortcuts-workspace-import-audio',
    categoryId: 'shortcuts-category-workspace',
    intent: ImportAudioIntent(),
    defaultKey: SingleActivator(LogicalKeyboardKey.keyI, control: true),
  ),
  DawShortcut(
    id: 'workspace.openProject',
    titleId: 'shortcuts-workspace-open-project',
    categoryId: 'shortcuts-category-workspace',
    intent: OpenProjectIntent(),
    defaultKey: SingleActivator(LogicalKeyboardKey.keyO, control: true),
  ),
  DawShortcut(
    id: 'workspace.newProject',
    titleId: 'shortcuts-workspace-new-project',
    categoryId: 'shortcuts-category-workspace',
    intent: NewProjectIntent(),
    defaultKey: SingleActivator(LogicalKeyboardKey.keyN, control: true),
  ),
  DawShortcut(
    id: 'workspace.cancelSelection',
    titleId: 'shortcuts-workspace-cancel-selection',
    categoryId: 'shortcuts-category-workspace',
    intent: CancelSelectionIntent(),
    defaultKey: SingleActivator(LogicalKeyboardKey.escape),
  ),
]);
