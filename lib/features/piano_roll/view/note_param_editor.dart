import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/piano_roll_state.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/src/rust/api/pattern.dart';

/// Note parameters shown in the [NoteParamEditorPanel] lane.
enum NoteParameter {
  velocity('Velocity'),
  pitch('Pitch'),
  pan('Pan');

  const NoteParameter(this.label);

  final String label;

  /// Whether the lane is centered on a neutral value rather than growing from 0.
  bool get isBipolar => this != NoteParameter.velocity;

  /// The note's value mapped to 0..1.
  double normalized(UiNote note) => switch (this) {
    NoteParameter.velocity => note.velocity / 127,
    NoteParameter.pitch => (note.pitch + 2) / 4,
    NoteParameter.pan => (note.pan + 1) / 2,
  };

  /// A parameter update that sets this parameter to [value] (0..1).
  UiNoteParamUpdate update(int noteId, double value) => switch (this) {
    NoteParameter.velocity => UiNoteParamUpdate(
      noteId: noteId,
      velocity: (1 + value * 126).round(),
    ),
    NoteParameter.pitch => UiNoteParamUpdate(
      noteId: noteId,
      pitch: value * 4 - 2,
    ),
    NoteParameter.pan => UiNoteParamUpdate(noteId: noteId, pan: value * 2 - 1),
  };
}

/// FL Studio-style note parameter lane under the piano roll.
///
/// One bar per note sits under its start, scrolled with the note grid. Dragging
/// across the lane draws values onto the notes it passes; with a selection only
/// the selected notes change. The edit commits as one undo step on release.
class NoteParamEditorPanel extends ConsumerStatefulWidget {
  const NoteParamEditorPanel({
    super.key,
    required this.scrollController,
    required this.zoomX,
    required this.gutterWidth,
  });

  /// Horizontal controller of the note grid, so bars line up with notes.
  final ScrollController scrollController;

  /// Grid zoom in pixels per tick.
  final double zoomX;

  /// Width of the piano-key column left of the grid.
  final double gutterWidth;

  @override
  ConsumerState<NoteParamEditorPanel> createState() =>
      _NoteParamEditorPanelState();
}

class _NoteParamEditorPanelState extends ConsumerState<NoteParamEditorPanel> {
  NoteParameter _parameter = NoteParameter.velocity;

  /// Values drawn during the current drag, by note ID.
  final Map<int, double> _draft = {};
  double? _lastDragX;

  double get _scrollOffset =>
      widget.scrollController.hasClients ? widget.scrollController.offset : 0.0;

  void _paint(Offset position, Size size, List<UiNote> notes) {
    final value = (1 - position.dy / size.height).clamp(0.0, 1.0);
    final absoluteX = position.dx + _scrollOffset;
    final fromX = (_lastDragX ?? absoluteX) - 3;
    final toX = absoluteX + 3;
    final (low, high) = fromX <= toX ? (fromX, toX) : (toX, fromX);
    _lastDragX = absoluteX;

    final selection = ref.read(pianoRollProvider).selectedNoteIds;
    var changed = false;
    for (final note in notes) {
      if (selection.isNotEmpty && !selection.contains(note.id)) continue;
      final x = note.startTick * widget.zoomX;
      if (x >= low && x <= high) {
        _draft[note.id] = value;
        changed = true;
      }
    }
    if (changed) setState(() {});
  }

