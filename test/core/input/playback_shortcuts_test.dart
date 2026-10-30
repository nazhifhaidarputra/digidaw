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

  testWidgets('Ctrl+Alt+R records the selected track and Ctrl+Alt+E stops', (
    tester,
  ) async {
    var recordCount = 0;
    var stopRecordingCount = 0;

    await _pumpShortcutHarness(
      tester,
      onToggle: () {},
      onStop: () {},
      extraActions: {
        RecordSelectedTrackIntent: CallbackAction<RecordSelectedTrackIntent>(
          onInvoke: (_) {
            recordCount += 1;
            return null;
          },
        ),
        StopRecordingIntent: CallbackAction<StopRecordingIntent>(
          onInvoke: (_) {
            stopRecordingCount += 1;
            return null;
          },
        ),
      },
      child: const Focus(autofocus: true, child: SizedBox()),
    );

    await _sendChord(tester, LogicalKeyboardKey.keyR);
    await _sendChord(tester, LogicalKeyboardKey.keyE);

    expect(recordCount, 1);
    expect(stopRecordingCount, 1);
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

/// Presses Ctrl+Alt+[key].
Future<void> _sendChord(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
}

Future<void> _pumpShortcutHarness(
  WidgetTester tester, {
  required VoidCallback onToggle,
  required VoidCallback onStop,
  required Widget child,
  Map<Type, Action<Intent>> extraActions = const {},
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
                ...extraActions,
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
