import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Note param editor panel for easily edit note param (Velocity, Pitch)
/// Digidaw supports smooth param modulation from here, so you can have a
/// linear plot going down for example for single not from start to end of note, to make a pitch swinging effect into
/// your note, or adding a rich sound through varying velocity of notes.
/// 
/// It is inspired by FL Studio note param editor + additional feature Digidaw provide
/// 
/// Note that note all plugin hosting API supports this kind of note behavior,
/// so you would expect that some features are not working
class NoteParamEditorPanel extends ConsumerStatefulWidget {
  const NoteParamEditorPanel({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() {
    return NoteParamEditorPanelState();
  }

}

class NoteParamEditorPanelState extends ConsumerState<NoteParamEditorPanel> {
  String _selectedParameter = 'Velocity';

  static const _parameters = <String>[
    'Velocity',
    'Pitch',
    'Pan',
    'Note release',
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment: Alignment.centerLeft,
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedParameter,
              isDense: true,
              dropdownColor: colors.surfaceContainerHigh,
              items: _parameters
                  .map(
                    (parameter) => DropdownMenuItem(
                      value: parameter,
                      child: Text(parameter),
                    ),
                  )
                  .toList(),
              onChanged: (parameter) {
                if (parameter != null) {
                  setState(() => _selectedParameter = parameter);
                }
              },
            ),
          ),
        ),
        Divider(height: 1, color: colors.outlineVariant),
        const Expanded(
          child: Center(child: Text('Note param editor')),
        ),
      ],
    );
  }
}
