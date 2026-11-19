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
  late final ValueNotifier<List<int>> _trackOrderController;
  List<int>? _trackOrderBeforeDrag;
  int? _draggedTrackId;

  // Horizontal Scrolling (Ruler <-> Tracks)
  late LinkedScrollControllerGroup _horizontalControllers;
  late ScrollController _rulerController; // Controller 1: Top Ruler
  late ScrollController _trackContentController; // Controller 2: Bottom Content

  // Right panel scroll controllers (browser and source list tabs).
  late ScrollController _browserPanelController;
  late ScrollController _sourcePanelController;
  late ScrollController _itemsPanelController;
  ProviderSubscription<bool>? _rightPanelSubscription;
  ProviderSubscription<bool>? _mixerPanelSubscription;
  late final DawContext _dawContext;

  late MultiSplitViewController _trackSplitViewController;

  // Local state for ghost clip
  Offset? _mousePos;

  // LocalState for width
  /// Pixel width of the scrollable timeline. A notifier so zooming and
  /// scroll expansion resize the timeline without rebuilding the split view
  /// (track headers, panels, every row).
  final _timelineWidth = ValueNotifier<double>(2000.0);

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
    _trackOrderController = ValueNotifier(List.unmodifiable(widget.trackIds));
    final rightPanelExpanded = ref.read(
      workspaceStateProvider.select((state) => state.isRightPanelExpanded),
    );
    _trackSplitViewController = MultiSplitViewController(
      areas: [
        if (ref.read(mixerChannelPanelTargetProvider) != null)
          _mixerPanelArea(),
        Area(size: widget.headerWidth, min: 160, max: 300, data: 'header'),
        Area(min: 200, data: 'timeline'),
        if (rightPanelExpanded)
          Area(size: 300, min: 220, max: 480, data: 'rightPanel'),
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
    _sourcePanelController = ScrollController();
    _itemsPanelController = ScrollController();
    _trackContentController.addListener(_handleScrollExpansion);
    HardwareKeyboard.instance.addHandler(_handleKeyEvents);
    _rightPanelSubscription = ref.listenManual<bool>(
      workspaceStateProvider.select((state) => state.isRightPanelExpanded),
      (_, isExpanded) => _setRightPanelExpanded(isExpanded),
    );
    _mixerPanelSubscription = ref.listenManual<bool>(
      mixerChannelPanelTargetProvider.select((target) => target != null),
      (_, isOpen) => _setMixerPanelOpen(isOpen),
    );
  }

  Area _mixerPanelArea() =>
      Area(size: 350, min: 300, max: 520, data: 'mixerPanel');

  /// Shows or hides the mixer channel panel at the far left.
  void _setMixerPanelOpen(bool isOpen) {
    final areas = _trackSplitViewController.areas;
    final panelIndex = areas.indexWhere((area) => area.data == 'mixerPanel');
    if (isOpen && panelIndex == -1) {
      _trackSplitViewController.areas = [_mixerPanelArea(), ...areas];
    } else if (!isOpen && panelIndex != -1) {
      _trackSplitViewController.removeAreaAt(panelIndex);
    }
  }

  @override
  void didUpdateWidget(covariant _SplitTrackView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_draggedTrackId == null &&
        !listEquals(_trackOrderController.value, widget.trackIds)) {
      _trackOrderController.value = List.unmodifiable(widget.trackIds);
    }
  }

  void _setRightPanelExpanded(bool isExpanded) {
    final panelIndex = _trackSplitViewController.areas.indexWhere(
      (area) => area.data == 'rightPanel',
    );
    if (isExpanded && panelIndex == -1) {
      _trackSplitViewController.addArea(
        Area(size: 300, min: 220, max: 480, data: 'rightPanel'),
      );
    } else if (!isExpanded && panelIndex != -1) {
      _trackSplitViewController.removeAreaAt(panelIndex);
    }
  }

  Future<void> _stopBrowserPreviews() async {
    try {
      await audio_api.stopAllPreviews(ctx: _dawContext);
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to stop browser sample previews during track view teardown',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  void dispose() {
    _rightPanelSubscription?.close();
    _mixerPanelSubscription?.close();
    _trackOrderController.dispose();
    _trackSplitViewController.dispose();
    _trackContentController.removeListener(_handleScrollExpansion);
    _timelineWidth.dispose();
    _headerController.dispose();
    _timelineController.dispose();
    _rulerController.dispose();
    _trackContentController.dispose();
    _browserPanelController.dispose();
    _sourcePanelController.dispose();
    _itemsPanelController.dispose();
    unawaited(_stopBrowserPreviews());
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
      _timelineWidth.value += 2000.0;
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
            clip.startTimeInTicks + clip.loopLengthInTicks(tempo, sampleRate);
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
    _timelineWidth.value = newTimelineWidth;

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
      case ToolSelection.panSelect:
      case ToolSelection.slice:
      default:
        break;
    }
  }

  /// Helper method to build the cut helper line
  Widget _buildCutHelperLine(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final state = ref.watch(
      workspaceStateProvider.select(
        (state) => (
          selectedTool: state.selectedTool,
          horizontalZoomLevel: state.horizontalZoomLevel,
          snapToGrid: state.snapToGrid,
          gridSize: state.gridSize,
        ),
      ),
    );
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

    // The cut lands on the grid, like the slice itself
    if (state.snapToGrid) {
      ticks = state.gridSize.snap(ticks.toInt()).toDouble();
    }

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
            Icon(Icons.content_cut, color: colors.error, size: 16),
            Expanded(
              child: Container(
                width: 1.5,
                color: colors.error.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// An on/off toolbar button. The active state gets a tinted background as
  /// well as the primary color, since some themes give inactive controls the
  /// same color as primary.
  Widget _buildToolbarToggle({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onPressed,
  }) {
    final colors = Theme.of(context).colorScheme;
    final foreground = isActive ? colors.primary : colors.onSurfaceVariant;
    return TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: isActive
            ? colors.primary.withValues(alpha: 0.2)
            : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      icon: Icon(icon, size: 16, color: foreground),
      label: Text(label, style: TextStyle(color: foreground, fontSize: 12)),
    );
  }

  Widget _buildToolbar() {
    final workspaceState = ref.watch(
      workspaceStateProvider.select(
        (state) => (
          gridSize: state.gridSize,
          isRightPanelExpanded: state.isRightPanelExpanded,
          resizeStretches: state.resizeStretches,
        ),
      ),
    );
    final colors = Theme.of(context).colorScheme;
    return Container(
      height: 36,
      color: colors.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Text(
              tr('workspace-snap-to-grid'),
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
            ),
            const SizedBox(width: 8),
            DropdownButton<GridSize>(
              value: workspaceState.gridSize,
              dropdownColor: colors.surfaceContainerHigh,
              style: TextStyle(color: colors.onSurface, fontSize: 12),
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
            _buildToolbarToggle(
              icon: Icons.vertical_split,
              label: tr('track-right-panel'),
              isActive: workspaceState.isRightPanelExpanded,
              onPressed: () =>
                  ref.read(workspaceStateProvider.notifier).toggleRightPanel(),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: tr('track-resizing-audio-clips-stretches-their'),
              child: _buildToolbarToggle(
                icon: Icons.open_in_full,
                label: tr('track-stretch'),
                isActive: workspaceState.resizeStretches,
                onPressed: () => ref
                    .read(workspaceStateProvider.notifier)
                    .toggleResizeStretches(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Opens the drawer and lane that show [row], then scrolls the timeline so
  /// [tick] on it is in view.
  void _revealTimelineItem(TimelineRow row, int tick) {
    if (row case TimelineLaneRow(:final laneId)) {
      final automation = ref.read(automationProvider.notifier);
      final index = ref.read(automationLaneIndexProvider);
      bool holds(IList<ChannelAutomationEntry>? entries) =>
          entries?.any((entry) => entry.laneId == laneId) ?? false;
      if (holds(index.master)) automation.ensureMasterAutomationDrawerOpened();
      for (final MapEntry(:key, :value) in index.buses.entries) {
        if (holds(value)) automation.ensureBusAutomationExpanded(key);
      }
      for (final MapEntry(:key, :value) in index.tracks.entries) {
        if (holds(value)) automation.ensureTrackAutomationExpanded(key);
      }
      if (ref
          .read(automationProvider)
          .collapsedAutomationLaneIds
          .contains(laneId)) {
        automation.toggleAutomationLaneCollapsed(laneId: laneId);
      }
    }
    // Scroll once the opened drawers are laid out.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scrollToTimelineRow(row, tick);
    });
  }

  void _scrollToTimelineRow(TimelineRow row, int tick) {
    const duration = Duration(milliseconds: 250);
    if (_trackContentController.hasClients) {
      final zoom = ref.read(workspaceStateProvider).horizontalZoomLevel;
      final position = _trackContentController.position;
      final target = (tick / zoom - position.viewportDimension * 0.1).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      _trackContentController.animateTo(
        target,
        duration: duration,
        curve: Curves.easeOut,
      );
    }
    final y = _timelineRowOffset(row);
    if (y != null && _timelineController.hasClients) {
      final position = _timelineController.position;
      _timelineController.animateTo(
        (y - 24).clamp(position.minScrollExtent, position.maxScrollExtent),
        duration: duration,
        curve: Curves.easeOut,
      );
    }
  }

  /// Top of [target] in the timeline's vertical scroll view, following the
  /// layout of [_buildMasterTimelineAutomationLanes],
  /// [_buildBusAutomationTimelineSection] and [_buildTimelineTrackWidget].
  /// Null when the row is not shown.
  double? _timelineRowOffset(TimelineRow target) {
    const expandBarHeight = 26.0;
    const channelLanePadding = 4.0;
    final automation = ref.read(automationProvider);
    final index = ref.read(automationLaneIndexProvider);
    final trackList = ref.read(trackListStateProvider);
    double laneHeight(int laneId) =>
        ref.read(automationLaneLayoutProvider(laneId)).height;

    var y = 0.0;
    double? channelLanes(IList<ChannelAutomationEntry>? lanes, bool open) {
      y += _ChannelTitleRow.height;
      if (lanes == null || lanes.isEmpty) return null;
      y += expandBarHeight;
      if (!open) return null;
      for (final entry in lanes) {
        y += channelLanePadding;
        if (target == TimelineRow.lane(entry.laneId)) return y;
        y += laneHeight(entry.laneId);
      }
      return null;
    }

    final master = channelLanes(
      index.master,
      automation.isMasterAutomationDrawerOpened,
    );
    if (master != null) return master;

    final busIds =
        ref.read(projectProvider).value?.mixer.buses.keys.toList() ?? <int>[];
    busIds.sort();
    for (final busId in busIds) {
      final bus = channelLanes(
        index.buses[busId],
        !automation.collapsedBusAutomations.contains(busId),
      );
      if (bus != null) return bus;
    }

    for (final trackId in _trackOrderController.value) {
      if (target == TimelineRow.track(trackId)) return y;
      y += _trackHeightOf(trackList, trackId);
      final lanes = index.tracks[trackId];
      if (lanes == null || lanes.isEmpty) continue;
      y += expandBarHeight;
      if (automation.collapsedTrackAutomations.contains(trackId)) continue;
      for (final entry in lanes) {
        if (target == TimelineRow.lane(entry.laneId)) return y;
        y += laneHeight(entry.laneId);
      }
    }
    return null;
  }

  /// Effective arranger row height of a track, honoring shrunk tracks.
  double _trackHeightOf(TrackListState state, int trackId) =>
      state.collapsedTrackIds.contains(trackId)
      ? TrackListNotifier.collapsedLaneHeight
      : (state.trackIdHeightMap.get(trackId) ?? widget.itemHeight).toDouble();

  /// Header side of one automation lane. Mirrors
  /// [_buildAutomationLaneTimelineRow] so both sides share the same height.
  Widget _buildAutomationLaneHeaderRow(
    ChannelAutomationEntry entry,
    Color trackColor,
  ) {
    return Consumer(
      key: ValueKey(('automation-header', entry.laneId)),
      builder: (context, ref, _) {
        final layout = ref.watch(automationLaneLayoutProvider(entry.laneId));
        final notifier = ref.read(automationProvider.notifier);
        return Stack(
          children: [
            AutomationLaneContextMenu(
              entry: entry,
              // With the Select tool a header click selects the lane's
              // regions.
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (ref.read(workspaceStateProvider).selectedTool !=
                      ToolSelection.select) {
                    return;
                  }
                  ref
                      .read(trackListStateProvider.notifier)
                      .selectAllRegionsOn(entry.laneId);
                },
                child: AutomationLaneHeader(
                  lane: entry.lane,
                  sourceName: entry.sourceName,
                  itemHeight: layout.height,
                  trackColor: trackColor,
                  collapsed: layout.collapsed,
                  onToggleCollapsed: () => notifier
                      .toggleAutomationLaneCollapsed(laneId: entry.laneId),
                  onToggleEnabled: () =>
                      notifier.handleSetAutomationLaneEnabled(
                        laneId: entry.laneId,
                        enabled: !entry.lane.enabled,
                      ),
                ),
              ),
            ),
            if (!layout.collapsed)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: HeaderResizeHandle(
                  onDelta: (dy) => notifier.changeAutomationLaneHeight(
                    laneId: entry.laneId,
                    newHeight:
                        (ref
                                    .read(
                                      automationLaneLayoutProvider(
                                        entry.laneId,
                                      ),
                                    )
                                    .height +
                                dy)
                            .round(),
                  ),
                  onReset: () =>
                      notifier.resetAutomationLaneHeight(laneId: entry.laneId),
                ),
              ),
          ],
        );
      },
    );
  }

  /// Timeline side of one automation lane; shrunk lanes show only a title.
  Widget _buildAutomationLaneTimelineRow(
    ChannelAutomationEntry entry,
    Color trackColor,
    int sampleRate,
  ) {
    return Consumer(
      key: ValueKey(('automation-timeline', entry.laneId)),
      builder: (context, ref, _) {
        final layout = ref.watch(automationLaneLayoutProvider(entry.laneId));
        return AutomationLaneContextMenu(
          entry: entry,
          child: layout.collapsed
              ? AutomationLaneCollapsedSlot(
                  lane: entry.lane,
                  sourceName: entry.sourceName,
                  height: layout.height,
                  horizontalScrollController: _trackContentController,
                  trackColor: trackColor,
                )
              : AutomationLaneSlot(
                  lane: entry.lane,
                  height: layout.height,
                  horizontalScrollController: _trackContentController,
                  trackColor: trackColor,
                  sampleRate: sampleRate,
                ),
        );
      },
    );
  }

  Widget _buildHeaderArea() {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        Container(
          height: 30,
          color: colors.surfaceContainer,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 10),
          child: Text(
            tr('workspace-view-tracks'),
            style: TextStyle(color: colors.onSurface, fontSize: 12),
          ),
        ),
        Expanded(
          child: CustomScrollView(
            controller: _headerController,
            slivers: [
              SliverToBoxAdapter(child: _buildMasterHeader()),
              _buildBusAutomationHeaderSection(),
              ValueListenableBuilder<List<int>>(
                valueListenable: _trackOrderController,
                builder: (context, trackIds, _) => SliverList.builder(
                  itemCount: trackIds.length,
                  findChildIndexCallback: _findTrackIndex,
                  itemBuilder: (context, index) =>
                      _buildHeaderItem(context, trackIds, index),
                ),
              ),
              SliverToBoxAdapter(child: _buildAddButton()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderItem(BuildContext context, List<int> trackIds, int index) {
    final trackId = trackIds[index];
    final colors = Theme.of(context).colorScheme;

    return DragTarget<int>(
      key: ValueKey(trackId),
      onWillAcceptWithDetails: (details) {
        _previewTrackOrder(details.data, index);
        return true;
      },
      onAcceptWithDetails: (details) {
        unawaited(_commitTrackOrder(details.data));
      },
      builder: (context, _, _) => Consumer(
        builder: (context, ref, _) {
          final isExpanded = ref.watch(
            trackAutomationExpandedProvider(trackId),
          );
          final lanes = ref.watch(trackAutomationProvider(trackId));
          final trackColor = ref.watch(
            projectProvider.select(
              (s) =>
                  s.value?.tracks[trackId]?.color.fromRGBorRGBAtoColor() ??
                  colors.onSurfaceVariant,
            ),
          );

          final height = ref.watch(
            trackListStateProvider.select((s) => _trackHeightOf(s, trackId)),
          );
          final isCollapsed = ref.watch(
            trackListStateProvider.select(
              (s) => s.collapsedTrackIds.contains(trackId),
            ),
          );

          return Column(
            children: [
              Stack(
                children: [
                  TrackHeader(
                    trackId: trackId,
                    itemHeight: height,
                    isSelected: ref.watch(
                      mixerChannelPanelTargetProvider.select(
                        (target) =>
                            target == UiMixerChannelTarget.track(trackId),
                      ),
                    ),
                    // With the Select tool a header click selects the
                    // track's clips; otherwise it shows its mixer channel.
                    onSelect: () {
                      final trackList = ref.read(
                        trackListStateProvider.notifier,
                      );
                      if (ref.read(workspaceStateProvider).selectedTool ==
                          ToolSelection.select) {
                        trackList.selectAllClipsOn(trackId);
                      } else {
                        trackList.selectMixerChannel(
                          UiMixerChannelTarget.track(trackId),
                        );
                      }
                    },
                    onDragStarted: () => _startTrackDrag(trackId),
                    onDragEnded: _endTrackDrag,
                  ),
                  if (!isCollapsed)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: HeaderResizeHandle(
                        onDelta: (dy) => _onHeaderResize(trackId, dy),
                        onReset: () => _onHeaderResizeReset(trackId),
                      ),
                    ),
                ],
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
                  (entry) => _buildAutomationLaneHeaderRow(entry, trackColor),
                ),
            ],
          );
        },
      ),
    );
  }

  void _onHeaderResize(int trackId, double dy) {
    final current =
        ref
            .read(trackListStateProvider)
            .trackIdHeightMap
            .get(trackId)
            ?.toDouble() ??
        widget.itemHeight;
    ref
        .read(trackListStateProvider.notifier)
        .changeHeight(trackId: trackId, newHeight: (current + dy).round());
  }

  void _onHeaderResizeReset(int trackId) {
    ref
        .read(trackListStateProvider.notifier)
        .resetTrackHeight(trackId: trackId);
  }

  int? _findTrackIndex(Key key) {
    if (key is! ValueKey<int>) return null;
    final index = _trackOrderController.value.indexOf(key.value);
    return index == -1 ? null : index;
  }

  void _startTrackDrag(int trackId) {
    _draggedTrackId = trackId;
    _trackOrderBeforeDrag = _trackOrderController.value;
  }

  void _previewTrackOrder(int trackId, int newIndex) {
    if (_draggedTrackId != trackId) return;
    final trackIds = _trackOrderController.value;
    final oldIndex = trackIds.indexOf(trackId);
    if (oldIndex == -1 || oldIndex == newIndex) return;

    final reordered = List<int>.from(trackIds)
      ..removeAt(oldIndex)
      ..insert(newIndex, trackId);
    _trackOrderController.value = List.unmodifiable(reordered);
  }

  Future<void> _commitTrackOrder(int trackId) async {
    if (_draggedTrackId != trackId) return;
    final newIndex = _trackOrderController.value.indexOf(trackId);
    _draggedTrackId = null;
    _trackOrderBeforeDrag = null;
    if (newIndex == -1) return;

    AppLogger.info("Update track order requested for track ID: $trackId");
    final result = await ref
        .read(trackListStateProvider.notifier)
        .handleUpdateTrackOrder(trackId: trackId, newIdx: newIndex);
    if (mounted && result.isErr()) {
      _trackOrderController.value = List.unmodifiable(widget.trackIds);
    }
  }

  void _endTrackDrag(bool wasAccepted) {
    if (wasAccepted) return;
    final previousOrder = _trackOrderBeforeDrag;
    _draggedTrackId = null;
    _trackOrderBeforeDrag = null;
    if (previousOrder != null) {
      _trackOrderController.value = previousOrder;
    }
  }

  Consumer _buildMasterHeader() {
    return Consumer(
      builder: (context, ref, _) {
        final colors = Theme.of(context).colorScheme;
        final lanes = ref.watch(masterAutomationProvider);
        final isExpanded = ref
            .watch(automationProvider)
            .isMasterAutomationDrawerOpened;
        final trackColor = colors.tertiary;
        const target = UiMixerChannelTarget.master();

        return Column(
          children: [
            // Always shown, so the master can be selected for the mixer panel
            MixerChannelContextMenu(
              target: target,
              child: _ChannelTitleRow(
                title: tr('track-master-track'),
                target: target,
                rainbow: true,
              ),
            ),
            if (lanes.isNotEmpty)
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
                  child: _buildAutomationLaneHeaderRow(entry, trackColor),
                ),
              ),
          ],
        );
      },
    );
  }

  void _seekToTicks(int ticks) {
    final pos = ref.read(transportPositionStreamProvider).value;
    if (pos == null) return;
    final tempo = pos.tempo;
    final sampleRate = pos.sampleRate;
    if (tempo <= 0 || sampleRate <= 0) return;
    final safeTicks = ticks < 0 ? 0 : ticks;
    final samples = (safeTicks * (60.0 / tempo) * (sampleRate / 960.0)).round();
    ref.read(transportProvider.notifier).seekTo(samples);
  }

  Widget _buildTimelineArea(BuildContext context) {
    final isPlacing = ref.watch(
      clipPlacementProvider.select((s) => s.isPlacing),
    );
    final selectedTool = ref.watch(
      workspaceStateProvider.select((state) => state.selectedTool),
    );
    // Read at event time rather than watched: watching zoom here rebuilt the
    // whole split view on every zoom step.
    double currentZoom() =>
        ref.read(workspaceStateProvider).horizontalZoomLevel;
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
      clipBehavior: Clip.none,
      children: [
        Column(
          children: [
            ValueListenableBuilder<double>(
              valueListenable: _timelineWidth,
              builder: (context, timelineWidth, _) => _TimelineRulerBar(
                scrollController: _rulerController,
                timelineWidth: timelineWidth,
                physics: isZooming
                    ? const UnclampedNeverScrollableScrollPhysics()
                    : const ClampingScrollPhysics(),
                onSeekTicks: _seekToTicks,
              ),
            ),
            Expanded(
              child: MouseRegion(
                cursor: handleCursor(),
                onHover: (event) {
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
                    _mousePos = event.localPosition;
                    if (event.buttons == kSecondaryButton) {
                      ref
                          .read(trackListStateProvider.notifier)
                          .deselectAllClips();
                      setState(() {});
                    }
                  },
                  child: DawInputDetector(
                    onCtrlScroll: (delta, localPosition) {
                      final double multiplier = delta > 0 ? 0.9 : 1.1;
                      _updateZoom(currentZoom() * multiplier, localPosition.dx);
                    },
                    onPinchZoom: (details) {
                      _updateZoom(
                        currentZoom() * details.scale,
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
                            currentZoom() * multiplier,
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
                            (selectedTool == ToolSelection.panSelect &&
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
                            child: ValueListenableBuilder<double>(
                              valueListenable: _timelineWidth,
                              // The content is built once and passed through,
                              // so a width change only relayouts it.
                              builder: (context, width, content) =>
                                  SizedBox(width: width, child: content),
                              child: ContextMenuWrapper(
                                title: tr('track-track-options'),
                                actions: [
                                  DawContextAction(
                                    title: tr('track-paste'),
                                    icon: Icons.paste,
                                    // The track slot under the pointer
                                    // records its own track and tick on
                                    // pointer down (right click included).
                                    // Deriving the track from the click's y
                                    // missed automation rows and picked the
                                    // wrong track.
                                    onTap: () async {
                                      final result = await ref
                                          .read(trackListStateProvider.notifier)
                                          .pasteClipsAtLastClick();
                                      if (result.isOk()) {
                                        AppLogger.info("Paste clip");
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
        Positioned.fill(
          top: _rulerHeight,
          child: _TimelineAnnotationLines(
            scrollController: _trackContentController,
          ),
        ),
        // Zoom-dependent overlays watch zoom themselves, so a zoom step
        // rebuilds them and not the whole split view.
        Consumer(
          builder: (context, ref, _) => _buildCutHelperLine(context, ref),
        ),

        Positioned.fill(
          child: IgnorePointer(
            ignoring: false,
            child: Consumer(
              builder: (context, ref, _) => PlayheadOverlay(
                offsetAdjustment: 0.0,
                scrollController: _trackContentController,
                zoomLevel: ref.watch(
                  workspaceStateProvider.select((s) => s.horizontalZoomLevel),
                ),
                sampleSelector: (pos) => pos.ticks,
                snapPosition: (ticks) =>
                    _snapTick(ticks, ref.read(workspaceStateProvider)),
                onSeek: _seekToTicks,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Quick actions for the selected clips and regions, and for a range
  /// painted on an automation lane. It floats over the whole track list, so
  /// resizing the split areas does not move it. Actions that don't fit move
  /// behind "More…".
  Widget _buildSelectionPanel() {
    return Consumer(
      builder: (context, ref, _) {
        final selection = ref.watch(trackListStateProvider);
        // A range painted with the Select tool on an automation lane.
        final rangeLaneId = ref.watch(
          automationEditorProvider.select((s) {
            final laneId = s.selectionLaneId;
            final range = laneId == null ? null : s.selectionOf(laneId);
            return range != null && range.$2 > range.$1 ? laneId : null;
          }),
        );
        if (!selection.hasSelection && rangeLaneId == null) {
          return const SizedBox.shrink();
        }
        // The actions describe the current clips, regions, clipboard and
        // template library.
        final project = ref.watch(projectProvider).value;
        ref.watch(automationEditorProvider.select((s) => s.clipboard));
        ref.watch(automationTemplatesProvider);
        ref.watch(workspaceStateProvider.select((s) => s.clipEnvelopeView));
        if (project == null) return const SizedBox.shrink();

        final trackList = ref.read(trackListStateProvider.notifier);
        final editor = ref.read(automationEditorProvider.notifier);
        final rangeLane = rangeLaneId == null
            ? null
            : project.automationPool[rangeLaneId];
        final rangeActions = rangeLane == null
            ? const <DawContextAction>[]
            : automationRangeActions(
                context: context,
                ref: ref,
                lane: rangeLane,
              );

        final itemActions = <DawContextAction>[];
        final trackId = selection.selectedTrackId;
        final regionLaneId = selection.selectedRegionLaneId;
        if (trackId != null) {
          final selectedIds = selection.selectedClipIds;
          final clips = project.tracks[trackId]?.clips ?? const <UiClip>[];
          final clip =
              clips.where((c) => c.id == selection.focusClipId).firstOrNull ??
              clips.where((c) => selectedIds.contains(c.id)).firstOrNull;
          if (clip != null) {
            itemActions.addAll(
              clipActions(
                context: context,
                ref: ref,
                trackId: trackId,
                clip: clip,
              ).forQuickMenu,
            );
          }
        } else if (regionLaneId != null) {
          itemActions.addAll(
            regionActions(
              context: context,
              ref: ref,
              laneId: regionLaneId,
              regionIds: selection.regionsSelectedOn(regionLaneId).toList(),
            ).forQuickMenu,
          );
        } else if (selection.hasSelection) {
          // Clips and regions of several rows only move, resize, slice and
          // delete together.
          itemActions.addAll([
            DawContextAction(
              title: tr('common-delete'),
              icon: Icons.delete,
              isDestructive: true,
              onTap: trackList.deleteSelectedClips,
            ),
            DawContextAction(
              title: tr('track-loop-to-selection'),
              icon: Icons.loop,
              onTap: () => loopToSelection(ref),
            ),
          ]);
        }

        final count = selection.selectionCount;
        return FloatingContextPanel(
          // With nothing selected the range comes first, led by "Create
          // region"; otherwise the selected items do.
          actions: [...itemActions, ...rangeActions],
          onClose: () {
            trackList.deselectAllClips();
            editor.clearSelection();
          },
          title: count > 0
              ? tr('track-items-selected', {'count': count})
              : tr('track-range', {'lane': rangeLane?.label ?? ''}),
        );
      },
    );
  }

  Widget _buildTimelineTrackWidget() {
    return ValueListenableBuilder<List<int>>(
      valueListenable: _trackOrderController,
      builder: (context, trackIds, _) => SliverList.builder(
        itemCount: trackIds.length,
        findChildIndexCallback: _findTrackIndex,
        itemBuilder: (context, index) {
          final trackId = trackIds[index];
          return Consumer(
            key: ValueKey(trackId),
            builder: (context, ref, _) {
              final isExpanded = ref.watch(
                trackAutomationExpandedProvider(trackId),
              );
              final lanes = ref.watch(trackAutomationProvider(trackId));
              final trackColor = ref.watch(
                projectProvider.select(
                  (s) =>
                      s.value?.tracks[trackId]?.color.fromRGBorRGBAtoColor() ??
                      Theme.of(context).colorScheme.outline,
                ),
              );

              final height = ref.watch(
                trackListStateProvider.select(
                  (s) => _trackHeightOf(s, trackId),
                ),
              );
              final isCollapsed = ref.watch(
                trackListStateProvider.select(
                  (s) => s.collapsedTrackIds.contains(trackId),
                ),
              );

              final sr = ref.read(transportProvider).value?.sampleRate ?? 48000;

              return Column(
                children: [
                  AudioTrackSlot(
                    trackId: trackId,
                    height: height,
                    collapsed: isCollapsed,
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
                      (entry) => _buildAutomationLaneTimelineRow(
                        entry,
                        trackColor,
                        sr,
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildMasterTimelineAutomationLanes() {
    return Consumer(
      builder: (context, ref, _) {
        final lanes = ref.watch(masterAutomationProvider);
        final isExpanded = ref
            .watch(automationProvider)
            .isMasterAutomationDrawerOpened;
        final trackColor = Theme.of(context).colorScheme.tertiary;
        final sr = ref.read(transportProvider).value?.sampleRate ?? 48000;

        return Column(
          children: [
            // Empty space to perfectly align with the "Master Track" title block on the left
            const SizedBox(height: _ChannelTitleRow.height),
            // AutomationExpandBar is duplicated here as a spacer to keep the layout aligned with the header side
            if (lanes.isNotEmpty)
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
                  child: _buildAutomationLaneTimelineRow(entry, trackColor, sr),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildAddButton() {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: 60,
      child: Center(
        child: TextButton.icon(
          onPressed: () => _showAddTrackDialog(context),
          icon: Icon(Icons.add, color: colors.primary),
          label: Text(
            tr('track-add-new-track'),
            style: TextStyle(color: colors.primary),
          ),
        ),
      ),
    );
  }

  void _showAddTrackDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(tr('track-add-new-track')),
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
            child: Row(
              children: [
                Icon(
                  Icons.graphic_eq,
                  color: Theme.of(ctx).colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Text(tr('track-audio-track')),
              ],
            ),
          ),
          const Divider(),
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(ctx);
              _showGeneratorBrowser(context);
            },
            child: Row(
              children: [
                Icon(Icons.piano, color: Theme.of(ctx).colorScheme.tertiary),
                const SizedBox(width: 10),
                Text(tr('track-add-generator')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showGeneratorBrowser(BuildContext context) async {
    await showPluginBrowserDialog(
      context: context,
      pluginType: KarbeatPluginType.generator,
      onAdd: (plugin) => ref
          .read(trackListStateProvider.notifier)
          .addMidiTrackWithGeneratorId(plugin.registryId),
    );
  }

  Widget _buildBusAutomationHeaderSection() {
    return Consumer(
      builder: (context, ref, _) {
        // Lock to an IMap so the select compares bus contents; a plain Map is
        // compared by identity and is replaced on every mixer publish.
        final buses = ref.watch(
          projectProvider.select((s) => s.value?.mixer.buses.lock),
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
                final lanes = ref.watch(busAutomationProvider(busId));
                final isExpanded = ref.watch(
                  busAutomationExpandedProvider(busId),
                );
                final trackColor = bus.color.fromRGBorRGBAtoColor();
                final target = UiMixerChannelTarget.bus(busId);

                return Column(
                  children: [
                    // Bus Title Header: always shown, so the bus can be
                    // selected for the mixer panel
                    MixerChannelContextMenu(
                      target: target,
                      child: _ChannelTitleRow(
                        title: bus.name,
                        target: target,
                        color: trackColor,
                      ),
                    ),
                    if (lanes.isNotEmpty)
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
                          child: _buildAutomationLaneHeaderRow(
                            entry,
                            trackColor,
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
        // Lock to an IMap so the select compares bus contents; a plain Map is
        // compared by identity and is replaced on every mixer publish.
        final buses = ref.watch(
          projectProvider.select((s) => s.value?.mixer.buses.lock),
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
            final trackColor = buses[busId]!.color.fromRGBorRGBAtoColor();

            return Consumer(
              builder: (context, ref, _) {
                final lanes = ref.watch(busAutomationProvider(busId));
                final isExpanded = ref.watch(
                  busAutomationExpandedProvider(busId),
                );

                return Column(
                  children: [
                    // Empty space to perfectly align with the Bus Title block on the left
                    const SizedBox(height: _ChannelTitleRow.height),
                    // AutomationExpandBar is duplicated here as a spacer to keep layout aligned
                    if (lanes.isNotEmpty)
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
                          child: _buildAutomationLaneTimelineRow(
                            entry,
                            trackColor,
                            sr,
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
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        _buildToolbar(),
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              MultiSplitViewTheme(
                data: MultiSplitViewThemeData(
                  dividerPainter: DividerPainters.grooved1(
                    color: colors.outlineVariant,
                    highlightedColor: colors.primary,
                    thickness: 1,
                  ),
                ),
                child: MultiSplitView(
                  controller: _trackSplitViewController,
                  areaClipBehavior: Clip.none,
                  builder: (context, area) {
                    switch (area.data) {
                      case 'mixerPanel':
                        return const MixerChannelSidePanel();
                      case 'header':
                        return _buildHeaderArea();
                      case 'timeline':
                        // Areas paint in reverse order, so without a clip the
                        // playhead and cut line overflow onto the browser panel.
                        return ClipRect(child: _buildTimelineArea(context));
                      case 'rightPanel':
                        return RightSidePanel(
                          browserScrollController: _browserPanelController,
                          sourceScrollController: _sourcePanelController,
                          itemsScrollController: _itemsPanelController,
                          onRevealItem: _revealTimelineItem,
                        );
                      default:
                        return const SizedBox();
                    }
                  },
                ),
              ),
              _buildSelectionPanel(),
            ],
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
    final colors = Theme.of(context).colorScheme;
    return Container(
      height: 24,
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        border: Border(
          right: BorderSide(color: colors.outlineVariant, width: 1),
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
              tr('track-automation-lanes', {'count': laneCount}),
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

/// Title row of the master or a bus in the header column. Tapping it shows
/// the channel in the mixer channel panel.
class _ChannelTitleRow extends ConsumerWidget {
  static const double height = 30;

  final String title;
  final UiMixerChannelTarget target;

  /// Background of the row; ignored when [rainbow] is set.
  final Color? color;

  /// Paints the animated master rainbow behind the title.
  final bool rainbow;

  const _ChannelTitleRow({
    required this.title,
    required this.target,
    this.color,
    this.rainbow = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final isSelected = ref.watch(
      mixerChannelPanelTargetProvider.select((shown) => shown == target),
    );
    final background = color ?? colors.surfaceContainerLow;
    final foreground = rainbow || background.computeLuminance() > 0.5
        ? Colors.black
        : Colors.white;

    final row = Container(
      height: height,
      decoration: BoxDecoration(color: rainbow ? null : background),
      foregroundDecoration: isSelected
          ? BoxDecoration(
              border: Border(left: BorderSide(color: colors.primary, width: 3)),
            )
          : null,
      // The meter runs along the bottom edge, like a track header's.
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 10, right: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: foreground,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (isSelected) Icon(Icons.tune, size: 14, color: foreground),
                ],
              ),
            ),
          ),
          SizedBox(
            height: _meterHeight,
            child: _ChannelLevelMeter(target: target, channelName: title),
          ),
        ],
      ),
    );

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => ref
            .read(trackListStateProvider.notifier)
            .selectMixerChannel(target),
        child: rainbow ? RainbowSparkle(child: row) : row,
      ),
    );
  }
}

/// Thickness of the output meter along the bottom of a channel title row.
const double _meterHeight = 4;

/// The output meter of the master or a bus. It is the only part of the title
/// row that watches the meter magnitude, so a telemetry tick rebuilds this
/// leaf alone.
class _ChannelLevelMeter extends ConsumerWidget {
  const _ChannelLevelMeter({required this.target, required this.channelName});

  final UiMixerChannelTarget target;
  final String channelName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final magnitude = ref.watch(
      mixerStateProvider.select(
        (state) => switch (target) {
          UiMixerChannelTarget_Track(:final field0) =>
            state.trackMagnitudes[field0] ?? 0.0,
          UiMixerChannelTarget_Bus(:final field0) =>
            state.busMagnitudes[field0] ?? 0.0,
          UiMixerChannelTarget_Master() => state.masterMagnitude,
        },
      ),
    );
    return Semantics(
      label: tr('track-output-level', {'trackName': channelName}),
      value: '${magnitudeToDb(magnitude).toStringAsFixed(1)} dB',
      child: DbLevelMeter(magnitude: magnitude, axis: Axis.horizontal),
    );
  }
}
