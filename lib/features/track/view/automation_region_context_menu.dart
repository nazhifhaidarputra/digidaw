import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/automation_provider.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/app/providers/timeline_state.dart';
import 'package:karbeat/app/providers/track_list_state.dart';
import 'package:karbeat/core/l10n/localizer.dart';
import 'package:karbeat/core/widgets/context_menu.dart';
import 'package:karbeat/core/widgets/rename_dialog.dart';
import 'package:karbeat/features/track/services/automation_editor_service.dart';
import 'package:karbeat/features/track/services/automation_region_edit.dart';
import 'package:karbeat/features/track/view/automation_template_dialogs.dart';
import 'package:karbeat/features/track/view/clip_actions.dart';
import 'package:karbeat/src/rust/api/automation.dart';

/// The regions a region action works on: the selected regions of the lane
/// when they hold [regionId], else the region alone.
List<int> regionActionTargets(WidgetRef ref, int laneId, int regionId) {
  final selection = ref.read(trackListStateProvider);
  final selected = selection.regionsSelectedOn(laneId);
  return selected.contains(regionId) && selection.selectedRegionLaneId == laneId
      ? selected.toList()
      : [regionId];
}

/// Asks for a new name for [region] of the lane [laneId] and renames it.
Future<void> renameRegionWithDialog(
  BuildContext context,
  WidgetRef ref,
  int laneId,
  AutomationRegionDto region,
) async {
  final name = await showRenameDialog(
    context,
    title: tr('track-rename-region'),
    label: tr('track-region-name'),
    currentName: region.name,
  );
  final trimmed = name?.trim();
  if (trimmed == null || trimmed.isEmpty || trimmed == region.name) return;
  await ref
      .read(automationProvider.notifier)
      .renameRegion(laneId: laneId, regionId: region.id, name: trimmed);
}

/// Every action for the regions [regionIds] of the lane [laneId].
TimelineItemActions regionActions({
  required BuildContext context,
  required WidgetRef ref,
  required int laneId,
  required List<int> regionIds,
}) {
  final lane = ref.read(projectProvider).value?.automationPool[laneId];
  final regions =
      lane?.regions.where((r) => regionIds.contains(r.id)).toList() ??
      const <AutomationRegionDto>[];
  if (lane == null || regions.isEmpty) return (edit: const [], other: const []);

  final automation = ref.read(automationProvider.notifier);
  final editor = ref.read(automationEditorProvider.notifier);
  final single = regions.length == 1 ? regions.single : null;

  return (
    edit: [
      DawContextAction(
        title: tr('track-copy'),
        icon: Icons.copy,
        onTap: () => editor.copyRegions(laneId, regionIds),
      ),
      DawContextAction(
        title: tr('track-cut'),
        icon: Icons.content_cut,
        onTap: () => editor.cutRegions(laneId, regionIds),
      ),
      DawContextAction(
        title: tr('track-duplicate'),
        icon: Icons.control_point_duplicate,
        onTap: () => editor.duplicateRegions(laneId, regionIds),
      ),
      DawContextAction(
        title: tr('common-delete'),
        icon: Icons.delete_outline,
        isDestructive: true,
        onTap: () =>
            automation.deleteRegions(laneId: laneId, regionIds: regionIds),
      ),
    ],
    other: [
      if (single != null)
        DawContextAction(
          title: tr('common-rename'),
          icon: Icons.edit,
          onTap: () => renameRegionWithDialog(context, ref, laneId, single),
        ),
      if (regions.any(lane.isShared))
        DawContextAction(
          title: tr('track-make-unique'),
          icon: Icons.call_split,
          onTap: () => automation.makeRegionsUnique(
            laneId: laneId,
            regionIds: regionIds,
          ),
        ),
      DawContextAction(
        title: single != null
            ? tr('track-loop-to-region')
            : tr('track-loop-to-selection'),
        icon: Icons.loop,
        onTap: () => ref
            .read(timelineProvider.notifier)
            .setLoopRegion(
              regions.map((r) => r.startTicks).reduce((a, b) => a < b ? a : b),
              regions.map((r) => r.endTicks).reduce((a, b) => a > b ? a : b),
            ),
      ),
      if (single != null)
        DawContextAction(
          title: tr('track-save-region-as-template'),
          icon: Icons.bookmark_add_outlined,
          onTap: () async {
            final name = await showAutomationTemplateNameDialog(
              context: context,
              title: tr('track-save-curve-as-template'),
              initialName: single.name,
            );
            if (name == null) return;
            await editor.saveRegionAsTemplate(
              laneId: laneId,
              regionId: single.id,
              name: name,
            );
          },
        ),
      DawContextAction(
        title: tr('track-dissolve-regions'),
        icon: Icons.layers_clear,
        onTap: () =>
            automation.dissolveRegions(laneId: laneId, regionIds: regionIds),
      ),
    ],
  );
}

/// Opens the actions for [region] of [lane]. When the region is part of the
/// selected regions of its lane, the batch actions apply to all of them.
Future<void> showAutomationRegionContextMenu({
  required BuildContext context,
  required WidgetRef ref,
  required AutomationLaneDto lane,
  required AutomationRegionDto region,
}) {
  final regionIds = regionActionTargets(ref, lane.id, region.id);
  if (!ref
      .read(trackListStateProvider)
      .regionsSelectedOn(lane.id)
      .contains(region.id)) {
    ref
        .read(trackListStateProvider.notifier)
        .selectRegion(laneId: lane.id, regionId: region.id);
  }
  return showDawContextMenu(
    context: context,
    title: regionIds.length > 1
        ? tr('track-regions-selected', {'count': regionIds.length})
        : region.name,
    actions: regionActions(
      context: context,
      ref: ref,
      laneId: lane.id,
      regionIds: regionIds,
    ).forContextMenu,
  );
}
