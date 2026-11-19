import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/app/providers/track_list_state.dart';
import 'package:karbeat/core/l10n/localizer.dart';
import 'package:karbeat/src/rust/api/jobs.dart';
import 'package:karbeat/src/rust/api/audio_analysis.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/app/providers/notification_provider.dart';
import 'package:karbeat/app/providers/background_jobs_provider.dart';
import 'package:karbeat/core/widgets/digidaw_plugin_widgets/parameter_knob.dart';
import 'package:karbeat/features/source/services/audio_source_import.dart';
import 'package:karbeat/features/source/services/audio_waveform_services.dart';
import 'package:karbeat/features/track/services/gain_envelope_evaluator.dart';
import 'package:karbeat/features/track/view/gain_envelope_editor.dart';
import 'package:karbeat/features/track/view/waveform_painter.dart';
import 'package:karbeat/src/rust/api/audio.dart';
import 'package:karbeat/src/rust/api/project.dart';

class AudioPropertiesScreen extends ConsumerWidget {
  final int sourceId;
  final String sourceName;

  const AudioPropertiesScreen({
    super.key,
    required this.sourceId,
    required this.sourceName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final propsAsync = ref.watch(audioPropertiesProvider(sourceId));

    final ctx = ref.read(projectProvider.notifier).dawContext;

    return Scaffold(
      appBar: AppBar(
        title: Text(sourceName),
        actions: [
          IconButton(
            tooltip: tr('source-replace-audio'),
            onPressed: () =>
                replaceAudioSourceWithPicker(context, ref, sourceId),
            icon: const Icon(Icons.swap_horiz),
          ),
        ],
      ),
      body: propsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),

        error: (err, _) => Center(
          child: Text(
            tr('source-error', {'error': err}),
            style: TextStyle(color: colors.error),
          ),
        ),

        data: (props) {
          final handle = props.id != null
              ? ref.watch(audioWaveformHandleProvider(props.id!))
              : null;
          final envelope =
              ref.watch(
                projectProvider.select(
                  (s) => s.value?.sourceEnvelopes[sourceId],
                ),
              ) ??
              identityEnvelope;
          return Column(
            children: [
              // HEADER
              _buildInfoSection(context, props),

              Divider(color: colors.outlineVariant),

              // WAVEFORM
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerLowest,
                      border: Border.all(color: colors.outlineVariant),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: CustomPaint(
                              painter: StereoWaveformPainter(
                                samples: handle != null
                                    ? createZeroCopyWaveformView(handle)
                                    : Float32List(0),
                                color: colors.primary,
                              ),
                            ),
                          ),
                          Positioned.fill(
                            child: _TrimmedWaveformOverlay(
                              sourceId: sourceId,
                              props: props,
                              envelope: envelope,
                              frames: handle == null
                                  ? 0
                                  : handle.getLen() ~/
                                        (handle.getChannels() == 0
                                            ? 1
                                            : handle.getChannels()),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              _EnvelopeReadout(
                envelope: envelope,
                sampleRate: props.sampleRate,
              ),

              _TrimControls(sourceId: sourceId, props: props),

              _OfflineEditControls(sourceId: sourceId, props: props),

              _TempoControls(sourceId: sourceId, props: props),

              // CONTROLS
              Container(
                padding: const EdgeInsets.all(24),
                color: colors.surfaceContainerLow,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FloatingActionButton.extended(
                      heroTag: 'play_source_fab',
                      onPressed: () {
                        playSourcePreview(ctx: ctx, id: sourceId);
                      },
                      icon: const Icon(Icons.play_arrow),
                      label: Text(tr('source-preview')),
                      backgroundColor: colors.primaryContainer,
                      foregroundColor: colors.onPrimaryContainer,
                    ),
                    const SizedBox(width: 10),
                    FloatingActionButton.extended(
                      heroTag: 'stop_source_fab',
                      onPressed: () {
                        stopAllPreviews(ctx: ctx);
                      },
                      label: Text(tr('source-stop')),
                      icon: const Icon(Icons.stop),
                      backgroundColor: colors.errorContainer,
                      foregroundColor: colors.onErrorContainer,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInfoSection(
    BuildContext context,
    AudioWaveformUiForAudioProperties props,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          _row(
            context,
            tr('workspace-export-format'),
            tr('source-format-value', {
              'rate': props.sampleRate,
              'channels': props.channels,
            }),
          ),
          _row(
            context,
            tr('source-duration'),
            tr('source-duration-value', {
              'seconds': props.duration.toStringAsFixed(2),
            }),
          ),
          _row(context, tr('source-path'), props.filePath, isSmall: true),
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context,
    String label,
    String value, {
    bool isSmall = false,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: colors.onSurfaceVariant)),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                color: colors.onSurface,
                fontSize: isSmall ? 10 : 14,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Stores new trim points, in frames of the original audio, and refreshes what
/// shows the source. An end at the last frame plays to the end, like zero.
Future<void> _commitTrim(
  WidgetRef ref,
  int sourceId,
  int originalFrames,
  int start,
  int end,
) async {
  await ref
      .read(projectProvider.notifier)
      .setSourceTrim(sourceId, start, end >= originalFrames ? 0 : end);
  if (!ref.context.mounted) return;
  ref.invalidate(audioPropertiesProvider(sourceId));
  ref.invalidate(audioWaveformHandleProvider(sourceId));
  ref.invalidate(trackWaveformProvider);
}

/// Shades what the trim points cut off, and holds the grips that move them and
/// the envelope editor over the part that plays.
class _TrimmedWaveformOverlay extends ConsumerStatefulWidget {
  const _TrimmedWaveformOverlay({
    required this.sourceId,
    required this.props,
    required this.envelope,
    required this.frames,
  });

  final int sourceId;
  final AudioWaveformUiForAudioProperties props;
  final UiGainEnvelope envelope;

  /// Frames of the shown buffer; a render can differ from the original audio.
  final int frames;

  @override
  ConsumerState<_TrimmedWaveformOverlay> createState() =>
      _TrimmedWaveformOverlayState();
}

class _TrimmedWaveformOverlayState
    extends ConsumerState<_TrimmedWaveformOverlay> {
  static const double _gripWidth = 14;
  static const double _gripHeight = 44;

  /// Trim points being dragged, as shares of the audio's length.
  (double, double)? _draft;

  int get _total => widget.props.originalFrames;

  (double, double) get _shares {
    final draft = _draft;
    if (draft != null) return draft;
    if (_total <= 0) return (0, 1);
    final end = widget.props.trimEnd == 0 ? _total : widget.props.trimEnd;
    return (widget.props.trimStart / _total, end / _total);
  }

  void _moveGrip({
    required bool start,
    required double dx,
    required double width,
  }) {
    final (from, to) = _shares;
    final minShare = _total <= 0 ? 0.0 : 1 / _total;
    setState(() {
      _draft = start
          ? ((from + dx / width).clamp(0.0, to - minShare), to)
          : (from, (to + dx / width).clamp(from + minShare, 1.0));
    });
  }

  Future<void> _commitDrag() async {
    final (from, to) = _shares;
    await _commitTrim(
      ref,
      widget.sourceId,
      _total,
      (from * _total).round(),
      (to * _total).round(),
    );
    if (mounted) setState(() => _draft = null);
  }

  Widget _grip({
    required bool start,
    required double x,
    required double width,
    required double height,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Positioned(
      // The envelope editor leaves the stack while a grip drags. Without a key
      // the grips would swap elements, and the drag would move the other point.
      key: ValueKey(start ? 'trim-start-grip' : 'trim-end-grip'),
      left: start ? x : x - _gripWidth,
      top: (height - _gripHeight) / 2,
      width: _gripWidth,
      height: _gripHeight,
      child: Tooltip(
        message: start ? tr('source-trim-start') : tr('source-trim-end'),
        child: MouseRegion(
          cursor: SystemMouseCursors.resizeLeftRight,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragUpdate: (details) =>
                _moveGrip(start: start, dx: details.delta.dx, width: width),
            onHorizontalDragEnd: (_) => _commitDrag(),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.secondary,
                borderRadius: BorderRadius.horizontal(
                  left: start ? Radius.zero : const Radius.circular(4),
                  right: start ? const Radius.circular(4) : Radius.zero,
                ),
              ),
              child: Icon(
                Icons.drag_indicator,
                size: 12,
                color: colors.onSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (from, to) = _shares;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final left = from * width;
        final right = to * width;
        final shade = colors.surfaceContainerLowest.withValues(alpha: 0.75);
        final playedFrames = ((to - from) * widget.frames).round();
        return Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: left,
              child: ColoredBox(color: shade),
            ),
            Positioned(
              left: right,
              top: 0,
              bottom: 0,
              right: 0,
              child: ColoredBox(color: shade),
            ),
            // The envelope belongs to the part that plays. Its layout waits
            // for a drag to end, when the points have moved with the trim.
            if (_draft == null)
              Positioned(
                left: left,
                top: 0,
                bottom: 0,
                width: right - left,
                child: _WaveformEnvelopeEditor(
                  sourceId: widget.sourceId,
                  envelope: widget.envelope,
                  frames: playedFrames,
                ),
              ),
            if (_total > 0) ...[
              _grip(start: true, x: left, width: width, height: height),
              _grip(start: false, x: right, width: width, height: height),
            ],
          ],
        );
      },
    );
  }
}

/// Trim points as exact times, for when dragging is not precise enough.
class _TrimControls extends ConsumerWidget {
  const _TrimControls({required this.sourceId, required this.props});

  final int sourceId;
  final AudioWaveformUiForAudioProperties props;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final total = props.originalFrames;
    final rate = props.sampleRate;
    final end = props.trimEnd == 0 ? total : props.trimEnd;
    final trimmed = props.trimStart > 0 || end < total;
    if (total <= 0 || rate <= 0) return const SizedBox.shrink();

    int? toFrames(String text) {
      final seconds = double.tryParse(text.trim());
      return seconds == null ? null : (seconds * rate).round();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Icon(Icons.content_cut, size: 16, color: colors.onSurfaceVariant),
          _TrimTimeField(
            key: ValueKey(('trim-start', props.trimStart)),
            label: tr('source-trim-start-s'),
            seconds: props.trimStart / rate,
            onSubmitted: (text) {
              final frames = toFrames(text);
              if (frames == null) return;
              _commitTrim(ref, sourceId, total, frames.clamp(0, end - 1), end);
            },
          ),
          _TrimTimeField(
            key: ValueKey(('trim-end', end)),
            label: tr('source-trim-end-s'),
            seconds: end / rate,
            onSubmitted: (text) {
              final frames = toFrames(text);
              if (frames == null) return;
              _commitTrim(
                ref,
                sourceId,
                total,
                props.trimStart,
                frames.clamp(props.trimStart + 1, total),
              );
            },
          ),
          Text(
            tr('source-plays-seconds', {
              'seconds': ((end - props.trimStart) / rate).toStringAsFixed(3),
            }),
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
          ),
          if (trimmed)
            TextButton.icon(
              onPressed: () => _commitTrim(ref, sourceId, total, 0, total),
              icon: const Icon(Icons.restart_alt, size: 16),
              label: Text(tr('source-reset-trim')),
            ),
        ],
      ),
    );
  }
}

/// A trim time in seconds that commits when submitted or when focus leaves it.
class _TrimTimeField extends StatefulWidget {
  const _TrimTimeField({
    super.key,
    required this.label,
    required this.seconds,
    required this.onSubmitted,
  });

  final String label;
  final double seconds;
  final ValueChanged<String> onSubmitted;

  @override
  State<_TrimTimeField> createState() => _TrimTimeFieldState();
}

class _TrimTimeFieldState extends State<_TrimTimeField> {
  late final TextEditingController _controller = TextEditingController(
    text: _shown,
  );
  final FocusNode _focusNode = FocusNode();

  String get _shown => widget.seconds.toStringAsFixed(3);

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus && _controller.text != _shown) {
        widget.onSubmitted(_controller.text);
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: const TextStyle(fontSize: 12),
        decoration: InputDecoration(
          labelText: widget.label,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
        onSubmitted: (text) {
          if (text != _shown) widget.onSubmitted(text);
        },
      ),
    );
  }
}

/// Edits the waveform envelope shared by every clip of the source; the
/// envelope's positions are frames from the trim start, spread across the
/// part of the waveform that plays.
class _WaveformEnvelopeEditor extends ConsumerWidget {
  const _WaveformEnvelopeEditor({
    required this.sourceId,
    required this.envelope,
    required this.frames,
  });

  final int sourceId;
  final UiGainEnvelope envelope;
  final int frames;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (frames <= 0) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) => GainEnvelopeEditor(
        envelope: envelope,
        axis: EnvelopeAxis(
          pixelsPerSample: constraints.maxWidth / frames,
          originPosition: 0,
        ),
        contentStart: 0,
        contentLength: frames,
        maxCrossfade: frames ~/ 2,
        color: Colors.amber,
        canAddPoints: false,
        onCommit: (next) => ref
            .read(projectProvider.notifier)
            .setSourceEnvelope(sourceId, next),
      ),
    );
  }
}

