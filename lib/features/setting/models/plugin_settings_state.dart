import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:karbeat/src/rust/api/external_plugins.dart';

part 'plugin_settings_state.freezed.dart';

@freezed
abstract class PluginSettingsState with _$PluginSettingsState {
  const PluginSettingsState._();

  const factory PluginSettingsState({
    @Default(false) bool isInitialized,
    @Default(IListConst<String>([])) IList<String> defaultDirectories,
    @Default(IListConst<String>([])) IList<String> directories,
    @Default(30) int timeoutSeconds,
    @Default(false) bool isSaving,
    @Default(false) bool isScanning,
    @Default(false) bool isCancelling,
    int? scanId,
    @Default(0) int completed,
    @Default(0) int total,
    String? currentPath,
    @Default(0) int discoveredCount,
    @Default(false) bool hasCompletedScan,
    @Default(false) bool lastScanCancelled,
    String? scanError,
    @Default(IListConst<UiPluginScanFailure>([]))
    IList<UiPluginScanFailure> failures,
    @Default(IListConst<UiExternalPluginEntry>([]))
    IList<UiExternalPluginEntry> externalPlugins,
  }) = _PluginSettingsState;

  bool get canRetryFailures =>
      !isScanning &&
      (failures.isNotEmpty || externalPlugins.any((entry) => !entry.available));
}
