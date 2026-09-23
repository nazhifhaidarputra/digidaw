import 'package:freezed_annotation/freezed_annotation.dart';

part 'automation_lane_clipboard.freezed.dart';

@freezed
abstract class AutomationLanePointClipboard
    with _$AutomationLanePointClipboard {
  const factory AutomationLanePointClipboard.empty() =
      AutomationLanePointClipboardEmpty;
  const factory AutomationLanePointClipboard.value({
    required double normalizedValue,
  }) = AutomationLanePointClipboardValue;
}
