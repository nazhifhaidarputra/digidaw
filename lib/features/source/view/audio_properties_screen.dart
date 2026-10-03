import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/app/providers/track_list_state.dart';
import 'package:karbeat/src/rust/api/jobs.dart';
import 'package:karbeat/src/rust/api/audio_analysis.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/app/providers/notification_provider.dart';
import 'package:karbeat/app/providers/background_jobs_provider.dart';
import 'package:karbeat/core/widgets/digidaw_plugin_widgets/parameter_knob.dart';
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
      appBar: AppBar(title: Text(sourceName)),
      body: propsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),

        error: (err, _) => Center(
          child: Text("Error: $err", style: TextStyle(color: colors.error)),
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
                          if (handle != null)
                            Positioned.fill(
                              child: _WaveformEnvelopeEditor(
                                sourceId: sourceId,
                                envelope: envelope,
                                frames:
                                    handle.getLen() ~/
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
                      label: const Text("Preview"),
                      backgroundColor: colors.primaryContainer,
                      foregroundColor: colors.onPrimaryContainer,
                    ),
                    const SizedBox(width: 10),
                    FloatingActionButton.extended(
                      heroTag: 'stop_source_fab',
                      onPressed: () {
                        stopAllPreviews(ctx: ctx);
                      },
                      label: const Text("Stop"),
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
            "Format",
            "${props.sampleRate} Hz / ${props.channels} Ch",
          ),
          _row(context, "Duration", "${props.duration.toStringAsFixed(2)} sec"),
          _row(context, "Path", props.filePath, isSmall: true),
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

/// Edits the waveform envelope shared by every clip of the source; the
/// envelope's positions are source frames spread across the full width.
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
        onCommit: (next) => ref
            .read(projectProvider.notifier)
            .setSourceEnvelope(sourceId, next),
      ),
    );
  }
}

/// Fade, loop crossfade, and point count of the waveform envelope.
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
          Text('Fade in ${_ms(envelope.fadeIn.length)}', style: style),
          Text('Fade out ${_ms(envelope.fadeOut.length)}', style: style),
          Text('Loop crossfade ${_ms(envelope.crossfade)}', style: style),
          Text('Points ${envelope.points.length}', style: style),
        ],
      ),
    );
  }
}

/// Sample mode and offline edits. Edits render in the background; the
/// original audio plays until the render is ready.
class _OfflineEditControls extends ConsumerWidget {
  const _OfflineEditControls({required this.sourceId, required this.props});

  final int sourceId;
  final AudioWaveformUiForAudioProperties props;

  String _modeLabel(UiAudioSampleMode mode) => switch (mode) {
    UiAudioSampleMode.default_ => 'Default',
    UiAudioSampleMode.resampled => 'Resampled',
    UiAudioSampleMode.stretch => 'Stretch',
  };

  String _modeHint(UiAudioSampleMode mode) => switch (mode) {
    UiAudioSampleMode.default_ => 'Plays at its own speed',
    UiAudioSampleMode.resampled => 'Follows the tempo, pitch bends with it',
    UiAudioSampleMode.stretch => 'Follows the tempo, keeps its pitch',
  };

  Future<void> _apply(
    WidgetRef ref,
    Future<void> Function(DawContext ctx) change,
  ) async {
    final ctx = ref.read(projectProvider.notifier).dawContext;
    final result = await attemptAsync(() => change(ctx));
    if (result case Error<void>(:final error)) {
      ref.read(notificationProvider.notifier).error(error, title: 'Audio edit');
    }
    ref.invalidate(audioPropertiesProvider(sourceId));
    // Clips on the timeline draw with the source's playback rate.
    ref.invalidate(trackWaveformProvider);
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

  Future<void> _setPitch(
    WidgetRef ref, {
    double? semitones,
    bool? preserveFormants,
  }) => _apply(
    ref,
    (ctx) => setWaveformPitch(
      ctx: ctx,
      sourceId: sourceId,
      pitchSemitones: semitones ?? props.pitchSemitones,
      preserveFormants: preserveFormants ?? props.preserveFormants,
    ),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final semitones = props.pitchSemitones.roundToDouble();
    final cents = ((props.pitchSemitones - semitones) * 100).roundToDouble();
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
            'Normalize',
            Icons.vertical_align_center,
            props.normalized,
            (value) => _setEdits(ref, normalize: value),
          ),
          toggle(
            'Invert',
            Icons.swap_vert,
            props.invert,
            (value) => _setEdits(ref, invert: value),
          ),
          toggle(
            'Reverse',
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
            label: 'Pitch',
            unit: 'st',
            value: semitones,
            min: -24,
            max: 24,
            onCommit: (value) => _setPitch(ref, semitones: value + cents / 100),
          ),
          _CommitKnob(
            label: 'Fine',
            unit: 'ct',
            value: cents,
            min: -50,
            max: 50,
            onCommit: (value) =>
                _setPitch(ref, semitones: semitones + value / 100),
          ),
          Tooltip(
            message: 'Keep the voice character when shifting pitch',
            child: toggle(
              'Formants',
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

/// A whole-step knob that previews its value while dragging and commits once on
/// release, so a drag starts one render instead of one per step.
class _CommitKnob extends StatefulWidget {
  const _CommitKnob({
    required this.label,
    required this.unit,
    required this.value,
    required this.min,
    required this.max,
    required this.onCommit,
  });

  final String label;
  final String unit;
  final double value;
  final double min;
  final double max;
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
          step: 1,
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
      ref.read(notificationProvider.notifier).error(error, title: 'Tempo');
    }
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
      (final grid?, _) =>
        '${grid.bpm.toStringAsFixed(1)} BPM · '
            '${(grid.confidence * 100).round()}% steady',
      (null, final bpm?) => '${bpm.toStringAsFixed(1)} BPM (as placed)',
      (null, null) => 'Tempo unknown',
    };
    final status = rendering || (props.fitted && !props.renderReady)
        ? 'Rendering…'
        : props.fitted
        ? (props.warp ? 'Fitted beat by beat' : 'Fitted to project tempo')
        : null;
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
            onPressed: detecting
                ? null
                : () => _start(
                    (ctx) => startTempoDetection(ctx: ctx, sourceId: sourceId),
                  ),
            icon: detecting ? busy() : const Icon(Icons.graphic_eq, size: 16),
            label: const Text('Detect tempo'),
          ),
          OutlinedButton.icon(
            onPressed: rendering
                ? null
                : () => _start(
                    (ctx) => startFitToTempo(
                      ctx: ctx,
                      sourceId: sourceId,
                      warp: _warp && grid != null,
                    ),
                  ),
            icon: rendering ? busy() : const Icon(Icons.timer, size: 16),
            label: const Text('Fit to tempo'),
          ),
          Tooltip(
            message: grid == null
                ? 'Detect the tempo first'
                : 'Stretch beat by beat so every beat lands on the grid',
            child: FilterChip(
              label: const Text('Beat by beat'),
              selected: _warp && grid != null,
              onSelected: grid == null
                  ? null
                  : (selected) => setState(() => _warp = selected),
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
