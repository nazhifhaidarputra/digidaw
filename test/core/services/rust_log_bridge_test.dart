import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:karbeat/core/services/rust_log_bridge.dart';
import 'package:karbeat/core/utils/log_models.dart';
import 'package:karbeat/core/utils/logger.dart';
import 'package:karbeat/src/rust/api/logging.dart';

void main() {
  tearDown(() {
    AppLogRepository.instance.clear();
    AppLogger.configure(minimumLevel: AppLogLevel.info, maximumEntries: 250);
  });

  test('maps Rust batches to labelled entries with one change event', () async {
    final rust = StreamController<List<RustLogEntryDto>>();
    final repository = AppLogRepository(maximumEntries: 50);
    var changes = 0;
    repository.changes.listen((_) => changes++);
    final bridge = RustLogBridge(
      subscribe: () => rust.stream,
      capture: repository.addAll,
    );

    expect(bridge.start().isOk(), isTrue);
    rust.add(const [
      RustLogEntryDto(
        timestampMillis: 1000,
        level: RustLogLevel.warn,
        target: 'karbeat_core::audio',
        message: 'buffer underrun',
      ),
      RustLogEntryDto(
        timestampMillis: 2000,
        level: RustLogLevel.info,
        target: 'karbeat_core::project',
        message: 'project loaded',
      ),
    ]);
    await pumpEventQueue();

    final entries = repository.snapshot;
    expect(changes, 1);
    expect(entries.map((entry) => entry.source), [
      AppLogSource.rust,
      AppLogSource.rust,
    ]);
    expect(entries.first.level, AppLogLevel.warning);
    expect(entries.first.target, 'karbeat_core::audio');
    expect(entries.first.timestamp.millisecondsSinceEpoch, 1000);

    await bridge.stop();
    await rust.close();
  });

  test('AppLogger applies the capture level to Rust records', () {
    AppLogger.configure(minimumLevel: AppLogLevel.warning, maximumEntries: 50);

    AppLogger.captureExternal([
      RustLogBridge.toRecord(
        const RustLogEntryDto(
          timestampMillis: 0,
          level: RustLogLevel.debug,
          target: 'karbeat',
          message: 'hidden',
        ),
      ),
      RustLogBridge.toRecord(
        const RustLogEntryDto(
          timestampMillis: 0,
          level: RustLogLevel.error,
          target: 'karbeat',
          message: 'visible',
        ),
      ),
    ]);

    expect(AppLogRepository.instance.snapshot.map((entry) => entry.message), [
      'visible',
    ]);
  });

  test('Flutter entries keep the Flutter source label', () {
    final repository = AppLogRepository(maximumEntries: 5)
      ..add(level: AppLogLevel.info, message: 'from dart');

    expect(repository.snapshot.single.source, AppLogSource.flutter);
    expect(repository.snapshot.single.target, isNull);
  });

  test('start reports a subscription failure as a Result', () {
    final bridge = RustLogBridge(
      subscribe: () => throw Exception('bridge not initialized'),
      capture: (_) {},
    );

    final started = bridge.start();

    expect(started.isErr(), isTrue);
    expect(bridge.isAttached, isFalse);
  });
}
