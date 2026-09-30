part of 'track_list_screen.dart';

const double _rulerHeight = 30;
const double _markerFlagHeight = 14;
const double _loopEdgeHitWidth = 8;

/// Four beats, the length a loop gets when only one of its ends is picked.
const int _defaultLoopTicks = 960 * 4;

/// Timeline span covering [clipIds], or null when none of them exist.
_ClipTickRange? _clipsSpan(WidgetRef ref, Set<int> clipIds) {
  final tracks = ref.read(projectProvider).value?.tracks;
  if (clipIds.isEmpty || tracks == null) return null;
  final position = ref.read(transportPositionStreamProvider).value;
  final tempo = position?.tempo ?? 120.0;
  final sampleRate = position?.sampleRate ?? 48000;

  _ClipTickRange? span;
  for (final track in tracks.values) {
    for (final clip in track.clips) {
      if (!clipIds.contains(clip.id)) continue;
      final start = clip.startTimeInTicks;
      final end = start + clip.loopLengthInTicks(tempo, sampleRate);
      span = span == null
          ? _ClipTickRange(start, end)
          : _ClipTickRange(
              math.min(span.start, start),
              math.max(span.end, end),
            );
    }
  }
  return span != null && span.end > span.start ? span : null;
}

/// The timeline ruler with the song loop region and cue markers on it.
///
/// Tapping or dragging seeks. Shift-dragging draws a loop region, and its edges
/// drag to resize it. Markers seek when tapped, move when dragged, and have a
/// menu on right click. Right clicking anywhere else opens the ruler menu.
class _TimelineRulerBar extends ConsumerStatefulWidget {
  final ScrollController scrollController;
  final double timelineWidth;
  final ScrollPhysics physics;
  final void Function(int ticks) onSeekTicks;

  const _TimelineRulerBar({
    required this.scrollController,
    required this.timelineWidth,
    required this.physics,
    required this.onSeekTicks,
  });

  @override
  ConsumerState<_TimelineRulerBar> createState() => _TimelineRulerBarState();
}

enum _LoopEdge { start, end }

class _TimelineRulerBarState extends ConsumerState<_TimelineRulerBar> {
  /// Loop region shown while drawing or resizing it, before it is committed.
  (int, int)? _draftRegion;
  int? _drawAnchorTick;
  double _edgeDragTicks = 0;

  /// Marker being dragged and where it is shown meanwhile.
  int? _draggedMarkerId;
  int _draftMarkerTick = 0;
  double _markerDragTicks = 0;

  double get _zoom => ref.read(workspaceStateProvider).horizontalZoomLevel;

  int _tickAt(double x) {
    final ticks = (x * _zoom).round();
    return _snap(ticks < 0 ? 0 : ticks);
  }

  int _snap(int ticks) => _snapTick(ticks, ref.read(workspaceStateProvider));

  TimelineNotifier get _timeline => ref.read(timelineProvider.notifier);

  // --------------------------------------------------------------------------
  // Ruler gestures: seek, or draw a loop region with shift held
  // --------------------------------------------------------------------------

  void _onPanStart(DragStartDetails details) {
    if (HardwareKeyboard.instance.isShiftPressed) {
      final tick = _tickAt(details.localPosition.dx);
      setState(() {
        _drawAnchorTick = tick;
        _draftRegion = (tick, tick);
      });
      return;
    }
    widget.onSeekTicks(_tickAt(details.localPosition.dx));
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final anchor = _drawAnchorTick;
    final tick = _tickAt(details.localPosition.dx);
    if (anchor == null) {
      widget.onSeekTicks(tick);
      return;
    }
    setState(
      () => _draftRegion = (math.min(anchor, tick), math.max(anchor, tick)),
    );
  }

  void _onPanEnd(DragEndDetails _) {
    final draft = _draftRegion;
    final drawing = _drawAnchorTick != null;
    setState(() {
      _drawAnchorTick = null;
      _draftRegion = null;
    });
    if (drawing && draft != null && draft.$2 > draft.$1) {
      _timeline.setLoopRegion(draft.$1, draft.$2);
    }
  }

  // --------------------------------------------------------------------------
  // Loop edges
  // --------------------------------------------------------------------------

