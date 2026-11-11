import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/features/setting/models/general_settings_state.dart';
import 'package:karbeat/features/setting/services/general_settings_provider.dart';
import 'package:karbeat/features/setting/services/settings_service.dart';
import 'package:karbeat/features/setting/view/general_settings_page.dart';
import 'package:karbeat/src/rust/api/mitigation.dart';
import 'package:karbeat/src/rust/api/settings.dart';

class _RecordingGeneralSettingsNotifier extends GeneralSettingsNotifier {
  _RecordingGeneralSettingsNotifier(this.initial);

  final GeneralSettingsState initial;
  final enabledCalls = <bool>[];
  final intervalCalls = <int>[];
  final chooseCalls = <DefaultFolder>[];
  final setCalls = <(DefaultFolder, String?)>[];
  final showRecentCalls = <bool>[];

  @override
  GeneralSettingsState build() => initial;

  @override
  Future<Result<void>> setAutoSaveEnabled(bool enabled) async {
    enabledCalls.add(enabled);
    state = state.copyWith(autoSaveEnabled: enabled);
    return Result.ok(null);
  }

  @override
  Future<Result<void>> setAutoSaveInterval(int seconds) async {
    intervalCalls.add(seconds);
    state = state.copyWith(autoSaveIntervalSeconds: seconds);
    return Result.ok(null);
  }

  @override
  Future<Result<void>> chooseDefaultFolder(DefaultFolder kind) async {
    chooseCalls.add(kind);
    return Result.ok(null);
  }

  @override
  Future<Result<void>> setDefaultFolder(
    DefaultFolder kind,
    String? folder,
  ) async {
    setCalls.add((kind, folder));
    return Result.ok(null);
  }

  @override
  Future<Result<void>> setShowRecentProjects(bool visible) async {
    showRecentCalls.add(visible);
    state = state.copyWith(showRecentProjects: visible);
    return Result.ok(null);
  }
}

/// Saves folders in memory; folders listed in [existing] exist.
class _FakeSettingsService extends SettingsService {
  final existing = <String>{};
  String? projectFolder;
  String? exportFolder;

  UiGeneralSettings get _settings => UiGeneralSettings(
    historyLimit: 100,
    autoSave: const UiAutoSaveSettings(isEnabled: true, intervalSeconds: 300),
    defaultProjectFolder: projectFolder,
    defaultExportFolder: exportFolder,
    showRecentProjects: true,
  );

  @override
  Future<Result<UiGeneralSettings>> saveDefaultProjectFolder(
    String? folder,
  ) async {
    projectFolder = folder;
    return Result.ok(_settings);
  }

  @override
  Future<Result<UiGeneralSettings>> saveDefaultExportFolder(
    String? folder,
  ) async {
    exportFolder = folder;
    return Result.ok(_settings);
  }

  @override
  Future<bool> folderExists(String path) async => existing.contains(path);
}

Future<_RecordingGeneralSettingsNotifier> _pumpPage(
  WidgetTester tester,
  GeneralSettingsState initial,
) async {
  final notifier = _RecordingGeneralSettingsNotifier(initial);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [generalSettingsProvider.overrideWith(() => notifier)],
      child: MaterialApp(
        theme: ThemeData.dark(),
        home: const Scaffold(body: GeneralSettingsPage()),
      ),
    ),
  );
  return notifier;
}

