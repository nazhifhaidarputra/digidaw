import 'dart:convert';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:karbeat/core/input/shortcut_models.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ShortcutPreferencesService {
  static const storageKey = 'settings.shortcuts.v1';
  static const schemaVersion = 1;

  Future<Result<IMap<String, ShortcutChord>>> load() {
    return attemptAsync(() async {
      final preferences = SharedPreferencesAsync();
      final encoded = await preferences.getString(storageKey);
      if (encoded == null) return const IMapConst({});

      final decoded = decode(encoded);
      if (decoded.repaired) {
        await preferences.setString(storageKey, encode(decoded.overrides));
      }
      return decoded.overrides;
    });
  }

  Future<Result<void>> save(IMap<String, ShortcutChord> overrides) {
    return attemptAsync(() async {
      await SharedPreferencesAsync().setString(storageKey, encode(overrides));
    });
  }

  static ({IMap<String, ShortcutChord> overrides, bool repaired}) decode(
    String encoded,
  ) {
    Object? decoded;
    try {
      decoded = jsonDecode(encoded);
    } on FormatException {
      return (overrides: const IMapConst({}), repaired: true);
    }
    if (decoded is! Map<String, dynamic> ||
        decoded['version'] != schemaVersion ||
        decoded['overrides'] is! Map<String, dynamic>) {
      return (overrides: const IMapConst({}), repaired: true);
    }

    var repaired = false;
    final overrides = <String, ShortcutChord>{};
    for (final entry
        in (decoded['overrides'] as Map<String, dynamic>).entries) {
      final chord = ShortcutChord.tryFromStorageJson(entry.value);
      if (chord == null) {
        repaired = true;
      } else {
        overrides[entry.key] = chord;
      }
    }
    return (overrides: overrides.lock, repaired: repaired);
  }

  static String encode(IMap<String, ShortcutChord> overrides) {
    return jsonEncode({
      'version': schemaVersion,
      'overrides': {
        for (final entry in overrides.entries)
          entry.key: entry.value.toStorageJson(),
      },
    });
  }
}