/// ADSR stages, loop crossfade, and point count of the waveform envelope.
class _EnvelopeReadout extends StatelessWidget {
  const _EnvelopeReadout({required this.envelope, required this.sampleRate});

  final UiGainEnvelope envelope;
  final int sampleRate;

  String _ms(int samples) => sampleRate > 0
      ? '${(samples * 1000 / sampleRate).toStringAsFixed(0)} ms'
      : '$samples smp';

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final style = TextStyle(color: colors.onSurfaceVariant, fontSize: 12);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 16,
        children: [
          Text(
            tr('source-attack', {'time': _ms(envelope.fadeIn.length)}),
            style: style,
          ),
          Text(
            tr('source-decay', {'time': _ms(envelope.decay.length)}),
            style: style,
          ),
          Text(
            tr('source-sustain', {'sustain': (envelope.sustain * 100).round()}),
            style: style,
          ),
          Text(
            tr('source-release', {'time': _ms(envelope.fadeOut.length)}),
            style: style,
          ),
          Text(
            tr('source-loop-crossfade', {'time': _ms(envelope.crossfade)}),
            style: style,
          ),
          if (envelope.points.isNotEmpty)
            Text(
              tr('source-points', {'count': envelope.points.length}),
              style: style,
            ),
        ],
      ),
    );
  }
}