void main() {
  test('auto save interval bounds match the engine', () {
    expect(SettingsService.isValidAutoSaveInterval(60), isTrue);
    expect(SettingsService.isValidAutoSaveInterval(3600), isTrue);
    expect(SettingsService.isValidAutoSaveInterval(59), isFalse);
    expect(SettingsService.isValidAutoSaveInterval(3601), isFalse);
  });

  testWidgets('auto save switch and interval dispatch updates', (tester) async {
    final notifier = await _pumpPage(tester, const GeneralSettingsState());

    expect(find.text('5 minutes'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('auto-save-enabled-switch')));
    await tester.pump();
    expect(notifier.enabledCalls, [false]);

    await tester.tap(find.byKey(const ValueKey('auto-save-enabled-switch')));
    await tester.pump();
    await tester.tap(find.text('5 minutes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('10 minutes').last);
    await tester.pumpAndSettle();

    expect(notifier.enabledCalls, [false, true]);
    expect(notifier.intervalCalls, [600]);
    expect(find.text('10 minutes'), findsOneWidget);
  });

  testWidgets('interval is locked while auto save is disabled', (tester) async {
    final notifier = await _pumpPage(
      tester,
      const GeneralSettingsState(autoSaveEnabled: false),
    );

    await tester.tap(find.text('5 minutes'));
    await tester.pumpAndSettle();

    expect(find.text('10 minutes'), findsNothing);
    expect(notifier.intervalCalls, isEmpty);
  });

  testWidgets('a persisted non-preset interval stays selectable', (
    tester,
  ) async {
    await _pumpPage(
      tester,
      const GeneralSettingsState(autoSaveIntervalSeconds: 90),
    );

    expect(find.text('90 seconds'), findsOneWidget);
  });

  testWidgets('unset folders can be chosen', (tester) async {
    final notifier = await _pumpPage(tester, const GeneralSettingsState());

    expect(find.textContaining('Not set'), findsNWidgets(2));
    expect(
      find.byKey(const ValueKey('default-folder-project-reset')),
      findsNothing,
    );

    final choose = find.byKey(const ValueKey('default-folder-project-choose'));
    await tester.ensureVisible(choose);
    await tester.tap(choose);
    await tester.pump();
    expect(notifier.chooseCalls, [DefaultFolder.project]);
  });

  testWidgets('a missing folder is flagged and can be reset', (tester) async {
    final notifier = await _pumpPage(
      tester,
      GeneralSettingsState(
        defaultExportFolder: '/gone/exports',
        missingFolders: ISet(const {DefaultFolder.export}),
      ),
    );

    expect(find.text('/gone/exports'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('default-folder-export-missing')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('default-folder-project-missing')),
      findsNothing,
    );

    final reset = find.byKey(const ValueKey('default-folder-export-reset'));
    await tester.ensureVisible(reset);
    await tester.tap(reset);
    await tester.pump();
    expect(notifier.setCalls, [(DefaultFolder.export, null)]);
  });

  test('saving a folder publishes it and whether it exists', () async {
    final service = _FakeSettingsService()..existing.add('/projects');
    final container = ProviderContainer(
      overrides: [settingsServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(generalSettingsProvider.notifier);

    await notifier.setDefaultFolder(DefaultFolder.project, '/projects');
    var state = container.read(generalSettingsProvider);
    expect(state.defaultProjectFolder, '/projects');
    expect(state.usableFolder(DefaultFolder.project), '/projects');
    expect(state.missingFolders, isEmpty);

    service.existing.remove('/projects');
    await notifier.setDefaultFolder(DefaultFolder.export, '/exports');
    state = container.read(generalSettingsProvider);
    expect(state.missingFolders, {DefaultFolder.project, DefaultFolder.export});
    expect(state.usableFolder(DefaultFolder.project), isNull);

    await notifier.setDefaultFolder(DefaultFolder.export, null);
    state = container.read(generalSettingsProvider);
    expect(state.defaultExportFolder, isNull);
    expect(state.missingFolders, {DefaultFolder.project});
  });

  testWidgets('recent projects can be hidden', (tester) async {
    final notifier = await _pumpPage(tester, const GeneralSettingsState());
    final toggle = find.byKey(const ValueKey('show-recent-projects-switch'));
    await tester.ensureVisible(toggle);
    expect(tester.widget<SwitchListTile>(toggle).value, isTrue);

    await tester.tap(toggle);
    await tester.pump();

    expect(notifier.showRecentCalls, [false]);
    expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
  });
}
