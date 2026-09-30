import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karbeat/core/input/input.dart';
import 'package:karbeat/core/input/intents/song_timeline/playback_intent.dart';
import 'package:karbeat/core/input/text_input_shortcut_manager.dart';
import 'package:karbeat/core/widgets/shortcut_focus_anchor.dart';

void main() {
  testWidgets(
    'a focused text field owns letter keys until it loses focus',
    (tester) async {
      var loopToggles = 0;
      final manager = TextInputAwareShortcutManager();
      addTearDown(manager.dispose);

      await tester.pumpWidget(
        ProviderScope(
          child: Consumer(
            builder: (context, ref, _) {
              manager.shortcuts = ref.watch(activeShortcutMapProvider);
              return Shortcuts.manager(
                manager: manager,
                child: MaterialApp(
                  home: Actions(
                    actions: {
                      ToggleLoopIntent: CallbackAction<ToggleLoopIntent>(
                        onInvoke: (_) {
                          loopToggles += 1;
                          return null;
                        },
                      ),
                    },
                    child: const ShortcutFocusAnchor(
                      child: Scaffold(
                        body: Column(
                          children: [
                            TextField(key: Key('name')),
                            SizedBox(key: Key('outside'), height: 200),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pump();

      // The workspace shortcut works while nothing text-like has focus.
      await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
      expect(loopToggles, 1);

      await tester.tap(find.byKey(const Key('name')));
      await tester.pump();

      // Unhandled, so the platform delivers the character to the field.
      final handled = await tester.sendKeyDownEvent(LogicalKeyboardKey.keyL);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyL);
      expect(handled, isFalse);
      expect(loopToggles, 1);

      // Clicking outside unfocuses the field and the anchor reclaims focus.
      await tester.tapAt(tester.getCenter(find.byKey(const Key('outside'))));
      await tester.pump();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
      expect(loopToggles, 2);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );
}
