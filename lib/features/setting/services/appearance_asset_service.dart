import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/core/l10n/localizer.dart';
import 'package:karbeat/core/utils/result_type.dart';

class AppearanceAssetService {
  /// Asset key of the colour theme used until the user picks another one.
  static const defaultColorThemeSource = 'assets/themes/digidaw_dark.json';

  static const digidawLightColorThemeSource =
      'assets/themes/digidaw_light.json';
  static const digidawDarkColorThemeSource = defaultColorThemeSource;

  static const catppuccinMochaColorThemeSource =
      'assets/themes/catppuccin_mocha.json';
  static const catppuccinLatteColorThemeSource =
      'assets/themes/catppuccin_latte.json';

  /// Asset keys of the colour themes shipped with the app, in menu order.
  static const bundledColorThemes = [
    digidawDarkColorThemeSource,
    digidawLightColorThemeSource,
    catppuccinMochaColorThemeSource,
    catppuccinLatteColorThemeSource,
  ];

  static const maxColorThemeFileBytes = 1024 * 1024;

  Future<Result<String?>> pickBackgroundImage() {
    return attemptAsync(() async {
      final result = await FilePicker.pickFiles(
        dialogTitle: tr('settings-appearance-background-dialog'),
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
      );
      return result?.files.single.path;
    });
  }

  Future<Result<String?>> pickFontFile() {
    return attemptAsync(() async {
      final result = await FilePicker.pickFiles(
        dialogTitle: tr('settings-appearance-font-dialog'),
        type: FileType.custom,
        allowedExtensions: const ['ttf', 'otf'],
      );
      return result?.files.single.path;
    });
  }

  Future<Result<String?>> pickColorThemeFile() {
    return attemptAsync(() async {
      final result = await FilePicker.pickFiles(
        dialogTitle: tr('settings-appearance-theme-dialog'),
        type: FileType.custom,
        allowedExtensions: const ['json'],
      );
      return result?.files.single.path;
    });
  }

  /// Reads the JSON text of a colour theme from a bundled asset key or a
  /// file path.
  Future<Result<String>> readColorTheme(String source) {
    return attemptAsync(() async {
      if (bundledColorThemes.contains(source)) {
        return rootBundle.loadString(source);
      }
      final file = File(source);
      if (await file.length() > maxColorThemeFileBytes) {
        throw FileSystemException(
          tr('settings-appearance-theme-too-large'),
          source,
        );
      }
      return file.readAsString();
    });
  }

  Future<Result<bool>> fileExists(String path) {
    return attemptAsync(() => File(path).exists());
  }

  Future<Result<void>> loadFont(String path, String family) {
    return attemptAsync(() async {
      final bytes = await File(path).readAsBytes();
      final data = ByteData.sublistView(Uint8List.fromList(bytes));
      final loader = FontLoader(family)..addFont(Future.value(data));
      await loader.load();
    });
  }
}

final appearanceAssetServiceProvider = Provider<AppearanceAssetService>((ref) {
  return AppearanceAssetService();
});
