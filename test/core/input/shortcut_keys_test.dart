import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karbeat/core/input/input.dart';
import 'package:karbeat/core/input/shortcut_key_tree.dart';
import 'package:karbeat/core/input/shortcut_models.dart';
import 'package:karbeat/generated/shortcuts/shortcut_keys.dart';
import 'package:karbeat/tool/generate_shortcut_keys.dart';

void main() {
  test('generated shortcut keys match the module tree', () {
    expect(
      File(shortcutKeysOutputPath).readAsStringSync(),
      renderShortcutKeys(shortcutModules),
      reason: 'Run: dart run lib/tool/generate_shortcut_keys.dart',
    );
  });

  test('keys are derived from their path in the module tree', () {
    expect(
      TrackListToolShortcutKeys.delete,
      const ShortcutKey(
        id: 'trackList.tool.delete',
        titleId: 'shortcuts-track-list-tool-delete',
        categoryId: 'shortcuts-category-track-list-tool',
      ),
    );
  });

  test('every key is unique and has its English messages', () {
    final keys = shortcutKeysOf(shortcutModules);
    expect(duplicateShortcutIds(keys), isEmpty);
    expect(missingShortcutMessages(keys, englishMessageIds()), isEmpty);
  });

  test('the generator reports a missing message', () {
    final keys = shortcutKeysOf(const [
      ShortcutModule('trackList', commands: ['missing']),
    ]);
    expect(missingShortcutMessages(keys, englishMessageIds()), [
      'Missing English message shortcuts-track-list-missing '
          '(for trackList.missing)',
    ]);
  });

  test('every generated key is bound exactly once', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final bound = container
        .read(shortcutCatalogProvider)
        .map((shortcut) => shortcut.key)
        .toList();

    expect(bound, unorderedEquals(allShortcutKeys));
  });
}
