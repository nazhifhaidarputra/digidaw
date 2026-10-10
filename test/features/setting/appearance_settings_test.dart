import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karbeat/app/app_theme.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/features/setting/models/appearance_settings_state.dart';
import 'package:karbeat/features/setting/services/appearance_asset_service.dart';
import 'package:karbeat/features/setting/services/appearance_preferences_service.dart';
import 'package:karbeat/features/setting/services/appearance_settings_provider.dart';
import 'package:karbeat/features/setting/services/color_theme_parser.dart';
import 'package:karbeat/features/setting/view/appearance_settings_page.dart';

class _FakeAppearanceService extends AppearancePreferencesService {
  AppearancePreferences loaded = (
    themeMode: AppThemeMode.light,
    colorPalette: AppColorPalette.teal,
    backgroundImagePath: null,
    backgroundFit: AppBackgroundFit.cover,
    backgroundOverlayOpacity: 0.35,
    customFontPath: null,
    customFontFamily: null,
    colorThemeSource: null,
    customColorThemePath: null,
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
      asset: _themeJson(asset),
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
    final service = _FakeAppearanceService();
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
      container.read(appearanceSettingsProvider).customFontPath,
      '/tmp/studio.ttf',
    );
    expect(
      container.read(appearanceSettingsProvider).customFontFamily,
      isNotNull,
    );

    await notifier.clearBackgroundImage();
    await notifier.clearCustomFont();
    expect(
      container.read(appearanceSettingsProvider).backgroundImagePath,
      isNull,
    );
    expect(container.read(appearanceSettingsProvider).customFontPath, isNull);
  });

  test('missing restored assets safely fall back and are cleared', () async {
    final preferences = _FakeAppearanceService()
      ..loaded = (
        themeMode: AppThemeMode.dark,
        colorPalette: AppColorPalette.purple,
        backgroundImagePath: '/gone/background.png',
        backgroundFit: AppBackgroundFit.fill,
        backgroundOverlayOpacity: 0.5,
        customFontPath: '/gone/font.ttf',
        customFontFamily: 'DigiDAWCustomFont1',
        colorThemeSource: null,
        customColorThemePath: null,
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
    expect(container.read(appearanceSettingsProvider).customFontPath, isNull);
    expect(preferences.saved?.backgroundImagePath, isNull);
    expect(preferences.saved?.customFontPath, isNull);
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
      final mocha = AppearanceAssetService.bundledColorThemes.first;

      expect(
        container.read(appearanceSettingsProvider).colorThemes.keys,
        containsAll(AppearanceAssetService.bundledColorThemes),
      );
      expect(container.read(appearanceSettingsProvider).colorTheme, isNull);

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

    test('a picked theme file is loaded, applied, and replaced', () async {
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
      expect(preferences.saved?.customColorThemePath, '/themes/one.json');

      assets.colorThemeSelection = '/themes/two.json';
      await notifier.chooseColorThemeFile();
      final state = container.read(appearanceSettingsProvider);
      expect(state.colorTheme?.name, 'Two');
      expect(state.colorThemes.containsKey('/themes/one.json'), isFalse);
    });

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
        expect(state.colorThemeSource, isNull);
        expect(state.customColorThemePath, isNull);
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
          customFontPath: null,
          customFontFamily: null,
          colorThemeSource: '/themes/mine.json',
          customColorThemePath: '/themes/mine.json',
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
      expect(preferences.saved?.customColorThemePath, isNull);
    });

    testWidgets('the theme menu applies a theme and locks the palette', (
      tester,
    ) async {
      final container = containerWith(
        _FakeAppearanceService(),
        _FakeAssetService(),
      );
      await container.read(appearanceSettingsProvider.notifier).initialize();
      final mocha = AppearanceAssetService.bundledColorThemes.first;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: AppearanceSettingsPage()),
          ),
        ),
      );
      await tester.tap(find.byKey(ValueKey('color-theme-$mocha')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('palette-red')));
      await tester.pump();

      final state = container.read(appearanceSettingsProvider);
      expect(state.colorThemeSource, mocha);
      expect(state.colorPalette, AppColorPalette.teal);
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
