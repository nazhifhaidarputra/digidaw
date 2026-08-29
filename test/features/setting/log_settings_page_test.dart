import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karbeat/core/utils/log_models.dart';
import 'package:karbeat/core/utils/logger.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/features/setting/services/log_export_service.dart';
import 'package:karbeat/features/setting/services/log_provider.dart';
import 'package:karbeat/features/setting/view/log_settings_page.dart';

class _FakeLogExportService extends LogExportService {
  IList<AppLogEntry>? exported;

  @override
  Future<Result<String?>> export(IList<AppLogEntry> entries) async {
    exported = entries;
    return Result.ok('/tmp/digidaw.log');
  }
}

void main() {
  testWidgets('search filters the captured snapshot', (tester) async {
    final repository = AppLogRepository(maximumEntries: 50)
      ..add(level: AppLogLevel.info, message: 'transport started')
      ..add(level: AppLogLevel.warning, message: 'buffer warning');

    await _pumpPage(tester, repository: repository);
    await tester.enterText(find.byKey(const ValueKey('log-search')), 'warning');
    await tester.pump();

    expect(find.text('buffer warning'), findsOneWidget);
    expect(find.text('transport started'), findsNothing);
  });

  testWidgets('pause freezes display without stopping capture', (tester) async {
    final repository = AppLogRepository(maximumEntries: 50)
      ..add(level: AppLogLevel.info, message: 'before pause');

    await _pumpPage(tester, repository: repository);
    await tester.tap(find.byKey(const ValueKey('pause-log-display')));
    repository.add(level: AppLogLevel.error, message: 'captured while paused');
    await tester.pump();

    expect(find.text('captured while paused'), findsNothing);
    expect(find.text('Resume display'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('pause-log-display')));
    await tester.pump();
    expect(find.text('captured while paused'), findsOneWidget);
  });

  testWidgets('clear requires confirmation', (tester) async {
    final repository = AppLogRepository(maximumEntries: 50)
      ..add(level: AppLogLevel.info, message: 'clear me');

    await _pumpPage(tester, repository: repository);
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    expect(find.text('Clear captured logs?'), findsOneWidget);

    await tester.tap(find.text('Clear logs'));
    await tester.pumpAndSettle();
    expect(find.text('No matching log entries.'), findsOneWidget);
  });

  testWidgets('exports only the filtered entries', (tester) async {
    final repository = AppLogRepository(maximumEntries: 50)
      ..add(level: AppLogLevel.info, message: 'include this')
      ..add(level: AppLogLevel.info, message: 'exclude this');
    final exporter = _FakeLogExportService();

    await _pumpPage(tester, repository: repository, exporter: exporter);
    await tester.enterText(find.byKey(const ValueKey('log-search')), 'include');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('export-filtered-logs')));
    await tester.pump();

    expect(exporter.exported?.map((entry) => entry.message), ['include this']);
  });
}

Future<void> _pumpPage(
  WidgetTester tester, {
  required AppLogRepository repository,
  LogExportService? exporter,
}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        appLogRepositoryProvider.overrideWithValue(repository),
        if (exporter != null)
          logExportServiceProvider.overrideWithValue(exporter),
      ],
      child: MaterialApp(
        theme: ThemeData.dark(),
        home: const Scaffold(body: LogSettingsPage()),
      ),
    ),
  );
}
