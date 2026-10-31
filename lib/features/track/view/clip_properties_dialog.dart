import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/app/providers/track_list_state.dart';
import 'package:karbeat/app/providers/transport_state.dart';
import 'package:karbeat/app/providers/workspace_state.dart';
import 'package:karbeat/core/utils/clip_time_utils.dart';
import 'package:karbeat/core/widgets/rename_dialog.dart';
import 'package:karbeat/features/source/services/audio_waveform_services.dart';
import 'package:karbeat/features/track/services/curve_sampler.dart';
import 'package:karbeat/features/track/services/gain_envelope_evaluator.dart';
import 'package:karbeat/features/track/view/clip_curve_editor.dart';
import 'package:karbeat/features/track/view/gain_envelope_editor.dart';
import 'package:karbeat/features/track/view/waveform_painter.dart';
import 'package:karbeat/src/rust/api/automation.dart';
import 'package:karbeat/src/rust/api/project.dart';

/// Modulation that leaves a clip untouched. The loop time is what the engine
/// assumes for a clip that has never looped.
const UiClipModulation identityClipModulation = UiClipModulation(
  pan: [],
  pitch: [],
  looping: UiClipLoop(enabled: false, time: 12000, curve: []),
);

const int _ticksPerBeat = 960;

/// Largest pitch curve offset in cents, matching the engine's.
const double _maxPitchCents = 2400;

/// Shortest loop time in samples, matching the engine's.
const double _minLoopSamples = 64;

/// Note lengths offered for the loop time, longest first, in beats.
const List<(String, double)> _loopNoteValues = [
  ('1/1', 4),
  ('1/2', 2),
  ('1/4', 1),
  ('1/8', 0.5),
  ('1/16', 0.25),
  ('1/32', 0.125),
  ('1/64', 0.0625),
];

/// Shows a clip's details and, for an audio clip, its automation editor.
/// [onGoToParent] opens what the clip plays, after the dialog has closed.
Future<void> showClipPropertiesDialog(
  BuildContext context, {
  required int trackId,
  required int clipId,
  required VoidCallback onGoToParent,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final screen = MediaQuery.sizeOf(dialogContext);
      return Dialog(
        insetPadding: const EdgeInsets.all(24),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: math.min(960, screen.width - 48),
          height: math.min(680, screen.height - 48),
          child: _ClipProperties(
            trackId: trackId,
            clipId: clipId,
            onGoToParent: () {
              Navigator.of(dialogContext).pop();
              onGoToParent();
            },
          ),
        ),
      );
    },
  );
}

class _ClipProperties extends ConsumerWidget {
  const _ClipProperties({
    required this.trackId,
    required this.clipId,
    required this.onGoToParent,
  });

  final int trackId;
  final int clipId;
  final VoidCallback onGoToParent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clip = ref.watch(
      projectProvider.select(
        (s) => s.value?.tracks[trackId]?.clips
            .where((candidate) => candidate.id == clipId)
            .firstOrNull,
      ),
    );
    final transport = ref.watch(transportProvider).value;
    final bpm = transport?.state?.bpm;
    final sampleRate = transport?.sampleRate;
    if (clip == null || bpm == null || sampleRate == null) {
      return const Center(child: Text('This clip no longer exists.'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ClipInfoHeader(
          trackId: trackId,
          clip: clip,
          bpm: bpm,
          sampleRate: sampleRate,
          onGoToParent: onGoToParent,
        ),
        const Divider(height: 1),
        Expanded(
          child: switch (clip.source) {
            UiClipSource_Audio(:final sourceId) => _ClipAutomationSection(
              trackId: trackId,
              clip: clip,
              sourceId: sourceId,
              bpm: bpm,
              sampleRate: sampleRate,
            ),
            _ => const _NoClipAutomation(),
          },
        ),
      ],
    );
  }
}

/// Name, timing, and the shortcut to what the clip plays.
class _ClipInfoHeader extends ConsumerWidget {
  const _ClipInfoHeader({
    required this.trackId,
    required this.clip,
    required this.bpm,
    required this.sampleRate,
    required this.onGoToParent,
  });

  final int trackId;
  final UiClip clip;
  final double bpm;
  final int sampleRate;
  final VoidCallback onGoToParent;

