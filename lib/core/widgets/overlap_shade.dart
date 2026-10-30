import 'package:flutter/material.dart';

/// A half-open `[start, end)` range on a single lane, such as one piano key or
/// one track.
typedef LaneSpan = ({int start, int end});

/// Returns every range where two of [spans] overlap.
///
/// Each overlapping pair yields its own range, so a region covered by three
/// spans is reported more than once and its shade builds up darker.
List<LaneSpan> overlapSpans(Iterable<LaneSpan> spans) {
  final sorted = spans.where((s) => s.end > s.start).toList()
    ..sort((a, b) => a.start.compareTo(b.start));
  final overlaps = <LaneSpan>[];
  for (var i = 0; i < sorted.length; i++) {
    final current = sorted[i];
    for (var j = i + 1; j < sorted.length; j++) {
      final next = sorted[j];
      if (next.start >= current.end) break;
      final end = next.end < current.end ? next.end : current.end;
      overlaps.add((start: next.start, end: end));
    }
  }
  return overlaps;
}

/// Hatched shading that marks where notes or clips are stacked on top of each
/// other, so fully hidden duplicates stay visible. Ignores pointer input so
/// the items underneath keep their gestures.
class OverlapShade extends StatelessWidget {
  const OverlapShade({super.key});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.error;
    return IgnorePointer(
      child: CustomPaint(painter: _OverlapShadePainter(color)),
    );
  }
}

class _OverlapShadePainter extends CustomPainter {
  _OverlapShadePainter(this.color);

  final Color color;

  static const double _hatchSpacing = 6;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = color.withValues(alpha: 0.18));

    canvas.save();
    canvas.clipRect(rect);
    final hatch = Paint()
      ..color = color.withValues(alpha: 0.7)
      ..strokeWidth = 1;
    for (var x = -size.height; x < size.width; x += _hatchSpacing) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        hatch,
      );
    }
    canvas.restore();

    canvas.drawRect(
      rect.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = color.withValues(alpha: 0.9),
    );
  }

  @override
  bool shouldRepaint(_OverlapShadePainter oldDelegate) =>
      oldDelegate.color != color;
}