/// Sample mode and edits. Edits render in the background and the original
/// audio plays until the render is ready, except pitch and tempo in realtime
/// mode, which play through a realtime stretcher at once.
class _OfflineEditControls extends ConsumerWidget {
  const _OfflineEditControls({required this.sourceId, required this.props});

  final int sourceId;
  final AudioWaveformUiForAudioProperties props;

  String _modeLabel(UiAudioSampleMode mode) => switch (mode) {
    UiAudioSampleMode.default_ => tr('common-default'),
    UiAudioSampleMode.resampled => tr('source-mode-resampled'),
    UiAudioSampleMode.stretch => tr('source-mode-stretch'),
  };

  String _modeHint(UiAudioSampleMode mode) => switch (mode) {
    UiAudioSampleMode.default_ => tr('source-mode-default-hint'),
    UiAudioSampleMode.resampled => tr('source-mode-resampled-hint'),
    UiAudioSampleMode.stretch => tr('source-mode-stretch-hint'),
  };

  Future<void> _apply(
    WidgetRef ref,
    Future<void> Function(DawContext ctx) change,
  ) async {
    final ctx = ref.read(projectProvider.notifier).dawContext;
    final result = await attemptAsync(() => change(ctx));
    if (result case Error<void>(:final error)) {
      ref
          .read(notificationProvider.notifier)
          .error(error, title: tr('source-audio-edit'));
    }
    ref.invalidate(audioPropertiesProvider(sourceId));
    // Clips on the timeline draw with the source's playback rate, and a sample
    // mode change rescales the clips that play it.
    ref.invalidate(trackWaveformProvider);
    await ref.read(trackListStateProvider.notifier).syncTracks();
  }

