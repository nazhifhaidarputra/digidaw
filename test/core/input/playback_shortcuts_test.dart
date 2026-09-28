import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karbeat/core/input/input.dart';
import 'package:karbeat/core/input/intents/song_timeline/playback_intent.dart';

void main() {
  testWidgets('Space toggles playback and End stops playback', (tester) async {
    var toggleCount = 0;
    var stopCount = 0;

    await _pumpShortcutHarness(
      tester,
      onToggle: () => toggleCount += 1,
      onStop: () => stopCount += 1,
      child: const Focus(autofocus: true, child: SizedBox()),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.sendKeyEvent(LogicalKeyboardKey.end);

    expect(toggleCount, 1);
    expect(stopCount, 1);
  });

  testWidgets('playback shortcuts do not intercept text editing keys', (
    tester,
  ) async {
    var toggleCount = 0;
    var stopCount = 0;

    await _pumpShortcutHarness(
      tester,
      onToggle: () => toggleCount += 1,
      onStop: () => stopCount += 1,
      child: const TextField(autofocus: true),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.sendKeyEvent(LogicalKeyboardKey.end);

    expect(toggleCount, 0);
    expect(stopCount, 0);
  });

  testWidgets('focused controls retain their Space activation', (tester) async {
    var toggleCount = 0;
    var buttonCount = 0;
    final buttonFocus = FocusNode();
    addTearDown(buttonFocus.dispose);

    await _pumpShortcutHarness(
      tester,
      onToggle: () => toggleCount += 1,
      onStop: () {},
      child: ElevatedButton(
        focusNode: buttonFocus,
        onPressed: () => buttonCount += 1,
        child: const Text('Control'),
      ),
    );
    buttonFocus.requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.space);

    expect(buttonCount, 1);
    expect(toggleCount, 0);
  });
}

Future<void> _pumpShortcutHarness(
  WidgetTester tester, {
  required VoidCallback onToggle,
  required VoidCallback onStop,
  required Widget child,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      child: Consumer(
        builder: (context, ref, _) => Shortcuts(
          shortcuts: ref.watch(activeShortcutMapProvider),
          child: MaterialApp(
            home: Actions(
              actions: {
                TogglePlayIntent: CallbackAction<TogglePlayIntent>(
                  onInvoke: (_) {
                    onToggle();
                    return null;
                  },
                ),
                StopIntent: CallbackAction<StopIntent>(
                  onInvoke: (_) {
                    onStop();
                    return null;
                  },
                ),
              },
              child: Scaffold(body: child),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}
