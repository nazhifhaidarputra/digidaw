import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/core/widgets/context_menu.dart';
import 'package:karbeat/features/track/models/automation_lane_clipboard.dart';
import 'package:karbeat/features/track/services/automation_editor_service.dart';
import 'package:karbeat/src/rust/api/automation.dart';

String _curveTypeLabel(AutomationCurveTypeDto curveType) => switch (curveType) {
  AutomationCurveTypeDto.linear => 'Linear',
  AutomationCurveTypeDto.exponential => 'Exponential',
  AutomationCurveTypeDto.step => 'Step',
};

IconData _curveTypeIcon(AutomationCurveTypeDto curveType) =>
    switch (curveType) {
      AutomationCurveTypeDto.linear => Icons.show_chart,
      AutomationCurveTypeDto.exponential => Icons.trending_up,
      AutomationCurveTypeDto.step => Icons.stairs_outlined,
    };

/// Opens the per point actions for one automation point. The editor context
/// target is held for as long as the menu is visible.
Future<void> showAutomationPointContextMenu({
  required BuildContext context,
  required WidgetRef ref,
  required AutomationLaneDto lane,
  required AutomationPointDto point,
}) async {
  final editor = ref.read(automationEditorProvider.notifier);
  final clipboard = ref.read(automationEditorProvider).clipboard;
  final laneId = lane.id;
  final pointId = point.id;
  final colors = Theme.of(context).colorScheme;

  double denormalize(double normalized) =>
      lane.min + normalized * (lane.max - lane.min);

  editor.openPointContext(laneId: laneId, pointId: pointId);

  await showDawContextMenu(
    context: context,
    title: 'Point: ${lane.label}',
    header: Text(
      'Value ${denormalize(point.value).toStringAsFixed(2)}'
      '  at tick ${point.timeTicks}',
      style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
    ),
    actions: [
      DawContextAction(
        title: 'Copy value',
        icon: Icons.copy,
        onTap: () => editor.copyPointValue(laneId: laneId, pointId: pointId),
      ),
      if (clipboard case AutomationLanePointClipboardValue(
        :final normalizedValue,
      ))
        DawContextAction(
          title:
              'Paste value (${denormalize(normalizedValue).toStringAsFixed(2)})',
          icon: Icons.content_paste,
          onTap: () => editor.pastePointValue(laneId: laneId, pointId: pointId),
        ),
      for (final curveType in AutomationCurveTypeDto.values)
        DawContextAction(
          title: 'Curve: ${_curveTypeLabel(curveType)}',
          icon: point.curveType == curveType
              ? Icons.check
              : _curveTypeIcon(curveType),
          color: point.curveType == curveType ? colors.primary : null,
          onTap: () => editor.setPointCurveType(
            laneId: laneId,
            pointId: pointId,
            curveType: curveType,
          ),
        ),
      DawContextAction(
        title: 'Delete point',
        icon: Icons.delete_outline,
        isDestructive: true,
        onTap: () => editor.deletePoint(laneId: laneId, pointId: pointId),
      ),
    ],
  );

  editor.closePointContext(laneId: laneId, pointId: pointId);
}
