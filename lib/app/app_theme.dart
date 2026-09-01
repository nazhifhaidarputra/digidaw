import 'package:flutter/material.dart';
import 'package:karbeat/features/setting/models/appearance_settings_state.dart';

abstract final class AppTheme {
  static ThemeMode themeMode(AppThemeMode mode) => switch (mode) {
    AppThemeMode.system => ThemeMode.system,
    AppThemeMode.light => ThemeMode.light,
    AppThemeMode.dark => ThemeMode.dark,
  };

  static ThemeData light(AppColorPalette palette, {String? fontFamily}) {
    return _build(Brightness.light, palette, fontFamily: fontFamily);
  }

  static ThemeData dark(AppColorPalette palette, {String? fontFamily}) {
    return _build(Brightness.dark, palette, fontFamily: fontFamily);
  }

  static Color seedColor(AppColorPalette palette) => switch (palette) {
    AppColorPalette.purple => Colors.purple,
    AppColorPalette.blue => Colors.blue,
    AppColorPalette.teal => Colors.teal,
    AppColorPalette.orange => Colors.orange,
    AppColorPalette.red => Colors.red,
  };

  static ThemeData _build(
    Brightness brightness,
    AppColorPalette palette, {
    String? fontFamily,
  }) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor(palette),
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: colorScheme.surface,
      canvasColor: colorScheme.surface,
      dividerColor: colorScheme.outlineVariant,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surfaceContainer,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colorScheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
      ),
      inputDecorationTheme: const InputDecorationTheme(isDense: true),
      listTileTheme: const ListTileThemeData(dense: true),
    );
  }
}
