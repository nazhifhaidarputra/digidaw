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

  /// Renders a solid block with only the clip title, for shrunk tracks.
  final bool compact;

  /// Track owning the clip; set when the clip's envelopes can be edited.
  final int? trackId;

  /// Whether the shown gain envelope reacts to pointer input.
  final bool envelopeInteractive;

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
    this.compact = false,
    this.trackId,
    this.envelopeInteractive = false,
  });

  static const double _headerHeight = 16;

  /// Header fill. Follows the track color until clips carry their own color.
  Color get _headerColor => color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    if (compact) return _buildCompact(colors);
    final headerColor = _headerColor;
    final headerForeground = headerColor.computeLuminance() > 0.5
        ? Colors.black
        : Colors.white;
    return Container(
      decoration: BoxDecoration(
        color: color.withAlpha(100),
        borderRadius: BorderRadius.circular(4),
        border: isSelected
            ? Border.all(color: colors.primary, width: 2)
            : Border.all(color: color.withAlpha(150), width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: Stack(
          children: [
            // A. Label Header
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: _headerHeight,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                alignment: Alignment.centerLeft,
                color: headerColor,
                child: Text(
                  clip.name,
                  style: TextStyle(
                    color: headerForeground,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),

            // B. Content (Waveform or MIDI Notes), laid out below the header
            Positioned.fill(
              top: _headerHeight,
              child: _buildContent(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompact(ColorScheme colors) {
    final foreground = color.computeLuminance() > 0.5
        ? Colors.black
        : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
        border: isSelected ? Border.all(color: colors.primary, width: 2) : null,
      ),
      child: Text(
        clip.name,
        style: TextStyle(
          color: foreground,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  /// The clip's own envelope, in clip content samples at the project rate.
  Widget _buildClipEnvelope(
    BuildContext context,
    WidgetRef ref, {
    required double tempo,
    required double offsetTicks,
  }) {
    final projectSamplesPerTick = samplesPerTick(tempo, projectSampleRate);
    final trackId = this.trackId;
    return GainEnvelopeEditor(
      envelope: clip.envelope ?? identityEnvelope,
      axis: EnvelopeAxis(
        pixelsPerSample: 1 / (projectSamplesPerTick * zoomLevel),
        originPosition: offsetTicks * projectSamplesPerTick,
      ),
      contentStart: clip.offsetStart,
      contentLength: clip.loopLength,
      maxCrossfade: clip.loopLength,
      color: Theme.of(context).colorScheme.primary,
      interactive: envelopeInteractive && trackId != null,
      onCommit: (envelope) async {
        if (trackId == null) return;
        await ref
            .read(trackListStateProvider.notifier)
            .setClipEnvelope(
              trackId: trackId,
              clipId: clip.id,
              envelope: envelope,
            );
      },
    );
  }

  /// The waveform envelope shared by every clip of the source, in source
  /// frames.
  Widget _buildWaveformEnvelope(
    WidgetRef ref, {
    required int sourceId,
    required WaveformHandle handle,
    required double sourceSamplesPerTick,
    required double offsetTicks,
  }) {
    final envelope = ref.watch(
      projectProvider.select((s) => s.value?.sourceEnvelopes[sourceId]),
    );
    final frames = handle.getLen() ~/ math.max(1, handle.getChannels());
    return GainEnvelopeEditor(
      envelope: envelope ?? identityEnvelope,
      axis: EnvelopeAxis(
        pixelsPerSample: 1 / (sourceSamplesPerTick * zoomLevel),
        originPosition: offsetTicks * sourceSamplesPerTick,
      ),
      contentStart: 0,
      contentLength: frames,
      maxCrossfade: frames ~/ 2,
      color: Colors.amber,
      interactive: envelopeInteractive,
      onCommit: (envelope) => ref
          .read(projectProvider.notifier)
          .setSourceEnvelope(sourceId, envelope),
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
        final sourceSamplesPerTick =
            (60.0 / tempo) * (handle.getSampleRate() / 960.0);

        final waveformColor = color.computeLuminance() > 0.5
            ? Colors.black.withAlpha(180) // Dark waveform for light tracks
            : Colors.white.withAlpha(200);

        final waveform = RepaintBoundary(
          child: CustomPaint(
            size: Size.infinite,
            painter: StereoWaveformClipPainter(
              // Zero-copy: Float32List view directly into Rust-owned Mmap memory
              samples: createZeroCopyWaveformView(handle),
              color: waveformColor,
              zoomLevel: zoomLevel,
              offsetTicks: effectiveOffsetTicks,
              strokeWidth: 1.0,
              samplesPerTick: sourceSamplesPerTick,
              scrollController: scrollController,
              clipLeftOffset: clipLeftOffset,
            ),
          ),
        );

        final envelopeView = ref.watch(
          workspaceStateProvider.select((s) => s.clipEnvelopeView),
        );
        if (envelopeView == ClipEnvelopeView.none) return waveform;

        return Stack(
          children: [
            Positioned.fill(child: waveform),
            Positioned.fill(
              child: RepaintBoundary(
                child: envelopeView == ClipEnvelopeView.clip
                    ? _buildClipEnvelope(
                        context,
                        ref,
                        tempo: tempo,
                        offsetTicks: effectiveOffsetTicks,
                      )
                    : _buildWaveformEnvelope(
                        ref,
                        sourceId: sourceId,
                        handle: handle,
                        sourceSamplesPerTick: sourceSamplesPerTick,
                        offsetTicks: effectiveOffsetTicks,
                      ),
              ),
            ),
          ],
        );
      case UiClipSource_Midi(:final patternId):
        final pattern = projectState.patterns[patternId];

        if (pattern == null) {
          return Center(
            child: Text(
              "?",
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 10,
              ),
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
