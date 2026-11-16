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

/// Scrolls the timeline while a drag holds the pointer near an edge of the
/// visible track area, so an edit can reach clips outside the view.
///
/// The timeline moves under a still pointer without any pointer event, so
/// [onScrolled] reports each horizontal scroll step in pixels; the drag adds
/// it to the distance it has travelled.
class TimelineEdgeAutoScroller {
  TimelineEdgeAutoScroller({required this.onScrolled});

  final void Function(double dx) onScrolled;

  /// Width of the band along each edge that scrolls.
  static const double edgeSize = 40;

  /// Pixels scrolled per frame with the pointer on the very edge.
  static const double maxStep = 20;

  static const Duration _frame = Duration(milliseconds: 16);

  Timer? _timer;
  ScrollPosition? _horizontal;
  ScrollPosition? _vertical;
  double _stepX = 0;
  double _stepY = 0;

  /// Updates the scroll speed for the pointer at [globalPosition]. [context]
  /// is any widget inside the timeline's scroll views.
  void update(BuildContext context, Offset globalPosition) {
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
      stop();
    } else {
      _timer ??= Timer.periodic(_frame, (_) => _scroll());
    }
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
    final vertical = _vertical;
    if (vertical != null && _stepY != 0 && vertical.hasContentDimensions) {
      final target = (vertical.pixels + _stepY).clamp(
        vertical.minScrollExtent,
        vertical.maxScrollExtent,
      );
      if (target != vertical.pixels) vertical.jumpTo(target);
    }

    final horizontal = _horizontal;
    if (horizontal == null || _stepX == 0 || !horizontal.hasContentDimensions) {
      return;
    }
    final before = horizontal.pixels;
    final target = (before + _stepX).clamp(
      horizontal.minScrollExtent,
      horizontal.maxScrollExtent,
    );
    if (target == before) return;
    horizontal.jumpTo(target);
    onScrolled(horizontal.pixels - before);
  }

  /// Stops scrolling. Call when the drag ends.
  void stop() {
    _timer?.cancel();
    _timer = null;
    _stepX = 0;
    _stepY = 0;
  }
}
