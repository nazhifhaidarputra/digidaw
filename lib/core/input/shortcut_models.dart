import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:karbeat/core/l10n/localizer.dart';

part 'shortcut_models.freezed.dart';

/// The workspace view a shortcut is limited to.
enum ShortcutScope {
  /// Active in every view.
  global,
  trackList,
  pianoRoll;

  /// Whether shortcuts of this scope and [other] can be active together, and
  /// so must not share a key.
  bool overlaps(ShortcutScope other) =>
      this == global || other == global || this == other;
}

/// Identifies a shortcut command: the id its binding is stored under and the
/// message ids of its name and category.
///
/// Do not write these by hand. Add the command to `shortcutModules` in
/// `lib/core/input/shortcut_key_tree.dart` and use the constant generated in
/// `lib/generated/shortcuts/shortcut_keys.dart`.
@freezed
abstract class ShortcutKey with _$ShortcutKey {
  const factory ShortcutKey({
    /// Stored id of the user's binding, e.g. `trackList.tool.delete`.
    required String id,

    /// Message id of the command's name, shown in menus and key bindings.
    required String titleId,

    /// Message id of the group the command is listed under.
    required String categoryId,
  }) = _ShortcutKey;
}

class DawShortcut {
  const DawShortcut({
    required this.key,
    required this.intent,
    required this.defaultKey,
    this.scope = ShortcutScope.global,
  });

  /// The generated key naming this command.
  final ShortcutKey key;

  String get id => key.id;

  String get titleId => key.titleId;

  String get categoryId => key.categoryId;

  String get title => tr(titleId);

  String get category => tr(categoryId);

  final Intent intent;
  final SingleActivator defaultKey;
  final ShortcutScope scope;
}

@freezed
abstract class ShortcutChord with _$ShortcutChord {
  const ShortcutChord._();

  const factory ShortcutChord({
    required int logicalKeyId,
    @Default(false) bool control,
    @Default(false) bool shift,
    @Default(false) bool alt,
    @Default(false) bool meta,
  }) = _ShortcutChord;

  factory ShortcutChord.fromActivator(SingleActivator activator) {
    return ShortcutChord(
      logicalKeyId: activator.trigger.keyId,
      control: activator.control,
      shift: activator.shift,
      alt: activator.alt,
      meta: activator.meta,
    );
  }

  /// Editing keys that are useful on their own, such as the Delete key that
  /// removes the current selection in a DAW.
  bool get isSupported =>
      !_modifierKeyIds.contains(logicalKeyId) &&
      (control || alt || meta || _bareEditingKeyIds.contains(logicalKeyId));

  SingleActivator toActivator() => SingleActivator(
    LogicalKeyboardKey(logicalKeyId),
    control: control,
    shift: shift,
    alt: alt,
    meta: meta,
    includeRepeats: false,
  );
}

@freezed
abstract class ShortcutManagerState with _$ShortcutManagerState {
  const factory ShortcutManagerState({
    @Default(IMapConst<String, ShortcutChord>({}))
    IMap<String, ShortcutChord> overrides,
    @Default(false) bool isInitialized,
  }) = _ShortcutManagerState;
}

class ShortcutConflictException implements Exception {
  const ShortcutConflictException({
    required this.conflictingId,
    required this.conflictingTitle,
  });

  final String conflictingId;
  final String conflictingTitle;

  @override
  String toString() => tr('shortcuts-conflict', {'command': conflictingTitle});
}

/// Explains which chords [ShortcutChord.isSupported] accepts.
String get shortcutSupportHint => tr('shortcuts-support-hint');

class ShortcutValidationException implements Exception {
  const ShortcutValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Human-readable label for [chord], using the platform's modifier names.
String shortcutLabel(ShortcutChord chord) {
  final macOS = defaultTargetPlatform == TargetPlatform.macOS;
  final parts = <String>[];
  if (chord.control) parts.add(macOS ? 'Control' : 'Ctrl');
  if (chord.alt) parts.add(macOS ? 'Option' : 'Alt');
  if (chord.shift) parts.add('Shift');
  if (chord.meta) parts.add(macOS ? 'Command' : 'Meta');
  final logicalKey = LogicalKeyboardKey(chord.logicalKeyId);
  final key = switch (logicalKey) {
    LogicalKeyboardKey.space => 'Space',
    _ => logicalKey.keyLabel,
  };
  parts.add(key.isEmpty ? 'Key ${chord.logicalKeyId}' : key.toUpperCase());
  return parts.join('+');
}

final _bareEditingKeyIds = <int>{
  LogicalKeyboardKey.delete.keyId,
  LogicalKeyboardKey.backspace.keyId,
};

final _modifierKeyIds = <int>{
  LogicalKeyboardKey.controlLeft.keyId,
  LogicalKeyboardKey.controlRight.keyId,
  LogicalKeyboardKey.shiftLeft.keyId,
  LogicalKeyboardKey.shiftRight.keyId,
  LogicalKeyboardKey.altLeft.keyId,
  LogicalKeyboardKey.altRight.keyId,
  LogicalKeyboardKey.metaLeft.keyId,
  LogicalKeyboardKey.metaRight.keyId,
};
