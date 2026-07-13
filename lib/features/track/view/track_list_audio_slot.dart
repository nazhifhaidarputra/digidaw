part of 'track_list_screen.dart';

class AudioTrackSlot extends ConsumerStatefulWidget {
  final int trackId;
  final double height;
  final ScrollController horizontalScrollController;
  final int sampleRate;
  final ClipDragController clipDragController;

  const AudioTrackSlot({
    super.key,
    required this.trackId,
    required this.height,
    required this.horizontalScrollController,
    required this.sampleRate,
    required this.clipDragController,
  });

  @override
  ConsumerState<AudioTrackSlot> createState() => _AudioTrackSlotState();
}

class _AudioTrackSlotState extends ConsumerState<AudioTrackSlot> {
  void _handleEmptySpaceClick({
    required BuildContext context,
    required double localDx,
    required double zoomLevel,
  }) {
    // final state = ref.read(workspaceStateProvider);
    int startTime = (localDx * zoomLevel).round();

    if (ref.read(workspaceStateProvider).snapToGrid) {
      startTime = _snapTick(startTime, ref.read(workspaceStateProvider));
    }

    ref
        .read(trackListStateProvider.notifier)
        .createEmptyPatternClip(trackId: widget.trackId, startTime: startTime);
  }

  @override
  Widget build(BuildContext context) {
    // Listen to Zoom Level (Global)
    final zoomLevel = ref.watch(
      workspaceStateProvider.select((s) => s.horizontalZoomLevel),
    );

    final gridSize = ref.watch(
      workspaceStateProvider.select((s) => s.gridSize),
    );
    final tempo = ref.watch(
      transportProvider.select((s) => s.value?.state?.bpm),
    );

    // Listen to Track Data
    final track = ref.watch(
      projectProvider.select((s) => s.value?.tracks[widget.trackId]),
    );

    final isSelectedTrack = ref.watch(
      trackListStateProvider.select((s) => s.selectedTrackId == widget.trackId),
    );

    final trackSelectedClipIdsStr = ref.watch(
      trackListStateProvider.select((s) {
        if (s.selectedTrackId != widget.trackId) return '';
        return s.selectedClipIds.join(',');
      }),
    );

    final safeSampleRate = widget.sampleRate <= 0 ? 48000 : widget.sampleRate;

    final waveformMap = ref.watch(
      trackWaveformProvider((trackId: widget.trackId)),
    );

    final selectedTool = ref.watch(
      workspaceStateProvider.select((s) => s.selectedTool),
    );

    final selectedClipIds = trackSelectedClipIdsStr.isEmpty
        ? <int>[]
        : trackSelectedClipIdsStr.split(',').map(int.parse).toList();

    if (track == null) return const SizedBox();

    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withAlpha(16), width: 1),
          right: BorderSide(color: Colors.white.withAlpha(16), width: 1),
        ),
        color: Colors.grey.shade900,
      ),
      child: Stack(
        clipBehavior: Clip.none, // Allow clips to drag outside temporarily
        children: [
          Positioned.fill(
            child: MouseRegion(
              cursor: selectedTool == ToolSelection.draw
                  ? SystemMouseCursors.precise
                  : SystemMouseCursors.basic,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTapUp: (details) {
                  if (selectedTool == ToolSelection.draw) {
                    _handleEmptySpaceClick(
                      context: context,
                      localDx: details.localPosition.dx,
                      zoomLevel: zoomLevel,
                    );
                  } else {
                    ref
                        .read(trackListStateProvider.notifier)
                        .deselectAllClips();
                  }
                },
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: GridPainter(
                      zoomLevel: zoomLevel,
                      gridSize: gridSize,
                      tempo: tempo ?? 120,
                      sampleRate: safeSampleRate,
                      scrollController: widget.horizontalScrollController,
                    ),
                  ),
                ),
              ),
            ),
          ),
          ...track.clips.map((clip) {
            final isSelected =
                isSelectedTrack && selectedClipIds.contains(clip.id);

            return _InteractiveClip(
              key: ValueKey(clip.id),
              clip: clip,
              trackId: widget.trackId,
              trackType: track.trackType,
              color: track.color.toColor(),
              zoomLevel: zoomLevel,
              height: widget.height,
              selectedTool: selectedTool,
              isSelected: isSelected,
              selectedClipIds: selectedClipIds,
              clipDragController: widget.clipDragController,
              horizontalScrollController: widget.horizontalScrollController,
              waveformMap: waveformMap,
            );
          }),
        ],
      ),
    );
  }
}
