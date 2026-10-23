import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/src/rust/api/automation.dart';
import 'package:karbeat/src/rust/api/project.dart';

/// Curve shapes and parameter values computed by the Rust code the audio
/// engine plays, so the editors draw exactly what is heard.
///
/// Widgets read it through [curveSamplerProvider]; tests override that
/// provider with a fake when the native library is not loaded.
class CurveSampler {
  CurveSampler(this._context);

  final DawContext Function() _context;

  /// Traits never change for a curve type, so each is fetched once.
  final Map<AutomationCurveTypeDto, AutomationCurveTraitsDto> _traits = {};

  /// Samples a lane's curve at [count] evenly spaced ticks from [startTick]
  /// to [endTick] inclusive. [points] must be in lane order.
  Float32List sampleLane(
    List<AutomationPointDto> points, {
    required double startTick,
    required double endTick,
    required int count,
  }) => sampleAutomationCurve(
    points: points,
    startTick: startTick,
    endTick: endTick,
    sampleCount: count,
  );

  /// Value at the time midpoint of every segment of [points], one entry per
  /// pair of consecutive points.
  Float32List segmentMidpoints(List<AutomationPointDto> points) =>
      automationSegmentMidpoints(points: points);

  /// Which segment controls [curveType] responds to.
  AutomationCurveTraitsDto traits(AutomationCurveTypeDto curveType) =>
      _traits[curveType] ??= automationCurveTraits(curveType: curveType);

  /// Step or cycle count that [tension] selects for count-driven curves.
  int tensionCount(double tension) => automationTensionCount(tension: tension);

  /// Gains of [envelope] at [positions], in the envelope's own unit.
  Float32List sampleEnvelope(
    UiGainEnvelope envelope, {
    required int contentStart,
    required int contentLength,
    required List<double> positions,
  }) => sampleGainEnvelope(
    envelope: envelope,
    contentStart: contentStart,
    contentLength: contentLength,
    positions: positions,
  );

  /// Gain of [fade] at normalized position [t], rising from 0 to 1.
  double fadeGain(UiFade fade, double t) => fadeGainAt(fade: fade, t: t);

  /// Formats the normalized lane value [normalized] in the unit of the
  /// parameter that lane [laneId] automates. Falls back to the normalized
  /// value when the parameter cannot be resolved.
  String valueText(int laneId, double normalized) => attempt(
    () => automationValueText(
      ctx: _context(),
      automationId: laneId,
      normalized: normalized,
    ),
  ).unwrapOr(normalized.toStringAsFixed(2));

  /// Parses [text], typed in the unit of the parameter that lane [laneId]
  /// automates, into a normalized lane value. Null when it is not a value of
  /// that parameter.
  double? parseValue(int laneId, String text) => switch (attempt(
    () =>
        parseAutomationValue(ctx: _context(), automationId: laneId, text: text),
  )) {
    Ok(:final value) => value,
    Error() => null,
  };
}

final curveSamplerProvider = Provider<CurveSampler>(
  (ref) => CurveSampler(() => ref.read(projectProvider.notifier).dawContext),
);
