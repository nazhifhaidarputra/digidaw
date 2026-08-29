import 'package:freezed_annotation/freezed_annotation.dart';

part 'setting_state.freezed.dart';

enum SettingMenu {
  /// General settings (Max number of latest history stored)
  general,

  /// Configure settings for device host (Choosing ASIO or Pipewire, etc) and Input and output devices
  /// Currently input devices are not handled. Only output devices configuration are available
  hostAndDevices,

  /// Set information about the project (Title, Description, Author, Genre, etc)
  project,

  /// Set theme or appearance (Like background image, theme color pallete, Font family used, Dark vs Light mode, etc)
  appearance,

  /// Configure DSP Audio engine buffer size, DSP thread sample rate. DSP thread sample rate is different
  /// from the CPAL sample rate which based on audio device sample rate. The more sample rate of DSP thread is,
  /// the better DSP result is, with the trade-off of performance
  /// (CPAL audio thread never be responsible during DSP processing)
  audio,

  /// Configure key binding
  keyBinding,

  /// Configure plugin scanning and other plugin settings.
  plugins,

  /// Configure and see logging
  log,

  /// Display Info about the app and how to ask and report bug to developers
  info,
}

enum AppThemeMode { system, light, dark }

enum AppColorPalette { purple, blue, teal, orange, red }

enum AppBackgroundFit { cover, contain, fill }

@freezed
abstract class SettingState with _$SettingState {
  const factory SettingState({
    @Default(SettingMenu.general) SettingMenu selectedMenu,
    @Default(100) int maxHistoryEntries,
    @Default(false) bool isApplyingHistoryLimit,
    @Default(false) bool isInitialized,
    @Default(AppThemeMode.dark) AppThemeMode themeMode,
    @Default(AppColorPalette.purple) AppColorPalette colorPalette,
    @Default(false) bool isAppearanceInitialized,
    String? backgroundImagePath,
    @Default(AppBackgroundFit.cover) AppBackgroundFit backgroundFit,
    @Default(0.35) double backgroundOverlayOpacity,
    String? customFontPath,
    String? customFontFamily,
  }) = _SettingState;
}
