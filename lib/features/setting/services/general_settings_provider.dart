import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/notification_provider.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/features/setting/models/general_settings_state.dart';
import 'package:karbeat/features/setting/services/settings_service.dart';
import 'package:karbeat/src/rust/api/project.dart';

final settingsServiceProvider = Provider<SettingsService>((ref) {
  return SettingsService();
});

class GeneralSettingsNotifier extends Notifier<GeneralSettingsState> {
  bool _initializationStarted = false;
  DawContext? _dawContext;

  @override
  GeneralSettingsState build() => const GeneralSettingsState();

  Future<Result<void>> initialize(DawContext context) async {
    if (_initializationStarted) return Result.ok(null);
    _initializationStarted = true;
    _dawContext = context;
    state = state.copyWith(isApplyingHistoryLimit: true);

    final service = ref.read(settingsServiceProvider);
    final loaded = await service.loadHistoryLimit();
    if (loaded case Error<int>(error: final error)) {
      _initializationStarted = false;
      state = state.copyWith(
        isApplyingHistoryLimit: false,
        isInitialized: false,
      );
      return ref.notifyErrorResult(error, title: 'Could not load settings');
    }

    final applied = await service.applyHistoryLimit(context, loaded.ok());
    if (applied case Error<int>(error: final error)) {
      _initializationStarted = false;
      state = state.copyWith(
        isApplyingHistoryLimit: false,
        isInitialized: false,
      );
      return ref.notifyErrorResult(
        error,
        title: 'Could not apply history limit',
      );
    }

    state = state.copyWith(
      maxHistoryEntries: applied.ok(),
      isApplyingHistoryLimit: false,
      isInitialized: true,
    );
    return Result.ok(null);
  }

  Future<Result<void>> setHistoryLimit(int limit) async {
    final context = _dawContext;
    if (context == null) {
      return ref.notifyErrorResult(
        StateError('General settings have not been initialized'),
        title: 'Could not update history limit',
      );
    }
    if (state.isApplyingHistoryLimit) {
      return Result.error(Exception('History limit update is already running'));
    }

    state = state.copyWith(isApplyingHistoryLimit: true);
    final service = ref.read(settingsServiceProvider);
    final applied = await service.applyHistoryLimit(context, limit);
    if (applied case Error<int>(error: final error)) {
      state = state.copyWith(isApplyingHistoryLimit: false);
      return ref.notifyErrorResult(
        error,
        title: 'Could not update history limit',
      );
    }

    final appliedLimit = applied.ok();
    state = state.copyWith(
      maxHistoryEntries: appliedLimit,
      isApplyingHistoryLimit: false,
    );
    final saved = await service.saveHistoryLimit(appliedLimit);
    if (saved case Error<void>(error: final error)) {
      return ref.notifyErrorResult(
        error,
        title: 'History limit applied but not saved',
      );
    }
    return Result.ok(null);
  }
}

final generalSettingsProvider =
    NotifierProvider<GeneralSettingsNotifier, GeneralSettingsState>(
      GeneralSettingsNotifier.new,
    );
