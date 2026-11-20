import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karbeat/app/app_theme.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/features/setting/models/app_fonts.dart';
import 'package:karbeat/features/setting/models/appearance_settings_state.dart';
import 'package:karbeat/features/setting/services/appearance_asset_service.dart';
import 'package:karbeat/features/setting/services/appearance_preferences_service.dart';
import 'package:karbeat/features/setting/services/appearance_settings_provider.dart';
import 'package:karbeat/features/setting/services/color_theme_parser.dart';
import 'package:karbeat/features/setting/services/system_font_service.dart';
import 'package:karbeat/features/setting/view/appearance_settings_page.dart';
import 'package:karbeat/src/rust/api/settings.dart';

class _FakeAppearanceService extends AppearancePreferencesService {
  AppearancePreferences loaded = (
    themeMode: AppThemeMode.light,
    colorPalette: AppColorPalette.teal,
    backgroundImagePath: null,
    backgroundFit: AppBackgroundFit.cover,
    backgroundOverlayOpacity: 0.35,
    font: AppFontChoice.defaultFont,
    colorThemeSource: AppearanceAssetService.defaultColorThemeSource,
    customColorThemePaths: const [],
  );
  AppearancePreferences? saved;

  @override
  Future<Result<AppearancePreferences>> load() async => Result.ok(loaded);

  @override
  Future<Result<void>> save(AppearancePreferences value) async {
    saved = value;
    return Result.ok(null);
  }
}

class _FakeAssetService extends AppearanceAssetService {
  String? backgroundSelection;
  String? fontSelection;
  String? colorThemeSelection;
  final Map<String, String> colorThemeFiles = {
    for (final asset in AppearanceAssetService.bundledColorThemes)
      asset: _themeJson(
        asset == AppearanceAssetService.defaultColorThemeSource
            ? 'DigiDAW Dark'
            : asset,
        primary: asset == AppearanceAssetService.defaultColorThemeSource
            ? '#CFB8D9'
            : '#CBA6F7',
      ),
  };
  bool exists = true;
  bool fontLoads = true;

  @override
  Future<Result<String?>> pickBackgroundImage() async =>
      Result.ok(backgroundSelection);

  @override
  Future<Result<String?>> pickFontFile() async => Result.ok(fontSelection);

  @override
  Future<Result<bool>> fileExists(String path) async => Result.ok(exists);

  @override
  Future<Result<String?>> pickColorThemeFile() async =>
      Result.ok(colorThemeSelection);

  @override
  Future<Result<String>> readColorTheme(String source) async {
    final text = colorThemeFiles[source];
    return text == null
        ? Result.error(Exception('theme missing'))
        : Result.ok(text);
  }

  @override
  Future<Result<void>> loadFont(String path, String family) async =>
      fontLoads ? Result.ok(null) : Result.error(Exception('font missing'));
}

class _FakeSystemFontService extends SystemFontService {
  _FakeSystemFontService(this.family);

  final String? family;

  @override
  Future<String?> interfaceFontFamily() async => family;
}

String _themeJson(String name, {String primary = '#cba6f7'}) => jsonEncode({
  'name': name,
  'brightness': 'dark',
  'colors': {
    'primary': primary,
    'onPrimary': '#11111b',
    'secondary': '#89b4fa',
    'onSecondary': '#11111b',
    'error': '#f38ba8',
    'onError': '#11111b',
    'surface': '#1e1e2e',
    'onSurface': '#cdd6f4',
  },
});

