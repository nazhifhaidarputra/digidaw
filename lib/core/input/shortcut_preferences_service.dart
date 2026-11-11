import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:karbeat/core/input/shortcut_models.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/src/rust/api/settings.dart' as settings_api;

/// Stores the shortcuts the user changed. Rust drops stored entries it cannot
/// read; [load] also drops chords this platform cannot trigger.
class ShortcutPreferencesService {
  Future<Result<IMap<String, ShortcutChord>>> load() {
    return attemptAsync(() async {
      final stored = await settings_api.loadShortcutOverrides();
      final decoded = fromStored(stored);
      if (decoded.repaired) {
        await settings_api.saveShortcutOverrides(
          overrides: toStored(decoded.overrides),
        );
      }
      return decoded.overrides;
    });
  }

  Future<Result<void>> save(IMap<String, ShortcutChord> overrides) {
    return attemptAsync(
      () => settings_api.saveShortcutOverrides(overrides: toStored(overrides)),
    );
  }

  /// The stored chords that are supported; `repaired` is set when any were
  /// dropped.
  static ({IMap<String, ShortcutChord> overrides, bool repaired}) fromStored(
    Map<String, settings_api.UiShortcutChord> stored,
  ) {
    final overrides = <String, ShortcutChord>{
      for (final MapEntry(key: id, value: chord) in stored.entries)
        if (ShortcutChord(
              logicalKeyId: chord.key,
              control: chord.control,
              shift: chord.shift,
              alt: chord.alt,
              meta: chord.meta,
            )
            case final supported when supported.isSupported)
          id: supported,
    };
    return (
      overrides: overrides.lock,
      repaired: overrides.length != stored.length,
    );
  }

  static Map<String, settings_api.UiShortcutChord> toStored(
    IMap<String, ShortcutChord> overrides,
  ) {
    return {
      for (final MapEntry(key: id, value: chord) in overrides.entries)
        id: settings_api.UiShortcutChord(
          key: chord.logicalKeyId,
          control: chord.control,
          shift: chord.shift,
          alt: chord.alt,
          meta: chord.meta,
        ),
    };
  }
}
