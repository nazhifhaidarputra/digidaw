import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:karbeat/src/rust/api/automation.dart';

part 'automation_curve_template.freezed.dart';

/// A reusable automation curve saved to the user's template library.
@freezed
abstract class AutomationCurveTemplate with _$AutomationCurveTemplate {
  const factory AutomationCurveTemplate({
    /// Stable identifier, unique inside the library
    required String id,

    /// Name shown in the template menus
    required String name,

    /// Length of the saved range in ticks
    required int lengthTicks,

    /// Points with times relative to the start of the saved range
    required IList<AutomationPointDto> points,
  }) = _AutomationCurveTemplate;
}
