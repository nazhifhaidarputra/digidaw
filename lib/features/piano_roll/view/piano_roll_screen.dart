import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:karbeat/app/providers/piano_roll_state.dart';
import 'package:karbeat/app/providers/notification_provider.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/app/providers/transport_state.dart';
import 'package:karbeat/core/widgets/context_menu.dart';
import 'package:karbeat/features/piano_roll/view/scrollable_virtual_keyboard.dart';
import 'package:karbeat/features/piano_roll/view/note_param_editor.dart';
import 'package:karbeat/features/piano_roll/view/pattern_ruler.dart';
import 'package:karbeat/features/piano_roll/view/piano_roll_actions.dart';
import 'package:karbeat/features/plugins/services/plugin_ui_launcher.dart';
import 'package:karbeat/features/track/view/playhead.dart';
import 'package:karbeat/core/widgets/shortcut_focus_anchor.dart';
import 'package:karbeat/shared/enums/global.dart';
import 'package:karbeat/shared/models/grid.dart';
import 'package:karbeat/shared/models/piano_key.dart';
import 'package:karbeat/src/rust/api/audio.dart';
import 'package:karbeat/src/rust/api/pattern.dart';
import 'package:karbeat/src/rust/api/plugin.dart';
import 'package:karbeat/src/rust/api/project.dart';
import 'package:karbeat/src/rust/api/transport.dart';
import 'package:karbeat/core/utils/formatter.dart';
import 'package:karbeat/core/utils/logger.dart';
import 'package:linked_scroll_controller/linked_scroll_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/core/widgets/daw_input_detector.dart';
import 'package:karbeat/core/widgets/scroll_physics/unclamped_never_scrollable_physics.dart';
import 'package:multi_split_view/multi_split_view.dart';

class PianoRollScreen extends ConsumerStatefulWidget {
  const PianoRollScreen({super.key});

  @override
  ConsumerState<PianoRollScreen> createState() {
    return PianoRollScreenState();
  }
}

class PianoRollScreenState extends ConsumerState<PianoRollScreen> {
  static const double _initialTimelineWidth = 2000;
  static const double _timelineExtensionWidth = 2000;

  /// Row height, owned by [pianoRollProvider] so the toolbar can change it.
  double get _keyHeight => ref.read(pianoRollProvider).keyHeight;
  final double _keyWidth = 60.0;
  final FocusNode _focusNode = FocusNode(debugLabel: 'PianoRoll');
  double _timelineWidth = _initialTimelineWidth;

  late LinkedScrollControllerGroup _verticalControllers;
  late ScrollController _keysController;
  late ScrollController _gridVerticalController;
  late ScrollController _gridHorizontalController;
  late final MultiSplitViewController _editorSplitController;

  _PianoRollBottomPanel _bottomPanel = _PianoRollBottomPanel.keyboard;

  // Track active notes for Keyboard visualization
  final Set<int> _activeKeyboardNotes = {};

  /// Notes stamped by the current draw stroke, previewed until pointer up.
  final List<UiNoteDraft> _brushAddNotes = [];

  /// Stamp slots (multiples of the stamp span from the stroke origin) already
  /// filled in this stroke, so stamps never overlap.
  final Set<int> _stampedSlots = {};
  int? _strokeOriginTick;
  final Set<int> _brushDeleteNoteIds = {};
  Timer? _autoScrollTimer;
  double _lastZoomDragY = 0;
  Offset? _selectionStart;
  Offset? _selectionEnd;
  Offset? _lastInteractionPos;

  DawContext get _ctx => ref.read(projectProvider.notifier).dawContext;