  Future<void> _setEdits(
    WidgetRef ref, {
    bool? normalize,
    bool? invert,
    bool? reverse,
  }) => _apply(
    ref,
    (ctx) => setWaveformEdits(
      ctx: ctx,
      sourceId: sourceId,
      normalize: normalize ?? props.normalized,
      invert: invert ?? props.invert,
      reverse: reverse ?? props.reverse,
    ),
  );

  Future<void> _setRealtime(WidgetRef ref, bool realtime) => _apply(
    ref,
    (ctx) =>
        setWaveformRealtime(ctx: ctx, sourceId: sourceId, realtime: realtime),
  );

  Future<void> _setPitch(
    WidgetRef ref, {
    double? cents,
    bool? preserveFormants,
  }) => _apply(
    ref,
    (ctx) => setWaveformPitch(
      ctx: ctx,
      sourceId: sourceId,
      pitchCents: cents ?? props.pitchCents,
      preserveFormants: preserveFormants ?? props.preserveFormants,
    ),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Coarse moves in whole semitones (100 cents); fine covers the cents between.
    final coarse = (props.pitchCents / 100).roundToDouble() * 100;
    final fine = (props.pitchCents - coarse).roundToDouble();
    Widget toggle(
      String label,
      IconData icon,
      bool selected,
      ValueChanged<bool> onSelected,
    ) => FilterChip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          toggle(
            tr('source-normalize'),
            Icons.vertical_align_center,
            props.normalized,
            (value) => _setEdits(ref, normalize: value),
          ),
          toggle(
            tr('source-invert'),
            Icons.swap_vert,
            props.invert,
            (value) => _setEdits(ref, invert: value),
          ),
          toggle(
            tr('source-reverse'),
            Icons.swap_horiz,
            props.reverse,
            (value) => _setEdits(ref, reverse: value),
          ),
          Tooltip(
            message: _modeHint(props.sampleMode),
            child: DropdownButton<UiAudioSampleMode>(
              value: props.sampleMode,
              onChanged: (mode) {
                if (mode == null || mode == props.sampleMode) return;
                _apply(
                  ref,
                  (ctx) => setAudioSourceSampleMode(
                    ctx: ctx,
                    sourceId: sourceId,
                    mode: mode,
                  ),
                );
              },
              items: [
                for (final mode in UiAudioSampleMode.values)
                  DropdownMenuItem(value: mode, child: Text(_modeLabel(mode))),
              ],
            ),
          ),
          _CommitKnob(
            label: tr('source-pitch'),
            unit: 'ct',
            value: coarse,
            min: -2400,
            max: 2400,
            step: 100,
            onCommit: (value) => _setPitch(ref, cents: value + fine),
          ),
          _CommitKnob(
            label: tr('source-fine'),
            unit: 'ct',
            value: fine,
            min: -50,
            max: 50,
            onCommit: (value) => _setPitch(ref, cents: coarse + value),
          ),
          Tooltip(
            message: props.realtime
                ? tr('source-realtime-on-hint')
                : tr('source-realtime-off-hint'),
            child: toggle(
              tr('source-realtime'),
              Icons.bolt,
              props.realtime,
              (value) => _setRealtime(ref, value),
            ),
          ),
          Tooltip(
            message: tr('source-keep-the-voice-character-when'),
            child: toggle(
              tr('source-formants'),
              Icons.record_voice_over,
              props.preserveFormants,
              (value) => _setPitch(ref, preserveFormants: value),
            ),
          ),
        ],
      ),
    );
  }
}