  void _onEdgeDragStart(UiLoopRegion region, _LoopEdge edge) {
    setState(() {
      _edgeDragTicks = switch (edge) {
        _LoopEdge.start => region.startTick.toDouble(),
        _LoopEdge.end => region.endTick.toDouble(),
      };
      _draftRegion = (region.startTick, region.endTick);
    });
  }

  void _onEdgeDragUpdate(_LoopEdge edge, DragUpdateDetails details) {
    final draft = _draftRegion;
    if (draft == null) return;
    _edgeDragTicks = math.max(0, _edgeDragTicks + details.delta.dx * _zoom);
    final tick = _snap(_edgeDragTicks.round());
    setState(() {
      _draftRegion = switch (edge) {
        _LoopEdge.start => (math.min(tick, draft.$2 - 1), draft.$2),
        _LoopEdge.end => (draft.$1, math.max(tick, draft.$1 + 1)),
      };
    });
  }

  void _onEdgeDragEnd() {
    final draft = _draftRegion;
    setState(() => _draftRegion = null);
    if (draft != null) _timeline.setLoopRegion(draft.$1, draft.$2);
  }

  // --------------------------------------------------------------------------
  // Markers
  // --------------------------------------------------------------------------

  void _onMarkerDragStart(UiCueMarker marker) {
    setState(() {
      _draggedMarkerId = marker.id;
      _draftMarkerTick = marker.tick;
      _markerDragTicks = marker.tick.toDouble();
    });
  }

  void _onMarkerDragUpdate(DragUpdateDetails details) {
    _markerDragTicks = math.max(0, _markerDragTicks + details.delta.dx * _zoom);
    setState(() => _draftMarkerTick = _snap(_markerDragTicks.round()));
  }

  void _onMarkerDragEnd(UiCueMarker marker) {
    final tick = _draftMarkerTick;
    setState(() => _draggedMarkerId = null);
    if (tick != marker.tick) _timeline.moveCueMarker(marker, tick);
  }

