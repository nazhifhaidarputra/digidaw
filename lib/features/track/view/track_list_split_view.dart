part of 'track_list_screen.dart';

class _SplitTrackView extends ConsumerStatefulWidget {
  final List<int> trackIds;
  final double itemHeight;
  final double headerWidth;

  const _SplitTrackView({
    required this.trackIds,
    required this.itemHeight,
    required this.headerWidth,
  });

  @override
  ConsumerState<_SplitTrackView> createState() => _SplitTrackViewState();
}

class _SplitTrackViewState extends ConsumerState<_SplitTrackView> {
  late LinkedScrollControllerGroup _verticalControllers;
  late ScrollController _headerController;
  late ScrollController _timelineController;

  // Horizontal Scrolling (Ruler <-> Tracks)
  late LinkedScrollControllerGroup _horizontalControllers;
  late ScrollController _rulerController; // Controller 1: Top Ruler
  late ScrollController _trackContentController; // Controller 2: Bottom Content

  // Sample Browser scroll controller (not linked with other scroll controller like the header and audio slot)
  late ScrollController _browserPanelController;
  ProviderSubscription<bool>? _browserPanelSubscription;
  late final DawContext _dawContext;

  late MultiSplitViewController _trackSplitViewController;

  // Local state for ghost clip
  Offset? _mousePos;
  Offset? _lastRightClickPos;

  // LocalState for width
  double _timelineWidth = 2000.0;

  // ignore:unused_field
  StreamSubscription? _posSub;

  bool _isCtrlPressed = false;

  // Range selection state is now managed by rangeSelectProvider.
  // No local state needed here — the per-track TrackRangeSelectOverlay
  // widget renders the rect directly in each track's coordinate space.

  // ==========================================================================
  // BATCH CLIP DRAG STATE (handled by ClipPlacementNotifier now)
  // ==========================================================================

  @override
  void initState() {
    super.initState();
    _dawContext = ref.read(projectProvider.notifier).dawContext;
    unawaited(
      ref.read(workspaceStateProvider.notifier).restoreSampleDirectories(),
    );
    final browserExpanded = ref.read(
      workspaceStateProvider.select(
        (state) => state.browserPanelState.isExpanded,
      ),
    );
    _trackSplitViewController = MultiSplitViewController(
      areas: [
        Area(size: widget.headerWidth, min: 80, max: 240, data: 'header'),
        Area(min: 200, data: 'timeline'),
        if (browserExpanded)
          Area(size: 300, min: 220, max: 480, data: 'browser'),
      ],
    );

    // Initialize the Linked Group
    _verticalControllers = LinkedScrollControllerGroup();
    _headerController = _verticalControllers.addAndGet();
    _timelineController = _verticalControllers.addAndGet();
    _horizontalControllers = LinkedScrollControllerGroup();
    _rulerController = _horizontalControllers.addAndGet();
    _trackContentController = _horizontalControllers.addAndGet();
    _browserPanelController = ScrollController();
    _trackContentController.addListener(_handleScrollExpansion);
    HardwareKeyboard.instance.addHandler(_handleKeyEvents);
    _browserPanelSubscription = ref.listenManual<bool>(
      workspaceStateProvider.select(
        (state) => state.browserPanelState.isExpanded,
      ),
      (_, isExpanded) => _setBrowserPanelExpanded(isExpanded),
    );
  }

  void _setBrowserPanelExpanded(bool isExpanded) {
    final browserIndex = _trackSplitViewController.areas.indexWhere(
      (area) => area.data == 'browser',
    );
    if (isExpanded && browserIndex == -1) {
      _trackSplitViewController.addArea(
        Area(size: 300, min: 220, max: 480, data: 'browser'),
      );
    } else if (!isExpanded && browserIndex != -1) {
      _trackSplitViewController.removeAreaAt(browserIndex);
    }
  }

  @override
  void dispose() {
    _browserPanelSubscription?.close();
    _trackSplitViewController.dispose();
    _trackContentController.removeListener(_handleScrollExpansion);
    _headerController.dispose();
    _timelineController.dispose();
    _rulerController.dispose();
    _trackContentController.dispose();
    _browserPanelController.dispose();
    unawaited(audio_api.stopAllPreviews(ctx: _dawContext));
    HardwareKeyboard.instance.removeHandler(_handleKeyEvents);
    super.dispose();
  }

  bool _handleKeyEvents(KeyEvent event) {
    final isCtrl =
        HardwareKeyboard.instance.logicalKeysPressed.contains(
          LogicalKeyboardKey.controlLeft,
        ) ||
        HardwareKeyboard.instance.logicalKeysPressed.contains(
          LogicalKeyboardKey.controlRight,
        );

    if (isCtrl != _isCtrlPressed && mounted) {
      setState(() {
        _isCtrlPressed = isCtrl;
      });
    }
    return false;
  }

