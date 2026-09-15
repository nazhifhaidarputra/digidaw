import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:karbeat/src/rust/api/plugin.dart';

part 'plugin_browser_entry.freezed.dart';

enum PluginBinaryType { native, vst3, clap, lv2, au }

extension PluginBinaryTypeLabel on PluginBinaryType {
  String get label => switch (this) {
    PluginBinaryType.native => 'Native',
    PluginBinaryType.vst3 => 'VST3',
    PluginBinaryType.clap => 'CLAP',
    PluginBinaryType.lv2 => 'LV2',
    PluginBinaryType.au => 'AU',
  };
}

@freezed
abstract class PluginBrowserEntry with _$PluginBrowserEntry {
  const factory PluginBrowserEntry({
    required int registryId,
    required String favoriteKey,
    required String name,
    required String vendor,
    required KarbeatPluginType pluginType,
    required PluginBinaryType binaryType,
    required bool isExternal,
  }) = _PluginBrowserEntry;
}
