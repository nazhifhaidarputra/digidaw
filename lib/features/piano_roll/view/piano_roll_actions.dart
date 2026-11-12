import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/piano_roll_state.dart';
import 'package:karbeat/core/input/intents/piano_roll/piano_roll_intent.dart';
import 'package:karbeat/core/l10n/localizer.dart';
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
      title: tr('piano-roll-quantize'),
      icon: Icons.grid_on,
      onTap: notifier.quantizeNotes,
    ),
    DawContextAction(
      title: tr('piano-roll-quantize-start-times'),
      icon: Icons.align_horizontal_left,
      onTap: notifier.quantizeNoteStarts,
    ),
    DawContextAction(
      title: tr('piano-roll-legato'),
      icon: Icons.linear_scale,
      onTap: notifier.legatoNotes,
    ),
    DawContextAction(
      title: tr('piano-roll-humanize'),
      icon: Icons.blur_on,
      onTap: notifier.humanizeNotes,
    ),
    DawContextAction(
      title: tr('piano-roll-chop-into-steps'),
      icon: Icons.content_cut,
      onTap: notifier.chopNotes,
    ),
    DawContextAction.submenu(
      title: tr('piano-roll-stretch'),
      icon: Icons.swap_horiz,
      children: [
        DawContextAction(
          title: tr('piano-roll-longer-1-25'),
          icon: Icons.open_in_full,
          onTap: () => notifier.stretchNotes(1.25),
        ),
        DawContextAction(
          title: tr('piano-roll-longer-1-5'),
          icon: Icons.open_in_full,
          onTap: () => notifier.stretchNotes(1.5),
        ),
        DawContextAction(
          title: tr('piano-roll-longer-2'),
          icon: Icons.open_in_full,
          onTap: () => notifier.stretchNotes(2),
        ),
        DawContextAction(
          title: tr('piano-roll-shorter-0-75'),
          icon: Icons.close_fullscreen,
          onTap: () => notifier.stretchNotes(0.75),
        ),
        DawContextAction(
          title: tr('piano-roll-shorter-0-5'),
          icon: Icons.close_fullscreen,
          onTap: () => notifier.stretchNotes(0.5),
        ),
      ],
    ),
    DawContextAction.submenu(
      title: tr('piano-roll-transpose'),
      icon: Icons.swap_vert,
      children: [
        DawContextAction(
          title: tr('piano-roll-up-a-semitone'),
          icon: Icons.keyboard_arrow_up,
          onTap: () => notifier.transposeNotes(1),
        ),
        DawContextAction(
          title: tr('piano-roll-down-a-semitone'),
          icon: Icons.keyboard_arrow_down,
          onTap: () => notifier.transposeNotes(-1),
        ),
        DawContextAction(
          title: tr('piano-roll-up-an-octave'),
          icon: Icons.keyboard_double_arrow_up,
          onTap: () => notifier.transposeNotes(12),
        ),
        DawContextAction(
          title: tr('piano-roll-down-an-octave'),
          icon: Icons.keyboard_double_arrow_down,
          onTap: () => notifier.transposeNotes(-12),
        ),
      ],
    ),
    DawContextAction.submenu(
      title: tr('piano-roll-shift-in-time'),
      icon: Icons.swap_horiz,
      children: [
        DawContextAction(
          title: tr('piano-roll-left-one-step'),
          icon: Icons.keyboard_arrow_left,
          onTap: () => notifier.shiftNotes(-1),
        ),
        DawContextAction(
          title: tr('piano-roll-right-one-step'),
          icon: Icons.keyboard_arrow_right,
          onTap: () => notifier.shiftNotes(1),
        ),
      ],
    ),
    DawContextAction(
      title: tr('piano-roll-note-properties'),
      icon: Icons.tune,
      onTap: () => showNotePropertiesDialog(context: context),
    ),
    if (hasSelection && patternId != null) ...[
      DawContextAction(
        title: tr('piano-roll-copy'),
        icon: Icons.copy,
        onTap: () => notifier.copyNotesFromPattern(patternId, selection),
      ),
      DawContextAction(
        title: tr('piano-roll-cut'),
        icon: Icons.content_cut,
        onTap: () => notifier.cutNotesFromPattern(patternId, selection),
      ),
      DawContextAction(
        title: tr('common-delete'),
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
  return count == 0
      ? tr('piano-roll-all-notes')
      : tr('piano-roll-notes-count', {'count': count});
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
    CopyNotesIntent: CallbackAction<CopyNotesIntent>(
      onInvoke: (_) => notifier().copySelectedNotes(),
    ),
    PasteNotesIntent: CallbackAction<PasteNotesIntent>(
      onInvoke: (_) => notifier().pasteNotesAfterSelection(),
    ),
    DuplicateNotesIntent: CallbackAction<DuplicateNotesIntent>(
      onInvoke: (_) => notifier().duplicateSelectedNotes(),
    ),
    DeleteNotesIntent: CallbackAction<DeleteNotesIntent>(
      onInvoke: (_) => notifier().deleteSelectedNotes(),
    ),
    SelectPianoRollToolIntent: CallbackAction<SelectPianoRollToolIntent>(
      onInvoke: (intent) {
        notifier().selectPianoRollTool(intent.tool);
        return null;
      },
    ),
  };
}
