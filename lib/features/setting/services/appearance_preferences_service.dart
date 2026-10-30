import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/features/setting/models/appearance_settings_state.dart';
import 'package:karbeat/features/setting/services/appearance_asset_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef AppearancePreferences = ({
  AppThemeMode themeMode,
  AppColorPalette colorPalette,
  String? backgroundImagePath,
  AppBackgroundFit backgroundFit,
  double backgroundOverlayOpacity,
  String? customFontPath,
  String? customFontFamily,
  String? colorThemeSource,
  List<String> customColorThemePaths,
});

class AppearancePreferencesService {
  static const themeModeKey = 'settings.appearance.theme_mode.v1';
  static const colorPaletteKey = 'settings.appearance.color_palette.v1';
  static const backgroundPathKey = 'settings.appearance.background_path.v1';
  static const backgroundFitKey = 'settings.appearance.background_fit.v1';
  static const backgroundOverlayKey =
      'settings.appearance.background_overlay.v1';
  static const fontPathKey = 'settings.appearance.font_path.v1';
  static const fontFamilyKey = 'settings.appearance.font_family.v1';
  static const colorThemeSourceKey =
      'settings.appearance.color_theme_source.v1';
  static const customColorThemePathsKey =
      'settings.appearance.custom_color_theme_paths.v1';

  /// Stored when the user explicitly picks the accent-palette fallback, so a
  /// missing source can mean "never chosen" and use the bundled default.
  static const explicitDefaultColorThemeSource =
      'settings.appearance.default_color_theme';

  /// Resolves a persisted theme source. A missing key means the user has not
  /// chosen a theme yet, while [explicitDefaultColorThemeSource] means they
  /// deliberately picked the accent-palette fallback.
  static String? resolveColorThemeSource({
    required bool hasStoredSource,
    required String? storedSource,
  }) {
    if (!hasStoredSource) {
      return AppearanceAssetService.defaultColorThemeSource;
    }
    return storedSource == explicitDefaultColorThemeSource
        ? null
        : storedSource;
  }

  /// Held the single loaded theme file before several could be kept.
  static const legacyCustomColorThemePathKey =
      'settings.appearance.custom_color_theme_path.v1';

  Future<Result<AppearancePreferences>> load() {
    return attemptAsync(() async {
      final preferences = SharedPreferencesAsync();
      final themeName = await preferences.getString(themeModeKey);
      final paletteName = await preferences.getString(colorPaletteKey);
      final backgroundPath = await preferences.getString(backgroundPathKey);
      final backgroundFitName = await preferences.getString(backgroundFitKey);
      final storedOverlay = await preferences.getDouble(backgroundOverlayKey);
      final fontPath = await preferences.getString(fontPathKey);
      final fontFamily = await preferences.getString(fontFamilyKey);
      final hasColorThemeSource = await preferences.containsKey(
        colorThemeSourceKey,
      );
      final storedColorThemeSource = hasColorThemeSource
          ? await preferences.getString(colorThemeSourceKey)
          : null;
      final customColorThemePaths =
          await preferences.getStringList(customColorThemePathsKey) ??
          [?await preferences.getString(legacyCustomColorThemePathKey)];
      final theme = AppThemeMode.values
          .where((value) => value.name == themeName)
          .firstOrNull;
      final palette = AppColorPalette.values
          .where((value) => value.name == paletteName)
          .firstOrNull;
      final backgroundFit = AppBackgroundFit.values
          .where((value) => value.name == backgroundFitName)
          .firstOrNull;

      if (themeName != null && theme == null) {
        await preferences.remove(themeModeKey);
      }
      if (paletteName != null && palette == null) {
        await preferences.remove(colorPaletteKey);
      }
      if (backgroundFitName != null && backgroundFit == null) {
        await preferences.remove(backgroundFitKey);
      }
      final overlay =
          storedOverlay != null && storedOverlay >= 0 && storedOverlay <= 0.9
          ? storedOverlay
          : 0.35;
      if (storedOverlay != null && overlay != storedOverlay) {
        await preferences.setDouble(backgroundOverlayKey, overlay);
      }

      return (
        themeMode: theme ?? AppThemeMode.dark,
        colorPalette: palette ?? AppColorPalette.purple,
        backgroundImagePath: backgroundPath,
        backgroundFit: backgroundFit ?? AppBackgroundFit.cover,
        backgroundOverlayOpacity: overlay,
        customFontPath: fontPath,
        customFontFamily: fontFamily,
        colorThemeSource: resolveColorThemeSource(
          hasStoredSource: hasColorThemeSource,
          storedSource: storedColorThemeSource,
        ),
        customColorThemePaths: customColorThemePaths,
      );
    });
  }

  Future<Result<void>> save(AppearancePreferences value) {
    return attemptAsync(() async {
      final preferences = SharedPreferencesAsync();
      await preferences.setString(themeModeKey, value.themeMode.name);
      await preferences.setString(colorPaletteKey, value.colorPalette.name);
      await _writeOptionalString(
        preferences,
        backgroundPathKey,
        value.backgroundImagePath,
      );
      await preferences.setString(backgroundFitKey, value.backgroundFit.name);
      await preferences.setDouble(
        backgroundOverlayKey,
        value.backgroundOverlayOpacity,
      );
      await _writeOptionalString(
        preferences,
        fontPathKey,
        value.customFontPath,
      );
      await _writeOptionalString(
        preferences,
        fontFamilyKey,
        value.customFontFamily,
      );
      await preferences.setString(
        colorThemeSourceKey,
        value.colorThemeSource ?? explicitDefaultColorThemeSource,
      );
      if (value.customColorThemePaths.isEmpty) {
        await preferences.remove(customColorThemePathsKey);
      } else {
        await preferences.setStringList(
          customColorThemePathsKey,
          value.customColorThemePaths,
        );
      }
      await preferences.remove(legacyCustomColorThemePathKey);
    });
  }

  Future<void> _writeOptionalString(
    SharedPreferencesAsync preferences,
    String key,
    String? value,
  ) async {
    if (value == null || value.isEmpty) {
      await preferences.remove(key);
    } else {
      await preferences.setString(key, value);
    }
  }
}
