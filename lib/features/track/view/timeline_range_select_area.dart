import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/range_select_state.dart';
import 'package:karbeat/app/providers/workspace_state.dart';
import 'package:karbeat/features/track/services/timeline_pointer.dart';
import 'package:karbeat/shared/enums/global.dart';

/// Lets the Select tool paint a range from any part of the timeline.
///
/// Track rows and automation lanes start their own ranges. This catches a
/// drag that starts where no row does: the master and bus title spacers, the
/// automation expand bars, and the empty space below the last track. Such a
/// drag anchors on the row nearest above the pointer.
///
/// [child] must fill the timeline's full scrollable width, so a local x is a
/// timeline pixel.
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

  /// Pointer of the range this area started.
  int? _rangePointer;
  Offset? _lastPosition;

  late final TimelineEdgeAutoScroller _autoScroller = TimelineEdgeAutoScroller(
    onScrolled: (_) {
      final position = _lastPosition;
      if (position != null) _update(position);
    },
  );

  @override
  void dispose() {
    _autoScroller.stop();
    super.dispose();
  }

  double _tickAt(Offset globalPosition) {
    final box = context.findRenderObject();
    if (box is! RenderBox) return 0;
    final x = box.globalToLocal(globalPosition).dx;
    return x * ref.read(workspaceStateProvider).horizontalZoomLevel;
  }

  void _onPointerDown(PointerDownEvent event) {
    if (_pressedPointer != null || _rangePointer != null) return;
    if ((event.buttons & kPrimaryButton) == 0) return;
    if (ref.read(workspaceStateProvider).selectedTool != ToolSelection.select) {
      return;
    }
    // Rows under the pointer handle the event first; one that started a
    // range owns it.
    if (ref.read(rangeSelectProvider).isSelecting) return;
    _pressedPointer = event.pointer;
    _pressPosition = event.position;
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_rangePointer == event.pointer) {
      _update(event.position);
      return;
    }
    if (_pressedPointer != event.pointer) return;
    if ((event.position - _pressPosition).distance < kPrecisePointerPanSlop) {
      return;
    }
    _pressedPointer = null;
    final box = context.findRenderObject();
    if (box is! RenderBox) return;
    final row =
        timelineRowAt(context, _pressPosition) ??
        widget.rowNear(box.globalToLocal(_pressPosition).dy);
    if (row == null) return;
    _rangePointer = event.pointer;
    ref.read(rangeSelectProvider.notifier).start(row, _tickAt(_pressPosition));
    _update(event.position);
  }

  void _update(Offset globalPosition) {
    _lastPosition = globalPosition;
    _autoScroller.update(context, globalPosition);
    ref
        .read(rangeSelectProvider.notifier)
        .update(
          _tickAt(globalPosition),
          row: timelineRowAt(context, globalPosition),
        );
  }

  void _onPointerUp(PointerUpEvent event) {
    if (_pressedPointer == event.pointer) _pressedPointer = null;
    if (_rangePointer != event.pointer) return;
    _update(event.position);
    _end();
    ref.read(rangeSelectProvider.notifier).finish();
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (_pressedPointer == event.pointer) _pressedPointer = null;
    if (_rangePointer != event.pointer) return;
    _end();
    ref.read(rangeSelectProvider.notifier).cancel();
  }

  void _end() {
    _rangePointer = null;
    _lastPosition = null;
    _autoScroller.stop();
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
