part of 'track_list_screen.dart';

class _ClipRenderer extends ConsumerWidget {
  final UiClip clip;
  final UiTrackType trackType;
  final Color color;
  final double zoomLevel;
  final int projectSampleRate;
  final double? overrideOffset;
  final bool isSelected;
  final ScrollController scrollController;
  final double clipLeftOffset;
  final Map<int, WaveformHandle> waveformMap;

  const _ClipRenderer({
    required this.clip,
    required this.trackType,
    required this.color,
    required this.zoomLevel,
    required this.projectSampleRate,
    this.overrideOffset,
    required this.isSelected,
    required this.scrollController,
    required this.clipLeftOffset,
    required this.waveformMap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: color.withAlpha(100),
        borderRadius: BorderRadius.circular(4),
        border: isSelected
            ? Border.all(color: Colors.white, width: 2)
            : Border.all(color: color.withAlpha(150), width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: Stack(
          children: [
            // A. Content (Waveform or MIDI Notes)
            Positioned.fill(child: _buildContent(context, ref)),

            // B. Label Header
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                color: Colors.black26,
                child: Text(
                  clip.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref) {
    final transportState = ref.watch(transportProvider).value?.state;
    final projectState = ref.watch(projectProvider).value;
    if (transportState == null || projectState == null) return const SizedBox();
    final tempo = transportState.bpm;

    switch (clip.source) {
      case UiClipSource_Audio(:final sourceId):
        final handle = waveformMap[sourceId];
        if (handle == null) {
          return const Center(
            child: Text("Loading...", style: TextStyle(fontSize: 8)),
          );
        }

        final double effectiveOffsetTicks =
            overrideOffset ??
            clip.offsetStartInTicks(tempo, projectSampleRate).toDouble();

        // getSampleRate() is a sync opaque call — zero FFI overhead
        final samplesPerTick =
            (60.0 / tempo) * (handle.getSampleRate() / 960.0);

        final waveformColor = color.computeLuminance() > 0.5
            ? Colors.black.withAlpha(180) // Dark waveform for light tracks
            : Colors.white.withAlpha(200);

        return RepaintBoundary(
          child: CustomPaint(
            size: Size.infinite,
            painter: StereoWaveformClipPainter(
              // Zero-copy: Float32List view directly into Rust-owned Mmap memory
              samples: createZeroCopyWaveformView(handle),
              color: waveformColor,
              zoomLevel: zoomLevel,
              offsetTicks: effectiveOffsetTicks,
              strokeWidth: 1.0,
              samplesPerTick: samplesPerTick,
              scrollController: scrollController,
              clipLeftOffset: clipLeftOffset,
            ),
          ),
        );
      case UiClipSource_Midi(:final patternId):
        final pattern = projectState.patterns[patternId];

        if (pattern == null) {
          return const Center(
            child: Text(
              "?",
              style: TextStyle(color: Colors.white54, fontSize: 10),
            ),
          );
        }

        return RepaintBoundary(
          child: CustomPaint(
            size: Size.infinite,
            painter: MidiClipPainter(
              pattern: pattern,
              color: color,
              zoomLevel: zoomLevel,
              sampleRate: projectSampleRate,
              bpm: tempo,
              scrollController: scrollController,
              clipLeftOffset: clipLeftOffset,
            ),
          ),
        );
      default:
        return const SizedBox();
    }
  }
}

int computeTargetBin(double zoomLevel) {
  if (zoomLevel <= 1) return 1;

  const levels = [1, 4, 16, 64, 256, 1024];

  for (final l in levels) {
    if (l >= zoomLevel) return l;
  }

  return levels.last; // fallback (max zoomed out)
}

/// Snaps a tick value to the nearest grid line based on the global state
int _snapTick(int ticks, WorkspaceState workspaceState) {
  if (!workspaceState.snapToGrid) return ticks;
  if (workspaceState.gridSize.value <= 0) return ticks;
  final double ticksPerGridLine = (960.0 * 4.0) / workspaceState.gridSize.value;
  if (ticksPerGridLine <= 0) return ticks;
  return ((ticks / ticksPerGridLine).round() * ticksPerGridLine).toInt();
}

/// Snaps an absolute tick value to the nearest global step boundary.
/// Used for the cut tool, where the cut point should land on a step grid line.
int _snapClipShiftTick({required int ticks, required MusicalBeatSize step}) {
  if (step == MusicalBeatSize.none) return ticks;

  final double ticksPerStep = step.value * 960.0;
  if (ticksPerStep <= 0) return ticks;

  return ((ticks / ticksPerStep).round() * ticksPerStep).toInt();
}

/// Snaps a movement **delta** to the nearest multiple of the move-step size.
/// Unlike [_snapClipShiftTick], this does NOT clamp to global grid boundaries.
/// The clip jumps in step-size increments from its initial starting position:
///   new_position = initial_start + round(delta / step) * step
int _snapDeltaToStep({
  required int deltaInTicks,
  required MusicalBeatSize step,
}) {
  if (step == MusicalBeatSize.none) return deltaInTicks;

  final double ticksPerStep = step.value * 960.0;
  if (ticksPerStep <= 0) return deltaInTicks;

  return ((deltaInTicks / ticksPerStep).round() * ticksPerStep).toInt();
}
