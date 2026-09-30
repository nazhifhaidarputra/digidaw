import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/features/setting/services/general_settings_provider.dart';
import 'package:karbeat/features/setting/services/settings_service.dart';
import 'package:karbeat/src/rust/api/mitigation.dart';
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

  UiAutoSaveSettings loadedAutoSave = const UiAutoSaveSettings(
    isEnabled: true,
    intervalSeconds: 300,
  );
  UiAutoSaveSettings? appliedAutoSave;
  UiAutoSaveSettings? savedAutoSave;
  Exception? autoSaveApplyError;

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

  @override
  Future<Result<UiAutoSaveSettings>> loadAutoSaveSettings() async {
    return Result.ok(loadedAutoSave);
  }

  @override
  Future<Result<UiAutoSaveSettings>> applyAutoSaveSettings(
    DawContext context,
    UiAutoSaveSettings settings,
  ) async {
    final error = autoSaveApplyError;
    if (error != null) return Result.error(error);
    appliedAutoSave = settings;
    return Result.ok(settings);
  }

  @override
  Future<Result<void>> saveAutoSaveSettings(UiAutoSaveSettings settings) async {
    savedAutoSave = settings;
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
        .read(generalSettingsProvider.notifier)
        .initialize(_MockDawContext());

    expect(result.isOk(), isTrue);
    expect(service.appliedLimit, 250);
    expect(container.read(generalSettingsProvider).maxHistoryEntries, 250);
    expect(container.read(generalSettingsProvider).isInitialized, isTrue);
  });

  test('update publishes the applied value and persists it', () async {
    final service = _FakeSettingsService();
    final container = ProviderContainer(
      overrides: [settingsServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(generalSettingsProvider.notifier);
    await notifier.initialize(_MockDawContext());

    final result = await notifier.setHistoryLimit(500);

    expect(result.isOk(), isTrue);
    expect(service.appliedLimit, 500);
    expect(service.savedLimit, 500);
    expect(container.read(generalSettingsProvider).maxHistoryEntries, 500);
  });

  test('backend failure keeps the previous provider value', () async {
    final service = _FakeSettingsService();
    final container = ProviderContainer(
      overrides: [settingsServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(generalSettingsProvider.notifier);
    await notifier.initialize(_MockDawContext());
    service.applyError = Exception('backend rejected limit');

    final result = await notifier.setHistoryLimit(500);

    expect(result.isErr(), isTrue);
    expect(container.read(generalSettingsProvider).maxHistoryEntries, 100);
    expect(
      container.read(generalSettingsProvider).isApplyingHistoryLimit,
      isFalse,
    );
  });

  test(
    'initialize restores and applies persisted auto save settings',
    () async {
      final service = _FakeSettingsService()
        ..loadedAutoSave = const UiAutoSaveSettings(
          isEnabled: false,
          intervalSeconds: 600,
        );
      final container = ProviderContainer(
        overrides: [settingsServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);

      final result = await container
          .read(generalSettingsProvider.notifier)
          .initialize(_MockDawContext());

      final state = container.read(generalSettingsProvider);
      expect(result.isOk(), isTrue);
      expect(service.appliedAutoSave, service.loadedAutoSave);
      expect(state.autoSaveEnabled, isFalse);
      expect(state.autoSaveIntervalSeconds, 600);
      expect(state.isApplyingAutoSave, isFalse);
    },
  );

  test('auto save changes are applied then persisted', () async {
    final service = _FakeSettingsService();
    final container = ProviderContainer(
      overrides: [settingsServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(generalSettingsProvider.notifier);
    await notifier.initialize(_MockDawContext());

    await notifier.setAutoSaveInterval(120);
    final disabled = await notifier.setAutoSaveEnabled(false);

    const expected = UiAutoSaveSettings(isEnabled: false, intervalSeconds: 120);
    expect(disabled.isOk(), isTrue);
    expect(service.appliedAutoSave, expected);
    expect(service.savedAutoSave, expected);
    expect(container.read(generalSettingsProvider).autoSaveEnabled, isFalse);
    expect(
      container.read(generalSettingsProvider).autoSaveIntervalSeconds,
      120,
    );
  });

  test('rejected auto save change keeps the previous settings', () async {
    final service = _FakeSettingsService();
    final container = ProviderContainer(
      overrides: [settingsServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(generalSettingsProvider.notifier);
    await notifier.initialize(_MockDawContext());
    service.autoSaveApplyError = Exception('backend rejected interval');

    final result = await notifier.setAutoSaveInterval(30);

    final state = container.read(generalSettingsProvider);
    expect(result.isErr(), isTrue);
    expect(state.autoSaveIntervalSeconds, 300);
    expect(state.isApplyingAutoSave, isFalse);
    expect(service.savedAutoSave, isNull);
  });

  test('failed initialization can be retried', () async {
    final service = _FakeSettingsService()
      ..loadError = Exception('read failed');
    final container = ProviderContainer(
      overrides: [settingsServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(generalSettingsProvider.notifier);

    final failed = await notifier.initialize(_MockDawContext());
    service.loadError = null;
    service.loadedLimit = 25;
    final retried = await notifier.initialize(_MockDawContext());

    expect(failed.isErr(), isTrue);
    expect(retried.isOk(), isTrue);
    expect(container.read(generalSettingsProvider).maxHistoryEntries, 25);
  });
}
