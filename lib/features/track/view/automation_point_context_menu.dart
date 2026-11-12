import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/core/l10n/localizer.dart';
import 'package:karbeat/core/widgets/context_menu.dart';
import 'package:karbeat/features/track/models/automation_lane_clipboard.dart';
import 'package:karbeat/features/track/services/automation_editor_service.dart';
import 'package:karbeat/features/track/services/curve_sampler.dart';
import 'package:karbeat/features/track/view/automation_point_value_dialog.dart';
import 'package:karbeat/src/rust/api/automation.dart';

/// Display name of an automation or envelope curve type.
String automationCurveTypeLabel(AutomationCurveTypeDto curveType) =>
    switch (curveType) {
      AutomationCurveTypeDto.linear => tr('track-curve-linear'),
      AutomationCurveTypeDto.exponential => tr('track-curve-exponential'),
      AutomationCurveTypeDto.logarithmic => tr('track-curve-logarithmic'),
      AutomationCurveTypeDto.sCurve => tr('track-curve-s-curve'),
      AutomationCurveTypeDto.bezier => tr('track-curve-bezier'),
      AutomationCurveTypeDto.step => tr('track-curve-step'),
      AutomationCurveTypeDto.stairs => tr('track-curve-stairs'),
      AutomationCurveTypeDto.smoothStairs => tr('track-curve-smooth-stairs'),
      AutomationCurveTypeDto.pulse => tr('track-curve-pulse'),
      AutomationCurveTypeDto.wave => tr('track-curve-wave'),
      AutomationCurveTypeDto.triangle => tr('track-curve-triangle'),
      AutomationCurveTypeDto.halfSine => tr('track-curve-half-sine'),
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
    title: tr('track-point', {'lane': lane.label}),
    header: Text(
      tr('track-point-at-tick', {
        'value': valueText(point.value),
        'tick': point.timeTicks,
      }),
      style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
    ),
    actions: [
      DawContextAction(
        title: tr('track-set-value'),
        icon: Icons.edit,
        onTap: () => setValueRequested = true,
      ),
      DawContextAction(
        title: tr('track-copy-value'),
        icon: Icons.copy,
        onTap: () => editor.copyPointValue(laneId: laneId, pointId: pointId),
      ),
      if (clipboard case AutomationLanePointClipboardValue(
        :final normalizedValue,
      ))
        DawContextAction(
          title: tr('track-paste-value', {
            'normalizedValue': valueText(normalizedValue),
          }),
          icon: Icons.content_paste,
          onTap: () => editor.pastePointValue(laneId: laneId, pointId: pointId),
        ),
      DawContextAction.submenu(
        title: tr('track-curve-type'),
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
              ? tr('track-reset-count')
              : tr('track-reset-tension'),
          icon: Icons.restart_alt,
          onTap: () => editor.setPointTension(
            laneId: laneId,
            pointId: pointId,
            tension: 0,
          ),
        ),
      DawContextAction(
        title: tr('track-delete-point'),
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
