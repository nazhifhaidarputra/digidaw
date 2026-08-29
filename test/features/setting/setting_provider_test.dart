import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/features/setting/services/setting_provider.dart';
import 'package:karbeat/features/setting/services/settings_service.dart';
import 'package:karbeat/src/rust/api/project.dart';
import 'package:mocktail/mocktail.dart';

class _MockDawContext extends Mock implements DawContext {}

class _FakeSettingsService extends SettingsService {
  _FakeSettingsService({this.loadedLimit = 100});

  int loadedLimit;
  int? appliedLimit;
  int? savedLimit;
  Exception? loadError;
  Exception? applyError;
  Exception? saveError;

  @override
  Future<Result<int>> loadHistoryLimit() async {
    final error = loadError;
    return error == null ? Result.ok(loadedLimit) : Result.error(error);
  }

  @override
  Future<Result<int>> applyHistoryLimit(DawContext context, int limit) async {
    final error = applyError;
    if (error != null) return Result.error(error);
    appliedLimit = limit;
    return Result.ok(limit);
  }

  @override
  Future<Result<void>> saveHistoryLimit(int limit) async {
    final error = saveError;
    if (error != null) return Result.error(error);
    savedLimit = limit;
    return Result.ok(null);
  }
}

void main() {
  test('initialize restores and applies the persisted history limit', () async {
    final service = _FakeSettingsService(loadedLimit: 250);
    final container = ProviderContainer(
      overrides: [settingsServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);

    final result = await container
        .read(settingsProvider.notifier)
        .initialize(_MockDawContext());

    expect(result.isOk(), isTrue);
    expect(service.appliedLimit, 250);
    expect(container.read(settingsProvider).maxHistoryEntries, 250);
    expect(container.read(settingsProvider).isInitialized, isTrue);
  });

  test('update publishes the applied value and persists it', () async {
    final service = _FakeSettingsService();
    final container = ProviderContainer(
      overrides: [settingsServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(settingsProvider.notifier);
    await notifier.initialize(_MockDawContext());

    final result = await notifier.setHistoryLimit(500);

    expect(result.isOk(), isTrue);
    expect(service.appliedLimit, 500);
    expect(service.savedLimit, 500);
    expect(container.read(settingsProvider).maxHistoryEntries, 500);
  });

  test('backend failure keeps the previous provider value', () async {
    final service = _FakeSettingsService();
    final container = ProviderContainer(
      overrides: [settingsServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(settingsProvider.notifier);
    await notifier.initialize(_MockDawContext());
    service.applyError = Exception('backend rejected limit');

    final result = await notifier.setHistoryLimit(500);

    expect(result.isErr(), isTrue);
    expect(container.read(settingsProvider).maxHistoryEntries, 100);
    expect(container.read(settingsProvider).isApplyingHistoryLimit, isFalse);
  });

  test('failed initialization can be retried', () async {
    final service = _FakeSettingsService()
      ..loadError = Exception('read failed');
    final container = ProviderContainer(
      overrides: [settingsServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(settingsProvider.notifier);

    final failed = await notifier.initialize(_MockDawContext());
    service.loadError = null;
    service.loadedLimit = 25;
    final retried = await notifier.initialize(_MockDawContext());

    expect(failed.isErr(), isTrue);
    expect(retried.isOk(), isTrue);
    expect(container.read(settingsProvider).maxHistoryEntries, 25);
  });
}
