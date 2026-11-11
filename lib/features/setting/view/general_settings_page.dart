import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/features/setting/models/general_settings_state.dart';
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
    final showRecentProjects = ref.watch(
      generalSettingsProvider.select((state) => state.showRecentProjects),
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
              const SizedBox(height: 32),
              Text('Folders', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              const _DefaultFolderTile(
                kind: DefaultFolder.project,
                title: 'Default project folder',
                unsetText:
                    'Not set. Save and open dialogs start where the system chooses.',
              ),
              const _DefaultFolderTile(
                kind: DefaultFolder.export,
                title: 'Default export folder',
                unsetText: 'Not set. Choose a folder for every export.',
              ),
              const SizedBox(height: 32),
              Text(
                'Recent projects',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                key: const ValueKey('show-recent-projects-switch'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Show recent projects'),
                subtitle: const Text(
                  'Lists recently opened projects under Open recent in the Project menu. Hiding them keeps the list.',
                ),
                value: showRecentProjects,
                onChanged: (value) => unawaited(
                  ref
                      .read(generalSettingsProvider.notifier)
                      .setShowRecentProjects(value),
                ),
              ),
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

/// One default folder: its path, a warning when it is gone, and buttons to
/// choose or clear it.
class _DefaultFolderTile extends ConsumerWidget {
  const _DefaultFolderTile({
    required this.kind,
    required this.title,
    required this.unsetText,
  });

  final DefaultFolder kind;
  final String title;
  final String unsetText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folder = ref.watch(
      generalSettingsProvider.select(
        (state) => (
          path: state.folder(kind),
          missing: state.missingFolders.contains(kind),
          busy: state.isSavingFolder,
        ),
      ),
    );
    final notifier = ref.read(generalSettingsProvider.notifier);
    final path = folder.path;
    final theme = Theme.of(context);

    return ListTile(
      key: ValueKey('default-folder-${kind.name}'),
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(path ?? unsetText),
          if (folder.missing)
            Text(
              'This folder no longer exists, so it is not used.',
              key: ValueKey('default-folder-${kind.name}-missing'),
              style: TextStyle(color: theme.colorScheme.error),
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            key: ValueKey('default-folder-${kind.name}-choose'),
            onPressed: folder.busy
                ? null
                : () => unawaited(notifier.chooseDefaultFolder(kind)),
            child: const Text('Choose…'),
          ),
          if (path != null)
            TextButton(
              key: ValueKey('default-folder-${kind.name}-reset'),
              onPressed: folder.busy
                  ? null
                  : () => unawaited(notifier.setDefaultFolder(kind, null)),
              child: const Text('Reset'),
            ),
        ],
      ),
    );
  }
}
