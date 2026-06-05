import 'package:karbeat/src/rust/api/project.dart';

/// ======================================
/// Clip Time Conversion Utilities
/// Handles conversion between sample-based (audio) and tick-based (MIDI)
/// clip positioning for the timeline UI.
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
/// For tick-based clips (MIDI/automation), values are returned as-is.
/// For sample-based clips (audio), values are converted to ticks using BPM and sample rate.
extension UiClipTickConversion on UiClip {
  /// Get the start time in ticks (for timeline rendering).
  int startTimeInTicks(double bpm, int sampleRate) {
    if (!isSampleBased) return startTime;
    return samplesToTicks(startTime, bpm, sampleRate);
  }

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
