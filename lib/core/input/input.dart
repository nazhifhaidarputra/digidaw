import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DawShortcut {
  /// A unique identifier for the shortcut.
  final String id;

  /// The display name of the shortcut.
  final String title;

  /// The category of the shortcut.
  final String category;

  /// The intent of the shortcut.
  final Intent intent;

  /// The default key combination for the shortcut.
  final ShortcutActivator defaultKey;

  const DawShortcut({
    required this.id,
    required this.title,
    required this.category,
    required this.intent,
    required this.defaultKey,
  });
}

class ShortcutManagerNotifier extends Notifier<Map<ShortcutActivator, Intent>> {
  /// A decentralized list of all registered shortcuts across the app
  final List<DawShortcut> _registeredShortcuts = [];
  
  /// User overrides loaded from local storage/settings
  final Map<String, ShortcutActivator> _userOverrides = {};

  @override
  Map<ShortcutActivator, Intent> build() {
    _loadUserOverrides(); // TODO: Load from SharedPreferences/Hive
    return _buildActiveMap();
  }

  /// Register shortcut to the manager. Call this in the UI to add the shortcut
  void registerFeatureShortcuts(List<DawShortcut> shortcuts) {
    _registeredShortcuts.addAll(shortcuts);
    state = _buildActiveMap(); // Rebuild the global mapping
  }

  void remapShortcut(String id, ShortcutActivator newKey) {
    _userOverrides[id] = newKey;
    // TODO: Save to local storage.
    state = _buildActiveMap();
  }

  Map<ShortcutActivator, Intent> _buildActiveMap() {
    final Map<ShortcutActivator, Intent> activeMap = {};
    for (final shortcut in _registeredShortcuts) {
      final key = _userOverrides[shortcut.id] ?? shortcut.defaultKey;
      activeMap[key] = shortcut.intent;
    }
    return activeMap;
  }

  Future<void> _loadUserOverrides() async {
   // TODO: Load from SharedPreferences/Hive
  }
}

final shortcutManagerProvider = NotifierProvider<ShortcutManagerNotifier, Map<ShortcutActivator, Intent>>(
  ShortcutManagerNotifier.new,
);