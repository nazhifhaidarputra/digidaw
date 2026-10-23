import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/notification_provider.dart';
import 'package:karbeat/core/utils/logger.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/features/setting/models/app_color_theme.dart';
import 'package:karbeat/features/setting/models/appearance_settings_state.dart';
import 'package:karbeat/features/setting/services/appearance_asset_service.dart';
import 'package:karbeat/features/setting/services/appearance_preferences_service.dart';
import 'package:karbeat/features/setting/services/color_theme_parser.dart';

/// Pixel size to decode a background image at so it stays sharp when the
/// window fills [displaySize], without decoding more than is ever shown.
///
/// A cover fit scales the image until it covers the display, so the larger of
/// the two axis ratios applies; the other fits stay inside or match it.
/// Images are never decoded above their own resolution.
({int width, int height}) backgroundDecodeSize({
  required ui.Size imageSize,
  required ui.Size displaySize,
  required AppBackgroundFit fit,
}) {
  final fullSize = (
    width: imageSize.width.round(),
    height: imageSize.height.round(),
  );
  if (imageSize.isEmpty || displaySize.isEmpty) return fullSize;

  final widthRatio = displaySize.width / imageSize.width;
  final heightRatio = displaySize.height / imageSize.height;
  final scale = switch (fit) {
    AppBackgroundFit.cover ||
    AppBackgroundFit.fill => math.max(widthRatio, heightRatio),
    AppBackgroundFit.contain => math.min(widthRatio, heightRatio),
  };
  if (scale >= 1) return fullSize;
  return (
    width: math.max(1, (imageSize.width * scale).round()),
    height: math.max(1, (imageSize.height * scale).round()),
  );
}

final workspaceBackgroundImageProvider = FutureProvider<ui.Image?>((ref) async {
  final appearance = ref.watch(
    appearanceSettingsProvider.select(
      (s) => (path: s.backgroundImagePath, fit: s.backgroundFit),
    ),
  );
  final path = appearance.path;
  if (path == null) return null;

  final bytes = await File(path).readAsBytes();
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  final descriptor = await ui.ImageDescriptor.encoded(buffer);

  // Sized for the largest display rather than the current window: the window
  // starts small and is maximized afterwards.
  final dispatcher = ui.PlatformDispatcher.instance;
  var displaySize = dispatcher.views.first.physicalSize;
  for (final display in dispatcher.displays) {
    displaySize = ui.Size(
      math.max(displaySize.width, display.size.width),
      math.max(displaySize.height, display.size.height),
    );
  }
  final target = backgroundDecodeSize(
    imageSize: ui.Size(
      descriptor.width.toDouble(),
      descriptor.height.toDouble(),
    ),
    displaySize: displaySize,
    fit: appearance.fit,
  );
  final codec = await descriptor.instantiateCodec(
    targetWidth: target.width,
    targetHeight: target.height,
  );
  final frame = await codec.getNextFrame();
  final image = frame.image;
  codec.dispose();
  descriptor.dispose();
  buffer.dispose();

  // Dispose the native buffer when this provider recomputes (path changed)
  // or is torn down, so we don't leak GPU memory on repeated picks.
  ref.onDispose(image.dispose);

  return image;
});

final appearancePreferencesServiceProvider =
    Provider<AppearancePreferencesService>((ref) {
      return AppearancePreferencesService();
    });

class AppearanceSettingsNotifier extends Notifier<AppearanceSettingsState> {
  bool _initializationStarted = false;

  @override
  AppearanceSettingsState build() => const AppearanceSettingsState();

