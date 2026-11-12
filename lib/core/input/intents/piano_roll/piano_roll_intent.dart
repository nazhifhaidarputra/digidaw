import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:karbeat/core/input/shortcut_models.dart';
import 'package:karbeat/shared/enums/global.dart';

/// Snaps note starts and ends to the draw step.
class QuantizeNotesIntent extends Intent {
  const QuantizeNotesIntent();
}

/// Snaps only note starts to the draw step.
class QuantizeNoteStartsIntent extends Intent {
  const QuantizeNoteStartsIntent();
}

/// Stretches notes to the start of the next note.
class LegatoNotesIntent extends Intent {
  const LegatoNotesIntent();
}

/// Randomizes note timing and velocity slightly.
class HumanizeNotesIntent extends Intent {
  const HumanizeNotesIntent();
}

/// Splits notes into draw-step pieces.
class ChopNotesIntent extends Intent {
  const ChopNotesIntent();
}

/// Transposes notes by [semitones].
class TransposeNotesIntent extends Intent {
  const TransposeNotesIntent(this.semitones);

  final int semitones;
}

/// Moves notes by [steps] draw steps in time.
class ShiftNotesIntent extends Intent {
  const ShiftNotesIntent(this.steps);

  final int steps;
}

/// Copies the selected notes to the note clipboard.
class CopyNotesIntent extends Intent {
  const CopyNotesIntent();
}

/// Pastes the note clipboard after the selection, snapped up to the draw step.
class PasteNotesIntent extends Intent {
  const PasteNotesIntent();
}

/// Duplicates the selected notes after themselves, without touching the
/// clipboard.
class DuplicateNotesIntent extends Intent {
  const DuplicateNotesIntent();
}

/// Deletes the selected notes and clears the selection.
class DeleteNotesIntent extends Intent {
  const DeleteNotesIntent();
}

/// Switches the piano-roll tool.
class SelectPianoRollToolIntent extends Intent {
  const SelectPianoRollToolIntent(this.tool);

  final PianoRollToolSelection tool;
}