  void _handleScrollExpansion() {
    final maxScroll = _trackContentController.position.maxScrollExtent;
    final currentScroll = _trackContentController.offset;

    if (currentScroll >= maxScroll - 500) {
      setState(() {
        _timelineWidth += 2000.0;
      });
    }
  }

  void _updateZoom(double newZoom, double focalPointX) {
    final workspaceState = ref.read(workspaceStateProvider);
    final oldZoom = workspaceState.horizontalZoomLevel;

    final clampedZoom = newZoom.clamp(1.0, 1000.0);
    if (clampedZoom == oldZoom) return;

    final controller = _trackContentController;
    double currentScroll = controller.hasClients ? controller.offset : 0.0;
    double viewportWidth = controller.hasClients
        ? controller.position.viewportDimension
        : 1000.0;

    // Pivot Math: Lock the exact musical time under the cursor
    final double ticksAtFocalPoint = (currentScroll + focalPointX) * oldZoom;
    double newScroll = (ticksAtFocalPoint / clampedZoom) - focalPointX;
    if (newScroll < 0) newScroll = 0.0;

    final tracks = ref.read(projectProvider).value?.tracks.values ?? [];
    final tempo = ref.read(transportProvider).value?.state?.bpm ?? 120.0;
    final sampleRate = ref.read(transportProvider).value?.sampleRate ?? 48000;

    // Dynamic Window Strategy
    // Find the actual furthest tick of content in the project
    double maxContentTicks = 3840.0; // Base minimum 1 bar
    for (final track in tracks) {
      for (final clip in track.clips) {
        final endTick =
            clip.startTimeInTicks(tempo, sampleRate) +
            clip.loopLengthInTicks(tempo, sampleRate);
        if (endTick > maxContentTicks) {
          maxContentTicks = endTick.toDouble();
        }
      }
    }
    // Add 1 bar of padding to the end of the song
    maxContentTicks += 3840.0;

    // The pixel width required for the actual song content
    double contentWidth = maxContentTicks / clampedZoom;

    // The pixel width required to support the new scroll position + viewport size
    double requiredWindowWidth = newScroll + viewportWidth;

    // Set the timeline to wrap whichever is larger.
    // This allows zooming infinitely without clamping, but cleanly shrinks
    // the scrollbar exactly to the edge of the content when zooming out.
    double newTimelineWidth = math.max(contentWidth, requiredWindowWidth);

    // Update the state immediately
    ref.read(workspaceStateProvider.notifier).setHorizontalZoom(clampedZoom);
    setState(() {
      _timelineWidth = newTimelineWidth;
    });

    // Synchronous Jump
    // Because we are using UnclampedNeverScrollableScrollPhysics, this jump will
    // bypass Flutter's 1-frame layout boundary check, guaranteeing a flawless pivot.
    if (controller.hasClients) {
      controller.jumpTo(newScroll);
    }
  }

  void _handleTimelineGesture(BuildContext context, Offset localPosition) {
    final selectedTool = ref.read(workspaceStateProvider).selectedTool;
    double scrollX = 0;
    if (_trackContentController.hasClients) {
      scrollX = _trackContentController.offset;
    }
    final double absoluteX = localPosition.dx + scrollX;
    if (absoluteX < 0) return;

    switch (selectedTool) {
      case ToolSelection.zoom:
        break;
      case ToolSelection.draw:
        setState(() {
          _mousePos = localPosition;
        });
        break;
      case ToolSelection.pointer:
      case ToolSelection.slice:
      default:
        break;
    }
  }

