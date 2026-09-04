import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karbeat/core/input/input.dart';
import 'package:karbeat/core/input/shortcut_models.dart';
import 'package:karbeat/core/input/shortcut_preferences_service.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/features/setting/view/key_binding_settings_page.dart';

class _FakeShortcutPreferencesService extends ShortcutPreferencesService {
  IMap<String, ShortcutChord> saved = const IMapConst({});

  @override
  Future<Result<IMap<String, ShortcutChord>>> load() async => Result.ok(saved);

  @override
  Future<Result<void>> save(IMap<String, ShortcutChord> overrides) async {
    saved = overrides;
    return Result.ok(null);
  }
}

void main() {
  test('formats the Space shortcut with a visible label', () {
    expect(
      shortcutLabel(
        ShortcutChord(logicalKeyId: LogicalKeyboardKey.space.keyId),
      ),
      'SPACE',
    );
  });

  late ProviderContainer container;
  late _FakeShortcutPreferencesService preferences;

  setUp(() async {
    preferences = _FakeShortcutPreferencesService();
    container = ProviderContainer(
      overrides: [
        shortcutPreferencesServiceProvider.overrideWithValue(preferences),
      ],
    );
    await container.read(shortcutManagerProvider.notifier).initialize();
  });

  tearDown(() => container.dispose());

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: KeyBindingSettingsPage()),
        ),
      ),
    );
  }

  Finder changeButton(String id) => find.descendant(
    of: find.byKey(ValueKey('shortcut-$id')),
    matching: find.widgetWithText(OutlinedButton, 'Change'),
  );

  Future<void> enterChord(
    WidgetTester tester,
    LogicalKeyboardKey key, {
    LogicalKeyboardKey modifier = LogicalKeyboardKey.controlLeft,
  }) async {
    await tester.sendKeyDownEvent(modifier);
    await tester.sendKeyDownEvent(key);
    await tester.sendKeyUpEvent(key);
    await tester.sendKeyUpEvent(modifier);
    await tester.pumpAndSettle();
  }

  testWidgets('search filters command rows', (tester) async {
    await pumpPage(tester);

    await tester.enterText(
      find.byKey(const ValueKey('shortcut-search')),
      'Undo',
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('shortcut-workspace.undo')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('shortcut-workspace.save')), findsNothing);
  });

  testWidgets('captures a supported chord and reset-one restores default', (
    tester,
  ) async {
    await pumpPage(tester);

    await tester.tap(changeButton('workspace.save'));
    await tester.pumpAndSettle();
    await enterChord(tester, LogicalKeyboardKey.keyP);

    final remapped = container
        .read(shortcutManagerProvider.notifier)
        .activeChords()['workspace.save'];
    expect(remapped?.logicalKeyId, LogicalKeyboardKey.keyP.keyId);
    expect(preferences.saved.containsKey('workspace.save'), isTrue);

    await tester.tap(find.byTooltip('Reset Save Project'));
    await tester.pump();
    expect(
      container
          .read(shortcutManagerProvider)
          .overrides
          .containsKey('workspace.save'),
      isFalse,
    );
  });

  testWidgets('escape cancels capture without changing state', (tester) async {
    await pumpPage(tester);

    await tester.tap(changeButton('workspace.undo'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(container.read(shortcutManagerProvider).overrides, isEmpty);
  });

  testWidgets('conflict is shown and does not overwrite either command', (
    tester,
  ) async {
    await pumpPage(tester);

    await tester.tap(changeButton('workspace.undo'));
    await tester.pumpAndSettle();
    await enterChord(tester, LogicalKeyboardKey.keyS);

    expect(
      find.textContaining('Already assigned to Save Project'),
      findsOneWidget,
    );
    expect(container.read(shortcutManagerProvider).overrides, isEmpty);
  });

  testWidgets('reset all requires confirmation', (tester) async {
    await container
        .read(shortcutManagerProvider.notifier)
        .remap(
          'workspace.save',
          ShortcutChord(
            logicalKeyId: LogicalKeyboardKey.keyP.keyId,
            control: true,
          ),
        );
    await pumpPage(tester);

    await tester.tap(find.byKey(const ValueKey('reset-all-shortcuts')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Reset all'));
    await tester.pumpAndSettle();

    expect(container.read(shortcutManagerProvider).overrides, isEmpty);
  });
}