/// Piano-roll shortcuts. They are active only in the piano roll view.
const pianoRollShortcuts = IListConst<DawShortcut>([
  DawShortcut(
    id: 'pianoRoll.quantize',
    titleId: 'shortcuts-piano-roll-quantize',
    categoryId: 'shortcuts-category-piano-roll',
    scope: ShortcutScope.pianoRoll,
    intent: QuantizeNotesIntent(),
    defaultKey: SingleActivator(LogicalKeyboardKey.keyQ, control: true),
  ),
  DawShortcut(
    id: 'pianoRoll.quantizeStart',
    titleId: 'shortcuts-piano-roll-quantize-start',
    categoryId: 'shortcuts-category-piano-roll',
    scope: ShortcutScope.pianoRoll,
    intent: QuantizeNoteStartsIntent(),
    defaultKey: SingleActivator(LogicalKeyboardKey.keyQ, alt: true),
  ),
  DawShortcut(
    id: 'pianoRoll.legato',
    titleId: 'shortcuts-piano-roll-legato',
    categoryId: 'shortcuts-category-piano-roll',
    scope: ShortcutScope.pianoRoll,
    intent: LegatoNotesIntent(),
    defaultKey: SingleActivator(LogicalKeyboardKey.keyL, control: true),
  ),
  DawShortcut(
    id: 'pianoRoll.humanize',
    titleId: 'shortcuts-piano-roll-humanize',
    categoryId: 'shortcuts-category-piano-roll',
    scope: ShortcutScope.pianoRoll,
    intent: HumanizeNotesIntent(),
    defaultKey: SingleActivator(LogicalKeyboardKey.keyH, alt: true),
  ),
  DawShortcut(
    id: 'pianoRoll.chop',
    titleId: 'shortcuts-piano-roll-chop',
    categoryId: 'shortcuts-category-piano-roll',
    scope: ShortcutScope.pianoRoll,
    intent: ChopNotesIntent(),
    defaultKey: SingleActivator(LogicalKeyboardKey.keyU, control: true),
  ),
  DawShortcut(
    id: 'pianoRoll.transposeUp',
    titleId: 'shortcuts-piano-roll-transpose-up',
    categoryId: 'shortcuts-category-piano-roll',
    scope: ShortcutScope.pianoRoll,
    intent: TransposeNotesIntent(1),
    defaultKey: SingleActivator(LogicalKeyboardKey.arrowUp, shift: true),
  ),
  DawShortcut(
    id: 'pianoRoll.transposeDown',
    titleId: 'shortcuts-piano-roll-transpose-down',
    categoryId: 'shortcuts-category-piano-roll',
    scope: ShortcutScope.pianoRoll,
    intent: TransposeNotesIntent(-1),
    defaultKey: SingleActivator(LogicalKeyboardKey.arrowDown, shift: true),
  ),
  DawShortcut(
    id: 'pianoRoll.octaveUp',
    titleId: 'shortcuts-piano-roll-octave-up',
    categoryId: 'shortcuts-category-piano-roll',
    scope: ShortcutScope.pianoRoll,
    intent: TransposeNotesIntent(12),
    defaultKey: SingleActivator(LogicalKeyboardKey.arrowUp, control: true),
  ),
  DawShortcut(
    id: 'pianoRoll.octaveDown',
    titleId: 'shortcuts-piano-roll-octave-down',
    categoryId: 'shortcuts-category-piano-roll',
    scope: ShortcutScope.pianoRoll,
    intent: TransposeNotesIntent(-12),
    defaultKey: SingleActivator(LogicalKeyboardKey.arrowDown, control: true),
  ),
  DawShortcut(
    id: 'pianoRoll.shiftLeft',
    titleId: 'shortcuts-piano-roll-shift-left',
    categoryId: 'shortcuts-category-piano-roll',
    scope: ShortcutScope.pianoRoll,
    intent: ShiftNotesIntent(-1),
    defaultKey: SingleActivator(LogicalKeyboardKey.arrowLeft, shift: true),
  ),
  DawShortcut(
    id: 'pianoRoll.shiftRight',
    titleId: 'shortcuts-piano-roll-shift-right',
    categoryId: 'shortcuts-category-piano-roll',
    scope: ShortcutScope.pianoRoll,
    intent: ShiftNotesIntent(1),
    defaultKey: SingleActivator(LogicalKeyboardKey.arrowRight, shift: true),
  ),
  DawShortcut(
    id: 'pianoRoll.copyNotes',
    titleId: 'shortcuts-piano-roll-copy-notes',
    categoryId: 'shortcuts-category-piano-roll',
    scope: ShortcutScope.pianoRoll,
    intent: CopyNotesIntent(),
    defaultKey: SingleActivator(LogicalKeyboardKey.keyC, control: true),
  ),
  DawShortcut(
    id: 'pianoRoll.pasteNotes',
    titleId: 'shortcuts-piano-roll-paste-notes',
    categoryId: 'shortcuts-category-piano-roll',
    scope: ShortcutScope.pianoRoll,
    intent: PasteNotesIntent(),
    defaultKey: SingleActivator(LogicalKeyboardKey.keyV, control: true),
  ),
  DawShortcut(
    id: 'pianoRoll.duplicateNotes',
    titleId: 'shortcuts-piano-roll-duplicate-notes',
    categoryId: 'shortcuts-category-piano-roll',
    scope: ShortcutScope.pianoRoll,
    intent: DuplicateNotesIntent(),
    defaultKey: SingleActivator(LogicalKeyboardKey.keyB, control: true),
  ),
  DawShortcut(
    id: 'pianoRoll.deleteNotes',
    titleId: 'shortcuts-piano-roll-delete-notes',
    categoryId: 'shortcuts-category-piano-roll',
    scope: ShortcutScope.pianoRoll,
    intent: DeleteNotesIntent(),
    defaultKey: SingleActivator(LogicalKeyboardKey.delete),
  ),
  DawShortcut(
    id: 'pianoRoll.tool.grab',
    titleId: 'shortcuts-piano-roll-tool-grab',
    categoryId: 'shortcuts-category-piano-roll-tools',
    scope: ShortcutScope.pianoRoll,
    intent: SelectPianoRollToolIntent(PianoRollToolSelection.grab),
    defaultKey: SingleActivator(LogicalKeyboardKey.digit1, alt: true),
  ),
  DawShortcut(
    id: 'pianoRoll.tool.draw',
    titleId: 'shortcuts-piano-roll-tool-draw',
    categoryId: 'shortcuts-category-piano-roll-tools',
    scope: ShortcutScope.pianoRoll,
    intent: SelectPianoRollToolIntent(PianoRollToolSelection.draw),
    defaultKey: SingleActivator(LogicalKeyboardKey.digit2, alt: true),
  ),
  DawShortcut(
    id: 'pianoRoll.tool.delete',
    titleId: 'shortcuts-piano-roll-tool-delete',
    categoryId: 'shortcuts-category-piano-roll-tools',
    scope: ShortcutScope.pianoRoll,
    intent: SelectPianoRollToolIntent(PianoRollToolSelection.delete),
    defaultKey: SingleActivator(LogicalKeyboardKey.digit3, alt: true),
  ),
  DawShortcut(
    id: 'pianoRoll.tool.select',
    titleId: 'shortcuts-piano-roll-tool-select',
    categoryId: 'shortcuts-category-piano-roll-tools',
    scope: ShortcutScope.pianoRoll,
    intent: SelectPianoRollToolIntent(PianoRollToolSelection.select),
    defaultKey: SingleActivator(LogicalKeyboardKey.digit4, alt: true),
  ),
  DawShortcut(
    id: 'pianoRoll.tool.selectRegion',
    titleId: 'shortcuts-piano-roll-tool-select-region',
    categoryId: 'shortcuts-category-piano-roll-tools',
    scope: ShortcutScope.pianoRoll,
    intent: SelectPianoRollToolIntent(PianoRollToolSelection.selectRegion),
    defaultKey: SingleActivator(LogicalKeyboardKey.digit5, alt: true),
  ),
  DawShortcut(
    id: 'pianoRoll.tool.slice',
    titleId: 'shortcuts-piano-roll-tool-slice',
    categoryId: 'shortcuts-category-piano-roll-tools',
    scope: ShortcutScope.pianoRoll,
    intent: SelectPianoRollToolIntent(PianoRollToolSelection.slice),
    defaultKey: SingleActivator(LogicalKeyboardKey.digit6, alt: true),
  ),
  DawShortcut(
    id: 'pianoRoll.tool.pan',
    titleId: 'shortcuts-piano-roll-tool-pan',
    categoryId: 'shortcuts-category-piano-roll-tools',
    scope: ShortcutScope.pianoRoll,
    intent: SelectPianoRollToolIntent(PianoRollToolSelection.pan),
    defaultKey: SingleActivator(LogicalKeyboardKey.digit7, alt: true),
  ),
  DawShortcut(
    id: 'pianoRoll.tool.zoom',
    titleId: 'shortcuts-piano-roll-tool-zoom',
    categoryId: 'shortcuts-category-piano-roll-tools',
    scope: ShortcutScope.pianoRoll,
    intent: SelectPianoRollToolIntent(PianoRollToolSelection.zoom),
    defaultKey: SingleActivator(LogicalKeyboardKey.digit8, alt: true),
  ),
  DawShortcut(
    id: 'pianoRoll.tool.stretch',
    titleId: 'shortcuts-piano-roll-tool-stretch',
    categoryId: 'shortcuts-category-piano-roll-tools',
    scope: ShortcutScope.pianoRoll,
    intent: SelectPianoRollToolIntent(PianoRollToolSelection.stretch),
    defaultKey: SingleActivator(LogicalKeyboardKey.digit9, alt: true),
  ),
]);
