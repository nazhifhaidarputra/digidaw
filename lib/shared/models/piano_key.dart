import 'package:flutter/services.dart';

final Map<PhysicalKeyboardKey, int> keyMap = {
    PhysicalKeyboardKey.keyZ: 48, // C3
    PhysicalKeyboardKey.keyS: 49,
    PhysicalKeyboardKey.keyX: 50,
    PhysicalKeyboardKey.keyD: 51,
    PhysicalKeyboardKey.keyC: 52,
    PhysicalKeyboardKey.keyV: 53,
    PhysicalKeyboardKey.keyG: 54,
    PhysicalKeyboardKey.keyB: 55,
    PhysicalKeyboardKey.keyH: 56,
    PhysicalKeyboardKey.keyN: 57,
    PhysicalKeyboardKey.keyJ: 58,
    PhysicalKeyboardKey.keyM: 59,
    PhysicalKeyboardKey.comma: 60, // C4
    // Upper row (Q=C4)
    PhysicalKeyboardKey.keyQ: 60,
    PhysicalKeyboardKey.digit2: 61,
    PhysicalKeyboardKey.keyW: 62,
    PhysicalKeyboardKey.digit3: 63,
    PhysicalKeyboardKey.keyE: 64,
    PhysicalKeyboardKey.keyR: 65,
    PhysicalKeyboardKey.digit5: 66,
    PhysicalKeyboardKey.keyT: 67,
    PhysicalKeyboardKey.digit6: 68,
    PhysicalKeyboardKey.keyY: 69,
    PhysicalKeyboardKey.digit7: 70,
    PhysicalKeyboardKey.keyU: 71,
    // C5
    PhysicalKeyboardKey.keyI: 72,
    PhysicalKeyboardKey.digit9: 73,
    PhysicalKeyboardKey.keyO: 74,
    PhysicalKeyboardKey.digit0: 75,
    PhysicalKeyboardKey.keyP: 76,
    PhysicalKeyboardKey.bracketLeft: 77,
    PhysicalKeyboardKey.equal: 78,
    PhysicalKeyboardKey.bracketRight: 79,
  };

final Map<LogicalKeyboardKey, int> logicalPianoKeyMap = {
  LogicalKeyboardKey.keyZ: 48,
  LogicalKeyboardKey.keyS: 49,
  LogicalKeyboardKey.keyX: 50,
  LogicalKeyboardKey.keyD: 51,
  LogicalKeyboardKey.keyC: 52,
  LogicalKeyboardKey.keyV: 53,
  LogicalKeyboardKey.keyG: 54,
  LogicalKeyboardKey.keyB: 55,
  LogicalKeyboardKey.keyH: 56,
  LogicalKeyboardKey.keyN: 57,
  LogicalKeyboardKey.keyJ: 58,
  LogicalKeyboardKey.keyM: 59,
  LogicalKeyboardKey.comma: 60,
  LogicalKeyboardKey.keyQ: 60,
  LogicalKeyboardKey.digit2: 61,
  LogicalKeyboardKey.keyW: 62,
  LogicalKeyboardKey.digit3: 63,
  LogicalKeyboardKey.keyE: 64,
  LogicalKeyboardKey.keyR: 65,
  LogicalKeyboardKey.digit5: 66,
  LogicalKeyboardKey.keyT: 67,
  LogicalKeyboardKey.digit6: 68,
  LogicalKeyboardKey.keyY: 69,
  LogicalKeyboardKey.digit7: 70,
  LogicalKeyboardKey.keyU: 71,
  LogicalKeyboardKey.keyI: 72,
  LogicalKeyboardKey.digit9: 73,
  LogicalKeyboardKey.keyO: 74,
  LogicalKeyboardKey.digit0: 75,
  LogicalKeyboardKey.keyP: 76,
  LogicalKeyboardKey.bracketLeft: 77,
  LogicalKeyboardKey.equal: 78,
  LogicalKeyboardKey.bracketRight: 79,
};

/// Resolves a computer-key event to a MIDI note, transposed from C3 to
/// [baseKey]. Physical position is preferred, with logical keys as a fallback.
int? pianoNoteForKeyEvent(KeyEvent event, {int baseKey = 48}) {
  final baseNote =
      keyMap[event.physicalKey] ?? logicalPianoKeyMap[event.logicalKey];
  if (baseNote == null) return null;

  final note = baseNote + baseKey - 48;
  return note >= 0 && note <= 127 ? note : null;
}