  Future<Result<void>> initialize() async {
    if (_initializationStarted) return Result.ok(null);
    _initializationStarted = true;
    final loaded = await ref.read(appearancePreferencesServiceProvider).load();
    if (loaded case Error<AppearancePreferences>(error: final error)) {
      _initializationStarted = false;
      return ref.notifyErrorResult(
        error,
        title: 'Could not load appearance settings',
      );
    }

    final appearance = loaded.ok();
    final assets = ref.read(appearanceAssetServiceProvider);
    var backgroundPath = appearance.backgroundImagePath;
    if (backgroundPath != null) {
      final exists = await assets.fileExists(backgroundPath);
      if (exists.isErr() || !exists.ok()) {
        ref
            .read(notificationProvider.notifier)
            .warn(
              'The saved background image is unavailable. The default background is being used.',
              title: 'Background image unavailable',
            );
        backgroundPath = null;
      }
    }

    var fontPath = appearance.customFontPath;
    var fontFamily = appearance.customFontFamily;
    if (fontPath != null && fontFamily != null) {
      final loadedFont = await assets.loadFont(fontPath, fontFamily);
      if (loadedFont.isErr()) {
        ref
            .read(notificationProvider.notifier)
            .warn(
              'The saved custom font is unavailable. The system font is being used.',
              title: 'Custom font unavailable',
            );
        fontPath = null;
        fontFamily = null;
      }
    } else {
      fontPath = null;
      fontFamily = null;
    }

    var colorThemes = const IMap<String, AppColorTheme>.empty();
    for (final asset in AppearanceAssetService.bundledColorThemes) {
      switch (await _loadColorTheme(asset)) {
        case Ok<AppColorTheme>(value: final theme):
          colorThemes = colorThemes.add(asset, theme);
        case Error<AppColorTheme>(:final error):
          AppLogger.warn('Bundled color theme $asset is unavailable: $error');
      }
    }
    var customThemePaths = const IList<String>.empty();
    var unavailableThemes = 0;
    for (final path in appearance.customColorThemePaths) {
      switch (await _loadColorTheme(path)) {
        case Ok<AppColorTheme>(value: final theme):
          colorThemes = colorThemes.add(path, theme);
          customThemePaths = customThemePaths.add(path);
        case Error<AppColorTheme>(:final error):
          AppLogger.warn('Color theme $path is unavailable: $error');
          unavailableThemes++;
      }
    }
    if (unavailableThemes > 0) {
      ref
          .read(notificationProvider.notifier)
          .warn(
            unavailableThemes == 1
                ? 'A saved color theme file is unavailable or no longer valid. It was removed from the theme menu.'
                : '$unavailableThemes saved color theme files are unavailable or no longer valid. They were removed from the theme menu.',
            title: 'Color theme unavailable',
          );
    }
    var themeSource = appearance.colorThemeSource;
    if (themeSource != null && !colorThemes.containsKey(themeSource)) {
      themeSource = null;
    }

    state = AppearanceSettingsState(
      themeMode: appearance.themeMode,
      colorPalette: appearance.colorPalette,
      backgroundImagePath: backgroundPath,
      backgroundFit: appearance.backgroundFit,
      backgroundOverlayOpacity: appearance.backgroundOverlayOpacity,
      customFontPath: fontPath,
      customFontFamily: fontFamily,
      colorThemes: colorThemes,
      colorThemeSource: themeSource,
      customColorThemePaths: customThemePaths,
      isInitialized: true,
    );
    if (backgroundPath != appearance.backgroundImagePath ||
        fontPath != appearance.customFontPath ||
        themeSource != appearance.colorThemeSource ||
        unavailableThemes > 0) {
      await _persist(state);
    }
    return Result.ok(null);
  }

  Future<Result<void>> setThemeMode(AppThemeMode themeMode) {
    return _persist(state.copyWith(themeMode: themeMode));
  }

  Future<Result<void>> setColorPalette(AppColorPalette palette) {
    return _persist(state.copyWith(colorPalette: palette));
  }

  /// Activates a loaded colour theme, or the accent palette when [source] is
  /// null.
  Future<Result<void>> setColorTheme(String? source) async {
    if (source != null && !state.colorThemes.containsKey(source)) {
      return ref.notifyErrorResult(
        Exception('The color theme is not loaded.'),
        title: 'Could not apply color theme',
      );
    }
    return _persist(state.copyWith(colorThemeSource: source));
  }

  /// Loads a JSON theme file picked by the user into the theme menu and
  /// activates it. Picking a file that is already in the menu reloads it.
  Future<Result<void>> chooseColorThemeFile() async {
    final picked = await ref
        .read(appearanceAssetServiceProvider)
        .pickColorThemeFile();
    if (picked case Error<String?>(error: final error)) {
      return ref.notifyErrorResult(
        error,
        title: 'Could not choose color theme',
      );
    }
    final path = picked.ok();
    if (path == null) return Result.ok(null);
    final loaded = await _loadColorTheme(path);
    if (loaded case Error<AppColorTheme>(error: final error)) {
      return ref.notifyErrorResult(error, title: 'Could not load color theme');
    }

    final paths = state.customColorThemePaths;
    return _persist(
      state.copyWith(
        colorThemes: state.colorThemes.add(path, loaded.ok()),
        colorThemeSource: path,
        customColorThemePaths: paths.contains(path) ? paths : paths.add(path),
      ),
    );
  }

