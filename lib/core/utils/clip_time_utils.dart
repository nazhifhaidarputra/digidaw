import 'package:karbeat/src/rust/api/project.dart';
import 'package:karbeat/src/rust/api/track.dart' show UiResizeEdge;

/// ======================================
/// Clip Time Conversion Utilities
/// Handles conversion of sample-based clip dimensions for the tick timeline.
/// ======================================

const int _ticksPerBeat = 960;

/// Compute samples per tick from BPM and sample rate.
/// This matches the Rust-side `ClipTimeUnit::samples_per_tick`.
double samplesPerTick(double bpm, int sampleRate) {
  final effectiveBpm = bpm <= 0 ? 120.0 : bpm;
  final samplesPerBeat = (60.0 / effectiveBpm) * sampleRate;
  return samplesPerBeat / _ticksPerBeat;
}

/// Convert a sample count to ticks.
int samplesToTicks(int samples, double bpm, int sampleRate) {
  final spt = samplesPerTick(bpm, sampleRate);
  if (spt <= 0) return 0;
  return (samples / spt).round();
}

/// Convert ticks to a sample count.
int ticksToSamples(int ticks, double bpm, int sampleRate) {
  final spt = samplesPerTick(bpm, sampleRate);
  return (ticks * spt).round();
}

/// Extension on UiClip that provides tick-equivalent accessors for rendering.
///
/// Placement is always stored in ticks. Sample-based content dimensions are
/// converted using the current BPM and sample rate.
extension UiClipTickConversion on UiClip {
  /// Get the timeline placement in ticks.
  int get startTimeInTicks => startTime;

  /// Get the loop length in ticks (for clip width rendering).
  int loopLengthInTicks(double bpm, int sampleRate) {
    if (!isSampleBased) return loopLength;
    return samplesToTicks(loopLength, bpm, sampleRate);
  }

  /// Get the offset start in ticks.
  int offsetStartInTicks(double bpm, int sampleRate) {
    if (!isSampleBased) return offsetStart;
    return samplesToTicks(offsetStart, bpm, sampleRate);
  }
}

/// [clip] after its [edge] is dragged by [deltaTicks], trimming or extending
/// what it plays. Mirrors the Rust-side `resize_clip_batch`.
UiClip resizedClip(
  UiClip clip,
  UiResizeEdge edge,
  int deltaTicks,
  double bpm,
  int sampleRate,
) {
  int newStart = clip.startTime;
  int newLength = clip.loopLength;
  int newOffset = clip.offsetStart;

  if (clip.isSampleBased) {
    final oldLengthTicks = samplesToTicks(clip.loopLength, bpm, sampleRate);
    final oldEndTick = clip.startTime + oldLengthTicks;
    if (edge == UiResizeEdge.right) {
      final newEndTick = (oldEndTick + deltaTicks).clamp(
        clip.startTime + 10,
        1 << 62,
      );
      newLength = ticksToSamples(newEndTick - clip.startTime, bpm, sampleRate);
    } else {
      final newStartTick = (clip.startTime + deltaTicks)
          .clamp(0, oldEndTick - 10)
          .toInt();
      final deltaSamples = ticksToSamples(
        newStartTick - clip.startTime,
        bpm,
        sampleRate,
      );
      newStart = newStartTick;
      newLength = (clip.loopLength - deltaSamples).clamp(1, 1 << 62).toInt();
      newOffset = (clip.offsetStart + deltaSamples).clamp(0, 1 << 62).toInt();
    }
  } else if (edge == UiResizeEdge.right) {
    final newEnd = (clip.startTime + clip.loopLength + deltaTicks).clamp(
      clip.startTime + 10,
      1 << 62,
    );
    newLength = newEnd.toInt() - clip.startTime;
  } else {
    final oldEnd = clip.startTime + clip.loopLength;
    newStart = (clip.startTime + deltaTicks).clamp(0, oldEnd - 10).toInt();
    newLength = oldEnd - newStart;
    newOffset = (clip.offsetStart + newStart - clip.startTime)
        .clamp(0, 1 << 62)
        .toInt();
  }
  return clip.copyWith(
    startTime: newStart,
    loopLength: newLength,
    offsetStart: newOffset,
  );
}

/// [clip] after its [edge] is dragged by [deltaTicks] with its audio stretched
/// to the new length. The clip takes the bounds of a plain resize, and its
/// content offset scales with the length, like the Rust-side `stretched_time`.
UiClip stretchResizedClip(
  UiClip clip,
  UiResizeEdge edge,
  int deltaTicks,
  double bpm,
  int sampleRate,
) {
  final resized = resizedClip(clip, edge, deltaTicks, bpm, sampleRate);
  if (clip.loopLength <= 0) return resized;
  final factor = resized.loopLength / clip.loopLength;
  return resized.copyWith(offsetStart: (clip.offsetStart * factor).round());
}
