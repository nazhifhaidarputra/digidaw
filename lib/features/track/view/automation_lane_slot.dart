import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/app_state.dart';
import 'package:karbeat/features/track/view/grid_painter.dart';
import 'package:karbeat/src/rust/api/automation.dart';
import 'automation_curve_painter.dart';

class AutomationLaneSlot extends ConsumerWidget {
  final AutomationLaneDto lane;
  final double height;
  final ScrollController horizontalScrollController;
  final Color trackColor;
  final int sampleRate;

  const AutomationLaneSlot({
    super.key,
    required this.lane,
    required this.height,
    required this.horizontalScrollController,
    required this.trackColor,
    required this.sampleRate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(globalStateProvider);
    final zoomLevel = state.horizontalZoomLevel;
    final gridSize = state.gridSize;
    final tempo = state.tempo;
    final safeSampleRate = sampleRate <= 0 ? 48000 : sampleRate;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(80), // Slightly darker than main track
        border: Border(
          bottom: BorderSide(color: Colors.white.withAlpha(16), width: 1),
          right: BorderSide(color: Colors.white.withAlpha(16), width: 1),
        ),
      ),
      child: Stack(
        children: [
          // 1. Background Grid
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: GridPainter(
                  zoomLevel: zoomLevel,
                  gridSize: gridSize,
                  tempo: tempo,
                  sampleRate: safeSampleRate,
                  scrollController: horizontalScrollController,
                ),
              ),
            ),
          ),
          
          // 2. Automation Curve Overlay
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: AutomationCurvePainter(
                  lane: lane,
                  zoomLevel: zoomLevel,
                  scrollController: horizontalScrollController,
                  trackColor: trackColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}