  /// Removes a loaded theme file from the theme menu; the file itself is not
  /// touched. Removing the active theme returns to the accent palette.
  ///
  /// Bundled themes cannot be removed.
  Future<Result<void>> removeColorTheme(String source) async {
    if (!state.customColorThemePaths.contains(source)) {
      return ref.notifyErrorResult(
        Exception('Only color themes loaded from a file can be removed.'),
        title: 'Could not remove color theme',
      );
    }
    final active = state.colorThemeSource;
    return _persist(
      state.copyWith(
        colorThemes: state.colorThemes.remove(source),
        colorThemeSource: active == source ? null : active,
        customColorThemePaths: state.customColorThemePaths.remove(source),
      ),
    );
  }

  Future<Result<AppColorTheme>> _loadColorTheme(String source) async {
    final text = await ref
        .read(appearanceAssetServiceProvider)
        .readColorTheme(source);
    return text.andThen(parseColorTheme);
  }

  Future<Result<void>> setBackgroundFit(AppBackgroundFit fit) {
    return _persist(state.copyWith(backgroundFit: fit));
  }

  Future<Result<void>> setBackgroundOverlayOpacity(double opacity) {
    return _persist(
      state.copyWith(backgroundOverlayOpacity: opacity.clamp(0.0, 0.9)),
    );
  }

  Future<Result<void>> chooseBackgroundImage() async {
    final picked = await ref
        .read(appearanceAssetServiceProvider)
        .pickBackgroundImage();
    if (picked case Error<String?>(error: final error)) {
      return ref.notifyErrorResult(
        error,
        title: 'Could not choose background image',
      );
    }
    final path = picked.ok();
    if (path == null) return Result.ok(null);
    return _persist(state.copyWith(backgroundImagePath: path));
  }

  Future<Result<void>> clearBackgroundImage() {
    return _persist(state.copyWith(backgroundImagePath: null));
  }

  Future<Result<void>> chooseCustomFont() async {
    final assets = ref.read(appearanceAssetServiceProvider);
    final picked = await assets.pickFontFile();
    if (picked case Error<String?>(error: final error)) {
      return ref.notifyErrorResult(error, title: 'Could not choose font');
    }
    final path = picked.ok();
    if (path == null) return Result.ok(null);
    final family = 'DigiDAWCustomFont${DateTime.now().microsecondsSinceEpoch}';
    final loaded = await assets.loadFont(path, family);
    if (loaded case Error<void>(error: final error)) {
      return ref.notifyErrorResult(error, title: 'Could not load font');
    }
    return _persist(
      state.copyWith(customFontPath: path, customFontFamily: family),
    );
  }

  Future<Result<void>> clearCustomFont() {
    return _persist(
      state.copyWith(customFontPath: null, customFontFamily: null),
    );
  }

  Future<Result<void>> _persist(AppearanceSettingsState nextState) async {
    state = nextState;
    final saved = await ref.read(appearancePreferencesServiceProvider).save((
      themeMode: state.themeMode,
      colorPalette: state.colorPalette,
      backgroundImagePath: state.backgroundImagePath,
      backgroundFit: state.backgroundFit,
      backgroundOverlayOpacity: state.backgroundOverlayOpacity,
      customFontPath: state.customFontPath,
      customFontFamily: state.customFontFamily,
      colorThemeSource: state.colorThemeSource,
      customColorThemePaths: state.customColorThemePaths.unlock,
    ));
    if (saved case Error<void>(error: final error)) {
      return ref.notifyErrorResult(
        error,
        title: 'Appearance changed but not saved',
      );
    }
    return Result.ok(null);
  }
}

final appearanceSettingsProvider =
    NotifierProvider<AppearanceSettingsNotifier, AppearanceSettingsState>(
      AppearanceSettingsNotifier.new,
    );
