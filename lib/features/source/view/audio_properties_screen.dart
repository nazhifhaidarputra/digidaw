import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/features/source/services/audio_waveform_services.dart';
import 'package:karbeat/features/track/view/waveform_painter.dart';
import 'package:karbeat/src/rust/api/audio.dart';
import 'package:karbeat/src/rust/api/project.dart';
import 'package:karbeat/src/rust/api/waveform.dart';

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
              ? getWaveformHandle(ctx: ctx, sourceId: props.id!)
              : null;
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
                      child: CustomPaint(
                        painter: StereoWaveformPainter(
                          samples: handle != null
                              ? createZeroCopyWaveformView(handle)
                              : Float32List(0),
                          color: colors.primary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

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
