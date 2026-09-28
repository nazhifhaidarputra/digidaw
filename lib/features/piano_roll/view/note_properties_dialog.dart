import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/piano_roll_state.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/src/rust/api/pattern.dart';

/// Opens an editor for the velocity, fine pitch, and pan of the selected notes,
/// or of every note in the pattern when nothing is selected.
Future<void> showNotePropertiesDialog({required BuildContext context}) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _NotePropertiesDialog(),
  );
}

class _NotePropertiesDialog extends ConsumerStatefulWidget {
  const _NotePropertiesDialog();

  @override
  ConsumerState<_NotePropertiesDialog> createState() =>
      _NotePropertiesDialogState();
}

class _NotePropertiesDialogState extends ConsumerState<_NotePropertiesDialog> {
  // Values being edited; null means "leave each note's own value".
  double? _velocity;
  double? _pitch;
  double? _pan;

  List<UiNote> _targets() {
    final state = ref.read(pianoRollProvider);
    final patternId = state.editingPatternId;
    final notes = patternId == null
        ? const <UiNote>[]
        : ref.read(projectProvider).value?.patterns[patternId]?.notes ??
              const <UiNote>[];
    final selection = state.selectedNoteIds;
    return selection.isEmpty
        ? notes
        : notes.where((note) => selection.contains(note.id)).toList();
  }

  Future<void> _apply(List<UiNote> targets) async {
    final result = await ref.read(pianoRollProvider.notifier).setNoteParams([
      for (final note in targets)
        UiNoteParamUpdate(
          noteId: note.id,
          velocity: _velocity?.round(),
          pan: _pan,
          pitch: _pitch,
        ),
    ]);
    if (result.isOk() && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final targets = _targets();
    final first = targets.firstOrNull;
    final count = targets.length;

    Widget slider({
      required String label,
      required double value,
      required double min,
      required double max,
      required int divisions,
      required String Function(double) format,
      required ValueChanged<double> onChanged,
      required bool mixed,
    }) {
      return Row(
        children: [
          SizedBox(width: 72, child: Text(label)),
          Expanded(
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              label: format(value),
              onChanged: count == 0 ? null : onChanged,
            ),
          ),
          SizedBox(
            width: 64,
            child: Text(
              mixed ? 'Mixed' : format(value),
              textAlign: TextAlign.end,
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
            ),
          ),
        ],
      );
    }

    bool mixed(double Function(UiNote) read) =>
        targets.map(read).toSet().length > 1;

    return AlertDialog(
      title: Text(
        count == 1 ? 'Note properties' : 'Note properties · $count notes',
      ),
      content: SizedBox(
        width: 420,
        child: count == 0
            ? const Text('This pattern has no notes.')
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  slider(
                    label: 'Velocity',
                    value: _velocity ?? first!.velocity.toDouble(),
                    min: 1,
                    max: 127,
                    divisions: 126,
                    format: (v) => v.round().toString(),
                    mixed: _velocity == null && mixed((n) => n.velocity * 1.0),
                    onChanged: (v) => setState(() => _velocity = v),
                  ),
                  slider(
                    label: 'Pitch',
                    value: _pitch ?? first!.pitch,
                    min: -2,
                    max: 2,
                    divisions: 400,
                    format: (v) =>
                        '${v >= 0 ? '+' : ''}${(v * 100).round()} ct',
                    mixed: _pitch == null && mixed((n) => n.pitch),
                    onChanged: (v) => setState(() => _pitch = v),
                  ),
                  slider(
                    label: 'Pan',
                    value: _pan ?? first!.pan,
                    min: -1,
                    max: 1,
                    divisions: 200,
                    format: (v) => v.abs() < 0.005
                        ? 'C'
                        : '${(v.abs() * 100).round()}${v < 0 ? 'L' : 'R'}',
                    mixed: _pan == null && mixed((n) => n.pan),
                    onChanged: (v) => setState(() => _pan = v),
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => setState(() {
            _velocity = 100;
            _pitch = 0;
            _pan = 0;
          }),
          child: const Text('Reset'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed:
              count == 0 ||
                  (_velocity == null && _pitch == null && _pan == null)
              ? null
              : () => _apply(targets),
          child: const Text('Apply'),
        ),
      ],
    );
  }
}
