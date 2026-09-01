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
  int? _drawPointer;
  List<UiClip> _drawSourceClips = const [];
  List<int> _drawCopyStartTicks = const [];
  bool _isCommittingDrawCopies = false;
  int? _rangePointer;

  int _browserDropTick(Offset globalOffset, double zoomLevel) {
    final renderBox = context.findRenderObject() as RenderBox;
    var ticks = (renderBox.globalToLocal(globalOffset).dx * zoomLevel)
        .clamp(0.0, double.infinity)
        .round();
    final workspaceState = ref.read(workspaceStateProvider);
    if (workspaceState.snapToGrid) {
      ticks = _snapTick(ticks, workspaceState);
    }
    return ticks;
  }

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

  int? _gridStep(WorkspaceState workspaceState) {
    if (!workspaceState.snapToGrid || workspaceState.gridSize.value <= 0) {
      return null;
    }
    final step = (960.0 * 4.0) / workspaceState.gridSize.value;
    return step > 0 ? step.round() : null;
  }

  UiClip? _clipAtTick({
    required List<UiClip> clips,
    required int tick,
    required double tempo,
    required int sampleRate,
  }) {
    // Clips later in the list are painted on top, so use the same ordering for
    // hit testing in the unlikely event that a project already has overlaps.
    for (final clip in clips.reversed) {
      final start = clip.startTimeInTicks(tempo, sampleRate);
      final end = start + clip.loopLengthInTicks(tempo, sampleRate);
      if (tick >= start && tick < end) return clip;
    }
    return null;
  }

  _ClipTickRange _clipRangeInTicks(UiClip clip, double tempo, int sampleRate) {
    if (!clip.isSampleBased) {
      return _ClipTickRange(clip.startTime, clip.startTime + clip.loopLength);
    }

    final samplesPerTimelineTick = samplesPerTick(tempo, sampleRate);
    if (samplesPerTimelineTick <= 0) return const _ClipTickRange(0, 0);
    final start = (clip.startTime / samplesPerTimelineTick).floor();
    final end = ((clip.startTime + clip.loopLength) / samplesPerTimelineTick)
        .ceil();
    return _ClipTickRange(start, end);
  }

  void _startDrawSwipe({
    required PointerEvent event,
    required UiTrack track,
    required double zoomLevel,
  }) {
    if (_drawPointer != null ||
        _isCommittingDrawCopies ||
        event.pointer < 0 ||
        (event.buttons & kPrimaryButton) == 0) {
      return;
    }

    final tempo = ref.read(transportProvider).value?.state?.bpm ?? 120.0;
    final sampleRate = ref.read(transportProvider).value?.sampleRate ?? 48000;
    final tick = (event.localPosition.dx * zoomLevel).round();
    final hitClip = _clipAtTick(
      clips: track.clips,
      tick: tick,
      tempo: tempo,
      sampleRate: sampleRate,
    );
    if (hitClip == null) return;

    final selection = ref.read(trackListStateProvider);
    final hitIsSelected =
        selection.selectedTrackId == widget.trackId &&
        selection.selectedClipIds.contains(hitClip.id);

    final sourceIds = hitIsSelected
        ? selection.selectedClipIds.toSet()
        : <int>{hitClip.id};

    if (!hitIsSelected) {
      ref
          .read(trackListStateProvider.notifier)
          .selectClip(trackId: widget.trackId, clipId: hitClip.id);
    }

    final sourceClips = track.clips
        .where((clip) => sourceIds.contains(clip.id))
        .toList(growable: false);
    if (sourceClips.isEmpty) return;

    setState(() {
      _drawPointer = event.pointer;
      _drawSourceClips = sourceClips;
      _drawCopyStartTicks = const [];
    });
  }

  void _updateDrawSwipe({
    required PointerEvent event,
    required UiTrack track,
    required double zoomLevel,
  }) {
    // A draw that began in empty space may enter a clip. Treat that as clip
    // interaction and make it the source of the swipe.
    if (_drawPointer == null) {
      _startDrawSwipe(event: event, track: track, zoomLevel: zoomLevel);
    }
    if (_drawPointer != event.pointer || _drawSourceClips.isEmpty) return;

    final tempo = ref.read(transportProvider).value?.state?.bpm ?? 120.0;
    final sampleRate = ref.read(transportProvider).value?.sampleRate ?? 48000;
    final sourceIds = _drawSourceClips.map((clip) => clip.id).toSet();
    final sourceRanges = _drawSourceClips
        .map((clip) => _clipRangeInTicks(clip, tempo, sampleRate))
        .toList(growable: false);
    final occupiedRanges = track.clips
        .where((clip) => !sourceIds.contains(clip.id))
        .map((clip) => _clipRangeInTicks(clip, tempo, sampleRate))
        .toList(growable: false);
    final workspaceState = ref.read(workspaceStateProvider);
    final starts = _drawSwipeCopyStarts(
      sourceRanges: sourceRanges,
      occupiedRanges: occupiedRanges,
      dragTick: (event.localPosition.dx * zoomLevel).round(),
      gridStep: _gridStep(workspaceState),
    );

    if (!listEquals(starts, _drawCopyStartTicks)) {
      setState(() => _drawCopyStartTicks = starts);
    }
  }

  Future<void> _finishDrawSwipe(PointerEvent event, UiTrack track) async {
    if (_drawPointer != event.pointer) return;

    // Account for the final pointer coordinate even when the platform does not
    // emit a move event immediately before pointer-up.
    _updateDrawSwipe(
      event: event,
      track: track,
      zoomLevel: ref.read(workspaceStateProvider).horizontalZoomLevel,
    );

    final sourceClips = _drawSourceClips;
    final startsInTicks = _drawCopyStartTicks;
    setState(() {
      _drawPointer = null;
      _drawSourceClips = const [];
      _drawCopyStartTicks = const [];
      _isCommittingDrawCopies =
          sourceClips.isNotEmpty && startsInTicks.isNotEmpty;
    });

    if (sourceClips.isEmpty || startsInTicks.isEmpty) return;

    final notifier = ref.read(trackListStateProvider.notifier);
    final sourceIds = sourceClips
        .map((clip) => clip.id)
        .toList(growable: false);
    final sourceIdSet = sourceIds.toSet();
    final tempo = ref.read(transportProvider).value?.state?.bpm ?? 120.0;
    final sampleRate = ref.read(transportProvider).value?.sampleRate ?? 48000;
    final snapToGrid = ref.read(workspaceStateProvider).snapToGrid;
    final isSampleBased = sourceClips.every((clip) => clip.isSampleBased);
    final sourceStart = sourceClips
        .map((clip) => clip.startTime)
        .reduce(math.min);
    final sourceEnd = sourceClips
        .map((clip) => clip.startTime + clip.loopLength)
        .reduce(math.max);
    final sourceLength = sourceEnd - sourceStart;
    final relativeSourceRanges = sourceClips
        .map(
          (clip) => _ClipTickRange(
            clip.startTime - sourceStart,
            clip.startTime + clip.loopLength - sourceStart,
          ),
        )
        .toList(growable: false);
    final occupiedRanges = track.clips
        .where((clip) => !sourceIdSet.contains(clip.id))
        .map(
          (clip) =>
              _ClipTickRange(clip.startTime, clip.startTime + clip.loopLength),
        )
        .toList(growable: false);
    final generatedRanges = sourceClips
        .map(
          (clip) =>
              _ClipTickRange(clip.startTime, clip.startTime + clip.loopLength),
        )
        .toList();
    final pasteStartTimes = <int>[];

    for (var index = 0; index < startsInTicks.length; index++) {
      final pasteStartTime = isSampleBased
          ? snapToGrid
                ? ticksToSamples(startsInTicks[index], tempo, sampleRate)
                // Sample-based clips must be adjacent at sample precision;
                // round-tripping their length through ticks can otherwise
                // introduce a one-sample overlap or gap.
                : sourceEnd + (sourceLength * index)
          : startsInTicks[index];
      final copyRanges = relativeSourceRanges
          .map((range) => range.shifted(pasteStartTime))
          .toList(growable: false);
      final collides = copyRanges.any(
        (copy) =>
            occupiedRanges.any(copy.overlaps) ||
            generatedRanges.any(copy.overlaps),
      );
      if (collides) break;
      pasteStartTimes.add(pasteStartTime);
      generatedRanges.addAll(copyRanges);
    }

    if (pasteStartTimes.isEmpty) {
      _isCommittingDrawCopies = false;
      return;
    }

    try {
      final result = await notifier.duplicateClipGroups(
        trackId: widget.trackId,
        clipIds: sourceIds,
        groupStartTimes: pasteStartTimes,
      );
      if (!result.isOk()) return;

      // Keep the source selected so another draw swipe repeats the same group.
      if (mounted) {
        notifier.selectClips(trackId: widget.trackId, clipIds: sourceIds);
      }
    } finally {
      _isCommittingDrawCopies = false;
    }
  }

  void _cancelDrawSwipe(PointerEvent event) {
    if (_drawPointer != event.pointer) return;
    setState(() {
      _drawPointer = null;
      _drawSourceClips = const [];
      _drawCopyStartTicks = const [];
    });
  }

  void _startRangeSelect(PointerEvent event, double zoomLevel) {
    if (_rangePointer != null || (event.buttons & kPrimaryButton) == 0) return;

    _rangePointer = event.pointer;
    final tick = math.max(0.0, event.localPosition.dx) * zoomLevel;
    ref.read(rangeSelectProvider.notifier).start(widget.trackId, tick);
  }

  void _updateRangeSelect(PointerEvent event, double zoomLevel) {
    if (_rangePointer != event.pointer) return;
    final tick = math.max(0.0, event.localPosition.dx) * zoomLevel;
    ref.read(rangeSelectProvider.notifier).update(tick);
  }

  void _finishRangeSelect(PointerEvent event, UiTrack track, double zoomLevel) {
    if (_rangePointer != event.pointer) return;
    _updateRangeSelect(event, zoomLevel);
    _rangePointer = null;

    final rangeState = ref.read(rangeSelectProvider);
    if (!rangeState.isSelecting || rangeState.trackId != widget.trackId) {
      ref.read(rangeSelectProvider.notifier).cancel();
      return;
    }

    final minTick = math.min(rangeState.startTick, rangeState.endTick).toInt();
    final maxTick = math.max(rangeState.startTick, rangeState.endTick).toInt();
    final tempo = ref.read(transportProvider).value?.state?.bpm ?? 120.0;
    final sampleRate = ref.read(transportProvider).value?.sampleRate ?? 48000;
    final selectedIds = track.clips
        .where((clip) {
          final range = _clipRangeInTicks(clip, tempo, sampleRate);
          return range.end > minTick && range.start < maxTick;
        })
        .map((clip) => clip.id)
        .toList(growable: false);

    final notifier = ref.read(trackListStateProvider.notifier);
    if (selectedIds.isEmpty) {
      notifier.deselectAllClips();
    } else {
      notifier.selectClips(trackId: widget.trackId, clipIds: selectedIds);
    }
    ref.read(rangeSelectProvider.notifier).cancel();
  }

  void _cancelRangeSelect(PointerEvent event) {
    if (_rangePointer != event.pointer) return;
    _rangePointer = null;
    ref.read(rangeSelectProvider.notifier).cancel();
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

    final trackSlot = DragTarget<Object>(
      onWillAcceptWithDetails: (details) => switch (details.data) {
        BrowserSample() => track.trackType == UiTrackType.audio,
        List<int>() => true,
        _ => false,
      },
      onAcceptWithDetails: (details) {
        final data = details.data;
        if (data is! BrowserSample) return;
        final startTick = _browserDropTick(details.offset, zoomLevel);
        unawaited(
          ref
              .read(trackListStateProvider.notifier)
              .createAudioClipFromFile(
                filePath: data.path,
                trackId: widget.trackId,
                startTick: startTick,
              ),
        );
      },
      onMove: (details) {
        if (details.data is BrowserSample) return;
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
        final colors = Theme.of(context).colorScheme;
        return Container(
          height: widget.height,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: colors.outlineVariant, width: 1),
              right: BorderSide(color: colors.outlineVariant, width: 1),
            ),
            color: candidateData.any((data) => data is BrowserSample)
                ? colors.primary.withValues(alpha: 0.12)
                : candidateData.isNotEmpty
                ? colors.onSurface.withValues(alpha: 0.08)
                : colors.surface.withValues(alpha: 0.72),
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
                        await ref
                            .read(clipPlacementProvider.notifier)
                            .confirmPlacement();
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
                              scrollController:
                                  widget.horizontalScrollController,
                              viewportWidth: constraints.maxWidth,
                              lineColor: colors.onSurface.withValues(
                                alpha: 0.08,
                              ),
                              barLineColor: colors.onSurface.withValues(
                                alpha: 0.25,
                              ),
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
                  color: track.color.fromRGBorRGBAtoColor(),
                  zoomLevel: zoomLevel,
                  height: widget.height,
                  selectedTool: selectedTool,
                  isSelected: isSelected,
                  selectedClipIds: selectedClipIds,
                  horizontalScrollController: widget.horizontalScrollController,
                  waveformMap: waveformMap,
                );
              }),

              // Lightweight preview for copies produced by a draw swipe.
              ..._drawCopyStartTicks.expand((copyStart) {
                if (_drawSourceClips.isEmpty) return const <Widget>[];
                final tempo =
                    ref.read(transportProvider).value?.state?.bpm ?? 120.0;
                final sampleRate =
                    ref.read(transportProvider).value?.sampleRate ?? 48000;
                final sourceStart = _drawSourceClips
                    .map((clip) => clip.startTimeInTicks(tempo, sampleRate))
                    .reduce(math.min);
                return _drawSourceClips.map((clip) {
                  final clipStart = clip.startTimeInTicks(tempo, sampleRate);
                  final clipLength = clip.loopLengthInTicks(tempo, sampleRate);
                  final previewLeft =
                      (copyStart + clipStart - sourceStart) / zoomLevel;
                  return Positioned(
                    left: previewLeft,
                    top: 2,
                    width: math.max(1, clipLength / zoomLevel),
                    height: widget.height - 4,
                    child: IgnorePointer(
                      child: Opacity(
                        opacity: 0.65,
                        child: _ClipRenderer(
                          clip: clip,
                          trackType: track.trackType,
                          color: track.color.fromRGBorRGBAtoColor(),
                          zoomLevel: zoomLevel,
                          projectSampleRate: sampleRate,
                          overrideOffset: clip
                              .offsetStartInTicks(tempo, sampleRate)
                              .toDouble(),
                          isSelected: false,
                          scrollController: widget.horizontalScrollController,
                          clipLeftOffset: previewLeft,
                          waveformMap: waveformMap,
                        ),
                      ),
                    ),
                  );
                });
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

    if (selectedTool != ToolSelection.draw || placementState.isPlacing) {
      if (selectedTool != ToolSelection.select || placementState.isPlacing) {
        return trackSlot;
      }

      return Listener(
        behavior: HitTestBehavior.deferToChild,
        onPointerDown: (event) => _startRangeSelect(event, zoomLevel),
        onPointerMove: (event) => _updateRangeSelect(event, zoomLevel),
        onPointerUp: (event) => _finishRangeSelect(event, track, zoomLevel),
        onPointerCancel: _cancelRangeSelect,
        child: trackSlot,
      );
    }

    return Listener(
      behavior: HitTestBehavior.deferToChild,
      onPointerDown: (event) =>
          _startDrawSwipe(event: event, track: track, zoomLevel: zoomLevel),
      onPointerMove: (event) =>
          _updateDrawSwipe(event: event, track: track, zoomLevel: zoomLevel),
      onPointerUp: (event) => unawaited(_finishDrawSwipe(event, track)),
      onPointerCancel: _cancelDrawSwipe,
      child: trackSlot,
    );
  }
}
