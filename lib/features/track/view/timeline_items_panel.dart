import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/automation_provider.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/app/providers/range_select_state.dart';
import 'package:karbeat/app/providers/track_list_state.dart';
import 'package:karbeat/core/l10n/localizer.dart';
import 'package:karbeat/core/utils/clip_time_utils.dart';
import 'package:karbeat/core/widgets/context_menu.dart';
import 'package:karbeat/features/track/view/automation_region_context_menu.dart';
import 'package:karbeat/features/track/view/clip_actions.dart';
import 'package:karbeat/src/rust/api/project.dart';

/// Kind of item listed in the clips tab.
enum TimelineItemKind { audio, midi, empty, region }

/// One clip or automation region of the timeline.
typedef TimelineItem = ({
  TimelineRow row,
  int id,
  String name,
  TimelineItemKind kind,

  /// The track, or "owner › parameter" of the automation lane, holding it.
  String owner,
  int startTick,
});

/// Every clip and automation region in the project, in timeline order: the
/// master's and buses' lanes, then each track followed by its lanes. Lanes
/// of closed drawers are listed too.
final timelineItemsProvider = Provider<IList<TimelineItem>>((ref) {
  final project = ref.watch(projectProvider).value;
  if (project == null) return const IListConst([]);
  final index = ref.watch(automationLaneIndexProvider);

  Iterable<TimelineItem> regionsOf(
    IList<ChannelAutomationEntry>? entries,
  ) sync* {
    for (final entry
        in entries ?? const IListConst<ChannelAutomationEntry>([])) {
      final regions = [...entry.lane.regions]
        ..sort((a, b) => a.startTicks.compareTo(b.startTicks));
      for (final region in regions) {
        yield (
          row: TimelineRow.lane(entry.laneId),
          id: region.id,
          name: region.name,
          kind: TimelineItemKind.region,
          owner: '${entry.sourceName} › ${entry.lane.label}',
          startTick: region.startTicks,
        );
      }
    }
  }

  final tracks = project.tracks.values.toList()
    ..sort((a, b) => a.orderIdx.compareTo(b.orderIdx));
  final busIds = project.mixer.buses.keys.toList()..sort();

  return [
    ...regionsOf(index.master),
    for (final busId in busIds) ...regionsOf(index.buses[busId]),
    for (final track in tracks) ...[
      ...([
        ...track.clips,
      ]..sort((a, b) => a.startTimeInTicks.compareTo(b.startTimeInTicks))).map(
        (clip) => (
          row: TimelineRow.track(track.id),
          id: clip.id,
          name: clip.name,
          kind: switch (clip.source) {
            UiClipSource_Audio() => TimelineItemKind.audio,
            UiClipSource_Midi() => TimelineItemKind.midi,
            UiClipSource_None() => TimelineItemKind.empty,
          },
          owner: track.name,
          startTick: clip.startTimeInTicks,
        ),
      ),
      ...regionsOf(index.tracks[track.id]),
    ],
  ].lock;
});

/// Short display ID: the slot index of a project-wide clip ID, or a
/// lane-local region ID. Live items never share a slot index.
int _displayId(int id) => id & 0xffffffff;

/// The clips tab of the track list's right panel. Tapping an item selects it
/// and scrolls the timeline to it through [onReveal].
class TimelineItemsPanel extends ConsumerWidget {
  const TimelineItemsPanel({
    super.key,
    required this.scrollController,
    required this.onReveal,
  });

  final ScrollController scrollController;

  /// Brings [row] at [tick] into view.
  final void Function(TimelineRow row, int tick) onReveal;

  /// Opens the same actions the item has on the timeline. An item outside
  /// the selection becomes the selection first, so batch actions don't reach
  /// unrelated clips.
  void _showActions(BuildContext context, WidgetRef ref, TimelineItem item) {
    final project = ref.read(projectProvider).value;
    if (project == null) return;
    final selection = ref.read(trackListStateProvider);
    final trackList = ref.read(trackListStateProvider.notifier);

    switch (item.row) {
      case TimelineTrackRow(:final trackId):
        final clip = project.tracks[trackId]?.clips
            .where((c) => c.id == item.id)
            .firstOrNull;
        if (clip == null) return;
        if (!selection.clipsSelectedOn(trackId).contains(clip.id)) {
          trackList.selectClip(trackId: trackId, clipId: clip.id);
        }
        showDawContextMenu(
          context: context,
          title: clip.name,
          actions: clipActions(
            context: context,
            ref: ref,
            trackId: trackId,
            clip: clip,
          ).forContextMenu,
        );
      case TimelineLaneRow(:final laneId):
        final lane = project.automationPool[laneId];
        final region = lane?.regions.where((r) => r.id == item.id).firstOrNull;
        if (lane == null || region == null) return;
        showAutomationRegionContextMenu(
          context: context,
          ref: ref,
          lane: lane,
          region: region,
        );
    }
  }

  void _select(WidgetRef ref, TimelineItem item) {
    final trackList = ref.read(trackListStateProvider.notifier);
    switch (item.row) {
      case TimelineTrackRow(:final trackId):
        trackList.selectClip(trackId: trackId, clipId: item.id);
      case TimelineLaneRow(:final laneId):
        trackList.selectRegion(laneId: laneId, regionId: item.id);
    }
    onReveal(item.row, item.startTick);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final items = ref.watch(timelineItemsProvider);
    final selection = ref.watch(
      trackListStateProvider.select(
        (s) => (clips: s.selectedClips, regions: s.selectedRegions),
      ),
    );

    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            tr('track-timeline-items-empty'),
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
          ),
        ),
      );
    }

    return ListView.builder(
      controller: scrollController,
      itemCount: items.length,
      itemExtent: 44,
      itemBuilder: (context, index) {
        final item = items[index];
        final selected = switch (item.row) {
          TimelineTrackRow(:final trackId) =>
            selection.clips[trackId]?.contains(item.id) ?? false,
          TimelineLaneRow(:final laneId) =>
            selection.regions[laneId]?.contains(item.id) ?? false,
        };
        final (icon, kind) = switch (item.kind) {
          TimelineItemKind.audio => (Icons.graphic_eq, tr('track-item-audio')),
          TimelineItemKind.midi => (Icons.piano, tr('track-item-midi')),
          TimelineItemKind.empty => (Icons.crop_square, tr('track-item-empty')),
          TimelineItemKind.region => (
            Icons.show_chart,
            tr('track-item-region'),
          ),
        };

        return Material(
          color: selected
              ? colors.primary.withValues(alpha: 0.16)
              : Colors.transparent,
          child: InkWell(
            onTap: () => _select(ref, item),
            onSecondaryTap: () => _showActions(context, ref, item),
            onLongPress: () => _showActions(context, ref, item),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  Icon(icon, size: 16, color: colors.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.onSurface,
                            fontSize: 12,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                        Text(
                          tr('track-item-details', {
                            'kind': kind,
                            'owner': item.owner,
                          }),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    tr('track-item-id', {'id': _displayId(item.id)}),
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 10,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
