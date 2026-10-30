import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/recording_state.dart';
import 'package:karbeat/app/providers/transport_state.dart';
import 'package:karbeat/core/utils/clip_time_utils.dart';
import 'package:karbeat/features/track/view/waveform_painter.dart';

/// The take a track is recording, drawn as a ghost clip from where the take
/// started to what it has recorded so far, with its waveform.
class TrackRecordingGhost extends ConsumerWidget {
  final int trackId;
  final double trackHeight;

  /// Ticks per pixel of the timeline.
  final double zoomLevel;

  const TrackRecordingGhost({
    super.key,
    required this.trackId,
    required this.trackHeight,
    required this.zoomLevel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final take = ref.watch(
      recordingProvider.select((state) => state.takes[trackId]),
    );
    final startSamples = take?.startSamples;
    // The lane's Stack sizes itself from its non-positioned children, so this
    // layer must stay positioned even when it draws nothing.
    if (take == null || startSamples == null || take.sampleRate <= 0) {
      return const Positioned.fill(child: Stack());
    }
    final bpm =
        ref.watch(transportProvider.select((s) => s.value?.state?.bpm)) ??
        120.0;
    final colors = Theme.of(context).colorScheme;
    final left = samplesToTicks(startSamples, bpm, take.sampleRate) / zoomLevel;
    final width = samplesToTicks(take.frames, bpm, take.sampleRate) / zoomLevel;
    final framesPerPixel = zoomLevel * samplesPerTick(bpm, take.sampleRate);

    return Positioned.fill(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: left,
            top: 2,
            width: math.max(1, width),
            height: trackHeight - 4,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  color: colors.error.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: colors.error, width: 1.5),
                ),
                clipBehavior: Clip.hardEdge,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: RecordingPreviewPainter(
                          peaks: take.peaks,
                          color: colors.error.withValues(alpha: 0.85),
                          framesPerPixel: framesPerPixel,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      child: Text(
                        take.isStopping ? 'Saving…' : 'Recording',
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        style: TextStyle(
                          color: colors.onSurface,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
