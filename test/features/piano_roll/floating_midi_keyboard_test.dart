import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/features/piano_roll/view/floating_midi_keyboard.dart';

class _LoadingProjectNotifier extends ProjectNotifier {
  @override
  Future<ApplicationDataStore> build() =>
      Completer<ApplicationDataStore>().future;
}

void main() {
  testWidgets('reclaims focus and maps computer keys to visible notes', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [projectProvider.overrideWith(_LoadingProjectNotifier.new)],
        child: MaterialApp(
          home: Scaffold(
            body: Stack(
              children: const [
                Focus(autofocus: true, child: SizedBox()),
                FloatingMidiKeyboard(),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final handled = await tester.sendKeyDownEvent(
      LogicalKeyboardKey.keyQ,
      physicalKey: PhysicalKeyboardKey.keyQ,
    );
    await tester.pump();

    expect(handled, isTrue);
    expect(tester.widget<Text>(find.text('C4')).style?.color, Colors.black);

    await tester.sendKeyDownEvent(
      LogicalKeyboardKey.comma,
      physicalKey: PhysicalKeyboardKey.comma,
    );
    await tester.sendKeyUpEvent(
      LogicalKeyboardKey.keyQ,
      physicalKey: PhysicalKeyboardKey.keyQ,
    );
    await tester.pump();

    expect(tester.widget<Text>(find.text('C4')).style?.color, Colors.black);

    await tester.sendKeyUpEvent(
      LogicalKeyboardKey.comma,
      physicalKey: PhysicalKeyboardKey.comma,
    );
    await tester.pump();

    expect(
      tester.widget<Text>(find.text('C4')).style?.color,
      Colors.grey.shade600,
    );
  });
}
