import 'dart:math' as math;

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:karbeat/app/providers/automation_provider.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/app/providers/track_list_state.dart';
import 'package:karbeat/app/providers/transport_state.dart';
import 'package:karbeat/app/providers/workspace_state.dart';
import 'package:karbeat/core/utils/clip_time_utils.dart';
import 'package:karbeat/features/track/services/automation_region_edit.dart';
import 'package:karbeat/src/rust/api/automation.dart' show AutomationRegionDto;
import 'package:karbeat/src/rust/api/project.dart' show UiClip;

part 'range_select_state.freezed.dart';

/// One row of the arranger timeline that can hold selectable items: a track's
/// clips, or an automation lane's regions.
@freezed
sealed class TimelineRow with _$TimelineRow {
  const factory TimelineRow.track(int trackId) = TimelineTrackRow;
  const factory TimelineRow.lane(int laneId) = TimelineLaneRow;
}

/// The rows of the timeline in the order they are drawn, top to bottom.
///
/// Rows the user cannot see are left out: lanes inside a closed automation
/// drawer, and automation lanes shrunk to their title, which hide their
/// regions. A range selection never reaches them.
final timelineRowsProvider = Provider<IList<TimelineRow>>((ref) {
  final automation = ref.watch(automationProvider);
  final index = ref.watch(automationLaneIndexProvider);
  final busIds = ref.watch(
    projectProvider.select(
      (s) => (s.value?.mixer.buses.keys.toList() ?? <int>[])..sort(),
    ),
  );
  final trackIds = ref.watch(
    projectProvider.select((s) {
      final tracks = s.value?.tracks.values.toList() ?? [];
      tracks.sort((a, b) => a.orderIdx.compareTo(b.orderIdx));
      return tracks.map((track) => track.id).toIList();
    }),
  );

  Iterable<TimelineRow> lanes(IList<ChannelAutomationEntry>? entries) sync* {
    for (final entry
        in entries ?? const IListConst<ChannelAutomationEntry>([])) {
      if (automation.collapsedAutomationLaneIds.contains(entry.laneId)) {
        continue;
      }
      yield TimelineRow.lane(entry.laneId);
    }
  }

  return [
    if (automation.isMasterAutomationDrawerOpened) ...lanes(index.master),
    for (final busId in busIds)
      if (!automation.collapsedBusAutomations.contains(busId))
        ...lanes(index.buses[busId]),
    for (final trackId in trackIds) ...[
      TimelineRow.track(trackId),
      if (!automation.collapsedTrackAutomations.contains(trackId))
        ...lanes(index.tracks[trackId]),
    ],
  ].lock;
});

/// A span of the timeline in ticks, never empty: [start] is always before
/// [end]. Build one with [TickSpan.between].
@freezed
abstract class TickSpan with _$TickSpan {
  const TickSpan._();

  const factory TickSpan._raw({required int start, required int end}) =
      _TickSpan;

  /// The span between two tick positions in either order, clamped at zero;
  /// null when they enclose no time.
  static TickSpan? between(double a, double b) {
    final start = math.max(0, math.min(a, b).floor());
    final end = math.max(a, b).ceil();
    return end > start ? TickSpan._raw(start: start, end: end) : null;
  }

  bool contains(double tick) => tick >= start && tick <= end;
}

/// The range being painted with the Select tool, in tick space.
///
/// The range covers every row from [anchorRow] to [focusRow] in
/// [timelineRowsProvider] order, so it can span tracks and automation lanes.
/// A range started on the ruler covers every row.
@freezed
abstract class RangeSelectState with _$RangeSelectState {
  const RangeSelectState._();

  const factory RangeSelectState({
    @Default(false) bool isSelecting,

    /// Row where the drag started; null for a range drawn on the ruler.
    TimelineRow? anchorRow,

    /// Row under the pointer, or the last row it passed over.
    TimelineRow? focusRow,

    /// Drag start in ticks.
    @Default(0) double startTick,

    /// Current drag end in ticks.
    @Default(0) double endTick,

    /// Time range kept highlighted on the ruler after a range drawn there
    /// ends. It outlives the clip selection it made; a double click on it, or
    /// Escape with nothing else selected, clears it.
    TickSpan? timeRange,
  }) = _RangeSelectState;

  bool get coversAllRows => isSelecting && anchorRow == null;

