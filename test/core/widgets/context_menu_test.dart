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
}
