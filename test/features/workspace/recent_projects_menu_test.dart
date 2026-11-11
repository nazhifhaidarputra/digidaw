import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karbeat/core/input/input.dart';
import 'package:karbeat/core/input/shortcut_models.dart';
import 'package:karbeat/core/input/shortcut_preferences_service.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/features/setting/models/general_settings_state.dart';
import 'package:karbeat/features/setting/services/general_settings_provider.dart';
import 'package:karbeat/features/workspace/services/recent_projects_service.dart';
import 'package:karbeat/features/workspace/view/side_panel.dart';
import 'package:karbeat/shared/models/menu_group.dart';
import 'package:karbeat/src/rust/api/settings.dart';

class _FakeShortcutPreferencesService extends ShortcutPreferencesService {
  @override
  Future<Result<IMap<String, ShortcutChord>>> load() async =>
      Result.ok(const IMapConst({}));

  @override
  Future<Result<void>> save(IMap<String, ShortcutChord> overrides) async =>
      Result.ok(null);
}

class _FakeRecentProjectsService extends RecentProjectsService {
  _FakeRecentProjectsService(this.projects);

  List<UiRecentProject> projects;
  int loadCount = 0;
  final removed = <String>[];

  @override
  Future<Result<IList<UiRecentProject>>> load() async {
    loadCount += 1;
    return Result.ok(projects.lock);
  }

  @override
  Future<Result<void>> remove(String path) async {
    removed.add(path);
    projects = [
      for (final project in projects)
        if (project.path != path) project,
    ];
    return Result.ok(null);
  }

  @override
  Future<Result<void>> clear() async {
    projects = [];
    return Result.ok(null);
  }
}

class _GeneralSettings extends GeneralSettingsNotifier {
  _GeneralSettings({required this.showRecentProjects});

  final bool showRecentProjects;

  @override
  GeneralSettingsState build() =>
      GeneralSettingsState(showRecentProjects: showRecentProjects);
}

const _projectA = UiRecentProject(
  path: '/home/me/music/a.dgdaw',
  label: '~/music/a.dgdaw',
  exists: true,
);
const _projectB = UiRecentProject(
  path: '/home/me/music/b.dgdaw',
  label: '~/music/b.dgdaw',
  exists: true,
);
const _gone = UiRecentProject(
  path: '/home/me/music/gone.dgdaw',
  label: '~/music/gone.dgdaw',
  exists: false,
);

/// Shows the real Project menu. Choosing an action runs its callback, as the
/// main screen does after closing the panel.
Future<_FakeRecentProjectsService> _pumpProjectMenu(
  WidgetTester tester, {
  bool showRecentProjects = true,
  List<UiRecentProject> projects = const [_projectA, _projectB],
}) async {
  final service = _FakeRecentProjectsService(projects);
  final container = ProviderContainer(
    overrides: [
      shortcutPreferencesServiceProvider.overrideWithValue(
        _FakeShortcutPreferencesService(),
      ),
      recentProjectsServiceProvider.overrideWithValue(service),
      generalSettingsProvider.overrideWith(
        () => _GeneralSettings(showRecentProjects: showRecentProjects),
      ),
    ],
  );
  addTearDown(container.dispose);
  await container.read(shortcutManagerProvider.notifier).initialize();
  await tester.binding.setSurfaceSize(const Size(1200, 800));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: Builder(
              builder: (context) => Consumer(
                builder: (context, ref, _) => ContextPanel(
                  group: DawToolbarMenuGroupFactory.createProjectMenuGroup(),
                  onAction: (action) => action.callback?.call(context, ref),
                  onClose: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  return service;
}

Future<void> _openRecent(WidgetTester tester) async {
  await tester.tap(find.text('Open recent'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Open recent is hidden when the setting is off', (tester) async {
    await _pumpProjectMenu(tester, showRecentProjects: false);

    expect(find.text('Open project'), findsOneWidget);
    expect(find.text('Open recent'), findsNothing);
  });

  testWidgets('the submenu opens beside the panel, newest first', (
    tester,
  ) async {
    await _pumpProjectMenu(tester);
    expect(find.text('~/music/a.dgdaw'), findsNothing);

    await _openRecent(tester);

    final a = tester.getRect(find.text('~/music/a.dgdaw'));
    final b = tester.getRect(find.text('~/music/b.dgdaw'));
    expect(a.top, lessThan(b.top));
    // Like a desktop submenu, it sits to the right of the 240 px panel.
    expect(a.left, greaterThanOrEqualTo(240));
    expect(find.text('Clear Recently Opened'), findsOneWidget);
  });

  testWidgets('hovering Open recent opens the submenu', (tester) async {
    await _pumpProjectMenu(tester);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.text('Open recent')));
    await tester.pumpAndSettle();

    expect(find.text('~/music/a.dgdaw'), findsOneWidget);
  });

  testWidgets('the list is read again each time the submenu opens', (
    tester,
  ) async {
    final service = await _pumpProjectMenu(tester);
    await _openRecent(tester);
    expect(service.loadCount, 1);

    await tester.tap(find.text('Open recent'));
    await tester.pumpAndSettle();
    expect(find.text('~/music/a.dgdaw'), findsNothing);

    service.projects = [_projectB, _projectA];
    await _openRecent(tester);
    expect(service.loadCount, 2);
    final a = tester.getRect(find.text('~/music/a.dgdaw'));
    final b = tester.getRect(find.text('~/music/b.dgdaw'));
    expect(b.top, lessThan(a.top));
  });

  testWidgets('a missing project can be removed from the list', (tester) async {
    final service = await _pumpProjectMenu(
      tester,
      projects: const [_gone, _projectA],
    );
    await _openRecent(tester);

    await tester.tap(find.text('~/music/gone.dgdaw'));
    await tester.pumpAndSettle();
    expect(find.text('Project not found'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('recent-project-forget')));
    await tester.pumpAndSettle();
    expect(service.removed, [_gone.path]);
  });

  testWidgets('Clear Recently Opened empties the list', (tester) async {
    final service = await _pumpProjectMenu(tester);
    await _openRecent(tester);

    await tester.tap(find.text('Clear Recently Opened'));
    await tester.pumpAndSettle();
    expect(service.projects, isEmpty);

    await _openRecent(tester);
    expect(find.text('No recent projects'), findsOneWidget);
  });
}
