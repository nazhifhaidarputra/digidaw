import 'dart:convert';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karbeat/core/input/intents/workspace/intent.dart';
import 'package:karbeat/app/providers/workspace_state.dart';
import 'package:karbeat/core/input/intents/piano_roll/piano_roll_intent.dart';
import 'package:karbeat/core/input/intents/track_list/track_list_intent.dart';
import 'package:karbeat/shared/enums/global.dart';
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
      // The track list is the first view, so its shortcuts join the global
      // ones and the piano roll's stay out
      expect(
        shortcuts.length,
        workspaceShortcuts.length + trackListShortcuts.length,
      );
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

  test('each view activates its own shortcuts beside the global ones', () {
    final container = ProviderContainer(
      overrides: [
        shortcutPreferencesServiceProvider.overrideWithValue(
          _FakeShortcutPreferencesService(),
        ),
      ],
    );
    addTearDown(container.dispose);
    Intent? intentFor(LogicalKeyboardKey key, {bool shift = false}) => container
        .read(activeShortcutMapProvider)
        .entries
        .where((entry) {
          final activator = entry.key as SingleActivator;
          return activator.trigger == key &&
              activator.shift == shift &&
              !activator.control &&
              !activator.alt;
        })
        .firstOrNull
        ?.value;

    // Track list: bare letters pick tools, Shift+arrows nudge clips
    final move = intentFor(LogicalKeyboardKey.keyM);
    expect(move, isA<SelectTrackListToolIntent>());
    expect((move! as SelectTrackListToolIntent).tool, ToolSelection.move);
    expect(
      (intentFor(LogicalKeyboardKey.keyQ)! as SelectTrackListToolIntent).tool,
      ToolSelection.panSelect,
    );
    expect(
      intentFor(LogicalKeyboardKey.arrowRight, shift: true),
      isA<NudgeClipsIntent>(),
    );
    expect(intentFor(LogicalKeyboardKey.space), isA<TogglePlayIntent>());

    // Piano roll: the same Shift+arrow shifts notes, and M is free
    container
        .read(workspaceStateProvider.notifier)
        .navigateTo(WorkspaceView.pianoRoll);
    expect(
      intentFor(LogicalKeyboardKey.arrowRight, shift: true),
      isA<ShiftNotesIntent>(),
    );
    expect(intentFor(LogicalKeyboardKey.keyM), isNull);
    expect(intentFor(LogicalKeyboardKey.space), isA<TogglePlayIntent>());

    // Mixer: only the global shortcuts
    container
        .read(workspaceStateProvider.notifier)
        .navigateTo(WorkspaceView.mixer);
    expect(
      container.read(activeShortcutMapProvider).length,
      workspaceShortcuts.length,
    );
  });

  test('the metronome toggle moved to Ctrl+M', () {
    final metronome = workspaceShortcuts.singleWhere(
      (shortcut) => shortcut.id == 'transport.toggleMetronome',
    );

    expect(metronome.defaultKey.trigger, LogicalKeyboardKey.keyM);
    expect(metronome.defaultKey.control, isTrue);
  });

  test('a key may be shared across views but not with a global one', () async {
    final service = _FakeShortcutPreferencesService();
    final container = ProviderContainer(
      overrides: [
        shortcutPreferencesServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(shortcutManagerProvider.notifier);
    await notifier.initialize();
    final chords = notifier.activeChords();

    // The defaults already share Shift+arrows between two views
    expect(chords['trackList.nudgeRight'], chords['pianoRoll.shiftRight']);
    expect(container.read(shortcutManagerProvider).overrides, isEmpty);

    final pianoRollOnly = await notifier.remap(
      'trackList.nudgeLeft',
      chords['pianoRoll.quantize']!,
    );
    expect(pianoRollOnly.isOk(), isTrue);

    final global = await notifier.remap(
      'trackList.nudgeLeft',
      chords['workspace.save']!,
    );
    expect(global.err(), isA<ShortcutConflictException>());
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
