import 'dart:convert';
import 'dart:ui' show Brightness, Color;

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/features/setting/models/app_color_theme.dart';

const maxColorThemeNameLength = 48;

/// Every problem found in a JSON theme, so a theme author can fix them in
/// one pass.
class ColorThemeFormatException implements Exception {
  const ColorThemeFormatException(this.issues);

  final IList<String> issues;

  @override
  String toString() => 'Invalid color theme:\n${issues.join('\n')}';
}

/// Parses and validates a JSON colour theme.
///
/// The format is documented in `assets/themes/README.md`.
Result<AppColorTheme> parseColorTheme(String source) {
  final decoded = attempt<Object?>(() => jsonDecode(source));
  if (decoded case Error<Object?>(:final error)) {
    final reason = error is FormatException ? error.message : error.toString();
    return _invalid(['The file is not valid JSON: $reason']);
  }
  final root = decoded.ok();
  if (root is! Map<String, dynamic>) {
    return _invalid(['The theme must be a JSON object.']);
  }

  final issues = <String>[];
  for (final key in root.keys) {
    if (!const {'name', 'brightness', 'colors'}.contains(key)) {
      issues.add('Unknown field "$key".');
    }
  }

  final name = _parseName(root['name'], issues);
  final brightness = _parseBrightness(root['brightness'], issues);
  final rawColors = root['colors'];
  if (rawColors is! Map<String, dynamic>) {
    issues.add(
      rawColors == null
          ? 'Missing "colors".'
          : '"colors" must be an object of colour roles.',
    );
    return _invalid(issues);
  }

  final colors = _ColorReader(rawColors, issues);
  final theme = AppColorTheme(
    name: name,
    brightness: brightness,
    primary: colors.required('primary'),
    onPrimary: colors.required('onPrimary'),
    secondary: colors.required('secondary'),
    onSecondary: colors.required('onSecondary'),
    error: colors.required('error'),
    onError: colors.required('onError'),
    surface: colors.required('surface'),
    onSurface: colors.required('onSurface'),
    primaryContainer: colors.optional('primaryContainer'),
    onPrimaryContainer: colors.optional('onPrimaryContainer'),
    secondaryContainer: colors.optional('secondaryContainer'),
    onSecondaryContainer: colors.optional('onSecondaryContainer'),
    tertiary: colors.optional('tertiary'),
    onTertiary: colors.optional('onTertiary'),
    tertiaryContainer: colors.optional('tertiaryContainer'),
    onTertiaryContainer: colors.optional('onTertiaryContainer'),
    errorContainer: colors.optional('errorContainer'),
    onErrorContainer: colors.optional('onErrorContainer'),
    onSurfaceVariant: colors.optional('onSurfaceVariant'),
    surfaceContainerLowest: colors.optional('surfaceContainerLowest'),
    surfaceContainerLow: colors.optional('surfaceContainerLow'),
    surfaceContainer: colors.optional('surfaceContainer'),
    surfaceContainerHigh: colors.optional('surfaceContainerHigh'),
    surfaceContainerHighest: colors.optional('surfaceContainerHighest'),
    outline: colors.optional('outline'),
    outlineVariant: colors.optional('outlineVariant'),
    inverseSurface: colors.optional('inverseSurface'),
    onInverseSurface: colors.optional('onInverseSurface'),
    inversePrimary: colors.optional('inversePrimary'),
  );
  colors.reportUnknownRoles();

  if (issues.isNotEmpty) return _invalid(issues);
  return Result.ok(theme);
}

Result<AppColorTheme> _invalid(List<String> issues) {
  return Result.error(ColorThemeFormatException(issues.lock));
}

String _parseName(Object? value, List<String> issues) {
  if (value == null) {
    issues.add('Missing "name".');
    return '';
  }
  if (value is! String) {
    issues.add('"name" must be text.');
    return '';
  }
  final name = value.trim();
  if (name.isEmpty) {
    issues.add('"name" must not be empty.');
  } else if (name.length > maxColorThemeNameLength) {
    issues.add(
      '"name" must be at most $maxColorThemeNameLength characters long.',
    );
  }
  return name;
}

Brightness _parseBrightness(Object? value, List<String> issues) {
  switch (value) {
    case 'light':
      return Brightness.light;
    case 'dark':
      return Brightness.dark;
    case null:
      issues.add('Missing "brightness".');
    default:
      issues.add('"brightness" must be "light" or "dark".');
  }
  return Brightness.dark;
}

/// Reads colour roles from the `colors` object, recording every problem and
/// which roles were asked for.
class _ColorReader {
  _ColorReader(this._colors, this._issues);

  static final _hexColor = RegExp(r'^#(?:[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$');
  static const _placeholder = Color(0x00000000);

  final Map<String, dynamic> _colors;
  final List<String> _issues;
  final Set<String> _knownRoles = {};

  Color required(String role) {
    final color = optional(role);
    if (color == null && !_colors.containsKey(role)) {
      _issues.add('Missing required colour "$role".');
    }
    return color ?? _placeholder;
  }

  Color? optional(String role) {
    _knownRoles.add(role);
    if (!_colors.containsKey(role)) return null;
    final value = _colors[role];
    if (value is! String || !_hexColor.hasMatch(value)) {
      _issues.add(
        'Colour "$role" must be written as "#RRGGBB" or "#RRGGBBAA".',
      );
      return null;
    }
    final digits = value.substring(1);
    final rgb = int.parse(digits.substring(0, 6), radix: 16);
    final alpha = digits.length == 8
        ? int.parse(digits.substring(6), radix: 16)
        : 0xFF;
    return Color(alpha << 24 | rgb);
  }

  void reportUnknownRoles() {
    for (final role in _colors.keys) {
      if (!_knownRoles.contains(role)) {
        _issues.add('Unknown colour "$role".');
      }
    }
  }
}