  Future<void> _showMarkerMenu(UiCueMarker marker) {
    return showDawContextMenu(
      context: context,
      title: marker.name,
      actions: [
        DawContextAction(
          title: "Rename",
          icon: Icons.edit,
          onTap: () async {
            final name = await showRenameDialog(
              context,
              title: "Rename Cue Marker",
              label: "Marker name",
              currentName: marker.name,
            );
            if (name != null) await _timeline.renameCueMarker(marker, name);
          },
        ),
        DawContextAction(
          title: "Change Color",
          icon: Icons.color_lens,
          onTap: () async {
            final color = await showColorPickerDialog(
              context,
              marker.color.fromRGBorRGBAtoColor(),
              title: "Cue Marker Color",
            );
            if (color != null) await _timeline.recolorCueMarker(marker, color);
          },
        ),
        DawContextAction(
          title: "Delete",
          icon: Icons.delete,
          isDestructive: true,
          onTap: () => _timeline.removeCueMarker(marker),
        ),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // Ruler menu
  // --------------------------------------------------------------------------

  Future<void> _showRulerMenu(double x) {
    final tick = _tickAt(x);
    final region = ref.read(loopRegionProvider);
    final selectionSpan = _clipsSpan(
      ref,
      ref.read(trackListStateProvider).selectedClipIds.toSet(),
    );

    return showDawContextMenu(
      context: context,
      title: "Timeline",
      actions: [
        DawContextAction(
          title: "Add Cue Marker Here",
          icon: Icons.bookmark_add,
          onTap: () => _timeline.addCueMarker(tick),
        ),
        DawContextAction(
          title: "Set Loop Start Here",
          icon: Icons.first_page,
          onTap: () => _timeline.setLoopRegion(
            tick,
            region != null && region.endTick > tick
                ? region.endTick
                : tick + _defaultLoopTicks,
          ),
        ),
        DawContextAction(
          title: "Set Loop End Here",
          icon: Icons.last_page,
          onTap: () => _timeline.setLoopRegion(
            region != null && region.startTick < tick
                ? region.startTick
                : math.max(0, tick - _defaultLoopTicks),
            math.max(tick, 1),
          ),
        ),
        if (selectionSpan != null)
          DawContextAction(
            title: "Loop Selected Clips",
            icon: Icons.select_all,
            onTap: () =>
                _timeline.setLoopRegion(selectionSpan.start, selectionSpan.end),
          ),
        if (region != null) ...[
          DawContextAction(
            title: "Clear Loop Region",
            icon: Icons.clear,
            onTap: _timeline.clearLoopRegion,
          ),
          DawContextAction(
            title: "Export Loop Region…",
            icon: Icons.ios_share,
            onTap: () {
              ref
                  .read(exportProjectProvider.notifier)
                  .updateRangeMode(ExportRangeMode.loopRegion);
              ref.read(workspaceStateProvider.notifier).openExportPanel();
            },
          ),
          DawContextAction(
            title: "Bounce Loop Region to New Source",
            icon: Icons.graphic_eq,
            onTap: _timeline.bounceLoopRegion,
          ),
        ],
      ],
    );
  }

  // --------------------------------------------------------------------------
  // Build
  // --------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final zoom = ref.watch(
      workspaceStateProvider.select((s) => s.horizontalZoomLevel),
    );
    final isLooping = ref.watch(
      transportProvider.select((s) => s.value?.isLooping ?? false),
    );
    final savedRegion = ref.watch(loopRegionProvider);
    final markers = ref.watch(cueMarkersProvider);
    final region =
        _draftRegion ??
        (savedRegion == null
            ? null
            : (savedRegion.startTick, savedRegion.endTick));
    double xOf(int tick) => zoom <= 0 ? 0 : tick / zoom;

    return Container(
      height: _rulerHeight,
      color: colors.surfaceContainer,
      width: double.infinity,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        controller: widget.scrollController,
        physics: widget.physics,
        child: SizedBox(
          width: widget.timelineWidth,
          height: _rulerHeight,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) {
              if (HardwareKeyboard.instance.isShiftPressed) return;
              widget.onSeekTicks(_tickAt(details.localPosition.dx));
            },
            onPanStart: _onPanStart,
            // Throttled by the TransportNotifier's seekTo queue implementation
            onPanUpdate: _onPanUpdate,
            onPanEnd: _onPanEnd,
            onSecondaryTapUp: (details) =>
                _showRulerMenu(details.localPosition.dx),
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Positioned.fill(
                  child: _TimelineRuler(
                    scrollController: widget.scrollController,
                    sampleRate:
                        ref.read(transportProvider).value?.sampleRate ?? 48000,
                  ),
                ),
                if (region != null && region.$2 > region.$1) ...[
                  Positioned(
                    left: xOf(region.$1),
                    width: xOf(region.$2) - xOf(region.$1),
                    top: 0,
                    bottom: 0,
                    child: IgnorePointer(
                      child: _LoopRegionBand(
                        color: colors.primary,
                        isActive: isLooping,
                      ),
                    ),
                  ),
                  if (_drawAnchorTick == null && savedRegion != null)
                    for (final edge in _LoopEdge.values)
                      Positioned(
                        left:
                            xOf(switch (edge) {
                              _LoopEdge.start => region.$1,
                              _LoopEdge.end => region.$2,
                            }) -
                            _loopEdgeHitWidth / 2,
                        width: _loopEdgeHitWidth,
                        top: 0,
                        bottom: 0,
                        child: MouseRegion(
                          cursor: SystemMouseCursors.resizeLeftRight,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onHorizontalDragStart: (_) =>
                                _onEdgeDragStart(savedRegion, edge),
                            onHorizontalDragUpdate: (details) =>
                                _onEdgeDragUpdate(edge, details),
                            onHorizontalDragEnd: (_) => _onEdgeDragEnd(),
                            onHorizontalDragCancel: () =>
                                setState(() => _draftRegion = null),
                          ),
                        ),
                      ),
                ],
                for (final marker in markers)
                  Positioned(
                    left: xOf(
                      marker.id == _draggedMarkerId
                          ? _draftMarkerTick
                          : marker.tick,
                    ),
                    top: _rulerHeight - _markerFlagHeight,
                    height: _markerFlagHeight,
                    child: _CueMarkerFlag(
                      marker: marker,
                      onTap: () => widget.onSeekTicks(marker.tick),
                      onDragStart: () => _onMarkerDragStart(marker),
                      onDragUpdate: _onMarkerDragUpdate,
                      onDragEnd: () => _onMarkerDragEnd(marker),
                      onMenu: () => _showMarkerMenu(marker),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Loop region on the ruler: a tinted band with a bar along its top, dimmed
/// while looping is off.
class _LoopRegionBand extends StatelessWidget {
  final Color color;
  final bool isActive;

  const _LoopRegionBand({required this.color, required this.isActive});

  @override
  Widget build(BuildContext context) {
    final strength = isActive ? 1.0 : 0.4;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18 * strength),
        border: Border(
          top: BorderSide(color: color.withValues(alpha: strength), width: 4),
          left: BorderSide(color: color.withValues(alpha: 0.8 * strength)),
          right: BorderSide(color: color.withValues(alpha: 0.8 * strength)),
        ),
      ),
    );
  }
}

/// A cue marker's flag: its name on its color, left edge on its position.
class _CueMarkerFlag extends StatelessWidget {
  final UiCueMarker marker;
  final VoidCallback onTap;
  final VoidCallback onDragStart;
  final GestureDragUpdateCallback onDragUpdate;
  final VoidCallback onDragEnd;
  final VoidCallback onMenu;

  const _CueMarkerFlag({
    required this.marker,
    required this.onTap,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    final color = marker.color.fromRGBorRGBAtoColor();
    final textColor =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? Colors.white
        : Colors.black;
    return Tooltip(
      message: '${marker.name}\nDrag to move, right click for options',
      waitDuration: const Duration(milliseconds: 600),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          onHorizontalDragStart: (_) => onDragStart(),
          onHorizontalDragUpdate: onDragUpdate,
          onHorizontalDragEnd: (_) => onDragEnd(),
          onSecondaryTap: onMenu,
          onLongPress: onMenu,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 120),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(3),
                bottomRight: Radius.circular(3),
              ),
            ),
            child: Text(
              marker.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: textColor, fontSize: 9, height: 1.4),
            ),
          ),
        ),
      ),
    );
  }
}

