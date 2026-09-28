import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/features/setting/services/plugin_settings_provider.dart';

class PluginSettingsPage extends ConsumerWidget {
  const PluginSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(pluginSettingsProvider);
    final notifier = ref.read(pluginSettingsProvider.notifier);
    final timeoutOptions = {
      5,
      10,
      30,
      60,
      120,
      300,
      state.timeoutSeconds,
    }.toList()..sort();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Plugins',
                key: const ValueKey('settings-page-plugins'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text(
                'DigiDAW loads the cached catalog at startup. Scans run only when requested and probe each plugin in an isolated helper process.',
              ),
              const SizedBox(height: 28),
              Text(
                'Additional scan folders',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (!state.isInitialized)
                const LinearProgressIndicator()
              else if (state.directories.isEmpty)
                const Text('No additional folders configured.')
              else
                ...state.directories.map(
                  (directory) => _DirectoryTile(
                    key: ValueKey('plugin-directory-$directory'),
                    directory: directory,
                    removable: !state.isSaving && !state.isScanning,
                    onRemove: () =>
                        unawaited(notifier.removeDirectory(directory)),
                  ),
                ),
              const SizedBox(height: 8),
              FilledButton.tonalIcon(
                key: const ValueKey('add-plugin-directory'),
                onPressed:
                    !state.isInitialized || state.isSaving || state.isScanning
                    ? null
                    : () => unawaited(notifier.chooseDirectory()),
                icon: state.isSaving
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.create_new_folder_outlined),
                label: const Text('Add folder'),
              ),
              const SizedBox(height: 28),
              Text(
                'System scan folders',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (state.defaultDirectories.isEmpty)
                const Text(
                  'No standard folders are available on this platform.',
                )
              else
                ...state.defaultDirectories.map(
                  (directory) => _DirectoryTile(
                    key: ValueKey('default-plugin-directory-$directory'),
                    directory: directory,
                  ),
                ),
              const SizedBox(height: 28),
              DropdownButtonFormField<int>(
                key: ValueKey('plugin-scan-timeout-${state.timeoutSeconds}'),
                initialValue: state.timeoutSeconds,
                decoration: const InputDecoration(
                  labelText: 'Per-plugin timeout',
                  border: OutlineInputBorder(),
                ),
                items: timeoutOptions
                    .map(
                      (seconds) => DropdownMenuItem(
                        value: seconds,
                        child: Text('$seconds seconds'),
                      ),
                    )
                    .toList(growable: false),
                onChanged:
                    !state.isInitialized || state.isSaving || state.isScanning
                    ? null
                    : (seconds) {
                        if (seconds != null) {
                          unawaited(notifier.setTimeoutSeconds(seconds));
                        }
                      },
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    key: const ValueKey('scan-plugins'),
                    onPressed: !state.isInitialized || state.isScanning
                        ? null
                        : () => unawaited(notifier.scan()),
                    icon: state.isScanning
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.search),
                    label: Text(state.isScanning ? 'Scanning…' : 'Scan now'),
                  ),
                  OutlinedButton.icon(
                    key: const ValueKey('cancel-plugin-scan'),
                    onPressed:
                        state.isScanning &&
                            state.scanId != null &&
                            !state.isCancelling
                        ? () => unawaited(notifier.cancelScan())
                        : null,
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: Text(
                      state.isCancelling ? 'Cancelling…' : 'Cancel scan',
                    ),
                  ),
                  OutlinedButton.icon(
                    key: const ValueKey('retry-plugin-scan'),
                    onPressed: state.canRetryFailures
                        ? () => unawaited(notifier.retryFailures())
                        : null,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry failed/quarantined plugins'),
                  ),
                ],
              ),
              if (state.isScanning) ...[
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: state.total == 0
                      ? null
                      : state.completed / state.total,
                ),
                const SizedBox(height: 8),
                Text(
                  state.total == 0
                      ? 'Preparing scan…'
                      : '${state.completed} of ${state.total} modules · '
                            '${state.discoveredCount} '
                            'plugin${state.discoveredCount == 1 ? '' : 's'} discovered',
                ),
                if (state.currentPath != null)
                  Text(
                    state.currentPath!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
              if (!state.isScanning && state.hasCompletedScan) ...[
                const SizedBox(height: 16),
                Text(
                  state.lastScanCancelled
                      ? 'Scan cancelled. ${state.discoveredCount} plugins were retained.'
                      : 'Scan complete. ${state.discoveredCount} plugins discovered.',
                  key: const ValueKey('plugin-scan-summary'),
                ),
              ],
              if (state.scanError != null) ...[
                const SizedBox(height: 16),
                Text(
                  state.scanError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              if (state.failures.isNotEmpty) ...[
                const SizedBox(height: 12),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text('${state.failures.length} scan failures'),
                  children: state.failures
                      .map(
                        (failure) => ListTile(
                          dense: true,
                          title: Text(failure.path),
                          subtitle: Text(failure.reason),
                        ),
                      )
                      .toList(growable: false),
                ),
              ],
              const SizedBox(height: 28),
              Text(
                'External catalog',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                '${state.externalPlugins.where((entry) => entry.available).length} available, '
                '${state.externalPlugins.where((entry) => !entry.available).length} unavailable',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DirectoryTile extends StatelessWidget {
  const _DirectoryTile({
    super.key,
    required this.directory,
    this.removable = false,
    this.onRemove,
  });

  final String directory;
  final bool removable;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: const Icon(Icons.folder_outlined),
      title: Text(directory, overflow: TextOverflow.ellipsis),
      trailing: removable
          ? IconButton(
              tooltip: 'Remove folder',
              onPressed: onRemove,
              icon: const Icon(Icons.close),
            )
          : null,
    );
  }
}