/// A stepped knob that previews its value while dragging and commits once on
/// release, so a drag starts one render instead of one per step.
class _CommitKnob extends StatefulWidget {
  const _CommitKnob({
    required this.label,
    required this.unit,
    required this.value,
    required this.min,
    required this.max,
    this.step = 1,
    required this.onCommit,
  });

  final String label;
  final String unit;
  final double value;
  final double min;
  final double max;
  final double step;
  final Future<void> Function(double value) onCommit;

  @override
  State<_CommitKnob> createState() => _CommitKnobState();
}

class _CommitKnobState extends State<_CommitKnob> {
  double? _draft;

  Future<void> _commit(double value) async {
    if (value != widget.value) await widget.onCommit(value);
    if (mounted) setState(() => _draft = null);
  }

  @override
  Widget build(BuildContext context) {
    final value = _draft ?? widget.value;
    final sign = value > 0 ? '+' : '';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DigidawParameterKnob(
          value: value,
          min: widget.min,
          max: widget.max,
          defaultValue: 0,
          step: widget.step,
          diameter: 32,
          onChanged: (next) => setState(() => _draft = next),
          onChangeEnd: _commit,
        ),
        const SizedBox(width: 6),
        Text(
          '${widget.label} $sign${value.toStringAsFixed(0)} ${widget.unit}',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

/// Tempo detection and fit-to-tempo for one source. Both run as background
/// jobs; the properties refetch when they complete.
class _TempoControls extends ConsumerStatefulWidget {
  const _TempoControls({required this.sourceId, required this.props});

  final int sourceId;
  final AudioWaveformUiForAudioProperties props;

  @override
  ConsumerState<_TempoControls> createState() => _TempoControlsState();
}

class _TempoControlsState extends ConsumerState<_TempoControls> {
  bool _warp = false;

  Future<void> _start(Future<int> Function(DawContext ctx) start) async {
    final ctx = ref.read(projectProvider.notifier).dawContext;
    final result = await attemptAsync(() => start(ctx));
    if (!mounted) return;
    if (result case Error<int>(:final error)) {
      ref
          .read(notificationProvider.notifier)
          .error(error, title: tr('source-tempo'));
    }
  }

  /// Asks for the tempo the audio was recorded at and stores it, replacing a
  /// detected tempo and its beats.
  Future<void> _setTempo(double? current) async {
    final bpm = await showDialog<double>(
      context: context,
      builder: (_) => _TempoDialog(initial: current),
    );
    if (bpm == null || !mounted) return;
    final ctx = ref.read(projectProvider.notifier).dawContext;
    final result = await attemptAsync(
      () => setAudioSourceTempo(ctx: ctx, sourceId: widget.sourceId, bpm: bpm),
    );
    if (!mounted) return;
    if (result case Error<void>(:final error)) {
      ref
          .read(notificationProvider.notifier)
          .error(error, title: tr('source-tempo'));
    }
    ref.invalidate(audioPropertiesProvider(widget.sourceId));
    // A tempo-following source plays for a new length, and its clips with it.
    ref.invalidate(trackWaveformProvider);
    await ref.read(trackListStateProvider.notifier).syncTracks();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final props = widget.props;
    final sourceId = widget.sourceId;
    final detecting = ref.watch(
      backgroundJobsProvider.select(
        (s) => s.isRunningFor(sourceId, UiJobKind.tempoDetection),
      ),
    );
    final rendering = ref.watch(
      backgroundJobsProvider.select(
        (s) => s.isRunningFor(sourceId, UiJobKind.waveformRender),
      ),
    );
    final grid = props.beatGrid;
    final tempo = switch ((grid, props.originalBpm)) {
      (final grid?, _) => tr('source-tempo-detected', {
        'bpm': grid.bpm.toStringAsFixed(1),
        'steady': (grid.confidence * 100).round(),
      }),
      (null, final bpm?) => tr('source-tempo-set', {
        'bpm': bpm.toStringAsFixed(1),
      }),
      (null, null) => tr('source-tempo-unknown'),
    };
    final followsLive =
        props.realtime && props.sampleMode == UiAudioSampleMode.stretch;
    final status = rendering || (props.fitted && !props.renderReady)
        ? tr('source-rendering')
        : props.fitted
        ? (props.warp ? tr('source-fitted-beats') : tr('source-fitted-tempo'))
        : followsLive
        ? tr('source-follows-tempo-live')
        : null;
    final canWarp = grid != null && !props.realtime;
    Widget busy() => const SizedBox.square(
      dimension: 14,
      child: CircularProgressIndicator(strokeWidth: 2),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Icon(Icons.speed, size: 16, color: colors.onSurfaceVariant),
          Text(tempo, style: TextStyle(color: colors.onSurfaceVariant)),
          OutlinedButton.icon(
            onPressed: () => _setTempo(grid?.bpm ?? props.originalBpm),
            icon: const Icon(Icons.edit, size: 16),
            label: Text(tr('source-set-tempo')),
          ),
          OutlinedButton.icon(
            onPressed: detecting
                ? null
                : () => _start(
                    (ctx) => startTempoDetection(ctx: ctx, sourceId: sourceId),
                  ),
            icon: detecting ? busy() : const Icon(Icons.graphic_eq, size: 16),
            label: Text(tr('source-detect-tempo')),
          ),
          OutlinedButton.icon(
            onPressed: rendering
                ? null
                : () => _start(
                    (ctx) => startFitToTempo(
                      ctx: ctx,
                      sourceId: sourceId,
                      warp: _warp && canWarp,
                    ),
                  ),
            icon: rendering ? busy() : const Icon(Icons.timer, size: 16),
            label: Text(tr('source-fit-to-tempo')),
          ),
          Tooltip(
            message: grid == null
                ? tr('source-warp-needs-tempo')
                : props.realtime
                ? tr('source-warp-needs-offline')
                : tr('source-warp-hint'),
            child: FilterChip(
              label: Text(tr('source-beat-by-beat')),
              selected: _warp && canWarp,
              onSelected: canWarp
                  ? (selected) => setState(() => _warp = selected)
                  : null,
            ),
          ),
          if (status != null)
            Text(
              status,
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
            ),
        ],
      ),
    );
  }
}

/// Asks for a tempo in BPM, within the range a source may be fitted from.
class _TempoDialog extends StatefulWidget {
  const _TempoDialog({required this.initial});

  final double? initial;

  @override
  State<_TempoDialog> createState() => _TempoDialogState();
}

class _TempoDialogState extends State<_TempoDialog> {
  static const _min = 20.0;
  static const _max = 400.0;

  final _formKey = GlobalKey<FormState>();
  late final _controller = TextEditingController(
    text: widget.initial?.toStringAsFixed(1) ?? '',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double? get _bpm {
    final bpm = double.tryParse(_controller.text.trim());
    return bpm != null && bpm >= _min && bpm <= _max ? bpm : null;
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      Navigator.of(context).pop(_bpm);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(tr('source-set-tempo')),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            suffixText: 'BPM',
            helperText: tr('source-set-tempo-hint'),
            helperMaxLines: 3,
            border: const OutlineInputBorder(),
          ),
          validator: (_) => _bpm == null ? tr('source-tempo-invalid') : null,
          onFieldSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(tr('common-cancel')),
        ),
        FilledButton(onPressed: _submit, child: Text(tr('common-apply'))),
      ],
    );
  }
}
