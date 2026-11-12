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

class DawShortcut {
  const DawShortcut({
    required this.id,
    required this.titleId,
    required this.categoryId,
    required this.intent,
    required this.defaultKey,
    this.scope = ShortcutScope.global,
  });

  final String id;

  /// Message id of the command's name, shown in menus and key bindings.
  final String titleId;

  /// Message id of the group the command is listed under.
  final String categoryId;

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
