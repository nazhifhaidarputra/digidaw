import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:karbeat/core/l10n/localizer.dart';

/// Shows the DAW color picker and resolves with the chosen color, or null
/// when cancelled.
Future<Color?> showColorPickerDialog(
  BuildContext context,
  Color currentColor, {
  required String title,
}) {
  var selectedColor = currentColor;

  return showDialog<Color>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setDialogState) {
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: ColorPicker(
                color: selectedColor,
                onColorChanged: (color) {
                  setDialogState(() => selectedColor = color);
                },
                pickersEnabled: const {
                  ColorPickerType.both: true,
                  ColorPickerType.primary: false,
                  ColorPickerType.accent: false,
                  ColorPickerType.bw: true,
                  ColorPickerType.custom: false,
                  ColorPickerType.customSecondary: false,
                  ColorPickerType.wheel: true,
                },
                enableShadesSelection: true,
                enableOpacity: true,
                showMaterialName: true,
                showColorName: true,
                showColorCode: true,
                showEditIconButton: true,
                colorCodeHasColor: true,
                wheelDiameter: 220,
                width: 36,
                height: 36,
                borderRadius: 18,
                hasBorder: true,
                heading: Text(
                  tr('common-color-choose'),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                subheading: Text(
                  tr('common-color-shade'),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                wheelSubheading: Text(
                  tr('common-color-fine-tune'),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                opacitySubheading: Text(
                  tr('common-color-opacity'),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(tr('common-cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(selectedColor),
              child: Text(tr('common-select')),
            ),
          ],
        );
      },
    ),
  );
}