  /// Musical position of a tick, as 1-based bar and beat in 4/4.
  String _position(int ticks) {
    final beats = ticks / _ticksPerBeat;
    final bar = beats ~/ 4 + 1;
    final beat = beats % 4 + 1;
    return '$bar.${beat.toStringAsFixed(2)}';
  }

  Future<void> _rename(BuildContext context, WidgetRef ref) async {
    final name = await showRenameDialog(
      context,
      title: 'Rename Clip',
      label: 'New clip name',
      currentName: clip.name,
    );
    if (name == null) return;
    await ref
        .read(trackListStateProvider.notifier)
        .renameClip(trackId, clip.id, name);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final lengthTicks = clip.loopLengthInTicks(bpm, sampleRate);
    final seconds = lengthTicks * samplesPerTick(bpm, sampleRate) / sampleRate;
    final isAudio = clip.source is UiClipSource_Audio;

    Widget info(String label, String value) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11),
        ),
        Text(value, style: TextStyle(color: colors.onSurface, fontSize: 13)),
      ],
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isAudio ? Icons.audio_file : Icons.piano,
                size: 20,
                color: colors.primary,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  clip.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Rename',
                visualDensity: VisualDensity.compact,
                onPressed: () => _rename(context, ref),
                icon: const Icon(Icons.edit, size: 16),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: onGoToParent,
                icon: Icon(isAudio ? Icons.tune : Icons.piano, size: 16),
                label: Text(
                  isAudio ? 'Go to Audio Properties' : 'Go to Piano Roll',
                ),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 28,
            runSpacing: 8,
            children: [
              info('Type', isAudio ? 'Audio clip' : 'MIDI clip'),
              info('Start (bar.beat)', _position(clip.startTimeInTicks)),
              info(
                'Length',
                '${(lengthTicks / _ticksPerBeat).toStringAsFixed(2)} beats · '
                    '${seconds.toStringAsFixed(2)} s',
              ),
              info(
                'Content offset',
                '${(clip.offsetStartInTicks(bpm, sampleRate) / _ticksPerBeat).toStringAsFixed(2)} beats',
              ),
              if (clip.modulation?.looping.enabled ?? false)
                info('Looping', 'On'),
            ],
          ),
        ],
      ),
    );
  }
}

class _NoClipAutomation extends StatelessWidget {
  const _NoClipAutomation();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Volume, pan, pitch, and loop automation apply to audio clips. A MIDI '
          "clip plays through its track's instrument, so automate that with a "
          'track automation lane.',
          textAlign: TextAlign.center,
          style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
        ),
      ),
    );
  }
}

enum _ClipParameter {
  volume('Volume', Icons.volume_up),
  pan('Pan', Icons.swap_horiz),
  pitch('Pitch', Icons.graphic_eq),
  loop('Loop', Icons.loop);