/// Loop edges and cue marker lines drawn through the track area.
class _TimelineAnnotationLines extends ConsumerWidget {
  final ScrollController scrollController;

  const _TimelineAnnotationLines({required this.scrollController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final zoom = ref.watch(
      workspaceStateProvider.select((s) => s.horizontalZoomLevel),
    );
    final isLooping = ref.watch(
      transportProvider.select((s) => s.value?.isLooping ?? false),
    );
    final region = ref.watch(loopRegionProvider);
    final markers = ref.watch(cueMarkersProvider);
    if (region == null && markers.isEmpty) return const SizedBox.shrink();

    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _TimelineAnnotationPainter(
            scrollController: scrollController,
            zoom: zoom,
            region: region,
            loopColor: colors.primary.withValues(alpha: isLooping ? 1 : 0.4),
            markers: [
              for (final marker in markers)
                (marker.tick, marker.color.fromRGBorRGBAtoColor()),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimelineAnnotationPainter extends CustomPainter {
  final ScrollController scrollController;
  final double zoom;
  final UiLoopRegion? region;
  final Color loopColor;
  final List<(int, Color)> markers;

  _TimelineAnnotationPainter({
    required this.scrollController,
    required this.zoom,
    required this.region,
    required this.loopColor,
    required this.markers,
  }) : super(repaint: scrollController);

  @override
  void paint(Canvas canvas, Size size) {
    if (zoom <= 0) return;
    final scroll = scrollController.hasClients ? scrollController.offset : 0.0;
    double xOf(int tick) => tick / zoom - scroll;

    final region = this.region;
    if (region != null) {
      final start = xOf(region.startTick);
      final end = xOf(region.endTick);
      canvas.drawRect(
        Rect.fromLTRB(start, 0, end, size.height),
        Paint()..color = loopColor.withValues(alpha: loopColor.a * 0.06),
      );
      final edge = Paint()
        ..color = loopColor.withValues(alpha: loopColor.a * 0.7)
        ..strokeWidth = 1;
      canvas.drawLine(Offset(start, 0), Offset(start, size.height), edge);
      canvas.drawLine(Offset(end, 0), Offset(end, size.height), edge);
    }

    for (final (tick, color) in markers) {
      final x = xOf(tick);
      if (x < -1 || x > size.width + 1) continue;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        Paint()
          ..color = color.withValues(alpha: 0.55)
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TimelineAnnotationPainter oldDelegate) {
    return oldDelegate.zoom != zoom ||
        oldDelegate.region != region ||
        oldDelegate.loopColor != loopColor ||
        !listEquals(oldDelegate.markers, markers) ||
        oldDelegate.scrollController != scrollController;
  }
}
