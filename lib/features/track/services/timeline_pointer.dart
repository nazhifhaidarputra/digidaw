import 'dart:async';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:karbeat/app/providers/range_select_state.dart';

/// Marks [child] as the timeline row [row], so a drag that leaves the row it
/// started on can find the row under the pointer.
class TimelineRowMarker extends StatelessWidget {
  const TimelineRowMarker({super.key, required this.row, required this.child});

  final TimelineRow row;
  final Widget child;

  @override
  Widget build(BuildContext context) => MetaData(
    metaData: row,
    behavior: HitTestBehavior.translucent,
    child: child,
  );
}

/// The visible rect of the nearest [axis] scroll view around [context], in
/// global coordinates.
Rect? _viewportRect(BuildContext context, Axis axis) {
  final scrollable = Scrollable.maybeOf(context, axis: axis);
  final box = scrollable?.context.findRenderObject();
  if (box is! RenderBox || !box.hasSize) return null;
  return box.localToGlobal(Offset.zero) & box.size;
}

/// The timeline row at the height of [globalPosition], or null when no row is
/// there. The position is moved inside the visible timeline first, so a
/// pointer over the track headers still finds the row beside it.
TimelineRow? timelineRowAt(BuildContext context, Offset globalPosition) {
  final viewport = _viewportRect(context, Axis.horizontal);
  final position = viewport == null
      ? globalPosition
      : Offset(
          globalPosition.dx.clamp(viewport.left + 1, viewport.right - 1),
          globalPosition.dy,
        );
  final result = HitTestResult();
  WidgetsBinding.instance.hitTestInView(
    result,
    position,
    View.of(context).viewId,
  );
  for (final entry in result.path) {
    final target = entry.target;
    if (target is RenderMetaData) {
      final row = target.metaData;
      if (row is TimelineRow) return row;
    }
  }
  return null;
}

/// The absolute timeline pixel under [globalPosition]: the pointer's x in the
/// visible part of the nearest horizontal scroll view, plus how far that view
/// is scrolled. Null when [context] is not inside a horizontal scroll view.
///
/// A drag must use this instead of a pointer event's local position. Flutter
/// keeps the transform from the pointer-down hit test for the whole gesture,
/// so once the timeline scrolls the local position is off by the scrolled
/// distance.
double? timelineXOf(BuildContext context, Offset globalPosition) {
  final scrollable = Scrollable.maybeOf(context, axis: Axis.horizontal);
  final box = scrollable?.context.findRenderObject();
  if (scrollable == null || box is! RenderBox || !box.hasSize) return null;
  return box.globalToLocal(globalPosition).dx + scrollable.position.pixels;
}

/// Follows a timeline drag in absolute timeline pixels and scrolls the
/// timeline while the pointer is held near an edge of the visible track area,
/// so an edit can reach items outside the view.
///
/// [onMoved] gets the pointer's absolute timeline x (see [timelineXOf]) and
/// its global position on every [update], and again after each auto-scroll
/// step, since the timeline then moves under a still pointer. A drag stores
/// where it started in the same coordinates and derives its state from the
/// two, so scrolling never shifts it.
class TimelineDragTracker {
  TimelineDragTracker({required this.onMoved});

  final void Function(double timelineX, Offset globalPosition) onMoved;

  /// Width of the band along each edge that scrolls.
  static const double edgeSize = 40;

  /// Pixels scrolled per frame with the pointer on the very edge.
  static const double maxStep = 20;

  static const Duration _frame = Duration(milliseconds: 16);

  Timer? _timer;
  BuildContext? _context;
  Offset? _globalPosition;
  ScrollPosition? _horizontal;
  ScrollPosition? _vertical;
  double _stepX = 0;
  double _stepY = 0;

  /// Moves the drag to the pointer at [globalPosition], reports it through
  /// [onMoved], and sets the scroll speed. [context] is any widget inside the
  /// timeline's scroll views.
  void update(BuildContext context, Offset globalPosition) {
    _context = context;
    _globalPosition = globalPosition;
    _horizontal = Scrollable.maybeOf(context, axis: Axis.horizontal)?.position;
    _vertical = Scrollable.maybeOf(context, axis: Axis.vertical)?.position;
    final horizontalRect = _viewportRect(context, Axis.horizontal);
    final verticalRect = _viewportRect(context, Axis.vertical);
    _stepX = horizontalRect == null
        ? 0
        : _step(globalPosition.dx, horizontalRect.left, horizontalRect.right);
    _stepY = verticalRect == null
        ? 0
        : _step(globalPosition.dy, verticalRect.top, verticalRect.bottom);

    if (_stepX == 0 && _stepY == 0) {
      _stopTimer();
    } else {
      _timer ??= Timer.periodic(_frame, (_) => _scroll());
    }
    _emit();
  }

  void _emit() {
    final context = _context;
    final globalPosition = _globalPosition;
    if (context == null || globalPosition == null || !context.mounted) return;
    final x = timelineXOf(context, globalPosition);
    if (x != null) onMoved(x, globalPosition);
  }

  double _step(double pointer, double start, double end) {
    if (pointer < start + edgeSize) {
      return -maxStep * ((start + edgeSize - pointer) / edgeSize).clamp(0, 1);
    }
    if (pointer > end - edgeSize) {
      return maxStep * ((pointer - (end - edgeSize)) / edgeSize).clamp(0, 1);
    }
    return 0;
  }

  void _scroll() {
    final scrolledY = _scrollBy(_vertical, _stepY);
    final scrolledX = _scrollBy(_horizontal, _stepX);
    if (scrolledX || scrolledY) _emit();
  }

  /// Scrolls [position] by [step] within its extent; whether it moved.
  static bool _scrollBy(ScrollPosition? position, double step) {
    if (position == null || step == 0 || !position.hasContentDimensions) {
      return false;
    }
    final target = (position.pixels + step).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (target == position.pixels) return false;
    position.jumpTo(target);
    return true;
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
    _stepX = 0;
    _stepY = 0;
  }

  /// Ends the drag and stops scrolling.
  void stop() {
    _stopTimer();
    _context = null;
    _globalPosition = null;
  }
}
