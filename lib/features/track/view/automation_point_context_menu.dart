import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/core/widgets/context_menu.dart';
import 'package:karbeat/features/track/models/automation_lane_clipboard.dart';
import 'package:karbeat/features/track/services/automation_editor_service.dart';
import 'package:karbeat/features/track/services/curve_sampler.dart';
import 'package:karbeat/features/track/view/automation_point_value_dialog.dart';
import 'package:karbeat/src/rust/api/automation.dart';

/// Display name of an automation or envelope curve type.
String automationCurveTypeLabel(AutomationCurveTypeDto curveType) =>
    switch (curveType) {
      AutomationCurveTypeDto.linear => 'Linear',
      AutomationCurveTypeDto.exponential => 'Exponential',
      AutomationCurveTypeDto.logarithmic => 'Logarithmic',
      AutomationCurveTypeDto.sCurve => 'S-curve',
      AutomationCurveTypeDto.bezier => 'Bezier',
      AutomationCurveTypeDto.step => 'Step (hold)',
      AutomationCurveTypeDto.stairs => 'Stairs',
      AutomationCurveTypeDto.smoothStairs => 'Smooth stairs',
      AutomationCurveTypeDto.pulse => 'Pulse',
      AutomationCurveTypeDto.wave => 'Wave (sine)',
      AutomationCurveTypeDto.triangle => 'Triangle',
      AutomationCurveTypeDto.halfSine => 'Half sine',
    };

/// Icon of an automation or envelope curve type.
IconData automationCurveTypeIcon(AutomationCurveTypeDto curveType) =>
    switch (curveType) {
      AutomationCurveTypeDto.linear => Icons.show_chart,
      AutomationCurveTypeDto.exponential => Icons.trending_up,
      AutomationCurveTypeDto.logarithmic => Icons.trending_flat,
      AutomationCurveTypeDto.sCurve => Icons.swap_calls,
      AutomationCurveTypeDto.bezier => Icons.gesture,
      AutomationCurveTypeDto.step => Icons.horizontal_rule,
      AutomationCurveTypeDto.stairs => Icons.stairs_outlined,
      AutomationCurveTypeDto.smoothStairs => Icons.stairs,
      AutomationCurveTypeDto.pulse => Icons.view_week_outlined,
      AutomationCurveTypeDto.wave => Icons.waves,
      AutomationCurveTypeDto.triangle => Icons.change_history,
      AutomationCurveTypeDto.halfSine => Icons.wb_twilight,
    };

/// Curve types in menu order: ramps, Bezier, stepped shapes, then periodic
/// shapes.
const automationCurveTypeMenuOrder = [
  AutomationCurveTypeDto.linear,
  AutomationCurveTypeDto.exponential,
  AutomationCurveTypeDto.logarithmic,
  AutomationCurveTypeDto.sCurve,
  AutomationCurveTypeDto.bezier,
  AutomationCurveTypeDto.step,
  AutomationCurveTypeDto.stairs,
  AutomationCurveTypeDto.smoothStairs,
  AutomationCurveTypeDto.pulse,
  AutomationCurveTypeDto.wave,
  AutomationCurveTypeDto.triangle,
  AutomationCurveTypeDto.halfSine,
];

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
  final sampler = ref.read(curveSamplerProvider);

  // The automated parameter formats lane values in its own unit.
  String valueText(double normalized) => sampler.valueText(laneId, normalized);

  editor.openPointContext(laneId: laneId, pointId: pointId);

  // Menu actions run as the menu closes; the value dialog opens after it so
  // the point stays highlighted while the value is typed.
  var setValueRequested = false;

  await showDawContextMenu(
    context: context,
    title: 'Point: ${lane.label}',
    header: Text(
      'Value ${valueText(point.value)}  at tick ${point.timeTicks}',
      style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
    ),
    actions: [
      DawContextAction(
        title: 'Set value',
        icon: Icons.edit,
        onTap: () => setValueRequested = true,
      ),
      DawContextAction(
        title: 'Copy value',
        icon: Icons.copy,
        onTap: () => editor.copyPointValue(laneId: laneId, pointId: pointId),
      ),
      if (clipboard case AutomationLanePointClipboardValue(
        :final normalizedValue,
      ))
        DawContextAction(
          title: 'Paste value (${valueText(normalizedValue)})',
          icon: Icons.content_paste,
          onTap: () => editor.pastePointValue(laneId: laneId, pointId: pointId),
        ),
      DawContextAction.submenu(
        title: 'Curve type',
        subtitle: automationCurveTypeLabel(point.curveType),
        icon: automationCurveTypeIcon(point.curveType),
        children: [
          for (final curveType in automationCurveTypeMenuOrder)
            DawContextAction(
              title: automationCurveTypeLabel(curveType),
              icon: point.curveType == curveType
                  ? Icons.check
                  : automationCurveTypeIcon(curveType),
              color: point.curveType == curveType ? colors.primary : null,
              onTap: () => editor.setPointCurveType(
                laneId: laneId,
                pointId: pointId,
                curveType: curveType,
              ),
            ),
        ],
      ),
      if (point.tension != 0 && sampler.traits(point.curveType).supportsTension)
        DawContextAction(
          title: sampler.traits(point.curveType).tensionIsCount
              ? 'Reset count'
              : 'Reset tension',
          icon: Icons.restart_alt,
          onTap: () => editor.setPointTension(
            laneId: laneId,
            pointId: pointId,
            tension: 0,
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

  if (setValueRequested && context.mounted) {
    final value = await showAutomationPointValueDialog(
      context: context,
      lane: lane,
      point: point,
      sampler: sampler,
    );
    if (value != null) {
      await editor.setPointValue(
        laneId: laneId,
        pointId: pointId,
        normalizedValue: value,
      );
    }
  }

  editor.closePointContext(laneId: laneId, pointId: pointId);
}
