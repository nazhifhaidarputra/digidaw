import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/notification_provider.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/features/setting/models/setting_state.dart';
import 'package:karbeat/features/setting/services/appearance_asset_service.dart';
import 'package:karbeat/features/setting/services/appearance_preferences_service.dart';
import 'package:karbeat/features/setting/services/settings_service.dart';
import 'package:karbeat/src/rust/api/project.dart';

final settingsServiceProvider = Provider<SettingsService>((ref) {
  return SettingsService();
});

final appearancePreferencesServiceProvider =
    Provider<AppearancePreferencesService>((ref) {
      return AppearancePreferencesService();
    });

class SettingsNotifier extends Notifier<SettingState> {
  bool _initializationStarted = false;
  bool _appearanceInitializationStarted = false;
  DawContext? _dawContext;

  @override
  SettingState build() => const SettingState();

  void selectMenu(SettingMenu menu) {
    if (state.selectedMenu == menu) return;
    state = state.copyWith(selectedMenu: menu);
  }

  Future<Result<void>> initializeAppearance() async {
    if (_appearanceInitializationStarted) return Result.ok(null);
    _appearanceInitializationStarted = true;
    final loaded = await ref.read(appearancePreferencesServiceProvider).load();
    if (loaded case Error<AppearancePreferences>(error: final error)) {
      _appearanceInitializationStarted = false;
      return ref.notifyErrorResult(
        error,
        title: 'Could not load appearance settings',
      );
    }

    final appearance = loaded.ok();
    final assets = ref.read(appearanceAssetServiceProvider);
    var backgroundPath = appearance.backgroundImagePath;
    if (backgroundPath != null) {
      final exists = await assets.fileExists(backgroundPath);
      if (exists.isErr() || !exists.ok()) {
        ref
            .read(notificationProvider.notifier)
            .warn(
              'The saved background image is unavailable. The default background is being used.',
              title: 'Background image unavailable',
            );
        backgroundPath = null;
      }
    }
    var fontPath = appearance.customFontPath;
    var fontFamily = appearance.customFontFamily;
    if (fontPath != null && fontFamily != null) {
      final loadedFont = await assets.loadFont(fontPath, fontFamily);
      if (loadedFont.isErr()) {
        ref
            .read(notificationProvider.notifier)
            .warn(
              'The saved custom font is unavailable. The system font is being used.',
              title: 'Custom font unavailable',
            );
        fontPath = null;
        fontFamily = null;
      }
    } else {
      fontPath = null;
      fontFamily = null;
    }
    state = state.copyWith(
      themeMode: appearance.themeMode,
      colorPalette: appearance.colorPalette,
      backgroundImagePath: backgroundPath,
      backgroundFit: appearance.backgroundFit,
      backgroundOverlayOpacity: appearance.backgroundOverlayOpacity,
      customFontPath: fontPath,
      customFontFamily: fontFamily,
      isAppearanceInitialized: true,
    );
    if (backgroundPath != appearance.backgroundImagePath ||
        fontPath != appearance.customFontPath) {
      await _persistAppearance(state);
    }
    return Result.ok(null);
  }

  Future<Result<void>> setThemeMode(AppThemeMode themeMode) {
    return _persistAppearance(state.copyWith(themeMode: themeMode));
  }

  Future<Result<void>> setColorPalette(AppColorPalette palette) {
    return _persistAppearance(state.copyWith(colorPalette: palette));
  }

  Future<Result<void>> setBackgroundFit(AppBackgroundFit fit) {
    return _persistAppearance(state.copyWith(backgroundFit: fit));
  }

  Future<Result<void>> setBackgroundOverlayOpacity(double opacity) {
    final clamped = opacity.clamp(0.0, 0.9);
    return _persistAppearance(
      state.copyWith(backgroundOverlayOpacity: clamped),
    );
  }

  Future<Result<void>> chooseBackgroundImage() async {
    final picked = await ref
        .read(appearanceAssetServiceProvider)
        .pickBackgroundImage();
    if (picked case Error<String?>(error: final error)) {
      return ref.notifyErrorResult(
        error,
        title: 'Could not choose background image',
      );
    }
    final path = picked.ok();
    if (path == null) return Result.ok(null);
    return _persistAppearance(state.copyWith(backgroundImagePath: path));
  }

  Future<Result<void>> clearBackgroundImage() {
    return _persistAppearance(state.copyWith(backgroundImagePath: null));
  }

  Future<Result<void>> chooseCustomFont() async {
    final assets = ref.read(appearanceAssetServiceProvider);
    final picked = await assets.pickFontFile();
    if (picked case Error<String?>(error: final error)) {
      return ref.notifyErrorResult(error, title: 'Could not choose font');
    }
    final path = picked.ok();
    if (path == null) return Result.ok(null);
    final family = 'DigiDAWCustomFont${DateTime.now().microsecondsSinceEpoch}';
    final loaded = await assets.loadFont(path, family);
    if (loaded case Error<void>(error: final error)) {
      return ref.notifyErrorResult(error, title: 'Could not load font');
    }
    return _persistAppearance(
      state.copyWith(customFontPath: path, customFontFamily: family),
    );
  }

  Future<Result<void>> clearCustomFont() {
    return _persistAppearance(
      state.copyWith(customFontPath: null, customFontFamily: null),
    );
  }

  Future<Result<void>> _persistAppearance(SettingState nextState) async {
    state = nextState;
    final saved = await ref.read(appearancePreferencesServiceProvider).save((
      themeMode: state.themeMode,
      colorPalette: state.colorPalette,
      backgroundImagePath: state.backgroundImagePath,
      backgroundFit: state.backgroundFit,
      backgroundOverlayOpacity: state.backgroundOverlayOpacity,
      customFontPath: state.customFontPath,
      customFontFamily: state.customFontFamily,
    ));
    if (saved case Error<void>(error: final error)) {
      return ref.notifyErrorResult(
        error,
        title: 'Appearance changed but not saved',
      );
    }
    return Result.ok(null);
  }

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

    final desiredLimit = loaded.ok();
    final applied = await service.applyHistoryLimit(context, desiredLimit);
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
        StateError('Settings have not been initialized'),
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

final settingsProvider = NotifierProvider<SettingsNotifier, SettingState>(
  SettingsNotifier.new,
);
