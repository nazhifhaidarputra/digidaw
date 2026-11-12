import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../helpers/ftl_test_localizer.dart';

/// Literal ids passed to `tr` and `trIn`, or stored as `titleId`,
/// `categoryId` or a menu action's name for formatting later.
final _literalId = RegExp(
  r'''(?:\btr(?:In)?\(\s*(?:[^,()]+,\s*)?|\b(?:titleId|categoryId):\s*|DawToolbarMenuAction\(\s*)'([a-z][a-z0-9-]*)'(?=[,)\s])''',
);

void main() {
  test('every message id used in lib/ exists in the English files', () {
    final known = FtlTestLocalizer().messageIds;
    final missing = <String>[];
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      if (file.path.startsWith('lib/src/rust/')) continue;
      final source = file.readAsStringSync();
      for (final match in _literalId.allMatches(source)) {
        final id = match.group(1)!;
        if (!known.contains(id)) missing.add('${file.path}: $id');
      }
    }
    expect(missing, isEmpty);
  });
}
