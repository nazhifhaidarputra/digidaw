import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/range_select_state.dart';
import 'package:karbeat/app/providers/workspace_state.dart';
import 'package:karbeat/features/track/services/timeline_pointer.dart';
import 'package:karbeat/shared/enums/global.dart';

/// Drives every range the Select tool paints on the timeline rows.
///
/// Track rows and automation lanes start a range on pointer down. This area
/// sits above them and outside the vertical scroll view, so it adopts that
/// range and moves its end for the rest of the drag. It keeps working when
/// the row that started the range scrolls out of view and is disposed.
///
/// It also starts a range from a drag where no row is: the master and bus
/// title spacers, the automation expand bars, and the empty space below the
/// last track. Such a drag anchors on the row nearest above the pointer.
///
/// The range end is the pointer's absolute timeline position (see
/// [timelineXOf]), recomputed on every move and every auto-scroll step, so
/// the range stays where it was drawn while the view scrolls.
class TimelineRangeSelectArea extends ConsumerStatefulWidget {
  const TimelineRangeSelectArea({
    super.key,
    required this.rowNear,
    required this.child,
  });

  /// The row drawn at or nearest above [localY], in this widget's
  /// coordinates; null when the timeline has no rows.
  final TimelineRow? Function(double localY) rowNear;

  final Widget child;

  @override
  ConsumerState<TimelineRangeSelectArea> createState() =>
      _TimelineRangeSelectAreaState();
}

class _TimelineRangeSelectAreaState
    extends ConsumerState<TimelineRangeSelectArea> {
  /// Pointer pressed outside every row, waiting to move far enough to count
  /// as a drag. A press that never moves is left to the tap it lands on.
  int? _pressedPointer;
  Offset _pressPosition = Offset.zero;

  /// Pointer of the range being drawn.
  int? _rangePointer;

  late final TimelineDragTracker _tracker = TimelineDragTracker(
    onMoved: (x, globalPosition) => ref
        .read(rangeSelectProvider.notifier)
        .update(
          x * ref.read(workspaceStateProvider).horizontalZoomLevel,
          row: timelineRowAt(context, globalPosition),
        ),
  );

  @override
  void dispose() {
    _tracker.stop();
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent event) {
    if (_pressedPointer != null || _rangePointer != null) return;
    if ((event.buttons & kPrimaryButton) == 0) return;
    if (ref.read(workspaceStateProvider).selectedTool != ToolSelection.select) {
      return;
    }
    // Rows under the pointer handle the event first; adopt a range one of
    // them started.
    if (ref.read(rangeSelectProvider).isSelecting) {
      _rangePointer = event.pointer;
      return;
    }
    _pressedPointer = event.pointer;
    _pressPosition = event.position;
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_rangePointer == event.pointer) {
      _tracker.update(context, event.position);
      return;
    }
    if (_pressedPointer != event.pointer) return;
    if ((event.position - _pressPosition).distance < kPrecisePointerPanSlop) {
      return;
    }
    _pressedPointer = null;
    final box = context.findRenderObject();
    final pressX = timelineXOf(context, _pressPosition);
    if (box is! RenderBox || pressX == null) return;
    final row =
        timelineRowAt(context, _pressPosition) ??
        widget.rowNear(box.globalToLocal(_pressPosition).dy);
    if (row == null) return;
    _rangePointer = event.pointer;
    ref
        .read(rangeSelectProvider.notifier)
        .start(
          row,
          pressX * ref.read(workspaceStateProvider).horizontalZoomLevel,
        );
    _tracker.update(context, event.position);
  }

  void _onPointerUp(PointerUpEvent event) {
    if (_pressedPointer == event.pointer) _pressedPointer = null;
    if (_rangePointer != event.pointer) return;
    _tracker.update(context, event.position);
    _end();
    // The row that started the range may have ended it already, as a click.
    if (ref.read(rangeSelectProvider).isSelecting) {
      ref.read(rangeSelectProvider.notifier).finish();
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (_pressedPointer == event.pointer) _pressedPointer = null;
    if (_rangePointer != event.pointer) return;
    _end();
    ref.read(rangeSelectProvider.notifier).cancel();
  }

  void _end() {
    _rangePointer = null;
    _tracker.stop();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: widget.child,
    );
  }
}
