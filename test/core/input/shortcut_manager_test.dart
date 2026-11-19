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
import 'package:karbeat/src/rust/api/settings.dart';
import 'package:karbeat/generated/shortcuts/shortcut_keys.dart';

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

  test('Escape cancels the selection in every view', () {
    final shortcut = workspaceShortcuts.singleWhere(
      (shortcut) => shortcut.id == WorkspaceShortcutKeys.cancelSelection.id,
    );
    expect(shortcut.intent, isA<CancelSelectionIntent>());
    expect(shortcut.scope, ShortcutScope.global);
    expect(
      ShortcutChord.fromActivator(shortcut.defaultKey),
      ShortcutChord.fromActivator(
        const SingleActivator(LogicalKeyboardKey.escape),
      ),
    );
  });

  test('stored chords round-trip supported keys', () {
    final decoded = ShortcutPreferencesService.fromStored(
      ShortcutPreferencesService.toStored(
        IMap({WorkspaceShortcutKeys.save.id: customChord}),
      ),
    );

    expect(decoded.repaired, isFalse);
    expect(decoded.overrides[WorkspaceShortcutKeys.save.id], customChord);
    expect(
      decoded.overrides[WorkspaceShortcutKeys.save.id]?.toActivator().trigger,
      LogicalKeyboardKey.keyP,
    );
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
    final saveChord = notifier.activeChords()[WorkspaceShortcutKeys.save.id]!;

    final result = await notifier.remap(
      WorkspaceShortcutKeys.undo.id,
      saveChord,
    );

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
      (await notifier.remap(WorkspaceShortcutKeys.save.id, customChord)).isOk(),
      isTrue,
    );
    expect(service.saved?[WorkspaceShortcutKeys.save.id], customChord);
    expect(
      (await notifier.resetOne(WorkspaceShortcutKeys.save.id)).isOk(),
      isTrue,
    );
    expect(service.saved, isEmpty);
    await notifier.remap(WorkspaceShortcutKeys.save.id, customChord);
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
      (shortcut) => shortcut.id == TransportShortcutKeys.toggleMetronome.id,
    );

    expect(metronome.defaultKey.trigger, LogicalKeyboardKey.keyM);
    expect(metronome.defaultKey.control, isTrue);
  });

  test('piano roll binds copy, paste, and duplicate notes', () {
    final container = ProviderContainer(
      overrides: [
        shortcutPreferencesServiceProvider.overrideWithValue(
          _FakeShortcutPreferencesService(),
        ),
      ],
    );
    addTearDown(container.dispose);
    container
        .read(workspaceStateProvider.notifier)
        .navigateTo(WorkspaceView.pianoRoll);

    final shortcuts = container.read(activeShortcutMapProvider);
    Intent? intentFor(LogicalKeyboardKey key) => shortcuts.entries
        .where((entry) {
          final activator = entry.key as SingleActivator;
          return activator.trigger == key &&
              activator.control &&
              !activator.alt &&
              !activator.shift;
        })
        .firstOrNull
        ?.value;

    expect(intentFor(LogicalKeyboardKey.keyC), isA<CopyNotesIntent>());
    expect(intentFor(LogicalKeyboardKey.keyV), isA<PasteNotesIntent>());
    expect(intentFor(LogicalKeyboardKey.keyB), isA<DuplicateNotesIntent>());
  });

  test('Delete removes the selection in both editing views', () {
    final container = ProviderContainer(
      overrides: [
        shortcutPreferencesServiceProvider.overrideWithValue(
          _FakeShortcutPreferencesService(),
        ),
      ],
    );
    addTearDown(container.dispose);

    Intent? deleteIntent() => container
        .read(activeShortcutMapProvider)
        .entries
        .where((entry) {
          final activator = entry.key as SingleActivator;
          return activator.trigger == LogicalKeyboardKey.delete &&
              !activator.control &&
              !activator.alt &&
              !activator.shift &&
              !activator.meta;
        })
        .firstOrNull
        ?.value;

    expect(deleteIntent(), isA<DeleteClipsIntent>());

    container
        .read(workspaceStateProvider.notifier)
        .navigateTo(WorkspaceView.pianoRoll);
    expect(deleteIntent(), isA<DeleteNotesIntent>());
  });

  test('Delete and Backspace are valid bare shortcut keys', () {
    expect(
      ShortcutChord(logicalKeyId: LogicalKeyboardKey.delete.keyId).isSupported,
      isTrue,
    );
    expect(
      ShortcutChord(
        logicalKeyId: LogicalKeyboardKey.backspace.keyId,
      ).isSupported,
      isTrue,
    );
    expect(
      ShortcutChord(logicalKeyId: LogicalKeyboardKey.keyA.keyId).isSupported,
      isFalse,
    );
  });

  test('active shortcut chords follow remapped settings', () async {
    final container = ProviderContainer(
      overrides: [
        shortcutPreferencesServiceProvider.overrideWithValue(
          _FakeShortcutPreferencesService(),
        ),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(shortcutManagerProvider.notifier);
    await notifier.initialize();

    expect(
      container.read(activeShortcutChordProvider(WorkspaceShortcutKeys.save)),
      ShortcutChord(logicalKeyId: LogicalKeyboardKey.keyS.keyId, control: true),
    );
    expect(
      container.read(
        activeShortcutChordProvider(
          const ShortcutKey(
            id: 'missing.command',
            titleId: 'missing-title',
            categoryId: 'missing-category',
          ),
        ),
      ),
      isNull,
    );

    await notifier.remap(WorkspaceShortcutKeys.save.id, customChord);

    expect(
      container.read(activeShortcutChordProvider(WorkspaceShortcutKeys.save)),
      customChord,
    );
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
    expect(
      chords[TrackListShortcutKeys.nudgeRight.id],
      chords[PianoRollShortcutKeys.shiftRight.id],
    );
    expect(container.read(shortcutManagerProvider).overrides, isEmpty);

    final pianoRollOnly = await notifier.remap(
      TrackListShortcutKeys.nudgeLeft.id,
      chords[PianoRollShortcutKeys.humanize.id]!,
    );
    expect(pianoRollOnly.isOk(), isTrue);

    final global = await notifier.remap(
      TrackListShortcutKeys.nudgeLeft.id,
      chords[WorkspaceShortcutKeys.save.id]!,
    );
    expect(global.err(), isA<ShortcutConflictException>());
  });

  test('stored chords this platform cannot trigger are dropped', () {
    final result = ShortcutPreferencesService.fromStored({
      WorkspaceShortcutKeys.save.id: UiShortcutChord(
        key: LogicalKeyboardKey.keyS.keyId,
        control: false,
        shift: false,
        alt: false,
        meta: false,
      ),
    });

    expect(result.repaired, isTrue);
    expect(result.overrides, isEmpty);
  });
}
