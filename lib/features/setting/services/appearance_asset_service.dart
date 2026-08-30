import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/core/utils/result_type.dart';

class AppearanceAssetService {
  Future<Result<String?>> pickBackgroundImage() {
    return attemptAsync(() async {
      final result = await FilePicker.pickFiles(
        dialogTitle: 'Choose workspace background',
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
      );
      return result?.files.single.path;
    });
  }

  Future<Result<String?>> pickFontFile() {
    return attemptAsync(() async {
      final result = await FilePicker.pickFiles(
        dialogTitle: 'Choose application font',
        type: FileType.custom,
        allowedExtensions: const ['ttf', 'otf'],
      );
      return result?.files.single.path;
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
