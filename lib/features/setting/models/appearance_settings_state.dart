import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:karbeat/features/setting/models/app_color_theme.dart';
import 'package:karbeat/features/setting/models/app_fonts.dart';

part 'appearance_settings_state.freezed.dart';

/// Which font the interface uses.
@freezed
sealed class AppFontChoice with _$AppFontChoice {
  /// The desktop's own interface font.
  const factory AppFontChoice.system() = SystemFontChoice;

  /// A font bundled with the app, one of [AppFonts.bundled].
  const factory AppFontChoice.bundled(String family) = BundledFontChoice;

  /// A TTF or OTF file the user loaded.
  const factory AppFontChoice.file(String path) = FileFontChoice;

  /// The font used until the user picks another one.
  static const AppFontChoice defaultFont = AppFontChoice.bundled(
    AppFonts.defaultFamily,
  );
}

enum AppThemeMode { system, light, dark }

enum AppColorPalette {
  purple,
  blue,
  teal,
  orange,
  red,
  green,
  pink,
  cyan,
  indigo,
  amber,
  lime,
  magenta,
  graphite,
}

enum AppBackgroundFit { cover, contain, fill }

@freezed
abstract class AppearanceSettingsState with _$AppearanceSettingsState {
  const AppearanceSettingsState._();

  const factory AppearanceSettingsState({
    @Default(AppThemeMode.dark) AppThemeMode themeMode,
    @Default(AppColorPalette.purple) AppColorPalette colorPalette,
    @Default(false) bool isInitialized,
    String? backgroundImagePath,
    @Default(AppBackgroundFit.cover) AppBackgroundFit backgroundFit,
    @Default(0.35) double backgroundOverlayOpacity,
    @Default(AppFontChoice.defaultFont) AppFontChoice font,

    /// Family the theme uses for [font]; null leaves the platform's default
    /// font, as [AppFontChoice.system] does when the desktop names none.
    @Default(AppFonts.defaultFamily) String? fontFamily,

    /// Loaded colour themes by source: a bundled asset key or a file path.
    @Default(IMapConst({})) IMap<String, AppColorTheme> colorThemes,

    /// Source of the active colour theme. Without one, the colours come from
    /// [themeMode] and [colorPalette].
    String? colorThemeSource,

    /// Theme files the user loaded, in the order they were loaded.
    @Default(IListConst([])) IList<String> customColorThemePaths,
  }) = _AppearanceSettingsState;

  AppColorTheme? get colorTheme {
    final source = colorThemeSource;
    return source == null ? null : colorThemes[source];
  }
}
