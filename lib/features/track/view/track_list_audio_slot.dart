part of 'track_list_screen.dart';

class AudioTrackSlot extends ConsumerStatefulWidget {
  final int trackId;
  final double height;
  final ScrollController horizontalScrollController;
  final int sampleRate;

  const AudioTrackSlot({
    super.key,
    required this.trackId,
    required this.height,
    required this.horizontalScrollController,
    required this.sampleRate,
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
    final zoomLevel = ref.watch(
      workspaceStateProvider.select((s) => s.horizontalZoomLevel),
    );

    final gridSize = ref.watch(
      workspaceStateProvider.select((s) => s.gridSize),
    );
    final tempo = ref.watch(
      transportProvider.select((s) => s.value?.state?.bpm),
    );

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

    final placementState = ref.watch(clipPlacementProvider);

    if (track == null) return const SizedBox();

    return DragTarget<List<int>>(
      onWillAcceptWithDetails: (details) => true,
      onAcceptWithDetails: (details) {},
      onMove: (details) {
        final renderBox = context.findRenderObject() as RenderBox;
        final localX = renderBox.globalToLocal(details.offset).dx;

        double ticks = localX * zoomLevel;
        if (ref.read(workspaceStateProvider).snapToGrid) {
          ticks = _snapTick(
            ticks.toInt(),
            ref.read(workspaceStateProvider),
          ).toDouble();
        }

        ref
            .read(clipPlacementProvider.notifier)
            .updatePlacementTarget(widget.trackId, ticks);
      },
      builder: (context, candidateData, rejectedData) {
        return Container(
          height: widget.height,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.white.withAlpha(16), width: 1),
              right: BorderSide(color: Colors.white.withAlpha(16), width: 1),
            ),
            color: candidateData.isNotEmpty
                ? Colors.white.withAlpha(20)
                : Colors.grey.shade900,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Grid Painter (Layer paling bawah)
              Positioned.fill(
                child: MouseRegion(
                  cursor: selectedTool == ToolSelection.draw
                      ? SystemMouseCursors.precise
                      : SystemMouseCursors.basic,
                  onHover: (event) {
                    if (!placementState.isPlacing) return;
                    double ticks = event.localPosition.dx * zoomLevel;
                    if (ref.read(workspaceStateProvider).snapToGrid) {
                      ticks = _snapTick(
                        ticks.toInt(),
                        ref.read(workspaceStateProvider),
                      ).toDouble();
                    }
                    ref
                        .read(clipPlacementProvider.notifier)
                        .updatePlacementTarget(widget.trackId, ticks);
                  },
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onPanUpdate: (details) {
                      if (!placementState.isPlacing) return;
                      double ticks = details.localPosition.dx * zoomLevel;
                      if (ref.read(workspaceStateProvider).snapToGrid) {
                        ticks = _snapTick(
                          ticks.toInt(),
                          ref.read(workspaceStateProvider),
                        ).toDouble();
                      }

                      ref
                          .read(clipPlacementProvider.notifier)
                          .updatePlacementTarget(widget.trackId, ticks);
                    },
                    onTapDown: (details) {
                      if (!placementState.isPlacing) return;
                      double ticks = details.localPosition.dx * zoomLevel;
                      if (ref.read(workspaceStateProvider).snapToGrid) {
                        ticks = _snapTick(
                          ticks.toInt(),
                          ref.read(workspaceStateProvider),
                        ).toDouble();
                      }
                      ref
                          .read(clipPlacementProvider.notifier)
                          .updatePlacementTarget(widget.trackId, ticks);
                    },
                    onTapUp: (details) async {
                      if (placementState.isPlacing) {
                        final result = await ref
                            .read(clipPlacementProvider.notifier)
                            .confirmPlacement();
                        if (result.isErr() && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                (result as Error<void>).toErrorMessage(),
                              ),
                            ),
                          );
                        }
                        return;
                      }

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
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return CustomPaint(
                            painter: GridPainter(
                              zoomLevel: zoomLevel,
                              gridSize: gridSize,
                              tempo: tempo ?? 120,
                              sampleRate: safeSampleRate,
                              scrollController: widget.horizontalScrollController,
                              viewportWidth: constraints.maxWidth,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),

              // Existing Clip list
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
                  horizontalScrollController: widget.horizontalScrollController,
                  waveformMap: waveformMap,
                );
              }),

              // Ghost Clip layer
              TrackGhostClip(
                trackId: widget.trackId,
                trackHeight: widget.height,
                zoomLevel: zoomLevel,
              ),

              // Range selection bounding box (per-track, in local coordinate space)
              TrackRangeSelectOverlay(
                trackId: widget.trackId,
                trackHeight: widget.height,
                zoomLevel: zoomLevel,
              ),
            ],
          ),
        );
      },
    );
  }
}
