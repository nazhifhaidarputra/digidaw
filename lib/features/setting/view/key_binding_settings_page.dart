import 'dart:async';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/core/input/input.dart';
import 'package:karbeat/core/input/shortcut_models.dart';

class KeyBindingSettingsPage extends ConsumerStatefulWidget {
  const KeyBindingSettingsPage({super.key});

  @override
  ConsumerState<KeyBindingSettingsPage> createState() =>
      _KeyBindingSettingsPageState();
}

class _KeyBindingSettingsPageState
    extends ConsumerState<KeyBindingSettingsPage> {
  final _searchController = TextEditingController();

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
    final shortcutState = ref.watch(shortcutManagerProvider);
    final catalog = ref.watch(shortcutCatalogProvider);
    final manager = ref.read(shortcutManagerProvider.notifier);
    final active = manager.activeChords();
    final query = _searchController.text.trim().toLowerCase();
    final visible = catalog
        .where(
          (shortcut) =>
              query.isEmpty ||
              shortcut.title.toLowerCase().contains(query) ||
              shortcut.category.toLowerCase().contains(query),
        )
        .toList(growable: false);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Key Bindings',
                key: const ValueKey('settings-page-keyBinding'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const ValueKey('shortcut-search'),
                      controller: _searchController,
                      decoration: const InputDecoration(
                        labelText: 'Search commands',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    key: const ValueKey('reset-all-shortcuts'),
                    onPressed: shortcutState.overrides.isEmpty
                        ? null
                        : _confirmResetAll,
                    icon: const Icon(Icons.restart_alt),
                    label: const Text('Reset all'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (visible.isEmpty)
                const Text('No commands match this search.')
              else
                ..._buildGroups(visible, active, shortcutState.overrides),
              const SizedBox(height: 16),
              Text(
                'Shortcuts require Ctrl, Alt, or Command plus a non-modifier key. Escape cancels capture.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildGroups(
    List<DawShortcut> shortcuts,
    IMap<String, ShortcutChord> active,
    IMap<String, ShortcutChord> overrides,
  ) {
    final categories = shortcuts.map((shortcut) => shortcut.category).toSet();
    return [
      for (final category in categories) ...[
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 6),
          child: Text(category, style: Theme.of(context).textTheme.titleMedium),
        ),
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              for (final shortcut in shortcuts.where(
                (item) => item.category == category,
              ))
                _ShortcutRow(
                  shortcut: shortcut,
                  activeChord: active[shortcut.id]!,
                  overridden: overrides.containsKey(shortcut.id),
                  onChange: () => _capture(shortcut),
                  onReset: () => unawaited(
                    ref
                        .read(shortcutManagerProvider.notifier)
                        .resetOne(shortcut.id),
                  ),
                ),
            ],
          ),
        ),
      ],
    ];
  }

  Future<void> _capture(DawShortcut shortcut) async {
    final chord = await showDialog<ShortcutChord>(
      context: context,
      builder: (context) => _ShortcutCaptureDialog(title: shortcut.title),
    );
    if (chord == null || !mounted) return;
    final result = await ref
        .read(shortcutManagerProvider.notifier)
        .remap(shortcut.id, chord);
    if (!mounted || result.isOk()) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result.err().toString())));
  }

  Future<void> _confirmResetAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset all shortcuts?'),
        content: const Text('Every command will return to its default chord.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reset all'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(shortcutManagerProvider.notifier).resetAll();
    }
  }
}

class _ShortcutRow extends StatelessWidget {
  const _ShortcutRow({
    required this.shortcut,
    required this.activeChord,
    required this.overridden,
    required this.onChange,
    required this.onReset,
  });

  final DawShortcut shortcut;
  final ShortcutChord activeChord;
  final bool overridden;
  final VoidCallback onChange;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final defaultChord = ShortcutChord.fromActivator(shortcut.defaultKey);
    return ListTile(
      key: ValueKey('shortcut-${shortcut.id}'),
      title: Text(shortcut.title),
      subtitle: Text('Default: ${shortcutLabel(defaultChord)}'),
      trailing: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        children: [
          Text(shortcutLabel(activeChord)),
          IconButton(
            tooltip: 'Reset ${shortcut.title}',
            onPressed: overridden ? onReset : null,
            icon: const Icon(Icons.restart_alt),
          ),
          OutlinedButton(onPressed: onChange, child: const Text('Change')),
        ],
      ),
    );
  }
}

class _ShortcutCaptureDialog extends StatefulWidget {
  const _ShortcutCaptureDialog({required this.title});

  final String title;

  @override
  State<_ShortcutCaptureDialog> createState() => _ShortcutCaptureDialogState();
}

class _ShortcutCaptureDialogState extends State<_ShortcutCaptureDialog> {
  final _focusNode = FocusNode();
  String? _error;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.handled;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
      return KeyEventResult.handled;
    }
    final keyboard = HardwareKeyboard.instance;
    final chord = ShortcutChord(
      logicalKeyId: event.logicalKey.keyId,
      control: keyboard.isControlPressed,
      shift: keyboard.isShiftPressed,
      alt: keyboard.isAltPressed,
      meta: keyboard.isMetaPressed,
    );
    if (!chord.isSupported) {
      setState(() {
        _error = 'Use Ctrl, Alt, or Command with a non-modifier key.';
      });
      return KeyEventResult.handled;
    }
    Navigator.of(context).pop(chord);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Change ${widget.title}'),
      content: Focus(
        autofocus: true,
        focusNode: _focusNode,
        onKeyEvent: _handleKey,
        child: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.keyboard, size: 40),
              const SizedBox(height: 12),
              const Text('Press the new shortcut'),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  key: const ValueKey('shortcut-capture-error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

String shortcutLabel(ShortcutChord chord) {
  final macOS = defaultTargetPlatform == TargetPlatform.macOS;
  final parts = <String>[];
  if (chord.control) parts.add(macOS ? 'Control' : 'Ctrl');
  if (chord.alt) parts.add(macOS ? 'Option' : 'Alt');
  if (chord.shift) parts.add('Shift');
  if (chord.meta) parts.add(macOS ? 'Command' : 'Meta');
  final logicalKey = LogicalKeyboardKey(chord.logicalKeyId);
  final key = switch (logicalKey) {
    LogicalKeyboardKey.space => 'Space',
    _ => logicalKey.keyLabel,
  };
  parts.add(key.isEmpty ? 'Key ${chord.logicalKeyId}' : key.toUpperCase());
  return parts.join('+');
}
