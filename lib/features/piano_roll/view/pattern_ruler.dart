import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/piano_roll_state.dart';
import 'package:karbeat/app/providers/transport_state.dart';
import 'package:karbeat/core/widgets/context_menu.dart';
import 'package:karbeat/shared/enums/global.dart';
import 'package:karbeat/src/rust/api/audio.dart';

/// Audio samples per 960-PPQ tick at the transport's tempo and sample rate,
/// falling back to 120 BPM at 48 kHz before the first transport update.
double patternSamplesPerTick(UiTransportFeedback? position) {
  final tempo = (position?.tempo ?? 0) > 0 ? position!.tempo : 120.0;
  final sampleRate = (position?.sampleRate ?? 0) > 0
      ? position!.sampleRate
      : 48000;
  return sampleRate * 60.0 / (tempo * 960.0);
}

/// Bar/beat ruler above the piano roll.
///
/// With the Select Region tool, dragging sets the pattern loop region and a
/// click clears it. With any other tool, clicking or dragging moves the
/// pattern playhead.
class PatternRuler extends ConsumerStatefulWidget {
  const PatternRuler({
    super.key,
    required this.scrollController,
    required this.zoomX,
  });

  final ScrollController scrollController;
  final double zoomX;

  @override
  ConsumerState<PatternRuler> createState() => _PatternRulerState();
}

class _PatternRulerState extends ConsumerState<PatternRuler> {
  int? _anchorTick;
  PatternLoopRegion? _draftRegion;

  double get _scrollOffset =>
      widget.scrollController.hasClients ? widget.scrollController.offset : 0.0;

  int _tickAt(double localX) =>
      max(0, ((localX + _scrollOffset) / widget.zoomX).round());

  int _snap(int tick) {
    final step = ref.read(pianoRollProvider).stepTicks;
    return step <= 1 ? tick : (tick / step).round() * step;
  }

  bool get _isRegionTool =>
      ref.read(pianoRollProvider).tool == PianoRollToolSelection.selectRegion;

  void _seek(double localX) {
    final samplesPerTick = patternSamplesPerTick(
      ref.read(transportPositionStreamProvider).value,
    );
    ref
        .read(pianoRollProvider.notifier)
        .seekPattern((_snap(_tickAt(localX)) * samplesPerTick).round());
  }

  void _dragStart(double localX) {
    if (_isRegionTool) {
      setState(() {
        _anchorTick = _snap(_tickAt(localX));
        _draftRegion = null;
      });
    } else {
      _seek(localX);
    }
  }

  void _dragUpdate(double localX) {
    final anchor = _anchorTick;
    if (anchor == null) {
      _seek(localX);
      return;
    }
    final tick = _snap(_tickAt(localX));
    setState(() {
      _draftRegion = PatternLoopRegion(
        startTick: min(anchor, tick),
        endTick: max(anchor, tick),
      );
    });
  }

