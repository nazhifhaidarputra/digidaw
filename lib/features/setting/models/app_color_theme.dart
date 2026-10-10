import 'dart:ui' show Brightness, Color;

import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_color_theme.freezed.dart';

/// A complete colour theme, as loaded from a JSON theme file.
///
/// The colour roles follow Material's `ColorScheme`. Optional roles that a
/// theme leaves out fall back to the closest required role.
@freezed
abstract class AppColorTheme with _$AppColorTheme {
  const factory AppColorTheme({
    required String name,
    required Brightness brightness,
    required Color primary,
    required Color onPrimary,
    required Color secondary,
    required Color onSecondary,
    required Color error,
    required Color onError,
    required Color surface,
    required Color onSurface,
    Color? primaryContainer,
    Color? onPrimaryContainer,
    Color? secondaryContainer,
    Color? onSecondaryContainer,
    Color? tertiary,
    Color? onTertiary,
    Color? tertiaryContainer,
    Color? onTertiaryContainer,
    Color? errorContainer,
    Color? onErrorContainer,
    Color? onSurfaceVariant,
    Color? surfaceContainerLowest,
    Color? surfaceContainerLow,
    Color? surfaceContainer,
    Color? surfaceContainerHigh,
    Color? surfaceContainerHighest,
    Color? outline,
    Color? outlineVariant,
    Color? inverseSurface,
    Color? onInverseSurface,
    Color? inversePrimary,
  }) = _AppColorTheme;
}
