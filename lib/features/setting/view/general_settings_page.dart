import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/features/setting/services/general_settings_provider.dart';

class GeneralSettingsPage extends ConsumerWidget {
  const GeneralSettingsPage({super.key});

  static const historyOptions = <int>[0, 25, 50, 100, 250, 500, 1000];

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
            ],
          ),
        ),
      ),
    );
  }
}
