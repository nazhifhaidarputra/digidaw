import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/src/rust/api/audio.dart';

// 1. Swap the import to your decoupled transport provider
import 'package:karbeat/app/providers/transport_state.dart';
import 'package:karbeat/app/providers/workspace_state.dart';

/// Gap kept between the viewport's left edge and the playhead after a page flip.
const double _followLeadIn = 40.0;

/// The scroll offset that brings a playhead at [playheadX] back into view, or
/// null while it is still inside the viewport.
double? followPageScrollOffset({
  required double playheadX,
  required double scrollOffset,
  required double viewportWidth,
  required double maxScrollExtent,
}) {
  if (playheadX >= scrollOffset && playheadX <= scrollOffset + viewportWidth) {
    return null;
  }
  return (playheadX - _followLeadIn).clamp(0.0, maxScrollExtent);
}

class _PlayheadHandlePainter extends CustomPainter {
  final Color color;

  const _PlayheadHandlePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, 0); // Top Left
    path.lineTo(size.width, 0); // Top Right
    path.lineTo(size.width / 2, size.height); // Bottom Center
    path.close();

    canvas.drawPath(path, paint);
    canvas.drawShadow(path, color.withValues(alpha: 0.4), 2.0, false);
  }

  @override
  bool shouldRepaint(covariant _PlayheadHandlePainter oldDelegate) =>
      oldDelegate.color != color;
}

class PlayheadOverlay extends ConsumerStatefulWidget {
  /// Amount of pixels to offset the draw start (e.g. for Headers)
  final double offsetAdjustment;
  final ScrollController scrollController;
  final Function(int samples) onSeek;

  /// The current zoom level (pixels per sample)
  final double zoomLevel;

  /// Logic to determine which sample count to display (Song vs Pattern)
  final int Function(UiTransportFeedback) sampleSelector;

  final bool isInteracting;

  /// Snaps a dragged position before it is shown and seeked to, such as to
  /// the grid while snap-to-grid is on. The drag itself accumulates unsnapped.
  final int Function(int position)? snapPosition;

  const PlayheadOverlay({
    super.key,
    required this.offsetAdjustment,
    required this.scrollController,
    required this.onSeek,
    required this.zoomLevel,
    required this.sampleSelector,
    this.isInteracting = false,
    this.snapPosition,
  });

  @override
  ConsumerState<PlayheadOverlay> createState() => _PlayheadOverlayState();
}

class _PlayheadOverlayState extends ConsumerState<PlayheadOverlay> {
  /// Latest engine position. The playhead is painted from these notifiers, so
  /// playback and scrolling move it without rebuilding or laying out.
  final _position = ValueNotifier<UiTransportFeedback?>(null);

  /// Unsnapped position of an active handle drag, or null when not dragging.
  final _dragSamples = ValueNotifier<int?>(null);

  bool get _isDragging => _dragSamples.value != null;

  int get _dragTarget {
    final samples = _dragSamples.value ?? 0;
    return widget.snapPosition?.call(samples) ?? samples;
  }

  /// The position the playhead shows: the drag while dragging, otherwise the
  /// engine's. Null before the engine reports one.
  int? get _shownSamples {
    if (_isDragging) return _dragTarget;
    final position = _position.value;
    return position == null ? null : widget.sampleSelector(position);
  }

  /// Screen x of the playhead line, or null when there is none to show.
  double? _playheadLeft() {
    final samples = _shownSamples;
    if (samples == null) return null;
    final absoluteX = widget.zoomLevel > 0 ? samples / widget.zoomLevel : 0.0;
    final scrollOffset = widget.scrollController.hasClients
        ? widget.scrollController.offset
        : 0.0;
    return widget.offsetAdjustment + absoluteX - scrollOffset;
  }

  @override
  void initState() {
    super.initState();
    final subscription = ref.listenManual(transportPositionStreamProvider, (
      previous,
      next,
    ) {
      final position = next.value;
      _position.value = position;
      if (position == null) return;
      _followPlayhead(previous?.value, position);
    });
    _position.value = subscription.read().value;
  }

  @override
  void dispose() {
    _position.dispose();
    _dragSamples.dispose();
    super.dispose();
  }

