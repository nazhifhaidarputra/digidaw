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
  final ClipDragController clipDragController;
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
    required this.clipDragController,
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
  double _verticalDragDy = 0.0;
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
    widget.clipDragController.addListener(_onBatchDragUpdate);
  }

  void _onBatchDragUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.clipDragController.removeListener(_onBatchDragUpdate);
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
    final sr = ref.read(projectProvider).value?.hardwareConfig.sampleRate;
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

    final sampleRate =
        ref.read(projectProvider).value?.hardwareConfig.sampleRate ?? 48000;
    final tempo = ref.read(transportProvider).value?.state?.bpm ?? 120.0;

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
    final isPartOfBatchDrag =
        widget.isSelected && widget.clipDragController.isActive;

    return Positioned(
      left: left,
      top: 2,
      height: widget.height - 4,
      width: safeWidth,
      child: Opacity(
        // Leader becomes invisible (has overlay), followers become semi-transparent
        opacity: isPartOfBatchDrag ? 0.3 : 1.0,
        child: IgnorePointer(
          ignoring: widget.clipDragController.isActive,
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
            child: GestureDetector(
              // Opaque ensures we catch taps even on transparent parts of waveform
              behavior: HitTestBehavior.opaque,

              onTapUp: (details) async {
                if (widget.selectedTool == ToolSelection.delete) {
                  final state = ref.read(trackListStateProvider.notifier);
                  // If this clip is selected and there are multiple selections, batch delete
                  if (widget.isSelected && widget.selectedClipIds.length > 1) {
                    state.deleteSelectedClips();
                  } else {
                    state.deleteClip(widget.trackId, widget.clip.id);
                  }
                } else if (widget.selectedTool == ToolSelection.select) {
                  final state = ref.read(trackListStateProvider.notifier);
                  // Get tap position for panel positioning
                  final renderBox = context.findRenderObject() as RenderBox?;
                  final tapPosition =
                      renderBox?.localToGlobal(Offset.zero) ?? Offset.zero;

                  // If not already selected, select it first
                  if (!widget.isSelected) {
                    state.selectClip(
                      trackId: widget.trackId,
                      clipId: widget.clip.id,
                    );
                  }

                  // Show interaction panel
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
                      .selectClip(
                        trackId: widget.trackId,
                        clipId: widget.clip.id,
                      );
                } else if (widget.selectedTool == ToolSelection.slice) {
                  // Calculate absolute position on the timeline (in native clip units)
                  final project = ref.read(projectProvider).value!;
                  final bpm = ref.read(transportProvider).value?.state?.bpm;
                  final sr = project.hardwareConfig.sampleRate;

                  if (bpm == null || sr == 0) {
                    throw Exception("BPM or Sample Rate is null or zero");
                  }
                  int cutPoint;
                  if (widget.clip.isSampleBased) {
                    // For audio clips: convert pixel→tick→sample
                    int cutTick =
                        widget.clip.startTimeInTicks(bpm, sr) +
                        (details.localPosition.dx * widget.zoomLevel).round();
                    cutTick = _snapClipShiftTick(
                      ticks: cutTick,
                      step: ref
                          .read(workspaceStateProvider)
                          .horizontalClipShiftSizeDenom,
                    );
                    // Convert back to samples for the backend
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

                  final result = await ref
                      .read(trackListStateProvider.notifier)
                      .sliceClip(widget.trackId, widget.clip.id, cutPoint);

                  if (result.isErr()) {
                    // Optional: Show error toast if cut fails (e.g. out of bounds)
                  }
                }
              },

              onPanStart: (details) {
                if (widget.selectedTool != ToolSelection.move &&
                    widget.selectedTool != ToolSelection.resize) {
                  return;
                }

                _accumulatedDeltaTicks = 0.0;
                _verticalDragDy = 0.0;
                _previousSnappedDelta = 0;

                final x = details.localPosition.dx;

                if (widget.selectedTool == ToolSelection.resize) {
                  if (x < resizeEdgeSize) {
                    setState(() => _currentAction = _DragAction.resizeLeft);
                  } else if (x > safeWidth - resizeEdgeSize) {
                    setState(() => _currentAction = _DragAction.resizeRight);
                  } else {
                    // Clicked the middle of the clip with the resize tool -> do nothing
                    return;
                  }
                } else if (widget.selectedTool == ToolSelection.move) {
                  // Move tool grabs the clip no matter where you click
                  setState(() => _currentAction = _DragAction.move);
                }

                // If the user starts dragging an UNSELECTED clip, select it first!
                final trackState = ref.read(trackListStateProvider.notifier);
                if (!widget.isSelected) {
                  trackState.selectClip(
                    trackId: widget.trackId,
                    clipId: widget.clip.id,
                  );
                }

                // Find the leader clip (the earliest one) to act as the snapping anchor
                final currentSelectedIds = ref
                    .read(trackListStateProvider)
                    .selectedClipIds;
                final track = ref
                    .read(projectProvider)
                    .value
                    ?.tracks[widget.trackId];
                if (track != null && currentSelectedIds.isNotEmpty) {
                  final tempo = ref.read(transportProvider).value?.state?.bpm;
                  final sr = ref
                      .read(projectProvider)
                      .value
                      ?.hardwareConfig
                      .sampleRate;
                  if (tempo == null || sr == null) {
                    throw Exception("Tempo or Sample Rate is null or zero");
                  }
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
                  _leaderBaseLoopLength = leaderClip.loopLengthInTicks(
                    tempo,
                    sr,
                  );
                }

                final batchAction = _currentAction == _DragAction.move
                    ? BatchDragAction.move
                    : _currentAction == _DragAction.resizeLeft
                    ? BatchDragAction.resizeLeft
                    : _currentAction == _DragAction.resizeRight
                    ? BatchDragAction.resizeRight
                    : BatchDragAction.none;

                widget.clipDragController.startBatchDrag(batchAction);
              },

              onPanUpdate: (details) {
                if (_currentAction == _DragAction.none) return;

                // final state = ref.read(globalStateProvider);
                final currentSelectedIds = ref
                    .read(trackListStateProvider)
                    .selectedClipIds;
                final track = ref
                    .read(projectProvider)
                    .value
                    ?.tracks[widget.trackId];
                if (track == null) return;

                _accumulatedDeltaTicks += details.delta.dx * widget.zoomLevel;
                _verticalDragDy += details.delta.dy;

                int rawTotalDelta = _accumulatedDeltaTicks.round();

                // Safety Clamp: Prevent shrinking past 10 ticks
                final minTicks = 10;
                final shortestClip = track.clips
                    .where((c) => currentSelectedIds.contains(c.id))
                    .reduce((a, b) => a.loopLength < b.loopLength ? a : b);

                if (_currentAction == _DragAction.resizeRight) {
                  final maxShrink = -(shortestClip.loopLength - minTicks);
                  if (rawTotalDelta < maxShrink) {
                    rawTotalDelta = maxShrink.toInt();
                  }
                } else if (_currentAction == _DragAction.resizeLeft) {
                  final maxShrink = shortestClip.loopLength - minTicks;
                  if (rawTotalDelta > maxShrink) {
                    rawTotalDelta = maxShrink.toInt();
                  }
                }

                int snappedTotalDelta = rawTotalDelta;

                // ======================================================
                // Snapping Logic
                // - snapToGrid ON  → clamp to absolute grid border (_snapTick)
                // - snapToGrid OFF → jump in step increments from the clip's
                //   initial position (_snapDeltaToStep), preserving the
                //   initial offset from the nearest step boundary.
                // ======================================================
                final workspaceStateProv = ref.read(workspaceStateProvider);
                if (_currentAction == _DragAction.move ||
                    _currentAction == _DragAction.resizeLeft) {
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

                // PUSH DATA TO THE OVERLAY
                widget.clipDragController.updateDrag(
                  snappedTotalDelta,
                  _verticalDragDy,
                );
              },

              onPanEnd: (_) {
                if (_currentAction == _DragAction.none) return;

                final state = ref.read(trackListStateProvider);
                final currentSelectedIds = state.selectedClipIds;

                int? newTrackId;
                final rowOffset = (_verticalDragDy / widget.height).round();
                if (rowOffset != 0) {
                  // Sort by visual orderIdx so vertical drag perfectly matches the UI layout
                  final trackListState = ref.read(
                    trackListStateProvider.notifier,
                  );
                  final sortedTracksList = trackListState
                      .getTracksFromProjectProvider()
                      .toValueIList()
                      .sort((a, b) => a.orderIdx.compareTo(b.orderIdx));
                  final sortedTracks = sortedTracksList
                      .map((t) => t.id)
                      .toList();

                  final currentIndex = sortedTracks.indexWhere(
                    (id) => id == widget.trackId,
                  );
                  if (currentIndex != -1) {
                    final targetIndex = currentIndex + rowOffset;
                    if (targetIndex >= 0 && targetIndex < sortedTracks.length) {
                      newTrackId = sortedTracks[targetIndex];
                    }
                  }
                }

                final isSampleBased = widget.clip.isSampleBased;
                final hardwareSampleRate = sampleRate;
                final delta = isSampleBased
                    ? ticksToSamples(
                        _previousSnappedDelta,
                        tempo,
                        hardwareSampleRate > 0 ? hardwareSampleRate : 48000,
                      )
                    : _previousSnappedDelta;

                // Send command to Rust backend
                if (_currentAction == _DragAction.move) {
                  ref
                      .read(trackListStateProvider.notifier)
                      .moveClipBatch(
                        widget.trackId,
                        currentSelectedIds.toList(),
                        delta,
                        newTrackId: newTrackId,
                      );
                } else if (_currentAction == _DragAction.resizeRight) {
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

                widget.clipDragController.reset();
              },

              child: _ClipRenderer(
                clip: widget.clip,
                trackType: widget.trackType,
                color: widget.color,
                zoomLevel: widget.zoomLevel,
                projectSampleRate:
                    ref
                        .read(projectProvider)
                        .value
                        ?.hardwareConfig
                        .sampleRate ??
                    48000,
                overrideOffset: _visualOffset.toDouble(),
                isSelected: widget.isSelected,
                scrollController: widget.horizontalScrollController,
                clipLeftOffset: left,
                waveformMap: widget.waveformMap,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// 2. THE CLIP RENDERER (The actual colored box)
// =============================================================================
