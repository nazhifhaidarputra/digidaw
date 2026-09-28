import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karbeat/app/providers/blocking_task_provider.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/core/widgets/blocking_task_overlay.dart';

class _PingIntent extends Intent {
  const _PingIntent();
}

void main() {
  testWidgets('blocks pointer and keyboard input until the task settles', (
    tester,
  ) async {
    final task = Completer<Result<void>>();
    var taps = 0;
    var shortcuts = 0;
    late WidgetRef widgetRef;

    await tester.pumpWidget(
      ProviderScope(
        child: Shortcuts(
          shortcuts: const {
            SingleActivator(LogicalKeyboardKey.keyP): _PingIntent(),
          },
          child: Actions(
            actions: {
              _PingIntent: CallbackAction<_PingIntent>(
                onInvoke: (_) => shortcuts++,
              ),
            },
            child: MaterialApp(
              builder: (context, child) => BlockingTaskOverlay(child: child!),
              home: Consumer(
                builder: (context, ref, _) {
                  widgetRef = ref;
                  return Scaffold(
                    body: Center(
                      child: Focus(
                        autofocus: true,
                        child: FilledButton(
                          onPressed: () => taps++,
                          child: const Text('Target'),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
    expect(shortcuts, 1);

    unawaited(
      widgetRef
          .read(blockingTaskProvider.notifier)
          .run(label: 'Saving project...', task: () => task.future),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const ValueKey('blocking-task-overlay')), findsOneWidget);
    expect(find.text('Saving project...'), findsOneWidget);

    await tester.tap(find.text('Target'), warnIfMissed: false);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
    expect(taps, 0);
    expect(shortcuts, 1);

    task.complete(Result.ok(null));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const ValueKey('blocking-task-overlay')), findsNothing);
    await tester.tap(find.text('Target'));
    await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
    expect(taps, 1);
    expect(shortcuts, 2);
  });
}
