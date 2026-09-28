import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karbeat/shared/models/piano_key.dart';

void main() {
  test('resolves physical piano keys and applies the selected base key', () {
    const event = KeyDownEvent(
      physicalKey: PhysicalKeyboardKey.keyZ,
      logicalKey: LogicalKeyboardKey.keyZ,
      timeStamp: Duration.zero,
    );

    expect(pianoNoteForKeyEvent(event), 48);
    expect(pianoNoteForKeyEvent(event, baseKey: 60), 60);
  });

  test('falls back to the logical key when the physical key is unmapped', () {
    const event = KeyDownEvent(
      physicalKey: PhysicalKeyboardKey.f1,
      logicalKey: LogicalKeyboardKey.keyQ,
      timeStamp: Duration.zero,
    );

    expect(pianoNoteForKeyEvent(event), 60);
  });

  test('does not produce MIDI notes outside the valid range', () {
    const event = KeyDownEvent(
      physicalKey: PhysicalKeyboardKey.bracketRight,
      logicalKey: LogicalKeyboardKey.bracketRight,
      timeStamp: Duration.zero,
    );

    expect(pianoNoteForKeyEvent(event, baseKey: 120), isNull);
  });

  testWidgets('leaves modifier chords to the shortcut map', (tester) async {
    const event = KeyDownEvent(
      physicalKey: PhysicalKeyboardKey.keyS,
      logicalKey: LogicalKeyboardKey.keyS,
      timeStamp: Duration.zero,
    );

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    expect(pianoNoteForKeyEvent(event), isNull);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

    expect(pianoNoteForKeyEvent(event), 49);
  });
}