  @override
  void initState() {
    super.initState();
    _verticalControllers = LinkedScrollControllerGroup();
    _keysController = _verticalControllers.addAndGet();
    _gridVerticalController = _verticalControllers.addAndGet();
    _gridHorizontalController = ScrollController();
    _gridHorizontalController.addListener(_handleTimelineExpansion);
    _editorSplitController = MultiSplitViewController(
      areas: [
        Area(min: 200, data: 'editor'),
        Area(size: 160, min: 100, max: 360, data: 'bottomPanel'),
      ],
    );

    // Jump to Middle C (MIDI 72)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _verticalControllers.jumpTo((127 - 72) * _keyHeight - 100);
    });
  }

  @override
  void dispose() {
    _gridHorizontalController.removeListener(_handleTimelineExpansion);
    _keysController.dispose();
    _gridVerticalController.dispose();
    _gridHorizontalController.dispose();
    _editorSplitController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleTimelineExpansion() {
    if (!_gridHorizontalController.hasClients) return;

    final position = _gridHorizontalController.position;
    if (position.extentAfter >= 500) return;

    final laidOutWidth = position.maxScrollExtent + position.viewportDimension;
    final nextWidth = max(_timelineWidth, laidOutWidth) +
        _timelineExtensionWidth;
    if (nextWidth == _timelineWidth) return;

    setState(() => _timelineWidth = nextWidth);
  }

  double _effectiveTimelineWidth(UiPattern pattern, double zoomX) {
    var contentEndTick = pattern.lengthTicks;
    for (final note in pattern.notes) {
      contentEndTick = max(contentEndTick, note.startTick + note.duration);
    }

    const endPaddingWidth = 1000.0;
    final contentWidth = contentEndTick * zoomX + endPaddingWidth;
    final viewportWidth = max(0.0, MediaQuery.sizeOf(context).width - _keyWidth);
    final scrollableViewportWidth = viewportWidth + _timelineExtensionWidth;
    return max(_timelineWidth, max(contentWidth, scrollableViewportWidth));
  }

  void _panEditor(Offset delta) {
    _scrollBy(_gridHorizontalController, -delta.dx);
    _scrollBy(_gridVerticalController, -delta.dy);
  }

  void _handleNoteOn(int note) {
    final generatorId = ref.read(pianoRollProvider).previewGeneratorId;
    if (generatorId != null) {
      try {
        playPreviewNoteGenerator(
          ctx: _ctx,
          generatorId: generatorId,
          noteKey: note,
          velocity: 100,
          isOn: true,
        );
      } catch (e) {
        AppLogger.error("Failed to play preview note: $e");
        ref.read(notificationProvider.notifier).error(e);
      }
    }
  }

  void _handleNoteOff(int note) {
    final generatorId = ref.read(pianoRollProvider).previewGeneratorId;
    if (generatorId != null) {
      try {
        playPreviewNoteGenerator(
          ctx: _ctx,
          generatorId: generatorId,
          noteKey: note,
          velocity: 100,
          isOn: false,
        );
      } catch (e) {
        AppLogger.error("Failed to play preview note: $e");
        ref.read(notificationProvider.notifier).error(e);
      }
    }
  }

  /// Plays the computer keyboard as a piano. Keys held with Ctrl, Alt, or
  /// Meta are left for the piano-roll shortcuts.
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    final keyboard = HardwareKeyboard.instance;
    if (event is KeyDownEvent &&
        (keyboard.isControlPressed ||
            keyboard.isAltPressed ||
            keyboard.isMetaPressed)) {
      return KeyEventResult.ignored;
    }
    if (event is KeyDownEvent) {
      final note = keyMap[event.physicalKey];
      if (note != null && !_activeKeyboardNotes.contains(note)) {
        setState(() => _activeKeyboardNotes.add(note));
        _handleNoteOn(note);
        return KeyEventResult.handled;
      }
    } else if (event is KeyUpEvent) {
      final note = keyMap[event.physicalKey];
      if (note != null && _activeKeyboardNotes.contains(note)) {
        setState(() => _activeKeyboardNotes.remove(note));
        _handleNoteOff(note);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  /// Scales the horizontal zoom by [scale], keeping the tick under
  /// [focalPointX] (relative to the visible grid) in place. Pivots on the
  /// viewport center when no focal point is given.
  void _handleZoom(double scale, {double? focalPointX}) {
    final oldZoom = ref.read(pianoRollProvider).zoomLevelTick;
    // The zoomLevelTick setter clamps, so read back the applied value.
    ref.read(pianoRollProvider.notifier).setZoomLevelTick(oldZoom * scale);
    final newZoom = ref.read(pianoRollProvider).zoomLevelTick;
    if (newZoom == oldZoom) return;

    final controller = _gridHorizontalController;
    if (!controller.hasClients) return;
    final currentScroll = controller.offset;
    final viewportWidth = controller.position.viewportDimension;
    final focalX = focalPointX ?? viewportWidth / 2;

    // Pivot Math: Lock the exact tick under the cursor
    final tickAtFocalPoint = (currentScroll + focalX) / oldZoom;
    final newScroll = max(0.0, tickAtFocalPoint * newZoom - focalX);

    // Synchronous Jump
    // The zoomed grid is laid out in the same frame as this jump. The
    // unclamped physics lets the offset sit past the old extent until then,
    // so the pivot never flickers through an intermediate position.
    controller.jumpTo(newScroll);

    // Dynamic Window Strategy
    // Wrap the new scroll position, so zooming in never runs out of room and
    // zooming out shrinks the window back toward the pattern content.
    setState(() {
      _timelineWidth = newScroll + viewportWidth + _timelineExtensionWidth;
    });
  }

  /// Converts an x position in grid content coordinates to one relative to
  /// the visible grid.
  double _viewportX(double contentX) =>
      contentX -
      (_gridHorizontalController.hasClients
          ? _gridHorizontalController.offset
          : 0.0);

  /// Scales the row height by [scale], keeping the key under [focalPointY]
  /// (relative to the visible grid) in place.
  void _handleKeyHeightZoom(double scale, double focalPointY) {
    final oldHeight = _keyHeight;
    final newHeight = (oldHeight * scale).clamp(
      minPianoRollKeyHeight,
      maxPianoRollKeyHeight,
    );
    if (oldHeight == newHeight) return;

    final controller = _gridVerticalController;
    final currentScroll = controller.hasClients ? controller.offset : 0.0;
    final viewportHeight = controller.hasClients
        ? controller.position.viewportDimension
        : 0.0;

    // Pivot Math: Lock the exact key position under the cursor
    final keyPosition = (currentScroll + focalPointY) / oldHeight;
    final maxScroll = max(0.0, 128 * newHeight - viewportHeight);
    final newScroll = (keyPosition * newHeight - focalPointY).clamp(
      0.0,
      maxScroll,
    );

    ref.read(pianoRollProvider.notifier).setKeyHeight(newHeight);

    // Synchronous Jump
    // The rows are re-laid out in the same frame as this jump. The unclamped
    // physics lets the offset sit past the old extent until then, so the
    // pivot never flickers through an intermediate position.
    if (controller.hasClients) {
      controller.jumpTo(newScroll);
    }
  }

  /// Snap distance for drawing, moving, and resizing: the draw step.
  int get _stepTicks => ref.read(pianoRollProvider).stepTicks;

  int _snapTick(int tick) {
    final step = _stepTicks;
    return step <= 1 ? tick : (tick / step).round() * step;
  }

  /// Draw-tool stamp at the pointer: a copy of the latest selection (FL
  /// Studio style), or a single step-long note when nothing was selected yet.
  ///
  /// Dragging repeats the stamp every span from where the stroke began, so
  /// copies line up end to end without overlapping. Each copy follows the
  /// pointer's pitch.
  void _handleBrushAdd(Offset localPos) {
    final state = ref.read(pianoRollProvider);
    final step = max(1, _stepTicks);
    final pointerTick = max(0, (localPos.dx / state.zoomLevelTick).floor());
    final tick = step <= 1 ? pointerTick : pointerTick ~/ step * step;
    final pointerKey = (127 - (localPos.dy / _keyHeight).floor()).clamp(0, 127);

    final template = state.drawTemplate.isNotEmpty
        ? state.drawTemplate.toList()
        : [
            UiNote(
              id: -1,
              startTick: 0,
              duration: step <= 1 ? 240 : step,
              key: pointerKey,
              velocity: 100,
              probability: 1,
              microOffset: 0,
              mute: false,
              pan: 0,
              pitch: 0,
            ),
          ];
    final templateStart = template.map((n) => n.startTick).reduce(min);
    final templateEnd = template
        .map((n) => n.startTick + n.duration)
        .reduce(max);
    final span = max(templateEnd - templateStart, step);
    // The earliest (then highest) note anchors the stamp to the pointer.
    final anchor = template.reduce(
      (a, b) =>
          a.startTick < b.startTick ||
              (a.startTick == b.startTick && a.key >= b.key)
          ? a
          : b,
    );

    final origin = _strokeOriginTick ??= tick;
    final slot = ((tick - origin) / span).floor();
    final stampStart = origin + slot * span;
    if (stampStart < 0 || !_stampedSlots.add(slot)) return;

    final keyOffset = pointerKey - anchor.key;
    setState(() {
      for (final note in template) {
        final key = note.key + keyOffset;
        if (key < 0 || key > 127) continue;
        _brushAddNotes.add(
          UiNoteDraft(
            key: key,
            startTick: stampStart + note.startTick - templateStart,
            duration: note.duration,
            velocity: note.velocity,
            pan: note.pan,
            pitch: note.pitch,
          ),
        );
      }
    });
  }

  void _submitBrushAdd() {
    if (_brushAddNotes.isEmpty) return;
    ref
        .read(pianoRollProvider.notifier)
        .stampNotes(List.of(_brushAddNotes));
    setState(_resetPaintState);
  }

  /// Slice tool: cuts the note under the pointer at the nearest step.
  void _handleSlice(Offset localPos, UiPattern pattern) {
    final zoomX = ref.read(pianoRollProvider).zoomLevelTick;
    final tick = (localPos.dx / zoomX).round();
    final key = (127 - (localPos.dy / _keyHeight).floor()).clamp(0, 127);
    final note = pattern.notes
        .where(
          (n) =>
              n.key == key &&
              tick > n.startTick &&
              tick < n.startTick + n.duration,
        )
        .firstOrNull;
    if (note == null) return;
    final cut = _snapTick(tick);
    ref
        .read(pianoRollProvider.notifier)
        .sliceNote(noteId: note.id, atTick: cut);
  }

  void _handleBrushDelete(Offset localPos, UiPattern pattern) {
    final zoomX = ref.read(pianoRollProvider).zoomLevelTick;
    int tick = (localPos.dx / zoomX).round();
    int keyIndex = (localPos.dy / _keyHeight).floor();
    int midiKey = (127 - keyIndex).clamp(0, 127);

    bool added = false;
    for (final note in pattern.notes) {
      if (note.key == midiKey &&
          tick >= note.startTick &&
          tick < note.startTick + note.duration) {
        if (!_brushDeleteNoteIds.contains(note.id)) {
          _brushDeleteNoteIds.add(note.id);
          added = true;
        }
      }
    }

    if (added) {
      setState(() {});
    }
  }

  void _submitBrushDelete(int patternId) {
    if (_brushDeleteNoteIds.isNotEmpty) {
      ref
          .read(pianoRollProvider.notifier)
          .deletePatternNoteBatch(
            patternId: patternId,
            noteIds: _brushDeleteNoteIds.toList(),
          );
      setState(() {
        _brushDeleteNoteIds.clear();
      });
    }
  }

  void _resetPaintState() {
    _stampedSlots.clear();
    _strokeOriginTick = null;
    _brushAddNotes.clear();
    _brushDeleteNoteIds.clear();
  }

  void _handleHorizontalAutoScroll(double globalX) {
    const double edgeThreshold = 50.0;
    const double maxSpeed = 14.0;

    // Width of the piano-key sidebar so we can compute the grid's screen rect
    final double gridLeft = _keyWidth; // same constant used for SizedBox width
    final double screenWidth = MediaQuery.of(context).size.width;

    double dx = 0;
    if (globalX < gridLeft + edgeThreshold) {
      // Near / past left edge — scroll left, faster the closer to the edge
      final ratio = ((gridLeft + edgeThreshold) - globalX) / edgeThreshold;
      dx = -maxSpeed * ratio.clamp(0.0, 1.0);
    } else if (globalX > screenWidth - edgeThreshold) {
      // Near / past right edge — scroll right
      final ratio = (globalX - (screenWidth - edgeThreshold)) / edgeThreshold;
      dx = maxSpeed * ratio.clamp(0.0, 1.0);
    }

    if (dx != 0) {
      if (_gridHorizontalController.hasClients) {
        _gridHorizontalController.jumpTo(
          (_gridHorizontalController.offset + dx).clamp(
            0.0,
            _gridHorizontalController.position.maxScrollExtent,
          ),
        );
      }
    }
  }

  void _handleAutoScroll(Offset globalPos, Size screenSize) {
    const double edgeThreshold = 40.0;
    const double scrollSpeed = 10.0;
    final double gridLeft = _keyWidth;

    double dx = 0;
    double dy = 0;

    if (globalPos.dx < gridLeft + edgeThreshold) {
      dx = -scrollSpeed;
    } else if (globalPos.dx > screenSize.width - edgeThreshold) {
      dx = scrollSpeed;
    }

    if (globalPos.dy < edgeThreshold) {
      dy = -scrollSpeed;
    } else if (globalPos.dy > screenSize.height - edgeThreshold) {
      dy = scrollSpeed;
    }

    if (dx != 0 || dy != 0) {
      if (_autoScrollTimer?.isActive ?? false) return;
      _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 16), (
        timer,
      ) {
        if (dx != 0 && _gridHorizontalController.hasClients) {
          _gridHorizontalController.jumpTo(
            (_gridHorizontalController.offset + dx).clamp(
              0.0,
              _gridHorizontalController.position.maxScrollExtent,
            ),
          );
        }
        if (dy != 0 && _gridVerticalController.hasClients) {
          _gridVerticalController.jumpTo(
            (_gridVerticalController.offset + dy).clamp(
              0.0,
              _gridVerticalController.position.maxScrollExtent,
            ),
          );
        }
      });
    } else {
      _stopAutoScroll();
    }
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
  }

  void _handleEditorPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;

    final pressedKeys = HardwareKeyboard.instance.logicalKeysPressed;
    final isControlPressed =
        pressedKeys.contains(LogicalKeyboardKey.controlLeft) ||
        pressedKeys.contains(LogicalKeyboardKey.controlRight);
    final isAltPressed =
        pressedKeys.contains(LogicalKeyboardKey.altLeft) ||
        pressedKeys.contains(LogicalKeyboardKey.altRight);
    if (isControlPressed || isAltPressed) return;

    GestureBinding.instance.pointerSignalResolver.register(event, (
      resolvedEvent,
    ) {
      if (resolvedEvent is! PointerScrollEvent) return;

      final isShiftPressed =
          pressedKeys.contains(LogicalKeyboardKey.shiftLeft) ||
          pressedKeys.contains(LogicalKeyboardKey.shiftRight);
      var horizontalDelta = resolvedEvent.scrollDelta.dx;
      var verticalDelta = resolvedEvent.scrollDelta.dy;

      // Mouse wheels report vertical deltas. Shift maps the wheel to the
      // timeline, while trackpads can scroll both axes directly.
      if (isShiftPressed) {
        horizontalDelta = horizontalDelta == 0
            ? verticalDelta
            : horizontalDelta;
        verticalDelta = 0;
      }

      _scrollBy(_gridHorizontalController, horizontalDelta);
      _scrollBy(_gridVerticalController, verticalDelta);
    });
  }

  /// Alt+scroll over the keys resizes rows; other scrolling pans the editor.
  void _handleKeysPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent && HardwareKeyboard.instance.isAltPressed) {
      GestureBinding.instance.pointerSignalResolver.register(event, (resolved) {
        if (resolved is! PointerScrollEvent) return;
        _handleKeyHeightZoom(
          resolved.scrollDelta.dy > 0 ? 0.9 : 1.1,
          resolved.localPosition.dy,
        );
      });
      return;
    }
    _handleEditorPointerSignal(event);
  }

  void _scrollBy(ScrollController controller, double delta) {
    if (delta == 0 || !controller.hasClients) return;

    controller.jumpTo(
      (controller.offset + delta).clamp(
        controller.position.minScrollExtent,
        controller.position.maxScrollExtent,
      ),
    );
  }

  // void _handleVirtualKeyPan(Offset localPos) {
  //   const double whiteKeyWidth = 40.0;
  // }

  void _commitRangeSelection(UiPattern pattern) {
    if (_selectionStart == null || _selectionEnd == null) return;

    final state = ref.read(pianoRollProvider);
    final notifier = ref.read(pianoRollProvider.notifier);
    final zoomX = state.zoomLevelTick;
    final rect = Rect.fromPoints(_selectionStart!, _selectionEnd!);

    Set<int> selectedIds = {};

    for (final note in pattern.notes) {
      double noteLeft = note.startTick * zoomX;
      double noteTop = (127 - note.key) * _keyHeight;
      double noteWidth = note.duration * zoomX;

      Rect noteRect = Rect.fromLTWH(noteLeft, noteTop, noteWidth, _keyHeight);

      // If the selection box overlaps the note's calculated rectangle
      if (rect.overlaps(noteRect)) {
        selectedIds.add(note.id);
      }
    }

    if (selectedIds.isNotEmpty) {
      notifier.selectNotes(selectedIds);
    } else {
      notifier.clearNoteSelection(); // Clicking empty space clears selection
    }

    setState(() {
      _selectionStart = null;
      _selectionEnd = null;
    });
  }

  Widget _buildPatternPicker(
    BuildContext context,
    IMap<int, UiPattern> patterns,
  ) {
    final colors = Theme.of(context).colorScheme;
    final entries = patterns.entries.toList()
      ..sort((a, b) => a.value.name.compareTo(b.value.name));

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "No Pattern Selected",
            style: TextStyle(color: colors.onSurface),
          ),
          const SizedBox(height: 12),
          DropdownButton<int>(
            hint: Text(
              entries.isEmpty ? "No Patterns Available" : "Choose a Pattern",
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            menuMaxHeight: 320,
            dropdownColor: colors.surfaceContainerHigh,
            underline: const SizedBox(),
            items: entries
                .map(
                  (entry) => DropdownMenuItem<int>(
                    value: entry.key,
                    child: Text(entry.value.name),
                  ),
                )
                .toList(growable: false),
            onChanged: entries.isEmpty
                ? null
                : (patternId) {
                    if (patternId == null) return;
                    final previewGeneratorId = ref
                        .read(pianoRollProvider)
                        .previewGeneratorId;
                    ref
                        .read(pianoRollProvider.notifier)
                        .openPattern(
                          patternId,
                          previewGeneratorId: previewGeneratorId,
                        );
                  },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final pianoRollState = ref.watch(pianoRollProvider);
    final projectState = ref.watch(projectProvider);
    final patternId = pianoRollState.editingPatternId;
    final patterns =
        projectState.value?.patterns ?? const IMapConst<int, UiPattern>({});
    if (patternId == null) {
      return _buildPatternPicker(context, patterns);
    }

    final pattern = patterns[patternId];

    final zoomX = pianoRollState.zoomLevelTick;
    final selectedTool = pianoRollState.tool;
    final gridDenom = pianoRollState.pianoRollGridDenom;
    final generatorId = pianoRollState.previewGeneratorId;

    final selectedNoteIds = pianoRollState.selectedNoteIds;
    final transportPosition = ref.watch(transportPositionStreamProvider).value;
    bool isInteracting = false;

    if (pattern == null) {
      return Center(
        child: Text(
          "Pattern not found",
          style: TextStyle(color: colors.onSurface),
        ),
      );
    }

    // Filter notes into separate layers
    final selectedNotes = pattern.notes
        .where((n) => selectedNoteIds.contains(n.id))
        .toList();
    final unselectedNotes = pattern.notes
        .where((n) => !selectedNoteIds.contains(n.id))
        .toList();

    final isDrawing = selectedTool == PianoRollToolSelection.draw;
    final isDeleting = selectedTool == PianoRollToolSelection.delete;
    final isPan = selectedTool == PianoRollToolSelection.pan;
    final isZoom = selectedTool == PianoRollToolSelection.zoom;
    final isSelecting = selectedTool == PianoRollToolSelection.select;
    final isSlicing = selectedTool == PianoRollToolSelection.slice;
    final timelineWidth = _effectiveTimelineWidth(pattern, zoomX);

    return Stack(
      children: [
        Actions(
          actions: pianoRollShortcutActions(ref),
          child: KeyboardFocusRegion(
            focusNode: _focusNode,
            onKeyEvent: _handleKeyEvent,
            child: Column(
            children: [
              // ==== TOOLBAR ===
              _PianoRollToolbar(
                patternId: pattern.id,
                name: pattern.name,
                onZoomIn: () => _handleZoom(1.2),
                onZoomOut: () => _handleZoom(1 / 1.2),
                gridDenom: gridDenom,
                onGridDenomChanged: (val) {
                  if (val != null) {
                    ref.read(pianoRollProvider.notifier).setGridSize(val);
                  }
                },
              ),

              SizedBox(
                height: 30,
                child: Row(
                  children: [
                    SizedBox(
                      width: _keyWidth,
                      child: ColoredBox(color: colors.surfaceContainer),
                    ),
                    Expanded(
                      child: PatternRuler(
                        scrollController: _gridHorizontalController,
                        zoomX: zoomX,
                      ),
                    ),
                  ],
                ),
              ),

              // === EDITOR AREA ===
              Expanded(
                child: MultiSplitViewTheme(
                  data: MultiSplitViewThemeData(
                    dividerPainter: DividerPainters.grooved1(
                      color: colors.outlineVariant,
                      highlightedColor: colors.primary,
                      thickness: 1,
                    ),
                  ),
                  child: MultiSplitView(
                    axis: Axis.vertical,
                    controller: _editorSplitController,
                    builder: (context, area) {
                      if (area.data == 'bottomPanel') {
                        return _PianoRollBottomPanelView(
                          scrollController: _gridHorizontalController,
                          zoomX: zoomX,
                          gutterWidth: _keyWidth,
                          selectedPanel: _bottomPanel,
                          onPanelChanged: (panel) {
                            setState(() => _bottomPanel = panel);
                          },
                          onNoteOn: _handleNoteOn,
                          onNoteOff: _handleNoteOff,
                          activeNotes: _activeKeyboardNotes,
                        );
                      }

                      return Row(
                  children: [
                    // PIANO KEYS (Left)
                    SizedBox(
                      width: _keyWidth,
                      child: Listener(
                        onPointerDown: (_) => _focusNode.requestFocus(),
                        onPointerSignal: _handleKeysPointerSignal,
                        child: ScrollConfiguration(
                          behavior: ScrollConfiguration.of(
                            context,
                          ).copyWith(scrollbars: false),
                          child: ListView.builder(
                            controller: _keysController,
                            itemCount: 128,
                            itemExtent: _keyHeight,
                            physics: isPan
                                ? const ClampingScrollPhysics()
                                : const UnclampedNeverScrollableScrollPhysics(),
                            itemBuilder: (context, index) {
                              // MIDI 127 is top, 0 is bottom. List index 0 is top.
                              final midiKey = 127 - index;
                              return _PianoKey(
                                midiKey: midiKey,
                                height: _keyHeight,
                                onPlayNote: (isOn) {
                                  if (isOn) {
                                    _handleNoteOn(midiKey);
                                  } else {
                                    _handleNoteOff(midiKey);
                                  }
                                },
                              );
                            },
                          ),
                        ),
                      ),
                    ),

                    // ========= GRID & NOTES & PLAYHEAD ===========
                    Expanded(
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: IgnorePointer(
                              child: RepaintBoundary(
                                child: CustomPaint(
                                  painter: _PianoGridPainter(
                                    horizontalController:
                                        _gridHorizontalController,
                                    verticalController: _gridVerticalController,
                                    zoomX: zoomX,
                                    keyHeight: _keyHeight,
                                    gridDenom: gridDenom,
                                    lineColor: colors.onSurface,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Positioned.fill(
                            child: IgnorePointer(
                              child: PatternLoopShade(
                                scrollController: _gridHorizontalController,
                                zoomX: zoomX,
                              ),
                            ),
                          ),
                          ScrollConfiguration(
                            behavior: ScrollConfiguration.of(context).copyWith(
                              scrollbars: true,
                              dragDevices: {
                                PointerDeviceKind.touch,
                                PointerDeviceKind.mouse,
                              },
                            ),
                            child: SingleChildScrollView(
                              controller: _gridHorizontalController,
                              scrollDirection: Axis.horizontal,
                              physics:
                                  const UnclampedNeverScrollableScrollPhysics(),
                              child: SingleChildScrollView(
                                controller: _gridVerticalController,
                                scrollDirection: Axis.vertical,
                                physics:
                                    const UnclampedNeverScrollableScrollPhysics(),
                                child: Listener(
                                  onPointerSignal: _handleEditorPointerSignal,
                                  onPointerDown: (event) {
                                    _focusNode.requestFocus();
                                    _lastInteractionPos = event.localPosition;
                                    if (event.buttons & kPrimaryButton == 0) {
                                      return;
                                    }
                                    if (isZoom || isPan) {
                                      setState(() => isInteracting = true);
                                    }

                                    if (isDrawing) {
                                      _resetPaintState();
                                      _handleBrushAdd(event.localPosition);
                                    } else if (isSlicing) {
                                      _handleSlice(
                                        event.localPosition,
                                        pattern,
                                      );
                                    } else if (isDeleting) {
                                      _resetPaintState();
                                      _handleBrushDelete(
                                        event.localPosition,
                                        pattern,
                                      );
                                    } else if (isZoom) {
                                      _lastZoomDragY = event.localPosition.dy;
                                    } else if (isSelecting) {
                                      setState(() {
                                        _selectionStart = event.localPosition;
                                        _selectionEnd = event.localPosition;
                                      });
                                    }
                                  },
                                  onPointerMove: (event) {
                                    if (event.buttons & kPrimaryButton == 0) {
                                      return;
                                    }
                                    if (isDrawing) {
                                      _handleBrushAdd(event.localPosition);
                                    } else if (isDeleting) {
                                      _handleBrushDelete(
                                        event.localPosition,
                                        pattern,
                                      );
                                    } else if (isZoom) {
                                      double deltaY =
                                          event.localPosition.dy -
                                          _lastZoomDragY;
                                      _lastZoomDragY = event.localPosition.dy;
                                      final focalX = _viewportX(
                                        event.localPosition.dx,
                                      );
                                      if (deltaY < 0) {
                                        _handleZoom(
                                          1 / 1.05,
                                          focalPointX: focalX,
                                        );
                                      } else if (deltaY > 0) {
                                        _handleZoom(
                                          1.05,
                                          focalPointX: focalX,
                                        );
                                      }
                                    } else if (isSelecting &&
                                        _selectionStart != null) {
                                      setState(() {
                                        _selectionEnd = event.localPosition;
                                      });

                                      _handleHorizontalAutoScroll(
                                        event.position.dx, // global X
                                      );

                                      // Also handle vertical auto-scroll for selection
                                      final screenSize = MediaQuery.of(
                                        context,
                                      ).size;
                                      _handleAutoScroll(
                                        event.position, // global Offset
                                        screenSize,
                                      );
                                    }
                                  },
                                  onPointerUp: (event) {
                                    _stopAutoScroll();
                                    if (isInteracting) {
                                      setState(() => isInteracting = false);
                                    }
                                    if (isDrawing) {
                                      _submitBrushAdd();
                                    } else if (isDeleting) {
                                      _submitBrushDelete(pattern.id);
                                    } else if (isSelecting) {
                                      _commitRangeSelection(pattern);
                                    }
                                  },
                                  child: DawInputDetector(
                                    onCtrlScroll: (delta, localPosition) {
                                      final double multiplier = delta > 0
                                          ? 0.9
                                          : 1.1;
                                      _handleZoom(
                                        multiplier,
                                        focalPointX: _viewportX(
                                          localPosition.dx,
                                        ),
                                      );
                                    },
                                    onAltScroll: (delta, localPosition) {
                                      final double multiplier = delta > 0
                                          ? 0.9
                                          : 1.1;
                                      // localPosition is in grid content
                                      // coordinates; the focal point is
                                      // relative to the visible viewport.
                                      _handleKeyHeightZoom(
                                        multiplier,
                                        localPosition.dy -
                                            (_gridVerticalController.hasClients
                                                ? _gridVerticalController.offset
                                                : 0.0),
                                      );
                                    },
                                    onPinchZoom: (details) {
                                      _handleZoom(
                                        details.scale,
                                        focalPointX: _viewportX(
                                          details.localFocalPoint.dx,
                                        ),
                                      );
                                    },
                                    onOneFingerPan: isPan ? _panEditor : null,
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.translucent,
                                      child: MouseRegion(
                                        cursor: isDrawing
                                            ? SystemMouseCursors.copy
                                            : isPan
                                            ? SystemMouseCursors.move
                                            : isZoom
                                            ? SystemMouseCursors.resizeUpDown
                                            : SystemMouseCursors.basic,
                                        child: SizedBox(
                                          height: 128 * _keyHeight,
                                          width: timelineWidth,
                                          child: ContextMenuWrapper(
                                            title: pianoRollNoteActionsTitle(
                                              pianoRollState,
                                            ),
                                            actions: [
                                              ...pianoRollNoteActions(
                                                context: context,
                                                ref: ref,
                                              ),
                                              DawContextAction(
                                                title: "Paste",
                                                icon: Icons.paste,
                                                onTap: () {
                                                  if (_lastInteractionPos ==
                                                      null) {
                                                    return;
                                                  }

                                                  // Convert local pixel position to Ticks and MIDI Key
                                                  int tick =
                                                      (_lastInteractionPos!.dx /
                                                              zoomX)
                                                          .round();
                                                  int keyIndex =
                                                      (_lastInteractionPos!.dy /
                                                              _keyHeight)
                                                          .floor();
                                                  int midiKey = (127 - keyIndex)
                                                      .clamp(0, 127);

                                                  // Snap to the draw step for clean pasting
                                                  final snappedTick = _snapTick(
                                                    tick,
                                                  );

                                                  ref
                                                      .read(
                                                        pianoRollProvider
                                                            .notifier,
                                                      )
                                                      .pasteNotesFromClipboardToPattern(
                                                        pattern.id,
                                                        snappedTick,
                                                        midiKey,
                                                      );
                                                },
                                              ),
                                            ],
                                            child: Stack(
                                              children: [
                                                // LAYER B1: Unselected Interactive Notes
                                                ...unselectedNotes.map((note) {
                                                  final isPendingDelete =
                                                      _brushDeleteNoteIds
                                                          .contains(note.id);
                                                  return _InteractiveNote(
                                                    key: ValueKey(note.id),
                                                    note: note,
                                                    noteId: note.id,
                                                    patternId: pattern.id,
                                                    generatorId: generatorId,
                                                    zoomX: zoomX,
                                                    keyHeight: _keyHeight,
                                                    selectedTool: selectedTool,
                                                    snapTicks: max(
                                                      1,
                                                      _stepTicks,
                                                    ),
                                                    opacity: isPendingDelete
                                                        ? 0.3
                                                        : 0.8,
                                                    borderColor:
                                                        colors.outlineVariant,
                                                    onDragUpdate: (globalPos) {
                                                      if (selectedTool ==
                                                          PianoRollToolSelection
                                                              .grab) {
                                                        final screenSize =
                                                            MediaQuery.of(
                                                              context,
                                                            ).size;
                                                        _handleAutoScroll(
                                                          globalPos,
                                                          screenSize,
                                                        );
                                                        _handleHorizontalAutoScroll(
                                                          globalPos.dx,
                                                        );
                                                      }
                                                    },
                                                    onDragEnd: () {
                                                      _stopAutoScroll();
                                                    },
                                                    onTapOverride: () {
                                                      if (selectedTool ==
                                                              PianoRollToolSelection
                                                                  .select ||
                                                          selectedTool ==
                                                              PianoRollToolSelection
                                                                  .grab) {
                                                        // Selecting an unselected note clears previous selection and selects only this one
                                                        ref
                                                            .read(
                                                              pianoRollProvider
                                                                  .notifier,
                                                            )
                                                            .selectNotes({
                                                              note.id,
                                                            });
                                                      }
                                                    },
                                                  );
                                                }),

                                                // LAYER B2: Selected Batch Notes
                                                if (selectedNotes.isNotEmpty)
                                                  _InteractiveNoteGroup(
                                                    notes: selectedNotes,
                                                    patternId: pattern.id,
                                                    generatorId: generatorId,
                                                    zoomX: zoomX,
                                                    keyHeight: _keyHeight,
                                                    selectedTool: selectedTool,
                                                    snapTicks: max(
                                                      1,
                                                      _stepTicks,
                                                    ),
                                                    pendingDeleteIds:
                                                        _brushDeleteNoteIds,
                                                    onDragUpdate: (globalPos) {
                                                      if (selectedTool ==
                                                          PianoRollToolSelection
                                                              .grab) {
                                                        final screenSize =
                                                            MediaQuery.of(
                                                              context,
                                                            ).size;
                                                        _handleAutoScroll(
                                                          globalPos,
                                                          screenSize,
                                                        );
                                                        _handleHorizontalAutoScroll(
                                                          globalPos.dx,
                                                        );
                                                      }
                                                    },
                                                    onDragEnd: () {
                                                      _stopAutoScroll();
                                                    },
                                                  ),

                                                // LAYER C: Preview Add Notes
                                                ..._brushAddNotes.map((
                                                  draft,
                                                ) {
                                                  final key = draft.key;
                                                  final startTick =
                                                      draft.startTick;
                                                  final duration =
                                                      draft.duration;
                                                  return Positioned(
                                                    top:
                                                        (127 - key) *
                                                            _keyHeight +
                                                        1,
                                                    left: startTick * zoomX,
                                                    width: duration * zoomX < 5
                                                        ? 5
                                                        : duration * zoomX,
                                                    height: _keyHeight - 2,
                                                    child: IgnorePointer(
                                                      child: Container(
                                                        decoration: BoxDecoration(
                                                          color: colors.primary
                                                              .withValues(
                                                                alpha: 0.5,
                                                              ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                2,
                                                              ),
                                                          border: Border.all(
                                                            color:
                                                                colors.primary,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                }),

                                                // LAYER D: Range Selection Box
                                                if (_selectionStart != null &&
                                                    _selectionEnd != null)
                                                  Positioned.fromRect(
                                                    rect: Rect.fromPoints(
                                                      _selectionStart!,
                                                      _selectionEnd!,
                                                    ),
                                                    child: Container(
                                                      decoration: BoxDecoration(
                                                        color: colors.primary
                                                            .withValues(
                                                              alpha: 0.32,
                                                            ),
                                                        border: Border.all(
                                                          color: colors.primary,
                                                          width: 1.0,
                                                        ),
                                                      ),
                                                    ),
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
                          if (selectedNoteIds.isNotEmpty)
                            FloatingContextPanel(
                              actions: [
                                DawContextAction(
                                  title: "More…",
                                  icon: Icons.more_horiz,
                                  onTap: () => showDawContextMenu(
                                    context: context,
                                    title: pianoRollNoteActionsTitle(
                                      ref.read(pianoRollProvider),
                                    ),
                                    actions: pianoRollNoteActions(
                                      context: context,
                                      ref: ref,
                                    ),
                                  ),
                                ),
                                DawContextAction(
                                  title: "Delete",
                                  onTap: () {
                                    ref
                                        .read(pianoRollProvider.notifier)
                                        .deletePatternNoteBatch(
                                          patternId: pattern.id,
                                          noteIds: selectedNoteIds.toList(),
                                        );
                                    ref
                                        .read(pianoRollProvider.notifier)
                                        .clearNoteSelection();
                                  },
                                ),
                                DawContextAction(
                                  title: "Copy",
                                  onTap: () async {
                                    await ref
                                        .read(pianoRollProvider.notifier)
                                        .copyNotesFromPattern(
                                          pattern.id,
                                          selectedNoteIds.toList(),
                                        );
                                    // we do not clear because every DAW do this
                                  },
                                ),
                                DawContextAction(
                                  title: "Cut",
                                  onTap: () async {
                                    await ref
                                        .read(pianoRollProvider.notifier)
                                        .cutNotesFromPattern(
                                          pattern.id,
                                          selectedNoteIds.toList(),
                                        );
                                  },
                                ),
                              ],
                              onClose: () {
                                ref
                                    .read(pianoRollProvider.notifier)
                                    .clearNoteSelection();
                              },
                              title: "${selectedNoteIds.length} Note(s)",
                            ),
                          // Same draggable playhead as the song timeline,
                          // reading and seeking the pattern position.
                          Positioned.fill(
                            child: PlayheadOverlay(
                              offsetAdjustment: 0,
                              scrollController: _gridHorizontalController,
                              zoomLevel:
                                  patternSamplesPerTick(transportPosition) /
                                  zoomX,
                              sampleSelector: (position) =>
                                  position.patternSamples,
                              isInteracting: isInteracting,
                              snapPosition: (samples) {
                                final samplesPerTick = patternSamplesPerTick(
                                  transportPosition,
                                );
                                return (_snapTick(
                                          (samples / samplesPerTick).round(),
                                        ) *
                                        samplesPerTick)
                                    .round();
                              },
                              onSeek: (samples) => ref
                                  .read(pianoRollProvider.notifier)
                                  .seekPattern(samples),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
          ),
        ),
      ],
    );
  }
}

enum _PianoRollBottomPanel { keyboard, noteParameters }

class _PianoRollBottomPanelView extends StatelessWidget {
  final ScrollController scrollController;
  final double zoomX;
  final double gutterWidth;
  final _PianoRollBottomPanel selectedPanel;
  final ValueChanged<_PianoRollBottomPanel> onPanelChanged;
  final ValueChanged<int> onNoteOn;
  final ValueChanged<int> onNoteOff;
  final Set<int> activeNotes;

  const _PianoRollBottomPanelView({
    required this.scrollController,
    required this.zoomX,
    required this.gutterWidth,
    required this.selectedPanel,
    required this.onPanelChanged,
    required this.onNoteOn,
    required this.onNoteOff,
    required this.activeNotes,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return ColoredBox(
      color: colors.surfaceContainerLowest,
      child: Column(
        children: [
          SizedBox(
            height: 32,
            child: Row(
              children: [
                _BottomPanelTab(
                  label: 'Keyboard',
                  selected: selectedPanel == _PianoRollBottomPanel.keyboard,
                  onTap: () => onPanelChanged(_PianoRollBottomPanel.keyboard),
                ),
                _BottomPanelTab(
                  label: 'Note parameters',
                  selected:
                      selectedPanel == _PianoRollBottomPanel.noteParameters,
                  onTap: () =>
                      onPanelChanged(_PianoRollBottomPanel.noteParameters),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: colors.outlineVariant),
          Expanded(
            child: selectedPanel == _PianoRollBottomPanel.keyboard
                ? LayoutBuilder(
                    builder: (context, constraints) =>
                        ScrollableVirtualKeyboard(
                          height: constraints.maxHeight,
                          onNoteOn: onNoteOn,
                          onNoteOff: onNoteOff,
                          activeNotes: activeNotes,
                          initialCenterNote: 72,
                        ),
                  )
                : NoteParamEditorPanel(
                    scrollController: scrollController,
                    zoomX: zoomX,
                    gutterWidth: gutterWidth,
                  ),
          ),
        ],
      ),
    );
  }
}

class _BottomPanelTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _BottomPanelTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? colors.surfaceContainerHigh : Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: selected ? colors.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: selected ? colors.primary : colors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _PianoRollToolbar extends ConsumerWidget {
  final int patternId;
  final String name;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final GridSize gridDenom;
  final ValueChanged<GridSize?> onGridDenomChanged;

  const _PianoRollToolbar({
    required this.patternId,
    required this.name,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.gridDenom,
    required this.onGridDenomChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final pianoRollState = ref.watch(pianoRollProvider);
    final projectState = ref.watch(projectProvider);

    final selectedTool = pianoRollState.tool;
    final generators = projectState.value?.generators ?? const IMapConst({});
    final previewGeneratorId = pianoRollState.previewGeneratorId;
    // Samplers have no plugin screen, so only plugin generators can be opened.
    final previewPlugin = previewGeneratorId == null
        ? null
        : switch (generators[previewGeneratorId]?.instanceType) {
            UiGeneratorInstanceType_Plugin(:final field0) => field0,
            _ => null,
          };

    // Watch the transport stream directly via Riverpod
    final positionAsync = ref.watch(transportPositionStreamProvider);
    final feedback = positionAsync.value;
    final isPatternPlaying =
        feedback != null && feedback.isPatternMode && feedback.isPatternPlaying;
    final notifier = ref.read(pianoRollProvider.notifier);

    return Container(
      height: 50,
      color: colors.surfaceContainer,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Pattern transport: play/pause resumes from the pattern
            // playhead, stop rewinds it.
            IconButton(
              icon: Icon(
                isPatternPlaying ? Icons.pause : Icons.play_arrow,
                color: isPatternPlaying
                    ? colors.tertiary
                    : colors.onSurfaceVariant,
              ),
              onPressed: previewGeneratorId != null
                  ? notifier.togglePatternPlayback
                  : null,
              tooltip: previewGeneratorId == null
                  ? 'Choose a generator to play this pattern'
                  : isPatternPlaying
                  ? 'Pause (Space)'
                  : 'Play pattern (Space)',
              iconSize: 24,
            ),
            IconButton(
              icon: Icon(Icons.stop, color: colors.onSurfaceVariant),
              onPressed: notifier.stopPatternPlayback,
              tooltip: 'Stop and rewind',
              iconSize: 22,
            ),
            const SizedBox(width: 4),
            _buildDivider(context),
            const SizedBox(width: 8),

            // Pattern name
            Text(
              name,
              style: TextStyle(
                color: colors.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 16),
            _buildDivider(context),
            const SizedBox(width: 8),

            // Tool buttons
            _ToolButton(
              icon: Icons.near_me,
              label: 'Grab (Alt+1)',
              isActive: selectedTool == PianoRollToolSelection.grab,
              onTap: () => ref
                  .read(pianoRollProvider.notifier)
                  .selectPianoRollTool(PianoRollToolSelection.grab),
            ),
            _ToolButton(
              icon: Icons.edit,
              label: 'Draw: stamps the last selection (Alt+2)',
              isActive: selectedTool == PianoRollToolSelection.draw,
              onTap: () => ref
                  .read(pianoRollProvider.notifier)
                  .selectPianoRollTool(PianoRollToolSelection.draw),
            ),
            _ToolButton(
              icon: Icons.delete,
              label: 'Delete (Alt+3)',
              isActive: selectedTool == PianoRollToolSelection.delete,
              onTap: () => ref
                  .read(pianoRollProvider.notifier)
                  .selectPianoRollTool(PianoRollToolSelection.delete),
            ),
            _ToolButton(
              icon: Icons.crop_free,
              label: 'Select (Alt+4)',
              isActive: selectedTool == PianoRollToolSelection.select,
              onTap: () => ref
                  .read(pianoRollProvider.notifier)
                  .selectPianoRollTool(PianoRollToolSelection.select),
            ),
            _ToolButton(
              icon: Icons.settings_ethernet,
              label: 'Select region: drag the ruler to loop (Alt+5)',
              isActive: selectedTool == PianoRollToolSelection.selectRegion,
              onTap: () => notifier.selectPianoRollTool(
                PianoRollToolSelection.selectRegion,
              ),
            ),
            _ToolButton(
              icon: Icons.content_cut,
              label: 'Slice (Alt+6)',
              isActive: selectedTool == PianoRollToolSelection.slice,
              onTap: () =>
                  notifier.selectPianoRollTool(PianoRollToolSelection.slice),
            ),
            _ToolButton(
              icon: Icons.pan_tool,
              label: 'Pan (Alt+7)',
              isActive: selectedTool == PianoRollToolSelection.pan,
              onTap: () => ref
                  .read(pianoRollProvider.notifier)
                  .selectPianoRollTool(PianoRollToolSelection.pan),
            ),
            _ToolButton(
              icon: Icons.zoom_in,
              label: 'Zoom (Alt+8)',
              isActive: selectedTool == PianoRollToolSelection.zoom,
              onTap: () => ref
                  .read(pianoRollProvider.notifier)
                  .selectPianoRollTool(PianoRollToolSelection.zoom),
            ),
            const SizedBox(width: 8),
            _buildDivider(context),
            const SizedBox(width: 8),

            // Zoom controls
            IconButton(
              icon: Icon(Icons.zoom_in, color: colors.onSurfaceVariant),
              onPressed: onZoomIn,
              tooltip: 'Zoom In',
              iconSize: 20,
            ),
            IconButton(
              icon: Icon(Icons.zoom_out, color: colors.onSurfaceVariant),
              onPressed: onZoomOut,
              tooltip: 'Zoom Out',
              iconSize: 20,
            ),
            IconButton(
              icon: Icon(Icons.unfold_less, color: colors.onSurfaceVariant),
              onPressed: () => notifier.scaleKeyHeight(1 / 1.15),
              tooltip: 'Shorter note rows (Alt+scroll)',
              iconSize: 20,
            ),
            IconButton(
              icon: Icon(Icons.unfold_more, color: colors.onSurfaceVariant),
              onPressed: () => notifier.scaleKeyHeight(1.15),
              tooltip: 'Taller note rows (Alt+scroll)',
              iconSize: 20,
            ),
            IconButton(
              icon: Icon(Icons.auto_fix_high, color: colors.onSurfaceVariant),
              onPressed: () => showDawContextMenu(
                context: context,
                title: pianoRollNoteActionsTitle(ref.read(pianoRollProvider)),
                actions: pianoRollNoteActions(context: context, ref: ref),
              ),
              tooltip: 'Note tools: quantize, legato, chop, transpose…',
              iconSize: 20,
            ),
            const SizedBox(width: 8),

            // Grid: the lines drawn behind the notes.
            Text(
              'Grid ',
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
            ),
            DropdownButton<GridSize>(
              value: gridDenom,
              dropdownColor: colors.surfaceContainerHigh,
              style: TextStyle(color: colors.onSurface, fontSize: 12),
              underline: const SizedBox(),
              items: [
                for (final size in GridSize.values)
                  DropdownMenuItem(value: size, child: Text(_gridLabel(size))),
              ],
              onChanged: onGridDenomChanged,
            ),
            const SizedBox(width: 8),

            // Step: what drawing, moving, and resizing snap to.
            Tooltip(
              message: 'Snap step for drawing and moving notes',
              child: Text(
                'Step ',
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
              ),
            ),
            DropdownButton<GridSize?>(
              value: pianoRollState.drawStep,
              dropdownColor: colors.surfaceContainerHigh,
              style: TextStyle(color: colors.onSurface, fontSize: 12),
              underline: const SizedBox(),
              items: [
                const DropdownMenuItem<GridSize?>(
                  value: null,
                  child: Text('Grid'),
                ),
                for (final size in GridSize.values)
                  DropdownMenuItem<GridSize?>(
                    value: size,
                    child: Text(_gridLabel(size)),
                  ),
              ],
              onChanged: notifier.setDrawStep,
            ),
            const SizedBox(width: 8),
            _buildDivider(context),
            const SizedBox(width: 8),

            // Generator dropdown
            Text(
              'Generator: ',
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
            ),
            DropdownButton<int?>(
              value: previewGeneratorId,
              hint: Text(
                'Select',
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
              dropdownColor: colors.surfaceContainerHigh,
              style: TextStyle(color: colors.onSurface, fontSize: 12),
              underline: const SizedBox(),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('None')),
                ...generators.entries.map(
                  (entry) => DropdownMenuItem<int?>(
                    value: entry.key,
                    child: Text(() {
                      final instanceType = entry.value.instanceType;
                      final name = switch (instanceType) {
                        UiGeneratorInstanceType_Plugin(:final field0) =>
                          field0.name,
                        _ => "Sampler",
                      };
                      return name;
                    }()),
                  ),
                ),
              ],
              onChanged: (value) {
                ref
                    .read(pianoRollProvider.notifier)
                    .setPreviewGenerator(generatorId: value);

                if (value != null && isPatternPlaying) {
                  try {
                    switchPatternGenerator(
                      ctx: ref.read(projectProvider.notifier).dawContext,
                      generatorId: value,
                    );
                  } catch (e) {
                    AppLogger.error("Failed to hot-swap generator: $e");
                    ref.read(notificationProvider.notifier).error(e);
                  }
                }
              },
            ),
            IconButton(
              icon: Icon(Icons.open_in_new, color: colors.onSurfaceVariant),
              onPressed: previewGeneratorId != null && previewPlugin != null
                  ? () => openPluginInterface(
                      context: context,
                      ref: ref,
                      target: UiPluginTarget.generator(previewGeneratorId),
                      registryId: previewPlugin.registryId,
                      instanceId: previewGeneratorId,
                      pluginName: previewPlugin.name,
                    )
                  : null,
              tooltip: previewPlugin == null
                  ? 'Choose a plugin generator to open its screen'
                  : 'Open plugin screen',
              iconSize: 20,
            ),
          ],
        ),
      ),
    );
  }

  /// Note-length label: 1/4 is one beat and 1/1 one bar in 4/4.
  static String _gridLabel(GridSize size) => size.label;

  Widget _buildDivider(BuildContext context) {
    return Container(
      width: 1,
      height: 30,
      color: Theme.of(context).colorScheme.outlineVariant,
    );
  }
}

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _ToolButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: isActive
              ? BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                )
              : null,
          child: Icon(
            icon,
            color: isActive ? colors.primary : colors.onSurfaceVariant,
            size: 20,
          ),
        ),
      ),
    );
  }
}

class _PianoKey extends StatefulWidget {
  final int midiKey;
  final Function(bool) onPlayNote;
  final double height;

  const _PianoKey({
    required this.midiKey,
    required this.height,
    required this.onPlayNote,
  });

  @override
  State<_PianoKey> createState() {
    return _PianoKeyState();
  }
}

class _PianoKeyState extends State<_PianoKey> {
  bool _isPressed = false;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    const blackIndices = [1, 3, 6, 8, 10];
    final isBlack = blackIndices.contains(widget.midiKey % 12);
    final label = numToMidiKey(widget.midiKey);

    return Listener(
      onPointerDown: (event) {
        setState(() {
          _isPressed = true;
        });
        widget.onPlayNote(true);
      },
      onPointerUp: (event) {
        setState(() {
          _isPressed = false;
        });
        widget.onPlayNote(false);
      },
      onPointerCancel: (event) {
        if (_isPressed) {
          setState(() {
            _isPressed = false;
          });
          widget.onPlayNote(false);
        }
      },
      child: Container(
        height: widget.height,
        decoration: BoxDecoration(
          color: _isPressed
              ? colors.primary
              : (isBlack ? Colors.black : Colors.white),
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade700, width: 0.5),
          ),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 4),
        child: (widget.midiKey % 12 == 0 || !isBlack)
            ? Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  color: _isPressed
                      ? Colors.black
                      : (isBlack ? Colors.white54 : Colors.black54),
                ),
              )
            : null,
      ),
    );
  }
}

// ignore: unused_field
enum _NoteDragMode { none, move, resizeLeft, resizeRight }

class _InteractiveNote extends ConsumerStatefulWidget {
  final UiNote note;
  final int noteId;
  final int patternId;
  final int? generatorId; // Optional: To preview note while dragging
  final double zoomX;
  final double keyHeight;
  final PianoRollToolSelection selectedTool;
  final int snapTicks;
  final ValueChanged<Offset>? onDragUpdate;
  final VoidCallback? onDragEnd;
  final double opacity;
  final Color? borderColor;
  final VoidCallback? onTapOverride;

  const _InteractiveNote({
    super.key,
    required this.note,
    required this.noteId,
    required this.patternId,
    this.generatorId,
    required this.zoomX,
    required this.keyHeight,
    required this.selectedTool,
    required this.snapTicks,
    this.onDragUpdate,
    this.onDragEnd,
    this.opacity = 1.0,
    this.borderColor,
    this.onTapOverride,
  });

  @override
  ConsumerState<_InteractiveNote> createState() {
    return _InteractiveNoteState();
  }
}

class _InteractiveNoteState extends ConsumerState<_InteractiveNote> {
  late double _localLeft;
  late double _localWidth;
  late double _localTop;
  // double _startDragX = 0;
  // double _startDragY = 0;
  _NoteDragMode _mode = _NoteDragMode.none;

  int? _currentPreviewKey;

  @override
  void initState() {
    super.initState();
    _syncFromProps();
  }

  @override
  void didUpdateWidget(covariant _InteractiveNote oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only sync if we are NOT dragging to avoid jitter
    if (_mode == _NoteDragMode.none) {
      _syncFromProps();
    }
  }

  void _syncFromProps() {
    _localLeft = widget.note.startTick * widget.zoomX;
    _localWidth = widget.note.duration * widget.zoomX;
    _localTop = (127 - widget.note.key) * widget.keyHeight;
  }

  void _playNote(int key, bool on) {
    if (widget.generatorId != null) {
      try {
        playPreviewNoteGenerator(
          ctx: ref.read(projectProvider.notifier).dawContext,
          generatorId: widget.generatorId!,
          noteKey: key,
          velocity: 100,
          isOn: on,
        );
      } catch (e) {
        AppLogger.error(e.toString());
        ref.read(notificationProvider.notifier).error(e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    // Determine cursor based on tool
    MouseCursor cursor = SystemMouseCursors.click;
    if (widget.selectedTool == PianoRollToolSelection.delete) {
      cursor = SystemMouseCursors.basic;
    } else if (_mode != _NoteDragMode.none) {
      cursor = SystemMouseCursors.grabbing;
    } else {
      cursor = SystemMouseCursors.click;
    }

    return Positioned(
      top: _localTop + 1,
      left: _localLeft,
      width: _localWidth < 5 ? 5 : _localWidth,
      height: widget.keyHeight - 2,
      child: Opacity(
        opacity: widget.opacity,
        child: MouseRegion(
          cursor: cursor,
          child: IgnorePointer(
            ignoring: widget.selectedTool == PianoRollToolSelection.pan,
            // Right-clicking an unselected note selects it, so the grid's
            // context menu acts on the note under the pointer.
            child: Listener(
            onPointerDown: (event) {
              if (event.buttons & kSecondaryButton == 0) return;
              final selection = ref.read(pianoRollProvider).selectedNoteIds;
              if (!selection.contains(widget.noteId)) {
                ref.read(pianoRollProvider.notifier).selectNotes({widget.noteId});
              }
            },
            child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (widget.onTapOverride != null) {
                widget.onTapOverride!();
                return;
              }

              if (widget.selectedTool == PianoRollToolSelection.delete) {
                final selectedIds = ref.read(pianoRollProvider).selectedNoteIds;
                if (selectedIds.length > 1 &&
                    selectedIds.contains(widget.noteId)) {
                  ref
                      .read(pianoRollProvider.notifier)
                      .deletePatternNoteBatch(
                        patternId: widget.patternId,
                        noteIds: selectedIds.toList(),
                      );
                } else {
                  ref
                      .read(pianoRollProvider.notifier)
                      .deletePatternNote(
                        patternId: widget.patternId,
                        noteId: widget.noteId,
                      );
                }
              }
            },
            onPanStart: (details) {
              if (widget.selectedTool != PianoRollToolSelection.grab) return;

              final renderBox = context.findRenderObject() as RenderBox;
              final localPos = renderBox.globalToLocal(details.globalPosition);

              // Hit test edge for resizing
              const edgeThreshold = 10.0;

              setState(() {
                if (localPos.dx > _localWidth - edgeThreshold) {
                  _mode = _NoteDragMode.resizeRight;
                } else {
                  _mode = _NoteDragMode.move;
                }
                // _startDragX = _localLeft;
                // _startDragY = _localTop;
              });

              // Play sound on touch
              _currentPreviewKey = widget.note.key;
              _playNote(_currentPreviewKey!, true);
            },

            onPanUpdate: (details) {
              if (_mode == _NoteDragMode.none) return;
              setState(() {
                if (_mode == _NoteDragMode.move) {
                  _localLeft += details.delta.dx;
                  _localTop += details.delta.dy;

                  int keyIndex = (_localTop / widget.keyHeight).round();
                  int newKey = (127 - keyIndex).clamp(0, 127);

                  if (newKey != _currentPreviewKey) {
                    if (_currentPreviewKey != null) {
                      _playNote(_currentPreviewKey!, false);
                    }
                    _currentPreviewKey = newKey;
                    _playNote(_currentPreviewKey!, true);
                  }
                } else if (_mode == _NoteDragMode.resizeRight) {
                  _localWidth += details.delta.dx;
                  if (_localWidth < 5) _localWidth = 5;
                }
                // SUGGESTION: Implement Resize Left logic if needed (requires shifting start tick)
              });
              widget.onDragUpdate?.call(details.globalPosition);
            },
            onPanEnd: (details) {
              if (_currentPreviewKey != null) {
                _playNote(_currentPreviewKey!, false);
                _currentPreviewKey = null;
              }

              // final state = ref.read(globalStateProvider);

              if (widget.generatorId != null) {
                try {
                  playPreviewNoteGenerator(
                    ctx: ref.read(projectProvider.notifier).dawContext,
                    generatorId: widget.generatorId!,
                    noteKey: widget.note.key,
                    velocity: 100,
                    isOn: false,
                  );
                } catch (e) {
                  AppLogger.error(e.toString());
                  ref.read(notificationProvider.notifier).error(e);
                }
              }

              int snap = widget.snapTicks;

              if (_mode == _NoteDragMode.move) {
                int keyIndex = (_localTop / widget.keyHeight).round();
                int newKey = (127 - keyIndex).clamp(0, 127);

                // snap time
                int rawTick = (_localLeft / widget.zoomX).round();

                int newStartTick = (rawTick / snap).round() * snap;
                if (newStartTick < 0) newStartTick = 0;

                final selectedIds = ref.read(pianoRollProvider).selectedNoteIds;
                if (selectedIds.length > 1 &&
                    selectedIds.contains(widget.noteId)) {
                  final tickDelta = newStartTick - widget.note.startTick;
                  final keyDelta = newKey - widget.note.key;

                  final pattern = ref
                      .read(projectProvider)
                      .value
                      ?.patterns[widget.patternId];
                  if (pattern != null) {
                    final updates = <(int, int, int)>[];
                    for (final n in pattern.notes) {
                      if (selectedIds.contains(n.id)) {
                        int targetStartTick = n.startTick + tickDelta;
                        if (targetStartTick < 0) targetStartTick = 0;
                        int targetKey = (n.key + keyDelta).clamp(0, 127);
                        updates.add((n.id, targetStartTick, targetKey));
                      }
                    }
                    ref
                        .read(pianoRollProvider.notifier)
                        .movePatternNoteBatch(
                          patternId: widget.patternId,
                          updates: updates,
                        );
                  }
                } else {
                  ref
                      .read(pianoRollProvider.notifier)
                      .movePatternNote(
                        patternId: widget.patternId,
                        noteId: widget.noteId,
                        newStartTick: newStartTick,
                        newKey: newKey,
                      );
                }
              } else if (_mode == _NoteDragMode.resizeRight) {
                int rawDuration = (_localWidth / widget.zoomX).round();
                int newDuration = (rawDuration / snap).round() * snap;
                if (newDuration < 10) newDuration = snap;

                final selectedIds = ref.read(pianoRollProvider).selectedNoteIds;
                if (selectedIds.length > 1 &&
                    selectedIds.contains(widget.noteId)) {
                  final durationDelta = newDuration - widget.note.duration;

                  final pattern = ref
                      .read(projectProvider)
                      .value
                      ?.patterns[widget.patternId];
                  if (pattern != null) {
                    final updates = <(int, int)>[];
                    for (final n in pattern.notes) {
                      if (selectedIds.contains(n.id)) {
                        int targetDuration = n.duration + durationDelta;
                        if (targetDuration < 10) targetDuration = 10;
                        updates.add((n.id, targetDuration));
                      }
                    }
                    ref
                        .read(pianoRollProvider.notifier)
                        .resizePatternNoteBatch(
                          patternId: widget.patternId,
                          updates: updates,
                        );
                  }
                } else {
                  ref
                      .read(pianoRollProvider.notifier)
                      .resizePatternNote(
                        patternId: widget.patternId,
                        noteId: widget.noteId,
                        newDuration: newDuration,
                      );
                }
              }
              setState(() {
                _mode = _NoteDragMode.none;
                // Snap visual state immediately to grid so it looks clean
                // _localTop =
                //     (_localTop / widget.keyHeight).round() * widget.keyHeight;
              });
              widget.onDragEnd?.call();
            },
            child: Container(
              decoration: BoxDecoration(
                color: _mode != _NoteDragMode.none
                    ? colors.primary
                    : colors.primaryContainer,
                borderRadius: BorderRadius.circular(2),
                border: Border.all(color: widget.borderColor ?? colors.primary),
              ),
              child: _localWidth > 30
                  ? Center(
                      child: Icon(
                        Icons.drag_handle,
                        size: 12,
                        color: colors.onPrimaryContainer.withValues(alpha: 0.5),
                      ),
                    )
                  : null,
            ),
          ),
          ),
        ),
      ),
    ),
    );
  }
}

class _PianoGridPainter extends CustomPainter {
  final ScrollController horizontalController;
  final ScrollController verticalController;
  final double zoomX;
  final double keyHeight;
  final GridSize gridDenom;
  final Color lineColor;

  _PianoGridPainter({
    required this.horizontalController,
    required this.verticalController,
    required this.zoomX,
    required this.keyHeight,
    required this.gridDenom,
    required this.lineColor,
  }) : super(
         repaint: Listenable.merge([
           horizontalController,
           verticalController,
         ]),
       );

  @override
  void paint(Canvas canvas, Size size) {
    if (zoomX <= 0 || keyHeight <= 0 || size.isEmpty) return;

    final horizontalOffset = horizontalController.hasClients
        ? horizontalController.offset
        : 0.0;
    final verticalOffset = verticalController.hasClients
        ? verticalController.offset
        : 0.0;
    final paint = Paint()..strokeWidth = 1.0;

    paint.color = lineColor.withValues(alpha: 0.12);
    final firstKeyLine = max(0, (verticalOffset / keyHeight).floor());
    final lastKeyLine = min(
      128,
      ((verticalOffset + size.height) / keyHeight).ceil(),
    );
    for (var keyLine = firstKeyLine; keyLine <= lastKeyLine; keyLine++) {
      final viewportY = keyLine * keyHeight - verticalOffset;
      canvas.drawLine(
        Offset(0, viewportY),
        Offset(size.width, viewportY),
        paint,
      );
    }

    if (gridDenom == GridSize.infinity) return;

    final ticksPerGrid = 3840.0 / gridDenom.value;
    final basePixelsPerGrid = ticksPerGrid * zoomX;
    if (!basePixelsPerGrid.isFinite || basePixelsPerGrid <= 0) return;

    var skippedGridLines = 1;
    while (basePixelsPerGrid * skippedGridLines < 4) {
      skippedGridLines *= 2;
    }
    final pixelsPerVisibleGrid = basePixelsPerGrid * skippedGridLines;
    final visibleStart = max(0.0, horizontalOffset - 2);
    final visibleEnd = horizontalOffset + size.width + 2;
    var visibleGridIndex = (visibleStart / pixelsPerVisibleGrid).floor();
    var absoluteX = visibleGridIndex * pixelsPerVisibleGrid;

    while (absoluteX <= visibleEnd) {
      final baseGridIndex = visibleGridIndex * skippedGridLines;
      final currentTick = (baseGridIndex * ticksPerGrid).round();

      final isBar = currentTick % 3840 == 0;
      final isBeat = currentTick % 960 == 0;

      if (isBar) {
        paint.color = lineColor.withValues(alpha: 0.54);
        paint.strokeWidth = 1.5;
      } else if (isBeat) {
        paint.color = lineColor.withValues(alpha: 0.24);
        paint.strokeWidth = 1.0;
      } else {
        paint.color = lineColor.withValues(alpha: 0.12);
        paint.strokeWidth = 0.5;
      }

      final viewportX = absoluteX - horizontalOffset;
      canvas.drawLine(
        Offset(viewportX, 0),
        Offset(viewportX, size.height),
        paint,
      );

      visibleGridIndex++;
      absoluteX = visibleGridIndex * pixelsPerVisibleGrid;
    }
  }

  @override
  bool shouldRepaint(covariant _PianoGridPainter old) =>
      old.horizontalController != horizontalController ||
      old.verticalController != verticalController ||
      old.zoomX != zoomX ||
      old.keyHeight != keyHeight ||
      old.gridDenom != gridDenom ||
      old.lineColor != lineColor;
}

/// A specialized widget to handle grouped interactions for multiple selected notes.
/// It creates a relative coordinate system bound box and accurately applies deltas to the whole group.
class _InteractiveNoteGroup extends ConsumerStatefulWidget {
  final List<UiNote> notes;
  final int patternId;
  final int? generatorId;
  final double zoomX;
  final double keyHeight;
  final PianoRollToolSelection selectedTool;
  final int snapTicks;
  final Set<int> pendingDeleteIds;
  final ValueChanged<Offset>? onDragUpdate;
  final VoidCallback? onDragEnd;

  const _InteractiveNoteGroup({
    required this.notes,
    required this.patternId,
    this.generatorId,
    required this.zoomX,
    required this.keyHeight,
    required this.selectedTool,
    required this.snapTicks,
    required this.pendingDeleteIds,
    this.onDragUpdate,
    this.onDragEnd,
  });

  @override
  ConsumerState<_InteractiveNoteGroup> createState() =>
      _InteractiveNoteGroupState();
}

class _InteractiveNoteGroupState extends ConsumerState<_InteractiveNoteGroup> {
  double _dragOffsetX = 0;
  double _dragOffsetY = 0;
  double _dragWidthDelta = 0;
  _NoteDragMode _mode = _NoteDragMode.none;

  int? _currentPreviewKey;

  void _playNote(int key, bool on) {
    if (widget.generatorId != null) {
      try {
        playPreviewNoteGenerator(
          ctx: ref.read(projectProvider.notifier).dawContext,
          generatorId: widget.generatorId!,
          noteKey: key,
          velocity: 100,
          isOn: on,
        );
      } catch (e) {
        AppLogger.error(e.toString());
        ref.read(notificationProvider.notifier).error(e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (widget.notes.isEmpty) return const SizedBox.shrink();

    int minTick = widget.notes.map((n) => n.startTick).reduce(min);
    int maxTick = widget.notes.map((n) => n.startTick + n.duration).reduce(max);
    int maxKey = widget.notes.map((n) => n.key).reduce(max);
    int minKey = widget.notes.map((n) => n.key).reduce(min);

    double baseLeft = minTick * widget.zoomX;
    double baseTop = (127 - maxKey) * widget.keyHeight;
    double baseWidth = (maxTick - minTick) * widget.zoomX;
    double baseHeight = (maxKey - minKey + 1) * widget.keyHeight;

    MouseCursor cursor = SystemMouseCursors.click;
    if (widget.selectedTool == PianoRollToolSelection.delete) {
      cursor = SystemMouseCursors.basic;
    } else if (_mode != _NoteDragMode.none) {
      cursor = SystemMouseCursors.grabbing;
    } else {
      cursor = SystemMouseCursors.click;
    }

    return Positioned(
      left: baseLeft + _dragOffsetX,
      top: baseTop + _dragOffsetY,
      width: max(0, baseWidth + _dragWidthDelta),
      height: baseHeight,
      child: MouseRegion(
        cursor: cursor,
        child: IgnorePointer(
          ignoring: widget.selectedTool == PianoRollToolSelection.pan,
          child: Stack(
            clipBehavior: Clip.none,
            children: widget.notes.map((note) {
            double noteLeft = (note.startTick - minTick) * widget.zoomX;
            double noteTop = (maxKey - note.key) * widget.keyHeight;
            double noteWidth = note.duration * widget.zoomX;

            if (_mode == _NoteDragMode.resizeRight) {
              noteWidth += _dragWidthDelta;
            }
            if (noteWidth < 5) noteWidth = 5;

            final isPendingDelete = widget.pendingDeleteIds.contains(note.id);

            return Positioned(
              left: noteLeft,
              top: noteTop - 1,
              width: noteWidth,
              height: widget.keyHeight - 2,
              child: Opacity(
                opacity: isPendingDelete ? 0.3 : 1.0,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (widget.selectedTool == PianoRollToolSelection.delete) {
                      ref
                          .read(pianoRollProvider.notifier)
                          .deletePatternNoteBatch(
                            patternId: widget.patternId,
                            noteIds: widget.notes.map((e) => e.id).toList(),
                          );
                      ref.read(pianoRollProvider.notifier).clearNoteSelection();
                    }
                  },
                  onPanStart: (details) {
                    if (widget.selectedTool != PianoRollToolSelection.grab) {
                      return;
                    }
                    final renderBox = context.findRenderObject() as RenderBox;
                    final localPos = renderBox.globalToLocal(
                      details.globalPosition,
                    );
                    const edgeThreshold = 10.0;

                    // localPos is relative to the Bounding Box Stack.
                    // Verify if the grab hits the right-side edge of THIS specific child note.
                    if (localPos.dx > noteLeft + noteWidth - edgeThreshold &&
                        localPos.dx <= noteLeft + noteWidth) {
                      setState(() => _mode = _NoteDragMode.resizeRight);
                    } else {
                      setState(() => _mode = _NoteDragMode.move);
                    }

                    _currentPreviewKey = note.key;
                    _playNote(_currentPreviewKey!, true);
                  },
                  onPanUpdate: (details) {
                    if (_mode == _NoteDragMode.none) return;
                    setState(() {
                      if (_mode == _NoteDragMode.move) {
                        _dragOffsetX += details.delta.dx;
                        _dragOffsetY += details.delta.dy;
                      } else if (_mode == _NoteDragMode.resizeRight) {
                        _dragWidthDelta += details.delta.dx;
                      }
                    });
                    widget.onDragUpdate?.call(details.globalPosition);
                  },

                  onPanEnd: (details) {
                    if (_currentPreviewKey != null) {
                      _playNote(_currentPreviewKey!, false);
                      _currentPreviewKey = null;
                    }

                    final state = ref.read(pianoRollProvider.notifier);
                    int snap = widget.snapTicks;

                    if (_mode == _NoteDragMode.move) {
                      int rawTickDelta = (_dragOffsetX / widget.zoomX).round();
                      int snappedTickDelta =
                          (rawTickDelta / snap).round() * snap;

                      // Negative Y means moving UP to a higher pitch
                      int keyDelta = -(_dragOffsetY / widget.keyHeight).round();

                      if (snappedTickDelta != 0 || keyDelta != 0) {
                        final updates = <(int, int, int)>[];
                        for (final n in widget.notes) {
                          int targetStartTick = n.startTick + snappedTickDelta;
                          if (targetStartTick < 0) targetStartTick = 0;
                          int targetKey = (n.key + keyDelta).clamp(0, 127);
                          updates.add((n.id, targetStartTick, targetKey));
                        }
                        state.movePatternNoteBatch(
                          patternId: widget.patternId,
                          updates: updates,
                        );
                      }
                    } else if (_mode == _NoteDragMode.resizeRight) {
                      int rawDurationDelta = (_dragWidthDelta / widget.zoomX)
                          .round();
                      int snappedDurationDelta =
                          (rawDurationDelta / snap).round() * snap;

                      if (snappedDurationDelta != 0) {
                        final updates = <(int, int)>[];
                        for (final n in widget.notes) {
                          int targetDuration =
                              n.duration + snappedDurationDelta;
                          if (targetDuration < 10) targetDuration = 10;
                          updates.add((n.id, targetDuration));
                        }
                        state.resizePatternNoteBatch(
                          patternId: widget.patternId,
                          updates: updates,
                        );
                      }
                    }

                    setState(() {
                      _mode = _NoteDragMode.none;
                      _dragOffsetX = 0;
                      _dragOffsetY = 0;
                      _dragWidthDelta = 0;
                    });
                    widget.onDragEnd?.call();
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: _mode != _NoteDragMode.none
                          ? colors.primary
                          : colors.primaryContainer,
                      borderRadius: BorderRadius.circular(2),
                      border: Border.all(
                        color: colors.primary,
                        width: 1.5,
                      ), // Thick white border for selection
                    ),
                    child: noteWidth > 30
                        ? Center(
                            child: Icon(
                              Icons.drag_handle,
                              size: 12,
                              color: colors.onPrimaryContainer.withValues(
                                alpha: 0.5,
                              ),
                            ),
                          )
                        : null,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    ),
    );
  }
}
