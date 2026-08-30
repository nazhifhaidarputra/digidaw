import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/features/setting/models/plugin_settings_state.dart';

final pluginSettingsProvider = Provider<PluginSettingsState>((ref) {
  return const PluginSettingsState();
});
