import 'package:karbeat/src/rust/api/automation.dart';

/// Point ordering helpers for optimistic automation edits.
///
/// Curve shapes are not computed here: the lane painter and editor sample them
/// from the audio engine's own code through `CurveSampler`. These helpers only
/// mirror how `AutomationLane` in
/// `rust/karbeat-core/src/core/project/automation.rs` orders points, so a
/// dragged point previews where the engine will place it.

/// Index after every point at or before [timeTicks] in time-ordered [points].
int automationIndexAfterTick(List<AutomationPointDto> points, num timeTicks) {
  var low = 0;
  var high = points.length;
  while (low < high) {
    final mid = (low + high) >> 1;
    if (points[mid].timeTicks <= timeTicks) {
      low = mid + 1;
    } else {
      high = mid;
    }
  }
  return low;
}

/// Places [point] into time-ordered [others] (which must not contain it) the
/// same way the engine orders an added or edited point: it keeps
/// [previousIndex] while it stays on [previousTime], otherwise it goes after
/// every point already on its tick.
List<AutomationPointDto> placeAutomationPoint(
  List<AutomationPointDto> others,
  AutomationPointDto point, {
  int? previousIndex,
  int? previousTime,
}) {
  final keepsPosition =
      previousIndex != null &&
      previousTime == point.timeTicks &&
      previousIndex <= others.length;
  final index = keepsPosition
      ? previousIndex
      : automationIndexAfterTick(others, point.timeTicks);
  return [...others.take(index), point, ...others.skip(index)];
}
