import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/features/plugins/models/plugin_browser_entry.dart';
import 'package:karbeat/features/plugins/services/audio_plugins_service.dart';
import 'package:karbeat/src/rust/api/plugin.dart';

typedef AddPluginCallback =
    Future<Result<void>> Function(PluginBrowserEntry plugin);

Future<void> showPluginBrowserDialog({
  required BuildContext context,
  required KarbeatPluginType pluginType,
  required AddPluginCallback onAdd,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => PluginBrowserDialog(pluginType: pluginType, onAdd: onAdd),
  );
}

class PluginBrowserDialog extends ConsumerStatefulWidget {
  const PluginBrowserDialog({
    super.key,
    required this.pluginType,
    required this.onAdd,
  });

  final KarbeatPluginType pluginType;
  final AddPluginCallback onAdd;

  @override
  ConsumerState<PluginBrowserDialog> createState() =>
      _PluginBrowserDialogState();
}

class _PluginBrowserDialogState extends ConsumerState<PluginBrowserDialog> {
  String _query = '';
  String? _selectedKey;
  bool _isAdding = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final pluginState = ref.watch(audioPluginProvider);
    final title = widget.pluginType == KarbeatPluginType.generator
        ? 'Instrument Browser'
        : 'Effect Browser';

    return AlertDialog(
      title: Text(title),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      content: SizedBox(
        width: 520,
        height: 480,
        child: Column(
          children: [
            TextField(
              key: const ValueKey('plugin-browser-search'),
              autofocus: true,
              enabled: !_isAdding,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                labelText: 'Search plugins',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: pluginState.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(child: Text(error.toString())),
                data: (state) {
                  final entries = filterAndSortPluginEntries(
                    state,
                    widget.pluginType,
                    _query,
                  );
                  if (entries.isEmpty) {
                    return const Center(
                      child: Text('No matching plugins found.'),
                    );
                  }
                  return ListView.separated(
                    key: const ValueKey('plugin-browser-list'),
                    itemCount: entries.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      final selected = entry.favoriteKey == _selectedKey;
                      final favorite = state.favoriteKeys.contains(
                        entry.favoriteKey,
                      );
                      final favoritePending = state.pendingFavoriteKeys
                          .contains(entry.favoriteKey);
                      return ListTile(
                        key: ValueKey('plugin-browser-${entry.favoriteKey}'),
                        selected: selected,
                        enabled: !_isAdding,
                        leading: Icon(
                          widget.pluginType == KarbeatPluginType.generator
                              ? Icons.piano
                              : Icons.graphic_eq,
                        ),
                        title: Text(entry.name),
                        subtitle: entry.vendor.isEmpty
                            ? null
                            : Text(entry.vendor),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _FormatBadge(label: entry.binaryType.label),
                            const SizedBox(width: 4),
                            IconButton(
                              key: ValueKey(
                                'plugin-favorite-${entry.favoriteKey}',
                              ),
                              tooltip: favorite
                                  ? 'Remove from favorites'
                                  : 'Add to favorites',
                              onPressed: _isAdding || favoritePending
                                  ? null
                                  : () => unawaited(
                                      ref
                                          .read(audioPluginProvider.notifier)
                                          .toggleFavorite(entry.favoriteKey),
                                    ),
                              icon: favoritePending
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Icon(
                                      favorite ? Icons.star : Icons.star_border,
                                    ),
                            ),
                          ],
                        ),
                        onTap: () => setState(() {
                          _selectedKey = entry.favoriteKey;
                          _error = null;
                        }),
                      );
                    },
                  );
                },
              ),
            ),
            if (_error != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _error!,
                    key: const ValueKey('plugin-browser-error'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isAdding ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          key: const ValueKey('add-selected-plugin'),
          onPressed: _selectedKey == null || _isAdding
              ? null
              : () => unawaited(_addSelected()),
          icon: _isAdding
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add),
          label: Text(_isAdding ? 'Adding…' : 'Add Plugin'),
        ),
      ],
    );
  }

  Future<void> _addSelected() async {
    final state = ref.read(audioPluginProvider).value;
    final selected = state?.registry.browserEntries
        .where((entry) => entry.favoriteKey == _selectedKey)
        .firstOrNull;
    if (selected == null) return;
    setState(() {
      _isAdding = true;
      _error = null;
    });
    final result = await widget.onAdd(selected);
    if (!mounted) return;
    if (result case Error<void>(error: final error)) {
      setState(() {
        _isAdding = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
      return;
    }
    Navigator.pop(context);
  }
}

class _FormatBadge extends StatelessWidget {
  const _FormatBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: colors.onSecondaryContainer),
      ),
    );
  }
}
