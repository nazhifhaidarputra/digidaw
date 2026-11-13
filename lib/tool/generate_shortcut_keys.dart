import 'dart:io';

import 'package:karbeat/core/input/shortcut_key_tree.dart';

/// Where the generated constants are written.
const shortcutKeysOutputPath = 'lib/generated/shortcuts/shortcut_keys.dart';

/// The English messages every shortcut title and category must exist in.
const englishMessagesPath = 'rust/karbeat-l10n/locales/en-US';

/// Writes [shortcutKeysOutputPath] from [shortcutModules]. Refuses to write
/// when an id repeats or a message is missing from the English files, so a
/// missing key fails here instead of showing a raw id at runtime.
void main() {
  final keys = shortcutKeysOf(shortcutModules);
  final problems = [
    ...duplicateShortcutIds(keys),
    ...missingShortcutMessages(keys, englishMessageIds()),
  ];
  if (problems.isNotEmpty) {
    stderr.writeln('Shortcut keys were not generated:');
    for (final problem in problems) {
      stderr.writeln('  $problem');
    }
    exitCode = 1;
    return;
  }

  File(shortcutKeysOutputPath)
    ..createSync(recursive: true)
    ..writeAsStringSync(renderShortcutKeys(shortcutModules));
  stdout.writeln(
    'Generated ${keys.length} shortcut keys in $shortcutKeysOutputPath',
  );
}

/// A shortcut key derived from its path in the module tree.
class GeneratedShortcutKey {
  const GeneratedShortcutKey(this.modulePath, this.command);

  /// Module names from the root, e.g. `['trackList', 'tool']`.
  final List<String> modulePath;
  final String command;

  String get id => [...modulePath, command].join('.');

  String get titleId =>
      'shortcuts-${[...modulePath, command].map(_kebab).join('-')}';

  String get categoryId =>
      'shortcuts-category-${modulePath.map(_kebab).join('-')}';

  String get className => '${modulePath.map(_pascal).join()}ShortcutKeys';
}

/// Every key of [modules], depth first in declaration order.
List<GeneratedShortcutKey> shortcutKeysOf(List<ShortcutModule> modules) {
  final keys = <GeneratedShortcutKey>[];
  void visit(ShortcutModule module, List<String> parentPath) {
    final path = [...parentPath, module.name];
    for (final command in module.commands) {
      keys.add(GeneratedShortcutKey(path, command));
    }
    for (final child in module.modules) {
      visit(child, path);
    }
  }

  for (final module in modules) {
    visit(module, const []);
  }
  return keys;
}

List<String> duplicateShortcutIds(List<GeneratedShortcutKey> keys) {
  final seen = <String>{};
  return [
    for (final key in keys)
      if (!seen.add(key.id)) 'Duplicate shortcut id ${key.id}',
  ];
}

/// Title and category messages of [keys] that are not in [messageIds].
List<String> missingShortcutMessages(
  List<GeneratedShortcutKey> keys,
  Set<String> messageIds,
) {
  final missing = <String>{};
  for (final key in keys) {
    for (final id in [key.titleId, key.categoryId]) {
      if (!messageIds.contains(id)) {
        missing.add('Missing English message $id (for ${key.id})');
      }
    }
  }
  return missing.toList();
}

/// Ids of the messages in the `.ftl` files of [directory].
Set<String> englishMessageIds([String directory = englishMessagesPath]) {
  final message = RegExp(r'^([a-zA-Z][a-zA-Z0-9_-]*)\s*=', multiLine: true);
  return {
    for (final file in Directory(directory).listSync())
      if (file is File && file.path.endsWith('.ftl'))
        for (final match in message.allMatches(file.readAsStringSync()))
          match.group(1)!,
  };
}

/// The generated Dart source, already formatted.
String renderShortcutKeys(List<ShortcutModule> modules) {
  final keys = shortcutKeysOf(modules);
  final buffer = StringBuffer()
    ..writeln('// GENERATED CODE - DO NOT MODIFY BY HAND.')
    ..writeln('// Source: lib/core/input/shortcut_key_tree.dart')
    ..writeln('// Regenerate: dart run lib/tool/generate_shortcut_keys.dart')
    ..writeln()
    ..writeln("import 'package:karbeat/core/input/shortcut_models.dart';");

  final byClass = <String, List<GeneratedShortcutKey>>{};
  for (final key in keys) {
    byClass.putIfAbsent(key.className, () => []).add(key);
  }
  for (final MapEntry(key: className, value: classKeys) in byClass.entries) {
    buffer
      ..writeln()
      ..writeln(
        '/// Shortcuts of the `${classKeys.first.modulePath.join('.')}` '
        'module.',
      )
      ..writeln('abstract final class $className {');
    for (final (index, key) in classKeys.indexed) {
      if (index > 0) buffer.writeln();
      buffer
        ..writeln('  static const ${key.command} = ShortcutKey(')
        ..writeln("    id: '${key.id}',")
        ..writeln("    titleId: '${key.titleId}',")
        ..writeln("    categoryId: '${key.categoryId}',")
        ..writeln('  );');
    }
    buffer.writeln('}');
  }

  buffer
    ..writeln()
    ..writeln('/// Every generated shortcut key, in tree order.')
    ..writeln('const allShortcutKeys = <ShortcutKey>[');
  for (final key in keys) {
    buffer.writeln('  ${key.className}.${key.command},');
  }
  buffer.writeln('];');
  return buffer.toString();
}

String _kebab(String camel) => camel.replaceAllMapped(
  RegExp('[A-Z]'),
  (match) => '-${match[0]!.toLowerCase()}',
);

String _pascal(String camel) =>
    camel.isEmpty ? camel : camel[0].toUpperCase() + camel.substring(1);
