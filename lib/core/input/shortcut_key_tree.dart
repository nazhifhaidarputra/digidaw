/// A group of shortcut commands. Its commands and child modules take their
/// keys from the path of names leading to them.
///
/// The command `delete` in the module `tool` inside `trackList` gets:
///
/// * the stored id `trackList.tool.delete`,
/// * the title message `shortcuts-track-list-tool-delete`,
/// * the category message `shortcuts-category-track-list-tool`,
/// * the constant `TrackListToolShortcutKeys.delete`.
///
/// Keep this file free of Flutter imports: the generator runs on the Dart VM.
class ShortcutModule {
  const ShortcutModule(
    this.name, {
    this.commands = const [],
    this.modules = const [],
  });

  /// Name in lowerCamelCase.
  final String name;

  /// Command names in lowerCamelCase. Renaming one changes its stored id and
  /// drops the user's binding for it.
  final List<String> commands;

  final List<ShortcutModule> modules;
}

/// Every shortcut module, the source of
/// `lib/generated/shortcuts/shortcut_keys.dart`. After editing, regenerate
/// with `dart run lib/tool/generate_shortcut_keys.dart`.
const shortcutModules = <ShortcutModule>[
  ShortcutModule(
    'transport',
    commands: [
      'togglePlayback',
      'stopPlayback',
      'toggleLoop',
      'toggleMetronome',
      'recordSelectedTrack',
      'stopRecording',
    ],
  ),
  ShortcutModule(
    'workspace',
    commands: [
      'save',
      'undo',
      'redo',
      'saveAs',
      'export',
      'toggleMidiKeyboard',
      'openSettings',
      'importAudio',
      'openProject',
      'newProject',
      'cancelSelection',
    ],
  ),
  ShortcutModule(
    'trackList',
    commands: [
      'nudgeLeft',
      'nudgeRight',
      'copyClips',
      'pasteClips',
      'duplicateClips',
      'deleteClips',
    ],
    modules: [
      ShortcutModule(
        'tool',
        commands: [
          'panSelect',
          'draw',
          'resize',
          'slice',
          'move',
          'rangeSelect',
          'delete',
        ],
      ),
    ],
  ),
  ShortcutModule(
    'pianoRoll',
    commands: [
      'quantize',
      'quantizeStart',
      'legato',
      'humanize',
      'chop',
      'transposeUp',
      'transposeDown',
      'octaveUp',
      'octaveDown',
      'shiftLeft',
      'shiftRight',
      'copyNotes',
      'pasteNotes',
      'duplicateNotes',
      'deleteNotes',
    ],
    modules: [
      ShortcutModule(
        'tool',
        commands: [
          'grab',
          'draw',
          'delete',
          'select',
          'selectRegion',
          'slice',
          'pan',
          'zoom',
          'stretch',
        ],
      ),
    ],
  ),
];
