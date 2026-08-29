import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karbeat/core/utils/log_models.dart';
import 'package:karbeat/core/utils/logger.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/features/setting/services/log_preferences_service.dart';
import 'package:karbeat/features/setting/services/log_provider.dart';

class _FakeLogPreferencesService extends LogPreferencesService {
  LogPreferences loaded = (minimumLevel: AppLogLevel.debug, maximumEntries: 50);
  LogPreferences? saved;
  Exception? loadError;
  Exception? saveError;

  @override
  Future<Result<LogPreferences>> load() async {
    final error = loadError;
    return error == null ? Result.ok(loaded) : Result.error(error);
  }

  @override
  Future<Result<void>> save(LogPreferences preferencesValue) async {
    final error = saveError;
    if (error != null) return Result.error(error);
    saved = preferencesValue;
    return Result.ok(null);
  }
}

void main() {
  tearDown(() {
    AppLogRepository.instance.clear();
    AppLogger.configure(minimumLevel: AppLogLevel.info, maximumEntries: 250);
  });

  test('repository evicts oldest entries and sanitizes line breaks', () {
    final repository = AppLogRepository(maximumEntries: 2);

    repository.add(level: AppLogLevel.info, message: 'first');
    repository.add(level: AppLogLevel.warning, message: 'second\nline');
    repository.add(level: AppLogLevel.error, message: 'third');

    expect(repository.snapshot.length, 2);
    expect(repository.snapshot.first.message, 'second line');
    expect(repository.snapshot.last.message, 'third');
  });

  test('AppLogger filters entries below the configured level', () {
    final repository = AppLogRepository.instance;
    repository.clear();
    AppLogger.configure(minimumLevel: AppLogLevel.warning, maximumEntries: 50);

    AppLogger.info('hidden');
    AppLogger.warn('visible');

    expect(repository.snapshot.map((entry) => entry.message), ['visible']);
  });

  test('provider restores and persists immutable log preferences', () async {
    final repository = AppLogRepository(maximumEntries: 250);
    final service = _FakeLogPreferencesService();
    final container = ProviderContainer(
      overrides: [
        appLogRepositoryProvider.overrideWithValue(repository),
        logPreferencesServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);

    final initialized = await container.read(logProvider.notifier).initialize();
    final changed = await container
        .read(logProvider.notifier)
        .setMinimumLevel(AppLogLevel.error);

    expect(initialized.isOk(), isTrue);
    expect(changed.isOk(), isTrue);
    expect(container.read(logProvider).minimumLevel, AppLogLevel.error);
    expect(container.read(logProvider).maximumEntries, 50);
    expect(service.saved?.minimumLevel, AppLogLevel.error);
  });

  test('provider clear removes captured entries', () async {
    final repository = AppLogRepository(maximumEntries: 50);
    final container = ProviderContainer(
      overrides: [appLogRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    container.read(logProvider);
    repository.add(level: AppLogLevel.info, message: 'entry');

    container.read(logProvider.notifier).clear();

    expect(container.read(logProvider).entries, isEmpty);
  });
}
