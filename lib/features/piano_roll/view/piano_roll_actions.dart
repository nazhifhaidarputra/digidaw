import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/piano_roll_state.dart';
import 'package:karbeat/core/input/intents/piano_roll/piano_roll_intent.dart';
import 'package:karbeat/core/widgets/context_menu.dart';
import 'package:karbeat/features/piano_roll/view/note_properties_dialog.dart';

/// Note actions for the piano roll's context menus and toolbar menu. They act
/// on the selected notes, or on the whole pattern when nothing is selected.
List<DawContextAction> pianoRollNoteActions({
  required BuildContext context,
  required WidgetRef ref,
}) {
  final notifier = ref.read(pianoRollProvider.notifier);
  final state = ref.read(pianoRollProvider);
  final patternId = state.editingPatternId;
  final selection = state.selectedNoteIds.toList();
  final hasSelection = selection.isNotEmpty;

  return [
    DawContextAction(
      title: 'Quantize',
      icon: Icons.grid_on,
      onTap: notifier.quantizeNotes,
    ),
    DawContextAction(
      title: 'Quantize start times',
      icon: Icons.align_horizontal_left,
      onTap: notifier.quantizeNoteStarts,
    ),
    DawContextAction(
      title: 'Legato',
      icon: Icons.linear_scale,
      onTap: notifier.legatoNotes,
    ),
    DawContextAction(
      title: 'Humanize',
      icon: Icons.blur_on,
      onTap: notifier.humanizeNotes,
    ),
    DawContextAction(
      title: 'Chop into steps',
      icon: Icons.content_cut,
      onTap: notifier.chopNotes,
    ),
    DawContextAction.submenu(
      title: 'Transpose',
      icon: Icons.swap_vert,
      children: [
        DawContextAction(
          title: 'Up a semitone',
          icon: Icons.keyboard_arrow_up,
          onTap: () => notifier.transposeNotes(1),
        ),
        DawContextAction(
          title: 'Down a semitone',
          icon: Icons.keyboard_arrow_down,
          onTap: () => notifier.transposeNotes(-1),
        ),
        DawContextAction(
          title: 'Up an octave',
          icon: Icons.keyboard_double_arrow_up,
          onTap: () => notifier.transposeNotes(12),
        ),
        DawContextAction(
          title: 'Down an octave',
          icon: Icons.keyboard_double_arrow_down,
          onTap: () => notifier.transposeNotes(-12),
        ),
      ],
    ),
    DawContextAction.submenu(
      title: 'Shift in time',
      icon: Icons.swap_horiz,
      children: [
        DawContextAction(
          title: 'Left one step',
          icon: Icons.keyboard_arrow_left,
          onTap: () => notifier.shiftNotes(-1),
        ),
        DawContextAction(
          title: 'Right one step',
          icon: Icons.keyboard_arrow_right,
          onTap: () => notifier.shiftNotes(1),
        ),
      ],
    ),
    DawContextAction(
      title: 'Note properties…',
      icon: Icons.tune,
      onTap: () => showNotePropertiesDialog(context: context),
    ),
    if (hasSelection && patternId != null) ...[
      DawContextAction(
        title: 'Copy',
        icon: Icons.copy,
        onTap: () => notifier.copyNotesFromPattern(patternId, selection),
      ),
      DawContextAction(
        title: 'Cut',
        icon: Icons.content_cut,
        onTap: () => notifier.cutNotesFromPattern(patternId, selection),
      ),
      DawContextAction(
        title: 'Delete',
        icon: Icons.delete_outline,
        isDestructive: true,
        onTap: () {
          notifier.deletePatternNoteBatch(
            patternId: patternId,
            noteIds: selection,
          );
          notifier.clearNoteSelection();
        },
      ),
    ],
  ];
}

/// Menu title describing what [pianoRollNoteActions] act on.
String pianoRollNoteActionsTitle(PianoRollStateData state) {
  final count = state.selectedNoteIds.length;
  return count == 0 ? 'All notes' : '$count note${count == 1 ? '' : 's'}';
}

/// Handlers for the piano-roll shortcuts in [pianoRollShortcuts].
Map<Type, Action<Intent>> pianoRollShortcutActions(WidgetRef ref) {
  PianoRollNotifier notifier() => ref.read(pianoRollProvider.notifier);
  return {
    QuantizeNotesIntent: CallbackAction<QuantizeNotesIntent>(
      onInvoke: (_) => notifier().quantizeNotes(),
    ),
    QuantizeNoteStartsIntent: CallbackAction<QuantizeNoteStartsIntent>(
      onInvoke: (_) => notifier().quantizeNoteStarts(),
    ),
    LegatoNotesIntent: CallbackAction<LegatoNotesIntent>(
      onInvoke: (_) => notifier().legatoNotes(),
    ),
    HumanizeNotesIntent: CallbackAction<HumanizeNotesIntent>(
      onInvoke: (_) => notifier().humanizeNotes(),
    ),
    ChopNotesIntent: CallbackAction<ChopNotesIntent>(
      onInvoke: (_) => notifier().chopNotes(),
    ),
    TransposeNotesIntent: CallbackAction<TransposeNotesIntent>(
      onInvoke: (intent) => notifier().transposeNotes(intent.semitones),
    ),
    ShiftNotesIntent: CallbackAction<ShiftNotesIntent>(
      onInvoke: (intent) => notifier().shiftNotes(intent.steps),
    ),
    SelectPianoRollToolIntent: CallbackAction<SelectPianoRollToolIntent>(
      onInvoke: (intent) {
        notifier().selectPianoRollTool(intent.tool);
        return null;
      },
    ),
  };
}
