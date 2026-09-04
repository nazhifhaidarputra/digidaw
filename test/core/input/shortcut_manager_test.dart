import 'dart:convert';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/core/input/intents/song_timeline/playback_intent.dart';
import 'package:karbeat/core/input/input.dart';
import 'package:karbeat/core/input/shortcut_models.dart';
import 'package:karbeat/core/input/shortcut_preferences_service.dart';
import 'package:karbeat/core/utils/result_type.dart';

class _FakeShortcutPreferencesService extends ShortcutPreferencesService {
  IMap<String, ShortcutChord> loaded = const IMapConst({});
  IMap<String, ShortcutChord>? saved;
  int loadCount = 0;

  @override
  Future<Result<IMap<String, ShortcutChord>>> load() async {
    loadCount += 1;
    return Result.ok(loaded);
  }

  @override
  Future<Result<void>> save(IMap<String, ShortcutChord> overrides) async {
    saved = overrides;
    return Result.ok(null);
  }
}

void main() {
  final customChord = ShortcutChord(
    logicalKeyId: LogicalKeyboardKey.keyP.keyId,
    control: true,
  );

  test('chord storage schema round-trips supported keys', () {
    final decoded = ShortcutChord.tryFromStorageJson(
      customChord.toStorageJson(),
    );

    expect(decoded, customChord);
    expect(decoded?.toActivator().trigger, LogicalKeyboardKey.keyP);
  });

  test(
    'initialization is idempotent and ignores unknown command IDs',
    () async {
      final service = _FakeShortcutPreferencesService()
        ..loaded = IMap({'removed.command': customChord});
      final container = ProviderContainer(
        overrides: [
          shortcutPreferencesServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(shortcutManagerProvider.notifier);
      expect((await notifier.initialize()).isOk(), isTrue);
      expect((await notifier.initialize()).isOk(), isTrue);

      expect(service.loadCount, 1);
      expect(container.read(shortcutManagerProvider).overrides, isEmpty);
      final shortcuts = container.read(activeShortcutMapProvider);
      expect(shortcuts.length, 10);
      expect(
        shortcuts.entries
            .singleWhere(
              (entry) =>
                  (entry.key as SingleActivator).trigger ==
                  LogicalKeyboardKey.space,
            )
            .value,
        isA<TogglePlayIntent>(),
      );
      expect(
        shortcuts.entries
            .singleWhere(
              (entry) =>
                  (entry.key as SingleActivator).trigger ==
                  LogicalKeyboardKey.end,
            )
            .value,
        isA<StopIntent>(),
      );
    },
  );

  test('remap rejects conflicts and preserves the active mapping', () async {
    final service = _FakeShortcutPreferencesService();
    final container = ProviderContainer(
      overrides: [
        shortcutPreferencesServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(shortcutManagerProvider.notifier);
    await notifier.initialize();
    final saveChord = notifier.activeChords()['workspace.save']!;

    final result = await notifier.remap('workspace.undo', saveChord);

    expect(result.isErr(), isTrue);
    expect(result.err(), isA<ShortcutConflictException>());
    expect(container.read(shortcutManagerProvider).overrides, isEmpty);
  });

  test('remap persists only overrides and supports one/all reset', () async {
    final service = _FakeShortcutPreferencesService();
    final container = ProviderContainer(
      overrides: [
        shortcutPreferencesServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(shortcutManagerProvider.notifier);
    await notifier.initialize();

    expect(
      (await notifier.remap('workspace.save', customChord)).isOk(),
      isTrue,
    );
    expect(service.saved?['workspace.save'], customChord);
    expect((await notifier.resetOne('workspace.save')).isOk(), isTrue);
    expect(service.saved, isEmpty);
    await notifier.remap('workspace.save', customChord);
    expect((await notifier.resetAll()).isOk(), isTrue);
    expect(container.read(shortcutManagerProvider).overrides, isEmpty);
  });

  test('malformed preferences reset safely', () {
    final result = ShortcutPreferencesService.decode(
      jsonEncode({
        'version': 1,
        'overrides': {
          'workspace.save': {'key': 'not-an-integer'},
        },
      }),
    );

    expect(result.repaired, isTrue);
    expect(result.overrides, isEmpty);
  });
}
