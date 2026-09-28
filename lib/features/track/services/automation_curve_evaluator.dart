import 'dart:math' as math;

import 'package:karbeat/src/rust/api/automation.dart';

/// Dart mirror of the automation interpolation used by the audio engine.
///
/// Keep in sync with `interpolate_points`, `interpolate_segment`,
/// `apply_tension_to_t`, and the point ordering of `AutomationLane` in
/// `rust/karbeat-core/src/core/project/automation.rs` so the drawn curve is
/// exactly what the engine plays back.

/// Smallest value used by exponential segments so the ratio stays finite.
const double _exponentialFloor = 1e-4;

double _lerp(double alpha, double from, double to) =>
    from + (to - from) * alpha;

/// Maps a linear `t` in 0..1 through the tension ease.
/// Positive tension eases out (toward √t), negative eases in (toward t²).
double applyAutomationTension(double t, double tension) {
  if (tension == 0.0) return t;
  if (tension < 0.0) return _lerp(-tension, t, t * t);
  return _lerp(tension, t, math.sqrt(t));
}

/// Evaluates the segment starting at [from] and ending at [toValue] at the
/// normalized segment position [t]. The first point's curve and tension
/// select the shape.
double evaluateAutomationSegment(
  AutomationPointDto from,
  double toValue,
  double t,
) {
  final clampedT = t.clamp(0.0, 1.0);
  final v1 = from.value.clamp(0.0, 1.0);
  final v2 = toValue.clamp(0.0, 1.0);

  return switch (from.curveType) {
    AutomationCurveTypeDto.linear => _lerp(
      applyAutomationTension(clampedT, from.tension),
      v1,
      v2,
    ),
    AutomationCurveTypeDto.exponential => () {
      final start = math.max(v1, _exponentialFloor);
      final end = math.max(v2, _exponentialFloor);
      final shaped = applyAutomationTension(clampedT, -from.tension);
      return (start * math.pow(end / start, shaped)).clamp(0.0, 1.0);
    }(),
    AutomationCurveTypeDto.step => clampedT < 1.0 ? v1 : v2,
  };
}

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

/// Evaluates time-ordered [points] at [timeTicks], holding the first value
/// before the first point and the last value after the last point. Points
/// sharing a tick form a vertical jump: the segment arriving at the tick ends
/// on the first of them, and from that tick on the last one applies.
/// Returns `null` when there are no points.
double? evaluateAutomationPoints(
  List<AutomationPointDto> points,
  double timeTicks,
) {
  if (points.isEmpty) return null;

  final first = points.first;
  if (timeTicks < first.timeTicks) return first.value.clamp(0.0, 1.0);

  final index = automationIndexAfterTick(points, timeTicks);
  final start = points[index - 1];
  if (index == points.length) return start.value.clamp(0.0, 1.0);

  final end = points[index];
  final duration = end.timeTicks - start.timeTicks;
  if (duration <= 0) return start.value.clamp(0.0, 1.0);
  final t = (timeTicks - start.timeTicks) / duration;
  return evaluateAutomationSegment(start, end.value, t);
}

/// Direction in which increasing tension moves a segment's midpoint value:
/// `1` raises it, `-1` lowers it. Flat segments report `1`.
double automationTensionDirection(AutomationPointDto from, double toValue) {
  final rising = toValue - from.value;
  if (rising == 0) return 1;
  final sign = rising.sign;
  return from.curveType == AutomationCurveTypeDto.exponential ? -sign : sign;
}

/// Whether the segment starting at [from] has a user-adjustable tension.
bool automationSegmentSupportsTension(AutomationPointDto from) =>
    from.curveType != AutomationCurveTypeDto.step;
