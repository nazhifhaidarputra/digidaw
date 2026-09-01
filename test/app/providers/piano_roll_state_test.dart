import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karbeat/app/providers/piano_roll_state.dart';

void main() {
  test('opening a pattern also selects its preview generator', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(pianoRollProvider.notifier);

    notifier.openPattern(12, previewGeneratorId: 34);

    final state = container.read(pianoRollProvider);
    expect(state.editingPatternId, 12);
    expect(state.previewGeneratorId, 34);
    expect(state.selectedNoteIds, isEmpty);
  });

  test('clearing the editing pattern also clears its preview generator', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(pianoRollProvider.notifier);

    notifier.openPattern(12, previewGeneratorId: 34);
    notifier.clearEditingPattern();

    final state = container.read(pianoRollProvider);
    expect(state.editingPatternId, isNull);
    expect(state.previewGeneratorId, isNull);
    expect(state.selectedNoteIds, isEmpty);
  });
}
