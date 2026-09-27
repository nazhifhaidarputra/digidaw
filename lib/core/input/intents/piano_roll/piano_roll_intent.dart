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

/// Switches the piano-roll tool.
class SelectPianoRollToolIntent extends Intent {
  const SelectPianoRollToolIntent(this.tool);

  final PianoRollToolSelection tool;
}

/// Piano-roll shortcuts. They act only while the piano roll has focus.
const pianoRollShortcuts = IListConst<DawShortcut>([
  DawShortcut(
    id: 'pianoRoll.quantize',
    title: 'Quantize',
    category: 'Piano Roll',
    intent: QuantizeNotesIntent(),
    defaultKey: SingleActivator(LogicalKeyboardKey.keyQ, control: true),
  ),
  DawShortcut(
    id: 'pianoRoll.quantizeStart',
    title: 'Quantize Start Times',
    category: 'Piano Roll',
    intent: QuantizeNoteStartsIntent(),
    defaultKey: SingleActivator(LogicalKeyboardKey.keyQ, alt: true),
  ),
  DawShortcut(
    id: 'pianoRoll.legato',
    title: 'Legato',
    category: 'Piano Roll',
    intent: LegatoNotesIntent(),
    defaultKey: SingleActivator(LogicalKeyboardKey.keyL, control: true),
  ),
  DawShortcut(
    id: 'pianoRoll.humanize',
    title: 'Humanize',
    category: 'Piano Roll',
    intent: HumanizeNotesIntent(),
    defaultKey: SingleActivator(LogicalKeyboardKey.keyH, alt: true),
  ),
  DawShortcut(
    id: 'pianoRoll.chop',
    title: 'Chop',
    category: 'Piano Roll',
    intent: ChopNotesIntent(),
    defaultKey: SingleActivator(LogicalKeyboardKey.keyU, control: true),
  ),
  DawShortcut(
    id: 'pianoRoll.transposeUp',
    title: 'Transpose Up a Semitone',
    category: 'Piano Roll',
    intent: TransposeNotesIntent(1),
    defaultKey: SingleActivator(LogicalKeyboardKey.arrowUp, shift: true),
  ),
  DawShortcut(
    id: 'pianoRoll.transposeDown',
    title: 'Transpose Down a Semitone',
    category: 'Piano Roll',
    intent: TransposeNotesIntent(-1),
    defaultKey: SingleActivator(LogicalKeyboardKey.arrowDown, shift: true),
  ),
  DawShortcut(
    id: 'pianoRoll.octaveUp',
    title: 'Transpose Up an Octave',
    category: 'Piano Roll',
    intent: TransposeNotesIntent(12),
    defaultKey: SingleActivator(LogicalKeyboardKey.arrowUp, control: true),
  ),
  DawShortcut(
    id: 'pianoRoll.octaveDown',
    title: 'Transpose Down an Octave',
    category: 'Piano Roll',
    intent: TransposeNotesIntent(-12),
    defaultKey: SingleActivator(LogicalKeyboardKey.arrowDown, control: true),
  ),
  DawShortcut(
    id: 'pianoRoll.shiftLeft',
    title: 'Shift Left One Step',
    category: 'Piano Roll',
    intent: ShiftNotesIntent(-1),
    defaultKey: SingleActivator(LogicalKeyboardKey.arrowLeft, shift: true),
  ),
  DawShortcut(
    id: 'pianoRoll.shiftRight',
    title: 'Shift Right One Step',
    category: 'Piano Roll',
    intent: ShiftNotesIntent(1),
    defaultKey: SingleActivator(LogicalKeyboardKey.arrowRight, shift: true),
  ),
  DawShortcut(
    id: 'pianoRoll.tool.grab',
    title: 'Grab Tool',
    category: 'Piano Roll Tools',
    intent: SelectPianoRollToolIntent(PianoRollToolSelection.grab),
    defaultKey: SingleActivator(LogicalKeyboardKey.digit1, alt: true),
  ),
  DawShortcut(
    id: 'pianoRoll.tool.draw',
    title: 'Draw Tool',
    category: 'Piano Roll Tools',
    intent: SelectPianoRollToolIntent(PianoRollToolSelection.draw),
    defaultKey: SingleActivator(LogicalKeyboardKey.digit2, alt: true),
  ),
  DawShortcut(
    id: 'pianoRoll.tool.delete',
    title: 'Delete Tool',
    category: 'Piano Roll Tools',
    intent: SelectPianoRollToolIntent(PianoRollToolSelection.delete),
    defaultKey: SingleActivator(LogicalKeyboardKey.digit3, alt: true),
  ),
  DawShortcut(
    id: 'pianoRoll.tool.select',
    title: 'Select Tool',
    category: 'Piano Roll Tools',
    intent: SelectPianoRollToolIntent(PianoRollToolSelection.select),
    defaultKey: SingleActivator(LogicalKeyboardKey.digit4, alt: true),
  ),
  DawShortcut(
    id: 'pianoRoll.tool.selectRegion',
    title: 'Select Region Tool',
    category: 'Piano Roll Tools',
    intent: SelectPianoRollToolIntent(PianoRollToolSelection.selectRegion),
    defaultKey: SingleActivator(LogicalKeyboardKey.digit5, alt: true),
  ),
  DawShortcut(
    id: 'pianoRoll.tool.slice',
    title: 'Slice Tool',
    category: 'Piano Roll Tools',
    intent: SelectPianoRollToolIntent(PianoRollToolSelection.slice),
    defaultKey: SingleActivator(LogicalKeyboardKey.digit6, alt: true),
  ),
  DawShortcut(
    id: 'pianoRoll.tool.pan',
    title: 'Pan Tool',
    category: 'Piano Roll Tools',
    intent: SelectPianoRollToolIntent(PianoRollToolSelection.pan),
    defaultKey: SingleActivator(LogicalKeyboardKey.digit7, alt: true),
  ),
  DawShortcut(
    id: 'pianoRoll.tool.zoom',
    title: 'Zoom Tool',
    category: 'Piano Roll Tools',
    intent: SelectPianoRollToolIntent(PianoRollToolSelection.zoom),
    defaultKey: SingleActivator(LogicalKeyboardKey.digit8, alt: true),
  ),
]);
