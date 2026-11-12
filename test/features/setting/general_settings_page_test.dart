import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/features/setting/models/general_settings_state.dart';
import 'package:karbeat/features/setting/models/language_state.dart';
import 'package:karbeat/features/setting/services/general_settings_provider.dart';
import 'package:karbeat/features/setting/services/language_provider.dart';
import 'package:karbeat/features/setting/services/settings_service.dart';
import 'package:karbeat/features/setting/view/general_settings_page.dart';
import 'package:karbeat/src/rust/api/l10n.dart';
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

class _RecordingLanguageNotifier extends LanguageNotifier {
  _RecordingLanguageNotifier(this.initial);

  final LanguageState initial;
  final setCalls = <String?>[];

  @override
  LanguageState build() => initial;

  @override
  Future<Result<void>> setLanguage(String? code) async {
    setCalls.add(code);
    state = state.copyWith(
      selected: code,
      active: code == null ? state.system : state.language(code),
    );
    return Result.ok(null);
  }
}

UiLanguage _language(String code, String native, String english, String flag) {
  return UiLanguage(
    code: code,
    nativeName: native,
    englishName: english,
    flag: flag,
  );
}

final _english = _language('en-US', 'English (US)', 'English (US)', 'us');
final _japanese = _language('ja-JP', '日本語', 'Japanese', 'jp');

final _languages = [
  _english,
  _language('id-ID', 'Bahasa Indonesia', 'Indonesian', 'id'),
  _japanese,
  _language('fr-FR', 'Français', 'French', 'fr'),
  _language('es-ES', 'Español (España)', 'Spanish (Spain)', 'es'),
  _language('pt-PT', 'Português (Portugal)', 'Portuguese (Portugal)', 'pt'),
  _language('nl-NL', 'Nederlands', 'Dutch', 'nl'),
  _language('ko-KR', '한국어', 'Korean', 'kr'),
  _language('zh-CN', '简体中文', 'Chinese (Simplified)', 'cn'),
  _language('it-IT', 'Italiano', 'Italian', 'it'),
  _language('de-DE', 'Deutsch', 'German', 'de'),
].lock;

LanguageState _languageState({String? selected}) => LanguageState(
  languages: _languages,
  selected: selected,
  active: selected == null
      ? _english
      : _languages.firstWhere((language) => language.code == selected),
  system: _english,
);

Future<_RecordingGeneralSettingsNotifier> _pumpPage(
  WidgetTester tester,
  GeneralSettingsState initial, {
  _RecordingLanguageNotifier? language,
}) async {
  final notifier = _RecordingGeneralSettingsNotifier(initial);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        generalSettingsProvider.overrideWith(() => notifier),
        if (language != null) languageProvider.overrideWith(() => language),
      ],
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

  group('language selector', () {
    Future<void> openSelector(WidgetTester tester) async {
      // Tall enough for the whole menu, which builds only visible items.
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pump();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
    }

    Future<void> choose(WidgetTester tester, String code) async {
      await openSelector(tester);
      await tester.tap(find.byKey(ValueKey('language-option-$code')).last);
      await tester.pumpAndSettle();
    }

    testWidgets('lists the system default and every language with its flag', (
      tester,
    ) async {
      final language = _RecordingLanguageNotifier(_languageState());
      await _pumpPage(tester, const GeneralSettingsState(), language: language);

      expect(find.text('System default (English (US))'), findsOneWidget);
      await openSelector(tester);

      expect(
        find.byKey(const ValueKey('language-option-system')),
        findsWidgets,
      );
      for (final option in _languages) {
        expect(
          find.byKey(ValueKey('language-option-${option.code}')),
          findsWidgets,
        );
        expect(
          find.byKey(ValueKey('language-flag-${option.flag}')),
          findsWidgets,
        );
      }
    });

    testWidgets('warns in the current and the new language; cancel keeps it', (
      tester,
    ) async {
      final language = _RecordingLanguageNotifier(_languageState());
      await _pumpPage(tester, const GeneralSettingsState(), language: language);

      await choose(tester, 'ja-JP');

      expect(
        find.byKey(const ValueKey('language-change-dialog')),
        findsOneWidget,
      );
      expect(
        find.text(
          'You are going to change your app language. Remember where the '
          'menu is so that you are not lost in translation. Are you sure you '
          'want to change your language?',
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('language-change-target-message')),
          matching: find.textContaining('アプリの言語を変更しようとしています'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('language-change-cancel')));
      await tester.pumpAndSettle();

      expect(language.setCalls, isEmpty);
      expect(find.text('System default (English (US))'), findsOneWidget);
    });

    testWidgets('confirming saves the chosen language', (tester) async {
      final language = _RecordingLanguageNotifier(_languageState());
      await _pumpPage(tester, const GeneralSettingsState(), language: language);

      await choose(tester, 'ja-JP');
      await tester.tap(find.byKey(const ValueKey('language-change-confirm')));
      await tester.pumpAndSettle();

      expect(language.setCalls, ['ja-JP']);
    });

    testWidgets('going back to the system default also asks first', (
      tester,
    ) async {
      final language = _RecordingLanguageNotifier(
        _languageState(selected: 'ja-JP'),
      );
      await _pumpPage(tester, const GeneralSettingsState(), language: language);

      await choose(tester, 'system');
      expect(
        find.byKey(const ValueKey('language-change-current-message')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('language-change-target-message')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('language-change-confirm')));
      await tester.pumpAndSettle();

      expect(language.setCalls, [null]);
    });
  });
}
