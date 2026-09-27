import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karbeat/core/widgets/shortcut_focus_anchor.dart';

class _PlayIntent extends Intent {
  const _PlayIntent();
}

/// Mirrors the app shell: shortcuts above [MaterialApp], and the page's
/// [Actions] above the anchor.
Widget _workspace({required Widget body, required VoidCallback onPlay}) {
  return Shortcuts(
    shortcuts: const {SingleActivator(LogicalKeyboardKey.space): _PlayIntent()},
    child: MaterialApp(
      home: Actions(
        actions: {
          _PlayIntent: CallbackAction<_PlayIntent>(onInvoke: (_) => onPlay()),
        },
        child: ShortcutFocusAnchor(child: Scaffold(body: body)),
      ),
    ),
  );
}

class _Dropdown extends StatefulWidget {
  const _Dropdown();

  @override
  State<_Dropdown> createState() => _DropdownState();
}

class _DropdownState extends State<_Dropdown> {
  String _value = 'Alpha';

  @override
  Widget build(BuildContext context) {
    return DropdownButton<String>(
      value: _value,
      items: const [
        DropdownMenuItem(value: 'Alpha', child: Text('Alpha')),
        DropdownMenuItem(value: 'Beta', child: Text('Beta')),
      ],
      onChanged: (value) => setState(() => _value = value!),
    );
  }
}

Future<void> _pickBeta(WidgetTester tester) async {
  await tester.tap(find.text('Alpha'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Beta').last);
  await tester.pumpAndSettle();
}

void main() {
  final bodies = <String, Widget>{
    'page': const Center(child: _Dropdown()),
    'nested navigator': Navigator(
      onGenerateRoute: (settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const Material(child: Center(child: _Dropdown())),
      ),
    ),
  };

  for (final MapEntry(key: name, value: body) in bodies.entries) {
    testWidgets('returns focus from a closed dropdown on a $name', (
      tester,
    ) async {
      var plays = 0;
      await tester.pumpWidget(_workspace(body: body, onPlay: () => plays++));
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(plays, 1);

      await _pickBeta(tester);
      expect(find.text('Beta'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(plays, 2);
      expect(find.text('Alpha'), findsNothing, reason: 'menu stays closed');
    });
  }

  testWidgets('lets a text field keep focus and recovers when it goes away', (
    tester,
  ) async {
    var plays = 0;
    final showField = ValueNotifier(true);
    addTearDown(showField.dispose);

    await tester.pumpWidget(
      _workspace(
        onPlay: () => plays++,
        body: ValueListenableBuilder<bool>(
          valueListenable: showField,
          builder: (context, show, _) =>
              show ? const TextField() : const SizedBox.shrink(),
        ),
      ),
    );
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(plays, 0);
    expect(find.byType(EditableText), findsOneWidget);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isTrue,
    );

    showField.value = false;
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(plays, 1);
  });

  testWidgets('keeps focus on a keyboard region and hands it back there', (
    tester,
  ) async {
    var plays = 0;
    var notes = 0;
    final regionNode = FocusNode();
    addTearDown(regionNode.dispose);

    await tester.pumpWidget(
      _workspace(
        onPlay: () => plays++,
        body: KeyboardFocusRegion(
          focusNode: regionNode,
          onKeyEvent: (_, event) {
            if (event.logicalKey != LogicalKeyboardKey.keyZ) {
              return KeyEventResult.ignored;
            }
            if (event is KeyDownEvent) notes++;
            return KeyEventResult.handled;
          },
          child: const Center(child: _Dropdown()),
        ),
      ),
    );
    regionNode.requestFocus();
    await tester.pumpAndSettle();
    expect(regionNode.hasPrimaryFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(notes, 1);
    expect(plays, 1);

    await _pickBeta(tester);
    expect(regionNode.hasPrimaryFocus, isTrue);
  });

  testWidgets('leaves a dialog its focus and reclaims it once closed', (
    tester,
  ) async {
    var plays = 0;

    await tester.pumpWidget(
      _workspace(
        onPlay: () => plays++,
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                actions: [
                  TextButton(
                    autofocus: true,
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // Space activates the dialog's focused button instead of the shortcut.
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(find.text('Close'), findsNothing);
    expect(plays, 0);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(plays, 1);
  });
}
