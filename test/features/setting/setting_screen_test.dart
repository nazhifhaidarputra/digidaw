import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karbeat/features/setting/models/setting_state.dart';
import 'package:karbeat/features/setting/services/setting_provider.dart';
import 'package:karbeat/features/setting/view/setting_screen.dart';
import 'package:karbeat/shared/models/menu_group.dart';

void main() {
  test('settings provider defaults to General and retains selection', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(settingsProvider).selectedMenu, SettingMenu.general);

    container
        .read(settingsProvider.notifier)
        .selectMenu(SettingMenu.appearance);

    expect(
      container.read(settingsProvider).selectedMenu,
      SettingMenu.appearance,
    );
  });

  testWidgets('all setting menus render without overflow', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final size in [const Size(1000, 600), const Size(640, 360)]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: const SettingScreen(),
          ),
        ),
      );

      for (final menu in SettingMenu.values) {
        final menuItem = find.byKey(ValueKey(menu));
        if (menuItem.evaluate().isEmpty) {
          await tester.scrollUntilVisible(
            menuItem,
            80,
            scrollable: find.byType(Scrollable).first,
          );
        }
        await tester.tap(menuItem);
        await tester.pump();
        expect(
          find.byKey(ValueKey('settings-page-${menu.name}')),
          findsOneWidget,
        );
        expect(
          tester.takeException(),
          isNull,
          reason: '${size.width}x${size.height}: ${menu.name}',
        );
      }
    }
  });

  testWidgets('Project settings action pushes and closes the route', (
    tester,
  ) async {
    final projectMenu = DawToolbarMenuGroupFactory.createProjectMenuGroup();
    final settingsAction = projectMenu.actions.singleWhere(
      (action) => action.title == 'Settings',
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, child) {
              return TextButton(
                onPressed: () => settingsAction.callback?.call(context, ref),
                child: const Text('Open settings'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingScreen), findsOneWidget);

    await tester.tap(find.byTooltip('Close settings'));
    await tester.pumpAndSettle();
    expect(find.text('Open settings'), findsOneWidget);
  });
}
