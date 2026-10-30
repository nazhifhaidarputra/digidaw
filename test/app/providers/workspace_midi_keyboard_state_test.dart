import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karbeat/app/providers/workspace_state.dart';

void main() {
  test('defaults to a C3 base key and a two-octave range', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final keyboard = container
        .read(workspaceStateProvider)
        .floatingMidiKeyboardState;

    expect(keyboard.baseKey, 48);
    expect(keyboard.keyRange, 24);
    expect(keyboard.baseOctave, 3);
    expect(keyboard.basePitchClass, 0);
    expect(keyboard.baseNoteLabel, 'C3');
  });

  test('combines the octave and key controls into the base key', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(workspaceStateProvider.notifier);

    notifier.setMidiKeyboardOctave(4);
    var keyboard = _keyboard(container);
    expect(keyboard.baseKey, 60);
    expect(keyboard.baseNoteLabel, 'C4');

    notifier.setMidiKeyboardKey(1);
    keyboard = _keyboard(container);
    expect(keyboard.baseKey, 61);
    expect(keyboard.baseOctave, 4);
    expect(keyboard.baseNoteLabel, 'C#4');

    notifier.setMidiKeyboardOctave(5);
    keyboard = _keyboard(container);
    expect(keyboard.baseKey, 73);
    expect(keyboard.baseNoteLabel, 'C#5');

    notifier.setMidiKeyboardKey(11);
    keyboard = _keyboard(container);
    expect(keyboard.baseKey, 83);
    expect(keyboard.baseNoteLabel, 'B5');
  });

  test('clamps the octave and key controls to the playable range', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(workspaceStateProvider.notifier);

    notifier.setMidiKeyboardOctave(-3);
    var keyboard = _keyboard(container);
    expect(keyboard.baseKey, 24);
    expect(keyboard.baseNoteLabel, 'C1');

    notifier.setMidiKeyboardKey(99);
    keyboard = _keyboard(container);
    expect(keyboard.basePitchClass, 11);
    expect(keyboard.baseKey, 35);
    expect(keyboard.baseNoteLabel, 'B1');

    notifier.setMidiKeyboardOctave(12);
    keyboard = _keyboard(container);
    expect(keyboard.baseKey, 119);
    expect(keyboard.baseNoteLabel, 'B8');
  });

  test('clamps the range control to two octaves', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(workspaceStateProvider.notifier);

    notifier.setMidiKeyboardRange(100);
    expect(_keyboard(container).keyRange, 24);

    notifier.setMidiKeyboardRange(0);
    expect(_keyboard(container).keyRange, 12);
  });
}

FloatingMidiKeyboardFieldState _keyboard(ProviderContainer container) {
  return container.read(workspaceStateProvider).floatingMidiKeyboardState;
}
