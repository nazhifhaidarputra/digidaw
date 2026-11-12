import 'dart:io';

import 'package:karbeat/core/l10n/localizer.dart';

/// Where the Fluent files live, relative to the project root tests run in.
const localesPath = 'rust/karbeat-l10n/locales';

/// Formats messages from the real Fluent files without the Rust library, so
/// widget tests see the same English text the app shows.
///
/// It reads the subset of Fluent the app uses: messages, terms, `{ $var }`,
/// message and term references, string literals and selectors. Plurals follow
/// English rules in every language, which is enough for tests.
final class FtlTestLocalizer implements Localizer {
  FtlTestLocalizer({this.languageCode = 'en-US'});

  /// The language [format] uses.
  String languageCode;

  final _catalogs = <String, Map<String, String>>{};

  @override
  String format(String id, Map<String, Object> args) =>
      formatIn(languageCode, id, args);

  @override
  String formatIn(String languageCode, String id, Map<String, Object> args) {
    final pattern =
        _catalog(languageCode)[id] ??
        _catalog('en-US')[id] ??
        (throw StateError('No en-US message "$id"'));
    return _Formatter(this, languageCode, args).pattern(pattern);
  }

  @override
  void languageChanged() {}

  /// Every message id of the English files.
  Set<String> get messageIds =>
      _catalog('en-US').keys.where((id) => !id.startsWith('-')).toSet();

  Map<String, String> _catalog(String code) =>
      _catalogs.putIfAbsent(code, () => parseFtlFolder('$localesPath/$code'));
}

/// Parses every `.ftl` file in [folder] into id → pattern text; terms keep
/// their leading `-`.
Map<String, String> parseFtlFolder(String folder) {
  final entries = <String, String>{};
  final directory = Directory(folder);
  if (!directory.existsSync()) return entries;
  for (final file in directory.listSync().whereType<File>()) {
    if (file.path.endsWith('.ftl')) {
      entries.addAll(parseFtl(file.readAsStringSync()));
    }
  }
  return entries;
}

final _entryStart = RegExp(r'^(-?[a-zA-Z][a-zA-Z0-9_-]*)\s*=\s?(.*)$');

/// Parses messages and terms of one Fluent file; attributes are skipped.
Map<String, String> parseFtl(String source) {
  final entries = <String, String>{};
  String? id;
  final lines = <String>[];
  void finish() {
    if (id != null) entries[id!] = _dedent(lines);
    id = null;
    lines.clear();
  }

  for (final line in source.split('\n')) {
    final start = _entryStart.firstMatch(line);
    if (start != null) {
      finish();
      id = start.group(1);
      lines.add(start.group(2)!);
    } else if (line.startsWith('#') || line.trim().isEmpty) {
      if (line.startsWith('#')) finish();
      if (id != null && line.trim().isEmpty) lines.add('');
    } else if (id != null && line.trimLeft().startsWith('.')) {
      // Attributes are not used by the app.
    } else if (id != null) {
      lines.add(line);
    }
  }
  finish();
  return entries;
}

String _dedent(List<String> lines) {
  final first = lines.first.trim();
  final rest = lines.skip(1).toList();
  while (rest.isNotEmpty && rest.last.trim().isEmpty) {
    rest.removeLast();
  }
  final indents = [
    for (final line in rest)
      if (line.trim().isNotEmpty) line.length - line.trimLeft().length,
  ];
  final indent = indents.isEmpty ? 0 : indents.reduce((a, b) => a < b ? a : b);
  final body = [
    for (final line in rest)
      line.length >= indent ? line.substring(indent) : '',
  ];
  return [if (first.isNotEmpty) first, ...body].join('\n');
}

class _Formatter {
  _Formatter(this.localizer, this.languageCode, this.args);

  final FtlTestLocalizer localizer;
  final String languageCode;
  final Map<String, Object> args;

  String pattern(String text) {
    final out = StringBuffer();
    var i = 0;
    while (i < text.length) {
      if (text[i] == '{') {
        final end = _closing(text, i);
        out.write(_placeable(text.substring(i + 1, end).trim()));
        i = end + 1;
      } else {
        out.write(text[i]);
        i++;
      }
    }
    return out.toString();
  }

  String _placeable(String inner) {
    final arrow = _topLevel(inner, '->');
    if (arrow >= 0) {
      final selector = _value(inner.substring(0, arrow).trim());
      return _select(selector, inner.substring(arrow + 2));
    }
    return _display(_value(inner));
  }

  Object _value(String expression) {
    if (expression.startsWith(r'$')) {
      final name = expression.substring(1);
      return args[name] ?? '{\$$name}';
    }
    if (expression.startsWith('"') && expression.endsWith('"')) {
      return expression.substring(1, expression.length - 1);
    }
    if (expression.startsWith('{')) {
      return pattern(expression);
    }
    if (num.tryParse(expression) case final number?) return number;
    return localizer.formatIn(languageCode, expression, args);
  }

  String _select(Object selector, String variantsText) {
    final variants = <String, String>{};
    String? defaultKey;
    final starts = RegExp(r'(\*?)\[([^\]]+)\]');
    var depth = 0;
    final positions = <(int, Match)>[];
    for (var i = 0; i < variantsText.length; i++) {
      final char = variantsText[i];
      if (char == '{') depth++;
      if (char == '}') depth--;
      if (depth == 0 && (char == '[' || char == '*')) {
        final match = starts.matchAsPrefix(variantsText, i);
        if (match != null) {
          positions.add((i, match));
          i = match.end - 1;
        }
      }
    }
    for (var index = 0; index < positions.length; index++) {
      final (_, match) = positions[index];
      final end = index + 1 < positions.length
          ? positions[index + 1].$1
          : variantsText.length;
      final key = match.group(2)!.trim();
      variants[key] = variantsText.substring(match.end, end).trim();
      if (match.group(1) == '*') defaultKey = key;
    }
    final display = _display(selector);
    final chosen =
        variants[display] ??
        (selector is num ? variants[selector == 1 ? 'one' : 'other'] : null) ??
        variants[defaultKey];
    return pattern(chosen ?? '');
  }

  String _display(Object value) => switch (value) {
    final double number when number == number.roundToDouble() =>
      number.toInt().toString(),
    _ => value.toString(),
  };

  static int _closing(String text, int open) {
    var depth = 0;
    for (var i = open; i < text.length; i++) {
      if (text[i] == '{') depth++;
      if (text[i] == '}' && --depth == 0) return i;
    }
    throw FormatException('Unclosed placeable', text, open);
  }

  static int _topLevel(String text, String token) {
    var depth = 0;
    for (var i = 0; i < text.length; i++) {
      if (text[i] == '{') depth++;
      if (text[i] == '}') depth--;
      if (depth == 0 && text.startsWith(token, i)) return i;
    }
    return -1;
  }
}
