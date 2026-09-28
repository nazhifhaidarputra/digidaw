import 'package:freezed_annotation/freezed_annotation.dart';

part 'appearance_settings_state.freezed.dart';

enum AppThemeMode { system, light, dark }

enum AppColorPalette { purple, blue, teal, orange, red }

enum AppBackgroundFit { cover, contain, fill }

@freezed
abstract class AppearanceSettingsState with _$AppearanceSettingsState {
  const factory AppearanceSettingsState({
    @Default(AppThemeMode.dark) AppThemeMode themeMode,
    @Default(AppColorPalette.purple) AppColorPalette colorPalette,
    @Default(false) bool isInitialized,
    String? backgroundImagePath,
    @Default(AppBackgroundFit.cover) AppBackgroundFit backgroundFit,
    @Default(0.35) double backgroundOverlayOpacity,
    String? customFontPath,
    String? customFontFamily,
  }) = _AppearanceSettingsState;
}
