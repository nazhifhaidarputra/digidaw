import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/features/setting/services/audio_settings_provider.dart';

class AudioSettingsPage extends ConsumerWidget {
  const AudioSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(audioSettingsProvider);
    final notifier = ref.read(audioSettingsProvider.notifier);
    final latencyMs = state.draftBlockSize / state.draftSampleRate * 1000;
    final actual = state.runtimeSettings?.actualStream;

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
                'Audio',
                key: const ValueKey('settings-page-audio'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text(
                'DSP settings control the dedicated processing worker. Device stream values are read-only and may differ safely.',
              ),
              const SizedBox(height: 24),
              DropdownButtonFormField<int>(
                key: ValueKey('dsp-sample-rate-${state.draftSampleRate}'),
                initialValue: state.draftSampleRate,
                decoration: const InputDecoration(
                  labelText: 'DSP sample rate',
                  border: OutlineInputBorder(),
                ),
                items: state.supportedSampleRates
                    .map(
                      (rate) => DropdownMenuItem(
                        value: rate,
                        child: Text('$rate Hz'),
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
                decoration: const InputDecoration(
                  labelText: 'DSP block size',
                  border: OutlineInputBorder(),
                ),
                items: state.supportedBlockSizes
                    .map(
                      (size) => DropdownMenuItem(
                        value: size,
                        child: Text('$size frames'),
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
                'One DSP block represents approximately ${latencyMs.toStringAsFixed(2)} ms. Smaller blocks reduce processing latency but increase CPU scheduling pressure.',
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
                    label: Text(state.isApplying ? 'Applying…' : 'Apply'),
                  ),
                  OutlinedButton(
                    onPressed: !state.hasPendingChanges || state.isApplying
                        ? null
                        : notifier.revertDraft,
                    child: const Text('Revert'),
                  ),
                ],
              ),
              if (state.fallbackReason != null) ...[
                const SizedBox(height: 16),
                Text(state.fallbackReason!),
              ],
              const SizedBox(height: 28),
              Text(
                'Device stream (read-only)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (actual == null)
                const Text('The active device stream is starting.')
              else ...[
                Text('Output: ${actual.deviceName}'),
                Text('Device sample rate: ${actual.sampleRate} Hz'),
                Text(
                  'Device callback buffer: ${actual.callbackBufferSize} frames',
                ),
                Text('Channels: ${actual.channels}'),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
