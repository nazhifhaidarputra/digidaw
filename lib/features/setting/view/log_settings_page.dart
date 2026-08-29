import 'dart:async';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/notification_provider.dart';
import 'package:karbeat/core/utils/log_models.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/features/setting/services/log_export_service.dart';
import 'package:karbeat/features/setting/services/log_provider.dart';

class LogSettingsPage extends ConsumerStatefulWidget {
  const LogSettingsPage({super.key});

  @override
  ConsumerState<LogSettingsPage> createState() => _LogSettingsPageState();
}

class _LogSettingsPageState extends ConsumerState<LogSettingsPage> {
  final _searchController = TextEditingController();
  AppLogLevel _displayMinimum = AppLogLevel.trace;
  bool _displayPaused = false;
  IList<AppLogEntry> _pausedEntries = const IListConst<AppLogEntry>([]);

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_refresh);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final logState = ref.watch(logProvider);
    final capturedEntries = _displayPaused ? _pausedEntries : logState.entries;
    final query = _searchController.text.trim().toLowerCase();
    final visibleEntries = capturedEntries
        .where(
          (entry) =>
              entry.level.index >= _displayMinimum.index &&
              (query.isEmpty ||
                  entry.message.toLowerCase().contains(query) ||
                  (entry.errorSummary?.toLowerCase().contains(query) ?? false)),
        )
        .toIList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Logs',
                key: const ValueKey('settings-page-log'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text(
                'This viewer contains Dart application logs. Rust audio-engine logs are not included.',
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<AppLogLevel>(
                      isExpanded: true,
                      key: const ValueKey('capture-log-level'),
                      initialValue: logState.minimumLevel,
                      decoration: const InputDecoration(
                        labelText: 'Capture level',
                        border: OutlineInputBorder(),
                      ),
                      items: _levelItems(),
                      onChanged: (level) {
                        if (level != null) {
                          unawaited(
                            ref
                                .read(logProvider.notifier)
                                .setMinimumLevel(level),
                          );
                        }
                      },
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<int>(
                      isExpanded: true,
                      key: const ValueKey('log-retention'),
                      initialValue: logState.maximumEntries,
                      decoration: const InputDecoration(
                        labelText: 'Retained entries',
                        border: OutlineInputBorder(),
                      ),
                      items: const [50, 100, 250, 500, 1000, 2000]
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text('$value entries'),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) {
                        if (value != null) {
                          unawaited(
                            ref
                                .read(logProvider.notifier)
                                .setMaximumEntries(value),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const ValueKey('log-search'),
                      controller: _searchController,
                      decoration: const InputDecoration(
                        labelText: 'Search logs',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 190,
                    child: DropdownButtonFormField<AppLogLevel>(
                      isExpanded: true,
                      key: const ValueKey('display-log-level'),
                      initialValue: _displayMinimum,
                      decoration: const InputDecoration(
                        labelText: 'Display level',
                        border: OutlineInputBorder(),
                      ),
                      items: _levelItems(),
                      onChanged: (level) {
                        if (level != null) {
                          setState(() => _displayMinimum = level);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    key: const ValueKey('pause-log-display'),
                    onPressed: () {
                      setState(() {
                        if (!_displayPaused) {
                          _pausedEntries = logState.entries;
                        }
                        _displayPaused = !_displayPaused;
                      });
                    },
                    icon: Icon(_displayPaused ? Icons.play_arrow : Icons.pause),
                    label: Text(
                      _displayPaused ? 'Resume display' : 'Pause display',
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: visibleEntries.isEmpty
                        ? null
                        : () => _copyVisible(visibleEntries),
                    icon: const Icon(Icons.copy_outlined),
                    label: const Text('Copy filtered'),
                  ),
                  OutlinedButton.icon(
                    key: const ValueKey('export-filtered-logs'),
                    onPressed: visibleEntries.isEmpty
                        ? null
                        : () => _exportVisible(visibleEntries),
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Export filtered'),
                  ),
                  OutlinedButton.icon(
                    onPressed: logState.entries.isEmpty ? null : _confirmClear,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Clear'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '${visibleEntries.length} shown • ${logState.entries.length}/${logState.maximumEntries} captured'
                '${_displayPaused ? ' • display paused' : ''}',
                key: const ValueKey('log-count'),
              ),
              const SizedBox(height: 8),
              Container(
                height: 420,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: visibleEntries.isEmpty
                    ? const Center(child: Text('No matching log entries.'))
                    : ListView.separated(
                        padding: const EdgeInsets.all(8),
                        itemCount: visibleEntries.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) =>
                            _LogEntryTile(entry: visibleEntries[index]),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<DropdownMenuItem<AppLogLevel>> _levelItems() {
    return AppLogLevel.values
        .map(
          (level) => DropdownMenuItem(
            value: level,
            child: Text(level.name.toUpperCase()),
          ),
        )
        .toList(growable: false);
  }

  Future<void> _copyVisible(IList<AppLogEntry> entries) async {
    final text = LogExportService.format(entries);
    final result = await attemptAsync(
      () => Clipboard.setData(ClipboardData(text: text)),
    );
    if (!mounted) return;
    if (result.isErr()) {
      ref
          .read(notificationProvider.notifier)
          .error(result.err(), title: 'Could not copy logs');
    } else {
      ref.read(notificationProvider.notifier).info('Filtered logs copied');
    }
  }

  Future<void> _exportVisible(IList<AppLogEntry> entries) async {
    final result = await ref.read(logExportServiceProvider).export(entries);
    if (!mounted || result.isOk() && result.ok() == null) return;
    if (result.isErr()) {
      ref
          .read(notificationProvider.notifier)
          .error(result.err(), title: 'Could not export logs');
    } else {
      ref
          .read(notificationProvider.notifier)
          .info('Logs exported to ${result.ok()}');
    }
  }

  Future<void> _confirmClear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear captured logs?'),
        content: const Text(
          'This removes all entries from the in-memory viewer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear logs'),
          ),
        ],
      ),
    );
    if (confirmed == true) ref.read(logProvider.notifier).clear();
  }
}

class _LogEntryTile extends StatelessWidget {
  const _LogEntryTile({required this.entry});

  final AppLogEntry entry;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Text(entry.level.name.toUpperCase()),
      title: SelectableText(entry.message),
      subtitle: Text(
        '${entry.timestamp.toIso8601String()}${entry.errorSummary == null ? '' : '\n${entry.errorSummary}'}',
      ),
    );
  }
}
