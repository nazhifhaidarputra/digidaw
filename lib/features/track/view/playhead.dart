import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/src/rust/api/audio.dart';

// 1. Swap the import to your decoupled transport provider
import 'package:karbeat/app/providers/transport_state.dart';

class _PlayheadHandlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.yellowAccent
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, 0); // Top Left
    path.lineTo(size.width, 0); // Top Right
    path.lineTo(size.width / 2, size.height); // Bottom Center
    path.close();

    canvas.drawPath(path, paint);
    canvas.drawShadow(path, Colors.black, 2.0, false);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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

  const PlayheadOverlay({
    super.key,
    required this.offsetAdjustment,
    required this.scrollController,
    required this.onSeek,
    required this.zoomLevel,
    required this.sampleSelector,
    this.isInteracting = false,
  });

  @override
  ConsumerState<PlayheadOverlay> createState() => _PlayheadOverlayState();
}

class _PlayheadOverlayState extends ConsumerState<PlayheadOverlay> {
  bool _isDragging = false;
  int _dragSamples = 0;
  int _lastKnownSamples = 0;

  // UiTransportFeedback? _lastProcessedFeedback;

  @override
  Widget build(BuildContext context) {
    final positionAsync = ref.watch(transportPositionStreamProvider);

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
                      ? _dragSamples
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
                      if (left < widget.offsetAdjustment)
                        return const SizedBox();

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
                                widget.onSeek(_dragSamples);
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
                                  painter: _PlayheadHandlePainter(),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Container(
                                width: 1.5,
                                color: Colors.yellowAccent.withAlpha(
                                  // If the user is zooming/panning the screen, dim the playhead slightly to indicate interaction
                                  widget.isInteracting ? 100 : 204,
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
