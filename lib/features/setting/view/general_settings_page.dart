import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/features/setting/services/general_settings_provider.dart';

class GeneralSettingsPage extends ConsumerWidget {
  const GeneralSettingsPage({super.key});

  static const historyOptions = <int>[0, 25, 50, 100, 250, 500, 1000];
  static const autoSaveIntervalMinutes = <int>[1, 2, 5, 10, 15, 30];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(
      generalSettingsProvider.select(
        (state) => (
          limit: state.maxHistoryEntries,
          busy: state.isApplyingHistoryLimit,
        ),
      ),
    );
    final autoSave = ref.watch(
      generalSettingsProvider.select(
        (state) => (
          enabled: state.autoSaveEnabled,
          intervalSeconds: state.autoSaveIntervalSeconds,
          busy: state.isApplyingAutoSave,
        ),
      ),
    );
    final intervalOptions = {
      for (final minutes in autoSaveIntervalMinutes) minutes * 60,
      autoSave.intervalSeconds,
    }.toList(growable: false)..sort();

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
                'General',
                key: const ValueKey('settings-page-general'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 24),
              DropdownButtonFormField<int>(
                key: ValueKey('history-limit-field-${selection.limit}'),
                initialValue: selection.limit,
                decoration: const InputDecoration(
                  labelText: 'Maximum undo history entries',
                  border: OutlineInputBorder(),
                ),
                items: historyOptions
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(value == 0 ? 'Disabled' : '$value entries'),
                      ),
                    )
                    .toList(growable: false),
                onChanged: selection.busy
                    ? null
                    : (value) {
                        if (value != null) {
                          unawaited(
                            ref
                                .read(generalSettingsProvider.notifier)
                                .setHistoryLimit(value),
                          );
                        }
                      },
              ),
              const SizedBox(height: 12),
              const Text(
                'Lower values use less memory. Reducing the limit immediately removes the oldest undo and redo entries. Choosing Disabled clears both histories.',
              ),
              if (selection.busy) ...[
                const SizedBox(height: 16),
                const LinearProgressIndicator(),
              ],
              const SizedBox(height: 32),
              Text('Auto save', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              SwitchListTile(
                key: const ValueKey('auto-save-enabled-switch'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Enable auto save'),
                value: autoSave.enabled,
                onChanged: autoSave.busy
                    ? null
                    : (value) => unawaited(
                        ref
                            .read(generalSettingsProvider.notifier)
                            .setAutoSaveEnabled(value),
                      ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                key: ValueKey(
                  'auto-save-interval-field-${autoSave.intervalSeconds}',
                ),
                initialValue: autoSave.intervalSeconds,
                decoration: const InputDecoration(
                  labelText: 'Auto save every',
                  border: OutlineInputBorder(),
                ),
                items: intervalOptions
                    .map(
                      (seconds) => DropdownMenuItem(
                        value: seconds,
                        child: Text(_formatInterval(seconds)),
                      ),
                    )
                    .toList(growable: false),
                onChanged: autoSave.busy || !autoSave.enabled
                    ? null
                    : (value) {
                        if (value != null) {
                          unawaited(
                            ref
                                .read(generalSettingsProvider.notifier)
                                .setAutoSaveInterval(value),
                          );
                        }
                      },
              ),
              const SizedBox(height: 12),
              const Text(
                'Auto save writes a recovery copy of unsaved changes. It never overwrites your project file; after a crash, DigiDAW offers to restore the copy on the next launch.',
              ),
              if (autoSave.busy) ...[
                const SizedBox(height: 16),
                const LinearProgressIndicator(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _formatInterval(int seconds) {
    if (seconds % 60 != 0) return '$seconds seconds';
    final minutes = seconds ~/ 60;
    return minutes == 1 ? '1 minute' : '$minutes minutes';
  }
}
