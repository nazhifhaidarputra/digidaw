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
  bool _isDragging = false;
  int _dragSamples = 0;
  int _lastKnownSamples = 0;

  int get _dragTarget =>
      widget.snapPosition?.call(_dragSamples) ?? _dragSamples;

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
    final positionAsync = ref.watch(transportPositionStreamProvider);
    ref.listen(transportPositionStreamProvider, (previous, next) {
      final position = next.value;
      if (position == null) return;
      _followPlayhead(previous?.value, position);
    });

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = constraints.maxWidth;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            if (positionAsync.hasValue && positionAsync.value != null)
              Builder(
                builder: (context) {
                  final pos = positionAsync.value!;
                  _lastKnownSamples = widget.sampleSelector(pos);

                  // If the user is actively dragging, use their finger position.
                  // Otherwise, snap to the actual engine position.
                  final currentSamples = _isDragging
                      ? _dragTarget
                      : _lastKnownSamples;

                  double playheadAbsoluteX = 0;
                  if (widget.zoomLevel > 0) {
                    playheadAbsoluteX = currentSamples / widget.zoomLevel;
                  }

                  return AnimatedBuilder(
                    animation: widget.scrollController,
                    builder: (context, child) {
                      double scrollOffset = 0;
                      if (widget.scrollController.hasClients) {
                        scrollOffset = widget.scrollController.offset;
                      }

                      // Calculate Screen X
                      final double left =
                          widget.offsetAdjustment +
                          playheadAbsoluteX -
                          scrollOffset;

                      // Optimization: Don't render if completely off-screen
                      if (left > viewportWidth + 50) return const SizedBox();

                      // Hide if it goes behind the header/offset (scrolled too far left)
                      if (left < widget.offsetAdjustment) {
                        return const SizedBox();
                      }

                      return Positioned(
                        left: left - 10, // Center the 20px wide handle
                        top: 0,
                        bottom: 0,
                        width: 20, // Hitbox
                        child: Column(
                          children: [
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onHorizontalDragStart: (details) {
                                setState(() {
                                  _isDragging = true;
                                  _dragSamples = currentSamples;
                                });
                              },
                              onHorizontalDragUpdate: (details) {
                                // Update local state instantly for buttery smooth UI
                                setState(() {
                                  final deltaSamples =
                                      (details.delta.dx * widget.zoomLevel)
                                          .toInt();
                                  _dragSamples += deltaSamples;
                                  if (_dragSamples < 0) {
                                    _dragSamples = 0; // Prevent negative time
                                  }
                                });
                              },
                              onHorizontalDragEnd: (details) {
                                widget.onSeek(_dragTarget);
                                setState(() {
                                  _isDragging = false;
                                });
                              },
                              onHorizontalDragCancel: () {
                                setState(() {
                                  _isDragging = false;
                                });
                              },
                              child: SizedBox(
                                height: 20,
                                width: 20,
                                child: CustomPaint(
                                  painter: _PlayheadHandlePainter(color),
                                ),
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
                      );
                    },
                  );
                },
              ),
          ],
        );
      },
    );
  }
}
