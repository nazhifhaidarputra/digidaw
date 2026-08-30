import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/notification_provider.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/features/setting/models/appearance_settings_state.dart';
import 'package:karbeat/features/setting/services/appearance_asset_service.dart';
import 'package:karbeat/features/setting/services/appearance_preferences_service.dart';

final appearancePreferencesServiceProvider =
    Provider<AppearancePreferencesService>((ref) {
      return AppearancePreferencesService();
    });

class AppearanceSettingsNotifier extends Notifier<AppearanceSettingsState> {
  bool _initializationStarted = false;

  @override
  AppearanceSettingsState build() => const AppearanceSettingsState();

  Future<Result<void>> initialize() async {
    if (_initializationStarted) return Result.ok(null);
    _initializationStarted = true;
    final loaded = await ref.read(appearancePreferencesServiceProvider).load();
    if (loaded case Error<AppearancePreferences>(error: final error)) {
      _initializationStarted = false;
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

    state = AppearanceSettingsState(
      themeMode: appearance.themeMode,
      colorPalette: appearance.colorPalette,
      backgroundImagePath: backgroundPath,
      backgroundFit: appearance.backgroundFit,
      backgroundOverlayOpacity: appearance.backgroundOverlayOpacity,
      customFontPath: fontPath,
      customFontFamily: fontFamily,
      isInitialized: true,
    );
    if (backgroundPath != appearance.backgroundImagePath ||
        fontPath != appearance.customFontPath) {
      await _persist(state);
    }
    return Result.ok(null);
  }

  Future<Result<void>> setThemeMode(AppThemeMode themeMode) {
    return _persist(state.copyWith(themeMode: themeMode));
  }

  Future<Result<void>> setColorPalette(AppColorPalette palette) {
    return _persist(state.copyWith(colorPalette: palette));
  }

  Future<Result<void>> setBackgroundFit(AppBackgroundFit fit) {
    return _persist(state.copyWith(backgroundFit: fit));
  }

  Future<Result<void>> setBackgroundOverlayOpacity(double opacity) {
    return _persist(
      state.copyWith(backgroundOverlayOpacity: opacity.clamp(0.0, 0.9)),
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
    return _persist(state.copyWith(backgroundImagePath: path));
  }

  Future<Result<void>> clearBackgroundImage() {
    return _persist(state.copyWith(backgroundImagePath: null));
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
    return _persist(
      state.copyWith(customFontPath: path, customFontFamily: family),
    );
  }

  Future<Result<void>> clearCustomFont() {
    return _persist(
      state.copyWith(customFontPath: null, customFontFamily: null),
    );
  }

  Future<Result<void>> _persist(AppearanceSettingsState nextState) async {
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
}

final appearanceSettingsProvider =
    NotifierProvider<AppearanceSettingsNotifier, AppearanceSettingsState>(
      AppearanceSettingsNotifier.new,
    );
