import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/core/widgets/context_menu.dart';
import 'package:karbeat/features/track/services/curve_sampler.dart';
import 'package:karbeat/features/track/view/automation_point_context_menu.dart';
import 'package:karbeat/src/rust/api/automation.dart';
import 'package:karbeat/src/rust/api/project.dart';

/// One labeled value line of a [ClipCurveScale].
@immutable
class ClipCurveGridLine {
  const ClipCurveGridLine(this.value, this.label, {this.major = false});

  final double value;
  final String label;

  /// Drawn stronger, like the center of a bipolar curve.
  final bool major;
}

/// How one clip curve maps values onto the editor's height. Fractions run from
/// 0 at the bottom to 1 at the top.
@immutable
class ClipCurveScale {
  const ClipCurveScale({
    required this.curve,
    required this.color,
    required this.toFraction,
    required this.fromFraction,
    required this.format,
    required this.parse,
    required this.snap,
    required this.gridLines,
    required this.valueHint,
  });

  final UiClipCurve curve;
  final Color color;
  final double Function(double value) toFraction;
  final double Function(double fraction) fromFraction;

  /// Text of a value, with its unit.
  final String Function(double value) format;

  /// Parses what the user typed, in the unit [format] shows. Null when invalid.
  final double? Function(String text) parse;

  /// Nearest musically useful value; Shift skips it while dragging.
  final double Function(double value) snap;
  final List<ClipCurveGridLine> gridLines;

  /// Shown as the label of the typed value field.
  final String valueHint;
}

/// Draws one clip curve and edits its points in place.
///
/// Double-click to add a point, drag a point to move it, double-click a point
/// to delete it, and right-click it for its value and curve shape. Drag the
/// small ring on a segment to bend it, and double-click the ring to straighten
/// it. Dragging a point snaps to the scale's values and the project grid; hold
/// Shift for free movement. Each gesture commits once, on release.
class ClipCurveEditor extends ConsumerStatefulWidget {
  const ClipCurveEditor({
    super.key,
    required this.points,
    required this.scale,
    required this.withPoints,
    required this.contentStart,
    required this.contentLength,
    required this.snapPosition,
    required this.onCommit,
    this.markers = const [],
  });

  final List<UiCurvePoint> points;
  final ClipCurveScale scale;

  /// The whole modulation with this curve's points replaced, for sampling a
  /// drag in progress with the code the engine plays.
  final UiClipModulation Function(List<UiCurvePoint> points) withPoints;

  /// Content position of the left edge.
  final int contentStart;

  /// Content samples across the width.
  final int contentLength;

  /// Moves a content position onto the project grid.
  final int Function(int position) snapPosition;
  final Future<void> Function(List<UiCurvePoint> points) onCommit;

  /// Clip-relative samples to mark with thin vertical lines.
  final List<int> markers;

  @override
  ConsumerState<ClipCurveEditor> createState() => _ClipCurveEditorState();
}

/// In-progress vertical drag of a segment's tension handle.
typedef _TensionDrag = ({
  int index,
  double startY,
  double startTension,
  double direction,
});

class _ClipCurveEditorState extends ConsumerState<ClipCurveEditor> {
  static const double _handleSize = 14;

  /// Minimum segment width in pixels before a tension handle is offered.
  static const double _minTensionSegmentWidth = 16;

  /// Points being edited; shown instead of [ClipCurveEditor.points] until the
  /// commit lands.
  List<UiCurvePoint>? _draft;
  int? _dragIndex;
  _TensionDrag? _tensionDrag;
  int? _hoveredTensionIndex;
  Offset? _doubleTapPosition;

  List<UiCurvePoint> get _points => _draft ?? widget.points;
  bool get _isDragging => _dragIndex != null || _tensionDrag != null;

