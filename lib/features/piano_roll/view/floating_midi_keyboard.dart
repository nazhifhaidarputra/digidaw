import 'dart:async';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/app/providers/notification_provider.dart';
import 'package:karbeat/app/providers/workspace_state.dart';
import 'package:karbeat/shared/models/piano_key.dart';
import 'package:karbeat/src/rust/api/project.dart';
import 'package:karbeat/src/rust/api/audio.dart' as audio_api;
import 'package:karbeat/core/utils/formatter.dart';
import 'package:karbeat/core/utils/logger.dart';
import 'package:karbeat/core/widgets/shortcut_focus_anchor.dart';

class FloatingMidiKeyboard extends ConsumerStatefulWidget {
  const FloatingMidiKeyboard({super.key});

  @override
  ConsumerState<FloatingMidiKeyboard> createState() =>
      _FloatingMidiKeyboardState();
}

class _FloatingMidiKeyboardState extends ConsumerState<FloatingMidiKeyboard> {
  double _x = 100;
  double _y = 100;

  final FocusNode _focusNode = FocusNode(debugLabel: 'Floating MIDI keyboard');
  final Set<int> _activeNotes = {};
  final Map<PhysicalKeyboardKey, ({int note, int? generatorId})>
  _keyboardNotes = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _releaseKeyboardNotes(updateState: false);
    _focusNode.dispose();
    super.dispose();
  }

  String _getGeneratorName(UiGeneratorInstance instance) {
    return instance.instanceType.when(
      plugin: (p) => p.name,
      sampler: (assetId, rootNote) => "Sampler",
    );
  }

  // Safe resolver that doesn't mutate state during build
  int? _resolveActiveGeneratorId(
    int? selectedGeneratorId,
    IMap<int, UiGeneratorInstance> generators,
  ) {
    int? genId = selectedGeneratorId;
    if (genId != null && !generators.containsKey(genId)) {
      genId = null;
    }
    if (genId == null && generators.isNotEmpty) {
      genId = generators.keys.first;
    }
    return genId;
  }

  KeyEventResult _handleKeyEvent(
    KeyEvent event, {
    required int baseKey,
    required int? generatorId,
  }) {
    if (event is KeyDownEvent) {
      final note = pianoNoteForKeyEvent(event, baseKey: baseKey);
      if (note == null) return KeyEventResult.ignored;

      if (!_keyboardNotes.containsKey(event.physicalKey)) {
        final soundingNote = _keyboardNotes.values
            .where((activeNote) => activeNote.note == note)
            .firstOrNull;
        _keyboardNotes[event.physicalKey] = (
          note: note,
          generatorId: soundingNote?.generatorId ?? generatorId,
        );
        if (soundingNote == null) _handleNoteOn(note, generatorId);
      }
      return KeyEventResult.handled;
    }

    if (event is KeyRepeatEvent) {
      return pianoNoteForKeyEvent(event, baseKey: baseKey) == null
          ? KeyEventResult.ignored
          : KeyEventResult.handled;
    }

    if (event is KeyUpEvent) {
      final activeNote = _keyboardNotes.remove(event.physicalKey);
      if (activeNote != null) {
        final isStillHeld = _keyboardNotes.values.any(
          (otherNote) => otherNote.note == activeNote.note,
        );
        if (!isStillHeld) {
          _handleNoteOff(activeNote.note, activeNote.generatorId);
        }
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  void _releaseKeyboardNotes({bool updateState = true}) {
    if (_keyboardNotes.isEmpty) return;

    final notes = <int, int?>{};
    for (final activeNote in _keyboardNotes.values) {
      notes.putIfAbsent(activeNote.note, () => activeNote.generatorId);
    }
    _keyboardNotes.clear();

    if (updateState && mounted) {
      setState(() => _activeNotes.removeAll(notes.keys));
    }
    for (final entry in notes.entries) {
      unawaited(_sendPreviewNote(entry.key, entry.value, isOn: false));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final workspaceState = ref.watch(workspaceStateProvider);
    final kState = workspaceState.floatingMidiKeyboardState;
    final workspaceNotifier = ref.read(workspaceStateProvider.notifier);

    // Safely unwrap the async project state
    final IMap<int, UiGeneratorInstance> generators = ref
        .watch(projectProvider)
        .maybeWhen(
          data: (project) => project.generators,
          orElse: () => const IMapConst<int, UiGeneratorInstance>({}),
        );

    final activeGeneratorId = _resolveActiveGeneratorId(
      kState.selectedGeneratorId,
      generators,
    );

    return Positioned(
      left: _x,
      top: _y,
      child: KeyboardFocusRegion(
        focusNode: _focusNode,
        onFocusChange: (hasFocus) {
          if (!hasFocus) _releaseKeyboardNotes();
        },
        onKeyEvent: (_, event) => _handleKeyEvent(
          event,
          baseKey: kState.baseKey,
          generatorId: activeGeneratorId,
        ),
        child: Material(
          color: Colors.transparent,
          elevation: 12,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 520,
            decoration: BoxDecoration(
              color: colors.surfaceContainer,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colors.outlineVariant),
              boxShadow: [
                BoxShadow(
                  color: colors.shadow.withValues(alpha: 0.55),
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Draggable Top Bar
                GestureDetector(
                  onPanUpdate: (details) {
                    setState(() {
                      _x += details.delta.dx;
                      _y += details.delta.dy;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHigh,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(8),
                      ),
                      border: Border(
                        bottom: BorderSide(color: colors.outlineVariant),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.drag_indicator,
                          color: colors.onSurfaceVariant,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "MIDI CONTROLLER",
                          style: TextStyle(
                            color: colors.onSurface,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                        const Spacer(),
                        Tooltip(
                          message:
                              "Octave ${kState.baseOctave} · "
                              "Key ${midiPitchClassName(kState.basePitchClass)}",
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colors.surfaceContainerLowest,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: colors.outlineVariant),
                            ),
                            child: Text(
                              kState.baseNoteLabel,
                              style: TextStyle(
                                color: colors.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () =>
                              workspaceNotifier.toggleFloatingMidiKeyboard(),
                          child: Icon(
                            Icons.close,
                            color: colors.onSurfaceVariant,
                            size: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Synth Control Panel
                Container(
                  padding: const EdgeInsets.all(12),
                  color: colors.surfaceContainerLow,
                  child: Row(
                    children: [
                      _buildStepControl(
                        "OCTAVE",
                        "${kState.baseOctave}",
                        () => workspaceNotifier.setMidiKeyboardOctave(
                          kState.baseOctave - 1,
                        ),
                        () => workspaceNotifier.setMidiKeyboardOctave(
                          kState.baseOctave + 1,
                        ),
                      ),
                      const SizedBox(width: 12),
                      _buildKeySelector(
                        kState.basePitchClass,
                        workspaceNotifier.setMidiKeyboardKey,
                      ),
                      const SizedBox(width: 12),
                      _buildStepControl(
                        "RANGE",
                        "${kState.keyRange}",
                        () => workspaceNotifier.setMidiKeyboardRange(
                          kState.keyRange - 1,
                        ),
                        () => workspaceNotifier.setMidiKeyboardRange(
                          kState.keyRange + 1,
                        ),
                      ),
                      const Spacer(),
                      SizedBox(
                        width: 168,
                        child: Container(
                          height: 36,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: colors.surfaceContainerLowest,
                            border: Border.all(color: colors.outlineVariant),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: activeGeneratorId,
                              isExpanded: true,
                              hint: Text(
                                "Select Synth",
                                style: TextStyle(
                                  color: colors.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                              dropdownColor: colors.surfaceContainerHigh,
                              icon: Icon(
                                Icons.arrow_drop_down,
                                color: colors.primary,
                              ),
                              style: TextStyle(
                                color: colors.primary,
                                fontSize: 12,
                              ),
                              onChanged: (val) {
                                workspaceNotifier.setMidiKeyboardGenerator(val);
                              },
                              items: generators.entries.map((e) {
                                return DropdownMenuItem(
                                  value: e.key,
                                  child: Text(
                                    _getGeneratorName(e.value),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Keyboard Area
                SizedBox(
                  height: 120,
                  child: _CustomVirtualKeyboard(
                    startNote: kState.baseKey,
                    totalKeys: kState.keyRange,
                    activeNotes: _activeNotes,
                    onNoteOn: (note) => _handleNoteOn(note, activeGeneratorId),
                    onNoteOff: (note) =>
                        _handleNoteOff(note, activeGeneratorId),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepControl(
    String label,
    String value,
    VoidCallback onDec,
    VoidCallback onInc,
  ) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: colors.onSurfaceVariant,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 32,
          child: Row(
            children: [
              InkWell(
                onTap: onDec,
                child: Icon(
                  Icons.remove_circle_outline,
                  color: colors.onSurfaceVariant,
                  size: 20,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 36,
                alignment: Alignment.center,
                child: Text(
                  value,
                  style: TextStyle(
                    color: colors.primary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: onInc,
                child: Icon(
                  Icons.add_circle_outline,
                  color: colors.onSurfaceVariant,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildKeySelector(int pitchClass, ValueChanged<int> onChanged) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(
          "KEY",
          style: TextStyle(
            color: colors.onSurfaceVariant,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: colors.surfaceContainerLowest,
            border: Border.all(color: colors.outlineVariant),
            borderRadius: BorderRadius.circular(4),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: pitchClass,
              isDense: true,
              dropdownColor: colors.surfaceContainerHigh,
              icon: Icon(
                Icons.arrow_drop_down,
                color: colors.primary,
                size: 18,
              ),
              style: TextStyle(
                color: colors.primary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              onChanged: (value) {
                if (value != null) onChanged(value);
              },
              items: [
                for (var pitch = 0; pitch < midiPitchClassNames.length; pitch++)
                  DropdownMenuItem<int>(
                    value: pitch,
                    child: Text(midiPitchClassNames[pitch]),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _handleNoteOn(int note, int? generatorId) {
    setState(() => _activeNotes.add(note));
    unawaited(_sendPreviewNote(note, generatorId, isOn: true));
  }

  void _handleNoteOff(int note, int? generatorId) {
    setState(() => _activeNotes.remove(note));
    unawaited(_sendPreviewNote(note, generatorId, isOn: false));
  }

  Future<void> _sendPreviewNote(
    int note,
    int? generatorId, {
    required bool isOn,
  }) async {
    if (generatorId == null) return;

    try {
      await audio_api.playPreviewNoteGenerator(
        ctx: ref.read(projectProvider.notifier).dawContext,
        generatorId: generatorId,
        noteKey: note,
        velocity: 100,
        isOn: isOn,
      );
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to ${isOn ? 'start' : 'stop'} MIDI preview note',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) {
        ref.read(notificationProvider.notifier).error(error);
      }
    }
  }
}

// ==== Custom Keyboard logic ====

class _CustomVirtualKeyboard extends StatelessWidget {
  final int startNote;
  final int totalKeys;
  final Set<int> activeNotes;
  final Function(int) onNoteOn;
  final Function(int) onNoteOff;

  const _CustomVirtualKeyboard({
    required this.startNote,
    required this.totalKeys,
    required this.activeNotes,
    required this.onNoteOn,
    required this.onNoteOff,
  });

  bool _isBlack(int note) {
    int n = note % 12;
    return n == 1 || n == 3 || n == 6 || n == 8 || n == 10;
  }

  /// The white key at or immediately below [note].
  ///
  /// Every black key has a white key right below it, so this walks back at
  /// most one semitone.
  int _whiteKeyAtOrBefore(int note) {
    var result = note;
    while (_isBlack(result) && result > 0) {
      result--;
    }
    return result;
  }

  /// The white key at or immediately above [note].
  int _whiteKeyAtOrAfter(int note) {
    var result = note;
    while (_isBlack(result) && result < 127) {
      result++;
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final lastNote = (startNote + totalKeys - 1).clamp(0, 127);

        // A piano is built from white keys: each black key sits in the gap
        // between the two white keys it belongs to. Striking a range that
        // starts or ends on a black key would leave that key without a gap,
        // so the drawn range is extended to the surrounding white keys.
        final firstDrawnNote = _whiteKeyAtOrBefore(startNote.clamp(0, 127));
        final lastDrawnNote = _whiteKeyAtOrAfter(lastNote);

        final whiteNotes = <int>[
          for (var note = firstDrawnNote; note <= lastDrawnNote; note++)
            if (!_isBlack(note)) note,
        ];
        if (whiteNotes.isEmpty) return const SizedBox.shrink();

        final whiteKeyWidth = constraints.maxWidth / whiteNotes.length;
        final blackKeyWidth = whiteKeyWidth * 0.62;
        final blackKeyHeight = constraints.maxHeight * 0.6;
        final whiteIndexByNote = <int, int>{
          for (var index = 0; index < whiteNotes.length; index++)
            whiteNotes[index]: index,
        };

        return Stack(
          children: [
            Row(
              children: [
                for (final note in whiteNotes)
                  _PianoKey(
                    note: note,
                    isBlack: false,
                    width: whiteKeyWidth,
                    height: constraints.maxHeight,
                    isPressed: activeNotes.contains(note),
                    onNoteOn: onNoteOn,
                    onNoteOff: onNoteOff,
                  ),
              ],
            ),
            for (var note = firstDrawnNote; note <= lastDrawnNote; note++)
              if (_isBlack(note))
                Positioned(
                  // Black keys are centred on the boundary of the white keys
                  // before and after them.
                  left:
                      (whiteIndexByNote[note - 1]! + 1) * whiteKeyWidth -
                      (blackKeyWidth / 2),
                  width: blackKeyWidth,
                  height: blackKeyHeight,
                  child: _PianoKey(
                    note: note,
                    isBlack: true,
                    width: blackKeyWidth,
                    height: blackKeyHeight,
                    isPressed: activeNotes.contains(note),
                    onNoteOn: onNoteOn,
                    onNoteOff: onNoteOff,
                  ),
                ),
          ],
        );
      },
    );
  }
}

class _PianoKey extends StatefulWidget {
  final int note;
  final bool isBlack;
  final bool isPressed;
  final double width;
  final double height;
  final Function(int) onNoteOn;
  final Function(int) onNoteOff;

  const _PianoKey({
    required this.note,
    required this.isBlack,
    required this.isPressed,
    required this.width,
    required this.height,
    required this.onNoteOn,
    required this.onNoteOff,
  });

  @override
  State<_PianoKey> createState() => _PianoKeyState();
}

class _PianoKeyState extends State<_PianoKey> {
  bool _touchActive = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isActive = widget.isPressed || _touchActive;

    return Listener(
      onPointerDown: (_) {
        Focus.of(context).requestFocus();
        setState(() => _touchActive = true);
        widget.onNoteOn(widget.note);
      },
      onPointerUp: (_) {
        setState(() => _touchActive = false);
        widget.onNoteOff(widget.note);
      },
      onPointerCancel: (_) {
        setState(() => _touchActive = false);
        widget.onNoteOff(widget.note);
      },
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: isActive
              ? colors.primary
              : (widget.isBlack ? Colors.black : Colors.white),
          border: Border.all(color: Colors.black, width: 1),
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(4),
          ),
          boxShadow: [
            if (!isActive && widget.isBlack)
              const BoxShadow(
                color: Colors.black54,
                offset: Offset(1, 1),
                blurRadius: 1,
              ),
          ],
        ),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6.0),
            child: Text(
              _getNoteLabel(widget.note),
              style: TextStyle(
                color: isActive
                    ? Colors.black
                    : (widget.isBlack ? Colors.white54 : Colors.grey.shade600),
                fontSize: 8,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _getNoteLabel(int note) {
    // Only show C notes label to reduce clutter unless it's the very first note
    if (note % 12 == 0) return numToMidiKey(note);
    return "";
  }
}
