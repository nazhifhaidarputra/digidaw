import 'dart:io';

import 'package:flutter/services.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/src/rust/api/audio_analysis.dart';
import 'package:path_provider/path_provider.dart';

/// Makes the bundled Beat This! models, the mel front end and the small beat
/// model, available to Rust tempo detection.
///
/// Desktop builds read the models straight from the Flutter asset folder. Mobile
/// assets are not files, so they are copied to app support storage once; a
/// marker holding the beat model's pinned hash skips the copy on later launches.
abstract final class TempoModelInstaller {
  static const _assetDir = 'assets/models';
  static const _mel = 'mel_spectrogram.onnx';
  static const _beat = 'beat_this_small.onnx';

  /// SHA-256 hash of the beat model, pinned in `scripts/fetch_beat_models.sh`,
  /// so a changed model is copied again.
  static const _modelsSha256 =
      'a5f8d39d989f31859454ba27afe61c5317ca95e4d9373e6853e5361b8937172f';

  static Future<Result<void>> install() => attemptAsync(() async {
    final directory = await _modelDirectory();
    await configureTempoModels(
      melPath: '$directory/$_mel',
      beatPath: '$directory/$_beat',
    );
  });

  static Future<String> _modelDirectory() async {
    final bundled = _bundledDirectory();
    if (bundled != null &&
        [_mel, _beat].every((name) => File('$bundled/$name').existsSync())) {
      return bundled;
    }

    final support = await getApplicationSupportDirectory();
    final target = Directory('${support.path}/models');
    final marker = File('${target.path}/$_beat.sha256');
    if (marker.existsSync() && marker.readAsStringSync() == _modelsSha256) {
      return target.path;
    }
    await target.create(recursive: true);
    for (final name in [_mel, _beat]) {
      final data = await rootBundle.load('$_assetDir/$name');
      final partial = File('${target.path}/$name.part');
      await partial.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );
      await partial.rename('${target.path}/$name');
    }
    await marker.writeAsString(_modelsSha256, flush: true);
    return target.path;
  }

  /// The Flutter asset folder of a desktop build, or `null` on mobile.
  static String? _bundledDirectory() {
    final executableDir = File(Platform.resolvedExecutable).parent.path;
    if (Platform.isLinux || Platform.isWindows) {
      return '$executableDir/data/flutter_assets/$_assetDir';
    }
    if (Platform.isMacOS) {
      final contents = Directory(executableDir).parent.path;
      return '$contents/Frameworks/App.framework/Resources/flutter_assets/$_assetDir';
    }
    return null;
  }
}
