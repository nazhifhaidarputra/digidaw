import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/core/l10n/localizer.dart';
import 'package:karbeat/features/setting/services/audio_settings_provider.dart';
import 'package:karbeat/features/setting/services/metronome_sound_provider.dart';

class AudioSettingsPage extends ConsumerWidget {
  const AudioSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(audioSettingsProvider);
    final notifier = ref.read(audioSettingsProvider.notifier);
    final latencyMs = state.draftBlockSize / state.draftSampleRate * 1000;
    final actual = state.runtimeSettings?.actualStream;
    final metronomeSound = ref.watch(metronomeSoundProvider);
    final metronomeNotifier = ref.read(metronomeSoundProvider.notifier);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('settings-menu-audio'),
                key: const ValueKey('settings-page-audio'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(tr('settings-audio-description')),
              const SizedBox(height: 24),
              DropdownButtonFormField<int>(
                key: ValueKey('dsp-sample-rate-${state.draftSampleRate}'),
                initialValue: state.draftSampleRate,
                decoration: InputDecoration(
                  labelText: tr('settings-audio-sample-rate'),
                  border: OutlineInputBorder(),
                ),
                items: state.supportedSampleRates
                    .map(
                      (rate) => DropdownMenuItem(
                        value: rate,
                        child: Text(
                          tr('settings-audio-hertz', {'value': rate}),
                        ),
                      ),
                    )
                    .toList(growable: false),
                onChanged: state.isApplying
                    ? null
                    : (value) {
                        if (value != null) notifier.setDraftSampleRate(value);
                      },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                key: ValueKey('dsp-block-size-${state.draftBlockSize}'),
                initialValue: state.draftBlockSize,
                decoration: InputDecoration(
                  labelText: tr('settings-audio-block-size'),
                  border: OutlineInputBorder(),
                ),
                items: state.supportedBlockSizes
                    .map(
                      (size) => DropdownMenuItem(
                        value: size,
                        child: Text(
                          tr('settings-audio-frames', {'count': size}),
                        ),
                      ),
                    )
                    .toList(growable: false),
                onChanged: state.isApplying
                    ? null
                    : (value) {
                        if (value != null) notifier.setDraftBlockSize(value);
                      },
              ),
              const SizedBox(height: 12),
              Text(
                tr('settings-audio-block-latency', {
                  'milliseconds': latencyMs.toStringAsFixed(2),
                }),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                children: [
                  FilledButton.icon(
                    key: const ValueKey('apply-dsp-settings'),
                    onPressed: !state.hasPendingChanges || state.isApplying
                        ? null
                        : () => unawaited(notifier.applyDraft()),
                    icon: state.isApplying
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: Text(
                      state.isApplying
                          ? tr('settings-audio-applying')
                          : tr('common-apply'),
                    ),
                  ),
                  OutlinedButton(
                    onPressed: !state.hasPendingChanges || state.isApplying
                        ? null
                        : notifier.revertDraft,
                    child: Text(tr('settings-audio-revert')),
                  ),
                ],
              ),
              if (state.fallbackReason != null) ...[
                const SizedBox(height: 16),
                Text(state.fallbackReason!),
              ],
              const SizedBox(height: 28),
              Text(
                tr('settings-audio-metronome'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                metronomeSound == null
                    ? tr('settings-audio-metronome-default')
                    : _fileName(metronomeSound),
                key: const ValueKey('metronome-sound-name'),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    key: const ValueKey('choose-metronome-sound'),
                    onPressed: () => unawaited(metronomeNotifier.chooseSound()),
                    icon: const Icon(Icons.audio_file_outlined),
                    label: Text(tr('settings-audio-metronome-choose')),
                  ),
                  OutlinedButton.icon(
                    key: const ValueKey('clear-metronome-sound'),
                    onPressed: metronomeSound == null
                        ? null
                        : () => unawaited(metronomeNotifier.useDefaultSound()),
                    icon: const Icon(Icons.restart_alt),
                    label: Text(tr('settings-audio-metronome-use-default')),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(tr('settings-audio-metronome-help')),
              const SizedBox(height: 28),
              Text(
                tr('settings-audio-device-stream'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (actual == null)
                Text(tr('settings-audio-device-stream-starting'))
              else ...[
                Text(
                  tr('settings-audio-device-output', {
                    'device': actual.deviceName,
                  }),
                ),
                Text(
                  tr('settings-audio-device-sample-rate', {
                    'value': actual.sampleRate,
                  }),
                ),
                Text(
                  tr('settings-audio-device-buffer', {
                    'count': actual.callbackBufferSize,
                  }),
                ),
                Text(
                  tr('settings-audio-device-channels', {
                    'count': actual.channels,
                  }),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String _fileName(String path) {
  final segments = path.replaceAll('\\', '/').split('/');
  return segments.lastWhere(
    (segment) => segment.isNotEmpty,
    orElse: () => path,
  );
}
