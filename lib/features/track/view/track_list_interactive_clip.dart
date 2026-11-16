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
  final bool isPendingDelete;
  final List<int> selectedClipIds;
  final ScrollController horizontalScrollController;
  final Map<int, WaveformHandle> waveformMap;
  final bool compact;

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
    this.isPendingDelete = false,
    this.compact = false,
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

  /// Runs while a second click would count as a double-click.
  Timer? _doubleClickWindow;

  /// Whether the drag in progress edits a selection spanning several tracks
  /// or lanes. Such a drag keeps every item on its own row.
  bool _isSelectionDrag = false;

  /// Scrolls the timeline while a move or resize nears its edge; the scrolled
  /// distance counts as pointer travel.
  late final TimelineEdgeAutoScroller _autoScroller = TimelineEdgeAutoScroller(
    onScrolled: (dx) {
      switch (_currentAction) {
        case _DragAction.move:
          _moveBy(dx);
        case _DragAction.resizeLeft || _DragAction.resizeRight:
          _resizeBy(dx);
        case _DragAction.none:
          break;
      }
    },
  );

  @override
  void initState() {
    super.initState();
    _syncModel();
  }

  @override
  void dispose() {
    _doubleClickWindow?.cancel();
    _autoScroller.stop();
    super.dispose();
  }

  /// Start and end of the earliest selected item, the anchor that snaps to
  /// the grid while the selection moves or resizes.
  (int, int)? _selectionLeader() {
    final spans = ref.read(trackListStateProvider.notifier).selectionSpans();
    if (spans.isEmpty) return null;
    return spans.reduce((a, b) => a.$1 <= b.$1 ? a : b);
  }

  /// Adds [dx] pixels to a move drag and publishes the snapped move.
  void _moveBy(double dx) {
    if (_currentAction != _DragAction.move) return;
    _accumulatedDeltaTicks += dx * widget.zoomLevel;
    final rawStart = _leaderBaseStartTime + _accumulatedDeltaTicks.round();
    var snappedTotalDelta =
        _snapTick(rawStart, ref.read(workspaceStateProvider)) -
        _leaderBaseStartTime;

    if (_isSelectionDrag) {
      snappedTotalDelta = ref
          .read(trackListStateProvider.notifier)
          .clampSelectionMove(snappedTotalDelta);
    } else if (snappedTotalDelta < -_leaderBaseStartTime) {
      // _leaderBaseStartTime is the leftmost clip in the selection, so
      // leaderBaseStart + delta >= 0  =>  delta >= -leaderBaseStartTime.
      snappedTotalDelta = -_leaderBaseStartTime;
    }
    _previousSnappedDelta = snappedTotalDelta;

    final placementState = ref.read(clipPlacementProvider);
    ref
        .read(clipPlacementProvider.notifier)
        .updateBatchDrag(
          targetTrackId: _isSelectionDrag
              ? widget.trackId
              : placementState.trackId,
          snappedDeltaTicks: snappedTotalDelta,
        );
  }

  /// Adds [dx] pixels to a resize drag and publishes the snapped resize.
  void _resizeBy(double dx) {
    if (_currentAction != _DragAction.resizeLeft &&
        _currentAction != _DragAction.resizeRight) {
      return;
    }
    final isRight = _currentAction == _DragAction.resizeRight;
    _accumulatedDeltaTicks += dx * widget.zoomLevel;
    int rawTotalDelta = _accumulatedDeltaTicks.round();

    const minTicks = 10;
    if (!_isSelectionDrag) {
      final currentSelectedIds = ref
          .read(trackListStateProvider)
          .clipsSelectedOn(widget.trackId);
      final track = ref.read(projectProvider).value?.tracks[widget.trackId];
      if (track == null) return;
      final tempo = ref.read(transportProvider).value?.state?.bpm ?? 120.0;
      final sampleRate = ref.read(transportProvider).value?.sampleRate ?? 48000;
      final lengths = track.clips
          .where((c) => currentSelectedIds.contains(c.id))
          .map((clip) => clip.loopLengthInTicks(tempo, sampleRate));
      if (lengths.isEmpty) return;
      final shortestClipLengthTicks = lengths.reduce(math.min);
      final maxShrink = shortestClipLengthTicks - minTicks;
      if (isRight && rawTotalDelta < -maxShrink) rawTotalDelta = -maxShrink;
      if (!isRight && rawTotalDelta > maxShrink) rawTotalDelta = maxShrink;
    }

    final workspaceStateProv = ref.read(workspaceStateProvider);
    int snappedTotalDelta;
    if (isRight) {
      final leaderEnd = _leaderBaseStartTime + _leaderBaseLoopLength;
      snappedTotalDelta =
          _snapTick(leaderEnd + rawTotalDelta, workspaceStateProv) - leaderEnd;
    } else {
      snappedTotalDelta =
          _snapTick(_leaderBaseStartTime + rawTotalDelta, workspaceStateProv) -
          _leaderBaseStartTime;
    }
    if (_isSelectionDrag) {
      snappedTotalDelta = ref
          .read(trackListStateProvider.notifier)
          .clampSelectionResize(
            isRight ? UiResizeEdge.right : UiResizeEdge.left,
            snappedTotalDelta,
            minTicks: minTicks,
          );
    }

    _previousSnappedDelta = snappedTotalDelta;
    ref
        .read(clipPlacementProvider.notifier)
        .updateBatchDrag(
          targetTrackId: widget.trackId,
          snappedDeltaTicks: snappedTotalDelta,
        );
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
    _visualStartTime = widget.clip.startTimeInTicks;
    _visualLoopLength = widget.clip.loopLengthInTicks(bpm, sr);
    _visualOffset = widget.clip.offsetStartInTicks(bpm, sr);
  }

  /// The clip's actions; built when the menu opens, so they act on the
  /// selection as it is then.
  void _showContextMenu(BuildContext context) {
    showDawContextMenu(
      context: context,
      title: widget.clip.name,
      actions: clipActions(
        context: context,
        ref: ref,
        trackId: widget.trackId,
        clip: widget.clip,
      ).forContextMenu,
    );
  }

  void _openClipInformation() =>
      openClipInformation(context, ref, widget.trackId, widget.clip);

  /// A double-click opens a pattern in the piano roll and shows the clip
  /// information of an audio clip.
  void _openOnDoubleClick() {
    switch (widget.clip.source) {
      case UiClipSource_Midi():
        openClipInPianoRoll(ref, widget.trackId, widget.clip);
      case UiClipSource_Audio():
        _openClipInformation();
      case UiClipSource_None():
        break;
    }
  }

  /// Records a click and reports whether it completes a double-click. The
  /// first click still acts as a normal click, so single clicks stay instant.
  bool _completesDoubleClick() {
    if (widget.selectedTool == ToolSelection.delete ||
        widget.selectedTool == ToolSelection.slice) {
      return false;
    }
    final window = _doubleClickWindow;
    if (window != null && window.isActive) {
      window.cancel();
      _doubleClickWindow = null;
      return true;
    }
    _doubleClickWindow = Timer(kDoubleTapTimeout, () {});
    return false;
  }

  @override
  Widget build(BuildContext context) {
    // Coordinate Mapping (Pixels)
    final double left = _visualStartTime / widget.zoomLevel;
    final double width = _visualLoopLength / widget.zoomLevel;
    final double safeWidth = width < 1 ? 1 : width;
    const resizeEdgeSize = 25.0;

    final sampleRate =
        ref.watch(transportProvider.select((s) => s.value?.sampleRate)) ??
        48000;
    final tempo =
        ref.watch(transportProvider.select((s) => s.value?.state?.bpm)) ??
        120.0;

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
    // Only the drag flag matters here; the full placement state changes on
    // every pointer move during a drag or placement.
    final isDraggingExisting = ref.watch(
      clipPlacementProvider.select((s) => s.isDraggingExisting),
    );
    final isPartOfBatchDrag = widget.isSelected && isDraggingExisting;

    return Positioned(
      left: left,
      top: 2,
      height: widget.height - 4,
      width: safeWidth,
      child: Opacity(
        // Leader becomes invisible (has overlay), followers become semi-transparent
        opacity: widget.isPendingDelete
            ? 0.2
            : isPartOfBatchDrag
            ? 0.3
            : 1.0,
        child: IgnorePointer(
          ignoring: isDraggingExisting,
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
      projectSampleRate: sampleRate,
      overrideOffset: _visualOffset.toDouble(),
      isSelected: widget.isSelected,
      scrollController: widget.horizontalScrollController,
      clipLeftOffset: left,
      waveformMap: widget.waveformMap,
      compact: widget.compact,
      trackId: widget.trackId,
      envelopeInteractive: switch (widget.selectedTool) {
        ToolSelection.panSelect ||
        ToolSelection.draw ||
        ToolSelection.select => true,
        _ => false,
      },
    );

    final gestureDetector = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (details) async {
        if (_completesDoubleClick()) {
          _openOnDoubleClick();
          return;
        }
        if (widget.selectedTool == ToolSelection.select) {
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
        } else if (widget.selectedTool == ToolSelection.panSelect) {
          ref
              .read(trackListStateProvider.notifier)
              .selectClip(trackId: widget.trackId, clipId: widget.clip.id);
        } else if (widget.selectedTool == ToolSelection.slice) {
          int cutPoint =
              widget.clip.startTimeInTicks +
              (details.localPosition.dx * widget.zoomLevel).round();
          cutPoint = _snapTick(cutPoint, ref.read(workspaceStateProvider));

          final trackList = ref.read(trackListStateProvider.notifier);
          // A clip of a multi-track selection cuts the whole selection.
          if (widget.isSelected &&
              ref.read(trackListStateProvider).spansLanes) {
            await trackList.sliceSelection(cutPoint);
          } else {
            await trackList.sliceClip(widget.trackId, widget.clip.id, cutPoint);
          }
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

              final selection = ref.read(trackListStateProvider);
              _isSelectionDrag = selection.spansLanes;
              final leader = _selectionLeader();
              if (leader != null) {
                _leaderBaseStartTime = leader.$1;
                _leaderBaseLoopLength = leader.$2 - leader.$1;
              }

              final batchAction = _currentAction == _DragAction.resizeLeft
                  ? BatchDragAction.resizeLeft
                  : BatchDragAction.resizeRight;

              ref
                  .read(clipPlacementProvider.notifier)
                  .startBatchDrag(
                    clipIds: selection.clipsSelectedOn(widget.trackId).toList(),
                    action: batchAction,
                    originalTrackId: widget.trackId,
                    isSelectionDrag: _isSelectionDrag,
                  );
            }
          : null,
      onPanUpdate: (widget.selectedTool == ToolSelection.resize)
          ? (details) {
              if (_currentAction == _DragAction.none) return;
              _resizeBy(details.delta.dx);
              _autoScroller.update(context, details.globalPosition);
            }
          : null,
      onPanEnd: (widget.selectedTool == ToolSelection.resize)
          ? (_) {
              if (_currentAction == _DragAction.none) return;
              _autoScroller.stop();

              final currentSelectedIds = ref
                  .read(trackListStateProvider)
                  .clipsSelectedOn(widget.trackId);
              // The track list's stretch mode stretches audio clips instead
              // of trimming them.
              final stretch = ref.read(workspaceStateProvider).resizeStretches;
              final edge = _currentAction == _DragAction.resizeRight
                  ? UiResizeEdge.right
                  : UiResizeEdge.left;
              final trackList = ref.read(trackListStateProvider.notifier);

              if (_isSelectionDrag) {
                trackList.resizeSelection(
                  edge,
                  _previousSnappedDelta,
                  stretch: stretch,
                );
              } else {
                trackList.resizeClipBatch(
                  widget.trackId,
                  currentSelectedIds.toList(),
                  edge,
                  _previousSnappedDelta,
                  stretch: stretch,
                );
              }

              setState(() {
                _currentAction = _DragAction.none;
                _isSelectionDrag = false;
              });

              ref.read(clipPlacementProvider.notifier).cancelBatchDrag();
            }
          : null,
      child: clipRenderer,
    );

    // Rebuilds the menu when the envelope view it shows a check for changes.
    ref.watch(workspaceStateProvider.select((s) => s.clipEnvelopeView));
    final interactiveChild = Builder(
      builder: (context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPress: () => _showContextMenu(context),
        onSecondaryTap: () => _showContextMenu(context),
        child: gestureDetector,
      ),
    );

    if (widget.selectedTool == ToolSelection.move) {
      return Draggable<List<int>>(
        data: widget.selectedClipIds.isNotEmpty && widget.isSelected
            ? widget.selectedClipIds
            : [widget.clip.id],
        feedback: const SizedBox.shrink(),
        childWhenDragging: interactiveChild,
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

          final selection = ref.read(trackListStateProvider);
          _isSelectionDrag = selection.spansLanes;
          final leader = _selectionLeader();
          if (leader != null) {
            _leaderBaseStartTime = leader.$1;
            _leaderBaseLoopLength = leader.$2 - leader.$1;
          }

          ref
              .read(clipPlacementProvider.notifier)
              .startBatchDrag(
                clipIds: selection.clipsSelectedOn(widget.trackId).toList(),
                action: BatchDragAction.move,
                originalTrackId: widget.trackId,
                isSelectionDrag: _isSelectionDrag,
              );
        },
        onDragUpdate: (details) {
          if (_currentAction != _DragAction.move) return;
          _moveBy(details.delta.dx);
          _autoScroller.update(context, details.globalPosition);
        },
        onDragEnd: (details) {
          if (_currentAction != _DragAction.move) return;
          _autoScroller.stop();

          final trackList = ref.read(trackListStateProvider.notifier);
          if (_isSelectionDrag) {
            trackList.moveSelection(_previousSnappedDelta);
          } else {
            final currentSelectedIds = ref
                .read(trackListStateProvider)
                .clipsSelectedOn(widget.trackId);
            final placementState = ref.read(clipPlacementProvider);
            int? newTrackId =
                placementState.trackId != widget.trackId &&
                    placementState.trackId != -1
                ? placementState.trackId
                : null;

            trackList.moveClipBatch(
              widget.trackId,
              currentSelectedIds.toList(),
              _previousSnappedDelta,
              newTrackId: newTrackId,
            );
          }

          setState(() {
            _currentAction = _DragAction.none;
            _isSelectionDrag = false;
          });

          ref.read(clipPlacementProvider.notifier).cancelBatchDrag();
        },
        child: interactiveChild,
      );
    }

    return interactiveChild;
  }
}
