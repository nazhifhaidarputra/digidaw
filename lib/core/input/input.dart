import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/notification_provider.dart';
import 'package:karbeat/core/input/intents/workspace/intent.dart';
import 'package:karbeat/core/input/shortcut_models.dart';
import 'package:karbeat/core/input/shortcut_preferences_service.dart';
import 'package:karbeat/core/utils/result_type.dart';

final shortcutPreferencesServiceProvider = Provider<ShortcutPreferencesService>(
  (ref) => ShortcutPreferencesService(),
);

final shortcutCatalogProvider = Provider<IList<DawShortcut>>(
  (ref) => workspaceShortcuts,
);

class ShortcutManagerNotifier extends Notifier<ShortcutManagerState> {
  bool _initializationStarted = false;

  @override
  ShortcutManagerState build() => const ShortcutManagerState();

  Future<Result<void>> initialize() async {
    if (_initializationStarted) return Result.ok(null);
    _initializationStarted = true;
    final loaded = await ref.read(shortcutPreferencesServiceProvider).load();
    if (loaded case Error<IMap<String, ShortcutChord>>(error: final error)) {
      _initializationStarted = false;
      return ref.notifyErrorResult(error, title: 'Could not load shortcuts');
    }

    final knownIds = ref
        .read(shortcutCatalogProvider)
        .map((shortcut) => shortcut.id)
        .toSet();
    final valid = loaded.ok().removeWhere((id, _) => !knownIds.contains(id));
    if (_hasConflict(valid)) {
      final reset = await ref
          .read(shortcutPreferencesServiceProvider)
          .save(const IMapConst({}));
      if (reset.isErr()) {
        _initializationStarted = false;
        return ref.notifyErrorResult(
          reset.err(),
          title: 'Could not reset conflicting shortcuts',
        );
      }
      state = const ShortcutManagerState(isInitialized: true);
      ref
          .read(notificationProvider.notifier)
          .warn(
            'Saved shortcuts contained a conflict and were reset to defaults.',
            title: 'Shortcut settings reset',
          );
      return Result.ok(null);
    }

    state = ShortcutManagerState(overrides: valid, isInitialized: true);
    if (valid.length != loaded.ok().length) {
      await ref.read(shortcutPreferencesServiceProvider).save(valid);
    }
    return Result.ok(null);
  }

  Future<Result<void>> remap(String id, ShortcutChord chord) async {
    if (!chord.isSupported) {
      return Result.error(
        const ShortcutValidationException(
          'Use a non-modifier key with Ctrl, Alt, or Command.',
        ),
      );
    }
    final shortcut = shortcutById(id);
    if (shortcut == null) {
      return Result.error(ShortcutValidationException('Unknown shortcut: $id'));
    }

    final conflict = activeChords().entries
        .where((entry) => entry.key != id && entry.value == chord)
        .firstOrNull;
    if (conflict != null) {
      return Result.error(
        ShortcutConflictException(
          conflictingId: conflict.key,
          conflictingTitle: shortcutById(conflict.key)?.title ?? conflict.key,
        ),
      );
    }

    final defaultChord = ShortcutChord.fromActivator(shortcut.defaultKey);
    final nextOverrides = chord == defaultChord
        ? state.overrides.remove(id)
        : state.overrides.add(id, chord);
    return _saveAndPublish(nextOverrides);
  }

  Future<Result<void>> resetOne(String id) async {
    if (shortcutById(id) == null) {
      return Result.error(ShortcutValidationException('Unknown shortcut: $id'));
    }
    return _saveAndPublish(state.overrides.remove(id));
  }

  Future<Result<void>> resetAll() => _saveAndPublish(const IMapConst({}));

  IMap<String, ShortcutChord> activeChords() {
    return IMap.fromEntries(
      ref
          .read(shortcutCatalogProvider)
          .map(
            (shortcut) => MapEntry(
              shortcut.id,
              state.overrides[shortcut.id] ??
                  ShortcutChord.fromActivator(shortcut.defaultKey),
            ),
          ),
    );
  }

  DawShortcut? shortcutById(String id) => ref
      .read(shortcutCatalogProvider)
      .where((shortcut) => shortcut.id == id)
      .firstOrNull;

  bool _hasConflict(IMap<String, ShortcutChord> overrides) {
    final seen = <ShortcutChord>{};
    for (final shortcut in ref.read(shortcutCatalogProvider)) {
      final chord =
          overrides[shortcut.id] ??
          ShortcutChord.fromActivator(shortcut.defaultKey);
      if (!seen.add(chord)) return true;
    }
    return false;
  }

  Future<Result<void>> _saveAndPublish(
    IMap<String, ShortcutChord> overrides,
  ) async {
    final saved = await ref
        .read(shortcutPreferencesServiceProvider)
        .save(overrides);
    if (saved case Error<void>(error: final error)) {
      return ref.notifyErrorResult(error, title: 'Could not save shortcuts');
    }
    state = state.copyWith(overrides: overrides, isInitialized: true);
    return Result.ok(null);
  }
}

final shortcutManagerProvider =
    NotifierProvider<ShortcutManagerNotifier, ShortcutManagerState>(
      ShortcutManagerNotifier.new,
    );

final activeShortcutMapProvider = Provider<Map<ShortcutActivator, Intent>>((
  ref,
) {
  ref.watch(shortcutManagerProvider);
  final manager = ref.read(shortcutManagerProvider.notifier);
  final active = manager.activeChords();
  return {
    for (final shortcut in ref.watch(shortcutCatalogProvider))
      active[shortcut.id]!.toActivator(): shortcut.intent,
  };
});