  Future<void> _commit() async {
    _lastDragX = null;
    if (_draft.isEmpty) return;
    final updates = [
      for (final entry in _draft.entries)
        _parameter.update(entry.key, entry.value),
    ];
    await ref.read(pianoRollProvider.notifier).setNoteParams(updates);
    if (mounted) setState(_draft.clear);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final patternId = ref.watch(
      pianoRollProvider.select((state) => state.editingPatternId),
    );
    final selection = ref.watch(
      pianoRollProvider.select((state) => state.selectedNoteIds),
    );
    final notes = patternId == null
        ? const <UiNote>[]
        : ref.watch(
                projectProvider.select(
                  (project) => project.value?.patterns[patternId]?.notes,
                ),
              ) ??
              const <UiNote>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              DropdownButtonHideUnderline(
                child: DropdownButton<NoteParameter>(
                  value: _parameter,
                  isDense: true,
                  dropdownColor: colors.surfaceContainerHigh,
                  items: [
                    for (final parameter in NoteParameter.values)
                      DropdownMenuItem(
                        value: parameter,
                        child: Text(parameter.label),
                      ),
                  ],
                  onChanged: (parameter) {
                    if (parameter != null) {
                      setState(() => _parameter = parameter);
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  selection.isEmpty
                      ? 'Drag across the lane to draw values.'
                      : 'Drawing edits the ${selection.length} selected notes.',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: colors.outlineVariant),
        Expanded(
          child: Row(
            children: [
              SizedBox(width: widget.gutterWidth),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final size = constraints.biggest;
                    return Listener(
                      onPointerDown: (event) {
                        if (event.buttons & kPrimaryButton == 0) return;
                        _paint(event.localPosition, size, notes);
                      },
                      onPointerMove: (event) {
                        if (event.buttons & kPrimaryButton == 0) return;
                        _paint(event.localPosition, size, notes);
                      },
                      onPointerUp: (_) => _commit(),
                      onPointerCancel: (_) => setState(() {
                        _draft.clear();
                        _lastDragX = null;
                      }),
                      child: ClipRect(
                        child: CustomPaint(
                          size: size,
                          painter: _NoteParamLanePainter(
                            notes: notes,
                            parameter: _parameter,
                            draft: Map.of(_draft),
                            selection: selection.unlockView,
                            zoomX: widget.zoomX,
                            scrollController: widget.scrollController,
                            barColor: colors.primary,
                            dimColor: colors.outline,
                            guideColor: colors.outlineVariant,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NoteParamLanePainter extends CustomPainter {
  _NoteParamLanePainter({
    required this.notes,
    required this.parameter,
    required this.draft,
    required this.selection,
    required this.zoomX,
    required this.scrollController,
    required this.barColor,
    required this.dimColor,
    required this.guideColor,
  }) : super(repaint: scrollController);

  final List<UiNote> notes;
  final NoteParameter parameter;
  final Map<int, double> draft;
  final Set<int> selection;
  final double zoomX;
  final ScrollController scrollController;
  final Color barColor;
  final Color dimColor;
  final Color guideColor;

  @override
  void paint(Canvas canvas, Size size) {
    final offset = scrollController.hasClients ? scrollController.offset : 0.0;
    final baseline = parameter.isBipolar ? size.height / 2 : size.height;
    canvas.drawLine(
      Offset(0, baseline - (parameter.isBipolar ? 0 : 0.5)),
      Offset(size.width, baseline - (parameter.isBipolar ? 0 : 0.5)),
      Paint()
        ..color = guideColor
        ..strokeWidth = 1,
    );

    final stem = Paint()..strokeWidth = 2;
    final head = Paint();
    for (final note in notes) {
      final x = note.startTick * zoomX - offset;
      if (x < -4 || x > size.width + 4) continue;
      final value = draft[note.id] ?? parameter.normalized(note);
      final y = (1 - value.clamp(0.0, 1.0)) * size.height;
      final active = selection.isEmpty || selection.contains(note.id);
      final color = active ? barColor : dimColor.withValues(alpha: 0.5);
      stem.color = color;
      head.color = color;
      canvas.drawLine(Offset(x, baseline), Offset(x, y), stem);
      canvas.drawCircle(Offset(x, y), 3.5, head);
    }
  }

  @override
  bool shouldRepaint(covariant _NoteParamLanePainter old) =>
      old.notes != notes ||
      old.parameter != parameter ||
      old.draft.length != draft.length ||
      !old.draft.entries.every((e) => draft[e.key] == e.value) ||
      old.selection != selection ||
      old.zoomX != zoomX ||
      old.scrollController != scrollController ||
      old.barColor != barColor;
}
