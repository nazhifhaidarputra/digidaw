import 'package:karbeat/src/rust/api/project.dart';

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