  const _ClipParameter(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// The clip's automation editor: one parameter at a time, drawn over the clip's
/// waveform, with one-click shapes for the common moves.
class _ClipAutomationSection extends ConsumerStatefulWidget {
  const _ClipAutomationSection({
    required this.trackId,
    required this.clip,
    required this.sourceId,
    required this.bpm,
    required this.sampleRate,
  });

  final int trackId;
  final UiClip clip;
  final int sourceId;
  final double bpm;
  final int sampleRate;

  @override
  ConsumerState<_ClipAutomationSection> createState() =>
      _ClipAutomationSectionState();
}

class _ClipAutomationSectionState
    extends ConsumerState<_ClipAutomationSection> {
  _ClipParameter _parameter = _ClipParameter.volume;

  UiClip get _clip => widget.clip;
  UiClipModulation get _modulation =>
      _clip.modulation ?? identityClipModulation;
  int get _contentStart => _clip.offsetStart;
  int get _contentLength => _clip.loopLength;

  double get _samplesPerBeat =>
      samplesPerTick(widget.bpm, widget.sampleRate) * _ticksPerBeat;

  Future<void> _commit(UiClipModulation modulation) => ref
      .read(trackListStateProvider.notifier)
      .setClipModulation(
        trackId: widget.trackId,
        clipId: _clip.id,
        modulation: modulation,
      );

  Future<void> _commitEnvelope(UiGainEnvelope envelope) => ref
      .read(trackListStateProvider.notifier)
      .setClipEnvelope(
        trackId: widget.trackId,
        clipId: _clip.id,
        envelope: envelope,
      );

  bool _isAutomated(_ClipParameter parameter) => switch (parameter) {
    _ClipParameter.volume => !isIdentityEnvelope(
      _clip.envelope ?? identityEnvelope,
    ),
    _ClipParameter.pan => _modulation.pan.isNotEmpty,
    _ClipParameter.pitch => _modulation.pitch.isNotEmpty,
    _ClipParameter.loop => _modulation.looping.enabled,
  };

  /// Moves a content position onto the project grid, measured from the clip's
  /// start, when snapping is on.
  int _snapPosition(int position) {
    final workspace = ref.read(workspaceStateProvider);
    if (!workspace.snapToGrid || workspace.gridSize.value <= 0) return position;
    final step =
        (_ticksPerBeat * 4 / workspace.gridSize.value) *
        samplesPerTick(widget.bpm, widget.sampleRate);
    if (step <= 0) return position;
    final elapsed = position - _contentStart;
    return _contentStart + ((elapsed / step).round() * step).round();
  }

  /// A curve of [points] at shares of the clip's length, so a shape fits the
  /// clip whatever its length.
  List<UiCurvePoint> _shape(
    List<(double, double)> points, {
    AutomationCurveTypeDto curveType = AutomationCurveTypeDto.linear,
  }) => [
    for (final (share, value) in points)
      UiCurvePoint(
        position: _contentStart + (share * _contentLength).round(),
        value: value,
        curveType: curveType,
        tension: 0,
      ),
  ];

  ClipCurveScale _panScale(ColorScheme colors) => ClipCurveScale(
    curve: UiClipCurve.pan,
    color: colors.tertiary,
    toFraction: (value) => (value + 1) / 2,
    fromFraction: (fraction) => fraction * 2 - 1,
    format: (value) {
      final percent = (value.abs() * 100).round();
      if (percent == 0) return 'Center';
      return '$percent ${value < 0 ? 'L' : 'R'}';
    },
    parse: (text) {
      final value = double.tryParse(text.trim());
      return value == null ? null : (value / 100).clamp(-1.0, 1.0);
    },
    snap: (value) => (value * 20).round() / 20,
    gridLines: const [
      ClipCurveGridLine(1, 'R'),
      ClipCurveGridLine(0, 'C', major: true),
      ClipCurveGridLine(-1, 'L'),
    ],
    valueHint: 'Pan, -100 (left) to 100 (right)',
  );

  ClipCurveScale _pitchScale(ColorScheme colors) => ClipCurveScale(
    curve: UiClipCurve.pitch,
    color: colors.secondary,
    toFraction: (value) => (value + _maxPitchCents) / (2 * _maxPitchCents),
    fromFraction: (fraction) => fraction * 2 * _maxPitchCents - _maxPitchCents,
    format: (value) {
      final semitones = value / 100;
      final sign = semitones > 0 ? '+' : '';
      return '$sign${semitones.toStringAsFixed(semitones % 1 == 0 ? 0 : 2)} st';
    },
    parse: (text) {
      final value = double.tryParse(text.trim());
      return value == null
          ? null
          : (value * 100).clamp(-_maxPitchCents, _maxPitchCents);
    },
    snap: (value) => (value / 100).round() * 100.0,
    gridLines: const [
      ClipCurveGridLine(2400, '+24'),
      ClipCurveGridLine(1200, '+12'),
      ClipCurveGridLine(0, '0', major: true),
      ClipCurveGridLine(-1200, '-12'),
      ClipCurveGridLine(-2400, '-24'),
    ],
    valueHint: 'Pitch in semitones',
  );

  /// Loop times in octaves, so every halving is the same height. Long repeats
  /// are at the top, so a falling line sounds like it is speeding up.
  ClipCurveScale _loopScale(ColorScheme colors) {
    final top = _samplesPerBeat * 4;
    final bottom = math.min(_samplesPerBeat / 32, top / 2);
    final low = math.log(math.max(bottom, _minLoopSamples)) / math.ln2;
    final high = math.log(top) / math.ln2;
    double snap(double samples) {
      final beats = samples / _samplesPerBeat;
      final nearest = _loopNoteValues
          .map((note) => note.$2)
          .reduce(
            (a, b) => (math.log(a / beats)).abs() < (math.log(b / beats)).abs()
                ? a
                : b,
          );
      return math.max(nearest * _samplesPerBeat, _minLoopSamples);
    }

    return ClipCurveScale(
      curve: UiClipCurve.loopTime,
      color: colors.primary,
      toFraction: (value) =>
          ((math.log(math.max(value, 1)) / math.ln2 - low) / (high - low))
              .clamp(0.0, 1.0),
      fromFraction: (fraction) =>
          math.pow(2, low + fraction * (high - low)).toDouble(),
      format: _formatLoopTime,
      parse: (text) {
        final milliseconds = double.tryParse(text.trim());
        if (milliseconds == null) return null;
        return math.max(
          milliseconds / 1000 * widget.sampleRate,
          _minLoopSamples,
        );
      },
      snap: snap,
      gridLines: [
        for (final (label, beats) in _loopNoteValues)
          if (beats * _samplesPerBeat >= bottom)
            ClipCurveGridLine(beats * _samplesPerBeat, label),
      ],
      valueHint: 'Loop time in milliseconds',
    );
  }

  /// Loop time as milliseconds, with its note length when it is one.
  String _formatLoopTime(double samples) {
    final milliseconds = samples / widget.sampleRate * 1000;
    final text = '${milliseconds.toStringAsFixed(1)} ms';
    final note = _noteFor(samples);
    return note == null ? text : '$text ($note)';
  }

  String? _noteFor(double samples) {
    for (final (label, beats) in _loopNoteValues) {
      if ((beats * _samplesPerBeat - samples).abs() < 2) return label;
    }
    return null;
  }

  Future<void> _setLoopTime(int samples) => _commit(
    _modulation.copyWith(looping: _modulation.looping.copyWith(time: samples)),
  );

  Future<void> _typeLoopTime() async {
    final controller = TextEditingController(
      text: (_modulation.looping.time / widget.sampleRate * 1000)
          .toStringAsFixed(1),
    );
    final text = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Loop time'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Milliseconds',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) => Navigator.pop(dialogContext, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Set'),
          ),
        ],
      ),
    );
    controller.dispose();
    final milliseconds = double.tryParse(text?.trim() ?? '');
    if (milliseconds == null || milliseconds <= 0) return;
    await _setLoopTime(
      math
          .max(milliseconds / 1000 * widget.sampleRate, _minLoopSamples)
          .round(),
    );
  }

  /// Turning a never-used loop on starts at an eighth note, not the engine's
  /// neutral time, which means nothing musically.
  Future<void> _setLoopEnabled(bool enabled) {
    final looping = _modulation.looping;
    final fresh = _clip.modulation == null || looping.time == 12000;
    return _commit(
      _modulation.copyWith(
        looping: looping.copyWith(
          enabled: enabled,
          time: enabled && fresh ? (_samplesPerBeat / 2).round() : looping.time,
        ),
      ),
    );
  }

  /// A stutter that halves its loop time at even steps across the clip.
  Future<void> _applyLoopShape(List<UiCurvePoint> curve) => _commit(
    _modulation.copyWith(
      looping: _modulation.looping.copyWith(enabled: true, curve: curve),
    ),
  );

  Widget _chip(String label, IconData icon, VoidCallback onPressed) =>
      ActionChip(
        avatar: Icon(icon, size: 14),
        label: Text(label, style: const TextStyle(fontSize: 11)),
        visualDensity: VisualDensity.compact,
        onPressed: onPressed,
      );

  /// One-click shapes and the way back to no automation, for this parameter.
  List<Widget> _shapeActions() {
    final beat = _samplesPerBeat;
    return switch (_parameter) {
      _ClipParameter.volume => [
        _chip('Clear', Icons.delete_outline, () {
          _commitEnvelope(identityEnvelope);
        }),
      ],
      _ClipParameter.pan => [
        _chip('Left to right', Icons.east, () {
          _commit(_modulation.copyWith(pan: _shape([(0, -1), (1, 1)])));
        }),
        _chip('Right to left', Icons.west, () {
          _commit(_modulation.copyWith(pan: _shape([(0, 1), (1, -1)])));
        }),
        _chip('Clear', Icons.delete_outline, () {
          _commit(_modulation.copyWith(pan: const []));
        }),
      ],
      _ClipParameter.pitch => [
        _chip('Rise an octave', Icons.north_east, () {
          _commit(_modulation.copyWith(pitch: _shape([(0, 0), (1, 1200)])));
        }),
        _chip('Fall an octave', Icons.south_east, () {
          _commit(_modulation.copyWith(pitch: _shape([(0, 0), (1, -1200)])));
        }),
        _chip('Clear', Icons.delete_outline, () {
          _commit(_modulation.copyWith(pitch: const []));
        }),
      ],
      _ClipParameter.loop => [
        _chip('Stutter roll', Icons.fast_forward, () {
          _applyLoopShape(
            _shape([
              (0, beat),
              (0.5, beat / 2),
              (0.75, beat / 4),
              (0.875, beat / 8),
            ], curveType: AutomationCurveTypeDto.step),
          );
        }),
        _chip('Smooth speed-up', Icons.trending_down, () {
          _applyLoopShape(_shape([(0, beat), (1, beat / 16)]));
        }),
        _chip('Slow down', Icons.trending_up, () {
          _applyLoopShape(_shape([(0, beat / 16), (1, beat)]));
        }),
        _chip('Clear curve', Icons.delete_outline, () {
          _commit(
            _modulation.copyWith(
              looping: _modulation.looping.copyWith(curve: const []),
            ),
          );
        }),
      ],
    };
  }

  Widget _buildLoopControls(ColorScheme colors) {
    final looping = _modulation.looping;
    final curveDrives = looping.curve.isNotEmpty;
    final note = _noteFor(looping.time.toDouble());
    return Row(
      children: [
        Switch(
          value: looping.enabled,
          onChanged: (value) => _setLoopEnabled(value),
        ),
        const SizedBox(width: 4),
        Text(
          'Loop this clip',
          style: TextStyle(color: colors.onSurface, fontSize: 13),
        ),
        const SizedBox(width: 20),
        Text(
          'Loop time',
          style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
        ),
        const SizedBox(width: 8),
        if (curveDrives)
          Text(
            'Follows the curve',
            style: TextStyle(color: colors.primary, fontSize: 12),
          )
        else ...[
          DropdownButton<String>(
            value: note ?? 'custom',
            underline: const SizedBox(),
            style: TextStyle(color: colors.onSurface, fontSize: 12),
            dropdownColor: colors.surfaceContainerHigh,
            onChanged: looping.enabled
                ? (value) {
                    if (value == 'custom') {
                      _typeLoopTime();
                      return;
                    }
                    for (final (label, beats) in _loopNoteValues) {
                      if (label == value) {
                        _setLoopTime((beats * _samplesPerBeat).round());
                      }
                    }
                  }
                : null,
            items: [
              for (final (label, _) in _loopNoteValues)
                DropdownMenuItem(value: label, child: Text(label)),
              const DropdownMenuItem(value: 'custom', child: Text('Custom...')),
            ],
          ),
          const SizedBox(width: 8),
          Text(
            '${(looping.time / widget.sampleRate * 1000).toStringAsFixed(1)} ms',
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
          ),
        ],
      ],
    );
  }

  String get _hint => switch (_parameter) {
    _ClipParameter.volume =>
      'Double-click to add a point. Drag the top corners for fades, and a ring '
          'between two points to bend that segment. Right-click a point for its '
          'curve.',
    _ClipParameter.loop =>
      'Each repeat lasts the loop time where it starts, so a falling line '
          'speeds up the stutter. Drag a ring to bend a segment. Shift-drag '
          'moves a point freely off the note values.',
    _ =>
      'Double-click to add a point, double-click a point to delete it. Drag a '
          'ring to bend a segment, double-click it to straighten. Right-click a '
          'point for its value and curve. Shift-drag moves a point freely.',
  };

  Widget _buildEditor(ColorScheme colors) {
    final modulation = _modulation;
    return switch (_parameter) {
      _ClipParameter.volume => LayoutBuilder(
        builder: (context, constraints) => GainEnvelopeEditor(
          envelope: _clip.envelope ?? identityEnvelope,
          axis: EnvelopeAxis(
            pixelsPerSample: constraints.maxWidth / math.max(_contentLength, 1),
            originPosition: _contentStart.toDouble(),
          ),
          contentStart: _contentStart,
          contentLength: _contentLength,
          maxCrossfade: _contentLength,
          color: colors.primary,
          onCommit: _commitEnvelope,
        ),
      ),
      _ClipParameter.pan => ClipCurveEditor(
        key: const ValueKey('clip-curve-pan'),
        points: modulation.pan,
        scale: _panScale(colors),
        withPoints: (points) => modulation.copyWith(pan: points),
        contentStart: _contentStart,
        contentLength: _contentLength,
        snapPosition: _snapPosition,
        onCommit: (points) => _commit(modulation.copyWith(pan: points)),
      ),
      _ClipParameter.pitch => ClipCurveEditor(
        key: const ValueKey('clip-curve-pitch'),
        points: modulation.pitch,
        scale: _pitchScale(colors),
        withPoints: (points) => modulation.copyWith(pitch: points),
        contentStart: _contentStart,
        contentLength: _contentLength,
        snapPosition: _snapPosition,
        onCommit: (points) => _commit(modulation.copyWith(pitch: points)),
      ),
      _ClipParameter.loop => ClipCurveEditor(
        key: const ValueKey('clip-curve-loop'),
        points: modulation.looping.curve,
        scale: _loopScale(colors),
        withPoints: (points) => modulation.copyWith(
          looping: modulation.looping.copyWith(curve: points),
        ),
        contentStart: _contentStart,
        contentLength: _contentLength,
        snapPosition: _snapPosition,
        markers: modulation.looping.enabled
            ? ref
                  .read(curveSamplerProvider)
                  .loopStarts(
                    modulation,
                    offsetStart: _contentStart,
                    loopLength: _contentLength,
                    limit: 2000,
                  )
            : const [],
        onCommit: (points) => _commit(
          modulation.copyWith(
            looping: modulation.looping.copyWith(curve: points),
          ),
        ),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SegmentedButton<_ClipParameter>(
                showSelectedIcon: false,
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                segments: [
                  for (final parameter in _ClipParameter.values)
                    ButtonSegment(
                      value: parameter,
                      icon: Icon(parameter.icon, size: 16),
                      label: Text(
                        // A dot marks the parameters already shaping the clip.
                        _isAutomated(parameter)
                            ? '${parameter.label} •'
                            : parameter.label,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                ],
                selected: {_parameter},
                onSelectionChanged: (selection) =>
                    setState(() => _parameter = selection.first),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 6,
                  runSpacing: 4,
                  children: _shapeActions(),
                ),
              ),
            ],
          ),
          if (_parameter == _ClipParameter.loop) ...[
            const SizedBox(height: 8),
            _buildLoopControls(colors),
          ],
          const SizedBox(height: 8),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surfaceContainerLowest,
                border: Border.all(color: colors.outlineVariant),
                borderRadius: BorderRadius.circular(6),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: _ClipWaveformBackdrop(
                        clip: _clip,
                        sourceId: widget.sourceId,
                        bpm: widget.bpm,
                        sampleRate: widget.sampleRate,
                      ),
                    ),
                    Positioned.fill(child: _buildEditor(colors)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _hint,
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

/// The audio the clip plays, faint behind the curve.
class _ClipWaveformBackdrop extends ConsumerWidget {
  const _ClipWaveformBackdrop({
    required this.clip,
    required this.sourceId,
    required this.bpm,
    required this.sampleRate,
  });

  final UiClip clip;
  final int sourceId;
  final double bpm;
  final int sampleRate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final handle = ref.watch(audioWaveformHandleProvider(sourceId));
    if (handle == null) return const SizedBox.shrink();
    final channels = handle.getChannels();
    final samples = createPlayableWaveformView(handle);
    if (channels != 2 || samples.isEmpty || sampleRate <= 0) {
      return const SizedBox.shrink();
    }
    // Clip content counts project samples; the source reads at its own rate.
    final framesPerSample =
        handle.getSampleRate() / sampleRate * handle.tempoRate(projectBpm: bpm);
    final total = samples.length ~/ 2;
    final first = (clip.offsetStart * framesPerSample).floor().clamp(0, total);
    final last = ((clip.offsetStart + clip.loopLength) * framesPerSample)
        .ceil()
        .clamp(first, total);
    return CustomPaint(
      painter: StereoWaveformPainter(
        samples: Float32List.sublistView(samples, first * 2, last * 2),
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.25),
      ),
    );
  }
}
