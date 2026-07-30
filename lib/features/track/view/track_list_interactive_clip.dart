part of 'track_list_screen.dart';

class _InteractiveClip extends ConsumerStatefulWidget {
  final UiClip clip;
  final int trackId;
  final UiTrackType trackType;
  final Color color;
  final double zoomLevel;
  final double height;
  final ToolSelection selectedTool;
  final bool isSelected;
  final List<int> selectedClipIds;
  final ScrollController horizontalScrollController;
  final Map<int, WaveformHandle> waveformMap;

  const _InteractiveClip({
    super.key,
    required this.clip,
    required this.trackId,
    required this.trackType,
    required this.zoomLevel,
    required this.height,
    required this.selectedTool,
    required this.color,
    required this.isSelected,
    required this.selectedClipIds,
    required this.horizontalScrollController,
    required this.waveformMap,
  });

  @override
  ConsumerState<_InteractiveClip> createState() => _InteractiveClipState();
}

enum _DragAction { none, resizeLeft, resizeRight, move }

class _InteractiveClipState extends ConsumerState<_InteractiveClip> {
  // Local state for smooth UI updates during drag
  late int _visualStartTime;
  late int _visualLoopLength;
  late int _visualOffset;

  _DragAction _currentAction = _DragAction.none;

  // Drag Math Tracking
  double _accumulatedDeltaTicks = 0.0;
  int _previousSnappedDelta = 0;
  int _leaderBaseStartTime = 0;
  int _leaderBaseLoopLength = 0;

  // Track vertical drag to determine target track

  /// Track dynamic cursor override
  MouseCursor? _cursorOverride;

