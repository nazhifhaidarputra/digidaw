import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karbeat/core/widgets/context_menu.dart';

void main() {
  testWidgets('submenu choices open from a dropdown drawer', (tester) async {
    String? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDawContextMenu(
                context: context,
                actions: [
                  DawContextAction.submenu(
                    title: 'Curve type',
                    subtitle: 'Linear',
                    children: [
                      DawContextAction(
                        title: 'Linear',
                        onTap: () => picked = 'linear',
                      ),
                      DawContextAction(
                        title: 'Step',
                        onTap: () => picked = 'step',
                      ),
                    ],
                  ),
                ],
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Curve type'), findsOneWidget);
    expect(find.text('Step'), findsNothing);

    await tester.tap(find.text('Curve type'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Step'));
    await tester.pumpAndSettle();

    expect(picked, 'step');
    expect(find.text('Curve type'), findsNothing);
  });

  group('floating context panel', () {
    Future<List<String>> pumpPanel(WidgetTester tester, double width) async {
      final tapped = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: width,
                height: 200,
                child: Stack(
                  children: [
                    FloatingContextPanel(
                      title: 'Selected',
                      onClose: () {},
                      actions: [
                        for (final name in [
                          'Copy',
                          'Cut',
                          'Delete',
                          'Rename this clip',
                        ])
                          DawContextAction(
                            title: name,
                            icon: Icons.circle,
                            onTap: () => tapped.add(name),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      return tapped;
    }

    testWidgets('shows every action when they fit', (tester) async {
      await pumpPanel(tester, 700);
      for (final name in ['Copy', 'Cut', 'Delete', 'Rename this clip']) {
        expect(find.text(name), findsOneWidget);
      }
      expect(find.text('More…'), findsNothing);
    });

    testWidgets('moves the actions that do not fit behind More', (
      tester,
    ) async {
      // The test font draws every glyph as wide as its size.
      final tapped = await pumpPanel(tester, 520);
      expect(find.text('Copy'), findsOneWidget);
      expect(find.text('Rename this clip'), findsNothing);

      await tester.tap(find.text('More…'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rename this clip'));
      await tester.pumpAndSettle();
      expect(tapped, ['Rename this clip']);
    });
  });
}