  /// Whether the range covers [row], given the rows in drawing order.
  bool covers(TimelineRow row, IList<TimelineRow> rows) {
    if (!isSelecting) return false;
    final anchor = anchorRow;
    if (anchor == null) return rows.contains(row);
    final index = rows.indexOf(row);
    final from = rows.indexOf(anchor);
    final to = rows.indexOf(focusRow ?? anchor);
    if (index < 0 || from < 0 || to < 0) return row == anchor;
    return index >= math.min(from, to) && index <= math.max(from, to);
  }

  double get minTick => math.min(startTick, endTick);
  double get maxTick => math.max(startTick, endTick);
}

class RangeSelectNotifier extends Notifier<RangeSelectState> {
  @override
  RangeSelectState build() => const RangeSelectState();

  /// [tick] on the nearest grid line while snap to grid is on.
  double _snap(double tick) {
    final workspace = ref.read(workspaceStateProvider);
    final clamped = math.max(0.0, tick);
    if (!workspace.snapToGrid) return clamped;
    return workspace.gridSize.snap(clamped.round()).toDouble();
  }

  /// Starts a range on [row] at [tick].
  void start(TimelineRow row, double tick) {
    final snapped = _snap(tick);
    state = RangeSelectState(
      timeRange: state.timeRange,
      isSelecting: true,
      anchorRow: row,
      focusRow: row,
      startTick: snapped,
      endTick: snapped,
    );
  }

  /// Starts a range on the ruler, covering every row. It replaces the kept
  /// time range once it ends.
  void startAllRows(double tick) {
    final snapped = _snap(tick);
    state = RangeSelectState(
      isSelecting: true,
      startTick: snapped,
      endTick: snapped,
    );
  }

  /// Moves the end of the range to [tick] and, when given, to [row].
  void update(double rawTick, {TimelineRow? row}) {
    if (!state.isSelecting) return;
    final tick = _snap(rawTick);
    final focusRow = state.anchorRow == null ? null : row ?? state.focusRow;
    if (state.endTick == tick && state.focusRow == focusRow) return;
    state = state.copyWith(endTick: tick, focusRow: focusRow);
  }

  /// Selects every clip and automation region the range touches, then ends
  /// the range. A range that touches nothing clears the selection.
  void finish() {
    final range = state;
    state = RangeSelectState(
      timeRange: range.coversAllRows
          ? TickSpan.between(range.startTick, range.endTick)
          : range.timeRange,
    );
    if (!range.isSelecting) return;

    final project = ref.read(projectProvider).value;
    if (project == null) return;
    final rows = ref.read(timelineRowsProvider);
    final transport = ref.read(transportProvider).value;
    final bpm = transport?.state?.bpm ?? 120.0;
    final sampleRate = transport?.sampleRate ?? 48000;
    final minTick = range.minTick.floor();
    final maxTick = range.maxTick.ceil();
    bool touches(int start, int end) => end > minTick && start < maxTick;

    final clips = <int, IList<int>>{};
    final regions = <int, IList<int>>{};
    for (final row in rows) {
      if (!range.covers(row, rows)) continue;
      switch (row) {
        case TimelineTrackRow(:final trackId):
          clips[trackId] = [
            for (final clip
                in project.tracks[trackId]?.clips ?? const <UiClip>[])
              if (touches(
                clip.startTimeInTicks,
                clip.startTimeInTicks + clip.loopLengthInTicks(bpm, sampleRate),
              ))
                clip.id,
          ].lock;
        case TimelineLaneRow(:final laneId):
          regions[laneId] = [
            for (final region
                in project.automationPool[laneId]?.regions ??
                    const <AutomationRegionDto>[])
              if (touches(region.startTicks, region.endTicks)) region.id,
          ].lock;
      }
    }

    ref
        .read(trackListStateProvider.notifier)
        .selectTimelineItems(clips: clips.lock, regions: regions.lock);
  }

  /// Ends the range being drawn, keeping the time range on the ruler.
  void cancel() {
    state = RangeSelectState(timeRange: state.timeRange);
  }

  /// Removes the time range kept on the ruler.
  void clearTimeRange() {
    if (state.timeRange == null) return;
    state = state.copyWith(timeRange: null);
  }
}

final rangeSelectProvider =
    NotifierProvider<RangeSelectNotifier, RangeSelectState>(
      () => RangeSelectNotifier(),
    );
