import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karbeat/app/providers/floating_midi_keyboard_state.dart';

void main() {
  test('provides immutable defaults and nullable copyWith support', () {
    const initial = FloatingMidiKeyboardState();

    expect(initial, const FloatingMidiKeyboardState());
    expect(initial.showed, isFalse);
    expect(initial.baseKey, 48);
    expect(initial.keyRange, 15);
    expect(initial.selectedGeneratorId, isNull);

    final selected = initial.copyWith(selectedGeneratorId: 42);
    expect(selected.selectedGeneratorId, 42);
    expect(selected.copyWith(selectedGeneratorId: null), initial);
  });

  test('notifier updates configuration and clamps keyboard bounds', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(floatingMidiKeyboardStateProvider.notifier);

    notifier.toggle();
    notifier.setBaseKey(0);
    notifier.setKeyRange(100);
    notifier.setGenerator(7);

    expect(
      container.read(floatingMidiKeyboardStateProvider),
      const FloatingMidiKeyboardState(
        showed: true,
        baseKey: 21,
        keyRange: 24,
        selectedGeneratorId: 7,
      ),
    );

    notifier.setBaseKey(999);
    notifier.setKeyRange(0);
    notifier.setGenerator(null);

    final state = container.read(floatingMidiKeyboardStateProvider);
    expect(state.baseKey, 120);
    expect(state.keyRange, 12);
    expect(state.selectedGeneratorId, isNull);
  });
}
