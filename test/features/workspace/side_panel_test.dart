import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karbeat/core/input/input.dart';
import 'package:karbeat/core/input/shortcut_models.dart';
import 'package:karbeat/core/input/shortcut_preferences_service.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/features/workspace/view/side_panel.dart';
import 'package:karbeat/shared/enums/global.dart';
import 'package:karbeat/shared/models/menu_group.dart';

class _FakeShortcutPreferencesService extends ShortcutPreferencesService {
  @override
  Future<Result<IMap<String, ShortcutChord>>> load() async =>
      Result.ok(const IMapConst({}));

  @override
  Future<Result<void>> save(IMap<String, ShortcutChord> overrides) async =>
      Result.ok(null);
}

void main() {
  testWidgets('shortcut hints follow the active key bindings', (tester) async {
    final container = ProviderContainer(
      overrides: [
        shortcutPreferencesServiceProvider.overrideWithValue(
          _FakeShortcutPreferencesService(),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(shortcutManagerProvider.notifier).initialize();

    final group = DawToolbarMenuGroup(
      id: ToolbarMenuContextGroup.project,
      title: 'Project',
      icon: Icons.work,
      actions: [
        DawToolbarMenuAction('Save Project', shortcutId: 'workspace.save'),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: ContextPanel(group: group, onAction: (_) {}, onClose: () {}),
          ),
        ),
      ),
    );

    expect(find.text('Ctrl+S'), findsOneWidget);

    await container
        .read(shortcutManagerProvider.notifier)
        .remap(
          'workspace.save',
          ShortcutChord(
            logicalKeyId: LogicalKeyboardKey.keyP.keyId,
            control: true,
          ),
        );
    await tester.pump();

    expect(find.text('Ctrl+P'), findsOneWidget);
  });
}