  @override
  void initState() {
    super.initState();
    _syncModel();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _InteractiveClip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_currentAction == _DragAction.none) {
      _syncModel();
    }
  }

  void _syncModel() {
    final bpm = ref.read(transportProvider).value?.state?.bpm;
    final sr = ref.read(transportProvider).value?.sampleRate;
    // Convert to tick-equivalent for rendering on the tick-based timeline
    if (bpm == null || sr == null) return;
    _visualStartTime = widget.clip.startTimeInTicks(bpm, sr);
    _visualLoopLength = widget.clip.loopLengthInTicks(bpm, sr);
    _visualOffset = widget.clip.offsetStartInTicks(bpm, sr);
  }

  @override
  Widget build(BuildContext context) {
    // Coordinate Mapping (Pixels)
    final double left = _visualStartTime / widget.zoomLevel;
    final double width = _visualLoopLength / widget.zoomLevel;
    final double safeWidth = width < 1 ? 1 : width;
    const resizeEdgeSize = 20.0;

    final sampleRate = ref.watch(transportProvider).value?.sampleRate ?? 48000;
    final tempo = ref.watch(transportProvider).value?.state?.bpm ?? 120.0;

    // final isMoving = _currentAction == _DragAction.move;

    // final double top = 2 + _verticalDragDy;

    // Determine Cursor
    MouseCursor cursor = SystemMouseCursors.basic;
    if (widget.selectedTool == ToolSelection.delete) {
      cursor = SystemMouseCursors.click;
    } else if (widget.selectedTool == ToolSelection.move) {
      cursor = SystemMouseCursors.move;
    } else if (widget.selectedTool == ToolSelection.resize) {
      cursor = SystemMouseCursors.basic; // Overridden on hover at edges
    }
    // Apply Override
    if (_cursorOverride != null) {
      cursor = _cursorOverride!;
    }

    // Check if this is a follower in a batch move (should be semi-transparent)
    final placementState = ref.watch(clipPlacementProvider);
    final isPartOfBatchDrag =
        widget.isSelected && placementState.isDraggingExisting;

    return Positioned(
      left: left,
      top: 2,
      height: widget.height - 4,
      width: safeWidth,
      child: Opacity(
        // Leader becomes invisible (has overlay), followers become semi-transparent
        opacity: isPartOfBatchDrag ? 0.3 : 1.0,
        child: IgnorePointer(
          ignoring: placementState.isDraggingExisting,
          child: MouseRegion(
            cursor: cursor,
            // Detect Hover for Resize Cursors (only if not in Delete mode)
            onHover: (event) {
              if (widget.selectedTool != ToolSelection.resize) {
                if (_cursorOverride != null) {
                  setState(() => _cursorOverride = null);
                }
                return;
              }

              final x = event.localPosition.dx;
              if (x < resizeEdgeSize || x > safeWidth - resizeEdgeSize) {
                if (_cursorOverride != SystemMouseCursors.resizeLeftRight) {
                  setState(() {
                    _cursorOverride = SystemMouseCursors.resizeLeftRight;
                  });
                } else {
                  if (_cursorOverride != null) {
                    setState(() {
                      _cursorOverride = null;
                    });
                  }
                }
              }
            },
            onExit: (event) {
              if (_cursorOverride != null) {
                setState(() {
                  _cursorOverride = null;
                });
              }
            },
            child: _buildInteractiveClipContent(
              left: left,
              safeWidth: safeWidth,
              resizeEdgeSize: resizeEdgeSize,
              tempo: tempo,
              sampleRate: sampleRate,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInteractiveClipContent({
    required double left,
    required double safeWidth,
    required double resizeEdgeSize,
    required double tempo,
    required int sampleRate,
  }) {
    final clipRenderer = _ClipRenderer(
      clip: widget.clip,
      trackType: widget.trackType,
      color: widget.color,
      zoomLevel: widget.zoomLevel,
      projectSampleRate:
          ref.watch(transportProvider).value?.sampleRate ?? 48000,
      overrideOffset: _visualOffset.toDouble(),
      isSelected: widget.isSelected,
      scrollController: widget.horizontalScrollController,
      clipLeftOffset: left,
      waveformMap: widget.waveformMap,
    );

    final gestureDetector = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (details) async {
        if (widget.selectedTool == ToolSelection.delete) {
          final state = ref.read(trackListStateProvider.notifier);
          if (widget.isSelected && widget.selectedClipIds.length > 1) {
            state.deleteSelectedClips();
          } else {
            state.deleteClip(widget.trackId, widget.clip.id);
          }
        } else if (widget.selectedTool == ToolSelection.select) {
          final state = ref.read(trackListStateProvider.notifier);
          final renderBox = context.findRenderObject() as RenderBox?;
          final tapPosition =
              renderBox?.localToGlobal(Offset.zero) ?? Offset.zero;

          if (!widget.isSelected) {
            state.selectClip(trackId: widget.trackId, clipId: widget.clip.id);
          }

          if (widget.isSelected && widget.selectedClipIds.length > 1) {
            ref
                .read(workspaceStateProvider.notifier)
                .showInteractionPanel(
                  MultiClipInteraction(
                    trackId: widget.trackId,
                    clipIds: widget.selectedClipIds,
                    tapPosition: tapPosition,
                  ),
                );
          } else {
            ref
                .read(workspaceStateProvider.notifier)
                .showInteractionPanel(
                  ClipInteraction(
                    trackId: widget.trackId,
                    clipId: widget.clip.id,
                    tapPosition: tapPosition,
                  ),
                );
          }
        } else if (widget.selectedTool == ToolSelection.pointer) {
          ref
              .read(trackListStateProvider.notifier)
              .selectClip(trackId: widget.trackId, clipId: widget.clip.id);
        } else if (widget.selectedTool == ToolSelection.slice) {
          final bpm = ref.read(transportProvider).value?.state?.bpm;
          final sr = ref.read(transportProvider).value?.sampleRate;

          if (bpm == null || sr == null || sr == 0) {
            throw Exception("BPM or Sample Rate is null or zero");
          }
          int cutPoint;
          if (widget.clip.isSampleBased) {
            int cutTick =
                widget.clip.startTimeInTicks(bpm, sr) +
                (details.localPosition.dx * widget.zoomLevel).round();
            cutTick = _snapClipShiftTick(
              ticks: cutTick,
              step: ref
                  .read(workspaceStateProvider)
                  .horizontalClipShiftSizeDenom,
            );
            cutPoint = ticksToSamples(cutTick, bpm, sr);
          } else {
            int cutTick =
                widget.clip.startTime +
                (details.localPosition.dx * widget.zoomLevel).round();
            cutTick = _snapClipShiftTick(
              ticks: cutTick,
              step: ref
                  .read(workspaceStateProvider)
                  .horizontalClipShiftSizeDenom,
            );
            cutPoint = cutTick;
          }

          await ref
              .read(trackListStateProvider.notifier)
              .sliceClip(widget.trackId, widget.clip.id, cutPoint);
        }
      },
      onPanStart: (widget.selectedTool == ToolSelection.resize)
          ? (details) {
              _accumulatedDeltaTicks = 0.0;
              _previousSnappedDelta = 0;

              final x = details.localPosition.dx;
              if (x < resizeEdgeSize) {
                setState(() => _currentAction = _DragAction.resizeLeft);
              } else if (x > safeWidth - resizeEdgeSize) {
                setState(() => _currentAction = _DragAction.resizeRight);
              } else {
                return;
              }

              final trackState = ref.read(trackListStateProvider.notifier);
              if (!widget.isSelected) {
                trackState.selectClip(
                  trackId: widget.trackId,
                  clipId: widget.clip.id,
                );
              }

              final currentSelectedIds = ref
                  .read(trackListStateProvider)
                  .selectedClipIds;
              final track = ref
                  .read(projectProvider)
                  .value
                  ?.tracks[widget.trackId];
              if (track != null && currentSelectedIds.isNotEmpty) {
                final tempo = ref.read(transportProvider).value?.state?.bpm;
                final sr = ref.read(transportProvider).value?.sampleRate;
                if (tempo == null || sr == null)
                  throw Exception("Tempo or Sample Rate is null");

                final leaderClip = track.clips
                    .where((c) => currentSelectedIds.contains(c.id))
                    .reduce(
                      (a, b) =>
                          a.startTimeInTicks(tempo, sr) <
                              b.startTimeInTicks(tempo, sr)
                          ? a
                          : b,
                    );

                _leaderBaseStartTime = leaderClip.startTimeInTicks(tempo, sr);
                _leaderBaseLoopLength = leaderClip.loopLengthInTicks(tempo, sr);
              }

              final batchAction = _currentAction == _DragAction.resizeLeft
                  ? BatchDragAction.resizeLeft
                  : BatchDragAction.resizeRight;

              ref
                  .read(clipPlacementProvider.notifier)
                  .startBatchDrag(
                    clipIds: currentSelectedIds.toList(),
                    action: batchAction,
                    originalTrackId: widget.trackId,
                  );
            }
          : null,
      onPanUpdate: (widget.selectedTool == ToolSelection.resize)
          ? (details) {
              if (_currentAction == _DragAction.none) return;

              final currentSelectedIds = ref
                  .read(trackListStateProvider)
                  .selectedClipIds;
              final track = ref
                  .read(projectProvider)
                  .value
                  ?.tracks[widget.trackId];
              if (track == null) return;

              _accumulatedDeltaTicks += details.delta.dx * widget.zoomLevel;
              int rawTotalDelta = _accumulatedDeltaTicks.round();

              final minTicks = 10;
              final shortestClip = track.clips
                  .where((c) => currentSelectedIds.contains(c.id))
                  .reduce((a, b) => a.loopLength < b.loopLength ? a : b);

              if (_currentAction == _DragAction.resizeRight) {
                final maxShrink = -(shortestClip.loopLength - minTicks);
                if (rawTotalDelta < maxShrink)
                  rawTotalDelta = maxShrink.toInt();
              } else if (_currentAction == _DragAction.resizeLeft) {
                final maxShrink = shortestClip.loopLength - minTicks;
                if (rawTotalDelta > maxShrink)
                  rawTotalDelta = maxShrink.toInt();
              }

              int snappedTotalDelta = rawTotalDelta;
              final workspaceStateProv = ref.read(workspaceStateProvider);

              if (_currentAction == _DragAction.resizeLeft) {
                if (workspaceStateProv.snapToGrid) {
                  final int rawStart = _leaderBaseStartTime + rawTotalDelta;
                  snappedTotalDelta =
                      _snapTick(rawStart, workspaceStateProv) -
                      _leaderBaseStartTime;
                } else {
                  snappedTotalDelta = _snapDeltaToStep(
                    deltaInTicks: rawTotalDelta,
                    step: workspaceStateProv.horizontalClipShiftSizeDenom,
                  );
                }
              } else if (_currentAction == _DragAction.resizeRight) {
                if (workspaceStateProv.snapToGrid) {
                  final int rawEnd =
                      _leaderBaseStartTime +
                      _leaderBaseLoopLength +
                      rawTotalDelta;
                  snappedTotalDelta =
                      _snapTick(rawEnd, workspaceStateProv) -
                      (_leaderBaseStartTime + _leaderBaseLoopLength);
                } else {
                  snappedTotalDelta = _snapDeltaToStep(
                    deltaInTicks: rawTotalDelta,
                    step: workspaceStateProv.horizontalClipShiftSizeDenom,
                  );
                }
              }

              _previousSnappedDelta = snappedTotalDelta;

              ref
                  .read(clipPlacementProvider.notifier)
                  .updateBatchDrag(
                    targetTrackId: widget.trackId,
                    snappedDeltaTicks: snappedTotalDelta,
                  );
            }
          : null,
      onPanEnd: (widget.selectedTool == ToolSelection.resize)
          ? (_) {
              if (_currentAction == _DragAction.none) return;

              final state = ref.read(trackListStateProvider);
              final currentSelectedIds = state.selectedClipIds;

              final isSampleBased = widget.clip.isSampleBased;
              final delta = isSampleBased
                  ? ticksToSamples(_previousSnappedDelta, tempo, sampleRate)
                  : _previousSnappedDelta;

              if (_currentAction == _DragAction.resizeRight) {
                ref
                    .read(trackListStateProvider.notifier)
                    .resizeClipBatch(
                      widget.trackId,
                      currentSelectedIds.toList(),
                      UiResizeEdge.right,
                      delta,
                    );
              } else if (_currentAction == _DragAction.resizeLeft) {
                ref
                    .read(trackListStateProvider.notifier)
                    .resizeClipBatch(
                      widget.trackId,
                      currentSelectedIds.toList(),
                      UiResizeEdge.left,
                      delta,
                    );
              }

              setState(() {
                _currentAction = _DragAction.none;
              });

              ref.read(clipPlacementProvider.notifier).cancelBatchDrag();
            }
          : null,
      child: clipRenderer,
    );

    if (widget.selectedTool == ToolSelection.move) {
      return Draggable<List<int>>(
        data: widget.selectedClipIds.isNotEmpty && widget.isSelected
            ? widget.selectedClipIds
            : [widget.clip.id],
        feedback: const SizedBox.shrink(),
        childWhenDragging: gestureDetector,
        onDragStarted: () {
          setState(() => _currentAction = _DragAction.move);
          _accumulatedDeltaTicks = 0.0;
          _previousSnappedDelta = 0;

          final trackState = ref.read(trackListStateProvider.notifier);
          if (!widget.isSelected) {
            trackState.selectClip(
              trackId: widget.trackId,
              clipId: widget.clip.id,
            );
          }

          final currentSelectedIds = ref
              .read(trackListStateProvider)
              .selectedClipIds;
          final track = ref.read(projectProvider).value?.tracks[widget.trackId];

          if (track != null && currentSelectedIds.isNotEmpty) {
            final leaderClip = track.clips
                .where((c) => currentSelectedIds.contains(c.id))
                .reduce(
                  (a, b) =>
                      a.startTimeInTicks(tempo, sampleRate) <
                          b.startTimeInTicks(tempo, sampleRate)
                      ? a
                      : b,
                );

            _leaderBaseStartTime = leaderClip.startTimeInTicks(
              tempo,
              sampleRate,
            );
            _leaderBaseLoopLength = leaderClip.loopLengthInTicks(
              tempo,
              sampleRate,
            );
          }

          ref
              .read(clipPlacementProvider.notifier)
              .startBatchDrag(
                clipIds: currentSelectedIds.toList(),
                action: BatchDragAction.move,
                originalTrackId: widget.trackId,
              );
        },
        onDragUpdate: (details) {
          if (_currentAction != _DragAction.move) return;

          _accumulatedDeltaTicks += details.delta.dx * widget.zoomLevel;
          int rawTotalDelta = _accumulatedDeltaTicks.round();
          int snappedTotalDelta = rawTotalDelta;

          final workspaceStateProv = ref.read(workspaceStateProvider);
          if (workspaceStateProv.snapToGrid) {
            final int rawStart = _leaderBaseStartTime + rawTotalDelta;
            snappedTotalDelta =
                _snapTick(rawStart, workspaceStateProv) - _leaderBaseStartTime;
          } else {
            snappedTotalDelta = _snapDeltaToStep(
              deltaInTicks: rawTotalDelta,
              step: workspaceStateProv.horizontalClipShiftSizeDenom,
            );
          }

          _previousSnappedDelta = snappedTotalDelta;

          // Clamp: prevent any clip from moving left of the timeline origin (x < 0).
          // _leaderBaseStartTime is the leftmost clip in the selection, so
          // leaderBaseStart + delta >= 0  =>  delta >= -leaderBaseStartTime.
          if (snappedTotalDelta < -_leaderBaseStartTime) {
            snappedTotalDelta = -_leaderBaseStartTime;
          }
          _previousSnappedDelta = snappedTotalDelta;

          final placementState = ref.read(clipPlacementProvider);
          ref
              .read(clipPlacementProvider.notifier)
              .updateBatchDrag(
                targetTrackId: placementState.trackId,
                snappedDeltaTicks: snappedTotalDelta,
              );
        },
        onDragEnd: (details) {
          if (_currentAction != _DragAction.move) return;

          final state = ref.read(trackListStateProvider);
          final currentSelectedIds = state.selectedClipIds;

          final placementState = ref.read(clipPlacementProvider);
          int? newTrackId =
              placementState.trackId != widget.trackId &&
                  placementState.trackId != -1
              ? placementState.trackId
              : null;

          final isSampleBased = widget.clip.isSampleBased;
          final delta = isSampleBased
              ? ticksToSamples(_previousSnappedDelta, tempo, sampleRate)
              : _previousSnappedDelta;

          ref
              .read(trackListStateProvider.notifier)
              .moveClipBatch(
                widget.trackId,
                currentSelectedIds.toList(),
                delta,
                newTrackId: newTrackId,
              );

          setState(() {
            _currentAction = _DragAction.none;
          });

          ref.read(clipPlacementProvider.notifier).cancelBatchDrag();
        },
        child: gestureDetector,
      );
    }

    return gestureDetector;
  }
}