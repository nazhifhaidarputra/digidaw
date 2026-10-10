import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:karbeat/features/setting/models/app_color_theme.dart';
import 'package:karbeat/features/setting/services/appearance_asset_service.dart';
import 'package:karbeat/features/setting/services/color_theme_parser.dart';

Map<String, Object?> _theme() => {
  'name': 'Studio',
  'brightness': 'dark',
  'colors': <String, Object?>{
    'primary': '#cba6f7',
    'onPrimary': '#11111b',
    'secondary': '#89b4fa',
    'onSecondary': '#11111b',
    'error': '#f38ba8',
    'onError': '#11111b',
    'surface': '#1e1e2e',
    'onSurface': '#cdd6f4',
  },
};

Map<String, Object?> _colors(Map<String, Object?> theme) =>
    theme['colors']! as Map<String, Object?>;

List<String> _issues(Object? theme) {
  final result = parseColorTheme(theme is String ? theme : jsonEncode(theme));
  expect(result.isErr(), isTrue);
  return (result.err() as ColorThemeFormatException).issues.toList();
}

void main() {
  test('parses a minimal theme into the concrete type', () {
    final theme = parseColorTheme(jsonEncode(_theme())).ok();

    expect(theme.name, 'Studio');
    expect(theme.brightness, Brightness.dark);
    expect(theme.primary, const Color(0xFFCBA6F7));
    expect(theme.onSurface, const Color(0xFFCDD6F4));
    expect(theme.outline, isNull);
  });

  test('parses optional roles, alpha, and trims the name', () {
    final source = _theme()..['name'] = '  Studio  ';
    _colors(source)
      ..['outline'] = '#6C708680'
      ..['surfaceContainerHigh'] = '#313244';

    final theme = parseColorTheme(jsonEncode(source)).ok();

    expect(theme.name, 'Studio');
    expect(theme.outline, const Color(0x806C7086));
    expect(theme.surfaceContainerHigh, const Color(0xFF313244));
  });

  test('rejects text that is not a JSON object', () {
    expect(_issues('{not json'), [startsWith('The file is not valid JSON')]);
    expect(_issues('[]'), ['The theme must be a JSON object.']);
  });

  test('reports every problem at once', () {
    final source = _theme()
      ..['name'] = ' '
      ..['brightness'] = 'dim'
      ..['author'] = 'me';
    _colors(source)
      ..remove('primary')
      ..['onPrimary'] = 'red'
      ..['surface'] = 12
      ..['error'] = '#fff'
      ..['primry'] = '#cba6f7';

    expect(
      _issues(source),
      unorderedEquals([
        'Unknown field "author".',
        '"name" must not be empty.',
        '"brightness" must be "light" or "dark".',
        'Missing required colour "primary".',
        'Colour "onPrimary" must be written as "#RRGGBB" or "#RRGGBBAA".',
        'Colour "surface" must be written as "#RRGGBB" or "#RRGGBBAA".',
        'Colour "error" must be written as "#RRGGBB" or "#RRGGBBAA".',
        'Unknown colour "primry".',
      ]),
    );
  });

  test('reports missing and mistyped top-level fields', () {
    expect(_issues(<String, Object?>{}), [
      'Missing "name".',
      'Missing "brightness".',
      'Missing "colors".',
    ]);
    expect(_issues({'name': 3, 'brightness': 'light', 'colors': 'purple'}), [
      '"name" must be text.',
      '"colors" must be an object of colour roles.',
    ]);
    expect(_issues(_theme()..['name'] = 'x' * (maxColorThemeNameLength + 1)), [
      '"name" must be at most 48 characters long.',
    ]);
  });

  test('every bundled theme is valid', () {
    for (final asset in AppearanceAssetService.bundledColorThemes) {
      final result = parseColorTheme(File(asset).readAsStringSync());
      expect(result.isOk(), isTrue, reason: '$asset: $result');
      expect(result.ok(), isA<AppColorTheme>());
    }
  });
}
