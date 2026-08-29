import 'dart:async';
import 'dart:collection';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:karbeat/core/utils/log_models.dart';
import 'package:logger/logger.dart';

class AppLogRepository {
  AppLogRepository({int maximumEntries = 250})
    : _maximumEntries = maximumEntries;

  static final AppLogRepository instance = AppLogRepository();

  final ListQueue<AppLogEntry> _entries = ListQueue<AppLogEntry>();
  final StreamController<AppLogEntry> _controller =
      StreamController<AppLogEntry>.broadcast(sync: true);
  int _maximumEntries;
  int _nextSequence = 0;

  Stream<AppLogEntry> get entriesAdded => _controller.stream;
  IList<AppLogEntry> get snapshot => _entries.toIList();
  int get maximumEntries => _maximumEntries;

  void configureMaximumEntries(int value) {
    _maximumEntries = value.clamp(1, 2000);
    _trim();
  }

  void add({
    required AppLogLevel level,
    required String message,
    Object? error,
  }) {
    final entry = AppLogEntry(
      sequence: _nextSequence++,
      timestamp: DateTime.now(),
      level: level,
      message: _sanitize(message, 2000),
      errorSummary: error == null ? null : _sanitize(error.toString(), 500),
    );
    _entries.addLast(entry);
    _trim();
    _controller.add(entry);
  }

  void clear() {
    _entries.clear();
  }

  void _trim() {
    while (_entries.length > _maximumEntries) {
      _entries.removeFirst();
    }
  }

  static String _sanitize(String value, int maximumLength) {
    final normalized = value.replaceAll(RegExp(r'[\r\n]+'), ' ').trim();
    if (normalized.length <= maximumLength) return normalized;
    return '${normalized.substring(0, maximumLength)}…';
  }
}

class AppLogger {
  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
  );
  static AppLogLevel _minimumLevel = AppLogLevel.info;

  static AppLogLevel get minimumLevel => _minimumLevel;

  static void configure({
    required AppLogLevel minimumLevel,
    required int maximumEntries,
  }) {
    _minimumLevel = minimumLevel;
    AppLogRepository.instance.configureMaximumEntries(maximumEntries);
  }

  static void debug(String message) {
    if (!_accepts(AppLogLevel.debug)) return;
    _capture(AppLogLevel.debug, message);
    _logger.d(message);
  }

  static void info(String message) {
    if (!_accepts(AppLogLevel.info)) return;
    _capture(AppLogLevel.info, message);
    _logger.i(message);
  }

  static void warn(String message) {
    if (!_accepts(AppLogLevel.warning)) return;
    _capture(AppLogLevel.warning, message);
    _logger.w(message);
  }

  static void error(String message, {Object? error, StackTrace? stackTrace}) {
    if (!_accepts(AppLogLevel.error)) return;
    _capture(AppLogLevel.error, message, error: error);
    _logger.e(message, error: error, stackTrace: stackTrace);
  }

  static void trace(String message) {
    if (!_accepts(AppLogLevel.trace)) return;
    _capture(AppLogLevel.trace, message);
    _logger.t(message);
  }

  static void fatal(String message, {Object? error, StackTrace? stackTrace}) {
    if (!_accepts(AppLogLevel.fatal)) return;
    _capture(AppLogLevel.fatal, message, error: error);
    _logger.f(message, error: error, stackTrace: stackTrace);
  }

  static bool _accepts(AppLogLevel level) => level.index >= _minimumLevel.index;

  static void _capture(AppLogLevel level, String message, {Object? error}) {
    AppLogRepository.instance.add(level: level, message: message, error: error);
  }
}
