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

    /// Lane holding the range painted with the Select tool
    int? selectionLaneId,

    /// Tick where the selected range was started
    int? selectionAnchorTick,

    /// Tick the selected range was dragged to
    int? selectionFocusTick,

    /// Lane that was last right-clicked on its timeline
    int? pasteLaneId,

    /// Tick that was right-clicked on [pasteLaneId]; where a paste lands
    int? pasteTick,
  }) = _AutomationLaneEditorState;

  const AutomationLaneEditorState._();

  /// The selected tick range of [laneId] as `(start, end)`, or null when that
  /// lane has no range.
  (int, int)? selectionOf(int laneId) {
    final anchor = selectionAnchorTick;
    final focus = selectionFocusTick;
    if (selectionLaneId != laneId || anchor == null || focus == null) {
      return null;
    }
    return anchor <= focus ? (anchor, focus) : (focus, anchor);
  }

  /// Where a curve pasted into [laneId] starts: the start of its selected
  /// range, else the tick that was right-clicked, else the project start.
  int pasteTickFor(int laneId) =>
      selectionOf(laneId)?.$1 ??
      (pasteLaneId == laneId ? pasteTick : null) ??
      0;
}

typedef AutomationPointHitbox = ({int pointId, Rect rect, Offset center});

/// Hit area of the tension handle drawn at a segment midpoint. [pointId] is
/// the segment's first point, which owns the curve type and tension.
typedef AutomationTensionHitbox = ({
  int pointId,
  int nextPointId,
  Rect rect,
  Offset center,
});

/// Hit area of one Bezier handle. [pointId] is the segment's first point,
/// which owns the handles; [isFirst] selects the handle leaving that point.
/// [anchor] is the point the handle is drawn attached to.
typedef AutomationBezierHitbox = ({
  int pointId,
  bool isFirst,
  Rect rect,
  Offset center,
  Offset anchor,
});
