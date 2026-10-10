import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:karbeat/features/setting/models/app_color_theme.dart';

part 'appearance_settings_state.freezed.dart';

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
    String? customFontPath,
    String? customFontFamily,

    /// Loaded colour themes by source: a bundled asset key or a file path.
    @Default(IMapConst({})) IMap<String, AppColorTheme> colorThemes,

    /// Source of the active colour theme. Without one, the colours come from
    /// [themeMode] and [colorPalette].
    String? colorThemeSource,
    String? customColorThemePath,
  }) = _AppearanceSettingsState;

  AppColorTheme? get colorTheme {
    final source = colorThemeSource;
    return source == null ? null : colorThemes[source];
  }
}
