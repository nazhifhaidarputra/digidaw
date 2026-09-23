import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:karbeat/features/track/models/automation_lane_clipboard.dart';

part 'automation_lane_editor.freezed.dart';

/// Class which defined AutomationLaneEditorState to
/// Know which automation point we interact
@freezed
abstract class AutomationLaneEditorState with _$AutomationLaneEditorState {
  const factory AutomationLaneEditorState({
    /// The ID of the hovered automation lane
    int? hoveredLaneId,

    /// The ID of the hovererd point in an automation lane
    int? hoveredPointId,

    /// The currently opened context automation lane ID
    int? contextLaneId,

    /// The currently opened context automation point ID
    int? contextPointId,

    /// The clipboard for automation lane point value
    @Default(AutomationLanePointClipboard.empty())
    AutomationLanePointClipboard clipboard,
  }) = _AutomationLaneEditorState;
}

typedef AutomationPointHitbox = ({int pointId, Rect rect, Offset center});
