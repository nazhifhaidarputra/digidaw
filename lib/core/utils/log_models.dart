import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'log_models.freezed.dart';

enum AppLogLevel { trace, debug, info, warning, error, fatal }

/// The runtime layer that emitted a log entry.
enum AppLogSource {
  flutter('Flutter'),
  rust('Rust');

  const AppLogSource(this.label);

  final String label;
}

@freezed
abstract class AppLogEntry with _$AppLogEntry {
  const factory AppLogEntry({
    required int sequence,
    required DateTime timestamp,
    required AppLogLevel level,
    required String message,
    @Default(AppLogSource.flutter) AppLogSource source,

    /// Rust `log` target (module path); `null` for Flutter entries.
    String? target,
    String? errorSummary,
  }) = _AppLogEntry;
}

@freezed
abstract class AppLogState with _$AppLogState {
  const factory AppLogState({
    @Default(IListConst<AppLogEntry>([])) IList<AppLogEntry> entries,
    @Default(AppLogLevel.info) AppLogLevel minimumLevel,
    @Default(250) int maximumEntries,
    @Default(false) bool isInitialized,
  }) = _AppLogState;
}
