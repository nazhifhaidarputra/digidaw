import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/core/utils/logger.dart';

/// Style words a desktop font setting may put after the family name.
const _styleWords = {
  'regular',
  'normal',
  'book',
  'roman',
  'italic',
  'oblique',
  'bold',
  'semibold',
  'semi-bold',
  'demibold',
  'medium',
  'light',
  'extralight',
  'ultralight',
  'thin',
  'heavy',
  'black',
  'extrabold',
  'ultrabold',
  'condensed',
  'semi-condensed',
  'expanded',
  'small-caps',
};

/// The family named by a Pango font description such as `'Cantarell 11'`,
/// `Noto Sans Bold 10` or `JetBrains Mono,  10`; null when it names none.
///
/// GNOME's `font-name` and GTK's `gtk-font-name` use this format: a
/// comma-separated family list, then style words, then a size.
String? pangoFontFamily(String description) {
  var text = description.trim();
  if (text.length >= 2 && text.startsWith("'") && text.endsWith("'")) {
    text = text.substring(1, text.length - 1);
  }
  final words = text
      .replaceAll(',', ' , ')
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList();
  // Drop the size, then the style words, from the end.
  if (words.isNotEmpty && RegExp(r'^\d+(\.\d+)?(px)?$').hasMatch(words.last)) {
    words.removeLast();
  }
  while (words.isNotEmpty &&
      (words.last == ',' || _styleWords.contains(words.last.toLowerCase()))) {
    words.removeLast();
  }
  final first = words.join(' ').split(',').first.trim();
  return first.isEmpty ? null : first;
}

/// The family of the `font` entry in the `[General]` group of a KDE
/// `kdeglobals` file, such as `font=Noto Sans,10,-1,5,400,0,0,0,0,0`; null
/// when the file sets none.
String? kdeFontFamily(String kdeglobals) {
  var inGeneral = false;
  for (final raw in kdeglobals.split('\n')) {
    final line = raw.trim();
    if (line.startsWith('[')) {
      inGeneral = line == '[General]';
      continue;
    }
    if (!inGeneral || !line.startsWith('font=')) continue;
    final family = line.substring('font='.length).split(',').first.trim();
    return family.isEmpty ? null : family;
  }
  return null;
}

/// Finds the font the desktop uses for its interface.
class SystemFontService {
  /// The desktop's interface font family, or null to keep the platform's
  /// default font.
  ///
  /// Windows and macOS need no lookup: the platform default already is the
  /// system font there. A Linux desktop names its font in its own settings,
  /// which Flutter does not read.
  Future<String?> interfaceFontFamily() async {
    if (!Platform.isLinux) return null;
    try {
      return await _linuxFontFamily();
    } on Object catch (error) {
      AppLogger.warn('Could not read the desktop font: $error');
      return null;
    }
  }

  Future<String?> _linuxFontFamily() async {
    final env = Platform.environment;
    final home = env['HOME'];
    final configHome =
        env['XDG_CONFIG_HOME'] ?? (home == null ? null : '$home/.config');
    final desktop = env['XDG_CURRENT_DESKTOP']?.toUpperCase() ?? '';

    if (desktop.contains('KDE') && configHome != null) {
      final family = await _readFamily(
        File('$configHome/kdeglobals'),
        kdeFontFamily,
      );
      if (family != null) return family;
    }

    final gsettings = await _gsettingsFontName();
    if (gsettings != null) {
      final family = pangoFontFamily(gsettings);
      if (family != null) return family;
    }

    if (configHome != null) {
      for (final version in const ['gtk-4.0', 'gtk-3.0']) {
        final family = await _readFamily(
          File('$configHome/$version/settings.ini'),
          _gtkSettingsFontFamily,
        );
        if (family != null) return family;
      }
    }
    return null;
  }

  Future<String?> _readFamily(File file, String? Function(String) parse) async {
    if (!await file.exists()) return null;
    return parse(await file.readAsString());
  }

  /// GNOME's interface font setting, or null without gsettings.
  Future<String?> _gsettingsFontName() async {
    try {
      final result = await Process.run('gsettings', const [
        'get',
        'org.gnome.desktop.interface',
        'font-name',
      ]);
      if (result.exitCode != 0) return null;
      final output = (result.stdout as String).trim();
      return output.isEmpty ? null : output;
    } on ProcessException {
      return null;
    }
  }
}

String? _gtkSettingsFontFamily(String settings) {
  for (final raw in settings.split('\n')) {
    final line = raw.trim();
    if (!line.startsWith('gtk-font-name')) continue;
    final separator = line.indexOf('=');
    if (separator < 0) continue;
    return pangoFontFamily(line.substring(separator + 1));
  }
  return null;
}

final systemFontServiceProvider = Provider<SystemFontService>(
  (ref) => SystemFontService(),
);