  /// Page-flips the view when the playhead moves out of it while following.
  void _followPlayhead(
    UiTransportFeedback? previous,
    UiTransportFeedback next,
  ) {
    final samples = widget.sampleSelector(next);
    if (previous != null && widget.sampleSelector(previous) == samples) return;
    _scrollToPlayhead(samples);
  }

  /// Scrolls to the playhead at [samples] when it is out of view, or
  /// regardless when [finishingFlip] continues a flip that fell short.
  void _scrollToPlayhead(int samples, {bool finishingFlip = false}) {
    if (!mounted || _isDragging || widget.zoomLevel <= 0) return;
    if (!ref.read(workspaceStateProvider).followPlayhead) return;
    if (!widget.scrollController.hasClients) return;

    final position = widget.scrollController.position;
    final playheadX = samples / widget.zoomLevel;
    final maxScrollExtent = position.maxScrollExtent;
    final target = followPageScrollOffset(
      playheadX: playheadX,
      // An offset the playhead is never inside, so the flip always resolves.
      scrollOffset: finishingFlip ? double.infinity : position.pixels,
      viewportWidth: position.viewportDimension,
      maxScrollExtent: maxScrollExtent,
    );
    if (target == null) return;
    if (target != position.pixels) widget.scrollController.jumpTo(target);

    // The jump stopped at the end of the laid-out timeline. Scrolling there
    // makes the timeline grow, so finish the flip once it has.
    if (playheadX - _followLeadIn > maxScrollExtent) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !widget.scrollController.hasClients) return;
        if (widget.scrollController.position.maxScrollExtent >
            maxScrollExtent) {
          _scrollToPlayhead(samples, finishingFlip: true);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.tertiary;

    // The playhead moves every frame during playback; keep that repaint off
    // the content below.
    return RepaintBoundary(
      child: Flow(
        clipBehavior: Clip.none,
        delegate: _PlayheadFlowDelegate(
          playheadLeft: _playheadLeft,
          offsetAdjustment: widget.offsetAdjustment,
          repaint: Listenable.merge([
            _position,
            _dragSamples,
            widget.scrollController,
          ]),
        ),
        children: [
          Column(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: (_) {
                  _dragSamples.value = _shownSamples ?? 0;
                },
                onHorizontalDragUpdate: (details) {
                  final deltaSamples = (details.delta.dx * widget.zoomLevel)
                      .toInt();
                  final next = (_dragSamples.value ?? 0) + deltaSamples;
                  _dragSamples.value = next < 0 ? 0 : next; // No negative time
                },
                onHorizontalDragEnd: (_) {
                  widget.onSeek(_dragTarget);
                  _dragSamples.value = null;
                },
                onHorizontalDragCancel: () {
                  _dragSamples.value = null;
                },
                child: SizedBox(
                  height: 20,
                  width: 20,
                  child: CustomPaint(painter: _PlayheadHandlePainter(color)),
                ),
              ),
              Expanded(
                child: Container(
                  width: 1.5,
                  color: color.withValues(
                    alpha: widget.isInteracting ? 0.4 : 0.8,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Places the 20px-wide playhead (handle and line) at the current position
/// during paint. A paint-time transform also moves the hit area, and children
/// that aren't painted aren't hit, so a hidden playhead can't be dragged.
class _PlayheadFlowDelegate extends FlowDelegate {
  _PlayheadFlowDelegate({
    required this.playheadLeft,
    required this.offsetAdjustment,
    required super.repaint,
  });

  final double? Function() playheadLeft;
  final double offsetAdjustment;

  @override
  BoxConstraints getConstraintsForChild(int i, BoxConstraints constraints) =>
      BoxConstraints.tightFor(width: 20, height: constraints.maxHeight);

  @override
  void paintChildren(FlowPaintingContext context) {
    final left = playheadLeft();
    if (left == null) return;
    // Off the right edge, or behind the header (scrolled too far left).
    if (left > context.size.width + 50 || left < offsetAdjustment) return;
    // Center the 20px wide handle on the line.
    context.paintChild(
      0,
      transform: Matrix4.translationValues(left - 10, 0, 0),
    );
  }

  // The widget rebuilds only when its inputs change, and the position lives
  // in the repaint listenables, so a repaint on rebuild is always warranted.
  @override
  bool shouldRepaint(_PlayheadFlowDelegate oldDelegate) => true;
}
