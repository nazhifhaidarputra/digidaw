import 'package:flutter/material.dart';
import 'package:karbeat/features/setting/models/app_color_theme.dart';
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
    AppColorPalette.green => Colors.green,
    AppColorPalette.pink => Colors.pink,
    AppColorPalette.cyan => Colors.cyan,
    AppColorPalette.indigo => Colors.indigo,
    AppColorPalette.amber => Colors.amber,
    AppColorPalette.lime => Colors.lime,
    AppColorPalette.magenta => const Color(0xFFD500F9),
    AppColorPalette.graphite => Colors.blueGrey,
  };

  /// Theme for a loaded colour theme, which sets its own brightness.
  static ThemeData custom(AppColorTheme theme, {String? fontFamily}) {
    return _fromColorScheme(
      ColorScheme(
        brightness: theme.brightness,
        primary: theme.primary,
        onPrimary: theme.onPrimary,
        primaryContainer: theme.primaryContainer,
        onPrimaryContainer: theme.onPrimaryContainer,
        secondary: theme.secondary,
        onSecondary: theme.onSecondary,
        secondaryContainer: theme.secondaryContainer,
        onSecondaryContainer: theme.onSecondaryContainer,
        tertiary: theme.tertiary,
        onTertiary: theme.onTertiary,
        tertiaryContainer: theme.tertiaryContainer,
        onTertiaryContainer: theme.onTertiaryContainer,
        error: theme.error,
        onError: theme.onError,
        errorContainer: theme.errorContainer,
        onErrorContainer: theme.onErrorContainer,
        surface: theme.surface,
        onSurface: theme.onSurface,
        onSurfaceVariant: theme.onSurfaceVariant,
        surfaceContainerLowest: theme.surfaceContainerLowest,
        surfaceContainerLow: theme.surfaceContainerLow,
        surfaceContainer: theme.surfaceContainer,
        surfaceContainerHigh: theme.surfaceContainerHigh,
        surfaceContainerHighest: theme.surfaceContainerHighest,
        outline: theme.outline,
        outlineVariant: theme.outlineVariant,
        inverseSurface: theme.inverseSurface,
        onInverseSurface: theme.onInverseSurface,
        inversePrimary: theme.inversePrimary,
      ),
      fontFamily: fontFamily,
    );
  }

  static ThemeData _build(
    Brightness brightness,
    AppColorPalette palette, {
    String? fontFamily,
  }) {
    return _fromColorScheme(
      ColorScheme.fromSeed(
        seedColor: seedColor(palette),
        brightness: brightness,
      ),
      fontFamily: fontFamily,
    );
  }

  static ThemeData _fromColorScheme(
    ColorScheme colorScheme, {
    String? fontFamily,
  }) {
    return ThemeData(
      useMaterial3: true,
      brightness: colorScheme.brightness,
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
