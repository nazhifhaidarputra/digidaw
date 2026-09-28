import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karbeat/app/app_theme.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/features/setting/models/appearance_settings_state.dart';
import 'package:karbeat/features/setting/services/appearance_asset_service.dart';
import 'package:karbeat/features/setting/services/appearance_preferences_service.dart';
import 'package:karbeat/features/setting/services/appearance_settings_provider.dart';
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
  Future<Result<void>> loadFont(String path, String family) async =>
      fontLoads ? Result.ok(null) : Result.error(Exception('font missing'));
}

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
}
