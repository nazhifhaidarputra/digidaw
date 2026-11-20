import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/features/setting/models/app_fonts.dart';
import 'package:karbeat/features/setting/models/appearance_settings_state.dart';
import 'package:karbeat/features/setting/services/appearance_asset_service.dart';
import 'package:karbeat/src/rust/api/settings.dart' as settings_api;

typedef AppearancePreferences = ({
  AppThemeMode themeMode,
  AppColorPalette colorPalette,
  String? backgroundImagePath,
  AppBackgroundFit backgroundFit,
  double backgroundOverlayOpacity,
  AppFontChoice font,
  String? colorThemeSource,
  List<String> customColorThemePaths,
});

/// Stores the appearance settings. Rust brings a stored overlay opacity back
/// into range and drops values it cannot read.
class AppearancePreferencesService {
  /// The color theme source for a stored [choice]. The bundled theme maps to
  /// [AppearanceAssetService.defaultColorThemeSource], and the accent palette
  /// to null.
  static String? colorThemeSourceFromStored(
    settings_api.UiColorThemeChoice choice,
  ) {
    return switch (choice) {
      settings_api.UiColorThemeChoice_Bundled() =>
        AppearanceAssetService.defaultColorThemeSource,
      settings_api.UiColorThemeChoice_AccentPalette() => null,
      settings_api.UiColorThemeChoice_Source(:final field0) => field0,
    };
  }

  /// The stored choice for a color theme [source]; the reverse of
  /// [colorThemeSourceFromStored].
  static settings_api.UiColorThemeChoice colorThemeSourceToStored(
    String? source,
  ) {
    return switch (source) {
      null => const settings_api.UiColorThemeChoice.accentPalette(),
      AppearanceAssetService.defaultColorThemeSource =>
        const settings_api.UiColorThemeChoice.bundled(),
      final source => settings_api.UiColorThemeChoice.source(source),
    };
  }

  /// The font choice for a stored [choice]. The stored default maps to
  /// [AppFontChoice.defaultFont].
  static AppFontChoice fontFromStored(settings_api.UiFontChoice choice) {
    return switch (choice) {
      settings_api.UiFontChoice_Default() => AppFontChoice.defaultFont,
      settings_api.UiFontChoice_System() => const AppFontChoice.system(),
      settings_api.UiFontChoice_Bundled(:final field0) => AppFontChoice.bundled(
        field0,
      ),
      settings_api.UiFontChoice_File(:final field0) => AppFontChoice.file(
        field0,
      ),
    };
  }

  /// The stored choice for [font]; the reverse of [fontFromStored]. The
  /// default font is stored as the default, not by name, so a later default
  /// applies to users who never picked a font.
  static settings_api.UiFontChoice fontToStored(AppFontChoice font) {
    return switch (font) {
      SystemFontChoice() => const settings_api.UiFontChoice.system(),
      BundledFontChoice(:final family) when family == AppFonts.defaultFamily =>
        const settings_api.UiFontChoice.default_(),
      BundledFontChoice(:final family) => settings_api.UiFontChoice.bundled(
        family,
      ),
      FileFontChoice(:final path) => settings_api.UiFontChoice.file(path),
    };
  }

  Future<Result<AppearancePreferences>> load() {
    return attemptAsync(() async {
      final stored = await settings_api.loadAppearanceSettings();
      return (
        themeMode: AppThemeMode.values.byName(stored.themeMode.name),
        colorPalette: AppColorPalette.values.byName(stored.colorPalette.name),
        backgroundImagePath: stored.backgroundImage,
        backgroundFit: AppBackgroundFit.values.byName(
          stored.backgroundFit.name,
        ),
        backgroundOverlayOpacity: stored.backgroundOverlay,
        font: fontFromStored(stored.font),
        colorThemeSource: colorThemeSourceFromStored(stored.colorTheme),
        customColorThemePaths: stored.customColorThemePaths,
      );
    });
  }

  Future<Result<void>> save(AppearancePreferences value) {
    return attemptAsync(
      () => settings_api.saveAppearanceSettings(
        settings: settings_api.UiAppearanceSettings(
          themeMode: settings_api.UiThemeMode.values.byName(
            value.themeMode.name,
          ),
          colorPalette: settings_api.UiColorPalette.values.byName(
            value.colorPalette.name,
          ),
          backgroundImage: value.backgroundImagePath,
          backgroundFit: settings_api.UiBackgroundFit.values.byName(
            value.backgroundFit.name,
          ),
          backgroundOverlay: value.backgroundOverlayOpacity,
          font: fontToStored(value.font),
          colorTheme: colorThemeSourceToStored(value.colorThemeSource),
          customColorThemePaths: value.customColorThemePaths,
        ),
      ),
    );
  }
}