  void _dragEnd() {
    final region = _draftRegion;
    setState(() {
      _anchorTick = null;
      _draftRegion = null;
    });
    if (region != null && region.endTick > region.startTick) {
      ref.read(pianoRollProvider.notifier).setLoopRegion(region);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final loopRegion = ref.watch(
      pianoRollProvider.select((state) => state.loopRegion),
    );
    final isRegionTool = ref.watch(
      pianoRollProvider.select(
        (state) => state.tool == PianoRollToolSelection.selectRegion,
      ),
    );

    return ContextMenuWrapper(
      title: 'Pattern loop',
      actions: [
        DawContextAction(
          title: 'Clear loop region',
          icon: Icons.clear,
          onTap: () => ref.read(pianoRollProvider.notifier).setLoopRegion(null),
        ),
        DawContextAction(
          title: 'Select Region tool',
          icon: Icons.space_bar,
          onTap: () => ref
              .read(pianoRollProvider.notifier)
              .selectPianoRollTool(PianoRollToolSelection.selectRegion),
        ),
      ],
      child: MouseRegion(
        cursor: isRegionTool
            ? SystemMouseCursors.resizeLeftRight
            : SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) {
            if (_isRegionTool) {
              ref.read(pianoRollProvider.notifier).setLoopRegion(null);
            } else {
              _seek(details.localPosition.dx);
            }
          },
          onHorizontalDragStart: (details) =>
              _dragStart(details.localPosition.dx),
          onHorizontalDragUpdate: (details) =>
              _dragUpdate(details.localPosition.dx),
          onHorizontalDragEnd: (_) => _dragEnd(),
          onHorizontalDragCancel: _dragEnd,
          child: ColoredBox(
            color: colors.surfaceContainer,
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _PatternRulerPainter(
                  scrollController: widget.scrollController,
                  zoomX: widget.zoomX,
                  loopRegion: _draftRegion ?? loopRegion,
                  loopColor: colors.secondary,
                  majorTickColor: colors.onSurface.withValues(alpha: 0.54),
                  minorTickColor: colors.onSurface.withValues(alpha: 0.24),
                  labelStyle: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontSize: 10,
                  ),
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tints the loop region across the note grid.
class PatternLoopShade extends ConsumerWidget {
  const PatternLoopShade({
    super.key,
    required this.scrollController,
    required this.zoomX,
  });

  final ScrollController scrollController;
  final double zoomX;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final region = ref.watch(
      pianoRollProvider.select((state) => state.loopRegion),
    );
    if (region == null) return const SizedBox.shrink();
    return CustomPaint(
      painter: _LoopShadePainter(
        scrollController: scrollController,
        zoomX: zoomX,
        region: region,
        color: Theme.of(context).colorScheme.secondary,
      ),
    );
  }
}

class _LoopShadePainter extends CustomPainter {
  _LoopShadePainter({
    required this.scrollController,
    required this.zoomX,
    required this.region,
    required this.color,
  }) : super(repaint: scrollController);

  final ScrollController scrollController;
  final double zoomX;
  final PatternLoopRegion region;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final offset = scrollController.hasClients ? scrollController.offset : 0.0;
    final left = region.startTick * zoomX - offset;
    final right = region.endTick * zoomX - offset;
    canvas.drawRect(
      Rect.fromLTRB(left, 0, right, size.height),
      Paint()..color = color.withValues(alpha: 0.06),
    );
    final edge = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(left, 0), Offset(left, size.height), edge);
    canvas.drawLine(Offset(right, 0), Offset(right, size.height), edge);
  }

  @override
  bool shouldRepaint(covariant _LoopShadePainter old) =>
      old.region != region ||
      old.zoomX != zoomX ||
      old.color != color ||
      old.scrollController != scrollController;
}

class _PatternRulerPainter extends CustomPainter {
  _PatternRulerPainter({
    required this.scrollController,
    required this.zoomX,
    required this.loopRegion,
    required this.loopColor,
    required this.majorTickColor,
    required this.minorTickColor,
    required this.labelStyle,
  }) : super(repaint: scrollController);

  final ScrollController scrollController;
  final double zoomX;
  final PatternLoopRegion? loopRegion;
  final Color loopColor;
  final Color majorTickColor;
  final Color minorTickColor;
  final TextStyle? labelStyle;

  @override
  void paint(Canvas canvas, Size size) {
    if (zoomX <= 0) return;

    final scrollOffset = scrollController.hasClients
        ? scrollController.positions.first.pixels
        : 0.0;

    final region = loopRegion;
    if (region != null) {
      final left = region.startTick * zoomX - scrollOffset;
      final right = region.endTick * zoomX - scrollOffset;
      canvas.drawRect(
        Rect.fromLTRB(left, 0, right, size.height),
        Paint()..color = loopColor.withValues(alpha: 0.28),
      );
      canvas.drawRect(
        Rect.fromLTRB(left, 0, right, 3),
        Paint()..color = loopColor,
      );
    }

    const ticksPerBeat = 960.0;
    const beatsPerBar = 4;
    final pixelsPerBeat = ticksPerBeat * zoomX;
    final pixelsPerBar = pixelsPerBeat * beatsPerBar;
    if (pixelsPerBeat < 1) return;

    const buffer = 200.0;
    final startPixel = (scrollOffset - buffer).clamp(0.0, double.infinity);
    final endPixel = scrollOffset + size.width + buffer;
    var barIndex = (startPixel / pixelsPerBar).floor() + 1;
    var currentX = (barIndex - 1) * pixelsPerBar;
    final lastVisibleBar = (endPixel / pixelsPerBar).ceil() + 1;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    final barLabelStep = _barLabelStep(
      textPainter: textPainter,
      lastVisibleBar: lastVisibleBar,
      pixelsPerBar: pixelsPerBar,
    );
    final majorTickPaint = Paint()
      ..color = majorTickColor
      ..strokeWidth = 1;
    final minorTickPaint = Paint()
      ..color = minorTickColor
      ..strokeWidth = 1;

    while (currentX < endPixel) {
      final viewportX = currentX - scrollOffset;
      if (currentX >= startPixel) {
        canvas.drawLine(
          Offset(viewportX, 15),
          Offset(viewportX, size.height),
          majorTickPaint,
        );

        if ((barIndex - 1) % barLabelStep == 0) {
          textPainter.text = TextSpan(text: '$barIndex', style: labelStyle);
          textPainter.layout();
          textPainter.paint(canvas, Offset(viewportX + 4, 2));
        }
      }

      if (pixelsPerBeat > 5) {
        for (var beat = 1; beat < beatsPerBar; beat++) {
          final beatX = currentX + pixelsPerBeat * beat;
          if (beatX >= startPixel && beatX < endPixel) {
            final beatViewportX = beatX - scrollOffset;
            canvas.drawLine(
              Offset(beatViewportX, 22),
              Offset(beatViewportX, size.height),
              minorTickPaint,
            );
          }
        }
      }

      currentX += pixelsPerBar;
      barIndex++;
    }
  }

  int _barLabelStep({
    required TextPainter textPainter,
    required int lastVisibleBar,
    required double pixelsPerBar,
  }) {
    var widestDigit = 0.0;
    for (var digit = 0; digit <= 9; digit++) {
      textPainter.text = TextSpan(text: '$digit', style: labelStyle);
      textPainter.layout();
      widestDigit = max(widestDigit, textPainter.width);
    }

    final widestLabel = widestDigit * lastVisibleBar.toString().length;
    final requiredSpacing = max(24.0, widestLabel + 4);
    if (pixelsPerBar >= requiredSpacing) return 1;
    if (pixelsPerBar * 2 >= requiredSpacing) return 2;
    return 4;
  }

  @override
  bool shouldRepaint(covariant _PatternRulerPainter oldDelegate) {
    return oldDelegate.scrollController != scrollController ||
        oldDelegate.zoomX != zoomX ||
        oldDelegate.loopRegion != loopRegion ||
        oldDelegate.loopColor != loopColor ||
        oldDelegate.majorTickColor != majorTickColor ||
        oldDelegate.minorTickColor != minorTickColor ||
        oldDelegate.labelStyle != labelStyle;
  }
}
