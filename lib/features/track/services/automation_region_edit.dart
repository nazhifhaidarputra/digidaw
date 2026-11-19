import 'dart:math' as math;

import 'package:karbeat/src/rust/api/automation.dart';
import 'package:karbeat/src/rust/api/track.dart' show UiResizeEdge;

/// Span helpers for automation regions. A region covers the half-open tick
/// span from [AutomationRegionDto.startTicks] to [endTicks].
extension AutomationRegionSpan on AutomationRegionDto {
  int get endTicks => startTicks + lengthTicks;

  bool contains(int tick) => tick >= startTicks && tick < endTicks;

  bool overlaps(int start, int end) => start < endTicks && startTicks < end;
}

extension AutomationLaneRegions on AutomationLaneDto {
  /// The region containing [tick], if any.
  AutomationRegionDto? regionAt(int tick) =>
      regions.where((region) => region.contains(tick)).firstOrNull;

  /// Whether another region of the lane shows the same composition as
  /// [region].
  bool isShared(AutomationRegionDto region) => regions.any(
    (other) => other.id != region.id && other.contentId == region.contentId,
  );
}

/// Closest move to [delta] ticks that keeps the regions [ids] at or after
/// tick zero and stops them at the first region they would run into. Matches
/// the clamp Rust applies.
int clampRegionMove(AutomationLaneDto lane, Set<int> ids, int delta) {
  var clamped = delta;
  for (final moving in lane.regions.where((r) => ids.contains(r.id))) {
    if (clamped < 0) clamped = math.max(clamped, -moving.startTicks);
    for (final still in lane.regions.where((r) => !ids.contains(r.id))) {
      if (clamped > 0 && still.startTicks >= moving.endTicks) {
        clamped = math.min(clamped, still.startTicks - moving.endTicks);
      } else if (clamped < 0 && still.endTicks <= moving.startTicks) {
        clamped = math.max(clamped, still.endTicks - moving.startTicks);
      }
    }
  }
  return clamped;
}

/// Closest resize to [delta] ticks on [edge] that keeps every region of [ids]
/// at least one tick long, at or after tick zero, and clear of its
/// neighbours. Matches the clamp Rust applies.
int clampRegionResize(
  AutomationLaneDto lane,
  Set<int> ids,
  UiResizeEdge edge,
  int delta,
) {
  var clamped = delta;
  for (final region in lane.regions.where((r) => ids.contains(r.id))) {
    final shortest = region.lengthTicks - 1;
    switch (edge) {
      case UiResizeEdge.right:
        clamped = math.max(clamped, -shortest);
        final next = lane.regions
            .where((r) => r.startTicks >= region.endTicks)
            .map((r) => r.startTicks)
            .fold<int?>(null, (a, b) => a == null ? b : math.min(a, b));
        if (next != null) clamped = math.min(clamped, next - region.endTicks);
      case UiResizeEdge.left:
        clamped = math.max(math.min(clamped, shortest), -region.startTicks);
        final previous = lane.regions
            .where((r) => r.endTicks <= region.startTicks)
            .map((r) => r.endTicks)
            .fold<int?>(null, (a, b) => a == null ? b : math.max(a, b));
        if (previous != null) {
          clamped = math.max(clamped, previous - region.startTicks);
        }
    }
  }
  return clamped;
}

/// The smaller of two moves in the direction of [delta].
int clampTowardZero(int delta, int limit) => delta >= 0
    ? math.min(delta, math.max(limit, 0))
    : math.max(delta, math.min(limit, 0));

/// [lane] after moving the regions [ids] by [delta] ticks: their points move
/// with them and the free points under their new spans are overwritten.
AutomationLaneDto previewRegionMove(
  AutomationLaneDto lane,
  Set<int> ids,
  int delta,
) {
  if (delta == 0 || ids.isEmpty) return lane;
  final moving = lane.regions.where((r) => ids.contains(r.id)).toList();
  bool inMoving(int tick) => moving.any((r) => r.contains(tick));
  bool underDestination(int tick) => moving.any(
    (r) => tick >= r.startTicks + delta && tick < r.endTicks + delta,
  );

  final points = <AutomationPointDto>[
    for (final point in lane.points)
      if (inMoving(point.timeTicks))
        point.copyWith(timeTicks: point.timeTicks + delta)
      else if (!underDestination(point.timeTicks))
        point,
  ]..sort((a, b) => a.timeTicks.compareTo(b.timeTicks));

  final regions = [
    for (final region in lane.regions)
      ids.contains(region.id)
          ? region.copyWith(startTicks: region.startTicks + delta)
          : region,
  ]..sort((a, b) => a.startTicks.compareTo(b.startTicks));
  return lane.copyWith(points: points, regions: regions);
}

/// [lane] after moving [edge] of the regions [ids] by [delta] ticks.
/// Shrinking crops their points and growing overwrites the free points under
/// the new span. What a shared region shows in the grown span appears once
/// the engine stores the edit.
AutomationLaneDto previewRegionResize(
  AutomationLaneDto lane,
  Set<int> ids,
  UiResizeEdge edge,
  int delta,
) {
  if (delta == 0 || ids.isEmpty) return lane;
  final changed = <(int, int)>[];
  final regions = <AutomationRegionDto>[];
  for (final region in lane.regions) {
    if (!ids.contains(region.id)) {
      regions.add(region);
      continue;
    }
    switch (edge) {
      case UiResizeEdge.right:
        final end = region.endTicks + delta;
        changed.add((
          math.min(end, region.endTicks),
          math.max(end, region.endTicks),
        ));
        regions.add(region.copyWith(lengthTicks: region.lengthTicks + delta));
      case UiResizeEdge.left:
        final start = region.startTicks + delta;
        changed.add((
          math.min(start, region.startTicks),
          math.max(start, region.startTicks),
        ));
        regions.add(
          region.copyWith(
            startTicks: start,
            lengthTicks: region.lengthTicks - delta,
            contentOffset: region.contentOffset + delta,
          ),
        );
    }
  }
  final points = lane.points
      .where(
        (point) => !changed.any(
          (span) => point.timeTicks >= span.$1 && point.timeTicks < span.$2,
        ),
      )
      .toList();
  return lane.copyWith(points: points, regions: regions);
}
