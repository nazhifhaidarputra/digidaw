import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/mixer_state.dart';
import 'package:karbeat/core/widgets/color_picker_dialog.dart';
import 'package:karbeat/core/widgets/context_menu.dart';
import 'package:karbeat/core/widgets/rename_dialog.dart';

/// Rename and recolor actions for a bus context menu, shared by the mixer
/// strip and the bus row in the track list.
List<DawContextAction> busIdentityActions({
  required BuildContext context,
  required WidgetRef ref,
  required int busId,
  required String name,
  required Color color,
}) {
  return [
    DawContextAction(
      title: 'Rename Bus',
      icon: Icons.edit,
      onTap: () async {
        final newName = await showRenameDialog(
          context,
          title: 'Rename Bus',
          label: 'New bus name',
          currentName: name,
        );
        if (newName == null) return;
        await ref
            .read(mixerStateProvider.notifier)
            .renameBus(busId: busId, name: newName);
      },
    ),
    DawContextAction(
      title: 'Change Color',
      icon: Icons.color_lens,
      onTap: () async {
        final selected = await showColorPickerDialog(
          context,
          color,
          title: 'Select Bus Color',
        );
        if (selected == null || selected.toARGB32() == color.toARGB32()) {
          return;
        }
        await ref
            .read(mixerStateProvider.notifier)
            .changeBusColor(busId: busId, color: selected);
      },
    ),
  ];
}
