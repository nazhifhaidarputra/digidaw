import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:karbeat/core/input/shortcut_models.dart';
import 'package:karbeat/generated/shortcuts/shortcut_keys.dart';
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
    key: PianoRollShortcutKeys.quantize,
    scope: ShortcutScope.pianoRoll,
    intent: QuantizeNotesIntent(),
    defaultKey: SingleActivator(LogicalKeyboardKey.keyQ, control: true),
  ),
  DawShortcut(
    key: PianoRollShortcutKeys.quantizeStart,
    scope: ShortcutScope.pianoRoll,
    intent: QuantizeNoteStartsIntent(),
    defaultKey: SingleActivator(LogicalKeyboardKey.keyQ, alt: true),
  ),
  DawShortcut(
    key: PianoRollShortcutKeys.legato,
    scope: ShortcutScope.pianoRoll,
    intent: LegatoNotesIntent(),
    defaultKey: SingleActivator(LogicalKeyboardKey.keyL, control: true),
  ),
  DawShortcut(
    key: PianoRollShortcutKeys.humanize,
    scope: ShortcutScope.pianoRoll,
    intent: HumanizeNotesIntent(),
    defaultKey: SingleActivator(LogicalKeyboardKey.keyH, alt: true),
  ),
  DawShortcut(
    key: PianoRollShortcutKeys.chop,
    scope: ShortcutScope.pianoRoll,
    intent: ChopNotesIntent(),
    defaultKey: SingleActivator(LogicalKeyboardKey.keyU, control: true),
  ),
  DawShortcut(
    key: PianoRollShortcutKeys.transposeUp,
    scope: ShortcutScope.pianoRoll,
    intent: TransposeNotesIntent(1),
    defaultKey: SingleActivator(LogicalKeyboardKey.arrowUp, shift: true),
  ),
  DawShortcut(
    key: PianoRollShortcutKeys.transposeDown,
    scope: ShortcutScope.pianoRoll,
    intent: TransposeNotesIntent(-1),
    defaultKey: SingleActivator(LogicalKeyboardKey.arrowDown, shift: true),
  ),
  DawShortcut(
    key: PianoRollShortcutKeys.octaveUp,
    scope: ShortcutScope.pianoRoll,
    intent: TransposeNotesIntent(12),
    defaultKey: SingleActivator(LogicalKeyboardKey.arrowUp, control: true),
  ),
  DawShortcut(
    key: PianoRollShortcutKeys.octaveDown,
    scope: ShortcutScope.pianoRoll,
    intent: TransposeNotesIntent(-12),
    defaultKey: SingleActivator(LogicalKeyboardKey.arrowDown, control: true),
  ),
  DawShortcut(
    key: PianoRollShortcutKeys.shiftLeft,
    scope: ShortcutScope.pianoRoll,
    intent: ShiftNotesIntent(-1),
    defaultKey: SingleActivator(LogicalKeyboardKey.arrowLeft, shift: true),
  ),
  DawShortcut(
    key: PianoRollShortcutKeys.shiftRight,
    scope: ShortcutScope.pianoRoll,
    intent: ShiftNotesIntent(1),
    defaultKey: SingleActivator(LogicalKeyboardKey.arrowRight, shift: true),
  ),
  DawShortcut(
    key: PianoRollShortcutKeys.copyNotes,
    scope: ShortcutScope.pianoRoll,
    intent: CopyNotesIntent(),
    defaultKey: SingleActivator(LogicalKeyboardKey.keyC, control: true),
  ),
  DawShortcut(
    key: PianoRollShortcutKeys.pasteNotes,
    scope: ShortcutScope.pianoRoll,
    intent: PasteNotesIntent(),
    defaultKey: SingleActivator(LogicalKeyboardKey.keyV, control: true),
  ),
  DawShortcut(
    key: PianoRollShortcutKeys.duplicateNotes,
    scope: ShortcutScope.pianoRoll,
    intent: DuplicateNotesIntent(),
    defaultKey: SingleActivator(LogicalKeyboardKey.keyB, control: true),
  ),
  DawShortcut(
    key: PianoRollShortcutKeys.deleteNotes,
    scope: ShortcutScope.pianoRoll,
    intent: DeleteNotesIntent(),
    defaultKey: SingleActivator(LogicalKeyboardKey.delete),
  ),
  DawShortcut(
    key: PianoRollToolShortcutKeys.grab,
    scope: ShortcutScope.pianoRoll,
    intent: SelectPianoRollToolIntent(PianoRollToolSelection.grab),
    defaultKey: SingleActivator(LogicalKeyboardKey.digit1, alt: true),
  ),
  DawShortcut(
    key: PianoRollToolShortcutKeys.draw,
    scope: ShortcutScope.pianoRoll,
    intent: SelectPianoRollToolIntent(PianoRollToolSelection.draw),
    defaultKey: SingleActivator(LogicalKeyboardKey.digit2, alt: true),
  ),
  DawShortcut(
    key: PianoRollToolShortcutKeys.delete,
    scope: ShortcutScope.pianoRoll,
    intent: SelectPianoRollToolIntent(PianoRollToolSelection.delete),
    defaultKey: SingleActivator(LogicalKeyboardKey.digit3, alt: true),
  ),
  DawShortcut(
    key: PianoRollToolShortcutKeys.select,
    scope: ShortcutScope.pianoRoll,
    intent: SelectPianoRollToolIntent(PianoRollToolSelection.select),
    defaultKey: SingleActivator(LogicalKeyboardKey.digit4, alt: true),
  ),
  DawShortcut(
    key: PianoRollToolShortcutKeys.selectRegion,
    scope: ShortcutScope.pianoRoll,
    intent: SelectPianoRollToolIntent(PianoRollToolSelection.selectRegion),
    defaultKey: SingleActivator(LogicalKeyboardKey.digit5, alt: true),
  ),
  DawShortcut(
    key: PianoRollToolShortcutKeys.slice,
    scope: ShortcutScope.pianoRoll,
    intent: SelectPianoRollToolIntent(PianoRollToolSelection.slice),
    defaultKey: SingleActivator(LogicalKeyboardKey.digit6, alt: true),
  ),
  DawShortcut(
    key: PianoRollToolShortcutKeys.pan,
    scope: ShortcutScope.pianoRoll,
    intent: SelectPianoRollToolIntent(PianoRollToolSelection.pan),
    defaultKey: SingleActivator(LogicalKeyboardKey.digit7, alt: true),
  ),
  DawShortcut(
    key: PianoRollToolShortcutKeys.zoom,
    scope: ShortcutScope.pianoRoll,
    intent: SelectPianoRollToolIntent(PianoRollToolSelection.zoom),
    defaultKey: SingleActivator(LogicalKeyboardKey.digit8, alt: true),
  ),
  DawShortcut(
    key: PianoRollToolShortcutKeys.stretch,
    scope: ShortcutScope.pianoRoll,
    intent: SelectPianoRollToolIntent(PianoRollToolSelection.stretch),
    defaultKey: SingleActivator(LogicalKeyboardKey.digit9, alt: true),
  ),
]);
