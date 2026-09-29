import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/project_provider.dart';
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

              _OfflineEditControls(sampleMode: props.sampleMode),

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

/// Offline edit controls. Placeholders: offline processing is not
/// implemented yet, so every control is disabled.
class _OfflineEditControls extends StatelessWidget {
  const _OfflineEditControls({required this.sampleMode});

  final UiAudioSampleMode sampleMode;

  static const _comingSoon = 'Coming soon';

  String _modeLabel(UiAudioSampleMode mode) => switch (mode) {
    UiAudioSampleMode.default_ => 'Default',
    UiAudioSampleMode.resampled => 'Resampled',
    UiAudioSampleMode.stretch => 'Stretch',
  };

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    Widget stubButton(String label, IconData icon) => Tooltip(
      message: _comingSoon,
      child: OutlinedButton.icon(
        onPressed: null,
        icon: Icon(icon, size: 16),
        label: Text(label),
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          stubButton('Normalize', Icons.vertical_align_center),
          stubButton('Invert', Icons.swap_vert),
          stubButton('Reverse', Icons.swap_horiz),
          Tooltip(
            message: _comingSoon,
            child: DropdownButton<UiAudioSampleMode>(
              value: sampleMode,
              onChanged: null,
              items: [
                for (final mode in UiAudioSampleMode.values)
                  DropdownMenuItem(value: mode, child: Text(_modeLabel(mode))),
              ],
            ),
          ),
          Tooltip(
            message: _comingSoon,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IgnorePointer(
                  child: Opacity(
                    opacity: 0.4,
                    child: DigidawParameterKnob(
                      value: 0,
                      min: -24,
                      max: 24,
                      defaultValue: 0,
                      step: 1,
                      diameter: 32,
                      onChanged: (_) {},
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'Pitch',
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
