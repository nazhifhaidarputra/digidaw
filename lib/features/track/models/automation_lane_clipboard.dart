import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:karbeat/src/rust/api/automation.dart';

part 'automation_lane_clipboard.freezed.dart';

@freezed
abstract class AutomationLanePointClipboard
    with _$AutomationLanePointClipboard {
  const factory AutomationLanePointClipboard.empty() =
      AutomationLanePointClipboardEmpty;
  const factory AutomationLanePointClipboard.value({
    required double normalizedValue,
  }) = AutomationLanePointClipboardValue;

  /// A copied range of a lane. [points] have times relative to the range
  /// start and [lengthTicks] is the length of the copied range.
  const factory AutomationLanePointClipboard.curve({
    required IList<AutomationPointDto> points,
    required int lengthTicks,
  }) = AutomationLanePointClipboardCurve;
}