void main() {
  test('restores and persists appearance preferences', () async {
    final service = _FakeAppearanceService();
    final container = ProviderContainer(
      overrides: [
        appearancePreferencesServiceProvider.overrideWithValue(service),
        appearanceAssetServiceProvider.overrideWithValue(_FakeAssetService()),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(appearanceSettingsProvider.notifier);

    final initialized = await notifier.initialize();
    final changed = await notifier.setColorPalette(AppColorPalette.blue);

    expect(initialized.isOk(), isTrue);
    expect(changed.isOk(), isTrue);
    expect(
      container.read(appearanceSettingsProvider).themeMode,
      AppThemeMode.light,
    );
    expect(
      container.read(appearanceSettingsProvider).colorPalette,
      AppColorPalette.blue,
    );
    expect(service.saved?.colorPalette, AppColorPalette.blue);
  });

  testWidgets('appearance controls update provider state', (tester) async {
    final service = _FakeAppearanceService()
      ..loaded = (
        themeMode: AppThemeMode.light,
        colorPalette: AppColorPalette.teal,
        backgroundImagePath: null,
        backgroundFit: AppBackgroundFit.cover,
        backgroundOverlayOpacity: 0.35,
        font: AppFontChoice.defaultFont,
        colorThemeSource: null,
        customColorThemePaths: const [],
      );
    final container = ProviderContainer(
      overrides: [
        appearancePreferencesServiceProvider.overrideWithValue(service),
        appearanceAssetServiceProvider.overrideWithValue(_FakeAssetService()),
      ],
    );
    addTearDown(container.dispose);
    await container.read(appearanceSettingsProvider.notifier).initialize();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(AppColorPalette.teal),
          darkTheme: AppTheme.dark(AppColorPalette.teal),
          themeMode: ThemeMode.light,
          home: const Scaffold(body: AppearanceSettingsPage()),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('palette-red')));
    await tester.pump();
    await tester.tap(find.text('Dark'));
    await tester.pump();

    expect(
      container.read(appearanceSettingsProvider).colorPalette,
      AppColorPalette.red,
    );
    expect(
      container.read(appearanceSettingsProvider).themeMode,
      AppThemeMode.dark,
    );
  });

  test('derived themes use requested brightness and palette', () {
    final light = AppTheme.light(AppColorPalette.orange);
    final dark = AppTheme.dark(
      AppColorPalette.orange,
      fontFamily: 'StudioFont',
    );

    expect(light.brightness, Brightness.light);
    expect(dark.brightness, Brightness.dark);
    expect(light.colorScheme.primary, isNot(dark.colorScheme.primary));
    expect(dark.textTheme.bodyMedium?.fontFamily, 'StudioFont');
    expect(dark.appBarTheme.backgroundColor, dark.colorScheme.surfaceContainer);
    expect(
      dark.floatingActionButtonTheme.backgroundColor,
      dark.colorScheme.primaryContainer,
    );
    expect(AppTheme.themeMode(AppThemeMode.system), ThemeMode.system);
  });

  test('every palette has its own accent colour', () {
    final seeds = AppColorPalette.values.map(AppTheme.seedColor).toSet();

    expect(AppColorPalette.values, hasLength(13));
    expect(seeds, hasLength(AppColorPalette.values.length));
  });

  group('background decode size', () {
    const display = Size(1920, 1080);

    test('a wide image covering the display keeps the display height', () {
      // Cover scales by height here, so decoding to the display width alone
      // would leave too few rows
      expect(
        backgroundDecodeSize(
          imageSize: const Size(6000, 2000),
          displaySize: display,
          fit: AppBackgroundFit.cover,
        ),
        (width: 3240, height: 1080),
      );
    });

    test('a tall image covering the display keeps the display width', () {
      expect(
        backgroundDecodeSize(
          imageSize: const Size(3840, 4320),
          displaySize: display,
          fit: AppBackgroundFit.cover,
        ),
        (width: 1920, height: 2160),
      );
    });

    test('a contained image fits inside the display', () {
      expect(
        backgroundDecodeSize(
          imageSize: const Size(6000, 2000),
          displaySize: display,
          fit: AppBackgroundFit.contain,
        ),
        (width: 1920, height: 640),
      );
    });

    test('a small image is never enlarged', () {
      expect(
        backgroundDecodeSize(
          imageSize: const Size(800, 600),
          displaySize: display,
          fit: AppBackgroundFit.cover,
        ),
        (width: 800, height: 600),
      );
    });

    test('an unknown display size keeps the full image', () {
      expect(
        backgroundDecodeSize(
          imageSize: const Size(6000, 2000),
          displaySize: Size.zero,
          fit: AppBackgroundFit.cover,
        ),
        (width: 6000, height: 2000),
      );
    });
  });

  test('picks, configures, and clears appearance assets', () async {
    final preferences = _FakeAppearanceService();
    final assets = _FakeAssetService()
      ..backgroundSelection = '/tmp/studio.png'
      ..fontSelection = '/tmp/studio.ttf';
    final container = ProviderContainer(
      overrides: [
        appearancePreferencesServiceProvider.overrideWithValue(preferences),
        appearanceAssetServiceProvider.overrideWithValue(assets),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(appearanceSettingsProvider.notifier);
    await notifier.initialize();

    expect((await notifier.chooseBackgroundImage()).isOk(), isTrue);
    expect(
      (await notifier.setBackgroundFit(AppBackgroundFit.contain)).isOk(),
      isTrue,
    );
    expect((await notifier.setBackgroundOverlayOpacity(0.6)).isOk(), isTrue);
    expect((await notifier.chooseCustomFont()).isOk(), isTrue);
    expect(
      container.read(appearanceSettingsProvider).backgroundImagePath,
      '/tmp/studio.png',
    );
    expect(
      container.read(appearanceSettingsProvider).backgroundFit,
      AppBackgroundFit.contain,
    );
    expect(
      container.read(appearanceSettingsProvider).backgroundOverlayOpacity,
      0.6,
    );
    expect(
      container.read(appearanceSettingsProvider).font,
      const AppFontChoice.file('/tmp/studio.ttf'),
    );
    expect(
      container.read(appearanceSettingsProvider).fontFamily,
      startsWith('DigiDAWCustomFont'),
    );
    expect(
      preferences.saved?.font,
      const AppFontChoice.file('/tmp/studio.ttf'),
    );

    await notifier.clearBackgroundImage();
    await notifier.setFont(AppFontChoice.defaultFont);
    expect(
      container.read(appearanceSettingsProvider).backgroundImagePath,
      isNull,
    );
    expect(
      container.read(appearanceSettingsProvider).fontFamily,
      AppFonts.defaultFamily,
    );
  });

  test('missing restored assets safely fall back and are cleared', () async {
    final preferences = _FakeAppearanceService()
      ..loaded = (
        themeMode: AppThemeMode.dark,
        colorPalette: AppColorPalette.purple,
        backgroundImagePath: '/gone/background.png',
        backgroundFit: AppBackgroundFit.fill,
        backgroundOverlayOpacity: 0.5,
        font: const AppFontChoice.file('/gone/font.ttf'),
        colorThemeSource: null,
        customColorThemePaths: const [],
      );
    final assets = _FakeAssetService()
      ..exists = false
      ..fontLoads = false;
    final container = ProviderContainer(
      overrides: [
        appearancePreferencesServiceProvider.overrideWithValue(preferences),
        appearanceAssetServiceProvider.overrideWithValue(assets),
      ],
    );
    addTearDown(container.dispose);

    expect(
      (await container.read(appearanceSettingsProvider.notifier).initialize())
          .isOk(),
      isTrue,
    );
    expect(
      container.read(appearanceSettingsProvider).backgroundImagePath,
      isNull,
    );
    expect(
      container.read(appearanceSettingsProvider).font,
      AppFontChoice.defaultFont,
    );
    expect(
      container.read(appearanceSettingsProvider).fontFamily,
      AppFonts.defaultFamily,
    );
    expect(preferences.saved?.backgroundImagePath, isNull);
    expect(preferences.saved?.font, AppFontChoice.defaultFont);
  });

  group('fonts', () {
    ProviderContainer containerWith(
      _FakeAppearanceService preferences, {
      String? systemFamily,
    }) {
      final container = ProviderContainer(
        overrides: [
          appearancePreferencesServiceProvider.overrideWithValue(preferences),
          appearanceAssetServiceProvider.overrideWithValue(_FakeAssetService()),
          systemFontServiceProvider.overrideWithValue(
            _FakeSystemFontService(systemFamily),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test(
      'the default font is IBM Plex Sans before and after loading',
      () async {
        final container = containerWith(_FakeAppearanceService());
        expect(
          container.read(appearanceSettingsProvider).fontFamily,
          AppFonts.defaultFamily,
        );
        await container.read(appearanceSettingsProvider.notifier).initialize();
        expect(
          container.read(appearanceSettingsProvider).fontFamily,
          AppFonts.defaultFamily,
        );
      },
    );

    test('the system font uses the family the desktop names', () async {
      final preferences = _FakeAppearanceService();
      final container = containerWith(
        preferences,
        systemFamily: 'JetBrains Mono',
      );
      final notifier = container.read(appearanceSettingsProvider.notifier);
      await notifier.initialize();

      await notifier.setFont(const AppFontChoice.system());
      final state = container.read(appearanceSettingsProvider);
      expect(state.font, const AppFontChoice.system());
      expect(state.fontFamily, 'JetBrains Mono');
      expect(preferences.saved?.font, const AppFontChoice.system());
    });

    test('a desktop without a named font keeps the platform font', () async {
      final container = containerWith(_FakeAppearanceService());
      final notifier = container.read(appearanceSettingsProvider.notifier);
      await notifier.initialize();
      await notifier.setFont(const AppFontChoice.system());
      expect(container.read(appearanceSettingsProvider).fontFamily, isNull);
    });

    test('a bundled font is applied, and an unknown one falls back', () async {
      final preferences = _FakeAppearanceService()
        ..loaded = (
          themeMode: AppThemeMode.dark,
          colorPalette: AppColorPalette.purple,
          backgroundImagePath: null,
          backgroundFit: AppBackgroundFit.cover,
          backgroundOverlayOpacity: 0.35,
          font: const AppFontChoice.bundled('Gone Sans'),
          colorThemeSource: null,
          customColorThemePaths: const [],
        );
      final container = containerWith(preferences);
      final notifier = container.read(appearanceSettingsProvider.notifier);
      await notifier.initialize();
      expect(
        container.read(appearanceSettingsProvider).fontFamily,
        AppFonts.defaultFamily,
      );

      await notifier.setFont(const AppFontChoice.bundled('Inter'));
      expect(container.read(appearanceSettingsProvider).fontFamily, 'Inter');
    });

    test('the default font is stored as the default', () {
      expect(
        AppearancePreferencesService.fontToStored(AppFontChoice.defaultFont),
        const UiFontChoice.default_(),
      );
      expect(
        AppearancePreferencesService.fontFromStored(
          const UiFontChoice.default_(),
        ),
        AppFontChoice.defaultFont,
      );
      for (final font in const [
        AppFontChoice.system(),
        AppFontChoice.bundled('Inter'),
        AppFontChoice.file('/fonts/studio.otf'),
      ]) {
        expect(
          AppearancePreferencesService.fontFromStored(
            AppearancePreferencesService.fontToStored(font),
          ),
          font,
        );
      }
    });

    test('desktop font settings name their family', () {
      expect(pangoFontFamily("'JetBrains Mono  10'"), 'JetBrains Mono');
      expect(pangoFontFamily('JetBrains Mono,  10'), 'JetBrains Mono');
      expect(pangoFontFamily('Noto Sans Bold Italic 11'), 'Noto Sans');
      expect(pangoFontFamily('Cantarell, Sans 11'), 'Cantarell');
      expect(pangoFontFamily("''"), isNull);
      expect(
        kdeFontFamily(
          '[KDE]\nfont=Wrong\n[General]\nColorScheme=Breeze\n'
          'font=JetBrains Mono,10,-1,5,400,0,0,0,0,0\n',
        ),
        'JetBrains Mono',
      );
      expect(kdeFontFamily('[General]\nColorScheme=Breeze\n'), isNull);
    });

    testWidgets('the font menu filters by typed text and applies a pick', (
      tester,
    ) async {
      final container = containerWith(_FakeAppearanceService());
      await container.read(appearanceSettingsProvider.notifier).initialize();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: AppearanceSettingsPage()),
          ),
        ),
      );

      final field = find.descendant(
        of: find.byType(DropdownMenu<AppFontChoice>),
        matching: find.byType(TextField),
      );
      await tester.ensureVisible(field);
      await tester.tap(field);
      await tester.pumpAndSettle();
      // The menu also builds a hidden copy of its entries to size itself;
      // only the shown ones can be hit.
      final fira = find
          .byKey(const ValueKey('font-entry-Fira Sans'))
          .hitTestable();
      final roboto = find
          .byKey(const ValueKey('font-entry-Roboto'))
          .hitTestable();
      await tester.enterText(field, 'fira');
      await tester.pumpAndSettle();

      expect(fira, findsOneWidget);
      expect(roboto, findsNothing);

      await tester.tap(fira);
      await tester.pumpAndSettle();
      expect(
        container.read(appearanceSettingsProvider).font,
        const AppFontChoice.bundled('Fira Sans'),
      );
    });
  });

  group('color themes', () {
    ProviderContainer containerWith(
      _FakeAppearanceService preferences,
      _FakeAssetService assets,
    ) {
      final container = ProviderContainer(
        overrides: [
          appearancePreferencesServiceProvider.overrideWithValue(preferences),
          appearanceAssetServiceProvider.overrideWithValue(assets),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('bundled themes are listed and can be applied and cleared', () async {
      final preferences = _FakeAppearanceService();
      final container = containerWith(preferences, _FakeAssetService());
      final notifier = container.read(appearanceSettingsProvider.notifier);
      await notifier.initialize();
      final mocha = AppearanceAssetService.catppuccinMochaColorThemeSource;
      const defaultSource = AppearanceAssetService.defaultColorThemeSource;

      expect(
        container.read(appearanceSettingsProvider).colorThemes.keys,
        containsAll(AppearanceAssetService.bundledColorThemes),
      );
      expect(
        container.read(appearanceSettingsProvider).colorThemeSource,
        defaultSource,
      );
      expect(
        container.read(appearanceSettingsProvider).colorTheme?.name,
        'DigiDAW Dark',
      );
      expect(
        container.read(appearanceSettingsProvider).colorTheme?.primary,
        const Color(0xFFCFB8D9),
      );

      expect((await notifier.setColorTheme(mocha)).isOk(), isTrue);
      expect(
        container.read(appearanceSettingsProvider).colorTheme?.primary,
        const Color(0xFFCBA6F7),
      );
      expect(preferences.saved?.colorThemeSource, mocha);

      expect(
        (await notifier.setColorTheme('/not/loaded.json')).isErr(),
        isTrue,
      );
      expect(
        container.read(appearanceSettingsProvider).colorThemeSource,
        mocha,
      );

      await notifier.setColorTheme(null);
      expect(container.read(appearanceSettingsProvider).colorTheme, isNull);
      expect(preferences.saved?.colorThemeSource, isNull);
    });

    test('stored color theme choices map to theme sources', () {
      const defaultSource = AppearanceAssetService.defaultColorThemeSource;

      expect(
        AppearancePreferencesService.colorThemeSourceFromStored(
          const UiColorThemeChoice.bundled(),
        ),
        defaultSource,
      );
      expect(
        AppearancePreferencesService.colorThemeSourceFromStored(
          const UiColorThemeChoice.accentPalette(),
        ),
        isNull,
      );
      expect(
        AppearancePreferencesService.colorThemeSourceFromStored(
          const UiColorThemeChoice.source('/themes/mine.json'),
        ),
        '/themes/mine.json',
      );
      for (final source in [defaultSource, null, '/themes/mine.json']) {
        expect(
          AppearancePreferencesService.colorThemeSourceFromStored(
            AppearancePreferencesService.colorThemeSourceToStored(source),
          ),
          source,
        );
      }
    });

    test('picked theme files are loaded, applied, and kept', () async {
      final preferences = _FakeAppearanceService();
      final assets = _FakeAssetService()
        ..colorThemeFiles['/themes/one.json'] = _themeJson('One')
        ..colorThemeFiles['/themes/two.json'] = _themeJson('Two')
        ..colorThemeSelection = '/themes/one.json';
      final container = containerWith(preferences, assets);
      final notifier = container.read(appearanceSettingsProvider.notifier);
      await notifier.initialize();

      expect((await notifier.chooseColorThemeFile()).isOk(), isTrue);
      expect(
        container.read(appearanceSettingsProvider).colorTheme?.name,
        'One',
      );
      expect(preferences.saved?.customColorThemePaths, ['/themes/one.json']);

      assets.colorThemeSelection = '/themes/two.json';
      await notifier.chooseColorThemeFile();
      var state = container.read(appearanceSettingsProvider);
      expect(state.colorTheme?.name, 'Two');
      expect(state.colorThemes.containsKey('/themes/one.json'), isTrue);
      expect(preferences.saved?.customColorThemePaths, [
        '/themes/one.json',
        '/themes/two.json',
      ]);

      // Picking a file that is already listed reloads it without a duplicate.
      assets
        ..colorThemeFiles['/themes/one.json'] = _themeJson('One again')
        ..colorThemeSelection = '/themes/one.json';
      await notifier.chooseColorThemeFile();
      state = container.read(appearanceSettingsProvider);
      expect(state.colorTheme?.name, 'One again');
      expect(state.customColorThemePaths, hasLength(2));
    });

    test(
      'removing a loaded theme returns to Default when it is active',
      () async {
        final preferences = _FakeAppearanceService();
        final assets = _FakeAssetService()
          ..colorThemeFiles['/themes/one.json'] = _themeJson('One')
          ..colorThemeFiles['/themes/two.json'] = _themeJson('Two')
          ..colorThemeSelection = '/themes/one.json';
        final container = containerWith(preferences, assets);
        final notifier = container.read(appearanceSettingsProvider.notifier);
        await notifier.initialize();
        await notifier.chooseColorThemeFile();
        assets.colorThemeSelection = '/themes/two.json';
        await notifier.chooseColorThemeFile();

        expect(
          (await notifier.removeColorTheme('/themes/one.json')).isOk(),
          isTrue,
        );
        var state = container.read(appearanceSettingsProvider);
        expect(state.colorThemes.containsKey('/themes/one.json'), isFalse);
        expect(state.colorTheme?.name, 'Two');

        await notifier.removeColorTheme('/themes/two.json');
        state = container.read(appearanceSettingsProvider);
        expect(state.colorTheme, isNull);
        expect(state.customColorThemePaths, isEmpty);
        expect(preferences.saved?.colorThemeSource, isNull);
        expect(preferences.saved?.customColorThemePaths, isEmpty);

        final mocha = AppearanceAssetService.catppuccinMochaColorThemeSource;
        expect((await notifier.removeColorTheme(mocha)).isErr(), isTrue);
        expect(
          container.read(appearanceSettingsProvider).colorThemes.keys,
          contains(mocha),
        );
      },
    );

    test(
      'an invalid theme file is rejected and keeps the current theme',
      () async {
        final preferences = _FakeAppearanceService();
        final assets = _FakeAssetService()
          ..colorThemeFiles['/themes/bad.json'] = '{"name": "Bad"}'
          ..colorThemeSelection = '/themes/bad.json';
        final container = containerWith(preferences, assets);
        final notifier = container.read(appearanceSettingsProvider.notifier);
        await notifier.initialize();

        final result = await notifier.chooseColorThemeFile();

        expect(result.err(), isA<ColorThemeFormatException>());
        final state = container.read(appearanceSettingsProvider);
        expect(
          state.colorThemeSource,
          AppearanceAssetService.defaultColorThemeSource,
        );
        expect(state.customColorThemePaths, isEmpty);
      },
    );

    test('a saved theme file is restored, or dropped when missing', () async {
      final preferences = _FakeAppearanceService()
        ..loaded = (
          themeMode: AppThemeMode.dark,
          colorPalette: AppColorPalette.purple,
          backgroundImagePath: null,
          backgroundFit: AppBackgroundFit.cover,
          backgroundOverlayOpacity: 0.35,
          font: AppFontChoice.defaultFont,
          colorThemeSource: '/themes/mine.json',
          customColorThemePaths: const ['/themes/mine.json'],
        );
      final restored = containerWith(
        preferences,
        _FakeAssetService()
          ..colorThemeFiles['/themes/mine.json'] = _themeJson('Mine'),
      );
      await restored.read(appearanceSettingsProvider.notifier).initialize();
      expect(
        restored.read(appearanceSettingsProvider).colorTheme?.name,
        'Mine',
      );

      final missing = containerWith(preferences, _FakeAssetService());
      await missing.read(appearanceSettingsProvider.notifier).initialize();
      expect(missing.read(appearanceSettingsProvider).colorTheme, isNull);
      expect(preferences.saved?.colorThemeSource, isNull);
      expect(preferences.saved?.customColorThemePaths, isEmpty);
    });

    testWidgets('the theme menu applies a theme and locks the palette', (
      tester,
    ) async {
      final container = containerWith(
        _FakeAppearanceService(),
        _FakeAssetService(),
      );
      await container.read(appearanceSettingsProvider.notifier).initialize();
      final mocha = AppearanceAssetService.catppuccinMochaColorThemeSource;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: AppearanceSettingsPage()),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('color-theme-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('color-theme-$mocha')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('palette-red')));
      await tester.pump();

      final state = container.read(appearanceSettingsProvider);
      expect(state.colorThemeSource, mocha);
      expect(state.colorPalette, AppColorPalette.teal);
    });

    testWidgets('the theme menu removes a loaded theme after a warning', (
      tester,
    ) async {
      final preferences = _FakeAppearanceService()
        ..loaded = (
          themeMode: AppThemeMode.dark,
          colorPalette: AppColorPalette.purple,
          backgroundImagePath: null,
          backgroundFit: AppBackgroundFit.cover,
          backgroundOverlayOpacity: 0.35,
          font: AppFontChoice.defaultFont,
          colorThemeSource: '/themes/mine.json',
          customColorThemePaths: const ['/themes/mine.json'],
        );
      final container = containerWith(
        preferences,
        _FakeAssetService()
          ..colorThemeFiles['/themes/mine.json'] = _themeJson('Mine'),
      );
      await container.read(appearanceSettingsProvider.notifier).initialize();
      final mocha = AppearanceAssetService.catppuccinMochaColorThemeSource;
      const remove = ValueKey('remove-color-theme-/themes/mine.json');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: AppearanceSettingsPage()),
          ),
        ),
      );
      // The closed menu shows the active theme without a remove button.
      expect(find.text('Mine'), findsOneWidget);
      expect(find.byKey(remove), findsNothing);

      await tester.tap(find.byKey(const ValueKey('color-theme-menu')));
      await tester.pumpAndSettle();
      // Bundled themes cannot be removed.
      expect(find.byKey(ValueKey('remove-color-theme-$mocha')), findsNothing);
      await tester.tap(find.byKey(remove));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('remove-color-theme-dialog')),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(
        container.read(appearanceSettingsProvider).colorThemeSource,
        '/themes/mine.json',
      );

      await tester.tap(find.byKey(const ValueKey('color-theme-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(remove));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('confirm-remove-color-theme')),
      );
      await tester.pumpAndSettle();

      final state = container.read(appearanceSettingsProvider);
      expect(state.colorThemeSource, isNull);
      expect(state.customColorThemePaths, isEmpty);
      expect(find.text('Mine'), findsNothing);
      expect(find.text('Default'), findsOneWidget);
    });

    test('a loaded theme maps onto the Material colour scheme', () {
      final theme = parseColorTheme(_themeJson('Mine')).ok();
      final data = AppTheme.custom(theme, fontFamily: 'StudioFont');

      expect(data.brightness, Brightness.dark);
      expect(data.colorScheme.primary, const Color(0xFFCBA6F7));
      expect(data.colorScheme.surface, const Color(0xFF1E1E2E));
      expect(data.scaffoldBackgroundColor, const Color(0xFF1E1E2E));
      expect(data.textTheme.bodyMedium?.fontFamily, 'StudioFont');
    });
  });
}
