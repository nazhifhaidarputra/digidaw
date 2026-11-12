import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/core/l10n/localizer.dart';
import 'package:karbeat/core/widgets/context_menu.dart';
import 'package:karbeat/features/track/models/automation_curve_template.dart';
import 'package:karbeat/features/track/models/automation_lane_clipboard.dart';
import 'package:karbeat/features/track/services/automation_editor_service.dart';
import 'package:karbeat/features/track/services/automation_template_service.dart';
import 'package:karbeat/features/track/view/automation_template_dialogs.dart';
import 'package:karbeat/src/rust/api/automation.dart';

/// Opens the actions for the range selected on [lane] with the Select tool.
Future<void> showAutomationRangeContextMenu({
  required BuildContext context,
  required WidgetRef ref,
  required AutomationLaneDto lane,
}) async {
  final editor = ref.read(automationEditorProvider.notifier);
  final editorState = ref.read(automationEditorProvider);
  final range = editorState.selectionOf(lane.id);
  if (range == null) return;
  final laneId = lane.id;
  final colors = Theme.of(context).colorScheme;

  // The name dialog opens after the menu has closed.
  var saveRequested = false;

  await showDawContextMenu(
    context: context,
    title: tr('track-range', {'lane': lane.label}),
    header: Text(
      tr('track-range-ticks', {'start': range.$1, 'end': range.$2}),
      style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
    ),
    actions: [
      DawContextAction(
        title: tr('track-copy-curve'),
        icon: Icons.copy,
        onTap: () => editor.copySelection(laneId),
      ),
      DawContextAction(
        title: tr('track-cut-curve'),
        icon: Icons.content_cut,
        onTap: () => editor.cutSelection(laneId),
      ),
      DawContextAction(
        title: tr('track-save-as-template'),
        icon: Icons.bookmark_add_outlined,
        onTap: () => saveRequested = true,
      ),
      if (editorState.clipboard is AutomationLanePointClipboardCurve)
        DawContextAction(
          title: tr('track-paste-curve-to-fit-range'),
          icon: Icons.content_paste,
          onTap: () => editor.pasteCurve(
            laneId: laneId,
            atTick: range.$1,
            fitSelection: true,
          ),
        ),
      ...automationTemplateActions(
        ref: ref,
        title: tr('track-insert-template-to-fit-range'),
        onInsert: (template) => editor.insertTemplate(
          laneId: laneId,
          atTick: range.$1,
          template: template,
          fitSelection: true,
        ),
      ),
      DawContextAction(
        title: tr('track-clear-selection'),
        icon: Icons.deselect,
        onTap: editor.clearSelection,
      ),
      DawContextAction(
        title: tr('track-delete-points-in-range'),
        icon: Icons.delete_outline,
        isDestructive: true,
        onTap: () => editor.deleteSelection(laneId),
      ),
    ],
  );

  if (saveRequested && context.mounted) {
    final name = await showAutomationTemplateNameDialog(
      context: context,
      title: tr('track-save-curve-as-template'),
      initialName: lane.label,
    );
    if (name != null) await editor.saveSelectionAsTemplate(laneId, name);
  }
}

/// A submenu listing the template library, or nothing while it is empty.
/// [onInsert] receives the chosen template.
List<DawContextAction> automationTemplateActions({
  required WidgetRef ref,
  required String title,
  required void Function(AutomationCurveTemplate template) onInsert,
}) {
  final templates = ref.read(automationTemplatesProvider).value;
  if (templates == null || templates.isEmpty) return const [];
  return [
    DawContextAction.submenu(
      title: title,
      subtitle: tr('track-templates-saved', {'count': templates.length}),
      icon: Icons.bookmarks_outlined,
      children: [
        for (final template in templates)
          DawContextAction(
            title: tr('track-template-points', {
              'template': template.name,
              'pointsCount': template.points.length,
            }),
            icon: Icons.show_chart,
            onTap: () => onInsert(template),
          ),
      ],
    ),
  ];
}
