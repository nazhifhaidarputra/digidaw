import 'dart:math' as math;

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/range_select_state.dart';

/// The part of the range box one timeline row draws: its tick span, and
/// whether the row carries the box's top or bottom edge.
typedef _RowSlice = ({double minTick, double maxTick, bool top, bool bottom});

/// The slice of [range] that falls on [row], or null when the range does
/// not cover it.
_RowSlice? _sliceOf(
  RangeSelectState range,
  TimelineRow row,
  IList<TimelineRow> rows,
) {
  if (!range.covers(row, rows)) return null;
  final anchor = range.anchorRow;
  final index = rows.indexOf(row);
  int first;
  int last;
  if (anchor == null) {
    first = 0;
    last = rows.length - 1;
  } else {
    final from = rows.indexOf(anchor);
    final to = rows.indexOf(range.focusRow ?? anchor);
    if (index < 0 || from < 0 || to < 0) {
      first = index;
      last = index;
    } else {
      first = math.min(from, to);
      last = math.max(from, to);
    }
  }
  return (
    minTick: range.minTick,
    maxTick: range.maxTick,
    top: index == first,
    bottom: index == last,
  );
}

/// Renders the range-selection box on one timeline row.
///
/// The box lives in the range state as absolute ticks and rows, so it stays
/// where it was drawn however the timeline scrolls. A range spanning several
/// rows is drawn as one box: each covered row paints its slice, and only the
/// first and last rows draw the top and bottom edges.
///
/// Only the part inside the visible timeline is painted. An edge that has
/// scrolled out of view is left out instead of being drawn at the viewport
/// border.
class TrackRangeSelectOverlay extends ConsumerWidget {
  final TimelineRow row;
  final double zoomLevel;

  const TrackRangeSelectOverlay({
    super.key,
    required this.row,
    required this.zoomLevel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(timelineRowsProvider);
    // Rows outside the range select null and skip rebuilding while it moves.
    final slice = ref.watch(
      rangeSelectProvider.select((s) => _sliceOf(s, row, rows)),
    );
    if (slice == null) return const Positioned.fill(child: SizedBox.shrink());

    final colors = Theme.of(context).colorScheme;
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter: _RangeBoxPainter(
            left: slice.minTick / zoomLevel,
            right: slice.maxTick / zoomLevel,
            top: slice.top,
            bottom: slice.bottom,
            scroll: Scrollable.maybeOf(
              context,
              axis: Axis.horizontal,
            )?.position,
            fill: colors.primary.withValues(alpha: 0.2),
            stroke: colors.primary,
          ),
        ),
      ),
    );
  }
}

class _RangeBoxPainter extends CustomPainter {
  _RangeBoxPainter({
    required this.left,
    required this.right,
    required this.top,
    required this.bottom,
    required this.scroll,
    required this.fill,
    required this.stroke,
  }) : super(repaint: scroll);

  static const double _strokeWidth = 2;

  /// The box's horizontal span in absolute timeline pixels.
  final double left;
  final double right;

  /// Whether this row draws the box's top and bottom edges.
  final bool top;
  final bool bottom;

  /// The timeline's horizontal scroll; repaints the visible slice on scroll.
  final ScrollPosition? scroll;

  final Color fill;
  final Color stroke;

  @override
  void paint(Canvas canvas, Size size) {
    // A box narrower than its border still shows as a line.
    final boxRight = math.max(right, left + _strokeWidth);

    var visibleLeft = 0.0;
    var visibleRight = size.width;
    final position = scroll;
    if (position != null &&
        position.hasPixels &&
        position.hasViewportDimension) {
      visibleLeft = position.pixels;
      visibleRight = position.pixels + position.viewportDimension;
    }

    final start = math.max(left, visibleLeft);
    final end = math.min(boxRight, visibleRight);
    if (end <= start) return;

    canvas.drawRect(
      Rect.fromLTRB(start, 0, end, size.height),
      Paint()..color = fill,
    );

    final border = Paint()..color = stroke;
    if (top) {
      canvas.drawRect(Rect.fromLTRB(start, 0, end, _strokeWidth), border);
    }
    if (bottom) {
      canvas.drawRect(
        Rect.fromLTRB(start, size.height - _strokeWidth, end, size.height),
        border,
      );
    }
    if (left >= visibleLeft) {
      canvas.drawRect(
        Rect.fromLTRB(left, 0, left + _strokeWidth, size.height),
        border,
      );
    }
    if (boxRight <= visibleRight) {
      canvas.drawRect(
        Rect.fromLTRB(boxRight - _strokeWidth, 0, boxRight, size.height),
        border,
      );
    }
  }

  @override
  bool shouldRepaint(_RangeBoxPainter old) =>
      old.left != left ||
      old.right != right ||
      old.top != top ||
      old.bottom != bottom ||
      old.scroll != scroll ||
      old.fill != fill ||
      old.stroke != stroke;
}
