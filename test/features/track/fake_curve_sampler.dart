import 'dart:typed_data';

import 'package:karbeat/features/track/services/curve_sampler.dart';
import 'package:karbeat/src/rust/api/automation.dart';
import 'package:karbeat/src/rust/api/project.dart';

/// Stands in for the Rust curve functions in widget tests, where the native
/// library is not loaded. Curves are flat and the parameter spans -100 to 6,
/// which is enough to exercise the widgets around them.
class FakeCurveSampler extends CurveSampler {
  FakeCurveSampler() : super(() => throw StateError('no native library'));

  static const double min = -100;
  static const double max = 6;

  @override
  Float32List sampleLane(
    List<AutomationPointDto> points, {
    required double startTick,
    required double endTick,
    required int count,
  }) =>
      Float32List(points.isEmpty ? 0 : count)
        ..fillRange(0, points.isEmpty ? 0 : count, 0.5);

  @override
  Float32List segmentMidpoints(List<AutomationPointDto> points) =>
      Float32List(points.length < 2 ? 0 : points.length - 1);

  @override
  AutomationCurveTraitsDto traits(AutomationCurveTypeDto curveType) =>
      AutomationCurveTraitsDto(
        supportsTension:
            curveType != AutomationCurveTypeDto.step &&
            curveType != AutomationCurveTypeDto.bezier,
        tensionInverted: curveType == AutomationCurveTypeDto.exponential,
        tensionIsCount: curveType == AutomationCurveTypeDto.stairs,
        usesHandles: curveType == AutomationCurveTypeDto.bezier,
      );

  @override
  int tensionCount(double tension) => 4;

  @override
  Float32List sampleEnvelope(
    UiGainEnvelope envelope, {
    required int contentStart,
    required int contentLength,
    required List<double> positions,
  }) => Float32List(positions.length)..fillRange(0, positions.length, 1);

  @override
  double fadeGain(UiFade fade, double t) => t;

  @override
  String valueText(int laneId, double normalized) =>
      (min + normalized * (max - min)).toStringAsFixed(2);

  @override
  double? parseValue(int laneId, String text) {
    final plain = double.tryParse(text.trim());
    if (plain == null) return null;
    return ((plain - min) / (max - min)).clamp(0.0, 1.0);
  }
}