  /// Helper method to build the cut helper line
  Widget _buildCutHelperLine(BuildContext context) {
    final state = ref.watch(workspaceStateProvider);
    if (_mousePos == null || state.selectedTool != ToolSelection.slice) {
      return const SizedBox();
    }

    double scrollX = 0;
    if (_trackContentController.hasClients) {
      scrollX = _trackContentController.offset;
    }

    double absoluteX = _mousePos!.dx + scrollX;
    if (absoluteX < 0) absoluteX = 0;

    final zoomLevel = state.horizontalZoomLevel;
    double ticks = absoluteX * zoomLevel;

    // Apply Shift Step Snapping for cut
    ticks = _snapClipShiftTick(
      ticks: ticks.toInt(),
      step: state.horizontalClipShiftSizeDenom,
    ).toDouble();

    double snappedAbsoluteX = ticks / zoomLevel;
    double left = snappedAbsoluteX - scrollX;

    // Hide if scrolled out of view to the left
    if (left < 0) return const SizedBox();

    return Positioned(
      left: left - 12, // Center the 24px wide column exactly on the cut point
      top: 0,
      bottom: 0,
      width: 24,
      child: IgnorePointer(
        child: Column(
          children: [
            const SizedBox(height: 10), // Padding above ruler
            const Icon(Icons.content_cut, color: Colors.redAccent, size: 16),
            Expanded(
              child: Container(
                width: 1.5,
                color: Colors.redAccent.withAlpha(200),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbar() {
    final workspaceState = ref.watch(workspaceStateProvider);
    return Container(
      height: 36,
      color: Colors.grey.shade900,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            const Text(
              "Snap to Grid",
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(width: 8),
            DropdownButton<GridSize>(
              value: workspaceState.gridSize,
              dropdownColor: Colors.grey.shade800,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              underline: const SizedBox(),
              items: GridSize.values.map((size) {
                final label = size.label;
                return DropdownMenuItem<GridSize>(
                  value: size,
                  child: Text(label),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  ref.read(workspaceStateProvider.notifier).setGridSize(val);
                }
              },
            ),
            const SizedBox(width: 16),
            TextButton.icon(
              onPressed: () => ref
                  .read(workspaceStateProvider.notifier)
                  .toggleBrowserPanel(),
              icon: Icon(
                Icons.library_music,
                size: 16,
                color: workspaceState.browserPanelState.isExpanded
                    ? Colors.cyanAccent
                    : Colors.white70,
              ),
              label: Text(
                'Samples',
                style: TextStyle(
                  color: workspaceState.browserPanelState.isExpanded
                      ? Colors.cyanAccent
                      : Colors.white70,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              "Move Step",
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(width: 8),
            DropdownButton<MusicalBeatSize>(
              value: workspaceState.horizontalClipShiftSizeDenom,
              dropdownColor: Colors.grey.shade800,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              underline: const SizedBox(),
              items: MusicalBeatSize.values.map((size) {
                return DropdownMenuItem<MusicalBeatSize>(
                  value: size,
                  child: Text(size.label),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  ref
                      .read(workspaceStateProvider.notifier)
                      .setHorizontalClipShiftSizeDenom(val);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderArea() {
    return Column(
      children: [
        Container(
          height: 30,
          color: Colors.grey.shade800,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 10),
          child: const Text(
            "Tracks",
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ),
        Expanded(
          child: CustomScrollView(
            controller: _headerController,
            slivers: [
              SliverToBoxAdapter(child: _buildMasterHeader()),
              _buildBusAutomationHeaderSection(),
              SliverList.builder(
                itemCount: widget.trackIds.length,
                itemBuilder: (context, index) {
                  final trackId = widget.trackIds[index];
                  return Consumer(
                    builder: (context, ref, _) {
                      final isExpanded = ref.watch(
                        trackAutomationExpandedProvider(trackId),
                      );
                      final lanes = ref.watch(
                        trackAutomationProvider(trackId),
                      ); // Using the API from previous steps
                      final trackColor = ref.watch(
                        projectProvider.select(
                          (s) =>
                              s.value?.tracks[trackId]?.color.toColor() ??
                              Colors.grey,
                        ),
                      );

                      return Column(
                        children: [
                          TrackHeader(
                            trackId: trackId,
                            itemHeight: widget.itemHeight,
                          ),
                          if (lanes.isNotEmpty)
                            AutomationExpandBar(
                              isExpanded: isExpanded,
                              laneCount: lanes.length,
                              trackColor: trackColor,
                              onTap: () => ref
                                  .read(automationProvider.notifier)
                                  .toggleTrackAutomationExpanded(trackId),
                            ),
                          if (isExpanded)
                            ...lanes.map(
                              (entry) => AutomationLaneHeader(
                                lane: entry.$3,
                                itemHeight: 60,
                                trackColor: trackColor,
                              ),
                            ),
                        ],
                      );
                    },
                  );
                },
              ),
              SliverToBoxAdapter(child: _buildAddButton()),
            ],
          ),
        ),
      ],
    );
  }

  Consumer _buildMasterHeader() {
    return Consumer(
      builder: (context, ref, _) {
        final lanes = ref.watch(masterAutomationProvider).toIList();
        final isExpanded = ref
            .watch(automationProvider)
            .isMasterAutomationDrawerOpened;
        final trackColor = const Color.fromRGBO(200, 100, 50, 1.0);

        if (lanes.isEmpty) return const SizedBox();

        return Column(
          children: [
            // A small header to visually separate the Master track
            Container(
              height: 30,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(left: 10),
              color: Colors.grey.shade900,
              child: const Text(
                "Master Track",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            AutomationExpandBar(
              isExpanded: isExpanded,
              laneCount: lanes.length,
              trackColor: trackColor,
              onTap: () => ref
                  .read(automationProvider.notifier)
                  .toggleMasterAutomationDrawer(),
            ),
            if (isExpanded)
              ...lanes.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: AutomationLaneHeader(
                    lane: entry.$3,
                    itemHeight: 60,
                    trackColor: trackColor,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildTimelineArea(BuildContext context) {
    final isPlacing = ref.watch(
      clipPlacementProvider.select((s) => s.isPlacing),
    );
    final workspaceState = ref.watch(workspaceStateProvider);
    final selectedTool = workspaceState.selectedTool;
    final horizontalZoom = workspaceState.horizontalZoomLevel;
    final selectedClipIds = ref.watch(
      trackListStateProvider.select((s) => s.selectedClipIds),
    );
    final bool isZooming = _isCtrlPressed || selectedTool == ToolSelection.zoom;

    MouseCursor handleCursor() {
      if (isPlacing) return SystemMouseCursors.move;
      if (selectedTool == ToolSelection.select) {
        return SystemMouseCursors.precise;
      }
      if (selectedTool == ToolSelection.slice) return SystemMouseCursors.text;
      return SystemMouseCursors.basic;
    }

    return Stack(
      children: [
        Column(
          children: [
            GestureDetector(
              onTapDown: (details) {
                double scrollX = _rulerController.hasClients
                    ? _rulerController.offset
                    : 0;
                double absoluteX = details.localPosition.dx + scrollX;
                final ticks = absoluteX * horizontalZoom;

                final pos = ref.read(transportPositionStreamProvider).value;
                if (pos == null) return;

                final sr = pos.sampleRate;
                final tempo = pos.tempo;

                final samples = (ticks * (60.0 / tempo) * (sr / 960.0)).round();
                AppLogger.info(
                  "[UI Seek] onTapDown: absoluteX=$absoluteX, ticks=$ticks, tempo=$tempo, sr=$sr -> samples=$samples",
                );
                ref.read(transportProvider.notifier).seekTo(samples);
              },
              onPanUpdate: (details) {
                // Throttled by the TransportNotifier's seekTo queue implementation
                double scrollX = _rulerController.hasClients
                    ? _rulerController.offset
                    : 0;
                double absoluteX = details.localPosition.dx + scrollX;
                final ticks = absoluteX * horizontalZoom;

                final pos = ref.read(transportPositionStreamProvider).value;
                if (pos == null) return;

                final sr = pos.sampleRate;
                final tempo = pos.tempo;

                final samples = (ticks * (60.0 / tempo) * (sr / 960.0)).round();
                AppLogger.info(
                  "[UI Seek] onPanUpdate: absoluteX=$absoluteX, ticks=$ticks, tempo=$tempo, sr=$sr -> samples=$samples",
                );
                ref.read(transportProvider.notifier).seekTo(samples);
              },
              child: Container(
                height: 30,
                color: Colors.grey.shade800,
                width: double.infinity,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  controller: _rulerController,
                  physics: isZooming
                      ? const UnclampedNeverScrollableScrollPhysics()
                      : const ClampingScrollPhysics(),
                  child: SizedBox(
                    width: _timelineWidth,
                    height: 30,
                    child: _TimelineRuler(
                      scrollController: _rulerController,
                      sampleRate:
                          ref.read(transportProvider).value?.sampleRate ??
                          48000,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: MouseRegion(
                cursor: handleCursor(),
                onHover: (event) {
                  _lastRightClickPos = event.localPosition;
                  if (selectedTool == ToolSelection.slice ||
                      selectedTool == ToolSelection.draw) {
                    setState(() => _mousePos = event.localPosition);
                  }
                },
                onExit: (_) {
                  if (isPlacing) return;
                  if (_mousePos != null) setState(() => _mousePos = null);
                },
                child: Listener(
                  onPointerDown: (event) {
                    _lastRightClickPos = event.localPosition;
                    _mousePos = event.localPosition;
                    if (event.buttons == kSecondaryButton) {
                      _lastRightClickPos = event.localPosition;
                      ref
                          .read(trackListStateProvider.notifier)
                          .deselectAllClips();
                      setState(() {});
                    }
                  },
                  child: DawInputDetector(
                    onCtrlScroll: (delta, localPosition) {
                      final double multiplier = delta > 0 ? 0.9 : 1.1;
                      _updateZoom(
                        horizontalZoom * multiplier,
                        localPosition.dx,
                      );
                    },
                    onPinchZoom: (details) {
                      _updateZoom(
                        horizontalZoom * details.scale,
                        details.focalPoint.dx,
                      );
                    },
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onPanUpdate: (details) {
                        if (selectedTool == ToolSelection.select) {
                          return;
                        }
                        if (selectedTool == ToolSelection.zoom) {
                          final double multiplier = details.delta.dy > 0
                              ? 0.9
                              : 1.1;
                          _updateZoom(
                            horizontalZoom * multiplier,
                            details.localPosition.dx,
                          );
                          return;
                        }
                        if (selectedTool == ToolSelection.draw || isPlacing) {
                          setState(() => _mousePos = details.localPosition);
                        }
                      },
                      onTapDown: isPlacing
                          ? (details) {
                              setState(() => _mousePos = details.localPosition);
                            }
                          : (details) => _handleTimelineGesture(
                              context,
                              details.localPosition,
                            ),
                      onPanStart: (details) {
                        if (selectedTool == ToolSelection.select) return;
                      },
                      onPanEnd: (details) {
                        if (selectedTool == ToolSelection.select) return;
                      },
                      child: ScrollConfiguration(
                        behavior:
                            (selectedTool == ToolSelection.pointer &&
                                !isPlacing)
                            ? DragScrollBehavior()
                            : ScrollConfiguration.of(context).copyWith(
                                dragDevices: {
                                  PointerDeviceKind.touch,
                                  PointerDeviceKind.trackpad,
                                },
                              ),
                        child: Scrollbar(
                          controller: _trackContentController,
                          thumbVisibility: true,
                          trackVisibility: true,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            controller: _trackContentController,
                            physics: isZooming
                                ? const UnclampedNeverScrollableScrollPhysics()
                                : const ClampingScrollPhysics(),
                            child: SizedBox(
                              width: _timelineWidth,
                              child: ContextMenuWrapper(
                                title: "Track Options",
                                actions: [
                                  DawContextAction(
                                    title: "Paste",
                                    icon: Icons.paste,
                                    onTap: () async {
                                      final targetPos = _lastRightClickPos;
                                      if (targetPos == null) return;

                                      double scrollY =
                                          _timelineController.hasClients
                                          ? _timelineController.offset
                                          : 0;
                                      double absoluteY = targetPos.dy + scrollY;

                                      if (widget.trackIds.isEmpty) return;
                                      int trackIndex =
                                          (absoluteY / widget.itemHeight)
                                              .floor();
                                      trackIndex = trackIndex.clamp(
                                        0,
                                        widget.trackIds.length - 1,
                                      );
                                      final targetTrackId =
                                          widget.trackIds[trackIndex];
                                      final track = ref
                                          .read(projectProvider)
                                          .value
                                          ?.tracks[targetTrackId];
                                      if (track == null) return;

                                      double scrollX =
                                          _trackContentController.hasClients
                                          ? _trackContentController.offset
                                          : 0;
                                      double absoluteX =
                                          (targetPos.dx + scrollX).clamp(
                                            0,
                                            double.infinity,
                                          );
                                      double ticks = absoluteX * horizontalZoom;

                                      if (workspaceState.snapToGrid) {
                                        ticks = _snapTick(
                                          ticks.toInt(),
                                          workspaceState,
                                        ).toDouble();
                                      }

                                      int pasteStartTime;
                                      if (track.trackType ==
                                          UiTrackType.audio) {
                                        final sr =
                                            ref
                                                .read(transportProvider)
                                                .value
                                                ?.sampleRate ??
                                            48000;
                                        final tempo =
                                            ref
                                                .read(transportProvider)
                                                .value
                                                ?.state
                                                ?.bpm ??
                                            120.0;
                                        pasteStartTime = ticksToSamples(
                                          ticks.toInt(),
                                          tempo,
                                          sr,
                                        );
                                      } else {
                                        pasteStartTime = ticks.toInt();
                                      }

                                      final result = await ref
                                          .read(trackListStateProvider.notifier)
                                          .pasteClips(
                                            targetTrackId: targetTrackId,
                                            pasteStartTime: pasteStartTime,
                                            trackType: track.trackType,
                                          );

                                      if (result.isOk()) {
                                        AppLogger.info("Paste clip");
                                        setState(
                                          () => _lastRightClickPos = null,
                                        );
                                      }
                                    },
                                  ),
                                ],
                                child: CustomScrollView(
                                  controller: _timelineController,
                                  physics: isZooming
                                      ? const UnclampedNeverScrollableScrollPhysics()
                                      : const ClampingScrollPhysics(),
                                  slivers: [
                                    SliverToBoxAdapter(
                                      child:
                                          _buildMasterTimelineAutomationLanes(),
                                    ),
                                    _buildBusAutomationTimelineSection(),
                                    _buildTimelineTrackWidget(),
                                    const SliverToBoxAdapter(
                                      child: SizedBox(height: 60),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),

        // Overlays inside the Timeline Stack
        // (Range selection rect is rendered per-track inside AudioTrackSlot via TrackRangeSelectOverlay)
        _buildCutHelperLine(context),

        Positioned.fill(
          child: IgnorePointer(
            ignoring: false,
            child: PlayheadOverlay(
              offsetAdjustment: 0.0,
              scrollController: _trackContentController,
              zoomLevel: horizontalZoom,
              sampleSelector: (pos) => pos.ticks,
              onSeek: (int newTicks) {
                final pos = ref.read(transportPositionStreamProvider).value;
                if (pos == null) return;
                final tempo = pos.tempo;
                final sampleRate = pos.sampleRate;
                if (tempo <= 0 || sampleRate <= 0) return;
                final safeTicks = newTicks < 0 ? 0 : newTicks;
                final samples =
                    (safeTicks * (60.0 / tempo) * (sampleRate / 960.0)).round();
                AppLogger.info(
                  "[UI Seek] onSeek: safeTicks=$safeTicks, tempo=$tempo, sr=$sampleRate -> samples=$samples",
                );
                ref.read(transportProvider.notifier).seekTo(samples);
              },
            ),
          ),
        ),

        // if (isPlacing)
        //   Positioned(
        //     bottom: 30,
        //     right: 30,
        //     child: Row(
        //       children: [
        //         FloatingActionButton.extended(
        //           heroTag: 'cancel_place',
        //           label: const Text("Cancel"),
        //           icon: const Icon(Icons.close),
        //           backgroundColor: Colors.redAccent,
        //           onPressed: () {
        //             ref.read(clipPlacementProvider.notifier).cancelPlacement();
        //           },
        //         ),
        //         const SizedBox(width: 16),
        //         FloatingActionButton.extended(
        //           heroTag: 'confirm_place',
        //           onPressed: () async {
        //             final result = await ref
        //                 .read(clipPlacementProvider.notifier)
        //                 .confirmPlacement();
        //             if (result.isErr() && context.mounted) {
        //               ScaffoldMessenger.of(context).showSnackBar(
        //                 SnackBar(
        //                   content: Text((result as Error).toErrorMessage()),
        //                 ),
        //               );
        //             }
        //           },
        //           label: const Text('Confirm'),
        //           icon: const Icon(Icons.check),
        //           backgroundColor: Colors.greenAccent,
        //         ),
        //       ],
        //     ),
        //   ),
        if (selectedClipIds.isNotEmpty)
          FloatingContextPanel(
            actions: [
              DawContextAction(
                title: "Copy",
                icon: Icons.copy,
                onTap: () async {
                  final trackId = ref
                      .read(trackListStateProvider)
                      .selectedTrackId;
                  if (trackId == null) return;
                  await ref
                      .read(trackListStateProvider.notifier)
                      .copySelectedClips(
                        trackId: trackId,
                        clipIds: selectedClipIds.toList(),
                      );
                },
              ),
              DawContextAction(
                title: "Cut",
                icon: Icons.cut,
                onTap: () async {
                  final trackId = ref
                      .read(trackListStateProvider)
                      .selectedTrackId;
                  if (trackId == null) return;
                  await ref
                      .read(trackListStateProvider.notifier)
                      .cutSelectedClips(
                        trackId: trackId,
                        clipIds: selectedClipIds.toList(),
                      );
                  ref.read(trackListStateProvider.notifier).deselectAllClips();
                },
              ),
              DawContextAction(
                title: "Delete",
                icon: Icons.delete,
                isDestructive: true,
                onTap: () async {
                  ref
                      .read(trackListStateProvider.notifier)
                      .deleteSelectedClips();
                  ref.read(trackListStateProvider.notifier).deselectAllClips();
                },
              ),
            ],
            onClose: () =>
                ref.read(trackListStateProvider.notifier).deselectAllClips(),
            title:
                "${selectedClipIds.length} Clip${selectedClipIds.length == 1 ? '' : 's'}",
          ),
      ],
    );
  }

  Widget _buildTimelineTrackWidget() {
    return SliverList.builder(
      itemCount: widget.trackIds.length,
      itemBuilder: (context, index) {
        final trackId = widget.trackIds[index];
        return Consumer(
          builder: (context, ref, _) {
            final isExpanded = ref.watch(
              trackAutomationExpandedProvider(trackId),
            );
            final lanes = ref.watch(trackAutomationProvider(trackId));
            final trackColor = ref.watch(
              projectProvider.select(
                (s) => s.value?.tracks[trackId]?.color.toColor() ?? Colors.grey,
              ),
            );

            final sr = ref.read(transportProvider).value?.sampleRate ?? 48000;

            return Column(
              children: [
                AudioTrackSlot(
                  trackId: trackId,
                  height: widget.itemHeight,
                  horizontalScrollController: _trackContentController,
                  sampleRate: sr,
                ),
                if (lanes.isNotEmpty)
                  AutomationExpandBar(
                    isExpanded: isExpanded,
                    laneCount: lanes.length,
                    trackColor: trackColor,
                    onTap: () => ref
                        .read(automationProvider.notifier)
                        .toggleTrackAutomationExpanded(trackId),
                  ),
                if (isExpanded)
                  ...lanes.map(
                    (entry) => AutomationLaneSlot(
                      lane: entry.$3,
                      height: 60,
                      horizontalScrollController: _trackContentController,
                      trackColor: trackColor,
                      sampleRate: sr,
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildMasterTimelineAutomationLanes() {
    return Consumer(
      builder: (context, ref, _) {
        final lanes = ref.watch(masterAutomationProvider).toIList();
        final isExpanded = ref
            .watch(automationProvider)
            .isMasterAutomationDrawerOpened;
        final trackColor = const Color.fromRGBO(200, 100, 50, 1.0);
        final sr = ref.read(transportProvider).value?.sampleRate ?? 48000;

        if (lanes.isEmpty) return const SizedBox();

        return Column(
          children: [
            // Empty space to perfectly align with the "Master Track" title block on the left
            const SizedBox(height: 30),
            // AutomationExpandBar is duplicated here as a spacer to keep the layout aligned with the header side
            AutomationExpandBar(
              isExpanded: isExpanded,
              laneCount: lanes.length,
              trackColor: trackColor,
              onTap: () => ref
                  .read(automationProvider.notifier)
                  .toggleMasterAutomationDrawer(),
            ),
            if (isExpanded)
              ...lanes.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: AutomationLaneSlot(
                    lane: entry.$3,
                    height: 60,
                    horizontalScrollController: _trackContentController,
                    trackColor: trackColor,
                    sampleRate: sr,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildAddButton() {
    return SizedBox(
      height: 60,
      child: Center(
        child: TextButton.icon(
          onPressed: () => _showAddTrackDialog(context),
          icon: const Icon(Icons.add, color: Colors.white54),
          label: const Text(
            "Add New Track",
            style: TextStyle(color: Colors.white54),
          ),
        ),
      ),
    );
  }

  void _showAddTrackDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text("Add New Track"),
        children: [
          SimpleDialogOption(
            onPressed: () async {
              Navigator.pop(ctx);
              final result = await ref
                  .read(trackListStateProvider.notifier)
                  .addAudioTrack();
              result.when(
                data: (_) {},
                loading: () {},
                error: (error, stack) {
                  AppLogger.error("Error adding audio track: $error");
                },
              );
            },
            child: const Row(
              children: [
                Icon(Icons.graphic_eq, color: Colors.cyanAccent),
                SizedBox(width: 10),
                Text("Audio Track"),
              ],
            ),
          ),
          const Divider(),
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(ctx);
              _showGeneratorBrowser(context);
            },
            child: const Row(
              children: [
                Icon(Icons.piano, color: Colors.orangeAccent),
                SizedBox(width: 10),
                Text("Add generator..."),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showGeneratorBrowser(BuildContext context) async {
    final availablePlugins = await ref
        .read(audioPluginProvider.notifier)
        .getAvailableGenerators();

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Generator Browser"),
        contentPadding: const EdgeInsets.only(top: 12, bottom: 24),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category header: Karbeat Native
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.extension,
                      size: 16,
                      color: Colors.deepOrangeAccent,
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.deepOrangeAccent.withAlpha(30),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: Colors.deepOrangeAccent.withAlpha(80),
                        ),
                      ),
                      child: const Text(
                        "Karbeat Native",
                        style: TextStyle(
                          color: Colors.deepOrangeAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Plugin list
              if (availablePlugins.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Text(
                    "No generators found",
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              else
                ...availablePlugins.map(
                  (plugin) => _buildGeneratorBrowserItem(ctx, plugin),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneratorBrowserItem(BuildContext ctx, UiPluginInfo plugin) {
    return InkWell(
      onTap: () {
        Navigator.pop(ctx);
        ref
            .read(trackListStateProvider.notifier)
            .addMidiTrackWithGeneratorId(plugin.id);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.piano, color: Colors.orangeAccent, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plugin.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    "Karbeat Native",
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBusAutomationHeaderSection() {
    return Consumer(
      builder: (context, ref, _) {
        final buses = ref.watch(
          projectProvider.select((s) => s.value?.mixer.buses),
        );
        if (buses == null || buses.isEmpty) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }

        final busIds = buses.keys.toList()..sort();

        return SliverList.builder(
          itemCount: busIds.length,
          itemBuilder: (context, index) {
            final busId = busIds[index];
            final bus = buses[busId]!;

            return Consumer(
              builder: (context, ref, _) {
                final lanes = ref.watch(busAutomationProvider(busId)).toIList();
                final isExpanded = ref.watch(
                  busAutomationExpandedProvider(busId),
                );
                final trackColor =
                    Colors.teal.shade400; // Distinct color for Buses

                if (lanes.isEmpty) return const SizedBox.shrink();

                return Column(
                  children: [
                    // Bus Title Header
                    Container(
                      height: 30,
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.only(left: 10),
                      color: Colors.grey.shade800,
                      child: Text(
                        bus.name,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    AutomationExpandBar(
                      isExpanded: isExpanded,
                      laneCount: lanes.length,
                      trackColor: trackColor,
                      onTap: () => ref
                          .read(automationProvider.notifier)
                          .toggleBusAutomationExpanded(busId),
                    ),
                    if (isExpanded)
                      ...lanes.map(
                        (entry) => Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: AutomationLaneHeader(
                            lane: entry.$3,
                            itemHeight: 60,
                            trackColor: trackColor,
                          ),
                        ),
                      ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildBusAutomationTimelineSection() {
    return Consumer(
      builder: (context, ref, _) {
        final buses = ref.watch(
          projectProvider.select((s) => s.value?.mixer.buses),
        );
        if (buses == null || buses.isEmpty) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }

        final busIds = buses.keys.toList()..sort();
        final sr = ref.read(transportProvider).value?.sampleRate ?? 48000;

        return SliverList.builder(
          itemCount: busIds.length,
          itemBuilder: (context, index) {
            final busId = busIds[index];

            return Consumer(
              builder: (context, ref, _) {
                final lanes = ref.watch(busAutomationProvider(busId)).toIList();
                final isExpanded = ref.watch(
                  busAutomationExpandedProvider(busId),
                );
                final trackColor = Colors.teal.shade400;

                if (lanes.isEmpty) return const SizedBox.shrink();

                return Column(
                  children: [
                    // Empty space to perfectly align with the Bus Title block on the left
                    const SizedBox(height: 30),
                    // AutomationExpandBar is duplicated here as a spacer to keep layout aligned
                    AutomationExpandBar(
                      isExpanded: isExpanded,
                      laneCount: lanes.length,
                      trackColor: trackColor,
                      onTap: () => ref
                          .read(automationProvider.notifier)
                          .toggleBusAutomationExpanded(busId),
                    ),
                    if (isExpanded)
                      ...lanes.map(
                        (entry) => Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: AutomationLaneSlot(
                            lane: entry.$3,
                            height: 60,
                            horizontalScrollController: _trackContentController,
                            trackColor: trackColor,
                            sampleRate: sr,
                          ),
                        ),
                      ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildToolbar(),
        Expanded(
          child: MultiSplitViewTheme(
            data: MultiSplitViewThemeData(
              dividerPainter: DividerPainters.grooved1(
                color: Colors.grey.shade800,
                highlightedColor: Colors.cyanAccent,
                thickness: 1,
              ),
            ),
            child: MultiSplitView(
              controller: _trackSplitViewController,
              builder: (context, area) {
                switch (area.data) {
                  case 'header':
                    return _buildHeaderArea();
                  case 'timeline':
                    return _buildTimelineArea(context);
                  case 'browser':
                    return SampleBrowserPanel(
                      scrollController: _browserPanelController,
                    );
                  default:
                    return const SizedBox();
                }
              },
            ),
          ),
        ),
      ],
    );
  }
}

class AutomationExpandBar extends StatelessWidget {
  final bool isExpanded;
  final int laneCount;
  final Color trackColor;
  final VoidCallback onTap;

  const AutomationExpandBar({
    super.key,
    required this.isExpanded,
    required this.laneCount,
    required this.trackColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
        border: Border(
          right: BorderSide(color: Colors.grey.shade400, width: 1),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 16,
              height: 16,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: trackColor.withAlpha(60),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Center(
                child: Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_down
                      : Icons.keyboard_arrow_right,
                  color: trackColor,
                  size: 14,
                ),
              ),
            ),
            Icon(Icons.show_chart, color: trackColor, size: 12),
            const SizedBox(width: 6),
            Text(
              '$laneCount automation lane${laneCount == 1 ? '' : 's'}',
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
