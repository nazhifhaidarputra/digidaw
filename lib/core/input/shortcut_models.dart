import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'shortcut_models.freezed.dart';

class DawShortcut {
  const DawShortcut({
    required this.id,
    required this.title,
    required this.category,
    required this.intent,
    required this.defaultKey,
  });

  final String id;
  final String title;
  final String category;
  final Intent intent;
  final SingleActivator defaultKey;
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

  bool get isSupported =>
      !_modifierKeyIds.contains(logicalKeyId) && (control || alt || meta);

  SingleActivator toActivator() => SingleActivator(
    LogicalKeyboardKey(logicalKeyId),
    control: control,
    shift: shift,
    alt: alt,
    meta: meta,
  );

  Map<String, Object> toStorageJson() => {
    'key': logicalKeyId,
    'control': control,
    'shift': shift,
    'alt': alt,
    'meta': meta,
  };

  static ShortcutChord? tryFromStorageJson(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final key = value['key'];
    final control = value['control'];
    final shift = value['shift'];
    final alt = value['alt'];
    final meta = value['meta'];
    if (key is! int ||
        control is! bool ||
        shift is! bool ||
        alt is! bool ||
        meta is! bool) {
      return null;
    }
    final chord = ShortcutChord(
      logicalKeyId: key,
      control: control,
      shift: shift,
      alt: alt,
      meta: meta,
    );
    return chord.isSupported ? chord : null;
  }
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
  String toString() => 'Already assigned to $conflictingTitle.';
}

class ShortcutValidationException implements Exception {
  const ShortcutValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

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