  @override
  void didUpdateWidget(covariant ClipCurveEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isDragging && oldWidget.points != widget.points) _draft = null;
  }

  double _toX(int position, double width) =>
      (position - widget.contentStart) / widget.contentLength * width;

  double _toY(double value, double height) =>
      (1 - widget.scale.toFraction(value)) * height;

  int _positionAt(double x, double width) =>
      (widget.contentStart + x / width * widget.contentLength).round().clamp(
        widget.contentStart,
        widget.contentStart + widget.contentLength,
      );

  double _valueAt(double y, double height) =>
      widget.scale.fromFraction((1 - y / height).clamp(0.0, 1.0));

  Future<void> _commit(List<UiCurvePoint> points) async {
    setState(() => _draft = points);
    await widget.onCommit(points);
    if (mounted && !_isDragging) setState(() => _draft = null);
  }

  void _addPoint(Size size) {
    final at = _doubleTapPosition;
    if (at == null) return;
    final point = UiCurvePoint(
      position: widget.snapPosition(_positionAt(at.dx, size.width)),
      value: widget.scale.snap(_valueAt(at.dy, size.height)),
      curveType: AutomationCurveTypeDto.linear,
      tension: 0,
    );
    final points = _points.where((p) => p.position != point.position).toList()
      ..add(point)
      ..sort((a, b) => a.position.compareTo(b.position));
    _commit(points);
  }

  void _deletePoint(int index) {
    final points = _points;
    _commit([
      for (var i = 0; i < points.length; i++)
        if (i != index) points[i],
    ]);
  }

  void _replacePoint(int index, UiCurvePoint next) {
    final points = _points;
    _commit([
      for (var i = 0; i < points.length; i++)
        if (i == index) next else points[i],
    ]);
  }

  void _dragTo(Offset local, Size size) {
    final index = _dragIndex;
    final draft = _draft;
    if (index == null || draft == null || index >= draft.length) return;
    final free = HardwareKeyboard.instance.isShiftPressed;
    var position = _positionAt(local.dx, size.width);
    var value = _valueAt(local.dy, size.height);
    if (!free) {
      position = widget.snapPosition(position);
      value = widget.scale.snap(value);
    }
    // Stay between the neighbours so the points remain sorted.
    final lower = index > 0
        ? draft[index - 1].position + 1
        : widget.contentStart;
    final upper = index < draft.length - 1
        ? draft[index + 1].position - 1
        : widget.contentStart + widget.contentLength;
    setState(() {
      _draft = [
        for (var i = 0; i < draft.length; i++)
          if (i == index)
            draft[i].copyWith(
              position: position.clamp(lower, math.max(lower, upper)),
              value: value,
            )
          else
            draft[i],
      ];
    });
  }

  void _endDrag() {
    final draft = _draft;
    setState(() => _dragIndex = null);
    if (draft != null) _commit(draft);
  }

  void _startTensionDrag(int index, double startY) {
    final points = _points;
    final from = points[index];
    setState(() {
      _draft = points;
      _tensionDrag = (
        index: index,
        startY: startY,
        startTension: from.tension,
        direction: tensionDragDirection(
          ref.read(curveSamplerProvider).traits(from.curveType),
          from.curveType,
          points[index + 1].value - from.value,
        ),
      );
    });
  }

  void _updateTensionDrag(double y, double height) {
    final drag = _tensionDrag;
    final draft = _draft;
    if (drag == null || draft == null) return;
    // Dragging the full height sweeps the whole -1..1 tension range.
    final delta = (drag.startY - y) / height * 2.0;
    final tension = (drag.startTension + delta * drag.direction).clamp(
      -1.0,
      1.0,
    );
    setState(() {
      _draft = [
        for (var i = 0; i < draft.length; i++)
          if (i == drag.index)
            draft[i].copyWith(tension: tension)
          else
            draft[i],
      ];
    });
  }

  void _endTensionDrag() {
    final drag = _tensionDrag;
    final draft = _draft;
    setState(() => _tensionDrag = null);
    if (drag == null || draft == null) return;
    if (draft[drag.index].tension == drag.startTension) {
      setState(() => _draft = null);
      return;
    }
    _commit(draft);
  }

  /// Text of the tension being dragged: the count for count-driven curves.
  String _tensionText(CurveSampler sampler, UiCurvePoint point) =>
      sampler.traits(point.curveType).tensionIsCount
      ? 'Count ${sampler.tensionCount(point.tension)}'
      : 'Tension ${point.tension.toStringAsFixed(2)}';

  /// One ring per segment whose curve responds to tension, on the curve at the
  /// segment's midpoint.
  List<Widget> _buildTensionHandles(
    CurveSampler sampler,
    List<UiCurvePoint> points,
    Size size,
  ) {
    final segments = [
      for (var i = 0; i < points.length - 1; i++)
        if (sampler.traits(points[i].curveType).supportsTension &&
            _toX(points[i + 1].position, size.width) -
                    _toX(points[i].position, size.width) >=
                _minTensionSegmentWidth)
          i,
    ];
    if (segments.isEmpty) return const [];
    final midpoints = [
      for (final i in segments)
        (points[i].position + points[i + 1].position) / 2,
    ];
    final values = sampler.sampleClipModulation(
      widget.withPoints(points),
      widget.scale.curve,
      midpoints,
    );
    final color = widget.scale.color;
    return [
      for (var n = 0; n < segments.length; n++)
        Positioned(
          left:
              (midpoints[n] - widget.contentStart) /
                  widget.contentLength *
                  size.width -
              _handleSize / 2,
          top: _toY(values[n], size.height) - _handleSize / 2,
          width: _handleSize,
          height: _handleSize,
          child: _buildTensionHandle(segments[n], size, color),
        ),
    ];
  }

  Widget _buildTensionHandle(int index, Size size, Color color) {
    final active =
        _tensionDrag?.index == index || _hoveredTensionIndex == index;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeUpDown,
      onEnter: (_) => setState(() => _hoveredTensionIndex = index),
      onExit: (_) {
        if (_hoveredTensionIndex != index) return;
        setState(() => _hoveredTensionIndex = null);
      },
      child: Tooltip(
        message: tensionHandleTooltip,
        waitDuration: const Duration(milliseconds: 600),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onDoubleTap: () =>
              _replacePoint(index, _points[index].copyWith(tension: 0)),
          onPanStart: (details) {
            final box = context.findRenderObject() as RenderBox?;
            if (box == null) return;
            _startTensionDrag(
              index,
              box.globalToLocal(details.globalPosition).dy,
            );
          },
          onPanUpdate: (details) {
            final box = context.findRenderObject() as RenderBox?;
            if (box == null) return;
            _updateTensionDrag(
              box.globalToLocal(details.globalPosition).dy,
              size.height,
            );
          },
          onPanEnd: (_) => _endTensionDrag(),
          onPanCancel: () => setState(() {
            _tensionDrag = null;
            _draft = null;
          }),
          child: Center(
            child: Container(
              width: active ? 10 : 7,
              height: active ? 10 : 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: active ? color.withValues(alpha: 0.3) : null,
                border: Border.all(color: color, width: active ? 2 : 1.25),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _typeValue(int index) async {
    final point = _points[index];
    final controller = TextEditingController(
      text: widget.scale.format(point.value).split(' ').first,
    );
    final text = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Set value'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: widget.scale.valueHint,
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (value) => Navigator.pop(dialogContext, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Set'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (text == null || !mounted) return;
    final value = widget.scale.parse(text);
    if (value != null) _replacePoint(index, point.copyWith(value: value));
  }

  void _openPointMenu(int index) {
    final point = _points[index];
    final sampler = ref.read(curveSamplerProvider);
    final colors = Theme.of(context).colorScheme;
    showDawContextMenu(
      context: context,
      title: 'Curve point',
      header: Text(
        widget.scale.format(point.value),
        style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
      ),
      actions: [
        DawContextAction(
          title: 'Set value',
          icon: Icons.edit,
          onTap: () => _typeValue(index),
        ),
        DawContextAction.submenu(
          title: 'Curve type',
          subtitle: automationCurveTypeLabel(point.curveType),
          icon: automationCurveTypeIcon(point.curveType),
          children: [
            // Clip curves have no Bezier handles.
            for (final curveType in automationCurveTypeMenuOrder)
              if (!sampler.traits(curveType).usesHandles)
                DawContextAction(
                  title: automationCurveTypeLabel(curveType),
                  icon: point.curveType == curveType
                      ? Icons.check
                      : automationCurveTypeIcon(curveType),
                  color: point.curveType == curveType ? colors.primary : null,
                  onTap: () => _replacePoint(
                    index,
                    point.copyWith(curveType: curveType),
                  ),
                ),
          ],
        ),
        if (point.tension != 0 &&
            sampler.traits(point.curveType).supportsTension)
          DawContextAction(
            title: sampler.traits(point.curveType).tensionIsCount
                ? 'Reset count'
                : 'Reset tension',
            icon: Icons.restart_alt,
            onTap: () => _replacePoint(index, point.copyWith(tension: 0)),
          ),
        DawContextAction(
          title: 'Delete point',
          icon: Icons.delete_outline,
          isDestructive: true,
          onTap: () => _deletePoint(index),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        if (widget.contentLength <= 0 || size.isEmpty) {
          return const SizedBox.shrink();
        }
        final points = _points;
        final sampler = ref.read(curveSamplerProvider);
        final tensionDrag = _tensionDrag;
        final sampleCount = math.max(2, size.width ~/ 3);
        final positions = [
          for (var i = 0; i < sampleCount; i++)
            widget.contentStart + i / (sampleCount - 1) * widget.contentLength,
        ];
        final values = points.isEmpty
            ? const <double>[]
            : sampler.sampleClipModulation(
                widget.withPoints(points),
                widget.scale.curve,
                positions,
              );
        final dragIndex = _dragIndex;
        final dragText = tensionDrag != null
            ? _tensionText(sampler, points[tensionDrag.index])
            : dragIndex != null && dragIndex < points.length
            ? widget.scale.format(points[dragIndex].value)
            : null;
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onDoubleTapDown: (details) =>
              _doubleTapPosition = details.localPosition,
          onDoubleTap: () => _addPoint(size),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _ClipCurvePainter(
                    values: values,
                    scale: widget.scale,
                    markers: widget.markers,
                    contentLength: widget.contentLength,
                    gridColor: colors.outlineVariant,
                    labelColor: colors.onSurfaceVariant,
                  ),
                ),
              ),
              if (points.isEmpty)
                Center(
                  child: Text(
                    'Double-click to add the first point',
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ),
              // Under the points, which win where the two overlap.
              ..._buildTensionHandles(sampler, points, size),
              for (var i = 0; i < points.length; i++)
                Positioned(
                  left: _toX(points[i].position, size.width) - _handleSize / 2,
                  top: _toY(points[i].value, size.height) - _handleSize / 2,
                  width: _handleSize,
                  height: _handleSize,
                  child: Tooltip(
                    message: widget.scale.format(points[i].value),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.move,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onDoubleTap: () => _deletePoint(i),
                        onSecondaryTap: () => _openPointMenu(i),
                        onLongPress: () => _openPointMenu(i),
                        onPanStart: (_) => setState(() {
                          _dragIndex = i;
                          _draft = points;
                        }),
                        onPanUpdate: (details) {
                          final box = context.findRenderObject() as RenderBox?;
                          if (box == null) return;
                          _dragTo(
                            box.globalToLocal(details.globalPosition),
                            size,
                          );
                        },
                        onPanEnd: (_) => _endDrag(),
                        onPanCancel: () => setState(() {
                          _dragIndex = null;
                          _draft = null;
                        }),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: dragIndex == i
                                ? colors.onSurface
                                : widget.scale.color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: colors.surface,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              if (dragText != null)
                Positioned(
                  left: 8,
                  top: 8,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Text(
                        dragText,
                        style: TextStyle(color: colors.onSurface, fontSize: 12),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ClipCurvePainter extends CustomPainter {
  _ClipCurvePainter({
    required this.values,
    required this.scale,
    required this.markers,
    required this.contentLength,
    required this.gridColor,
    required this.labelColor,
  });

  final List<double> values;
  final ClipCurveScale scale;
  final List<int> markers;
  final int contentLength;
  final Color gridColor;
  final Color labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..strokeWidth = 1
      ..color = gridColor.withValues(alpha: 0.5);
    final major = Paint()
      ..strokeWidth = 1
      ..color = gridColor;
    for (final gridLine in scale.gridLines) {
      final y = (1 - scale.toFraction(gridLine.value)) * size.height;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        gridLine.major ? major : line,
      );
      final text = TextPainter(
        text: TextSpan(
          text: gridLine.label,
          style: TextStyle(color: labelColor, fontSize: 9),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, Offset(size.width - text.width - 4, y - text.height));
      text.dispose();
    }

    final marker = Paint()
      ..strokeWidth = 1
      ..color = scale.color.withValues(alpha: 0.35);
    for (final start in markers) {
      final x = start / contentLength * size.width;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), marker);
    }

    if (values.length < 2) return;
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = i / (values.length - 1) * size.width;
      final y = (1 - scale.toFraction(values[i])) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = scale.color,
    );
  }

  @override
  bool shouldRepaint(covariant _ClipCurvePainter oldDelegate) =>
      oldDelegate.values != values ||
      oldDelegate.scale != scale ||
      oldDelegate.markers != markers ||
      oldDelegate.contentLength != contentLength ||
      oldDelegate.gridColor != gridColor ||
      oldDelegate.labelColor != labelColor;
}
