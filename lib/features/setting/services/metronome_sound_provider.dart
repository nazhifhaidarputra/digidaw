import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/notification_provider.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/src/rust/api/audio.dart' as audio_api;
import 'package:karbeat/src/rust/api/project.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Picks, stores and applies the custom metronome sound.
class MetronomeSoundService {
  static const soundPathKey = 'settings.audio.metronome_sound_path.v1';

  Future<Result<String?>> loadPath() {
    return attemptAsync(() => SharedPreferencesAsync().getString(soundPathKey));
  }

  Future<Result<void>> savePath(String? path) {
    return attemptAsync(() async {
      final preferences = SharedPreferencesAsync();
      if (path == null) {
        await preferences.remove(soundPathKey);
      } else {
        await preferences.setString(soundPathKey, path);
      }
    });
  }

  Future<Result<String?>> pickSound() {
    return attemptAsync(() async {
      final result = await FilePicker.pickFiles(
        dialogTitle: 'Choose metronome sound',
        type: FileType.audio,
      );
      return result?.files.single.path;
    });
  }

  Future<Result<bool>> fileExists(String path) {
    return attemptAsync(() => File(path).exists());
  }

  /// Makes the engine play the file at [path], or its built-in click when
  /// [path] is null.
  Future<Result<void>> apply(DawContext context, String? path) {
    return attemptAsync(
      () => audio_api.setMetronomeSound(ctx: context, filePath: path),
    );
  }
}

final metronomeSoundServiceProvider = Provider<MetronomeSoundService>((ref) {
  return MetronomeSoundService();
});

/// Path of the custom metronome sound, or null while the built-in click is
/// used.
///
/// The engine plays the file as recorded on offbeats and an octave higher on
/// downbeats.
class MetronomeSoundNotifier extends Notifier<String?> {
  bool _initializationStarted = false;
  DawContext? _dawContext;

  @override
  String? build() => null;

  MetronomeSoundService get _service => ref.read(metronomeSoundServiceProvider);

  /// Restores the saved sound. A sound that can no longer be loaded falls back
  /// to the built-in click.
  Future<Result<void>> initialize(DawContext context) async {
    if (_initializationStarted) return Result.ok(null);
    _initializationStarted = true;
    _dawContext = context;

    final loaded = await _service.loadPath();
    if (loaded case Error<String?>(error: final error)) {
      _initializationStarted = false;
      return ref.notifyErrorResult(
        error,
        title: 'Could not load the metronome sound setting',
      );
    }
    final path = loaded.ok();
    if (path == null) return Result.ok(null);

    final exists = await _service.fileExists(path);
    final applied = exists.isOk() && exists.ok()
        ? await _service.apply(context, path)
        : Result<void>.error(Exception('File not found'));
    if (applied.isErr()) {
      ref
          .read(notificationProvider.notifier)
          .warn(
            'The saved metronome sound is unavailable. The default click is being used.',
            title: 'Metronome sound unavailable',
          );
      return _service.savePath(null);
    }
    state = path;
    return Result.ok(null);
  }

  Future<Result<void>> chooseSound() async {
    final picked = await _service.pickSound();
    if (picked case Error<String?>(error: final error)) {
      return ref.notifyErrorResult(
        error,
        title: 'Could not choose metronome sound',
      );
    }
    final path = picked.ok();
    if (path == null) return Result.ok(null);
    return _applyAndSave(path, failureTitle: 'Could not load metronome sound');
  }

  Future<Result<void>> useDefaultSound() {
    return _applyAndSave(
      null,
      failureTitle: 'Could not restore the default metronome sound',
    );
  }

  Future<Result<void>> _applyAndSave(
    String? path, {
    required String failureTitle,
  }) async {
    final context = _dawContext;
    if (context == null) {
      return ref.notifyErrorResult(
        Exception('The audio engine is not ready'),
        title: failureTitle,
      );
    }
    final applied = await _service.apply(context, path);
    if (applied case Error<void>(error: final error)) {
      return ref.notifyErrorResult(error, title: failureTitle);
    }
    state = path;
    final saved = await _service.savePath(path);
    if (saved case Error<void>(error: final error)) {
      return ref.notifyErrorResult(
        error,
        title: 'Metronome sound changed but not saved',
      );
    }
    return Result.ok(null);
  }
}

final metronomeSoundProvider =
    NotifierProvider<MetronomeSoundNotifier, String?>(
      MetronomeSoundNotifier.new,
    );
