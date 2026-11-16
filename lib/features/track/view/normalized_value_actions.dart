import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/core/l10n/localizer.dart';
import 'package:karbeat/core/widgets/context_menu.dart';
import 'package:karbeat/features/track/models/automation_lane_clipboard.dart';
import 'package:karbeat/features/track/services/automation_editor_service.dart';

/// Copy and paste actions for a parameter value in the normalized 0..1 domain.
///
/// The clipboard is the automation editor's value clipboard: automation
/// points and parameter controls store the same normalized value.
List<DawContextAction> normalizedValueActions({
  required WidgetRef ref,
  required double value,
  required double min,
  required double max,
  required ValueChanged<double> onChanged,
}) {
  if (max <= min) return const [];
  final clipboard = ref.watch(
    automationEditorProvider.select((state) => state.clipboard),
  );
  final normalized = ((value - min) / (max - min)).clamp(0.0, 1.0);

  return [
    DawContextAction(
      title: tr('mixer-copy-normalized-value'),
      icon: Icons.copy,
      onTap: () => ref
          .read(automationEditorProvider.notifier)
          .copyNormalizedValue(normalized),
    ),
    if (clipboard case AutomationLanePointClipboardValue(
      :final normalizedValue,
    ))
      DawContextAction(
        title: tr('mixer-paste-normalized-value', {
          'normalizedValue': normalizedValue.toStringAsFixed(2),
        }),
        icon: Icons.content_paste,
        onTap: () => onChanged(min + normalizedValue * (max - min)),
      ),
  ];
}
